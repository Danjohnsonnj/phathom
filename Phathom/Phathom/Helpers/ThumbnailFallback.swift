import PhathomCore
import SwiftUI
import UIKit

struct ThumbnailView: View {
    let thumbnailData: Data?
    let colorHex: String?
    let contentKind: ContentKind
    let size: CGFloat

    var body: some View {
        Group {
            if let data = thumbnailData, let uiImage = UIImage(data: data) {
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
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
    }

    private var iconName: String {
        switch contentKind {
        case .web: "globe"
        case .media: "photo"
        case .note: "note.text"
        }
    }
}
