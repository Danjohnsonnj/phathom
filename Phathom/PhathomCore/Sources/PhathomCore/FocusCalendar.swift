import Foundation

public enum FocusCalendar {
    /// Whole calendar days from `start` to `end` using start-of-day semantics.
    public static func wholeDays(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }
}
