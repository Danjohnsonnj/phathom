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
    var sharedModelContainer: ModelContainer = {
        do {
            return try PhathomModelContainer.makeShared()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        BackgroundPipeline.register(modelContainer: sharedModelContainer)
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
