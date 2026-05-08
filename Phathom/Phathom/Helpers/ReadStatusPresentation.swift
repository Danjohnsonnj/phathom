import PhathomCore
import SwiftUI

/// User-facing labels, SF Symbols, and tints for `ReadStatus`.
/// Shared by the Library filter dropdown, swipe actions, and any future Detail-level affordance.
enum ReadStatusPresentation {
    nonisolated static func label(for status: ReadStatus) -> String {
        switch status {
        case .new: return "New"
        case .read: return "Read"
        case .filed: return "Filed"
        }
    }

    nonisolated static func symbolName(for status: ReadStatus) -> String {
        switch status {
        case .new: return "circle.inset.filled"
        case .read: return "envelope.open"
        case .filed: return "tray.and.arrow.down"
        }
    }

    static func swipeTint(for status: ReadStatus) -> Color {
        switch status {
        case .new: return .blue
        case .read: return .gray
        case .filed: return .green
        }
    }

    /// Verb form used as the leading-swipe button label so the action reads as an imperative
    /// ("Mark New", "Mark Read", "File") rather than a noun.
    nonisolated static func swipeActionLabel(for status: ReadStatus) -> String {
        switch status {
        case .new: return "Mark New"
        case .read: return "Mark Read"
        case .filed: return "File"
        }
    }
}
