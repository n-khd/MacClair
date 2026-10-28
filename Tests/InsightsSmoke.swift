import Foundation

@main
struct InsightsSmoke {
    static func main() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("macclair-insights-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home) }
        let downloads = home.appendingPathComponent("Downloads")
        try fm.createDirectory(at: downloads, withIntermediateDirectories: true)
        let first = downloads.appendingPathComponent("one.txt")
        let second = downloads.appendingPathComponent("two.txt")
        let hardlink = downloads.appendingPathComponent("hardlink.txt")
        try Data("même contenu".utf8).write(to: first)
        try Data("même contenu".utf8).write(to: second)
        try fm.linkItem(at: first, to: hardlink)
        let large = downloads.appendingPathComponent("large.bin")
        fm.createFile(atPath: large.path, contents: nil)
        let handle = try FileHandle(forWritingTo: large)
        try handle.truncate(atOffset: 101_000_000)
        try handle.close()
        let gitPack = downloads.appendingPathComponent("project/.git/objects/pack/private.pack")
        try fm.createDirectory(at: gitPack.deletingLastPathComponent(), withIntermediateDirectories: true)
        fm.createFile(atPath: gitPack.path, contents: nil)
        let gitHandle = try FileHandle(forWritingTo: gitPack)
        try gitHandle.truncate(atOffset: 101_000_000)
        try gitHandle.close()

        let result = InsightScanner(home: home).scan()
        precondition(result.largeFiles.count == 1)
        precondition(result.duplicates.count == 1)
        precondition(result.duplicates[0].files.count == 2)
        precondition(result.duplicates[0].reclaimableBytes == Int64(Data("même contenu".utf8).count))
        print("InsightsSmoke OK: gros fichier, doublon exact et lien dur exclu")
    }
}
