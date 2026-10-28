import Foundation
import Darwin

/// Un élément lié à une application : le paquet lui-même ou un résidu utilisateur.
struct AppResidue: Identifiable, Sendable {
    let url: URL
    let kind: String
    let bytes: Int64
    var id: URL { url }
}

/// Plan de désinstallation : l'application et les résidus trouvés pour son
/// identifiant de bundle. Rien n'est déplacé tant que l'utilisateur ne confirme pas.
struct AppUninstallPlan: Sendable {
    let app: URL
    let items: [AppResidue]
    let totalBytes: Int64
    var appName: String { app.deletingPathExtension().lastPathComponent }
}

enum UninstallError: LocalizedError {
    case notAllowed
    var errorDescription: String? {
        switch self {
        case .notAllowed: "Cet élément est hors des emplacements autorisés ou est un lien symbolique."
        }
    }
}

/// Construit un plan de résidus pour une application installée. Les résidus sont
/// recherchés par identifiant de bundle exact dans les dossiers utilisateur
/// connus, ce qui évite d'associer par erreur des données sans rapport.
struct UninstallerPlanner: Sendable {
    let home: URL

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home.standardizedFileURL
    }

    func plan(appURL: URL) -> AppUninstallPlan {
        var items: [AppResidue] = []
        let appBytes = Self.entrySize(appURL)
        items.append(AppResidue(url: appURL, kind: "Application", bytes: appBytes))

        let bundleID = Bundle(url: appURL)?.bundleIdentifier
        if let id = bundleID, Self.isValidBundleID(id) {
            let library = home.appendingPathComponent("Library", isDirectory: true)
            let candidates: [(String, URL, String)] = [
                ("Données d’application", library.appendingPathComponent("Application Support"), id),
                ("Caches", library.appendingPathComponent("Caches"), id),
                ("Préférences", library.appendingPathComponent("Preferences"), id + ".plist"),
                ("Journaux", library.appendingPathComponent("Logs"), id),
                ("Conteneur", library.appendingPathComponent("Containers"), id),
                ("État enregistré", library.appendingPathComponent("Saved Application State"), id + ".savedState"),
                ("Données Web", library.appendingPathComponent("WebKit"), id),
                ("Stockage HTTP", library.appendingPathComponent("HTTPStorages"), id),
                ("Agent de lancement", library.appendingPathComponent("LaunchAgents"), id + ".plist"),
                ("Scripts d’application", library.appendingPathComponent("Application Scripts"), id)
            ]
            var seen = Set<String>()
            for (kind, parent, name) in candidates {
                let std = parent.appendingPathComponent(name).standardizedFileURL
                // Le dossier parent résolu doit être exactement celui attendu : un identifiant
                // contenant « ../ » ne peut donc pas sortir de son dossier.
                guard std.deletingLastPathComponent().standardizedFileURL.path
                    == parent.standardizedFileURL.path else { continue }
                guard !seen.contains(std.path) else { continue }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: std.path, isDirectory: &isDir) else { continue }
                seen.insert(std.path)
                items.append(AppResidue(url: std, kind: kind, bytes: Self.entrySize(std)))
            }
        }
        let total = items.reduce(Int64(0)) { $0 + $1.bytes }
        return AppUninstallPlan(app: appURL, items: items, totalBytes: total)
    }

    /// Un identifiant de bundle sert à construire des chemins sous `~/Library` : il ne doit
    /// contenir que des caractères sûrs, sans barre oblique ni composant `..`.
    static func isValidBundleID(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 155 else { return false }
        guard !id.hasPrefix("."), !id.hasSuffix("."), !id.contains("..") else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        return id.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Taille bornée d'un fichier ou d'un dossier (somme des fichiers réguliers).
    static func entrySize(_ url: URL, entryCap: Int = 200_000) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            var st = stat()
            guard url.path.withCString({ Darwin.lstat($0, &st) }) == 0,
                  (st.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return 0 }
            return Int64(st.st_size)
        }
        var total: Int64 = 0
        var entries = 0
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                                              options: [], errorHandler: { _, _ in true }) else { return 0 }
        for case let file as URL in enumerator {
            entries += 1
            if entries > entryCap { return Int64.max }
            if let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               values.isRegularFile == true {
                let (sum, overflow) = total.addingReportingOverflow(Int64(values.fileSize ?? 0))
                total = overflow ? Int64.max : sum
            }
        }
        return total
    }
}

/// Déplace vers la Corbeille uniquement des éléments situés dans les dossiers
/// autorisés (données utilisateur, `/Applications`, `~/Applications`), jamais un
/// lien symbolique. `trashDirectory` sert aux tests pour éviter la Corbeille réelle.
struct AppUninstaller: Sendable {
    let home: URL
    let trashDirectory: URL?

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, trashDirectory: URL? = nil) {
        self.home = home.standardizedFileURL
        self.trashDirectory = trashDirectory
    }

    static func isAllowed(_ url: URL, home: URL) -> Bool {
        let std = url.standardizedFileURL
        var st = stat()
        guard std.path.withCString({ Darwin.lstat($0, &st) }) == 0 else { return false }
        // Refuse les liens symboliques eux-mêmes.
        if (st.st_mode & mode_t(S_IFMT)) == mode_t(S_IFLNK) { return false }
        let homePath = home.resolvingSymlinksInPath().standardizedFileURL.path
        let path = std.resolvingSymlinksInPath().standardizedFileURL.path
        // Jamais de zone système.
        for forbidden in ["/System/", "/Library/", "/usr/", "/bin/", "/sbin/", "/private/"] where path.hasPrefix(forbidden) {
            return false
        }
        // Zones sensibles de la maison : même sous ~/Library, on n'y touche pas.
        let sensitive = ["/Library/Keychains/", "/Library/Messages/", "/Library/Mail/",
                         "/Library/Safari/", "/Library/Cookies/", "/Library/Accounts/",
                         "/Library/IdentityServices/", "/Library/Autosave Information/"]
        for blocked in sensitive where path.hasPrefix(homePath + blocked) {
            return false
        }
        return path.hasPrefix(homePath + "/Library/")
            || path.hasPrefix("/Applications/")
            || path.hasPrefix(homePath + "/Applications/")
    }

    func moveToTrash(_ urls: [URL]) -> (moved: Int, freed: Int64, failures: [String]) {
        var moved = 0
        var freed: Int64 = 0
        var failures: [String] = []
        for url in urls {
            do {
                guard Self.isAllowed(url, home: home) else { throw UninstallError.notAllowed }
                let size = UninstallerPlanner.entrySize(url)
                if let trashDirectory {
                    try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
                    let destination = trashDirectory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
                    try FileManager.default.moveItem(at: url, to: destination)
                } else {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                }
                moved += 1
                freed += size
            } catch {
                failures.append("\(url.lastPathComponent) : \(error.localizedDescription)")
            }
        }
        return (moved, freed, failures)
    }
}
