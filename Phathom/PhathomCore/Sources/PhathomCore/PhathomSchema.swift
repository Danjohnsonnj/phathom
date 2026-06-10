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

/// Legacy schema snapshot (includes **`Category`**; no Focus Stack models).
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

/// Current shipped schema (adds **`FocusEntry`** + **`FocusOutcome`**).
public enum PhathomSchemaV5: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            ContentItem.self,
            Tag.self,
            Category.self,
            ChatThread.self,
            ChatMessage.self,
            Highlight.self,
            FocusEntry.self,
            FocusOutcome.self,
        ]
    }
}
