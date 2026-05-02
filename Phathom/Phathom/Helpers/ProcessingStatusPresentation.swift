import PhathomCore
import Foundation

/// User-facing labels and icons for `ProcessingStatus`, shared by Library badge and Detail chip.
enum ProcessingStatusPresentation {
    nonisolated static func label(for status: ProcessingStatus) -> String? {
        switch status {
        case .pending:
            return "Queued"
        case .scraping:
            return "Fetching source"
        case .embedding:
            return "Preparing analysis"
        case .summarizing:
            return "Generating summary"
        case .tagging:
            return "Creating tags"
        case .completed:
            return nil
        case .failed:
            return "Needs attention"
        }
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
