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
    let unreadablePaths: Int
    let evictedFiles: Int
    let evictedBytes: Int64
}

/// Read-only, bounded traversal. Symbolic links and package contents are skipped.
/// Les fichiers iCloud « évincés » (non téléchargés) sont repérés pour ne pas
/// fausser la lecture des tailles.
struct StorageAuditor: Sendable {
    let root: URL
    let fileLimit: Int

    init(root: URL, fileLimit: Int = 20_000) {
        self.root = root.standardizedFileURL
        self.fileLimit = fileLimit
    }

    func scan() -> StorageAudit {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isPackageKey]) else {
            return StorageAudit(folders: [], hidden: [], scannedFiles: 0, limited: false, unreadablePaths: 1, evictedFiles: 0, evictedBytes: 0)
        }
        var results: [FolderSize] = []
        var hidden: [URL] = []
        var count = 0
        var unreadable = 0
        var evictedFiles = 0
        var evictedBytes: Int64 = 0
        for child in children where count < fileLimit {
            var bytes: Int64 = 0
            var files = 0
            // Treat a regular file directly; an enumerator for a file can exist but be empty.
            if let file = regularFile(child) {
                if child.lastPathComponent.hasPrefix("."), hidden.count < 100 { hidden.append(child) }
                bytes = file.bytes
                files = 1
                count += 1
                if file.evicted { evictedFiles += 1; evictedBytes = saturatingAdd(evictedBytes, file.logicalBytes) }
            } else {
                var info = stat()
                guard child.path.withCString({ Darwin.lstat($0, &info) }) == 0 else { unreadable += 1; continue }
                guard (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
                      (try? child.resourceValues(forKeys: [.isPackageKey]).isPackage) != true else { continue }
                guard let enumerator = fm.enumerator(at: child, includingPropertiesForKeys: nil,
                                                      options: [.skipsPackageDescendants],
                                                      errorHandler: { _, _ in unreadable += 1; return true }) else {
                    unreadable += 1; continue
                }
                for case let url as URL in enumerator {
                    if count >= fileLimit { break }
                    if let file = regularFile(url) {
                        if url.lastPathComponent.hasPrefix("."), hidden.count < 100 { hidden.append(url) }
                        bytes += file.bytes
                        files += 1
                        count += 1
                        if file.evicted { evictedFiles += 1; evictedBytes = saturatingAdd(evictedBytes, file.logicalBytes) }
                    }
                }
            }
            if files > 0 { results.append(FolderSize(url: child, bytes: bytes, files: files)) }
        }
        return StorageAudit(folders: results.sorted { $0.bytes > $1.bytes }, hidden: hidden,
                            scannedFiles: count, limited: count >= fileLimit, unreadablePaths: unreadable,
                            evictedFiles: evictedFiles, evictedBytes: evictedBytes)
    }

    /// Taille et état cloud d'un fichier ordinaire. `evicted` est vrai quand le
    /// fichier est un élément ubiquitaire dont les données ont été évincées
    /// localement ; `logicalBytes` porte alors la taille logique réelle.
    private func regularFile(_ url: URL) -> (bytes: Int64, evicted: Bool, logicalBytes: Int64)? {
        var value = stat()
        guard url.path.withCString({ Darwin.lstat($0, &value) }) == 0,
              (value.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return nil }
        let bytes = Int64(value.st_size)
        if value.st_blocks == 0 && bytes > 0, let cloud = ubiquitousInfo(url) {
            return (cloud.logicalBytes > 0 ? cloud.logicalBytes : bytes, cloud.evicted, cloud.logicalBytes)
        }
        return (bytes, false, bytes)
    }

    private func ubiquitousInfo(_ url: URL) -> (evicted: Bool, logicalBytes: Int64)? {
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey, .fileSizeKey]),
              values.isUbiquitousItem == true,
              let status = values.ubiquitousItemDownloadingStatus else { return nil }
        let evicted = status == .notDownloaded
        let logicalBytes = Int64(values.fileSize ?? 0)
        return (evicted, logicalBytes)
    }

    private func saturatingAdd(_ a: Int64, _ b: Int64) -> Int64 {
        let (sum, overflow) = a.addingReportingOverflow(b)
        return overflow ? Int64.max : sum
    }
}

struct StartupItem: Identifiable, Sendable {
    let url: URL
    let kind: String
    let broken: Bool
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
                .map { StartupItem(url: $0, kind: kind, broken: isBroken($0)) }
        }.sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
    }

    /// Un élément est « cassé » quand son plist désigne un exécutable introuvable.
    private func isBroken(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else { return false }
        let program: String?
        if let path = dict["Program"] as? String {
            program = path
        } else if let arguments = dict["ProgramArguments"] as? [String], let first = arguments.first {
            program = first
        } else {
            return false
        }
        guard let program else { return false }
        if program.hasPrefix("/") { return !FileManager.default.fileExists(atPath: program) }
        // Chemin relatif : introuvable sans résolution du PATH, on ne le marque pas cassé.
        return false
    }
}
