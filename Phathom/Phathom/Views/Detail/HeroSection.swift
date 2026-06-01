import PhathomCore
import SwiftUI
import UIKit

struct HeroSection: View {
  let item: ContentItem
  /// Pre-decoded media hero image from `DetailView` (nil while loading).
  var heroImage: UIImage? = nil
  var onViewPhoto: (() -> Void)? = nil
  @Environment(\.openURL) private var openURL

  private var resolvedThumbnail: UIImage? {
    if item.kind == .media {
      return heroImage
    }
    return ThumbnailImageDecoding.uiImage(from: item.thumbnailData)
  }

  var body: some View {
    heroContent(thumbnail: resolvedThumbnail)
  }

  @ViewBuilder
  private func heroContent(thumbnail: UIImage?) -> some View {
    ZStack(alignment: .bottom) {
      // Use Color.clear as the layout anchor so the image overlay never reports a
      // fill-scaled width as its layout size. Without this, a wide OG image (e.g. 3:1
      // banner) would make the VStack wider than the viewport, causing ScrollView to
      // centre its content and clip both horizontal edges.
      Color.clear
        .overlay {
          if let thumbnail {
            Image(uiImage: thumbnail)
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
          if let url = item.originalURL {
            openURL(url)
          }
        }
      } else if item.kind == .media, thumbnail != nil, let onViewPhoto {
        heroCapsuleButton(title: "View Photo", action: onViewPhoto)
          .accessibilityHint("Opens full screen photo viewer")
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func heroCapsuleButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .phathomToolbarTextLabel()
        .foregroundStyle(AppPalette.floralWhite)
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(AppPalette.accent)
        .clipShape(Capsule())
    }
    .padding(.bottom, 16)
    .buttonStyle(.plain)
  }

  private var iconName: String {
    switch item.kind {
    case .web: "globe"
    case .media: "photo"
    case .note: "note.text"
    }
  }
}
