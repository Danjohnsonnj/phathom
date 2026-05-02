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
}
