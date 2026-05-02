#if os(iOS)
import UIKit

/// Downscale and re-encode shared or picked images so on-disk rows stay small.
public enum MediaImageEncoding {
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
}
#endif
