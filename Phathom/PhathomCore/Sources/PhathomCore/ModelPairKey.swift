/// On-disk GGUF identity for analyze-progress pairing (filename + byte count only).
public struct ModelFileIdentity: Equatable, Hashable, Sendable, Codable {
    public var filename: String
    public var byteCount: Int

    public init(filename: String, byteCount: Int) {
        self.filename = filename
        self.byteCount = byteCount
    }
}

/// Primary + Tagging model pair for rate buckets.
public struct ModelPairKey: Equatable, Hashable, Sendable, Codable {
    public var primary: ModelFileIdentity
    public var tagging: ModelFileIdentity

    public init(primary: ModelFileIdentity, tagging: ModelFileIdentity) {
        self.primary = primary
        self.tagging = tagging
    }

    /// Stable `UserDefaults` sub-key (not for UI).
    public var persistenceToken: String {
        [
            primary.filename,
            String(primary.byteCount),
            tagging.filename,
            String(tagging.byteCount),
        ].joined(separator: "\u{001F}")
    }

    /// Lookup when analyze starts: Primary plus configured Tagging when set, otherwise Primary plus Primary.
    public nonisolated static func forEstimate(
        primary: ModelFileIdentity,
        configuredTagging: ModelFileIdentity?
    ) -> ModelPairKey {
        ModelPairKey(primary: primary, tagging: configuredTagging ?? primary)
    }

    /// Bucket key for a finished pass (pair that actually ran).
    public nonisolated static func forStorage(
        primary: ModelFileIdentity,
        configuredTagging: ModelFileIdentity?,
        taggingRan: Bool,
        usedPrimaryFallback: Bool,
        ranTaggingIdentity: ModelFileIdentity?
    ) -> ModelPairKey {
        if configuredTagging == nil || !taggingRan || usedPrimaryFallback {
            return ModelPairKey(primary: primary, tagging: primary)
        }
        let tagging = ranTaggingIdentity ?? configuredTagging ?? primary
        return ModelPairKey(primary: primary, tagging: tagging)
    }
}
