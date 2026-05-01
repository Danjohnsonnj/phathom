import Foundation

enum LlamaInferenceError: Error, LocalizedError {
    case modelLoadFailed(String)
    case modelNotLoaded
    case generationFailed(String)
    case contextLimitReached(String)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let r): r
        case .modelNotLoaded: "No model is loaded."
        case .generationFailed(let r): r
        case .contextLimitReached(let r): r
        }
    }
}
