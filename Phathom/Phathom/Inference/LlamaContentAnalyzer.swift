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
        <PROMPT>

        <ROLE>You are an expert analyst specializing in extracting actionable insights from complex information.</ROLE>

        <CONTEXT>
        You will be provided with a piece of text. Your task is to distill it into a concise summary that not only captures the core message but also amplifies the most significant, novel, and potentially impactful insights.
        </CONTEXT>

        <INSTRUCTIONS>
        *Identify Core Theme(s):* Read the provided text and identify the 1-3 overarching themes or main arguments.
        *Extract Novel Insights:* Within these themes, pinpoint specific insights that are new, counter-intuitive, or offer a fresh perspective. These should go beyond mere restatements of the obvious.
        *Amplify & Explain Significance:* For each novel insight identified, explain why it matters. What are the implications? Who should care? What action might this insight inform?
        *Synthesize:* Combine these elements into a structured summary. Start with the core theme(s), followed by the amplified insights and their significance. The summary should be significantly shorter than the original text, prioritizing depth of insight over breadth of coverage.
        </INSTRUCTIONS>

        <CONSTRAINTS>
        - The summary must be no more than 250 words.
        - Avoid jargon where possible, or explain it briefly if essential.
        - Focus on 'what is new' and 'so what'.
        - Output ONLY a JSON array of strings, no other text.
        </CONSTRAINTS>

        <TEXT_TO_SUMMARIZE>
        \(body)
        </TEXT_TO_SUMMARIZE>
        
        <IMPORTANT>
        Output ONLY a JSON array of strings, no other text.
        </IMPORTANT>

        </PROMPT>
        """
        let out = try await collectTemplated(user: user, maxTokens: 512)
        return LLMJSONExtractor.decodeStringArray(out) ?? []
    }

    func generateTags(articleText: String) async throws -> [String] {
        let body = String(articleText.prefix(4_000))
        let user = """
        <PROMPT>

        <ROLE>You are an expert analyst specializing in producing topic tags from complex information.</ROLE>

        <CONTEXT>
        You will be provided with text to tag. Your task is to distill it into a a series of topic tags that capture the core themes, subjects, .
        </CONTEXT>

        <INSTRUCTIONS>
        1. Analyze the core themes and overarching arguments of the text.
        2. Select 2-5 tags that categorize the text based on these core themes and novel insights. 
        3. Prioritize subject-matter tags that capture the specific content (e.g., "quantum-computing" rather than just "tech").
        4. Assign 1-2 content-type tags that accurately describe the format (e.g., "opinion", "technical-guide", "recipe").
        5. Verify all selected tags against the strict formatting rules in the CONSTRAINTS section before outputting.
        </INSTRUCTIONS>

        <CONSTRAINTS>
        - Output ONLY a JSON array of 3-8 strings.
        - Each tag is lowercase ASCII, words joined with hyphens (e.g. "climate-change").
        - Allowed characters: a-z, 0-9, hyphen.
        - Include 2-5 subject-matter tags (e.g. "web-development", "art-history", "dark-money").
        - Include 1-2 content-type tags (e.g. "recipe", "news", "social-media", "opinion", "guide").
        - No duplicates, no hashtags, no commentary.

        Example:
        Article: "EU lawmakers approved new climate emissions rules on Tuesday..."
        Tags: ["eu-policy","climate-change","emissions","news"]
        </CONSTRAINTS>

        <TEXT_TO_TAG>
        \(body)
        </TEXT_TO_TAG>

        <IMPORTANT>
        Output ONLY a JSON array of lowercase kebab-case tags.
        </IMPORTANT>

        </PROMPT>
        """
        let out = try await collectTemplated(user: user, maxTokens: 96)
        let tags = LLMJSONExtractor.decodeStringArray(out) ?? []
        return tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    func generateExtracts(articleText: String) async throws -> [Extract] {
        let body = String(articleText.prefix(8_000))
        let user = """
        <PROMPT>

        <ROLE>You are a precise data extraction specialist focused on identifying high-impact information.</ROLE>

        <CONTEXT>
        You will be provided with an article. Your task is to scan the content for the most significant data points, specifically focusing on hard statistics, notable facts, or concrete actionable items that provide the most value to a reader.
        </CONTEXT>

        <INSTRUCTIONS>
        1. Scrutinize the text for quantitative data (percentages, dollar amounts, counts) and qualitative "gold nuggets" (key takeaways or specific advice).
        2. Select the 3-5 most impactful items based on their relevance and uniqueness.
        3. For each item, create a concise "label" (the category or subject) and a specific "value" (the fact, stat, or action).
        4. Ensure the "value" contains the specific detail or number, while the "label" provides context.
        </INSTRUCTIONS>

        <CONSTRAINTS>
        - Output ONLY a valid JSON array of objects.
        - Each object MUST contain exactly two keys: "label" and "value".
        - Do not include any markdown formatting, preamble, or postscript.
        - Values must be strings.
        </CONSTRAINTS>

        <ARTICLE>
        \(body)
        </ARTICLE>

        <EXAMPLE>
        Input: "Our 2023 survey showed that 65% of remote workers feel more productive. To maintain this, managers should schedule 10-minute daily syncs."
        Output: 
        [
          {"label": "Remote Productivity", "value": "65% of workers reported an increase in efficiency."},
          {"label": "Management Action", "value": "Implement a 10-minute daily synchronization meeting."}
        ]
        </EXAMPLE>

        <IMPORTANT>
        Return ONLY the JSON array. Do not include any other text or explanation.
        </IMPORTANT>

        </PROMPT>
        """
        let out = try await collectTemplated(user: user, maxTokens: 512)
        return LLMJSONExtractor.decodeExtracts(out) ?? []
    }

    /// Re-rank "adjacent" candidate items (none of which contain the tapped tag) by conceptual relatedness
    /// to the tapped tag and the source item's full tag list. Returns IDs in ranked order; unknown IDs are
    /// dropped, missing input IDs are appended at the end in the input's original (Jaccard) order so the
    /// caller never loses candidates.
    func rankAdjacentItems(
        tappedTag: String,
        sourceTagNames: [String],
        candidates: [(id: UUID, tagNames: [String])]
    ) async throws -> [UUID] {
        guard !candidates.isEmpty else { return [] }
        let candidatesJSON = candidates.map { c in
            let tagsList = c.tagNames.map { "\"\($0)\"" }.joined(separator: ",")
            return "{\"id\":\"\(c.id.uuidString)\",\"tags\":[\(tagsList)]}"
        }.joined(separator: ",\n ")
        let sourceTagsJSON = sourceTagNames.map { "\"\($0)\"" }.joined(separator: ",")

        let user = """
        <PROMPT>
        <ROLE>You are a semantic relationship engine specializing in tag-based taxonomy and conceptual mapping.</ROLE>
        <CONTEXT>
        A user interacted with a specific tag (the "Tapped Tag") on a source item. You must rank a list of candidate items that do NOT contain the Tapped Tag based on how closely their own tag sets relate conceptually to both the Tapped Tag and the broader Source Tag context.
        </CONTEXT>
        <INSTRUCTIONS>
        1. Establish a "Semantic Anchor": Use the Tapped Tag as the primary weight for relevance, supported by the Source Tags for context.
        2. Evaluate Candidates: Analyze each candidate's tag list. Look for synonyms, hierarchical relations (e.g., if the tag is "perennials," look for related biological or horticultural concepts like "native-plants", or if it is "AI" then topics like "Machine Learning", or strong industry associations like "Hardware" and "Semiconductors").
        3. Determine Rank: 
        - Highest rank: Candidates with tags that are direct sub-topics or super-topics of the Tapped Tag.
        - Middle rank: Candidates with tags that share a thematic ecosystem with the Source Tags.
        - Lowest rank: Candidates with generic or unrelated tags.
        4. Contextual Tie-Breaking: If two candidates are equally related to the Tapped Tag, use the Source Tags to break the tie.
        5. Finalize: Sort the candidate IDs from highest conceptual affinity to lowest.
        </INSTRUCTIONS>
        <INPUT>
        Tapped tag: "\(tappedTag)"
        Source tags: [\(sourceTagsJSON)]
        Candidates: [\(candidatesJSON)]
        </INPUT>
        <CONSTRAINTS>
        - Output ONLY a flat JSON array of strings (the "id" values).
        - The array must include every candidate ID provided in the input exactly once.
        - Order the IDs from most related to least related.
        - No markdown formatting (no ```json blocks), no preamble, no explanation.
        </CONSTRAINTS>
        <IMPORTANT>
        Your response must be a raw JSON array. Any text outside of the array will break the integration.
        </IMPORTANT>
        </PROMPT>
        """
        let out = try await collectTemplated(user: user, maxTokens: 192, temperature: 0)
        let ranked = LLMJSONExtractor.decodeStringArray(out) ?? []
        let inputIDs = candidates.map(\.id)
        let inputIDSet = Set(inputIDs)
        var seen = Set<UUID>()
        var ordered: [UUID] = []
        for raw in ranked {
            guard let uuid = UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                  inputIDSet.contains(uuid),
                  !seen.contains(uuid) else { continue }
            ordered.append(uuid)
            seen.insert(uuid)
        }
        for id in inputIDs where !seen.contains(id) {
            ordered.append(id)
        }
        return ordered
    }

    /// Short verification run for Settings.
    func runQuickTest() async throws -> String {
        let user = "Summarize in one short sentence: The quick brown fox jumps over the lazy dog."
        return try await collectTemplated(user: user, maxTokens: 64)
    }

    private func collectTemplated(
        user: String,
        maxTokens: Int,
        temperature: Double = 0.15
    ) async throws -> String {
        try bridge.startTemplatedUserPrompt(
            user,
            options: GenerationOptions(maxTokens: maxTokens, temperature: temperature)
        )
        var acc = ""
        while true {
            try Task.checkCancellation()
            guard let chunk = try bridge.nextTokenChunk() else { break }
            acc.append(chunk)
        }
        return acc
    }
}
