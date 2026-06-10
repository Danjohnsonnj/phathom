import Foundation
import PhathomCore

enum FocusStaleNudgeStorage {
    private static let defaultsKey = "phathom.focus.staleNudgeDismissals"

    static func loadDismissedKeys() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
    }

    static func dismiss(entry: FocusEntry) {
        var keys = loadDismissedKeys()
        keys.insert(FocusStalePresentation.nudgeDismissalKey(for: entry))
        UserDefaults.standard.set(Array(keys), forKey: defaultsKey)
    }
}
