import Foundation
import SwiftData

public enum PhathomModelContainer {
    /// Shared SwiftData container for the main app and Share Extension (App Group URL).
    public static func makeShared() throws -> ModelContainer {
        SwiftDataStoreMigration.migrateLegacyStoreToAppGroupIfNeeded()
        let schema = Schema([
            ContentItem.self,
            Tag.self,
            ChatThread.self,
            ChatMessage.self,
        ])
        let url = PhathomAppGroup.sharedStoreURL()
        let config = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
