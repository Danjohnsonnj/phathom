import PhathomCore
import SwiftUI

struct TagChipsView: View {
    let tags: [Tag]

    var body: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(tags, id: \.name) { tag in
                Text(tag.name.localizedCapitalized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppPalette.accent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppPalette.tagChipBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}
