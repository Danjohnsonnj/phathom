import PhathomCore
import Foundation

nonisolated protocol LlamaCppBridge: Sendable {
    func loadModel(path: String) throws
    func unloadModel()
    func startTemplatedUserPrompt(_ user: String, options: GenerationOptions) throws
    func startRawPrompt(_ fullChatPrompt: String, options: GenerationOptions) throws
    func nextTokenChunk() throws -> String?
    func cancelGeneration()
}
