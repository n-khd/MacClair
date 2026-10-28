import Foundation
import Darwin

struct TrashCandidate: Identifiable, Sendable {
    let url: URL
    let bytes: Int64
    let modifiedSeconds: Int64
    let modifiedNanoseconds: Int64
    let device: UInt64
    let inode: UInt64
    var id: URL { url }
}

struct DuplicateTrashPlan: Sendable {
    let selected: [URL: TrashCandidate]
    let keepers: Set<URL>
    let groupsPrepared: Int
    let protectedFiles: Int
    let groupsSkipped: Int
}

enum TrashError: LocalizedError {
    case outsideDownloads
    case notRegularFile
    case changed
    case lastDuplicate
    case protectedPath

    var errorDescription: String? {
        switch self {
        case .outsideDownloads: "Seuls les fichiers de Téléchargements peuvent être déplacés."
        case .notRegularFile: "Ce fichier n’est pas un fichier ordinaire."
        case .changed: "Ce fichier a changé depuis sa sélection. Relancez l’analyse."
        case .lastDuplicate: "Une copie doit rester dans chaque groupe de doublons."
        case .protectedPath: "Les fichiers internes de projets, de paquets et les dossiers cachés sont protégés."
        }
    }
}

/// Moves only explicitly chosen regular files under the current user's Downloads.
struct SafeTrash: Sendable {
    let home: URL

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home.standardizedFileURL
    }

    func capture(_ url: URL) throws -> TrashCandidate {
        try checkLocation(url)
        guard let info = identity(url) else { throw TrashError.notRegularFile }
        return TrashCandidate(url: url, bytes: Int64(info.st_size),
                              modifiedSeconds: Int64(info.st_mtimespec.tv_sec),
                              modifiedNanoseconds: Int64(info.st_mtimespec.tv_nsec),
                              device: UInt64(info.st_dev), inode: UInt64(info.st_ino))
    }

    func validate(_ candidate: TrashCandidate) throws {
        try checkLocation(candidate.url)
        guard let info = identity(candidate.url) else { throw TrashError.notRegularFile }
        guard Int64(info.st_size) == candidate.bytes,
              Int64(info.st_mtimespec.tv_sec) == candidate.modifiedSeconds,
              Int64(info.st_mtimespec.tv_nsec) == candidate.modifiedNanoseconds,
              UInt64(info.st_dev) == candidate.device,
              UInt64(info.st_ino) == candidate.inode else { throw TrashError.changed }
    }

    func moveToTrash(_ candidate: TrashCandidate) throws {
        try validate(candidate)
        try FileManager.default.trashItem(at: candidate.url, resultingItemURL: nil)
    }

    func validateDuplicateSelection(_ selected: Set<URL>, groups: [[URL]]) throws {
        for group in groups where !group.isEmpty {
            if group.allSatisfy({ selected.contains($0) }) { throw TrashError.lastDuplicate }
        }
    }

    /// Preselects all eligible extra copies. One file in every group stays unchecked.
    func planRedundantDuplicates(groups: [[URL]], includeProjectAndOtherFolders: Bool = false) -> DuplicateTrashPlan {
        var selected: [URL: TrashCandidate] = [:]
        var keepers = Set<URL>()
        var groupsPrepared = 0
        var protectedFiles = 0
        var groupsSkipped = 0
        for group in groups {
            let unique = Array(Set(group)).sorted { $0.path < $1.path }
            guard unique.count > 1 else { continue }
            if !includeProjectAndOtherFolders {
                let parents = Set(unique.map { $0.deletingLastPathComponent().standardizedFileURL.path })
                if parents.count > 1 || unique.contains(where: isLikelyProjectFile) {
                    groupsSkipped += 1
                    continue
                }
            }
            var eligible: [TrashCandidate] = []
            var protected: [URL] = []
            for url in unique {
                if let candidate = try? capture(url) { eligible.append(candidate) }
                else { protected.append(url); protectedFiles += 1 }
            }
            let keeper: URL
            if let firstProtected = protected.first {
                keeper = firstProtected
            } else if let oldest = eligible.min(by: { left, right in
                if left.modifiedSeconds != right.modifiedSeconds {
                    return left.modifiedSeconds < right.modifiedSeconds
                }
                if left.modifiedNanoseconds != right.modifiedNanoseconds {
                    return left.modifiedNanoseconds < right.modifiedNanoseconds
                }
                return left.url.path < right.url.path
            }) {
                keeper = oldest.url
            } else { continue }
            keepers.insert(keeper)
            let extras = eligible.filter { $0.url != keeper }
            if !extras.isEmpty { groupsPrepared += 1 }
            for candidate in extras { selected[candidate.url] = candidate }
        }
        return DuplicateTrashPlan(selected: selected, keepers: keepers,
                                  groupsPrepared: groupsPrepared, protectedFiles: protectedFiles,
                                  groupsSkipped: groupsSkipped)
    }

    private func isLikelyProjectFile(_ url: URL) -> Bool {
        let fm = FileManager.default
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true).standardizedFileURL.path
        var directory = url.deletingLastPathComponent().standardizedFileURL
        while directory.path.hasPrefix(downloads + "/") {
            for marker in [".git", ".hg", ".svn", "Package.swift", "package.json", "*.xcodeproj"] {
                if marker == "*.xcodeproj" {
                    if let children = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil),
                       children.contains(where: { $0.pathExtension == "xcodeproj" }) { return true }
                } else if fm.fileExists(atPath: directory.appendingPathComponent(marker).path) {
                    return true
                }
            }
            directory.deleteLastPathComponent()
        }
        return false
    }

    private func checkLocation(_ url: URL) throws {
        let download = home.appendingPathComponent("Downloads", isDirectory: true)
        let homePath = home.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPath = download.resolvingSymlinksInPath().standardizedFileURL.path
        let filePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard rootPath.hasPrefix(homePath + "/"),
              filePath.hasPrefix(rootPath + "/"),
              url.standardizedFileURL.path.hasPrefix(download.standardizedFileURL.path + "/") else {
            throw TrashError.outsideDownloads
        }
        let relative = String(url.standardizedFileURL.path.dropFirst(download.standardizedFileURL.path.count + 1))
        let components = relative.split(separator: "/").map(String.init)
        let protectedNames: Set<String> = ["node_modules", "Pods", "DerivedData", "venv"]
        let protectedExtensions: Set<String> = ["app", "bundle", "framework", "xcassets", "xcodeproj", "xcworkspace"]
        guard !components.contains(where: { $0.hasPrefix(".") || protectedNames.contains($0) ||
            protectedExtensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) }) else {
            throw TrashError.protectedPath
        }
    }

    private func identity(_ url: URL) -> stat? {
        var info = stat()
        guard url.path.withCString({ Darwin.lstat($0, &info) }) == 0,
              (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return nil }
        return info
    }
}
