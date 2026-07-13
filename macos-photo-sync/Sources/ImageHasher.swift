import Foundation
import CoreGraphics
import ImageIO
import CryptoKit
import AppKit

/// Computes content-based hashes for images.
///
/// All hashing is done on the *decoded pixel data* — never on the raw file
/// bytes — so EXIF / IPTC / XMP metadata never influences the result. Two
/// files that contain the same picture but different metadata therefore
/// produce the same hash.
enum ImageHasher {

    // MARK: - Decoding

    /// Decode an image file into a CGImage at its native resolution.
    /// `CGImageSource` deliberately does not apply metadata to the pixels.
    static func decode(url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        return CGImageSourceCreateImageAtIndex(src, 0, opts as CFDictionary)
    }

    /// Decode image data (used for assets fetched from the Photos library).
    static func decode(data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        return CGImageSourceCreateImageAtIndex(src, 0, opts as CFDictionary)
    }

    // MARK: - Exact content hash

    /// SHA-256 over the normalized RGBA pixel buffer.
    ///
    /// The dimensions are folded into the hash so two images of different
    /// sizes can never collide. Because the input is decoded pixels, this is
    /// an *exact content* match that ignores all metadata.
    static func exactHash(_ image: CGImage) -> String? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, let pixels = rgbaPixels(image, width: width, height: height) else {
            return nil
        }
        var hasher = SHA256()
        var w = UInt32(width).littleEndian
        var h = UInt32(height).littleEndian
        withUnsafeBytes(of: &w) { hasher.update(data: Data($0)) }
        withUnsafeBytes(of: &h) { hasher.update(data: Data($0)) }
        hasher.update(data: pixels)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Perceptual hash (for similarity matching)

    /// 64-bit difference hash (dHash). Robust to resizing, minor compression
    /// and small colour shifts. Compare two of these with `hammingDistance`.
    static func perceptualHash(_ image: CGImage) -> UInt64? {
        let w = 9, h = 8
        guard let gray = grayPixels(image, width: w, height: h) else { return nil }
        var hash: UInt64 = 0
        var bit: UInt64 = 0
        for row in 0..<h {
            for col in 0..<(w - 1) {
                let left = gray[row * w + col]
                let right = gray[row * w + col + 1]
                if left > right { hash |= (UInt64(1) << bit) }
                bit += 1
            }
        }
        return hash
    }

    /// Number of differing bits between two perceptual hashes (0 == identical).
    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    // MARK: - Thumbnails (for the UI)

    /// A small NSImage suitable for showing the picture currently being compared.
    static func thumbnail(url: URL, maxPixel: Int = 220) -> NSImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    // MARK: - Pixel extraction helpers

    private static func rgbaPixels(_ image: CGImage, width: Int, height: Int) -> Data? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = Data(count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ok = data.withUnsafeMutableBytes { ptr -> Bool in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(data: base,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? data : nil
    }

    private static func grayPixels(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        let bytesPerRow = width
        var buffer = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let ok = buffer.withUnsafeMutableBytes { ptr -> Bool in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(data: base,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                return false
            }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? buffer : nil
    }
}
