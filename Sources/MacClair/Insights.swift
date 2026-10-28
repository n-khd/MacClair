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
    let unreadablePaths: Int
    let limited: Bool
}

struct InsightScanner: Sendable {
    let home: URL
    let scanRoot: URL

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, scanRoot: URL? = nil) {
        self.home = home.standardizedFileURL
        self.scanRoot = (scanRoot ?? home.appendingPathComponent("Downloads", isDirectory: true)).standardizedFileURL
    }

    func scan(progress: (@Sendable (String, Int) -> Void)? = nil) -> InsightReport {
        let fm = FileManager.default
        var candidates: [(url: URL, bytes: Int64, modified: Date, inode: UInt64, device: UInt64, seconds: Int64, nanos: Int64)] = []
        var limited = false
        var unreadable = 0
        var directories = [scanRoot]
        progress?("Parcours des fichiers", 0)
        var nextDirectory = 0
        var visitedEntries = 0
        while nextDirectory < directories.count && candidates.count < 10_000 && visitedEntries < 80_000 {
            let directory = directories[nextDirectory]
            nextDirectory += 1
            guard let urls = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isPackageKey]) else { unreadable += 1; continue }
            for url in urls {
                visitedEntries += 1
                if visitedEntries % 200 == 0 { progress?("Parcours des fichiers", visitedEntries) }
                if candidates.count >= 10_000 || visitedEntries >= 80_000 { limited = true; break }
                if url.lastPathComponent.hasPrefix(".") { continue }
                var info = stat()
                guard url.path.withCString({ Darwin.lstat($0, &info) }) == 0 else { unreadable += 1; continue }
                let type = info.st_mode & mode_t(S_IFMT)
                if type == mode_t(S_IFDIR) {
                    if (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) != true,
                       !["node_modules", "Pods", "DerivedData", "venv"].contains(url.lastPathComponent),
                       !["app", "bundle", "framework", "xcassets", "xcodeproj", "xcworkspace"].contains(url.pathExtension.lowercased()) {
                        directories.append(url)
                    }
                } else if type == mode_t(S_IFREG), let file = fileInfo(url) {
                    candidates.append((url, file.bytes, file.modified, file.inode, file.device, file.seconds, file.nanos))
                }
            }
        }
        if nextDirectory < directories.count { limited = true }

        let large = candidates.filter { $0.bytes >= 25_000_000 }
            .sorted { $0.bytes > $1.bytes }
            .prefix(200)
            .map { LargeFile(url: $0.url, bytes: $0.bytes, modified: $0.modified) }

        // Equal-size files are first compared by a bounded sample. Only matching
        // samples are read in full; the full SHA-256 is the duplicate criterion.
        // A short read, changed identity or unreadable file never yields a match.
        let bySize = Dictionary(grouping: candidates, by: { $0.bytes })
        var duplicates: [DuplicateGroup] = []
        var hashed = 0
        progress?("Comparaison des doublons", hashed)
        for (_, sameSize) in bySize where sameSize.count > 1 {
            var bySample: [String: [(url: URL, bytes: Int64, modified: Date, inode: UInt64, device: UInt64, seconds: Int64, nanos: Int64)]] = [:]
            for file in sameSize {
                let sample: String
                if file.bytes > 128 * 1024 {
                    guard let value = sampleHash(file.url, bytes: file.bytes),
                          let after = fileInfo(file.url),
                          after.bytes == file.bytes, after.inode == file.inode, after.device == file.device,
                          after.seconds == file.seconds, after.nanos == file.nanos else { unreadable += 1; continue }
                    sample = value
                } else {
                    sample = "small"
                }
                bySample[sample, default: []].append(file)
            }
            for sampleFiles in bySample.values where sampleFiles.count > 1 {
                // Hard links alone do not represent independent copies.
                let identities = Set(sampleFiles.map { "\($0.device):\($0.inode)" })
                if identities.count < 2 { continue }
                var byDigest: [String: [(url: URL, inode: UInt64, device: UInt64)]] = [:]
                for file in sampleFiles {
                    hashed += 1
                    progress?("Comparaison des doublons", hashed)
                    guard let digest = hash(file.url, expectedBytes: file.bytes),
                          let after = fileInfo(file.url), after.bytes == file.bytes,
                          after.seconds == file.seconds, after.nanos == file.nanos,
                          after.inode == file.inode, after.device == file.device else { unreadable += 1; continue }
                    byDigest[digest, default: []].append((file.url, file.inode, file.device))
                }
                for (digest, files) in byDigest {
                    var seen = Set<String>()
                    let distinct = files.filter { seen.insert("\($0.device):\($0.inode)").inserted }
                    if distinct.count > 1 {
                        duplicates.append(DuplicateGroup(digest: digest,
                                                         files: distinct.map(\.url).sorted { $0.path < $1.path },
                                                         bytesPerFile: sampleFiles[0].bytes))
                    }
                }
            }
        }
        duplicates.sort { $0.reclaimableBytes > $1.reclaimableBytes }

        progress?("Inventaire des applications et protections", candidates.count)
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
                             scannedFiles: candidates.count, unreadablePaths: unreadable, limited: limited)
    }

    private func fileInfo(_ url: URL) -> (bytes: Int64, modified: Date, inode: UInt64, device: UInt64, seconds: Int64, nanos: Int64)? {
        var data = stat()
        guard url.path.withCString({ Darwin.lstat($0, &data) }) == 0,
              (data.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return nil }
        let seconds = TimeInterval(data.st_mtimespec.tv_sec)
        let nanos = TimeInterval(data.st_mtimespec.tv_nsec) / 1_000_000_000
        return (Int64(data.st_size), Date(timeIntervalSince1970: seconds + nanos),
                UInt64(data.st_ino), UInt64(data.st_dev), Int64(data.st_mtimespec.tv_sec), Int64(data.st_mtimespec.tv_nsec))
    }

    private func sampleHash(_ url: URL, bytes: Int64) -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let sampleSize = 64 * 1024
            guard let first = try handle.read(upToCount: sampleSize), first.count == sampleSize else { return nil }
            try handle.seek(toOffset: UInt64(bytes - Int64(sampleSize)))
            guard let last = try handle.read(upToCount: sampleSize), last.count == sampleSize else { return nil }
            var hasher = SHA256()
            hasher.update(data: first)
            hasher.update(data: last)
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        } catch { return nil }
    }

    private func hash(_ url: URL, expectedBytes: Int64) -> String? {
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }
        var hasher = SHA256()
        var total: Int64 = 0
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64 * 1024)
        defer { buffer.deallocate() }
        while true {
            let count = stream.read(buffer, maxLength: 64 * 1024)
            if count < 0 { return nil }
            if count == 0 { break }
            total += Int64(count)
            guard total <= expectedBytes else { return nil }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: count))
        }
        guard stream.streamError == nil, total == expectedBytes else { return nil }
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
