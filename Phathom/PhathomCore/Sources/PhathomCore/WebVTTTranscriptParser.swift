import Foundation

/// Strips WEBVTT timing/metadata and returns plain spoken text for summarization.
public enum WebVTTTranscriptParser {
    /// Converts WEBVTT content to a single paragraph-style string, capped for model context limits.
    public static func plainText(from vtt: String, maxCharacters: Int = 8_000) -> String {
        var pieces: [String] = []
        var inStyleBlock = false

        for rawLine in vtt.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                inStyleBlock = false
                continue
            }

            let lower = line.lowercased()
            if lower == "webvtt" { continue }
            if lower.hasPrefix("note") { continue }
            if lower.hasPrefix("region") || lower.hasPrefix("kind:") { continue }

            if lower == "style" {
                inStyleBlock = true
                continue
            }
            if inStyleBlock { continue }

            if line.contains("-->") { continue }

            if line.allSatisfy(\.isNumber) { continue }

            if line.hasPrefix("{") && line.hasSuffix("}") { continue }

            pieces.append(line)
        }

        var combined = pieces.joined(separator: " ")
        let ws = try? NSRegularExpression(pattern: #"\s+"#, options: [])
        if let ws {
            combined = ws.stringByReplacingMatches(
                in: combined,
                options: [],
                range: NSRange(location: 0, length: (combined as NSString).length),
                withTemplate: " "
            )
        }
        combined = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        if maxCharacters > 0, combined.count > maxCharacters {
            combined = String(combined.prefix(maxCharacters)) + "…"
        }
        return combined
    }
}
