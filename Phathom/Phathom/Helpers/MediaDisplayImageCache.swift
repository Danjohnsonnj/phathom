import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Process-wide decoded hero/viewer images keyed by item id (invalidated when `thumbnailData` changes).
final class MediaDisplayImageCache: @unchecked Sendable {
    static let shared = MediaDisplayImageCache()

    private let cache = NSCache<NSString, PlatformImage>()

    private init() {
        cache.countLimit = 48
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    private func key(for itemID: UUID) -> NSString {
        itemID.uuidString as NSString
    }

    func image(for itemID: UUID) -> PlatformImage? {
        cache.object(forKey: key(for: itemID))
    }

    func setImage(_ image: PlatformImage, for itemID: UUID) {
        let cost = imageEstimatedByteCost(image)
        cache.setObject(image, forKey: key(for: itemID), cost: max(cost, 1))
    }

    func remove(itemID: UUID) {
        cache.removeObject(forKey: key(for: itemID))
    }

    private func imageEstimatedByteCost(_ image: PlatformImage) -> Int {
        #if os(iOS)
        Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        #elseif os(macOS)
        Int(image.size.width * image.size.height * 4)
        #endif
    }
}
