//
//  PhathomApp.swift
//  Phathom
//
//  Created by Daniel Johnson on 4/29/26.
//

import SwiftData
import SwiftUI

@main
struct PhathomApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ContentItem.self,
            Tag.self,
            ChatThread.self,
            ChatMessage.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        BackgroundPipeline.register(modelContainer: sharedModelContainer)
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
