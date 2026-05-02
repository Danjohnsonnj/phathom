import Foundation

/// FIFO async mutex. One waiter holds the lock at a time; `acquire` suspends until the previous holder calls `release`.
/// Not re-entrant — do not `acquire` twice from the same task without releasing.
actor AsyncLock {
    private var locked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !locked {
            locked = true
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            waiters.append(cont)
        }
    }

    func release() {
        if waiters.isEmpty {
            locked = false
        } else {
            waiters.removeFirst().resume()
        }
    }

    /// Acquire, run `work`, then release — even when `work` throws.
    func withLock<R: Sendable>(_ work: @Sendable () async throws -> R) async rethrows -> R {
        await acquire()
        do {
            let value = try await work()
            release()
            return value
        } catch {
            release()
            throw error
        }
    }
}
