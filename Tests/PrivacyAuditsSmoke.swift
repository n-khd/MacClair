import Foundation

@main
struct PrivacyAuditsSmoke {
    static func main() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("macclair-privacy-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home) }
        let chrome = home.appendingPathComponent("Library/Caches/Google/Chrome")
        let safari = home.appendingPathComponent("Library/Caches/com.apple.Safari")
        let mail = home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads")
        try fm.createDirectory(at: chrome, withIntermediateDirectories: true)
        try fm.createDirectory(at: mail, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: chrome.appendingPathComponent("entry"))
        try Data("piece jointe".utf8).write(to: mail.appendingPathComponent("piece.pdf"))
        let outside = home.deletingLastPathComponent().appendingPathComponent("macclair-outside-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: outside) }
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data("ne pas suivre".utf8).write(to: outside.appendingPathComponent("private"))
        try fm.createSymbolicLink(at: safari, withDestinationURL: outside)
        try fm.createSymbolicLink(at: chrome.appendingPathComponent("link"), withDestinationURL: outside)

        let report = PrivacyAuditor(home: home).scan()
        let cache = report.items.first { $0.url.path == chrome.path }!
        let attachments = report.items.first { $0.url.path == mail.path }!
        precondition(cache.files == 1 && cache.bytes == 5)
        precondition(attachments.files == 1 && attachments.bytes == 12)
        precondition(!report.items.contains { $0.url.path == safari.path })
        precondition(report.unreadablePaths >= 1 && report.missingLocations == 2)
        precondition(!report.limited)
        let limited = PrivacyAuditor(home: home, entryLimit: 1).scan()
        precondition(limited.limited && limited.visitedEntries == 1)
        precondition(fm.fileExists(atPath: chrome.appendingPathComponent("entry").path))
        precondition(fm.fileExists(atPath: mail.appendingPathComponent("piece.pdf").path))
        print("PrivacyAuditsSmoke OK: inventaire local, chemins absents, liens et limite")
    }
}
