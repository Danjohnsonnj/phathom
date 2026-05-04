> **Status (2026-05-04): Implemented.** The recommendations in this document — foreground Metal, user-initiated CPU `BGContinuedProcessingTask`, no opportunistic LLM lane, defensive Metal teardown on resign-active — landed in `BackgroundContinuedAnalyze`, `SharedLlamaInference.withSession(backend:)`, `PendingSnapshotStore`, and the LibraryTab "Continue in background" banner. See [docs/decisions.md](../decisions.md) entries dated 2026-05-04. The opportunistic `com.phathom.analyze` `BGProcessingTask` lane (Mode 4 below) was dropped.

Plan **for iPhone 16 Pro on iOS 26.4 today** as if **background GPU does not exist**, because in practice it doesn't:

- `BGTaskScheduler.shared.supportedResources.contains(.gpu)` returns **`false`** on every shipped iPhone, including iPhone 16 Pro running iOS 26.4. Apple gated background GPU to **iPad only** despite documenting it as available "in iPadOS and iOS 26 on supported devices." iOS 26.4 release notes do not change this.
- Any attempt to submit Metal work in the background returns `kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted`. Older llama.cpp builds **`abort()` the process**; builds containing PR [#20306](https://github.com/ggml-org/llama.cpp/pull/20306) (merged 2026-03-09) fail gracefully but require recreating the Metal backend.
- This means the "tap to keep generating in the background" UX **cannot run on the GPU** on iPhone. It can run on llama.cpp's CPU backend inside a `BGContinuedProcessingTask`, which is fully sanctioned and works.

**Recommended product shape, given the constraint:**

| Mode                                            | Inference path                                               | iPhone behavior                                                                   | Notes                                                     |
| ----------------------------------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Foreground (default)                            | llama.cpp Metal                                              | Full speed. ~30–40 s/item.                                                        | Disable idle timer while a queue is draining.             |
| Foreground→background grace (~30 s)             | llama.cpp Metal                                              | Finish or checkpoint current item.                                                | `beginBackgroundTask`. Will not finish a fresh item.      |
| User-initiated "Process the rest in background" | llama.cpp **CPU** backend inside `BGContinuedProcessingTask` | Multiple-x slower per item, but reliable, on-charger-or-not.                      | iOS shows a Live Activity with progress. User can cancel. |
| Opportunistic (idle + plugged in)               | llama.cpp **CPU** backend inside `BGProcessingTask`          | Unreliable, gets killed when user picks up phone. **Recommend dropping from v1.** | No UI. Few minutes max.                                   |
| App switcher swipe                              | n/a                                                          | All work cancelled, no notification.                                              | Document this in onboarding.                              |

The cleanest v1 is **foreground Metal + a user-initiated CPU background lane via BGContinuedProcessingTask**. Drop the silent opportunistic lane until either Apple ships background GPU on iPhone or the workload acquires a privileged background mode (none of audio/location/VoIP/BLE/etc. legitimately apply).

---

## What changed from the prior assessment

The prior session recommended `BGContinuedProcessingTask` with `requiredResources = .gpu` as the user-initiated lane. **That recommendation is wrong on iPhone today.** The Apple Developer Forums thread linked below has Apple-side acknowledgement that background GPU is currently iPad-only. The entitlement (`com.apple.developer.background-tasks.continued-processing.gpu`) and the API surface exist, but `supportedResources` returns an empty / non-`.gpu` set on iPhone, and submitting `.gpu` resources will be rejected.

A separate but compounding fact: even on devices where background GPU _is_ available, when the OS revokes GPU access the Metal command buffer callback fires with the error above. llama.cpp's Metal context (`ggml-metal-context.m`) historically called `GGML_ABORT` here, killing the process. PR #20306 (March 2026) replaced that with a sticky `has_error` flag so subsequent `graph_compute` calls return `GGML_STATUS_FAILED`. Recovery requires recreating the backend.

Net: any iPhone background lane must be **CPU-only** until further notice, and the Metal backend's failure mode under unexpected revocation must be handled (do not hold a stale Metal backend across foreground↔background transitions if there's any chance work was in flight).

---

## Verified facts

### iOS 26.4 / iPhone 16 Pro

