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

private struct ImageFingerprint {
    let average: UInt64
    let gradient: UInt64
    let tone: Int
}

/// Local thumbnail fingerprint for suggestions only; no files are modified.
struct ImageAuditor: Sendable {
    let root: URL
    let maximumImages: Int

    init(root: URL, maximumImages: Int = 300) {
        self.root = root
        self.maximumImages = maximumImages
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
            if ["node_modules", "Pods", "DerivedData", "venv"].contains(url.lastPathComponent),
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
                let averageDifference = (images[i].1.average ^ images[j].1.average).nonzeroBitCount
                let gradientDifference = (images[i].1.gradient ^ images[j].1.gradient).nonzeroBitCount
                let toneDifference = abs(images[i].1.tone - images[j].1.tone)
                if averageDifference <= 2 && gradientDifference <= 3 && toneDifference <= 12 {
                    pairs.append(SimilarPair(first: images[i].0, second: images[j].0,
                                             difference: averageDifference + gradientDifference))
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

    private func fingerprint(_ url: URL) -> ImageFingerprint? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 64,
                                        kCGImageSourceCreateThumbnailWithTransform: true]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        var pixels = [UInt8](repeating: 0, count: 72)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: &pixels, width: 9, height: 8, bitsPerComponent: 8,
                                      bytesPerRow: 9, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: 9, height: 8))
        let average = pixels.reduce(0) { $0 + Int($1) } / 72
        var averageBits: UInt64 = 0
        var gradientBits: UInt64 = 0
        for y in 0..<8 {
            for x in 0..<8 {
                let value = pixels[y * 9 + x]
                averageBits = (averageBits << 1) | (value >= average ? 1 : 0)
                gradientBits = (gradientBits << 1) | (value > pixels[y * 9 + x + 1] ? 1 : 0)
            }
        }
        return ImageFingerprint(average: averageBits, gradient: gradientBits, tone: average)
    }
}
