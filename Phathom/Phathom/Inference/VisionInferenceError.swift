import Foundation

public enum VisionInferenceError: LocalizedError, Sendable {
    case modelLoadFailed(String)
    case visionInitFailed(String)
    case imageDecodeFailed
    case tokenizeFailed(Int32)
    case evalFailed(Int32)
    case generationFailed(String)
    case visionNotSupported
    case frameworkMissing

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let s):
            "Model load failed: \(s)"
        case .visionInitFailed(let s):
            "Vision projector failed: \(s)"
        case .imageDecodeFailed:
            "Could not decode image bytes for vision input."
        case .tokenizeFailed(let code):
            "Vision tokenize failed (code \(code))."
        case .evalFailed(let code):
            "Vision eval failed (code \(code))."
        case .generationFailed(let s):
            "Generation failed: \(s)"
        case .visionNotSupported:
            "Loaded mmproj does not report vision support."
        case .frameworkMissing:
            "llama.xcframework with mtmd is not linked. Run scripts/rebuild-llama-xcframework-with-mtmd.sh."
        }
    }
}
