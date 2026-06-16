import Foundation
import PhathomCore

/// Category filter capsule display parts — lead may truncate in UI; ``plusN`` is layout-pinned.
struct CategoryCapsuleLabelParts: Equatable, Sendable {
    let lead: String
    let plusN: Int?
}

/// Encode/decode Library + Notebook multiselect filter state stored in `@AppStorage`.
///
/// Sentinel `""` = pass-through (all values in dimension). Partial = comma-separated raw tokens.
enum LibraryFilterCodec {
    private static let delimiter = ","

    static let kindDisplayOrder: [ContentKind] = [.web, .media, .note]
    static let statusDisplayOrder: [ReadStatus] = [.new, .read, .filed]

    static var kindUniverse: Set<ContentKind> { Set(ContentKind.allCases) }
    static var statusUniverse: Set<ReadStatus> { Set(ReadStatus.allCases) }

    static func categoryUniverse(categoryNames: [String]) -> Set<String> {
        Set(categoryNames + [LibraryCategoryFilterStorage.uncategorizedRaw])
    }

    // MARK: - Pass-through

    static func isKindPassThrough(_ raw: String) -> Bool { raw.isEmpty }
    static func isStatusPassThrough(_ raw: String) -> Bool { raw.isEmpty }
    static func isCategoryPassThrough(_ raw: String) -> Bool { raw.isEmpty }

    // MARK: - Decode (read path)

    static func decodeKinds(_ raw: String) -> Set<ContentKind>? {
        guard !raw.isEmpty else { return nil }
        let kinds = Set(splitTokens(raw).compactMap { ContentKind(rawValue: $0) })
        return kinds.isEmpty ? nil : kinds
    }

    static func decodeStatuses(_ raw: String) -> Set<ReadStatus>? {
        guard !raw.isEmpty else { return nil }
        let statuses = Set(splitTokens(raw).compactMap { ReadStatus(rawValue: $0) })
        return statuses.isEmpty ? nil : statuses
    }

    static func decodeCategories(_ raw: String) -> Set<String>? {
        guard !raw.isEmpty else { return nil }
        let tokens = splitTokens(raw)
        return tokens.isEmpty ? nil : Set(tokens)
    }

    /// Prune deleted category names; empty after prune → sentinel `""`.
    static func sanitizeCategoryRaw(_ raw: String, validNames: [String]) -> String {
        guard !raw.isEmpty else { return "" }
        let allowed = categoryUniverse(categoryNames: validNames)
        let pruned = splitTokens(raw).filter { allowed.contains($0) }
        if pruned.isEmpty { return "" }
        return encodeTokens(pruned)
    }

    // MARK: - Encode (write path)

    static func encodeKinds(_ selection: Set<ContentKind>) -> String {
        if selection == kindUniverse { return "" }
        return encodeTokens(selection.map(\.rawValue).sorted())
    }

    static func encodeStatuses(_ selection: Set<ReadStatus>) -> String {
        if selection == statusUniverse { return "" }
        return encodeTokens(selection.map(\.rawValue).sorted())
    }

    static func encodeCategories(_ selection: Set<String>, universe: Set<String>) -> String {
        if selection == universe { return "" }
        return encodeTokens(Array(selection).sorted())
    }

    static func toggleKind(_ kind: ContentKind, in raw: String) -> String? {
        var selection = resolvedKindSelection(raw: raw)
        if selection.contains(kind) {
            guard selection.count > 1 else { return nil }
            selection.remove(kind)
        } else {
            selection.insert(kind)
        }
        return encodeKinds(selection)
    }

    static func toggleStatus(_ status: ReadStatus, in raw: String) -> String? {
        var selection = resolvedStatusSelection(raw: raw)
        if selection.contains(status) {
            guard selection.count > 1 else { return nil }
            selection.remove(status)
        } else {
            selection.insert(status)
        }
        return encodeStatuses(selection)
    }

    static func toggleCategory(_ token: String, in raw: String, universe: Set<String>) -> String? {
        var selection = resolvedCategorySelection(raw: raw, universe: universe)
        if selection.contains(token) {
            guard selection.count > 1 else { return nil }
            selection.remove(token)
        } else {
            selection.insert(token)
        }
        return encodeCategories(selection, universe: universe)
    }

    static func isKindSelected(_ kind: ContentKind, raw: String) -> Bool {
        resolvedKindSelection(raw: raw).contains(kind)
    }

    static func isStatusSelected(_ status: ReadStatus, raw: String) -> Bool {
        resolvedStatusSelection(raw: raw).contains(status)
    }

    static func isCategorySelected(_ token: String, raw: String, universe: Set<String>) -> Bool {
        resolvedCategorySelection(raw: raw, universe: universe).contains(token)
    }

    static func isKindToggleDisabled(_ kind: ContentKind, raw: String) -> Bool {
        let selection = resolvedKindSelection(raw: raw)
        return selection.count == 1 && selection.contains(kind)
    }

    static func isStatusToggleDisabled(_ status: ReadStatus, raw: String) -> Bool {
        let selection = resolvedStatusSelection(raw: raw)
        return selection.count == 1 && selection.contains(status)
    }

    static func isCategoryToggleDisabled(_ token: String, raw: String, universe: Set<String>) -> Bool {
        let selection = resolvedCategorySelection(raw: raw, universe: universe)
        return selection.count == 1 && selection.contains(token)
    }

