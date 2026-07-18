import PhathomCore
import SwiftUI

/// Expects `highlights` sorted by offset (pass `ContentItem.highlightsSortedByOffset`).
struct HighlightsNotesSection: View {
    var highlights: [Highlight]
    /// When true and there are no highlights, still show the header plus an empty-state hint (web detail UX).
    var showsEmptyPlaceholder: Bool = false
    var onTapHighlight: (Highlight) -> Void

    @State private var isExpanded = false

    private static let sectionTitle = "Highlights & Notes"

    private var collapsedHighlightsPreviewMaxHeight: CGFloat {
        #if os(iOS)
        let lineHeight = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
        #else
        let lineHeight = NSFont.preferredFont(forTextStyle: .subheadline).boundingRectForFont.size.height
        #endif
        return ceil(lineHeight) + 4
    }

    @ViewBuilder
    private var highlightsBody: some View {
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
                        verticalPadding: isExpanded ? 16 : 8,
                        onTap: { onTapHighlight(highlight) }
                    )
                }
            }
        }
    }

    var body: some View {
        if highlights.isEmpty, !showsEmptyPlaceholder {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Self.sectionTitle)
                            .appTypography(.zoneHeader)
                            .foregroundStyle(AppPalette.textPrimary)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(isExpanded ? "show less" : "show more")
                                .appTypography(.addNewAccentLabel)
                                .foregroundStyle(AppPalette.accent)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.accent)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isExpanded
                        ? "\(Self.sectionTitle), expanded"
                        : "\(Self.sectionTitle), collapsed preview"
                )
                .accessibilityHint("Double tap to expand or collapse.")

                highlightsBody
                    .modifier(CollapsedPreviewClipModifier(
                        isExpanded: isExpanded,
                        maxHeight: collapsedHighlightsPreviewMaxHeight
                    ))
            }
        }
    }
}

private struct CollapsedPreviewClipModifier: ViewModifier {
    let isExpanded: Bool
    let maxHeight: CGFloat

    func body(content: Content) -> some View {
        if isExpanded {
            content
        } else {
            content
                .frame(maxHeight: maxHeight, alignment: .top)
                .clipped()
        }
    }
}

#Preview("Collapsed — empty") {
    HighlightsNotesSection(highlights: [], showsEmptyPlaceholder: true) { _ in }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .background(AppPalette.background)
}

#Preview("Collapsed — highlights") {
    HighlightsNotesSection(
        highlights: [
            Highlight(
                sourceMarkdownOffset: 0,
                sourceMarkdownLength: 12,
                quotedText: "Token-to-learning is closer to the thing that matters when you measure outcomes instead of activity."
            ),
            Highlight(
                sourceMarkdownOffset: 40,
                sourceMarkdownLength: 8,
                quotedText: "Second highlight for expand preview."
            )
        ],
        showsEmptyPlaceholder: true
    ) { _ in }
    .padding(.horizontal, AppSpacing.screenHorizontal)
    .background(AppPalette.background)
}
