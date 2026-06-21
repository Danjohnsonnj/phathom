import Foundation

/// `@AppStorage` key and codec for Notebook item expand/collapse state.
enum NotebookExpansionStorage {
    static let expandedIDsKey = "notebook.expandedItemIDs"

    static func decodeExpandedIDs(_ raw: String) -> Set<UUID> {
        guard !raw.isEmpty else { return [] }
        var ids = Set<UUID>()
        for token in raw.split(separator: ",") {
            let trimmed = token.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let id = UUID(uuidString: String(trimmed)) else { continue }
            ids.insert(id)
        }
        return ids
    }

    static func encodeExpandedIDs(_ ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: ",")
    }
}
