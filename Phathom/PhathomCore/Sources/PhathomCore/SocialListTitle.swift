import Foundation

/// Builds list titles from social captions: first line, max 100 chars, word-safe trim.
public enum SocialListTitle {
    /// First line of `caption`, at most 100 characters, cut back to the last space.
    public static func fromCaption(_ caption: String) -> String? {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let line = trimmed.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !line.isEmpty else { return nil }

        if line.count <= 100 {
            return line
        }
        let prefix = String(line.prefix(100))
        if let lastSpace = prefix.lastIndex(of: " "), lastSpace > prefix.startIndex {
            return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
