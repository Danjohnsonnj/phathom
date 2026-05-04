import Foundation
import PhathomCore

/// Persists the `[UUID]` that the user committed to "Continue in background" at the moment of the
/// tap. The OS may wake `BackgroundContinuedAnalyze` minutes later (or after a relaunch via
/// app-switcher swipe + auto-relaunch), so the handler cannot assume in-memory state.
///
/// Backed by the App Group's `UserDefaults` suite so future moves to a Share Extension trigger
/// would also work; the snapshot is never larger than tens of UUIDs (the user's queue size).
nonisolated enum PendingSnapshotStore {
    private static let key = "com.phathom.continuedAnalyze.snapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: PhathomAppGroup.identifier)
    }

    /// Replace the snapshot. Empty array clears the entry.
    static func save(_ ids: [UUID]) {
        guard let defaults else { return }
        if ids.isEmpty {
            defaults.removeObject(forKey: key)
            return
        }
        let strings = ids.map { $0.uuidString }
        defaults.set(strings, forKey: key)
    }

    /// Read the snapshot. Returns an empty array if no snapshot was saved (or the saved value is
    /// malformed).
    static func load() -> [UUID] {
        guard
            let defaults,
            let strings = defaults.array(forKey: key) as? [String]
        else { return [] }
        return strings.compactMap(UUID.init(uuidString:))
    }

    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
