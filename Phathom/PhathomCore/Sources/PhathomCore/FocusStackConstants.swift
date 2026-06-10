import Foundation

public enum FocusStackConstants {
    /// Fixed v1 cap on active `FocusEntry` rows among non-archived items.
    public static let maxActiveEntries = 7
    /// Days without engagement before stale UI (Phase B); field writes begin in Phase A.
    public static let staleUntouchedDays = 7
}
