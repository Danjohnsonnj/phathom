import Foundation

public enum MarkdownNoteHelpers {
    public static func plainTitleLine(from line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix("#") {
            s.removeFirst()
            s = s.trimmingCharacters(in: .whitespaces)
        }
        if s.hasPrefix("- ") {
            s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else if let r = s.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            s.removeSubrange(r)
            s = s.trimmingCharacters(in: .whitespaces)
        }
        if (s.hasPrefix("* ") || s.hasPrefix("+ ")), s.count >= 2 {
            s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Produces single-line plain preview from markdown-ish source text.
    public static func plainSnippet(from markdown: String) -> String {
        let lines = markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { plainTitleLine(from: String($0)) }
            .filter { !$0.isEmpty }
        let combined = lines.joined(separator: " ")
        return combined
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
