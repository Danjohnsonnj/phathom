import ImageIO
import PhathomCore
import SwiftUI

enum ThumbnailImageDecoding {
    static func uiImage(from data: Data?) -> PlatformImage? {
        PlatformImageDecoding.image(from: data)
    }

    @MainActor
    static func displayMaxPixelSize() -> CGFloat {
        PlatformImageDecoding.displayMaxPixelSize()
    }

    static func uiImageForDisplay(from data: Data?, maxPixelSize: CGFloat) -> PlatformImage? {
        PlatformImageDecoding.imageForDisplay(from: data, maxPixelSize: maxPixelSize)
    }

    static func decodeOffMain(from data: Data?) async -> PlatformImage? {
        await PlatformImageDecoding.decodeOffMain(from: data)
    }
}

struct ThumbnailView: View {
    let thumbnailData: Data?
    let colorHex: String?
    let contentKind: ContentKind
    let size: CGFloat
    var cornerRadius: CGFloat?

    var body: some View {
        Group {
            if let platformImage = ThumbnailImageDecoding.uiImage(from: thumbnailData) {
                Image(platformImage: platformImage)
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
