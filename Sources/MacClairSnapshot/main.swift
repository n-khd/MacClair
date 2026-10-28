import AppKit
import SwiftUI

/// Rend l'interface réelle de MacClair hors écran, en français et en anglais.
/// Compilé avec -DSNAPSHOT (le @main de l'application est alors désactivé).
/// Usage : macclair-snapshot <dossier-de-sortie>
@MainActor
enum Snapshot {
    static func render(code: String, width: CGFloat, height: CGFloat, to path: String) throws {
        let view = ModernContentView()
            .frame(width: width, height: height)
            .environment(\.locale, Locale(identifier: code))
            .preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.isOpaque = true
        guard let image = renderer.cgImage else {
            throw NSError(domain: "snapshot", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "ImageRenderer n'a rien produit"])
        }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "snapshot", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "encodage PNG impossible"])
        }
        try data.write(to: URL(fileURLWithPath: path))
        print("capture \(code) -> \(path) (\(image.width)x\(image.height))")
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
                try Snapshot.render(code: "en", width: 1500, height: 950,
                                    to: "\(directory)/overview-en.png")
                try Snapshot.render(code: "fr", width: 1500, height: 950,
                                    to: "\(directory)/overview-fr.png")
                return 0
            } catch {
                FileHandle.standardError.write(Data("échec : \(error)\n".utf8))
                return 1
            }
        }
        exit(status)
    }
}
