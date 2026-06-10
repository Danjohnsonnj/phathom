import PhathomCore
import XCTest

final class FocusWeeklyResetCalendarTests: XCTestCase {
    func testShouldShowWhenLibraryNonEmptyAndNotDismissedThisWeek() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let key = FocusWeeklyResetCalendar.isoWeekKey(for: now)
        XCTAssertTrue(
            FocusWeeklyResetCalendar.shouldShowPrompt(
                libraryItemCount: 3,
                dismissedWeekKey: nil,
                now: now
            )
        )
        XCTAssertFalse(
            FocusWeeklyResetCalendar.shouldShowPrompt(
                libraryItemCount: 3,
                dismissedWeekKey: key,
                now: now
            )
        )
    }

    func testShouldHideWhenLibraryEmpty() {
        XCTAssertFalse(
            FocusWeeklyResetCalendar.shouldShowPrompt(
                libraryItemCount: 0,
                dismissedWeekKey: nil
            )
        )
    }
}
