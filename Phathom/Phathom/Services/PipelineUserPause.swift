import Foundation

/// User-initiated global pipeline pause. Persisted in `UserDefaults`; survives relaunch until Library Resume.
enum PipelineUserPause: Sendable {
    static let defaultsKey = "phathom.pipeline.userPaused"

    private static let lock = NSLock()

    nonisolated static var isPaused: Bool {
        lock.lock()
        defer { lock.unlock() }
        return UserDefaults.standard.bool(forKey: defaultsKey)
    }

    nonisolated static func setPaused(_ paused: Bool) {
        lock.lock()
        UserDefaults.standard.set(paused, forKey: defaultsKey)
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .phathomPipelinePauseDidChange, object: nil)
        }
    }

    #if DEBUG
    /// Test-only: clears persisted pause without posting (tests set explicitly when needed).
    nonisolated static func _test_clearPause() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        lock.unlock()
    }
    #endif
}