1. **Background GPU is not supported on any iPhone, as of iOS 26.4.** Confirmed by Apple Developer Forums responses: `BGTaskScheduler.shared.supportedResources.contains(.gpu) == false` on iPhone 15 Pro and iPhone 16 Pro. Background GPU is iPadOS-only. Likely intentional and battery-driven.
2. **iOS 26.4 release notes do not introduce iPhone background GPU.** No mention of `supportedResources` or background GPU expansion.
3. **`BGContinuedProcessingTask` itself is fully supported on iPhone for CPU work.** Apple's "Performing long-running tasks on iOS and iPadOS" doc explicitly enumerates CPU-bound use cases (Core Image, Vision, Accelerate). llama.cpp's CPU backend qualifies.
4. **System UX for `BGContinuedProcessingTask`:** The OS shows a Live Activity with title/subtitle/progress, with a user-accessible cancel button. App switcher swipe-kill cancels with no notification to the app.
5. **App must be foregrounded to _start_ a `BGContinuedProcessingTask`,** and the work must be tied to an explicit user action ("tap to keep going"). Automatic gesture-less submission is explicitly discouraged in the WWDC25 session and the docs.

### llama.cpp (ggml-org/llama.cpp)

1. **Cooperative cancellation is via `ggml_abort_callback`.** Originally added to llama.cpp via [PR #5409](https://github.com/ggml-org/llama.cpp/pull/5409) (March 2024). Works reliably for CPU and Metal backends; CUDA and other async backends have looser semantics.
2. **`llama_decode()` returns `ggml_status` values.** On abort, returns status `2`. On Metal failure post-PR-#20306, returns `GGML_STATUS_FAILED`.
3. **Recovery from a failed Metal backend** (e.g., after GPU access was revoked): release and recreate the backend. The error flag is sticky.
4. **Apple Silicon Metal is a first-class backend** for llama.cpp. The repo ships an official prebuilt **XCFramework** (Swift Package `binaryTarget`) — no need to build from source. See the `build-xcframework.sh` script and the README's "XCFramework" section.
5. **CPU performance on Apple A-series can be competitive with Metal for small models.** Reported result on iPhone 15 Pro for a 1B model: CPU 2-thread F16 ≈ 17 t/s vs Metal ≈ 12.8 t/s (single data point, but suggestive). For larger or multimodal models the gap widens in Metal's favor; do not extrapolate without benchmarking your specific model.
6. **There is an existing iOS Swift example** under `examples/` historically (`llama.swiftui`) that uses the C API directly from Swift. Useful prior art for wiring abort callbacks and `llama_decode` loops from a Swift `Task`.

---

## Recommended architecture (iPhone-only, iOS 26.4)

Four runtime modes, each mapped to the iOS API that actually fits, with the CPU/Metal split being the load-bearing decision.

### Mode 1 — Foreground (default, Metal)

App is foregrounded → drain queue normally on the Metal backend. No iOS limits beyond thermals and battery.

- Set `UIApplication.shared.isIdleTimerDisabled = true` while a queue is actively draining and the user has the screen on. Reset to `false` when the queue empties or the app backgrounds.
- Treat each item as an atomic unit; persist completion to disk per item so that if the app dies between items there is no replay confusion.

### Mode 2 — Foreground→background grace (~30 s, Metal)

The instant the app receives `applicationWillResignActive`/scene equivalent, you have ~30 s before the system suspends. Wrap the in-flight item in `beginBackgroundTask`:

- If the current item is far along, let it finish, then `endBackgroundTask`.
- If the current item is fresh, set `should_stop` (your `ggml_abort_callback` flag) so `llama_decode` returns early; checkpoint state and `endBackgroundTask`.
- **Tear down the Metal backend before the suspension lands** to avoid the GPU-revocation failure mode if the OS happens to re-wake briefly. Keep weights mmap'd; releasing only the backend (not the model) is cheap to recreate on next foregrounding.

### Mode 3 — User-initiated "Process the rest in background" (CPU, BGContinuedProcessingTask)

This is the v1 long-running lane. UX:

> User taps "Keep generating in background" on the queue screen → the system shows a Live Activity titled e.g. "Generating responses · 4 items remaining" → user can leave the app, switch tasks, or cancel from the Live Activity.

Plumbing:

- **Capability:** Background Modes → Background processing. **Do not** add the Background GPU Access capability for v1; you can't use it on iPhone and adding the entitlement may complicate App Review later when there's no actual iPad target.
- **`Info.plist`** → `BGTaskSchedulerPermittedIdentifiers` array contains your task ID, e.g. `com.yourapp.inference.queue` (or wildcard `com.yourapp.inference.*`).
- **Switch the inference engine to the CPU backend** when this task starts. Either keep two `llama_context` instances initialized (CPU and Metal) and route to the right one, or release the Metal backend and reinitialize CPU on entry. The latter is cheaper on memory but slower at task start.
- **Hook the `ggml_abort_callback`** so the task's `expirationHandler` flips `should_stop = true` and the next `llama_decode` returns status 2. Be sure your Swift wrapper actually wires this into `llama_context_params` — it's not on by default.
- **Report progress aggressively** — sub-item progress (token count or layer iteration) is much better than per-item. The system kills tasks that report no progress for too long.
- **Use `task.updateTitle(_:subtitle:)`** to keep the Live Activity informative ("Item 2 of 4 · 47%").
- **Submission strategy:** `.queue` for production (let the system schedule when ready). Use `.fail` during development to get loud immediate failures.
- **App switcher swipe kills the task without notifying the app.** Persist progress to disk often enough that a kill is recoverable on next launch.

### Mode 4 — Opportunistic (CPU, BGProcessingTask) — **drop for v1**

If you wanted this anyway, the only viable shape is:

- `BGProcessingTaskRequest` with `requiresExternalPower = true`, `requiresNetworkConnectivity = false`.
- CPU backend only.
- Killed instantly when the user touches the device.
- Scheduling is unreliable on TestFlight builds (the scheduler favors apps with high engagement).

Recommendation: **do not ship this in v1.** It will look broken to TestFlight users (they expect "opportunistic" to mean "happens automatically" but in practice it almost never runs) and adds review surface area. Revisit only if Apple opens iPhone background GPU.

---

## What to tell the user in the UI

Wording matters here because the gap between what people _think_ iOS does in the background and what it actually does is large.

- **Default copy when there are queued items:** `Generating <N> response<s>. Keep this screen open or tap "Keep going in background".`
- **Background lane button copy:** `Keep going in background — slower, runs on CPU` (don't promise GPU speed; users will time it).
- **First-time onboarding tip:** `If you swipe the app away from the app switcher, in-progress generations stop. Background generations always show in your Lock Screen.`
- **Don't promise:** "automatic background processing", "processes overnight while charging", "syncs automatically." None of those are deliverable on iPhone for GPU LLM work in iOS 26.4.

---

## Concrete code skeletons

### Cancellation flag wired to llama.cpp `ggml_abort_callback`

```swift
final class InferenceController {
    private var shouldStop: Bool = false

    func requestStop() { shouldStop = true }

    private func makeContextParams() -> llama_context_params {
        var params = llama_context_default_params()
        params.abort_callback = { ctx in
            let controller = Unmanaged<InferenceController>
                .fromOpaque(ctx!)
                .takeUnretainedValue()
            return controller.shouldStop
        }
        params.abort_callback_data = Unmanaged
            .passUnretained(self)
            .toOpaque()
        return params
    }
}
```

The callback is polled between graphs — for the Metal backend, that's roughly per `llama_decode` batch; for CPU, similar granularity. Don't expect microsecond-level responsiveness; expect ~100s of milliseconds.

### BGContinuedProcessingTask wiring (CPU, no GPU resource)

```swift
import BackgroundTasks

@MainActor
final class BackgroundInferenceCoordinator {
    private let id = "com.yourapp.inference.queue"
    private let inference: InferenceController
    private let queue: InferenceQueue

    init(inference: InferenceController, queue: InferenceQueue) {
        self.inference = inference
        self.queue = queue
        registerLaunchHandler()
    }

    private func registerLaunchHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: id,
            using: nil
        ) { [weak self] task in
            guard let self, let task = task as? BGContinuedProcessingTask else { return }
            self.run(task)
        }
    }

    func userTappedKeepGoing() {
        let pending = queue.pendingItems()
        guard !pending.isEmpty else { return }

        let request = BGContinuedProcessingTaskRequest(
            identifier: id,
            title: "Generating responses",
            subtitle: "\(pending.count) item\(pending.count == 1 ? "" : "s") remaining"
        )
        request.strategy = .queue

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Surface to UI: "Couldn't start background generation."
        }
    }

    private func run(_ task: BGContinuedProcessingTask) {
        task.expirationHandler = { [weak self] in
            self?.inference.requestStop()
        }

        let pending = queue.pendingItems()
        let total = Int64(pending.count) * 100  // sub-item progress
        task.progress.totalUnitCount = total
        task.progress.completedUnitCount = 0

        Task.detached { [weak self] in
            guard let self else { return }
            // Switch to CPU backend before doing anything.
            await self.inference.switchToCPU()

            for (index, item) in pending.enumerated() {
                if self.inference.isStopped { break }

                let baseProgress = Int64(index) * 100
                do {
                    try await self.inference.run(item) { fractionComplete in
                        Task { @MainActor in
                            task.progress.completedUnitCount =
                                baseProgress + Int64(fractionComplete * 100)
                            task.updateTitle(
                                task.title,
                                subtitle: "Item \(index + 1) of \(pending.count) · " +
                                          "\(Int(fractionComplete * 100))%"
                            )
                        }
                    }
                    self.queue.markCompleted(item)
                } catch {
                    self.queue.markFailed(item, error: error)
                }
            }

            await MainActor.run {
                task.setTaskCompleted(success: !self.inference.isStopped)
            }
        }
    }
}
```

### Defensive Metal teardown on backgrounding (optional, recommended)

```swift
func applicationWillResignActive() {
    if inference.isUsingMetal && inference.isRunning {
        inference.requestStop()                 // sets ggml abort flag
        // Wait briefly for the in-flight decode to bail.
        // If you hold a UIBackgroundTaskIdentifier, do this inside it.
    }
    inference.releaseMetalBackend()             // keep model + weights, drop backend
}

func applicationDidBecomeActive() {
    inference.recreateMetalBackendIfNeeded()
}
```

This avoids the case where a stale Metal backend gets a deferred command-buffer failure post-resume. Cost is a few hundred ms backend recreate on next foregrounding; weights stay mmap'd.

---

## Open questions / decisions for the human

1. **What's the actual model?** A vision-capable LMM at 30–40 s/item on Metal probably means a 3–8 B-parameter quantized multimodal model (e.g., Qwen2-VL, MiniCPM, LLaVA-class). On the CPU backend on A18 Pro, expect **2–5× slower per item**, possibly more for vision tokens. Worth running `llama-bench` against your specific quant on iPhone 16 Pro to set realistic Mode-3 expectations before you ship copy that says "slower, runs on CPU."
2. **Quant choice.** Q4_K_M / Q5_K_M run reasonably on A-series CPU; Q8_0 is too heavy. If you're using Q4_K_M today on Metal, the same file is fine on CPU.
3. **Memory ceiling.** A18 Pro has 8 GB RAM. Any model whose mmap'd weights + KV cache + working set exceeds ~3 GB is at meaningful jetsam risk in the background even on CPU. Confirm your model footprint with Instruments under background pressure.
4. **Live Activity visual.** The system provides default UI for `BGContinuedProcessingTask` progress, but you can pair it with a custom ActivityKit Live Activity for branded Lock Screen / Dynamic Island presence. Decide if you want that for v1.
5. **iPad as a secondary target?** If iPad is on the roadmap, it _does_ support background GPU and would let Mode 3 stay on Metal there. The code paths are identical; you just guard the `.gpu` requiredResources on `supportedResources.contains(.gpu)`.
6. **App Review story for the App Store launch.** You're not asking for any privileged background mode (no audio/location/VoIP). Background processing + (later) background GPU on iPad is a clean review story. Avoid the temptation to dress this as an "audio" app to extend runtime — that's a hard rejection.
7. **PR #20306 dependency.** If your llama.cpp build predates 2026-03-09, upgrade. Without it, an unexpected backgrounding while Metal work is in flight crashes the app.
8. **Watch for iOS 26.5 / 27.** This is the most likely window for Apple to flip iPhone background GPU on. Worth checking each release-notes update; if it lands, you flip a single capability + one runtime check and Mode 3 moves to Metal.

---

## References

### Apple — primary

- [Performing long-running tasks on iOS and iPadOS](https://developer.apple.com/documentation/BackgroundTasks/performing-long-running-tasks-on-ios-and-ipados) — canonical doc; explicitly mentions GPU is on "supported devices" and CPU work via Core Image / Vision / Accelerate is fine.
- [`BGContinuedProcessingTaskRequest`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest)
- [`BGContinuedProcessingTaskRequest.Resources`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/resources) and [`.gpu`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/resources/gpu)
- [`BGTaskScheduler.supportedResources`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/supportedresources)
- [`BGProcessingTask`](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask)
- [`BGAppRefreshTask`](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask)
- [Choosing background strategies for your app](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)
- [Using background tasks to update your app](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app)
- [WWDC25 — "Finish tasks in the background"](https://developer.apple.com/videos/play/wwdc2025/227/) — the source of much of the iOS 26 guidance.
- [iOS & iPadOS 26.4 Release Notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26_4-release-notes) — confirmed no relevant change.
- [Adding capabilities to your app (Xcode)](https://developer.apple.com/documentation/Xcode/adding-capabilities-to-your-app)

### Apple — community confirmation of iPhone limitation

- [Apple Developer Forums thread #816774 — "BGContinuedProcessingTask GPU access — no iPhone support?"](https://developer.apple.com/forums/thread/816774) — primary source of the "iPad-only" finding; confirms iPhone 15 Pro and iPhone 16 Pro return `false` from `supportedResources.contains(.gpu)`.

### llama.cpp — primary

- [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) — repo
- [XCFramework distribution / Swift Package usage](https://github.com/ggml-org/llama.cpp#xcframework) (in README)
- [`build-xcframework.sh`](https://github.com/ggml-org/llama.cpp/blob/master/build-xcframework.sh)
- [PR #5409 — abort_callback integration](https://github.com/ggml-org/llama.cpp/pull/5409) — the cooperative cancel hook.
- [Issue #10509 — feature request: cancel during prompt processing](https://github.com/ggml-org/llama.cpp/issues/10509) — context on backend granularity of abort.
- [Issue #12525 — direct way to check abort status](https://github.com/ggml-org/llama.cpp/issues/12525) — current API gap.
- [PR #10571 — generic abort in `token_decode_internal`](https://github.com/ggerganov/llama.cpp/pull/10571)
- [Issue #16998 — "GPU backend no longer available when app minimized"](https://github.com/ggml-org/llama.cpp/issues/16998) — exact failure mode (`kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted`) and historical `GGML_ABORT` crash.
- [PR #20306 — graceful Metal command-buffer failure handling](https://github.com/ggml-org/llama.cpp/pull/20306) — March 2026 fix; replaces abort with sticky `has_error`.
- [`ggml/src/ggml-metal/ggml-metal.cpp`](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-metal/ggml-metal.cpp)

### Performance background

- [Issue #4358 — Apple Silicon A-series benchmarks](https://github.com/ggml-org/llama.cpp/issues/4358)
- [arXiv 2505.06461](https://arxiv.org/pdf/2505.06461) — iPhone 15 Pro CPU vs Metal data point (CPU 17 t/s, Metal 12.8 t/s, 1B model). Single data point, treat as directional only.

---

## Quick checklist for the next agent

- [ ] Confirm `BGTaskScheduler.shared.supportedResources` on the actual target device the user has (iPhone 16 Pro / iOS 26.4) → expect `.gpu` absent.
- [ ] Decide whether v1 ships with both Mode 3 and Mode 4, or Mode 3 only. Recommend: **Mode 3 only** for v1.
- [ ] Verify the project's llama.cpp version is at or after PR #20306 (post 2026-03-09). If not, upgrade.
- [ ] Verify the Swift binding wires `llama_context_params.abort_callback` and `abort_callback_data`. Most popular Swift wrappers don't by default.
- [ ] Run `llama-bench` for the actual model + quant on iPhone 16 Pro CPU backend to set Mode 3 user-facing copy ("about Xs per item on CPU").
- [ ] Add the Background processing capability to the Xcode target. **Do not** add Background GPU Access on an iPhone-only target.
- [ ] Add the task identifier to `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
- [ ] Implement defensive Metal teardown on `applicationWillResignActive` to avoid stale-backend failures post-resume.
- [ ] Persist queue state to disk per-item-completion so app-switcher kills are recoverable.
- [ ] Write user-facing copy that does not promise gesture-less background processing.
- [ ] Add a recurring monitoring task: re-check Apple's iOS release notes for any future iPhone background GPU enablement; flip Mode 3 to Metal when it lands.
