import PhathomCore
import SwiftData
import SwiftUI

/// Library gallery row — hairline material, 64×64 thumb, no filled card (§3.4).
struct GalleryListRow: View {
    let item: ContentItem
    var showsBottomHairline: Bool = true

    @Environment(\.modelContext) private var modelContext

    private static let thumbSize: CGFloat = 64
    private static let trailingSignalSize: CGFloat = 22
    private static let trailingSignalTextGap: CGFloat = 6

    private static let dateFormat = Date.FormatStyle()
        .month(.abbreviated)
        .day()
        .locale(.init(identifier: "en_US_POSIX"))

    var body: some View {
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
                    HStack(alignment: .top, spacing: 6) {
                        if item.readState == .new {
                            Circle()
                                .fill(AppPalette.accent)
                                .frame(width: 7, height: 7)
                                .padding(.top, 6)
                                .accessibilityLabel("Unread")
                                .accessibilityAddTraits(.isStaticText)
                        }

                        Text(item.displayTitle)
                            .font(.system(size: 16, weight: .medium))
                            .tracking(-0.32)
                            .foregroundStyle(AppPalette.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, 5)

                    if !sourceLine.isEmpty {
                        Text(sourceLine)
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.textSecondary)
                            .lineLimit(1)
                            .padding(.bottom, 6)
                    }

                    metaRow
                }
                .padding(.top, 2)
                .padding(
                    .trailing,
                    trailingSignal != nil ? Self.trailingSignalSize + Self.trailingSignalTextGap : 0
                )
            }
            .padding(.vertical, AppSpacing.galleryRowVertical)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .overlay(alignment: .trailing) {
                if let trailingSignal {
                    trailingSignalIcon(trailingSignal)
                        .padding(.trailing, AppSpacing.screenHorizontal)
                }
            }

            if showsBottomHairline {
                Rectangle()
                    .fill(AppPalette.hairline)
                    .frame(height: 1)
            }
        }
    }

    private enum TrailingSignal {
        case inFocus
        case revisitDue
    }

    private var trailingSignal: TrailingSignal? {
        if FocusStackService.isInFocus(item) {
            return .inFocus
        }
        if FocusStackService.dueForRevisit(item, in: modelContext) {
            return .revisitDue
        }
        return nil
    }

    @ViewBuilder
    private func trailingSignalIcon(_ signal: TrailingSignal) -> some View {
        switch signal {
        case .inFocus:
            Image(systemName: "scope")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppPalette.accent)
                .frame(width: Self.trailingSignalSize, height: Self.trailingSignalSize)
                .accessibilityLabel("In Focus")
        case .revisitDue:
            Image(systemName: "clock")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppPalette.textSecondary.opacity(0.85))
                .frame(width: Self.trailingSignalSize, height: Self.trailingSignalSize)
                .accessibilityLabel("Revisit due")
        }
    }

    @ViewBuilder
    private var metaRow: some View {
        HStack(spacing: 8) {
            if item.status != .completed {
                ProcessingStatusBadge(
                    status: item.status,
                    contentKind: item.kind,
                    processingDetail: item.processingDetail,
                    onTap: chipAction(for: item)
                )
            } else {
                Text(item.createdAt.formatted(Self.dateFormat))
                    .font(.system(size: 12))
                    .foregroundStyle(AppPalette.textSecondary.opacity(0.65))
                    .tracking(0.24)
            }
        }
    }

    private func chipAction(for item: ContentItem) -> (() -> Void)? {
        switch item.status {
        case .pending where item.kind == .web:
            return {
                BackgroundPipeline.scheduleForegroundDrain()
                BackgroundPipeline.scheduleIngest()
            }
        case .failed where ProcessingRecovery.canRetryFailed(item):
            return {
                _ = ProcessingRecovery.retryFailedItemIfNeeded(item, modelContext: modelContext)
            }
        default:
            return nil
        }
    }

    private var sourceLine: String {
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
}

#Preview {
    GalleryListRowPreview()
        .modelContainer(PreviewModel.makeContainer())
}

private struct GalleryListRowPreview: View {
    @Query(sort: \ContentItem.createdAt, order: .reverse) private var items: [ContentItem]

    var body: some View {
        if let item = items.first {
            GalleryListRow(item: item)
                .background(AppPalette.background)
        }
    }
}
