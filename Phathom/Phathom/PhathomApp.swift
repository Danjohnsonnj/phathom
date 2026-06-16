//
//  PhathomApp.swift
//  Phathom
//
//  Created by Daniel Johnson on 4/29/26.
//

import PhathomCore
import PhathomInference
import SwiftData
import SwiftUI

@main
struct PhathomApp: App {
    #if os(macOS)
    @State private var macNavigation = MacShellNavigationModel()
    #endif

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
        #if os(iOS)
        MediaImageLoadMetrics.logProfilingEnabledIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TypographyEnvironmentRoot {
                Group {
                    #if os(macOS)
                    MainMacView()
                        .environment(macNavigation)
                    #else
                    MainTabView()
                    #endif
                }
                .pipelineLifecycle()
                .onAppear {
                    seedIfEmpty()
                }
            }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            CommandMenu("Navigate") {
                ForEach(MacNavigationSelection.allCases, id: \.self) { section in
                    Button(section.title) {
                        macNavigation.selection = section
                    }
                    .keyboardShortcut(section.menuKey, modifiers: .command)
                }
            }
        }
        #endif
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
