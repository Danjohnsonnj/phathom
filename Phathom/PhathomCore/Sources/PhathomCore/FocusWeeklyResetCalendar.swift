import Foundation

/// Calendar-week gating for the Focus weekly reset prompt (Phase B5).
public enum FocusWeeklyResetCalendar {
    public static func isoWeekKey(for date: Date, calendar: Calendar = .current) -> String {
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return "\(year)-W\(week)"
    }

    /// Prompt when library has items and user has not dismissed for the current ISO week.
    public static func shouldShowPrompt(
        libraryItemCount: Int,
        dismissedWeekKey: String?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard libraryItemCount > 0 else { return false }
        let currentKey = isoWeekKey(for: now, calendar: calendar)
        return dismissedWeekKey != currentKey
    }
}
