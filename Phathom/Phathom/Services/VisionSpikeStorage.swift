import Foundation

/// Phase 0 spike: security-scoped bookmarks for text GGUF + mmproj (DEBUG). Production vision keys ship in Phase 1.
enum VisionSpikeStorage {
    private static let textBookmarkKey = "phathom.visionSpike.textBookmark"
    private static let mmprojBookmarkKey = "phathom.visionSpike.mmprojBookmark"

    /// Legacy path-only keys (removed on first access).
    private static let legacyTextPathKey = "phathom.visionSpike.textGGUFPath"
    private static let legacyMmprojPathKey = "phathom.visionSpike.mmprojPath"

    enum SpikeFileKind: Sendable {
        case textGGUF
        case mmproj
    }

    /// Call from `fileImporter` completion — same pattern as `ModelManager.setSelection`.
    nonisolated static func setTextBookmark(from pickedURL: URL) throws {
        try setBookmark(from: pickedURL, key: textBookmarkKey)
    }

    nonisolated static func setMmprojBookmark(from pickedURL: URL) throws {
        try setBookmark(from: pickedURL, key: mmprojBookmarkKey)
    }

    /// Resolve and begin access for spike run. Caller **must** `end()` both before returning from `describeImage` path.
    nonisolated static func openTextSelection() -> ModelManager.ScopedAccess? {
        migrateLegacyKeysOnce()
        return openBookmark(forKey: textBookmarkKey)
    }

    nonisolated static func openMmprojSelection() -> ModelManager.ScopedAccess? {
        migrateLegacyKeysOnce()
        return openBookmark(forKey: mmprojBookmarkKey)
    }

    /// UI row: filename + whether the file is currently readable.
    nonisolated static func displayState(for kind: SpikeFileKind) -> (name: String, readable: Bool) {
        migrateLegacyKeysOnce()
        let key = kind == .textGGUF ? textBookmarkKey : mmprojBookmarkKey
        guard let data = UserDefaults.standard.data(forKey: key), !data.isEmpty else {
            return ("Not selected", false)
        }
        guard let (url, stale) = resolveBookmark(data: data), !stale else {
            return ("Missing or stale bookmark", false)
        }

        let commenced = url.startAccessingSecurityScopedResource()
        defer {
            if commenced {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let reachable = selectionReachability(url: url).0
        guard reachable, FileManager.default.isReadableFile(atPath: url.path) else {
            return (url.lastPathComponent, false)
        }
        return (url.lastPathComponent, true)
    }

    nonisolated static var hasBothReadable: Bool {
        let t = displayState(for: .textGGUF)
        let m = displayState(for: .mmproj)
        return t.readable && m.readable
    }

    // MARK: - Private

    nonisolated(unsafe) private static var legacyMigrationDone = false

    nonisolated private static func migrateLegacyKeysOnce() {
        if legacyMigrationDone { return }
        legacyMigrationDone = true
        UserDefaults.standard.removeObject(forKey: legacyTextPathKey)
        UserDefaults.standard.removeObject(forKey: legacyMmprojPathKey)
    }

    nonisolated private static func setBookmark(from pickedURL: URL, key: String) throws {
        let accessed = pickedURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                pickedURL.stopAccessingSecurityScopedResource()
            }
        }
        let data = try pickedURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: key)
    }

    nonisolated private static func openBookmark(forKey key: String) -> ModelManager.ScopedAccess? {
        guard let data = UserDefaults.standard.data(forKey: key), !data.isEmpty else {
            return nil
        }
        guard let (url, stale) = resolveBookmark(data: data) else {
            return nil
        }
        if stale {
            return nil
        }

        let commenced = url.startAccessingSecurityScopedResource()
        let (reachable, _) = selectionReachability(url: url)
        if !commenced && !reachable {
            return nil
        }
        if commenced && !reachable {
            url.stopAccessingSecurityScopedResource()
            return nil
        }

        return ModelManager.ScopedAccess(url: url) {
            if commenced {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    nonisolated private static func resolveBookmark(data: Data) -> (URL, Bool)? {
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

    nonisolated private static func selectionReachability(url: URL) -> (Bool, String) {
        if (try? url.checkResourceIsReachable()) == true {
            return (true, "checkResourceIsReachable")
        }
        if let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
           values.isRegularFile == true {
            return (true, "resourceValues.isRegularFile")
        }
        if FileManager.default.fileExists(atPath: url.path) {
            return (true, "fileExistsAtPath")
        }
        return (false, "allChecksFailed")
    }
}
