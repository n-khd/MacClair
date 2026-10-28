import Foundation
import Darwin

enum CleanupCategory: String, CaseIterable, Identifiable, Sendable {
    case caches = "Caches utilisateur"
    case logs = "Journaux"
    case diskImages = "Images disque téléchargées"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .caches: "externaldrive"
        case .logs: "doc.text"
        case .diskImages: "opticaldiscdrive"
        }
    }
}

struct CleanupItem: Identifiable, Sendable {
    let id: URL
    let category: CleanupCategory
    let bytes: Int64
    let modified: Date
    let device: UInt64
    let inode: UInt64
    var selected = false

    var name: String { id.lastPathComponent }
    var canMoveToTrash: Bool { category == .diskImages }
}

struct ScanReport: Sendable {
    var items: [CleanupItem]
    var unreadablePaths: Int
    var stoppedAtLimit: Bool
}

enum CleanupError: LocalizedError {
    case outsideAllowedFolder
    case changedSinceScan
    case symbolicLink
    case protectedCategory

    var errorDescription: String? {
        switch self {
        case .outsideAllowedFolder: "Le fichier se trouve hors des dossiers autorisés."
        case .changedSinceScan: "Le fichier a changé depuis le scan. Relancez le scan."
        case .symbolicLink: "Les liens symboliques ne sont pas supprimés."
        case .protectedCategory: "Cette catégorie est consultable uniquement."
        }
    }
}

struct Cleaner: Sendable {
    let home: URL
    private let maximumItems = 20_000
    private let minimumAge: TimeInterval = 30 * 24 * 60 * 60

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home.standardizedFileURL
    }

    func scan() -> ScanReport {
        let fileManager = FileManager.default
        let roots: [(CleanupCategory, URL)] = [
            (.caches, home.appendingPathComponent("Library/Caches", isDirectory: true)),
            (.logs, home.appendingPathComponent("Library/Logs", isDirectory: true)),
            (.diskImages, home.appendingPathComponent("Downloads", isDirectory: true))
        ]
        var items: [CleanupItem] = []
        var unreadable = 0
        var capped = false
        let cutoff = Date().addingTimeInterval(-minimumAge)

        for (category, root) in roots {
            guard fileManager.fileExists(atPath: root.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsPackageDescendants, .skipsHiddenFiles],
                errorHandler: { _, _ in unreadable += 1; return true }
            ) else {
                unreadable += 1
                continue
            }
            for case let url as URL in enumerator {
                if items.count >= maximumItems { capped = true; break }
                guard let identity = Self.identity(at: url), identity.modified < cutoff else { continue }
                if category == .diskImages {
                    guard ["dmg", "iso", "pkg"].contains(url.pathExtension.lowercased()) else { continue }
                }
                items.append(CleanupItem(id: url, category: category,
                                         bytes: identity.bytes, modified: identity.modified,
                                         device: identity.device, inode: identity.inode))
            }
            if capped { break }
        }
        items.sort { $0.bytes > $1.bytes }
        return ScanReport(items: items, unreadablePaths: unreadable, stoppedAtLimit: capped)
    }

    func moveToTrash(_ item: CleanupItem) throws {
        guard item.canMoveToTrash else { throw CleanupError.protectedCategory }
        let root: URL = switch item.category {
        case .caches: home.appendingPathComponent("Library/Caches", isDirectory: true)
        case .logs: home.appendingPathComponent("Library/Logs", isDirectory: true)
        case .diskImages: home.appendingPathComponent("Downloads", isDirectory: true)
        }
        let resolvedHome = home.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        let resolvedItem = item.id.resolvingSymlinksInPath().standardizedFileURL.path
        guard resolvedRoot.hasPrefix(resolvedHome), resolvedItem.hasPrefix(resolvedRoot) else {
            throw CleanupError.outsideAllowedFolder
        }
        guard ["dmg", "iso", "pkg"].contains(item.id.pathExtension.lowercased()) else {
            throw CleanupError.protectedCategory
        }
        guard let current = Self.identity(at: item.id) else { throw CleanupError.symbolicLink }
        guard current.bytes == item.bytes, current.modified == item.modified,
              current.device == item.device, current.inode == item.inode else {
            throw CleanupError.changedSinceScan
        }
        let safe = SafeTrash(home: home)
        let candidate = try safe.capture(item.id)
        try safe.moveToTrash(candidate)
    }

    private static func identity(at url: URL) -> (bytes: Int64, modified: Date, device: UInt64, inode: UInt64)? {
        var info = stat()
        let status = url.path.withCString { Darwin.lstat($0, &info) }
        guard status == 0, (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return nil }
        let seconds = TimeInterval(info.st_mtimespec.tv_sec)
        let nanoseconds = TimeInterval(info.st_mtimespec.tv_nsec) / 1_000_000_000
        return (Int64(info.st_size), Date(timeIntervalSince1970: seconds + nanoseconds),
                UInt64(info.st_dev), UInt64(info.st_ino))
    }
}
