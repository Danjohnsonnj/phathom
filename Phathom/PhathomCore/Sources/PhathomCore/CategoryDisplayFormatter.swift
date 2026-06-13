import Foundation

/// Category names are stored as **lowercase ASCII kebab-case** (same rules as tags via ``TagNameNormalizer``).
/// UI shows **sentence case** with spaces instead of hyphens.
public enum CategoryDisplayFormatter {
    public static func displayName(_ storedName: String) -> String {
        let spaced = storedName.replacingOccurrences(of: "-", with: " ")
        guard let first = spaced.first else { return storedName }
        return first.uppercased() + String(spaced.dropFirst())
    }

    /// Returns `nil` if input is invalid per ``TagNameNormalizer`` (length, charset after normalization).
    public static func normalize(_ raw: String) -> String? {
        TagNameNormalizer.normalize(raw)
    }
}

/// Category filter tokens: sentinel `""` (all buckets), ``uncategorizedRaw``, or kebab-case stored names (comma-separated when partial).
public enum LibraryCategoryFilterStorage {
    public static let uncategorizedRaw = "__uncategorized__"
}
