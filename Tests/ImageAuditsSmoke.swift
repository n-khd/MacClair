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
        let rotated = root.appendingPathComponent("rotated.png")
        let different = root.appendingPathComponent("different.png")
        try makeImage(a, x: 8, y: 8, w: 8, h: 8)
        try fm.copyItem(at: a, to: b)
        try makeImage(rotated, x: 16, y: 8, w: 8, h: 8)
        try makeImage(different, x: 8, y: 8, w: 16, h: 16)
        try fm.createSymbolicLink(at: root.appendingPathComponent("linked.png"), withDestinationURL: a)

        let result = ImageAuditor(root: root).scan()
        precondition(result.scanned == 4)
        // a, b (copie) et rotated (rotation de 90°) sont le même visuel : 3 paires.
        precondition(result.pairs.count == 3)
        let similar = Set(["a.png", "b.png", "rotated.png"])
        precondition(result.pairs.allSatisfy { similar.contains($0.first.lastPathComponent) && similar.contains($0.second.lastPathComponent) })
        let names = Set(result.pairs.map { Set([$0.first.lastPathComponent, $0.second.lastPathComponent]) })
        precondition(names.contains(Set([a.lastPathComponent, b.lastPathComponent])))
        precondition(names.contains(Set([a.lastPathComponent, rotated.lastPathComponent])))
        precondition(!names.contains { $0.contains(different.lastPathComponent) })
        precondition(result.pairs.allSatisfy { $0.difference == 0 })
        print("ImageAuditsSmoke OK: invariance à la rotation, contenu distinct et lien symbolique exclu")
    }

    /// Image 32x32 grise avec un bloc clair rectangulaire et le reste sombre.
    private static func makeImage(_ url: URL, x: Int, y: Int, w: Int, h: Int) throws {
        var bytes = [UInt8](repeating: 0, count: 32 * 32 * 4)
        for row in 0..<32 {
            for col in 0..<32 {
                let inside = col >= x && col < x + w && row >= y && row < y + h
                let tone: UInt8 = inside ? 235 : 24
                let i = (row * 32 + col) * 4
                bytes[i] = tone
                bytes[i + 1] = tone
                bytes[i + 2] = tone
                bytes[i + 3] = 255
            }
        }
        guard let context = CGContext(data: &bytes, width: 32, height: 32, bitsPerComponent: 8,
                                      bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
