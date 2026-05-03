import PhathomCore
import Foundation

nonisolated protocol LlamaCppBridge: Sendable {
    func loadModel(path: String) throws
    func unloadModel()
    /// Token count of the chat-templated prompt (matches what `startTemplatedUserPrompt` tokenizes).
    func countTemplatedUserPromptTokens(_ user: String) throws -> Int
    /// Max templated prompt tokens allowed so the prompt plus up to `generationMaxTokens` of output fits the context.
    func maxTemplatedPromptTokensForGeneration(_ generationMaxTokens: Int) -> Int
    func startTemplatedUserPrompt(_ user: String, options: GenerationOptions) throws
    func startRawPrompt(_ fullChatPrompt: String, options: GenerationOptions) throws
    func nextTokenChunk() throws -> String?
    func cancelGeneration()
}
