import ImageIO
import PhathomCore
import SwiftUI
import UIKit

#if os(iOS)
enum ThumbnailImageDecoding {
  /// Match library storage cap so Detail decode does not subsample above stored JPEG resolution.
  private static let ingestMaxPixelSide: CGFloat = MediaImageEncoding.libraryStorageMaxDimension

  /// Library rows and legacy call sites — full `UIImage(data:)` decode.
  static func uiImage(from data: Data?) -> UIImage? {
    guard let data else { return nil }
    return UIImage(data: data)
  }

  /// Max pixel side for Detail hero + full-screen viewer (screen × scale, capped at ingest).
  @MainActor
  static func displayMaxPixelSize() -> CGFloat {
    let screen = UIScreen.main
    let maxSide = max(screen.bounds.width, screen.bounds.height) * screen.scale
    return min(max(maxSide, 1), ingestMaxPixelSide)
  }

  /// Display-quality subsample via ImageIO (not full-raster `UIImage(data:)`).
  static func uiImageForDisplay(from data: Data?, maxPixelSize: CGFloat) -> UIImage? {
    guard let data, !data.isEmpty else { return nil }
    let cap = max(Int(maxPixelSize.rounded()), 1)
    return uiImageSubsampled(from: data, maxPixelSize: cap)
  }

  /// Subsampled decode off the main actor for Detail media cache.
  static func decodeOffMain(from data: Data?) async -> UIImage? {
    guard let data, !data.isEmpty else { return nil }
    let maxPixelSize = await displayMaxPixelSize()
    let cap = Int(maxPixelSize.rounded())
    return await Task.detached(priority: .userInitiated) {
      uiImageSubsampled(from: data, maxPixelSize: cap)
    }.value
  }

  nonisolated private static func uiImageSubsampled(from data: Data, maxPixelSize: Int) -> UIImage? {
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      kCGImageSourceCreateThumbnailWithTransform: true,
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) > 0,
      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else {
      return UIImage(data: data)
    }
    return UIImage(cgImage: cgImage)
  }
}
#endif

struct ThumbnailView: View {
  let thumbnailData: Data?
  let colorHex: String?
  let contentKind: ContentKind
  let size: CGFloat
  var cornerRadius: CGFloat?

  var body: some View {
    Group {
      if let uiImage = ThumbnailImageDecoding.uiImage(from: thumbnailData) {
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else {
        ZStack {
          Color(hex: colorHex ?? AppPalette.thumbnailFallbackHex)
          Image(systemName: iconName)
            .font(.system(size: size * 0.35))
            .foregroundStyle(AppPalette.floralWhite.opacity(0.85))
        }
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.15, style: .continuous))
  }

  private var iconName: String {
    switch contentKind {
    case .web: "globe"
    case .media: "photo"
    case .note: "note.text"
    }
  }
}
