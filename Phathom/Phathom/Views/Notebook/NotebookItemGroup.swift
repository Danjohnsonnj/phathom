import PhathomCore
import SwiftUI

struct NotebookItemGroup: View {
    let item: ContentItem
    let highlights: [Highlight]
    var onHeaderTap: () -> Void
    var onHighlightTap: (Highlight) -> Void

    private static let thumbnailSize: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onHeaderTap) {
                HStack(alignment: .top, spacing: 10) {
                    ThumbnailView(
                        thumbnailData: item.thumbnailData,
                        colorHex: item.thumbnailColorHex,
                        contentKind: item.kind,
                        size: Self.thumbnailSize
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.displayTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppPalette.accent)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundStyle(AppPalette.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens item detail")
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(highlights) { highlight in
                    HighlightCardView(
                        quotedText: highlight.quotedText,
                        userNote: highlight.userNote,
                        quotedLineLimit: 3,
                        noteLineLimit: 2,
                        onTap: { onHighlightTap(highlight) }
                    )
                }
            }
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .web:
            return item.displayHost ?? ""
        case .media:
            return "Photo"
        case .note:
            return "Note"
        }
    }
}
