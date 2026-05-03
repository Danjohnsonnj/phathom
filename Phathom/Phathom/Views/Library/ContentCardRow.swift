import PhathomCore
import SwiftData
import SwiftUI

enum ContentCardRowChrome {
    /// Full card surface (Library and navigation links).
    case card
    /// Text + thumbnail only — avoids stacking card chrome inside scroll rows.
    case plain
}

struct ContentCardRow: View {
    let item: ContentItem
    var chrome: ContentCardRowChrome = .card

    @Environment(\.modelContext) private var modelContext

    private static let timestampFormat = Date.FormatStyle()
        .month(.abbreviated)
        .day()
        .year()
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute()
        .locale(.init(identifier: "en_US_POSIX"))

    var body: some View {
        Group {
            if chrome == .card {
                rowContent
                    .padding(12)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            ThumbnailView(
                thumbnailData: item.thumbnailData,
                colorHex: item.thumbnailColorHex,
                contentKind: item.kind,
                size: 76
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.headline)
                    .foregroundStyle(AppPalette.textPrimary)
                    .lineLimit(1)


                if item.status != .completed {
                    ProcessingStatusBadge(status: item.status, onTap: chipAction(for: item))
                } else {
                    Text(secondaryText)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(item.createdAt.formatted(Self.timestampFormat))
                        .font(.caption)
                        .foregroundStyle(AppPalette.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var secondaryText: String {
        switch item.kind {
        case .web:
            return item.displayHost ?? ""
        case .media, .note:
            if let d = item.mediaDescription, !d.isEmpty {
                let clean = SummaryLineSanitization.sanitizedBullet(d)
                if !clean.isEmpty { return clean }
            }
            if let first = item.displaySummaryBullets.first {
                return "Summary, \(first)"
            }
            return ""
        }
    }
}

struct ProcessingStatusBadge: View {
    let status: ProcessingStatus
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let label = ProcessingStatusPresentation.label(for: status) {
            let chip = chipContent(label: label)
            if let onTap {
                Button(action: onTap) {
                    chip
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .accessibilityLabel("Status: \(label)")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(accessibilityHint)
            } else {
                chip
                    .accessibilityLabel("Status: \(label)")
            }
        }
    }

    @ViewBuilder
    private func chipContent(label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: ProcessingStatusPresentation.symbolName(for: status))
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(AppPalette.metaChipBackground)
        .foregroundStyle(AppPalette.floralWhite)
        .clipShape(Capsule())
    }

    private var accessibilityHint: String {
        switch status {
        case .pending:
            "Try fetching now"
        case .failed:
            "Retry processing"
        default:
            ""
        }
    }
}
