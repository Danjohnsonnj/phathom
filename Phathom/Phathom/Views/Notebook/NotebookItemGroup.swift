import PhathomCore
import SwiftUI

struct NotebookItemGroup: View {
    let item: ContentItem
    let highlights: [Highlight]
    var showsBottomGroupHairline: Bool = true
    var onHeaderTap: () -> Void
    var onHighlightTap: (Highlight) -> Void

    private static let thumbnailSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onHeaderTap) {
                    HStack(alignment: .top, spacing: 14) {
                        ThumbnailView(
                            thumbnailData: item.thumbnailData,
                            colorHex: item.thumbnailColorHex,
                            contentKind: item.kind,
                            size: Self.thumbnailSize,
                            cornerRadius: AppSpacing.thumbCornerRadius
                        )

                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.displayTitle)
                                .font(.system(size: 16, weight: .medium))
                                .tracking(-0.32)
                                .foregroundStyle(AppPalette.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 5)

                            if !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppPalette.textSecondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens item detail")
                .padding(.top, 16)
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: AppSpacing.highlightStackGap) {
                    ForEach(highlights) { highlight in
                        HairlineHighlightRow(
                            quotedText: highlight.quotedText,
                            userNote: highlight.userNote,
                            quotedLineLimit: 3,
                            noteLineLimit: 2,
                            showsBottomHairline: false,
                            verticalPadding: 0,
                            onTap: { onHighlightTap(highlight) }
                        )
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, showsBottomGroupHairline ? 20 : 8)

            if showsBottomGroupHairline {
                Rectangle()
                    .fill(AppPalette.hairline)
                    .frame(height: 1)
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
