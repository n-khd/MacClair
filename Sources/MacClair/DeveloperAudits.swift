import Foundation
import Darwin

/// Inventaire en lecture seule des caches de développement (Xcode) et des
/// sauvegardes d'appareils iOS. Ces emplacements peuvent occuper plusieurs
/// gigaoctets sans être visibles dans le balayage classique des caches.
struct DeveloperJunkItem: Identifiable, Sendable {
    let name: String
    let url: URL
    let bytes: Int64
    let files: Int
    let unreadablePaths: Int
    let limited: Bool
    var id: URL { url }
}

struct DeveloperJunkReport: Sendable {
    let items: [DeveloperJunkItem]
    let missingLocations: Int
    let unreadablePaths: Int
    let visitedEntries: Int
    let limited: Bool
}

struct DeveloperJunkAuditor: Sendable {
    let home: URL
    let entryLimit: Int

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, entryLimit: Int = 50_000) {
        self.home = home.standardizedFileURL
        self.entryLimit = max(1, entryLimit)
    }

    func scan() -> DeveloperJunkReport {
        let roots: [(String, String)] = [
            ("Données dérivées Xcode", "Library/Developer/Xcode/DerivedData"),
            ("Archives Xcode", "Library/Developer/Xcode/Archives"),
            ("Device Support iOS", "Library/Developer/Xcode/iOS DeviceSupport"),
            ("Device Support watchOS", "Library/Developer/Xcode/watchOS DeviceSupport"),
            ("Device Support tvOS", "Library/Developer/Xcode/tvOS DeviceSupport"),
            ("Caches CoreSimulator", "Library/Developer/CoreSimulator/Caches"),
            ("Simulateurs iOS", "Library/Developer/CoreSimulator/Devices"),
            ("Sauvegardes d’appareils iOS", "Library/Application Support/MobileSync/Backup")
        ]
        let fm = FileManager.default
        let homePath = home.resolvingSymlinksInPath().standardizedFileURL.path
        var results: [DeveloperJunkItem] = []
        var missing = 0
        var errors = 0
        var visited = 0
        var limited = false

        for (name, relativePath) in roots {
            if visited >= entryLimit { limited = true; break }
            let root = home.appendingPathComponent(relativePath, isDirectory: true).standardizedFileURL
            let resolvedPath = root.resolvingSymlinksInPath().standardizedFileURL.path
            guard resolvedPath.hasPrefix(homePath + "/"), !hasSymlink(relativePath) else { errors += 1; continue }
            var rootStat = stat()
            let status = root.path.withCString { Darwin.lstat($0, &rootStat) }
            if status != 0 {
                if errno == ENOENT || errno == ENOTDIR { missing += 1 } else { errors += 1 }
                continue
            }
            guard (rootStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) else { errors += 1; continue }

            var localErrors = 0
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil,
                                                 options: [.skipsPackageDescendants],
                                                 errorHandler: { _, _ in localErrors += 1; return true }) else {
                errors += 1
                continue
            }
            var size: Int64 = 0
            var files = 0
            var rootLimited = false
            for case let url as URL in enumerator {
                if visited >= entryLimit { rootLimited = true; limited = true; break }
                visited += 1
                var info = stat()
                guard url.path.withCString({ Darwin.lstat($0, &info) }) == 0 else {
                    localErrors += 1
                    continue
                }
                guard (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { continue }
                files += 1
                let (sum, overflow) = size.addingReportingOverflow(max(0, Int64(info.st_size)))
                size = overflow ? Int64.max : sum
            }
            errors += localErrors
            results.append(DeveloperJunkItem(name: name, url: root, bytes: size, files: files,
                                             unreadablePaths: localErrors, limited: rootLimited))
        }
        results.sort { $0.bytes > $1.bytes }
        return DeveloperJunkReport(items: results, missingLocations: missing,
                                   unreadablePaths: errors, visitedEntries: visited, limited: limited)
    }

    private func hasSymlink(_ relativePath: String) -> Bool {
        var path = home
        for component in relativePath.split(separator: "/") {
            path.appendPathComponent(String(component))
            var info = stat()
            guard path.path.withCString({ Darwin.lstat($0, &info) }) == 0 else { return false }
            if (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFLNK) { return true }
        }
        return false
    }
}
