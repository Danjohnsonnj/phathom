import BackgroundTasks
import Foundation
import PhathomCore
import SwiftData
import UIKit

/// User-initiated background lane for LLM analysis. Uses iOS 26's `BGContinuedProcessingTask`,
/// which provides:
///   - A system Live Activity (Lock Screen + Dynamic Island) showing progress / cancel.
///   - "Tap to keep going" UX (Apple's recommended use case for this task class).
///
/// **Snapshot semantics**: each user tap freezes the IDs that were queued at that moment into
/// `PendingSnapshotStore`. The handler processes only that frozen list — items added after the tap
/// are left for the next foreground drain or another tap.
///
/// **CPU-only**: iPhone has no Background GPU Access today (`BGTaskScheduler.supportedResources`
/// excludes `.gpu`); submitting Metal work from this handler returns
/// `kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted`. The handler forces the
/// `.cpu` backend on `SharedLlamaInference` so `n_gpu_layers = 0` for the duration.
enum BackgroundContinuedAnalyze {
    nonisolated static let identifier = "com.phathom.continued-analyze"

    /// Register the handler at app launch. Call once from `PhathomApp.init()` (after
    /// `BackgroundPipeline.register`, but order doesn't strictly matter — both must complete
    /// before `applicationDidFinishLaunching` returns per Apple's docs).
    nonisolated static func register(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            guard let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task: task, modelContainer: modelContainer)
        }
    }

    /// Submit a continued-processing request from the user-tapped UI. `itemIDs` is the snapshot;
    /// it's persisted via `PendingSnapshotStore` so the OS-driven handler at wake-up sees the same
    /// list (the app may be relaunched between submit and handle).
    ///
    /// We submit before persisting: if `BGTaskScheduler.shared.submit` throws, the snapshot is not
    /// written, so a subsequent `PendingSnapshotStore.load()` from the LibraryTab does not falsely
    /// imply an in-flight BG task. Callers should also `clear()` any prior snapshot in their catch
    /// block so a previous successful submit's stale entry is removed when the user taps again.
    static func submit(itemIDs: [UUID]) throws {
        guard !itemIDs.isEmpty else { return }
        let count = itemIDs.count
        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: "Processing saved items",
            subtitle: "\(count) item\(count == 1 ? "" : "s") remaining"
        )
        // `.queue` lets multiple submissions coalesce — but our snapshot semantics mean we'd
        // typically only ever have one in flight; queue is the safer default.
        request.strategy = .queue
        try BGTaskScheduler.shared.submit(request)
        PendingSnapshotStore.save(itemIDs)
    }

    private nonisolated static func handle(
        task: BGContinuedProcessingTask,
        modelContainer: ModelContainer
    ) {
        let snapshot = PendingSnapshotStore.load()

        guard !snapshot.isEmpty else {
            // Defensive clear: nothing to do but make sure the LibraryTab banner doesn't read a
            // ghost snapshot on next foreground.
            PendingSnapshotStore.clear()
            task.setTaskCompleted(success: true)
            return
        }

        // Bail early on thermal pressure — CPU at sustained load on a hot device leads to
        // visible jetsam risk. The user can re-tap later.
        if ThermalMonitor.shouldThrottle {
            // Clear so the confirmation banner doesn't survive an aborted run; the user's queued
            // items remain in pending/embedding and the original submit banner returns.
            PendingSnapshotStore.clear()
            task.setTaskCompleted(success: false)
            return
        }

        let cancel = CancelFlagBox()
        task.expirationHandler = {
            cancel.value = true
            // The cancel flag tunnels into `nextTokenChunk` via `llama_set_abort_callback` so the
            // in-flight decode bails within milliseconds. The lifecycle lock then unwinds.
            SharedLlamaInference.signalCancelInFlight()
        }

        // Each item is one progress unit. Sub-progress (per-stage) is a future enhancement; the
        // OS only redraws the Live Activity on `completedUnitCount` changes, so item-level
        // granularity is the lowest acceptable bar.
        task.progress.totalUnitCount = Int64(snapshot.count)
        task.progress.completedUnitCount = 0

        Task.detached {
            ModelManager.validateSelection()

            for (idx, id) in snapshot.enumerated() {
                if cancel.value { break }

                if ThermalMonitor.shouldThrottle { break }

                let outcome = await PipelineWorkGate.shared.processSnapshotItem(
                    id: id,
                    modelContainer: modelContainer,
                    cancel: { cancel.value },
                    backend: .cpu
                )

                let completedSoFar = idx + 1
                let total = snapshot.count
                await MainActor.run {
                    task.progress.completedUnitCount = Int64(completedSoFar)
                    // Update the Live Activity subtitle so users see "Item 2 of 5" rather than the
                    // static remaining-count from submit time. Title stays fixed across the run.
                    task.updateTitle(
                        "Processing saved items",
                        subtitle: "Item \(completedSoFar) of \(total)"
                    )
                }

                if case .cancelled = outcome { break }
            }

            // Snapshot is consumed — drop it so the banner returns to the un-submitted state on
            // next foreground.
            PendingSnapshotStore.clear()

            await MainActor.run {
                task.setTaskCompleted(success: !cancel.value)
            }
        }
    }
}
