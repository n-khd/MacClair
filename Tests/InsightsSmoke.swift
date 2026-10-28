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

        // Samples can collide: matching ends are not proof of matching content.
        let sampleA = downloads.appendingPathComponent("sample-a.bin")
        let sampleB = downloads.appendingPathComponent("sample-b.bin")
        let sampleDifferent = downloads.appendingPathComponent("sample-different.bin")
        var data = Data(repeating: 7, count: 200_000)
        try data.write(to: sampleA)
        try data.write(to: sampleB)
        data[100_000] = 8
        try data.write(to: sampleDifferent)
        let emptyA = downloads.appendingPathComponent("empty-a")
        let emptyB = downloads.appendingPathComponent("empty-b")
        try Data().write(to: emptyA)
        try Data().write(to: emptyB)

        // Sparse files exercise the former 512 MB cutoff without large allocations.
        let hugeA = downloads.appendingPathComponent("huge-a.bin")
        let hugeB = downloads.appendingPathComponent("huge-b.bin")
        for url in [hugeA, hugeB] {
            precondition(fm.createFile(atPath: url.path, contents: nil))
            let file = try FileHandle(forWritingTo: url)
            try file.truncate(atOffset: 512_000_001)
            try file.close()
        }

        let result = InsightScanner(home: home).scan()
        precondition(result.largeFiles.count == 3)
        let groups = result.duplicates.map { Set($0.files.map(\.lastPathComponent)) }
        precondition(groups.contains(Set([emptyA.lastPathComponent, emptyB.lastPathComponent])))
        precondition(groups.contains(Set([sampleA.lastPathComponent, sampleB.lastPathComponent])))
        precondition(!groups.contains(where: { $0.contains(sampleDifferent.lastPathComponent) }))
        precondition(groups.contains(Set([hugeA.lastPathComponent, hugeB.lastPathComponent])))
        precondition(result.duplicates.contains { $0.bytesPerFile == Int64(Data("même contenu".utf8).count) && $0.files.count == 2 })
        print("InsightsSmoke OK: fichiers vides et volumineux, comparaison complète et lien dur exclu")
    }
}
