import Foundation
import PhathomInference

enum AnalyzeProgressModelIdentity {
    nonisolated static func fileIdentity(scopedPath path: String) -> ModelFileIdentity? {
        let url = URL(fileURLWithPath: path)
        guard let byteCount = byteCount(for: url) else { return nil }
        return ModelFileIdentity(filename: url.lastPathComponent, byteCount: byteCount)
    }

    /// Estimate pair at analyze start: Primary required; unreadable Tagging → Primary+Primary.
    nonisolated static func estimateKeyForConfiguredModels() -> ModelPairKey? {
        guard let primaryAccess = ModelManager.openSelection() else { return nil }
        defer { primaryAccess.end() }
        guard let primary = fileIdentity(scopedPath: primaryAccess.path) else { return nil }

        var configuredTagging: ModelFileIdentity?
        if ModelManager.hasTaggingBookmark, let tagAccess = ModelManager.openTaggingSelection() {
            defer { tagAccess.end() }
            configuredTagging = fileIdentity(scopedPath: tagAccess.path)
        }
        return ModelPairKey.forEstimate(primary: primary, configuredTagging: configuredTagging)
    }

    nonisolated static func primaryIdentity() -> ModelFileIdentity? {
        guard let access = ModelManager.openSelection() else { return nil }
        defer { access.end() }
        return fileIdentity(scopedPath: access.path)
    }

    nonisolated static func configuredTaggingIdentityIfAny() -> ModelFileIdentity? {
        guard ModelManager.hasTaggingBookmark else { return nil }
        guard let access = ModelManager.openTaggingSelection() else { return nil }
        defer { access.end() }
        return fileIdentity(scopedPath: access.path)
    }

    nonisolated static func ranTaggingFileIdentityIfAny() -> ModelFileIdentity? {
        guard let access = ModelManager.openTaggingSelection() else { return nil }
        defer { access.end() }
        return fileIdentity(scopedPath: access.path)
    }

    private nonisolated static func byteCount(for url: URL) -> Int? {
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize {
            return size
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? UInt64 {
            return Int(size)
        }
        return nil
    }
}
