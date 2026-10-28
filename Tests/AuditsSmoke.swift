import Foundation

@main
struct AuditsSmoke {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("macclair-audits-\(UUID())")
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let alpha = root.appendingPathComponent("alpha")
        let beta = root.appendingPathComponent("beta")
        try fm.createDirectory(at: alpha, withIntermediateDirectories: true)
        try fm.createDirectory(at: beta, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 8).write(to: alpha.appendingPathComponent("a.txt"))
        try Data(repeating: 2, count: 3).write(to: beta.appendingPathComponent("b.txt"))
        try fm.createSymbolicLink(at: alpha.appendingPathComponent("link"), withDestinationURL: beta.appendingPathComponent("b.txt"))
        let result = StorageAuditor(root: root).scan()
        precondition(result.scannedFiles == 2)
        precondition(result.folders.map(\.bytes) == [8, 3])
        precondition(result.folders[0].url.lastPathComponent == "alpha")
        let limited = StorageAuditor(root: root, fileLimit: 1).scan()
        precondition(limited.limited && limited.scannedFiles == 1)
        let startup = root.appendingPathComponent("Library/LaunchAgents")
        try fm.createDirectory(at: startup, withIntermediateDirectories: true)
        try Data().write(to: startup.appendingPathComponent("example.plist"))
        precondition(StartupAuditor(home: root).scan().contains { $0.url.lastPathComponent == "example.plist" })
        print("AuditsSmoke OK: tailles, liens symboliques, limite et agents")
    }
}
