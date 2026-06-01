import Foundation

/// Deterministic cleanup for on-device vision captions before persisting `mediaDescription`.
public enum MediaDescriptionSanitization {
    public static func clean(_ raw: String) -> String {
        let normalized = SummaryLineSanitization.sanitizedBullet(raw)
        guard !normalized.isEmpty else { return "" }

        let stripped = stripBoilerplateOpener(normalized)
        if stripped.isEmpty {
            return isEmptyTextFiller(sentence: normalized) ? "" : normalized
        }

        var sentences = splitSentences(stripped)

        if sentences.count == 1, isEmptyTextFiller(sentence: sentences[0]) {
            return ""
        }
        if sentences.count >= 2, isEmptyTextFiller(sentence: sentences[1]) {
            sentences.remove(at: 1)
        }
        if sentences.count > 2 {
            sentences = Array(sentences.prefix(2))
        }

        return sentences.joined(separator: " ")
    }

    private static let boilerplateOpeners = [
        "This image shows",
        "The image shows",
        "The image depicts",
        "This photo shows",
        "This picture shows",
        "The photo shows",
    ]

    private static let emptyTextFillerSentences: Set<String> = [
        "no visible text",
        "there is no readable text",
        "no readable text",
        "no text visible",
        "none",
        "n/a",
    ]

    private static func stripBoilerplateOpener(_ text: String) -> String {
        let lowered = text.lowercased()
        for opener in boilerplateOpeners {
            let openerLower = opener.lowercased()
            if lowered.hasPrefix(openerLower) {
                var remainder = String(text.dropFirst(opener.count))
                remainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
                return capitalizeFirst(remainder)
            }
        }
        return text
    }

    private static func splitSentences(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        var sentences: [String] = []
        var segmentStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "." else {
                index = text.index(after: index)
                continue
            }

            let nextIndex = text.index(after: index)
            let hasTrailingWhitespace: Bool
            if nextIndex == text.endIndex {
                hasTrailingWhitespace = true
            } else {
                hasTrailingWhitespace = text[nextIndex].isWhitespace
            }

            if hasTrailingWhitespace {
                let body = String(text[segmentStart..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty {
                    sentences.append(body + ".")
                }
                segmentStart = nextIndex
                while segmentStart < text.endIndex, text[segmentStart].isWhitespace {
                    segmentStart = text.index(after: segmentStart)
                }
                index = segmentStart
                continue
            }

            index = text.index(after: index)
        }

        let tail = String(text[segmentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            sentences.append(tail.hasSuffix(".") ? tail : tail + ".")
        }
        return sentences
    }

    private static func isEmptyTextFiller(sentence: String) -> Bool {
        let normalized = sentence
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return emptyTextFillerSentences.contains(normalized)
    }

    private static func capitalizeFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
