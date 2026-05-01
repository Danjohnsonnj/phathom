import SwiftUI
import UIKit

struct HeroSection: View {
    let item: ContentItem
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let data = item.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color(hex: item.thumbnailColorHex ?? "#5E5CE6")
                        Image(systemName: iconName)
                            .font(.system(size: 64 * 0.35))
                            .foregroundStyle(.white.opacity(0.7))
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
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
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
