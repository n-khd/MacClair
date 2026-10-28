import AppKit
import SwiftUI

/// Rend l'interface réelle de MacClair hors écran, en français et en anglais.
/// Compilé avec -DSNAPSHOT (le @main de l'application est alors désactivé) puis exécuté
/// depuis l'intérieur du bundle MacClair.app, pour que Bundle.main expose bien en.lproj.
/// Usage : macclair-snapshot <dossier-de-sortie>
@MainActor
enum Snapshot {
    static func render(code: String, size: CGSize, to path: String) throws {
        let view = ModernContentView()
            .frame(width: size.width, height: size.height)
            .environment(\.locale, Locale(identifier: code))
            .preferredColorScheme(.dark)

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        // Laisse un tour de boucle : les Canvas/animations du fond ont besoin d'une passe.
        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw NSError(domain: "snapshot", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "bitmap indisponible"])
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "snapshot", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "encodage PNG impossible"])
        }
        try data.write(to: URL(fileURLWithPath: path))
        print("capture \(code) -> \(path) (\(rep.pixelsWide)x\(rep.pixelsHigh)) bundle=\(Bundle.main.bundlePath)")
    }
}

@main
struct SnapshotMain {
    static func main() {
        let arguments = CommandLine.arguments
        let directory = arguments.count > 1 ? arguments[1] : "dist/screenshots"
        let status: Int32 = MainActor.assumeIsolated {
            do {
                try FileManager.default.createDirectory(atPath: directory,
                                                        withIntermediateDirectories: true)
                let app = NSApplication.shared
                app.setActivationPolicy(.accessory)
                app.finishLaunching()
                let size = CGSize(width: 2400, height: 1520)
                try Snapshot.render(code: "en", size: size, to: "\(directory)/overview-en.png")
                try Snapshot.render(code: "fr", size: size, to: "\(directory)/overview-fr.png")
                try Snapshot.render(code: "en", size: size, to: "\(directory)/overview-en@full.png")
                return 0
            } catch {
                FileHandle.standardError.write(Data("échec : \(error)\n".utf8))
                return 1
            }
        }
        exit(status)
    }
}
