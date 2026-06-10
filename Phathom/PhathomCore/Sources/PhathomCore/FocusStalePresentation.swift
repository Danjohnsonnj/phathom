import Foundation

/// Progressive stale treatment for Focus tab rows (Phase B).
public enum FocusStalePresentation {
    public static let washOpacityFactor = 0.22
    public static let untouchedLabelOpacityFloor = 0.55

    public static func daysUntouched(lastTouchedAt: Date, now: Date = .now) -> Int {
        FocusCalendar.wholeDays(from: lastTouchedAt, to: now)
    }

    public static func staleIntensity(daysUntouched: Int) -> Double {
        guard daysUntouched >= FocusStackConstants.staleUntouchedDays else { return 0 }
        return min(Double(daysUntouched - 6) / 7.0, 1.0)
    }

    public static func staleIntensity(lastTouchedAt: Date, now: Date = .now) -> Double {
        staleIntensity(daysUntouched: daysUntouched(lastTouchedAt: lastTouchedAt, now: now))
    }

    public static func untouchedLabel(daysUntouched: Int) -> String? {
        guard daysUntouched >= FocusStackConstants.staleUntouchedDays else { return nil }
        if daysUntouched == 1 {
            return "Untouched 1 day"
        }
        return "Untouched \(daysUntouched) days"
    }

    public static func untouchedLabelOpacity(staleIntensity: Double) -> Double {
        max(untouchedLabelOpacityFloor, staleIntensity)
    }

    public static func nudgeMessage(daysUntouched: Int) -> String {
        "\(daysUntouched) days untouched in Focus — still committed?"
    }

    public static func nudgeDismissalKey(entryID: UUID, lastTouchedAt: Date) -> String {
        "\(entryID.uuidString)|\(lastTouchedAt.timeIntervalSince1970)"
    }

    public static func nudgeDismissalKey(for entry: FocusEntry) -> String {
        nudgeDismissalKey(entryID: entry.id, lastTouchedAt: entry.lastTouchedAt)
    }

    public static func isStale(entry: FocusEntry, now: Date = .now) -> Bool {
        staleIntensity(lastTouchedAt: entry.lastTouchedAt, now: now) > 0
    }

    /// Most-stale eligible entry (highest `daysUntouched`, then lowest `sortOrder`).
    public static func nudgeCandidate(
        among entries: [FocusEntry],
        dismissedKeys: Set<String>,
        now: Date = .now
    ) -> FocusEntry? {
        entries
            .filter { isStale(entry: $0, now: now) }
            .filter { !dismissedKeys.contains(nudgeDismissalKey(for: $0)) }
            .max { lhs, rhs in
                let leftDays = daysUntouched(lastTouchedAt: lhs.lastTouchedAt, now: now)
                let rightDays = daysUntouched(lastTouchedAt: rhs.lastTouchedAt, now: now)
                if leftDays != rightDays { return leftDays < rightDays }
                return lhs.sortOrder > rhs.sortOrder
            }
    }
}
