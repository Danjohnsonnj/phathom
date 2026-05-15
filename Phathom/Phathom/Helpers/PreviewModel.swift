import PhathomCore
import SwiftData
import SwiftUI

enum PreviewModel {
    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = PhathomModelContainer.currentSchema
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
