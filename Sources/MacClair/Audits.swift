import Foundation
import Darwin

struct FolderSize: Identifiable, Sendable {
    let url: URL
    let bytes: Int64
    let files: Int
    var id: URL { url }
}

struct StorageAudit: Sendable {
    let folders: [FolderSize]
    let hidden: [URL]
    let scannedFiles: Int
    let limited: Bool
}

/// Read-only, bounded traversal. Symbolic links and package contents are skipped.
struct StorageAuditor: Sendable {
    let root: URL
    let fileLimit: Int

    init(root: URL, fileLimit: Int = 20_000) {
        self.root = root.standardizedFileURL
        self.fileLimit = fileLimit
    }

    func scan() -> StorageAudit {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return StorageAudit(folders: [], hidden: [], scannedFiles: 0, limited: false)
        }
        var results: [FolderSize] = []
        var hidden: [URL] = []
        var count = 0
        for child in children where count < fileLimit {
            var bytes: Int64 = 0
            var files = 0
            if let enumerator = fm.enumerator(at: child, includingPropertiesForKeys: nil,
                                              options: [.skipsPackageDescendants],
                                              errorHandler: { _, _ in true }) {
                for case let url as URL in enumerator {
                    if count >= fileLimit { break }
                    if let size = regularFileSize(url) {
                        if url.lastPathComponent.hasPrefix("."), hidden.count < 100 { hidden.append(url) }
                        bytes += size
                        files += 1
                        count += 1
                    }
                }
            } else if let size = regularFileSize(child) {
                if child.lastPathComponent.hasPrefix("."), hidden.count < 100 { hidden.append(child) }
                bytes = size
                files = 1
                count += 1
            }
            if files > 0 { results.append(FolderSize(url: child, bytes: bytes, files: files)) }
        }
        return StorageAudit(folders: results.sorted { $0.bytes > $1.bytes }, hidden: hidden,
                            scannedFiles: count, limited: count >= fileLimit)
    }

    private func regularFileSize(_ url: URL) -> Int64? {
        var value = stat()
        guard url.path.withCString({ Darwin.lstat($0, &value) }) == 0,
              (value.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return nil }
        return Int64(value.st_size)
    }
}

struct StartupItem: Identifiable, Sendable {
    let url: URL
    let kind: String
    var id: URL { url }
}

struct StartupAuditor: Sendable {
    let home: URL

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) { self.home = home }

    func scan() -> [StartupItem] {
        let roots: [(URL, String)] = [
            (home.appendingPathComponent("Library/LaunchAgents"), "Agent utilisateur"),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), "Agent partagé"),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), "Service partagé")
        ]
        return roots.flatMap { root, kind in
            ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension.lowercased() == "plist" }
                .map { StartupItem(url: $0, kind: kind) }
        }.sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
    }
}
