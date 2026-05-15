import Foundation

/// Deterministic markdown → plain text for highlight anchoring (UTF-16 indices match `String.utf16` / `UITextView`).
public enum MarkdownStripper {
    /// Increment when strip rules change; `strippedSourceText` uses this for LLM/search only.
    public static let algorithmVersion: Int = 1

    public static func stripMarkdownToPlain(_ markdown: String) -> String {
        MarkdownPlainDecoration.makePlain(from: markdown)
    }
}
