import Foundation
import PhathomCore

enum FocusWeeklyResetStorage {
    private static let dismissedWeekKey = "phathom.focus.weeklyResetDismissedWeek"

    static func dismissedWeekKeyValue() -> String? {
        UserDefaults.standard.string(forKey: dismissedWeekKey)
    }

    static func dismissForCurrentWeek(now: Date = .now) {
        let key = FocusWeeklyResetCalendar.isoWeekKey(for: now)
        UserDefaults.standard.set(key, forKey: dismissedWeekKey)
    }

    static func shouldShowPrompt(libraryItemCount: Int, now: Date = .now) -> Bool {
        FocusWeeklyResetCalendar.shouldShowPrompt(
            libraryItemCount: libraryItemCount,
            dismissedWeekKey: dismissedWeekKeyValue(),
            now: now
        )
    }
}
