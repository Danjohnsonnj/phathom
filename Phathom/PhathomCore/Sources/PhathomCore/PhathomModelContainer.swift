import Foundation
import SwiftData

public enum PhathomModelContainer {
    public static var currentSchema: Schema {
        Schema(versionedSchema: PhathomSchemaV5.self)
    }

    private static let highlightWipeKey = "PhathomHighlightWipeV4Done"

    /// Shared SwiftData container for the main app and share extensions (App Group or macOS shared fallback).
    public static func makeShared() throws -> ModelContainer {
        SwiftDataStoreMigration.migrateLegacyStoreToAppGroupIfNeeded()
        let schema = currentSchema
        let url = PhathomAppGroup.sharedStoreURL()
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [config])
        wipeHighlightsOnceIfNeeded(container: container)
        return container
    }

    /// One-shot wipe of all Highlight rows on upgrade to sourceMarkdown-based anchors.
    /// Prior highlights used plainTextOffset which is incompatible with new schema.
    private static func wipeHighlightsOnceIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: highlightWipeKey) else { return }
        let context = ModelContext(container)
        do {
            try context.delete(model: Highlight.self)
            try context.save()
            defaults.set(true, forKey: highlightWipeKey)
        } catch {
            print("[PhathomModelContainer] Highlight wipe failed: \(error)")
        }
    }
}

