import PhathomCore
import Foundation

/// User-facing labels and icons for `ProcessingStatus`, shared by Library badge and Detail chip.
enum ProcessingStatusPresentation {
    nonisolated static let embeddingChipLabel = "Ready to analyze"

    nonisolated static var embeddingProcessingDetail: String {
        ProcessingStatusCopy.embeddingProcessingDetail
    }

    nonisolated static var pauseStoppingDetail: String {
        ProcessingStatusCopy.pauseStoppingDetail
    }

    nonisolated static func label(for status: ProcessingStatus, contentKind: ContentKind? = nil) -> String? {
        switch status {
        case .pending:
            return "Queued"
        case .scraping:
            return "Fetching source"
        case .embedding:
            return embeddingChipLabel
        case .summarizing:
            if contentKind == .media {
                return "Analyzing photo"
            }
            return "Generating summary"
        case .extracting:
            return "Extracting details"
        case .tagging:
            return "Creating tags"
        case .completed:
            return nil
        case .failed:
            return "Needs attention"
        }
    }

    nonisolated static func chipLabel(
        for status: ProcessingStatus,
        contentKind: ContentKind? = nil,
        processingDetail: String?
    ) -> String? {
        if let detail = processingDetail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
            return detail
        }
        return label(for: status, contentKind: contentKind)
    }

    nonisolated static func symbolName(for status: ProcessingStatus) -> String {
        switch status {
        case .pending:
            return "clock"
        case .failed:
            return "exclamationmark.circle"
        case .completed:
            return "checkmark.circle"
        default:
            return "arrow.triangle.2.circlepath"
        }
    }
}
