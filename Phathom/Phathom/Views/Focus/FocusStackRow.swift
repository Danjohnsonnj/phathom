import PhathomCore
import SwiftUI

struct FocusStackRow: View {
    let entry: FocusEntry
    var showsBottomHairline: Bool = true
    var now: Date = .now

    private static let thumbSize: CGFloat = 64

    private var item: ContentItem? { entry.contentItem }

    private var daysInFocus: Int {
        FocusCalendar.wholeDays(from: entry.addedAt, to: now)
    }

    private var daysInFocusLabel: String {
        if daysInFocus == 1 {
            return "1 day in focus"
        }
        return "\(daysInFocus) days in focus"
    }

    private var daysUntouched: Int {
        FocusStalePresentation.daysUntouched(lastTouchedAt: entry.lastTouchedAt, now: now)
    }

    private var staleIntensity: Double {
        FocusStalePresentation.staleIntensity(daysUntouched: daysUntouched)
    }

    var body: some View {
        if let item {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    ThumbnailView(
                        thumbnailData: item.thumbnailData,
                        colorHex: item.thumbnailColorHex,
                        contentKind: item.kind,
                        size: Self.thumbSize,
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

                        if !sourceLine(for: item).isEmpty {
                            Text(sourceLine(for: item))
                                .appTypography(.sourceLine)
                                .foregroundStyle(AppPalette.textSecondary)
                                .lineLimit(1)
                                .padding(.bottom, 6)
                        }

                        focusMetaRow(for: item)

                        if let summary = summarySnippet(for: item) {
                            Text(summary)
                                .appTypography(.zoneSubtitle)
                                .foregroundStyle(AppPalette.textSecondary.opacity(0.85))
                                .lineLimit(1)
                                .padding(.bottom, 4)
                        }

                        Text(highlightCountLabel(for: item))
                            .appTypography(.meta)
                            .foregroundStyle(AppPalette.textSecondary.opacity(0.55))
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, AppSpacing.galleryRowVertical)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .background {
                    if staleIntensity > 0 {
                        Color.orange.opacity(staleIntensity * FocusStalePresentation.washOpacityFactor)
                    }
                }
                .overlay(alignment: .leading) {
                    if staleIntensity > 0 {
                        Rectangle()
                            .fill(Color.orange.opacity(staleIntensity))
                            .frame(width: 3)
                    }
                }

                if showsBottomHairline {
                    Rectangle()
                        .fill(AppPalette.hairline)
                        .frame(height: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func focusMetaRow(for item: ContentItem) -> some View {
        HStack(spacing: 8) {
            Text(daysInFocusLabel)
                .appTypography(.meta)
                .foregroundStyle(AppPalette.textSecondary.opacity(0.72))

            Text("·")
                .appTypography(.meta)
                .foregroundStyle(AppPalette.textSecondary.opacity(0.35))

            readStatusChrome(for: item.readState)

            if let untouchedLabel = FocusStalePresentation.untouchedLabel(daysUntouched: daysUntouched) {
                Text("·")
                    .appTypography(.meta)
                    .foregroundStyle(AppPalette.textSecondary.opacity(0.35))

                Text(untouchedLabel)
                    .appTypography(.captionSemibold)
                    .foregroundStyle(
                        Color.orange.opacity(
                            FocusStalePresentation.untouchedLabelOpacity(staleIntensity: staleIntensity)
                        )
                    )
            }
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func readStatusChrome(for status: ReadStatus) -> some View {
        switch status {
        case .new:
            Circle()
                .fill(AppPalette.accent)
                .frame(width: 7, height: 7)
                .accessibilityLabel("New")
        case .read, .filed:
            Text(ReadStatusPresentation.label(for: status))
                .appTypography(.captionSemibold)
                .foregroundStyle(AppPalette.textSecondary.opacity(0.65))
        }
    }

    private func sourceLine(for item: ContentItem) -> String {
        switch item.kind {
        case .web:
            return item.displayHost ?? ""
        case .media, .note:
            if let description = item.mediaDescription, !description.isEmpty {
                let clean = SummaryLineSanitization.sanitizedBullet(description)
                if !clean.isEmpty { return clean }
            }
            if let first = item.displaySummaryBullets.first {
                return "Summary, \(first)"
            }
            return ""
        }
    }

    private func summarySnippet(for item: ContentItem) -> String? {
        item.displaySummaryBullets.first
    }

    private func highlightCountLabel(for item: ContentItem) -> String {
        let count = item.highlights.count
        if count == 1 {
            return "1 highlight"
        }
        return "\(count) highlights"
    }
}
