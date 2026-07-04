import Foundation

/// Sticky retag merge: LLM output ∪ user provenance names on the item.
public enum TagPipelineMerge {
    public static func mergedForUpsert(llmTags: [String], stickyTags: [String]) -> [String] {
        TagNameNormalizer.normalize(many: llmTags + stickyTags)
    }
}
