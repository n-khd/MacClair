import Foundation

@main
struct ScannerSmoke {
    static func main() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("macclair-smoke-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home) }
        let cache = home.appendingPathComponent("Library/Caches/TestApp")
        let downloads = home.appendingPathComponent("Downloads")
        try fm.createDirectory(at: cache, withIntermediateDirectories: true)
        try fm.createDirectory(at: downloads, withIntermediateDirectories: true)
        let old = cache.appendingPathComponent("old.cache")
        let recent = cache.appendingPathComponent("recent.cache")
        let image = downloads.appendingPathComponent("old.dmg")
        let outside = home.deletingLastPathComponent().appendingPathComponent("macclair-outside-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: outside) }
        try Data(repeating: 1, count: 32).write(to: old)
        try Data(repeating: 2, count: 8).write(to: recent)
        try Data(repeating: 3, count: 16).write(to: image)
        try Data(repeating: 4, count: 4).write(to: outside)
        try fm.createSymbolicLink(at: cache.appendingPathComponent("outside.cache"), withDestinationURL: outside)
        let oldDate = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        for url in [old, image] {
            try fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: url.path)
        }
        let report = Cleaner(home: home).scan()
        precondition(Set(report.items.map(\.name)) == ["old.cache", "old.dmg"])
        precondition(report.items.allSatisfy { !$0.selected })
        precondition(report.items.map(\.bytes).reduce(0, +) == 48)
        let oldItem = try report.items.first { $0.name == "old.dmg" }.unwrap()
        try Data(repeating: 5, count: 64).write(to: image)
        try fm.setAttributes([.modificationDate: Date()], ofItemAtPath: image.path)
        do {
            try Cleaner(home: home).moveToTrash(oldItem)
            preconditionFailure("Un fichier modifié a été déplacé")
        } catch CleanupError.changedSinceScan {
            precondition(fm.fileExists(atPath: image.path))
        }
        try fm.removeItem(at: image)
        let otherDownload = downloads.appendingPathComponent("other.dmg")
        try Data([1, 2, 3]).write(to: otherDownload)
        try fm.createSymbolicLink(at: image, withDestinationURL: otherDownload)
        do {
            try Cleaner(home: home).moveToTrash(oldItem)
            preconditionFailure("Un lien symbolique a été déplacé")
        } catch CleanupError.symbolicLink {
            precondition(fm.fileExists(atPath: otherDownload.path))
        }
        let protected = try report.items.first { $0.name == "old.cache" }.unwrap()
        do {
            try Cleaner(home: home).moveToTrash(protected)
            preconditionFailure("Un cache a été déplacé")
        } catch CleanupError.protectedCategory {}
        print("ScannerSmoke OK: ancienneté, liens symboliques, sélection et revérification")
    }
}

private extension Optional {
    func unwrap() throws -> Wrapped {
        guard let value = self else { throw CocoaError(.fileNoSuchFile) }
        return value
    }
}
