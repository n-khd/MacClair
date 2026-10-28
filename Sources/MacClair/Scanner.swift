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
    /// Caches, journaux et installateurs peuvent être déplacés vers la Corbeille ;
    /// le déplacement reste réversible et revérifie l'identité du fichier.
    var canMoveToTrash: Bool { true }
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
    private let maximumItemsPerCategory: Int
    private let minimumAge: TimeInterval = 30 * 24 * 60 * 60
    private let minimumBytes: Int64

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
         maximumItemsPerCategory: Int = 20_000,
         minimumBytes: Int64 = 1) {
        self.home = home.standardizedFileURL
        self.maximumItemsPerCategory = max(1, maximumItemsPerCategory)
        self.minimumBytes = max(0, minimumBytes)
    }

    func scan(progress: (@Sendable (String, Int) -> Void)? = nil) -> ScanReport {
        let fileManager = FileManager.default
        let roots: [(CleanupCategory, URL)] = [
            (.caches, home.appendingPathComponent("Library/Caches", isDirectory: true)),
            (.logs, home.appendingPathComponent("Library/Logs", isDirectory: true)),
            (.diskImages, home.appendingPathComponent("Downloads", isDirectory: true))
        ]
        var items: [CleanupItem] = []
        var unreadable = 0
        var capped = false
        var visited = 0
        let cutoff = Date().addingTimeInterval(-minimumAge)
        let mounted = Self.mountedDiskImagePaths()

        for (category, root) in roots {
            var categoryItems = 0
            progress?(category.rawValue, visited)
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
                visited += 1
                if visited % 200 == 0 { progress?(category.rawValue, visited) }
                guard let identity = Self.identity(at: url), identity.modified < cutoff else { continue }
                if category == .diskImages {
                    guard ["dmg", "iso", "pkg"].contains(url.pathExtension.lowercased()) else { continue }
                    // Une image disque actuellement montée ne doit pas être proposée.
                    if mounted.contains(url.resolvingSymlinksInPath().standardizedFileURL.path) { continue }
                } else if identity.bytes < minimumBytes {
                    continue
                }
                if categoryItems >= maximumItemsPerCategory { capped = true; break }
                categoryItems += 1
                items.append(CleanupItem(id: url, category: category,
                                         bytes: identity.bytes, modified: identity.modified,
                                         device: identity.device, inode: identity.inode))
            }
        }
        items.sort { $0.bytes > $1.bytes }
        return ScanReport(items: items, unreadablePaths: unreadable, stoppedAtLimit: capped)
    }

    /// Chemins normalisés des images disque actuellement attachées, d'après
    /// `hdiutil info -plist`. Renvoie un ensemble vide en cas d'échec.
    private static func mountedDiskImagePaths() -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["info", "-plist"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let top = plist as? [String: Any],
                  let images = top["images"] as? [[String: Any]] else { return [] }
            var paths = Set<String>()
            for image in images {
                if let path = image["image-path"] as? String, !path.isEmpty {
                    paths.insert(URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path)
                }
            }
            return paths
        } catch {
            return []
        }
    }

    func moveToTrash(_ item: CleanupItem) throws {
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
        if item.category == .diskImages {
            guard ["dmg", "iso", "pkg"].contains(item.id.pathExtension.lowercased()) else {
                throw CleanupError.protectedCategory
            }
            if Self.mountedDiskImagePaths().contains(item.id.resolvingSymlinksInPath().standardizedFileURL.path) {
                throw CleanupError.protectedCategory
            }
        }
        guard let current = Self.identity(at: item.id) else { throw CleanupError.symbolicLink }
        guard current.bytes == item.bytes, current.modified == item.modified,
              current.device == item.device, current.inode == item.inode else {
            throw CleanupError.changedSinceScan
        }
        if item.category == .diskImages {
            // Les téléchargements restent soumis aux protections de SafeTrash
            // (paquets, dossiers de projets, éléments cachés).
            let safe = SafeTrash(home: home)
            let candidate = try safe.capture(item.id)
            try safe.moveToTrash(candidate)
        } else {
            // Caches et journaux : la revérification d'identité et de confinement
            // ci-dessus suffit ; on déplace le fichier ordinaire vers la Corbeille.
            try FileManager.default.trashItem(at: item.id, resultingItemURL: nil)
        }
    }

    /// Déplace une sélection vers la Corbeille et renvoie l'espace libéré.
    /// Une erreur sur un élément n'interrompt pas les suivants.
    func moveToTrash(_ items: [CleanupItem],
                     progress: (@Sendable (Int, Int) -> Void)? = nil) -> (moved: [URL], freed: Int64, failures: [String]) {
        var moved: [URL] = []
        var freed: Int64 = 0
        var failures: [String] = []
        let total = items.count
        for (index, item) in items.enumerated() {
            do {
                try moveToTrash(item)
                moved.append(item.id)
                freed += item.bytes
            } catch {
                failures.append("\(item.name) : \(error.localizedDescription)")
            }
            progress?(index + 1, total)
        }
        return (moved, freed, failures)
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
