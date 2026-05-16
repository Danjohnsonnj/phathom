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

/// **Legacy** schema snapshot (highlight model, no Category). Runtime uses **no** `SchemaMigrationPlan` for lightweight migration elsewhere.
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

/// Current shipped schema (includes **`Category`** for structural grouping).
public enum PhathomSchemaV4: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            ContentItem.self,
            Tag.self,
            Category.self,
            ChatThread.self,
            ChatMessage.self,
            Highlight.self,
        ]
    }
}