    // MARK: - Capsule + accessibility

    static func kindCapsuleLabel(raw: String) -> String {
        let selection = resolvedKindSelection(raw: raw)
        if selection == kindUniverse { return "All" }
        let ordered = kindDisplayOrder.filter { selection.contains($0) }
        return plusNLabel(first: ordered.first.map(kindLabel), count: ordered.count)
    }

    static func statusCapsuleLabel(raw: String) -> String {
        let selection = resolvedStatusSelection(raw: raw)
        if selection == statusUniverse { return "All" }
        let ordered = statusDisplayOrder.filter { selection.contains($0) }
        return plusNLabel(first: ordered.first.map { ReadStatusPresentation.label(for: $0) }, count: ordered.count)
    }

    static func categoryCapsuleLabelParts(raw: String, sortedCategoryNames: [String]) -> CategoryCapsuleLabelParts {
        let universe = categoryUniverse(categoryNames: sortedCategoryNames)
        let selection = resolvedCategorySelection(raw: raw, universe: universe)
        if selection == universe { return CategoryCapsuleLabelParts(lead: "All", plusN: nil) }
        let order = categoryDisplayOrder(sortedCategoryNames: sortedCategoryNames)
        let ordered = order.filter { selection.contains($0) }
        if ordered.count > 1 {
            let leadToken = categoryShortestDisplayLabelToken(in: ordered)
            return CategoryCapsuleLabelParts(
                lead: leadToken.map(categoryTokenLabel) ?? "All",
                plusN: ordered.count - 1
            )
        } else if let first = ordered.first {
            return CategoryCapsuleLabelParts(lead: categoryTokenLabel(first), plusN: nil)
        } else {
            return CategoryCapsuleLabelParts(lead: "All", plusN: nil)
        }
    }

    static func categoryCapsuleLabel(raw: String, sortedCategoryNames: [String]) -> String {
        let parts = categoryCapsuleLabelParts(raw: raw, sortedCategoryNames: sortedCategoryNames)
        guard let plusN = parts.plusN else { return parts.lead }
        return "\(parts.lead) +\(plusN)"
    }

    static func kindAccessibilityValue(raw: String) -> String {
        let selection = resolvedKindSelection(raw: raw)
        if selection == kindUniverse { return "All" }
        return kindDisplayOrder.filter { selection.contains($0) }.map(kindLabel).joined(separator: ", ")
    }

    static func statusAccessibilityValue(raw: String) -> String {
        let selection = resolvedStatusSelection(raw: raw)
        if selection == statusUniverse { return "All" }
        return statusDisplayOrder
            .filter { selection.contains($0) }
            .map { ReadStatusPresentation.label(for: $0) }
            .joined(separator: ", ")
    }

    static func categoryAccessibilityValue(raw: String, sortedCategoryNames: [String]) -> String {
        let universe = categoryUniverse(categoryNames: sortedCategoryNames)
        let selection = resolvedCategorySelection(raw: raw, universe: universe)
        if selection == universe { return "All" }
        return categoryDisplayOrder(sortedCategoryNames: sortedCategoryNames)
            .filter { selection.contains($0) }
            .map(categoryTokenLabel)
            .joined(separator: ", ")
    }

    static func categoryDisplayOrder(sortedCategoryNames: [String]) -> [String] {
        [LibraryCategoryFilterStorage.uncategorizedRaw] + sortedCategoryNames
    }

    // MARK: - Private

    private static func resolvedKindSelection(raw: String) -> Set<ContentKind> {
        decodeKinds(raw) ?? kindUniverse
    }

    private static func resolvedStatusSelection(raw: String) -> Set<ReadStatus> {
        decodeStatuses(raw) ?? statusUniverse
    }

    private static func resolvedCategorySelection(raw: String, universe: Set<String>) -> Set<String> {
        decodeCategories(raw) ?? universe
    }

    private static func splitTokens(_ raw: String) -> [String] {
        raw.split(separator: Character(delimiter), omittingEmptySubsequences: true).map(String.init)
    }

    private static func encodeTokens(_ tokens: [String]) -> String {
        tokens.joined(separator: delimiter)
    }

    private static func kindLabel(_ kind: ContentKind) -> String {
        switch kind {
        case .web: return "Web"
        case .media: return "Media"
        case .note: return "Notes"
        }
    }

    private static func categoryTokenLabel(_ token: String) -> String {
        if token == LibraryCategoryFilterStorage.uncategorizedRaw { return "Uncategorized" }
        return CategoryDisplayFormatter.displayName(token)
    }

    private static func plusNLabel(first: String?, count: Int) -> String {
        guard let first, count > 0 else { return "All" }
        let remaining = count - 1
        if remaining == 0 { return first }
        return "\(first) +\(remaining)"
    }

    /// Shortest display label among selected tokens; ties broken alphabetically (case-insensitive).
    private static func categoryShortestDisplayLabelToken(in ordered: [String]) -> String? {
        guard let shortest = ordered.min(by: { a, b in
            let la = categoryTokenLabel(a)
            let lb = categoryTokenLabel(b)
            if la.count != lb.count { return la.count < lb.count }
            return la.localizedCaseInsensitiveCompare(lb) == .orderedAscending
        }) else { return nil }
        return shortest
    }
}
