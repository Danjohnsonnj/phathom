import PhathomCore
import Foundation

enum ModelManager {
    nonisolated static var selectedModelURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: "phathom.selectedGGUFPath"), !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.path, forKey: "phathom.selectedGGUFPath")
            } else {
                UserDefaults.standard.removeObject(forKey: "phathom.selectedGGUFPath")
            }
        }
    }

    nonisolated static func ggufFilesInDocuments() -> [URL] {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.filter { $0.pathExtension.lowercased() == "gguf" }.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    /// Clears selection when the file no longer exists or is unreadable.
    nonisolated static func validateSelection() {
        guard let url = selectedModelURL else { return }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            selectedModelURL = nil
            return
        }
    }

    nonisolated static func byteString(for url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let n = attrs[.size] as? UInt64 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file)
    }
}
