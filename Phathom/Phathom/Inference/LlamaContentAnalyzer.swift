import PhathomCore
import Foundation

enum LLMJSONExtractor {
    nonisolated static func firstJSONArraySubstring(in text: String) -> String? {
        guard let start = text.firstIndex(of: "[") else { return nil }
        guard let end = text.lastIndex(of: "]"), end > start else { return nil }
        return String(text[start ... end])
    }

    nonisolated static func decodeStringArray(_ text: String) -> [String]? {
        guard let slice = firstJSONArraySubstring(in: text),
              let data = slice.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    nonisolated static func decodeExtracts(_ text: String) -> [Extract]? {
        guard let slice = firstJSONArraySubstring(in: text),
              let data = slice.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([Extract].self, from: data)
    }
}

actor LlamaContentAnalyzer {
    private let bridge: LlamaCppBridge

    init(bridge: LlamaCppBridge = LlamaCppRuntime()) {
        self.bridge = bridge
    }

    func loadModel(path: String) throws {
        try bridge.loadModel(path: path)
    }

    func unloadModel() {
        bridge.unloadModel()
    }

    /// Request stop of an in-flight `collectTemplated` loop (e.g. BG task expiration).
    func cancelBridgeGeneration() {
        bridge.cancelGeneration()
    }

    func generateSummary(articleText: String) async throws -> [String] {
        let body = String(articleText.prefix(12_000))
        let user = """
        You are a concise summarizer. Given an article, produce exactly 3-5 bullet points capturing the key ideas. Output ONLY a JSON array of strings, no other text.

        Article:
        \(body)
        """
        let out = try await collectTemplated(user: user, maxTokens: 512)
        return LLMJSONExtractor.decodeStringArray(out) ?? []
    }

    func generateTags(articleText: String) async throws -> [String] {
        let body = String(articleText.prefix(4_000))
        let user = """
        You produce topic tags for an article.

        Rules:
        - Output ONLY a JSON array of 3-8 strings.
        - Each tag is lowercase ASCII, words joined with hyphens (e.g. "climate-change").
        - Allowed characters: a-z, 0-9, hyphen.
        - Include 2-5 subject-matter tags (e.g. "web-development", "art-history", "dark-money").
        - Include 1-2 content-type tags (e.g. "recipe", "news", "social-media", "opinion", "guide").
        - No duplicates, no hashtags, no commentary.

        Example:
        Article: "EU lawmakers approved new climate emissions rules on Tuesday..."
        Tags: ["eu-policy","climate-change","emissions","news"]

        ### Article
        \(body)

        Reply with ONLY a JSON array of lowercase kebab-case tags.
        """
        let out = try await collectTemplated(user: user, maxTokens: 96)
        let tags = LLMJSONExtractor.decodeStringArray(out) ?? []
        return tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    func generateExtracts(articleText: String) async throws -> [Extract] {
        let body = String(articleText.prefix(8_000))
        let user = """
        You extract the 3-5 most notable facts, statistics, or actionable items from content. Output ONLY a JSON array of objects with "label" and "value" keys, no other text.

        Article:
        \(body)
        """
        let out = try await collectTemplated(user: user, maxTokens: 512)
        return LLMJSONExtractor.decodeExtracts(out) ?? []
    }

    /// Short verification run for Settings.
    func runQuickTest() async throws -> String {
        let user = "Summarize in one short sentence: The quick brown fox jumps over the lazy dog."
        return try await collectTemplated(user: user, maxTokens: 64)
    }

    private func collectTemplated(user: String, maxTokens: Int) async throws -> String {
        try bridge.startTemplatedUserPrompt(user, options: GenerationOptions(maxTokens: maxTokens, temperature: 0.15))
        var acc = ""
        while true {
            try Task.checkCancellation()
            guard let chunk = try bridge.nextTokenChunk() else { break }
            acc.append(chunk)
        }
        return acc
    }
}
