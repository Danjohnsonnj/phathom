//
//  PhathomApp.swift
//  Phathom
//
//  Created by Daniel Johnson on 4/29/26.
//

import PhathomCore
import SwiftData
import SwiftUI

@main
struct PhathomApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        do {
            return try PhathomModelContainer.makeShared()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        BackgroundPipeline.register(modelContainer: sharedModelContainer)
        // The user-initiated `BGContinuedProcessingTask` lane must register before
        // `applicationDidFinishLaunching` returns, just like the BGAppRefreshTask above.
        BackgroundContinuedAnalyze.register(modelContainer: sharedModelContainer)
        SharedLlamaInference.scheduleWarmFromPersistedSelection()
        NetworkReachability.start()
        StoreChangedDarwinNotifier.start()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    seedIfEmpty()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    /// On `.inactive` / `.background`, signal the LLM cancel flag and force-unload the Metal context.
    /// Holding a Metal backend across foreground↔background transitions risks deferred command-buffer
    /// failures (`kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted`); the cancel flag
    /// causes any in-flight `nextTokenChunk` to return early, and `forceUnloadIfIdle` releases the
    /// context once the lifecycle lock is free. Weights remain mmap'd via the security-scoped bookmark.
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard phase != .active else { return }
        SharedLlamaInference.signalCancelInFlight()
        Task { await SharedLlamaInference.shared.forceUnloadIfIdle() }
    }

    @MainActor
    private func seedIfEmpty() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<ContentItem>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            SeedData.populate(context)
        }
    }
}
