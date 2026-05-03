import PhathomCore
import SwiftUI

struct TagChipsView: View {
    let tags: [Tag]
    /// When provided, each chip becomes a tap target that calls back with the tapped tag.
    var onTap: ((Tag) -> Void)? = nil

    var body: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(tags, id: \.name) { tag in
                if let onTap {
                    Button {
                        onTap(tag)
                    } label: {
                        chipLabel(for: tag)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tag: \(tag.name)")
                    .accessibilityHint("Show related items")
                    .accessibilityAddTraits(.isButton)
                } else {
                    chipLabel(for: tag)
                }
            }
        }
    }

    private func chipLabel(for tag: Tag) -> some View {
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
