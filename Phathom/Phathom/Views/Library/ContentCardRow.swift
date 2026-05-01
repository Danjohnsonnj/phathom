import SwiftData
import SwiftUI

struct ContentCardRow: View {
    let item: ContentItem

    private static let timestampFormat = Date.FormatStyle()
        .month(.abbreviated)
        .day()
        .year()
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute()
        .locale(.init(identifier: "en_US_POSIX"))

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ThumbnailView(
                thumbnailData: item.thumbnailData,
                colorHex: item.thumbnailColorHex,
                contentKind: item.kind,
                size: 76
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)

                Text(secondaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if item.status != .completed {
                        ProcessingStatusBadge(status: item.status)
                    }
                    Text(item.createdAt.formatted(Self.timestampFormat))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var secondaryText: String {
        switch item.kind {
        case .web:
            return item.displayHost ?? ""
        case .media, .note:
            if let d = item.mediaDescription, !d.isEmpty {
                return d
            }
            if let first = item.decodedSummaryBullets.first {
                return "Summary, \(first)"
            }
            return ""
        }
    }
}

struct ProcessingStatusBadge: View {
    let status: ProcessingStatus

    var body: some View {
        HStack(spacing: 4) {
            if status == .pending {
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))
            } else if status == .failed {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption.weight(.semibold))
            } else {
                ProgressView()
                    .scaleEffect(0.65)
                    .tint(.white)
            }
            Text(badgeLabel)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.accentColor)
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }

    private var badgeLabel: String {
        switch status {
        case .pending: "Pending"
        case .failed: "Failed"
        default: "Processing"
        }
    }
}
