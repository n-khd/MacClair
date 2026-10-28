import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@main
struct ImageAuditsSmoke {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("macclair-images-\(UUID())")
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let a = root.appendingPathComponent("a.png")
        let b = root.appendingPathComponent("b.png")
        let c = root.appendingPathComponent("c.png")
        try makeImage(a)
        try fm.copyItem(at: a, to: b)
        try makeImage(c, reversed: true)
        try fm.createSymbolicLink(at: root.appendingPathComponent("linked.png"), withDestinationURL: a)
        let result = ImageAuditor(root: root).scan()
        precondition(result.scanned == 3)
        precondition(result.pairs.count == 1)
        precondition(result.pairs[0].difference == 0)
        print("ImageAuditsSmoke OK: ressemblance et lien symbolique exclu")
    }

    private static func makeImage(_ url: URL, reversed: Bool = false) throws {
        var bytes = [UInt8](repeating: 0, count: 16 * 16 * 4)
        for y in 0..<16 { for x in 0..<16 {
            let i = (y * 16 + x) * 4
            let tone: UInt8 = (x < 8) != reversed ? 20 : 220
            bytes[i] = tone
            bytes[i + 1] = tone
            bytes[i + 2] = tone
            bytes[i + 3] = 255
        }}
        guard let context = CGContext(data: &bytes, width: 16, height: 16, bitsPerComponent: 8,
                                      bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
