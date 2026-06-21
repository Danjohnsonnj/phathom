import PhathomCore
import SwiftUI

struct NotebookItemGroup: View {
    let item: ContentItem
    let highlights: [Highlight]
    var isExpanded: Bool
    var showsBottomGroupHairline: Bool = true
    var onHeaderTap: () -> Void
    var onToggleExpand: () -> Void
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
                                .appTypography(.galleryTitle)
                                .foregroundStyle(AppPalette.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 5)

                            if !subtitle.isEmpty {
                                Text(subtitle)
                                    .appTypography(.sourceLine)
                                    .foregroundStyle(AppPalette.textSecondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityHint("Opens item detail")
                .padding(.top, AppSpacing.notebookGroupHeaderTop)

                if !highlights.isEmpty {
                    Button(action: onToggleExpand) {
                        HStack(spacing: 0) {
                            Text(highlightsCountLabel)
                                .appTypography(.addNewAccentLabel)
                                .foregroundStyle(AppPalette.accent)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.textSecondary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                .frame(width: 44, height: 44)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .accessibilityLabel(isExpanded ? "Collapse highlights" : "Expand highlights")
                    .accessibilityHint("Double tap to expand or collapse.")
                }

                if isExpanded {
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

    private var highlightsCountLabel: String {
        let count = highlights.count
        return count == 1 ? "1 highlight" : "\(count) highlights"
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
