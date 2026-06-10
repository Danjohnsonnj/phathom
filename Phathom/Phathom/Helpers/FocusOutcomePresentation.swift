import Foundation
import PhathomCore

/// User-facing labels for `FocusOutcomeKind` and closure copy on Detail.
enum FocusOutcomePresentation {
    nonisolated static func label(for kind: FocusOutcomeKind) -> String {
        switch kind {
        case .reference: return "Reference"
        case .takeaway: return "Takeaway"
        case .revisit: return "Revisit"
        case .release: return "Release"
        }
    }

    nonisolated static func closureLine(for outcome: FocusOutcome) -> String {
        let kindLabel = label(for: outcome.kind)
        let dateLabel = outcome.completedAt.formatted(closureDateFormat)
        return "\(kindLabel) · completed \(dateLabel)"
    }

    private static let closureDateFormat = Date.FormatStyle()
        .month(.abbreviated)
        .day()
}
