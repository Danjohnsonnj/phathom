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
                    Color(hex: colorHex ?? "#5E5CE6")
                    Image(systemName: iconName)
                        .font(.system(size: size * 0.35))
                        .foregroundStyle(.white.opacity(0.7))
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
