import AppKit
import SwiftUI

// Outil de capture : rend l'interface réelle de MacClair hors écran, en français et en anglais.
// Compilé avec -DSNAPSHOT (le @main de l'application est alors désactivé).
// Usage : macclair-snapshot <dossier-de-sortie>

@MainActor
func render(code: String, width: CGFloat, height: CGFloat, to path: String) throws {
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

let arguments = CommandLine.arguments
let directory = arguments.count > 1 ? arguments[1] : "dist/screenshots"
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()

var failure: Error?
let work = Task { @MainActor in
    do {
        try render(code: "en", width: 1500, height: 950, to: "\(directory)/overview-en.png")
        try render(code: "fr", width: 1500, height: 950, to: "\(directory)/overview-fr.png")
    } catch {
        failure = error
    }
    app.stop(nil)
}
_ = work
app.run()
if let failure { throw failure }
