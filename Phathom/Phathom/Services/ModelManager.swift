import Foundation

/// Persists the user's chosen `.gguf` as a security-scoped bookmark so the file stays in place (e.g. shared across apps under **On My iPhone**) instead of copying into Phathom's Documents.
enum ModelManager {
    private nonisolated static let bookmarkKey = "phathom.selectedGGUFBookmark"
    /// Legacy path-only storage from before bookmarks; migrated once into `bookmarkKey`.
    private nonisolated static let legacyPathKey = "phathom.selectedGGUFPath"

    /// Holds an active `startAccessingSecurityScopedResource` match; call `end()` when done reading.
    struct ScopedAccess: Sendable {
        let url: URL
        private let stopAccess: @Sendable () -> Void

        init(url: URL, stopAccess: @escaping @Sendable () -> Void) {
            self.url = url
            self.stopAccess = stopAccess
        }

        func end() {
            stopAccess()
        }

        /// Normalized path for llama.cpp / file checks.
        var path: String {
            url.standardizedFileURL.path
        }
    }

    enum SelectionDisplayState: Equatable, Sendable {
        /// No bookmark (after migration).
        case noSelection
        /// Bookmark resolves and file is readable.
        case ready(name: String, byteString: String)
        /// Bookmark exists but file is missing or unreadable (user should re-pick or forget).
        case missingFile
    }

    /// `true` when a non-empty bookmark exists after legacy migration (may still be `.missingFile` on disk).
    nonisolated static var hasBookmark: Bool {
        migrateLegacyIfNeeded()
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return false }
        return !data.isEmpty
    }

    /// Cheap probe used by the BG pipeline before fetching the next analyze item, so items stay in
    /// `.embedding` instead of transitioning to `.failed` when no model is picked. The subsequent
    /// `ensureLoaded()` re-opens scope for the actual load.
    nonisolated static var hasReadableSelection: Bool {
        guard let access = openSelection() else { return false }
        access.end()
        return true
    }

    nonisolated static func clearSelection() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: legacyPathKey)
    }

    /// Call from the `fileImporter` completion handler. The URL must still be valid for security-scoped access (call `startAccessingSecurityScopedResource` if needed before this).
    nonisolated static func setSelection(from pickedURL: URL) throws {
        migrateLegacyIfNeeded()

        let accessed = pickedURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                pickedURL.stopAccessingSecurityScopedResource()
            }
        }

        // `URL.BookmarkCreationOptions.withSecurityScope` is unavailable on iOS; `[]` is correct for
        // document-picker URLs — pair with `startAccessingSecurityScopedResource` after resolving.
        let data = try pickedURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: legacyPathKey)
    }

    /// Resolve bookmark and begin access. Returns `nil` if missing, stale, unreadable, or access denied. Caller **must** call `end()` on success.
    nonisolated static func openSelection() -> ScopedAccess? {
        migrateLegacyIfNeeded()

        guard let data = UserDefaults.standard.data(forKey: bookmarkKey), !data.isEmpty else {
            return nil
        }
        guard let (url, stale) = resolveBookmark(data: data) else {
            return nil
        }
        if stale {
            return nil
        }

        let commenced = url.startAccessingSecurityScopedResource()
        let readable = FileManager.default.isReadableFile(atPath: url.path)
        if !commenced && !readable {
            return nil
        }
        if commenced && !readable {
            url.stopAccessingSecurityScopedResource()
            return nil
        }

        return ScopedAccess(url: url) {
            if commenced {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    /// UI: status row without holding long-lived scoped access.
    nonisolated static func selectionDisplayState() -> SelectionDisplayState {
        migrateLegacyIfNeeded()

        guard let data = UserDefaults.standard.data(forKey: bookmarkKey), !data.isEmpty else {
            return .noSelection
        }
        guard let (url, stale) = resolveBookmark(data: data), !stale else {
            return .missingFile
        }

        let commenced = url.startAccessingSecurityScopedResource()
        defer {
            if commenced {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return .missingFile
        }
        let name = url.lastPathComponent
        let byteString = byteString(forPath: url.path)
        return .ready(name: name, byteString: byteString)
    }

    /// Drops bookmark data when resolution says the reference is stale. Does **not** remove bookmark when the file is merely missing on disk (so Settings can show **missingFile**).
    nonisolated static func validateSelection() {
        migrateLegacyIfNeeded()

        guard let data = UserDefaults.standard.data(forKey: bookmarkKey), !data.isEmpty else {
            return
        }
        guard let (_, stale) = resolveBookmark(data: data) else {
            clearSelection()
            return
        }
        if stale {
            clearSelection()
        }
    }

    private nonisolated static func resolveBookmark(data: Data) -> (URL, Bool)? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return nil
        }
        return (url, stale)
    }

    private nonisolated static func byteString(forPath path: String) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let n = attrs[.size] as? UInt64 else {
            return "—"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file)
    }

    /// Process-lifetime: after a full `migrateLegacyIfNeeded()` pass, skip re-reading UserDefaults for migration.
    private nonisolated(unsafe) static var legacyMigrationDone = false

    private nonisolated static func migrateLegacyIfNeeded() {
        if legacyMigrationDone { return }

        if let data = UserDefaults.standard.data(forKey: bookmarkKey), !data.isEmpty {
            legacyMigrationDone = true
            return
        }

        guard let path = UserDefaults.standard.string(forKey: legacyPathKey), !path.isEmpty else {
            legacyMigrationDone = true
            return
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            UserDefaults.standard.removeObject(forKey: legacyPathKey)
            legacyMigrationDone = true
            return
        }

        do {
            // Files inside the app sandbox don't need `.withSecurityScope`.
            let data = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            UserDefaults.standard.removeObject(forKey: legacyPathKey)
            legacyMigrationDone = true
        } catch {
            // Leave legacy key in place so the user can still be migrated on next successful pick.
        }
    }
}
