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

    /// Tokenises `prefix + task.suffix` for every task, finds the longest common token prefix
    /// (which covers the shared article body), decodes it once into seq 0, then for each task:
    ///   - forks seq 0 → task seq via `llama_memory_seq_cp` (O(1))
    ///   - decodes the task-specific suffix tokens
    ///   - generates up to `task.maxTokens` output tokens
    ///   - calls `onPartial` with the raw generated string
    ///   - removes the task's KV fork
    ///
    /// `onPartial` is called synchronously after each task completes, in task order, before the
    /// next task's suffix is decoded. Callers can checkpoint between tasks by doing work inside
    /// `onPartial`. Tasks are processed sequentially (not in parallel) so peak KV memory is
    /// prefix + one active task at a time.
    func generateWithSharedPrefix(
        prefix: String,
        tasks: [(suffix: String, maxTokens: Int, temperature: Double)],
        onPartial: (String) -> Void
    ) throws
}
