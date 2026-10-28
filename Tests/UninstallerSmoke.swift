import Foundation

@main
struct UninstallerSmoke {
    static func main() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("macclair-uninstall-\(UUID().uuidString)")
        let trash = fm.temporaryDirectory.appendingPathComponent("macclair-trash-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home); try? fm.removeItem(at: trash) }

        let app = home.appendingPathComponent("Applications/Fake.app")
        let contents = app.appendingPathComponent("Contents")
        try fm.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 10).write(to: contents.appendingPathComponent("MacOS/Fake"))
        let plist: [String: Any] = ["CFBundleIdentifier": "com.example.fake",
                                    "CFBundleName": "Fake",
                                    "CFBundleExecutable": "Fake"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))

        let cache = home.appendingPathComponent("Library/Caches/com.example.fake")
        let support = home.appendingPathComponent("Library/Application Support/com.example.fake")
        let prefsDir = home.appendingPathComponent("Library/Preferences")
        let prefs = prefsDir.appendingPathComponent("com.example.fake.plist")
        try fm.createDirectory(at: cache, withIntermediateDirectories: true)
        try fm.createDirectory(at: support, withIntermediateDirectories: true)
        try fm.createDirectory(at: prefsDir, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 40).write(to: cache.appendingPathComponent("entry"))
        try Data(repeating: 3, count: 60).write(to: support.appendingPathComponent("data.bin"))
        try Data(repeating: 4, count: 5).write(to: prefs)

        let plan = UninstallerPlanner(home: home).plan(appURL: app)
        let kinds = Set(plan.items.map(\.kind))
        precondition(kinds.contains("Application"))
        precondition(kinds.contains("Caches"))
        precondition(kinds.contains("Données d’application"))
        precondition(kinds.contains("Préférences"))
        precondition(plan.items.contains { $0.url.path == cache.path })
        precondition(plan.totalBytes >= 10 + 40 + 60 + 5)

        // Emplacements autorisés / interdits.
        precondition(AppUninstaller.isAllowed(cache, home: home))
        precondition(AppUninstaller.isAllowed(app, home: home))
        precondition(!AppUninstaller.isAllowed(URL(fileURLWithPath: "/usr/bin/true"), home: home))
        precondition(!AppUninstaller.isAllowed(URL(fileURLWithPath: "/System/Library"), home: home))
        let link = home.appendingPathComponent("Library/Caches/link")
        try fm.createSymbolicLink(at: link, withDestinationURL: cache)
        precondition(!AppUninstaller.isAllowed(link, home: home))

        // Déplacement vers une corbeille factice : isolé et vérifiable.
        let result = AppUninstaller(home: home, trashDirectory: trash).moveToTrash(plan.items.map(\.url))
        precondition(result.moved == plan.items.count)
        precondition(result.failures.isEmpty)
        precondition(result.freed >= plan.totalBytes)
        precondition(!fm.fileExists(atPath: app.path))
        precondition(!fm.fileExists(atPath: cache.path))
        let trashed = (try? fm.contentsOfDirectory(atPath: trash.path)) ?? []
        precondition(trashed.count == plan.items.count)
        print("UninstallerSmoke OK: résidus par bundle, emplacements autorisés et corbeille isolée")
    }
}
