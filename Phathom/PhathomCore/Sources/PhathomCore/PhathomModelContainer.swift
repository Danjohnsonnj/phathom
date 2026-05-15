import Foundation
import SwiftData

public enum PhathomModelContainer {
    public static var currentSchema: Schema {
        Schema(versionedSchema: PhathomSchemaV3.self)
    }

    /// Shared SwiftData container for the main app and Share Extension (App Group URL).
    public static func makeShared() throws -> ModelContainer {
        SwiftDataStoreMigration.migrateLegacyStoreToAppGroupIfNeeded()
        let schema = currentSchema
        let url = PhathomAppGroup.sharedStoreURL()
        let config = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

