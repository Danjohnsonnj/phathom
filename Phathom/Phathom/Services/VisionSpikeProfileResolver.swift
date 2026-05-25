#if DEBUG

import CoreGraphics
import Foundation

/// User-facing spike profile knob (persisted via `AppStorage`).
enum VisionSpikeProfileOverride: String, CaseIterable, Sendable {
    case automatic = "auto"
    case compact = "compact"
    case capable = "capable"

    nonisolated var label: String {
        switch self {
        case .automatic: return "Auto"
        case .compact: return "Compact"
        case .capable: return "Capable"
        }
    }
}

/// Auto-detected or overridden device spike profile (`compact` vs `capable`).
enum VisionSpikeProfile: String, Sendable {
    /// Smaller VLMs — default 1600px image side, permissive mtmd image token caps.
    case compact
    /// Larger VLMs (e.g. Qwen2.5-VL) — tighter image + token budgets for 8 GB class devices.
    case capable

    nonisolated var displayName: String {
        rawValue.capitalized
    }
}

/// Which configured attempt ran (logged in `VisionSpikeResult`).
enum VisionSpikeRuntimeAttempt: String, Sendable {
    case primary
    /// Only used for `.capable` when the primary attempt threw and spike retried tightened settings.
    case tightenedRetry

    nonisolated var labelForReport: String {
        rawValue
    }
}

/// Resolved runtime tuning for one spike attempt (`LlamaVisionSpike`).
struct VisionSpikeRunConfiguration: Sendable, Equatable {
    let profile: VisionSpikeProfile
    let runtimeAttempt: VisionSpikeRuntimeAttempt
    let imageMaxDimensionPixels: CGFloat
    let spikeContextWindow: UInt32
    let physicalBatchUBatch: UInt32
    /// When `nil`, `mtmd_context_params` keeps bundled defaults for vision token caps.
    let imageMaxTokens: Int?

    nonisolated static func primary(for profile: VisionSpikeProfile) -> VisionSpikeRunConfiguration {
        switch profile {
        case .compact:
            VisionSpikeRunConfiguration(
                profile: profile,
                runtimeAttempt: .primary,
                imageMaxDimensionPixels: 1600,
                spikeContextWindow: 4096,
                physicalBatchUBatch: 512,
                imageMaxTokens: nil
            )
        case .capable:
            VisionSpikeRunConfiguration(
                profile: profile,
                runtimeAttempt: .primary,
                imageMaxDimensionPixels: 768,
                spikeContextWindow: 2048,
                physicalBatchUBatch: 512,
                imageMaxTokens: 1024
            )
        }
    }

    /// Tighter budget for `.capable` only; `nil` for `.compact`.
    nonisolated static func tightenedFallback(for profile: VisionSpikeProfile) -> VisionSpikeRunConfiguration? {
        guard profile == .capable else { return nil }
        return VisionSpikeRunConfiguration(
            profile: profile,
            runtimeAttempt: .tightenedRetry,
            imageMaxDimensionPixels: 512,
            spikeContextWindow: 2048,
            physicalBatchUBatch: 512,
            imageMaxTokens: 768
        )
    }

    nonisolated static func resolveProfile(
        override: VisionSpikeProfileOverride,
        textGGUFPath: String,
        fileSizeBytes: UInt64?
    ) -> VisionSpikeProfile {
        switch override {
        case .compact:
            return .compact
        case .capable:
            return .capable
        case .automatic:
            return VisionSpikeProfileResolver.autoDetectedProfile(textGGUFPath: textGGUFPath, fileSizeBytes: fileSizeBytes)
        }
    }
}

/// Heuristics for choosing `VisionSpikeProfile` when UI override is **auto**.
nonisolated enum VisionSpikeProfileResolver {
    /// ~1.2 GiB: favor compact on disk when name is ambiguous (smaller GGUF heuristic).
    private static let compactIfSmallerThanBytes: UInt64 = 1_300_000_000

    nonisolated static func autoDetectedProfile(textGGUFPath: String, fileSizeBytes: UInt64?) -> VisionSpikeProfile {
        let leaf = URL(fileURLWithPath: textGGUFPath).lastPathComponent.lowercased()
        if leaf.contains("smol") || leaf.contains("smolvlm") {
            return .compact
        }
        if leaf.contains("qwen"), leaf.contains("vl") {
            return .capable
        }

        guard let sz = fileSizeBytes else {
            return .capable
        }
        return sz < Self.compactIfSmallerThanBytes ? .compact : .capable
    }
}

#endif
