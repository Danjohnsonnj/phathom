import Foundation
import UIKit

/// Ref-counted wrapper around `UIApplication.isIdleTimerDisabled` so multiple concurrent foreground
/// drains (capture finished + share extension Darwin notify + scene-active) cooperate without one
/// re-enabling the lock screen while another is still working.
///
/// Why disable the idle timer: long foreground LLM drains (3-8 k token prefills, multi-second decodes)
/// can outlast the user's display sleep timeout. When the screen locks, iOS suspends the app within
/// ~30 s, killing the in-flight `llama_decode` and stranding rows in `summarizing`/`tagging`.
/// `reviveAbortedPipelineItems` will recover them on next launch, but the user-visible delay is bad.
@MainActor
enum IdleTimerCoordinator {
    private static var refCount: Int = 0

    /// Increment the ref count and disable the idle timer if this is the first holder.
    /// Pair every call with `release()`; failing to release leaks the disabled state until app exit.
    static func acquire() {
        refCount += 1
        if refCount == 1 {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    /// Decrement the ref count and re-enable the idle timer if no holders remain.
    static func release() {
        guard refCount > 0 else { return }
        refCount -= 1
        if refCount == 0 {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
