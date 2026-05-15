import Foundation

public struct Extract: Codable, Identifiable, Hashable, Sendable {
    public var id: String { label }
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

/// User highlight + optional note passed into derived tagging (`user_highlights` JSON).
public struct DerivedTagHighlight: Codable, Hashable, Sendable {
    public var quote: String
    public var note: String?

    public init(quote: String, note: String?) {
        self.quote = quote
        self.note = note
    }

    /// Values embedded in tagging prompts: strip most control characters and cap length (prompt-injection hardening).
    public static func forTaggingPrompt(quote: String, note: String?) -> DerivedTagHighlight {
        DerivedTagHighlight(
            quote: Self.sanitizeForPromptEmbedding(quote, maxUTF16: 2_000),
            note: note.map { Self.sanitizeForPromptEmbedding($0, maxUTF16: 2_000) }
        )
    }

    private static func sanitizeForPromptEmbedding(_ string: String, maxUTF16: Int) -> String {
        let control = CharacterSet.controlCharacters
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(min(string.utf16.count, maxUTF16))
        var utf16Count = 0
        for scalar in string.unicodeScalars {
            guard utf16Count < maxUTF16 else { break }
            if scalar == "\n" || scalar == "\r" || scalar == "\t" {
                scalars.append(scalar)
                utf16Count += scalar.utf16.count
                continue
            }
            if control.contains(scalar) { continue }
            if scalar.properties.generalCategory == .privateUse { continue }
            scalars.append(scalar)
            utf16Count += scalar.utf16.count
        }
        return String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public extension ContentItem {
    var decodedSummaryBullets: [String] {
        guard let data = summaryBullets?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    /// Summary bullets safe for on-screen one-line rows (strips bidi controls, normalizes whitespace).
    var displaySummaryBullets: [String] {
        SummaryLineSanitization.sanitizedBullets(decodedSummaryBullets)
    }

    func encodeSummaryBullets(_ bullets: [String]) {
        summaryBullets = String(data: (try? JSONEncoder().encode(bullets)) ?? Data(), encoding: .utf8)
    }

    var decodedExtracts: [Extract] {
        guard let data = extracts?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Extract].self, from: data)) ?? []
    }

    func encodeExtracts(_ items: [Extract]) {
        extracts = String(data: (try? JSONEncoder().encode(items)) ?? Data(), encoding: .utf8)
    }
}
