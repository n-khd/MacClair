import Foundation
import Darwin

/// Summary for one known local cache or Mail Downloads directory. No files are modified.
struct PrivacyAuditItem: Identifiable, Sendable {
    let name: String
    let url: URL
    let bytes: Int64
    let files: Int
    let unreadablePaths: Int
    let limited: Bool
    var id: URL { url }
}

struct PrivacyAuditReport: Sendable {
    let items: [PrivacyAuditItem]
    let missingLocations: Int
    let unreadablePaths: Int
    let visitedEntries: Int
    let limited: Bool
}

/// Bounded, read-only inventory of fixed locations in the current user's home.
/// Mail Downloads is only one location where Mail can keep downloaded attachments;
/// this does not enumerate the user's messages or all Mail attachments.
struct PrivacyAuditor: Sendable {
    let home: URL
    let entryLimit: Int

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, entryLimit: Int = 20_000) {
        self.home = home.standardizedFileURL
        self.entryLimit = max(1, entryLimit)
    }

    func scan() -> PrivacyAuditReport {
        let roots: [(String, String)] = [
            ("Cache Safari", "Library/Caches/com.apple.Safari"),
            ("Cache Chrome", "Library/Caches/Google/Chrome"),
            ("Cache Firefox", "Library/Caches/Firefox"),
            ("Téléchargements de Mail", "Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
            ("Téléchargements de Mail (ancien emplacement)", "Library/Mail Downloads")
        ]
        let fm = FileManager.default
        let homePath = home.resolvingSymlinksInPath().standardizedFileURL.path
        var results: [PrivacyAuditItem] = []
        var missing = 0
        var errors = 0
        var visited = 0
        var limited = false

        for (name, relativePath) in roots {
            if visited >= entryLimit { limited = true; break }
            let root = home.appendingPathComponent(relativePath, isDirectory: true).standardizedFileURL
            // Reject symlink roots and paths that resolve outside the user's home.
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
                // Saturate on overflow rather than wrapping to a misleading negative size.
                let (sum, overflow) = size.addingReportingOverflow(max(0, Int64(info.st_size)))
                size = overflow ? Int64.max : sum
            }
            errors += localErrors
            results.append(PrivacyAuditItem(name: name, url: root, bytes: size, files: files,
                                            unreadablePaths: localErrors, limited: rootLimited))
        }
        return PrivacyAuditReport(items: results, missingLocations: missing,
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
