import Foundation

/// Deterministic markdown → plain text for highlight anchoring (UTF-16 indices match `String.utf16` / `UITextView`).
public enum MarkdownStripper {
    /// Increment when strip rules change; persisted on `Highlight.markdownStripperVersion` for anchor validity.
    public static let algorithmVersion: Int = 1

    public static func stripMarkdownToPlain(_ markdown: String) -> String {
        var s = markdown

        s = replaceRepeating(
            pattern: #"(?s)```[^`]*```"#,
            in: s,
            with: "\n"
        )
        s = replaceRepeating(
            pattern: #"(?m)^[ \t]*`{3}.*$"#,
            in: s,
            with: "\n"
        )

        s = replaceRepeating(
            pattern: #"!\[([^\]]*)\]\([^)]*\)"#,
            in: s,
            with: "$1"
        )
        s = replaceRepeating(
            pattern: #"\[([^\]]*)\]\([^)]*\)"#,
            in: s,
            with: "$1"
        )

        s = replaceRepeating(
            pattern: #"^[ \t]*#{1,6}[ \t]+"#,
            options: [.anchorsMatchLines],
            in: s,
            with: ""
        )

        s = replaceRepeating(
            pattern: #"^[ \t]*([-*_])\s*\1\s*\1[ \t]*$"#,
            options: [.anchorsMatchLines],
            in: s,
            with: "\n"
        )

        s = replaceRepeating(
            pattern: #"`([^`]+)`"#,
            in: s,
            with: "$1"
        )

        for _ in 0 ..< 8 {
            let next = boldItalicPass(s)
            if next == s { break }
            s = next
        }

        s = replaceRepeating(
            pattern: #"[\t ]+"#,
            in: s,
            with: " "
        )
        s = replaceRepeating(
            pattern: #"\n{3,}"#,
            in: s,
            with: "\n\n"
        )

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func boldItalicPass(_ s: String) -> String {
        var out = s
        out = replaceRepeating(
            pattern: #"\*\*([^*]+)\*\*"#,
            in: out,
            with: "$1"
        )
        out = replaceRepeating(
            pattern: #"__([^_]+)__"#,
            in: out,
            with: "$1"
        )
        out = replaceRepeating(
            pattern: #"(?<!\*)\*(?!\*)([^*]+)\*(?!\*)"#,
            in: out,
            with: "$1"
        )
        out = replaceRepeating(
            pattern: #"(?<!_)_(?!_)([^_\n]+)_(?!_)"#,
            in: out,
            with: "$1"
        )
        return out
    }

    private static func replaceRepeating(
        pattern: String,
        options: NSRegularExpression.Options = [],
        in string: String,
        with template: String
    ) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else {
            return string
        }
        var result = string
        var safety = 0
        while safety < 10_000 {
            safety += 1
            let range = NSRange(result.startIndex ..< result.endIndex, in: result)
            let next = re.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: template)
            if next == result { break }
            result = next
        }
        return result
    }
}
