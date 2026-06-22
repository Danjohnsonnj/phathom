import PhathomCore
import SwiftUI

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}

enum PlatformImageDecoding {
    private static let ingestMaxPixelSide: CGFloat = MediaImageEncoding.libraryStorageMaxDimension

    nonisolated static func image(from data: Data?) -> PlatformImage? {
        guard let data, !data.isEmpty else { return nil }
        #if os(iOS)
        return UIImage(data: data)
        #elseif os(macOS)
        return NSImage(data: data)
        #endif
    }

    #if os(iOS)
    @MainActor
    static func displayMaxPixelSize() -> CGFloat {
        let maxSide = max(PhathomActiveScreen.bounds.width, PhathomActiveScreen.bounds.height) * PhathomActiveScreen.scale
        return min(max(maxSide, 1), ingestMaxPixelSide)
    }
    #elseif os(macOS)
    @MainActor
    static func displayMaxPixelSize() -> CGFloat {
        guard let screen = NSScreen.main else { return ingestMaxPixelSide }
        let maxSide = max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor
        return min(max(maxSide, 1), ingestMaxPixelSide)
    }
    #endif

    static func imageForDisplay(from data: Data?, maxPixelSize: CGFloat) -> PlatformImage? {
        guard let data, !data.isEmpty else { return nil }
        let cap = max(Int(maxPixelSize.rounded()), 1)
        return subsampled(from: data, maxPixelSize: cap)
    }

    static func decodeOffMain(from data: Data?) async -> PlatformImage? {
        guard let data, !data.isEmpty else { return nil }
        let maxPixelSize = displayMaxPixelSize()
        let cap = Int(maxPixelSize.rounded())
        return await Task.detached(priority: .userInitiated) {
            subsampled(from: data, maxPixelSize: cap)
        }.value
    }

    nonisolated private static func subsampled(from data: Data, maxPixelSize: Int) -> PlatformImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return image(from: data)
        }
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #elseif os(macOS)
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)
        return image
        #endif
    }
}
