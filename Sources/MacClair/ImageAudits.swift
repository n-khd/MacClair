import Foundation
import ImageIO
import CoreGraphics
import Darwin

struct SimilarPair: Identifiable, Sendable {
    let first: URL
    let second: URL
    let difference: Int
    var id: String { first.path + "|" + second.path }
}

struct ImageAudit: Sendable {
    let pairs: [SimilarPair]
    let scanned: Int
    let limited: Bool
}

/// Empreinte visuelle insensible à la rotation : la magnitude du gradient de
/// Sobel est réduite à 8x8 puis hachée (64 bits) dans quatre orientations
/// (0°, 90°, 180°, 270°). Deux images dont l'une est une rotation de l'autre
/// obtiennent ainsi une distance nulle. La magnitude de gradient rend le
/// résultat moins sensible à l'exposition qu'un hachage de la luminance brute.
private struct ImageFingerprint {
    let orientations: [UInt64]
}

/// Local thumbnail fingerprint for suggestions only; no files are modified.
struct ImageAuditor: Sendable {
    let root: URL
    let maximumImages: Int
    let minimumDimension: Int
    let similarityThreshold: Int

    init(root: URL, maximumImages: Int = 300, minimumDimension: Int = 16, similarityThreshold: Int = 6) {
        self.root = root
        self.maximumImages = maximumImages
        self.minimumDimension = minimumDimension
        self.similarityThreshold = similarityThreshold
    }

    func scan() -> ImageAudit {
        let allowed: Set<String> = ["jpg", "jpeg", "png", "heic", "tiff", "webp"]
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil,
                                             options: [.skipsPackageDescendants, .skipsHiddenFiles], errorHandler: { _, _ in true }) else {
            return ImageAudit(pairs: [], scanned: 0, limited: false)
        }
        var images: [(URL, ImageFingerprint)] = []
        var limited = false
        for case let url as URL in enumerator {
            if ["app", "bundle", "framework", "xcassets", "xcodeproj", "xcworkspace"].contains(url.pathExtension.lowercased()),
               (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                enumerator.skipDescendants()
                continue
            }
            if ["node_modules", "Pods", "DerivedData", "venv", ".git"].contains(url.lastPathComponent),
               (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                enumerator.skipDescendants()
                continue
            }
            guard allowed.contains(url.pathExtension.lowercased()), let bytes = regularSize(url),
                  bytes > 0 && bytes <= 50_000_000 else { continue }
            if images.count >= maximumImages { limited = true; break }
            if let fingerprint = fingerprint(url) { images.append((url, fingerprint)) }
        }
        var pairs: [SimilarPair] = []
        for i in images.indices {
            for j in images.indices where j > i {
                let difference = distance(images[i].1, images[j].1)
                if difference <= similarityThreshold {
                    pairs.append(SimilarPair(first: images[i].0, second: images[j].0, difference: difference))
                }
                if pairs.count >= 100 { return ImageAudit(pairs: pairs, scanned: images.count, limited: true) }
            }
        }
        return ImageAudit(pairs: pairs.sorted { $0.difference < $1.difference },
                          scanned: images.count, limited: limited)
    }

    private func regularSize(_ url: URL) -> Int64? {
        var value = stat()
        guard url.path.withCString({ Darwin.lstat($0, &value) }) == 0,
              (value.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return nil }
        return Int64(value.st_size)
    }

    /// Distance de Hamming minimale entre une orientation de `a` et l'orientation
    /// de base de `b`. Comme l'ensemble des orientations couvre 90°, 180° et 270°,
    /// une seule image pivotée produit une distance nulle.
    private func distance(_ a: ImageFingerprint, _ b: ImageFingerprint) -> Int {
        guard let base = b.orientations.first else { return 64 }
        return a.orientations.map { ($0 ^ base).nonzeroBitCount }.min() ?? 64
    }

    private func fingerprint(_ url: URL) -> ImageFingerprint? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = props[kCGImagePropertyPixelWidth] as? Int,
           let height = props[kCGImagePropertyPixelHeight] as? Int,
           min(width, height) < minimumDimension {
            return nil
        }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 32,
                                        kCGImageSourceCreateThumbnailWithTransform: true]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: side, height: side))

        let magnitude = gradientMagnitude(pixels, side: side)
        var orientations: [UInt64] = []
        var rotated = magnitude
        for _ in 0..<4 {
            orientations.append(averageHash(rotated, side: side))
            rotated = rotate90(rotated, side: side)
        }
        return ImageFingerprint(orientations: orientations)
    }

    /// Magnitude du gradient de Sobel (canal gris), bords laissés à zéro.
    private func gradientMagnitude(_ pixels: [UInt8], side: Int) -> [Float] {
        var magnitude = [Float](repeating: 0, count: side * side)
        for y in 1..<(side - 1) {
            for x in 1..<(side - 1) {
                let gx = -Int(pixels[(y - 1) * side + x - 1]) - 2 * Int(pixels[(y - 1) * side + x]) - Int(pixels[(y - 1) * side + x + 1])
                         + Int(pixels[(y + 1) * side + x - 1]) + 2 * Int(pixels[(y + 1) * side + x]) + Int(pixels[(y + 1) * side + x + 1])
                let gy = -Int(pixels[(y - 1) * side + x - 1]) - 2 * Int(pixels[y * side + x - 1]) - Int(pixels[(y + 1) * side + x - 1])
                         + Int(pixels[(y - 1) * side + x + 1]) + 2 * Int(pixels[y * side + x + 1]) + Int(pixels[(y + 1) * side + x + 1])
                magnitude[y * side + x] = (Float(gx * gx + gy * gy)).squareRoot()
            }
        }
        return magnitude
    }

    /// Hash moyen (aHash) 64 bits : grille 8x8 réduite par moyenne de blocs,
    /// chaque bit compare un bloc à la moyenne de la grille.
    private func averageHash(_ magnitude: [Float], side: Int) -> UInt64 {
        let target = 8
        let block = side / target
        var reduced = [Float](repeating: 0, count: target * target)
        var total: Float = 0
        for by in 0..<target {
            for bx in 0..<target {
                var sum: Float = 0
                for y in (by * block)..<(by * block + block) {
                    for x in (bx * block)..<(bx * block + block) {
                        sum += magnitude[y * side + x]
                    }
                }
                let value = sum / Float(block * block)
                reduced[by * target + bx] = value
                total += value
            }
        }
        let mean = total / Float(target * target)
        var hash: UInt64 = 0
        for y in 0..<target {
            for x in 0..<target {
                hash = (hash << 1) | (reduced[y * target + x] >= mean ? 1 : 0)
            }
        }
        return hash
    }

    /// Rotation de 90° dans le sens horaire d'une grille carrée.
    private func rotate90(_ input: [Float], side: Int) -> [Float] {
        var output = [Float](repeating: 0, count: side * side)
        for y in 0..<side {
            for x in 0..<side {
                output[x * side + (side - 1 - y)] = input[y * side + x]
            }
        }
        return output
    }
}
