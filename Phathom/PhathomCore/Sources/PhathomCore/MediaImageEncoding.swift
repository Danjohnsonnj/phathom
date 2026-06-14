import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

/// Downscale and re-encode shared or picked images so on-disk rows stay small.
public enum MediaImageEncoding {
    /// Detail cold-open target: smaller on-disk rows + faster ImageIO subsample (see gate doc).
    public static let libraryStorageMaxDimension: CGFloat = 1024
    private static let libraryStorageQuality: CGFloat = 0.72

    /// Smaller JPEG for `ContentItem.thumbnailData` on new library captures (Detail hero / vision input).
    public static func normalizedJPEGForLibraryStorage(from data: Data) -> Data? {
        normalizedJPEG(
            from: data,
            maxDimension: libraryStorageMaxDimension,
            quality: libraryStorageQuality
        )
    }

#if canImport(UIKit)
    public static func normalizedJPEGForLibraryStorage(from image: UIImage) -> Data? {
        normalizedJPEG(
            from: image,
            maxDimension: libraryStorageMaxDimension,
            quality: libraryStorageQuality
        )
    }

    public static func normalizedJPEG(from image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image.jpegData(compressionQuality: quality) }
        let maxSide = max(size.width, size.height)
        let scale = maxSide > maxDimension ? maxDimension / maxSide : 1
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let drawn = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return drawn.jpegData(compressionQuality: quality)
    }

    public static func normalizedJPEG(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return normalizedJPEG(from: image, maxDimension: maxDimension, quality: quality)
    }
#elseif os(macOS)
    public static func normalizedJPEG(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return normalizedJPEG(from: image, maxDimension: maxDimension, quality: quality)
    }

    public static func normalizedJPEG(from image: CGImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > 0, height > 0 else { return nil }

        let maxSide = max(width, height)
        let scale = maxSide > maxDimension ? maxDimension / maxSide : 1
        let targetWidth = max(1, Int(floor(width * scale)))
        let targetHeight = max(1, Int(floor(height * scale)))

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaled = context.makeImage() else { return nil }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
        ]
        CGImageDestinationAddImage(dest, scaled, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
#endif
}
