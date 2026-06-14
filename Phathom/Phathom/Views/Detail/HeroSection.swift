import PhathomCore
import SwiftUI

struct HeroSection: View {
    let item: ContentItem
    /// Pre-decoded media hero image from `DetailView` (nil while loading).
    var heroImage: PlatformImage? = nil
    var onViewPhoto: (() -> Void)? = nil
    @Environment(\.openURL) private var openURL

    private var resolvedThumbnail: PlatformImage? {
        if item.kind == .media {
            return heroImage
        }
        return ThumbnailImageDecoding.uiImage(from: item.thumbnailData)
    }

    var body: some View {
        heroContent(thumbnail: resolvedThumbnail)
    }

    @ViewBuilder
    private func heroContent(thumbnail: PlatformImage?) -> some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .overlay {
                    if let thumbnail {
                        Image(platformImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color(hex: item.thumbnailColorHex ?? AppPalette.thumbnailFallbackHex)
                            Image(systemName: iconName)
                                .font(.system(size: 64 * 0.35))
                                .foregroundStyle(AppPalette.floralWhite.opacity(0.85))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()

            if item.kind == .web, item.originalURL != nil {
                heroCapsuleButton(title: "Visit Site") {
                    if let url = item.originalURL { openURL(url) }
                }
            } else if item.kind == .media, onViewPhoto != nil {
                heroCapsuleButton(title: "View Photo") {
                    onViewPhoto?()
                }
            }
        }
    }

    private var iconName: String {
        switch item.kind {
        case .web: "globe"
        case .media: "photo"
        case .note: "note.text"
        }
    }

    private func heroCapsuleButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .phathomCapsuleCTALabel()
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .foregroundStyle(AppPalette.textPrimary)
                .background(AppPalette.accent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }
}
