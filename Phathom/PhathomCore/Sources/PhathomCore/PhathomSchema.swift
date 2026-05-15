import SwiftData

/// Snapshot for **tests** that seed a pre-`Highlight` on-disk store.
public enum PhathomSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            ContentItem.self,
            Tag.self,
            ChatThread.self,
            ChatMessage.self,
        ]
    }
}

/// Current shipped schema. Runtime `ModelContainer` uses **no** `SchemaMigrationPlan` — additive changes use Core Data lightweight migration; staged `MigrationStage` plans hit duplicate-checksum failures on some OS/store combos.
public enum PhathomSchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            ContentItem.self,
            Tag.self,
            ChatThread.self,
            ChatMessage.self,
            Highlight.self,
        ]
    }
}
