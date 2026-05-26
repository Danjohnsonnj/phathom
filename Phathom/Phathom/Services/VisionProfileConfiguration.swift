import CoreGraphics
import Foundation

/// User-facing profile knob (`VisionContentAnalyzer` accepts overrides; production uses `.automatic` + `VisionProfileResolver` heuristics).
enum VisionProfileOverride: String, CaseIterable, Sendable {
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

/// Auto-detected or overridden VLM profile (`compact` vs `capable`).
enum VisionProfile: String, Sendable {
    /// Smaller VLMs — default 1600px image side, permissive mtmd image token caps.
    case compact
    /// Larger VLMs (e.g. Qwen2.5-VL) — tighter image + token budgets for 8 GB class devices.
    case capable

    nonisolated var displayName: String {
        rawValue.capitalized
    }
}

/// Which configured attempt ran (logged in spike reports / diagnostics).
enum VisionRuntimeAttempt: String, Sendable {
    case primary
    /// Only used for `.capable` when the primary attempt threw and describe retried tightened settings.
    case tightenedRetry

    nonisolated var labelForReport: String {
        rawValue
    }
}

/// Resolved runtime tuning for one vision describe attempt.
struct VisionRunConfiguration: Sendable, Equatable {
    let profile: VisionProfile
    let runtimeAttempt: VisionRuntimeAttempt
    let imageMaxDimensionPixels: CGFloat
    let contextWindow: UInt32
    let physicalBatchUBatch: UInt32
    /// When `nil`, `mtmd_context_params` keeps bundled defaults for vision token caps.
    let imageMaxTokens: Int?

    nonisolated static func primary(for profile: VisionProfile) -> VisionRunConfiguration {
        switch profile {
        case .compact:
            VisionRunConfiguration(
                profile: profile,
                runtimeAttempt: .primary,
                imageMaxDimensionPixels: 1600,
                contextWindow: 4096,
                physicalBatchUBatch: 512,
                imageMaxTokens: nil
            )
        case .capable:
            VisionRunConfiguration(
                profile: profile,
                runtimeAttempt: .primary,
                imageMaxDimensionPixels: 768,
                contextWindow: 2048,
                physicalBatchUBatch: 512,
                imageMaxTokens: 1024
            )
        }
    }

    /// Tighter budget for `.capable` only; `nil` for `.compact`.
    nonisolated static func tightenedFallback(for profile: VisionProfile) -> VisionRunConfiguration? {
        guard profile == .capable else { return nil }
        return VisionRunConfiguration(
            profile: profile,
            runtimeAttempt: .tightenedRetry,
            imageMaxDimensionPixels: 512,
            contextWindow: 2048,
            physicalBatchUBatch: 512,
            imageMaxTokens: 768
        )
    }

    nonisolated static func resolveProfile(
        override: VisionProfileOverride,
        textGGUFPath: String,
        fileSizeBytes: UInt64?
    ) -> VisionProfile {
        switch override {
        case .compact:
            return .compact
        case .capable:
            return .capable
        case .automatic:
            return VisionProfileResolver.autoDetectedProfile(textGGUFPath: textGGUFPath, fileSizeBytes: fileSizeBytes)
        }
    }
}

/// Heuristics for choosing `VisionProfile` when override is **automatic**.
nonisolated enum VisionProfileResolver {
    /// ~1.2 GiB: favor compact on disk when name is ambiguous (smaller GGUF heuristic).
    private static let compactIfSmallerThanBytes: UInt64 = 1_300_000_000

    nonisolated static func autoDetectedProfile(textGGUFPath: String, fileSizeBytes: UInt64?) -> VisionProfile {
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
