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
                    .font(.headline.bold())
                    .foregroundStyle(AppPalette.textPrimary)

                if highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No highlights")
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(highlights) { highlight in
                            highlightCard(highlight)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func highlightCard(_ highlight: Highlight) -> some View {
        Button {
            onTapHighlight(highlight)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(highlight.quotedText)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let note = highlight.userNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.surface)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(AppPalette.accent)
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
