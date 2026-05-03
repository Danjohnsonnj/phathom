import PhathomCore
import SwiftUI
import UIKit

struct HeroSection: View {
    let item: ContentItem
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .bottom) {
            // Use Color.clear as the layout anchor so the image overlay never reports a
            // fill-scaled width as its layout size. Without this, a wide OG image (e.g. 3:1
            // banner) would make the VStack wider than the viewport, causing ScrollView to
            // centre its content and clip both horizontal edges.
            Color.clear
                .overlay {
                    if let data = item.thumbnailData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
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
                Button {
                    if let url = item.originalURL {
                        openURL(url)
                    }
                } label: {
                    Text("Visit Site")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.floralWhite)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(AppPalette.accent)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 16)
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var iconName: String {
        switch item.kind {
        case .web: "globe"
        case .media: "photo"
        case .note: "note.text"
        }
    }
}
