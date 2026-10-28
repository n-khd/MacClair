import Foundation
import CryptoKit
import Darwin

struct LargeFile: Identifiable, Sendable {
    let url: URL
    let bytes: Int64
    let modified: Date
    var id: URL { url }
}

struct DuplicateGroup: Identifiable, Sendable {
    let digest: String
    let files: [URL]
    let bytesPerFile: Int64
    var id: String { digest }
    var reclaimableBytes: Int64 { Int64(max(0, files.count - 1)) * bytesPerFile }
}

struct InstalledApp: Identifiable, Sendable {
    let url: URL
    let name: String
    let version: String
    let bundleID: String
    var id: URL { url }
}

struct SystemSnapshot: Sendable {
    let capacity: Int64
    let available: Int64
    let memory: UInt64
    let processors: Int
}

struct SecuritySnapshot: Sendable {
    let fileVault: String
    let gatekeeper: String
    let systemIntegrity: String
}

struct InsightReport: Sendable {
    let largeFiles: [LargeFile]
    let duplicates: [DuplicateGroup]
    let apps: [InstalledApp]
    let system: SystemSnapshot
    let security: SecuritySnapshot
    let scannedFiles: Int
    let limited: Bool
}

struct InsightScanner: Sendable {
    let home: URL
    let scanRoot: URL

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, scanRoot: URL? = nil) {
        self.home = home.standardizedFileURL
        self.scanRoot = (scanRoot ?? home.appendingPathComponent("Downloads", isDirectory: true)).standardizedFileURL
    }

    func scan() -> InsightReport {
        let fm = FileManager.default
        var candidates: [(url: URL, bytes: Int64, modified: Date, inode: UInt64, device: UInt64)] = []
        var limited = false
        var directories = [scanRoot]
        var nextDirectory = 0
        var visitedEntries = 0
        while nextDirectory < directories.count && candidates.count < 10_000 && visitedEntries < 80_000 {
            let directory = directories[nextDirectory]
            nextDirectory += 1
            guard let urls = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isPackageKey]) else { continue }
            for url in urls {
                visitedEntries += 1
                if candidates.count >= 10_000 || visitedEntries >= 80_000 { limited = true; break }
                if url.lastPathComponent.hasPrefix(".") { continue }
                var info = stat()
                guard url.path.withCString({ Darwin.lstat($0, &info) }) == 0 else { continue }
                let type = info.st_mode & mode_t(S_IFMT)
                if type == mode_t(S_IFDIR) {
                    if (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) != true,
                       !["node_modules", "Pods", "DerivedData", "venv"].contains(url.lastPathComponent),
                       !["app", "bundle", "framework", "xcassets", "xcodeproj", "xcworkspace"].contains(url.pathExtension.lowercased()) {
                        directories.append(url)
                    }
                } else if type == mode_t(S_IFREG), let file = fileInfo(url) {
                    candidates.append((url, file.bytes, file.modified, file.inode, file.device))
                }
            }
        }
        if nextDirectory < directories.count { limited = true }

        let large = candidates.filter { $0.bytes >= 25_000_000 }
            .sorted { $0.bytes > $1.bytes }
            .prefix(200)
            .map { LargeFile(url: $0.url, bytes: $0.bytes, modified: $0.modified) }

        // Hash only equal-size files. Two hard links to one inode are one file,
        // and a partial hash or unreadable file never becomes a duplicate result.
        let bySize = Dictionary(grouping: candidates.filter { $0.bytes > 0 && $0.bytes <= 512_000_000 },
                                by: { $0.bytes })
        var duplicates: [DuplicateGroup] = []
        for (_, sameSize) in bySize where sameSize.count > 1 {
            var byDigest: [String: [(url: URL, inode: UInt64, device: UInt64)]] = [:]
            for file in sameSize {
                guard let digest = hash(file.url) else { continue }
                guard let after = fileInfo(file.url), after.bytes == file.bytes,
                      after.modified == file.modified, after.inode == file.inode,
                      after.device == file.device else { continue }
                byDigest[digest, default: []].append((file.url, file.inode, file.device))
            }
            for (digest, files) in byDigest {
                var seen = Set<String>()
                let distinct = files.filter { seen.insert("\($0.device):\($0.inode)").inserted }
                if distinct.count > 1 {
                    duplicates.append(DuplicateGroup(digest: digest,
                                                     files: distinct.map(\.url).sorted { $0.path < $1.path },
                                                     bytesPerFile: sameSize[0].bytes))
                }
            }
        }
        duplicates.sort { $0.reclaimableBytes > $1.reclaimableBytes }

        let appRoots = [URL(fileURLWithPath: "/Applications", isDirectory: true),
                        home.appendingPathComponent("Applications", isDirectory: true)]
        var apps: [InstalledApp] = []
        for root in appRoots {
            guard let urls = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for url in urls where url.pathExtension.lowercased() == "app" {
                guard let bundle = Bundle(url: url) else { continue }
                apps.append(InstalledApp(url: url,
                                         name: (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                                            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                                            ?? url.deletingPathExtension().lastPathComponent,
                                         version: (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "—",
                                         bundleID: bundle.bundleIdentifier ?? "—"))
            }
        }
        apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let disk = (try? home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]))
        let system = SystemSnapshot(capacity: Int64(disk?.volumeTotalCapacity ?? 0),
                                    available: Int64(disk?.volumeAvailableCapacity ?? 0),
                                    memory: ProcessInfo.processInfo.physicalMemory,
                                    processors: ProcessInfo.processInfo.activeProcessorCount)
        let security = SecuritySnapshot(
            fileVault: commandOutput("/usr/bin/fdesetup", ["status"]),
            gatekeeper: commandOutput("/usr/sbin/spctl", ["--status"]),
            systemIntegrity: commandOutput("/usr/bin/csrutil", ["status"])
        )
        return InsightReport(largeFiles: large, duplicates: duplicates, apps: apps,
                             system: system, security: security,
                             scannedFiles: candidates.count, limited: limited)
    }

    private func fileInfo(_ url: URL) -> (bytes: Int64, modified: Date, inode: UInt64, device: UInt64)? {
        var data = stat()
        guard url.path.withCString({ Darwin.lstat($0, &data) }) == 0,
              (data.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return nil }
        let seconds = TimeInterval(data.st_mtimespec.tv_sec)
        let nanos = TimeInterval(data.st_mtimespec.tv_nsec) / 1_000_000_000
        return (Int64(data.st_size), Date(timeIntervalSince1970: seconds + nanos),
                UInt64(data.st_ino), UInt64(data.st_dev))
    }

    private func hash(_ url: URL) -> String? {
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }
        var hasher = SHA256()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64 * 1024)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 64 * 1024)
            if count < 0 { return nil }
            if count == 0 { break }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: count))
        }
        guard stream.streamError == nil else { return nil }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func commandOutput(_ executable: String, _ arguments: [String]) -> String {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return "État indisponible" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? "État indisponible" : value
        } catch {
            return "État indisponible"
        }
    }
}
