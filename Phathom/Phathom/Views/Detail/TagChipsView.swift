import PhathomCore
import SwiftUI

struct TagChipsView: View {
    let tags: [Tag]
    /// When provided, each chip becomes a tap target that calls back with the tapped tag.
    var onTap: ((Tag) -> Void)? = nil
    /// Optional accessibility hint provider for each chip action.
    var accessibilityHintProvider: ((Tag) -> String)? = nil
    /// Optional inline action rendered as a chip (used by detail tag edit mode).
    var addActionTitle: String? = nil
    var onAddAction: (() -> Void)? = nil

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
                    .accessibilityHint(accessibilityHintProvider?(tag) ?? "Activate tag action")
                    .accessibilityAddTraits(.isButton)
                } else {
                    chipLabel(for: tag)
                }
            }
            if let addActionTitle, let onAddAction {
                Button {
                    onAddAction()
                } label: {
                    Text(addActionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.textPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppPalette.surfaceNested)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(addActionTitle)
                .accessibilityHint("Add tag")
                .accessibilityAddTraits(.isButton)
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
