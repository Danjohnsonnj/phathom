import Foundation

/// Normalizes LLM-produced summary lines for safe single-line display (detail, library, Spotlight).
public enum SummaryLineSanitization {
    public static func sanitizedBullet(_ raw: String) -> String {
        var kept = String.UnicodeScalarView()
        kept.reserveCapacity(raw.unicodeScalars.count)
        for s in raw.unicodeScalars where !strippedCodePoints.contains(s.value) {
            kept.append(s)
        }
        let string = String(kept)
        let pieces = string.split(whereSeparator: \.isWhitespace)
        return pieces.joined(separator: " ")
    }

    public static func sanitizedBullets(_ bullets: [String]) -> [String] {
        bullets.map { sanitizedBullet($0) }.filter { !$0.isEmpty }
    }

    private static let strippedCodePoints: Set<UInt32> = [
        0xFEFF, // BOM
        0x200E, 0x200F, // LRM / RLM
        0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // explicit embedding / override / PDF
        0x2066, 0x2067, 0x2068, 0x2069, // isolate controls
    ]
}
