import Foundation

@main
struct DeveloperAuditsSmoke {
    static func main() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("macclair-dev-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home) }
        let derivedRoot = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        let backupRoot = home.appendingPathComponent("Library/Application Support/MobileSync/Backup")
        let derived = derivedRoot.appendingPathComponent("App-xyz/Build")
        let backups = backupRoot.appendingPathComponent("device1")
        try fm.createDirectory(at: derived, withIntermediateDirectories: true)
        try fm.createDirectory(at: backups, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100).write(to: derived.appendingPathComponent("object.o"))
        try Data(repeating: 2, count: 30).write(to: backups.appendingPathComponent("manifest.db"))

        let report = DeveloperJunkAuditor(home: home).scan()
        precondition(report.items.count == 2)
        let derivedItem = report.items.first { $0.url.path == derivedRoot.path }!
        let backupItem = report.items.first { $0.url.path == backupRoot.path }!
        precondition(derivedItem.bytes == 100 && derivedItem.files == 1)
        precondition(backupItem.bytes == 30 && backupItem.files == 1)
        precondition(report.missingLocations == 6)
        precondition(!report.limited)

        let limited = DeveloperJunkAuditor(home: home, entryLimit: 1).scan()
        precondition(limited.limited && limited.visitedEntries == 1)
        print("DeveloperAuditsSmoke OK: inventaire Xcode et sauvegardes, chemins absents et limite")
    }
}
