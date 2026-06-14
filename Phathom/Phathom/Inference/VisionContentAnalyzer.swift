import Foundation
import PhathomCore

#if canImport(llama)

public struct VisionDescribeResult: Sendable {
    public let description: String
    public let profile: VisionProfile
    public let runtimeAttempt: VisionRuntimeAttempt
    public let imageMaxDimensionApplied: CGFloat
    public let loadDuration: TimeInterval
    public let evalDuration: TimeInterval
    public let generateDuration: TimeInterval
    public let totalDuration: TimeInterval
    public let supportsVision: Bool
    public let useGPUProjector: Bool
    public let estimatedVisionSequenceTokens: UInt?
}

/// On-device VLM describe for media items (text GGUF + mmproj via libmtmd).
public actor VisionContentAnalyzer {
    static let defaultDescribePrompt = VisionDescribePrompts.defaultMediaDescribe

    private static let maxNewTokens = 192
    private static let temperature: Float = 0.2

    private let runtime: LlamaCppRuntime

    public init(runtime: LlamaCppRuntime) {
        self.runtime = runtime
    }

    func unloadModel() {
        runtime.unloadModel()
    }

    func cancelGeneration() {
        runtime.cancelGeneration()
    }

    public func describeImage(
        jpegData: Data,
        textModelPath: String,
        mmprojPath: String,
        profileOverride: VisionProfileOverride = .automatic,
        userPrompt: String? = nil
    ) throws -> VisionDescribeResult {
        let mergedProfile = Self.resolveProfile(
            override: profileOverride,
            textGGUFPath: textModelPath
        )
        let primary = VisionRunConfiguration.primary(for: mergedProfile)
        if let tightened = VisionRunConfiguration.tightenedFallback(for: mergedProfile) {
            do {
                return try describeSingleAttempt(
                    jpegData: jpegData,
                    textModelPath: textModelPath,
                    mmprojPath: mmprojPath,
                    configuration: primary,
                    userPrompt: userPrompt
                )
            } catch {
                return try describeSingleAttempt(
                    jpegData: jpegData,
                    textModelPath: textModelPath,
                    mmprojPath: mmprojPath,
                    configuration: tightened,
                    userPrompt: userPrompt
                )
            }
        }
        return try describeSingleAttempt(
            jpegData: jpegData,
            textModelPath: textModelPath,
            mmprojPath: mmprojPath,
            configuration: primary,
            userPrompt: userPrompt
        )
    }

    private func describeSingleAttempt(
        jpegData: Data,
        textModelPath: String,
        mmprojPath: String,
        configuration: VisionRunConfiguration,
        userPrompt: String?
    ) throws -> VisionDescribeResult {
        runtime.unloadModel()
        let totalStart = CFAbsoluteTimeGetCurrent()

        let loadStart = CFAbsoluteTimeGetCurrent()
        try runtime.loadVisionStack(
            textModelPath: textModelPath,
            mmprojPath: mmprojPath,
            configuration: configuration
        )
        let loadDuration = CFAbsoluteTimeGetCurrent() - loadStart

        let output = try runtime.describeLoadedVisionImage(
            jpegData: jpegData,
            configuration: configuration,
            userPrompt: userPrompt,
            maxNewTokens: Self.maxNewTokens,
            temperature: Self.temperature
        )

        let totalDuration = CFAbsoluteTimeGetCurrent() - totalStart
        defer { runtime.unloadModel() }

        let usesCustomPrompt = userPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let description = usesCustomPrompt
            ? output.text
            : MediaDescriptionSanitization.clean(output.text)

        return VisionDescribeResult(
            description: description,
            profile: configuration.profile,
            runtimeAttempt: configuration.runtimeAttempt,
            imageMaxDimensionApplied: configuration.imageMaxDimensionPixels,
            loadDuration: loadDuration,
            evalDuration: output.evalDuration,
            generateDuration: output.generateDuration,
            totalDuration: totalDuration,
            supportsVision: true,
            useGPUProjector: true,
            estimatedVisionSequenceTokens: nil
        )
    }

    private static func resolveProfile(
        override: VisionProfileOverride,
        textGGUFPath: String
    ) -> VisionProfile {
        var fileSizeBytes: UInt64?
        if let attrs = try? FileManager.default.attributesOfItem(atPath: textGGUFPath),
           let ns = attrs[.size] as? NSNumber {
            let v = ns.uint64Value
            fileSizeBytes = v == 0 ? nil : v
        }
        return VisionRunConfiguration.resolveProfile(
            override: override,
            textGGUFPath: textGGUFPath,
            fileSizeBytes: fileSizeBytes
        )
    }
}

#else

public struct VisionDescribeResult: Sendable {
    public let description: String
    public let profile: VisionProfile
    public let runtimeAttempt: VisionRuntimeAttempt
    public let imageMaxDimensionApplied: CGFloat
    public let loadDuration: TimeInterval
    public let evalDuration: TimeInterval
    public let generateDuration: TimeInterval
    public let totalDuration: TimeInterval
    public let supportsVision: Bool
    public let useGPUProjector: Bool
    public let estimatedVisionSequenceTokens: UInt?
}

public actor VisionContentAnalyzer {
    static let defaultDescribePrompt = VisionDescribePrompts.defaultMediaDescribe

    public init(runtime: LlamaCppRuntime) {
        _ = runtime
    }

    func unloadModel() {}

    func cancelGeneration() {}

    public func describeImage(
        jpegData: Data,
        textModelPath: String,
        mmprojPath: String,
        profileOverride: VisionProfileOverride = .automatic,
        userPrompt: String? = nil
    ) throws -> VisionDescribeResult {
        _ = jpegData
        _ = textModelPath
        _ = mmprojPath
        _ = profileOverride
        _ = userPrompt
        throw VisionInferenceError.frameworkMissing
    }
}

#endif
