import PhathomCore
import SwiftUI

/// Expects `highlights` sorted by offset (pass `ContentItem.highlightsSortedByOffset`).
struct HighlightsNotesSection: View {
    var highlights: [Highlight]
    /// When true and there are no highlights, still show the header plus an empty-state hint (web detail UX).
    var showsEmptyPlaceholder: Bool = false
    var onTapHighlight: (Highlight) -> Void

    var body: some View {
        if highlights.isEmpty, !showsEmptyPlaceholder {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Highlights & Notes")
                    .appTypography(.zoneHeader)
                    .foregroundStyle(AppPalette.textPrimary)

                if highlights.isEmpty {
                    Text("No highlights")
                        .appTypography(.zoneSubtitle)
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(highlights.enumerated()), id: \.element.id) { index, highlight in
                            HairlineHighlightRow(
                                quotedText: highlight.quotedText,
                                userNote: highlight.userNote,
                                showsBottomHairline: index != highlights.count - 1,
                                onTap: { onTapHighlight(highlight) }
                            )
                        }
                    }
                }
            }
        }
    }
}
