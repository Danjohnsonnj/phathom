import Foundation
import PhathomCore

#if canImport(llama)

struct VisionDescribeResult: Sendable {
    let description: String
    let profile: VisionProfile
    let runtimeAttempt: VisionRuntimeAttempt
    let imageMaxDimensionApplied: CGFloat
    let loadDuration: TimeInterval
    let evalDuration: TimeInterval
    let generateDuration: TimeInterval
    let totalDuration: TimeInterval
    let supportsVision: Bool
    let useGPUProjector: Bool
    let estimatedVisionSequenceTokens: UInt?
}

/// On-device VLM describe for media items (text GGUF + mmproj via libmtmd).
actor VisionContentAnalyzer {
    static let defaultDescribePrompt =
        "Describe this image in detail for a personal knowledge library. Include subjects, scene, mood, and any visible text."

    private static let maxNewTokens = 384
    private static let temperature: Float = 0.2

    private let runtime: LlamaCppRuntime

    init(runtime: LlamaCppRuntime) {
        self.runtime = runtime
    }

    func unloadModel() {
        runtime.unloadModel()
    }

    func cancelGeneration() {
        runtime.cancelGeneration()
    }

    func describeImage(
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

        return VisionDescribeResult(
            description: output.text,
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

struct VisionDescribeResult: Sendable {
    let description: String
    let profile: VisionProfile
    let runtimeAttempt: VisionRuntimeAttempt
    let imageMaxDimensionApplied: CGFloat
    let loadDuration: TimeInterval
    let evalDuration: TimeInterval
    let generateDuration: TimeInterval
    let totalDuration: TimeInterval
    let supportsVision: Bool
    let useGPUProjector: Bool
    let estimatedVisionSequenceTokens: UInt?
}

actor VisionContentAnalyzer {
    static let defaultDescribePrompt =
        "Describe this image in detail for a personal knowledge library. Include subjects, scene, mood, and any visible text."

    init(runtime: LlamaCppRuntime) {
        _ = runtime
    }

    func unloadModel() {}

    func cancelGeneration() {}

    func describeImage(
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
