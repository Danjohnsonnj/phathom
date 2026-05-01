import SwiftData
import SwiftUI

enum PreviewModel {
    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            ContentItem.self,
            Tag.self,
            ChatThread.self,
            ChatMessage.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            SeedData.populate(container.mainContext)
            return container
        } catch {
            fatalError("Preview container: \(error)")
        }
    }
}
