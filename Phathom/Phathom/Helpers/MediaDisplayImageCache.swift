#if os(iOS)
import UIKit

/// Process-wide decoded hero/viewer images keyed by item id (invalidated when `thumbnailData` changes).
final class MediaDisplayImageCache: @unchecked Sendable {
    static let shared = MediaDisplayImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 48
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    private func key(for itemID: UUID) -> NSString {
        itemID.uuidString as NSString
    }

    func image(for itemID: UUID) -> UIImage? {
        cache.object(forKey: key(for: itemID))
    }

    func setImage(_ image: UIImage, for itemID: UUID) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key(for: itemID), cost: max(cost, 1))
    }

    func remove(itemID: UUID) {
        cache.removeObject(forKey: key(for: itemID))
    }
}
#endif
