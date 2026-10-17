import Foundation

/// On-disk GGUF identity for analyze-progress pairing (filename + byte count only).
struct ModelFileIdentity: Equatable, Hashable, Sendable, Codable {
    var filename: String
    var byteCount: Int
}

/// Primary + Tagging model pair for rate buckets.
struct ModelPairKey: Equatable, Hashable, Sendable, Codable {
    var primary: ModelFileIdentity
    var tagging: ModelFileIdentity

    /// Stable `UserDefaults` sub-key (not for UI).
    var persistenceToken: String {
        [
            primary.filename,
            String(primary.byteCount),
            tagging.filename,
            String(tagging.byteCount),
        ].joined(separator: "\u{001F}")
    }

    /// Lookup when analyze starts: Primary plus configured Tagging when set, otherwise Primary plus Primary.
    nonisolated static func forEstimate(
        primary: ModelFileIdentity,
        configuredTagging: ModelFileIdentity?
    ) -> ModelPairKey {
        ModelPairKey(primary: primary, tagging: configuredTagging ?? primary)
    }

    /// Bucket key for a finished pass (pair that actually ran).
    nonisolated static func forStorage(
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
