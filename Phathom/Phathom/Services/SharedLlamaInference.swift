import Foundation
import PhathomCore

/// One shared `LlamaContentAnalyzer` for the process so startup warmup, the analyze pipeline, and Settings “test model” reuse the same loaded weights.
actor SharedLlamaInference {
    static let shared = SharedLlamaInference()

    private let analyzer = LlamaContentAnalyzer()
    private var loadedPath: String?
    /// Active security-scoped access for `loadedPath`; released in `unload()`.
    private var scopedAccess: ModelManager.ScopedAccess?

    /// If the user previously picked a GGUF that still exists, load it in the background shortly after launch (skipped when thermally throttled).
    nonisolated static func scheduleWarmFromPersistedSelection() {
        Task(priority: .utility) {
            ModelManager.validateSelection()
            guard !ThermalMonitor.shouldThrottle else { return }
            guard ModelManager.hasReadableSelection else { return }
            try? await SharedLlamaInference.shared.ensureLoaded()
        }
    }

    /// Opens the bookmarked model (scoped access) and loads weights if needed.
    func ensureLoaded() async throws {
        guard let access = ModelManager.openSelection() else {
            ModelManager.setLastLoadFailed(true)
            throw SharedLlamaInferenceError.noModelSelected
        }
        let path = access.path
        if loadedPath == path {
            ModelManager.setLastLoadFailed(false)
            access.end()
            return
        }

        await analyzer.unloadModel()
        scopedAccess?.end()
        scopedAccess = nil
        loadedPath = nil

        scopedAccess = access
        do {
            try await analyzer.loadModel(path: path)
            loadedPath = path
            ModelManager.setLastLoadFailed(false)
        } catch {
            scopedAccess?.end()
            scopedAccess = nil
            loadedPath = nil
            ModelManager.setLastLoadFailed(true)
            throw error
        }
    }

    func unload() async {
        await analyzer.unloadModel()
        loadedPath = nil
        scopedAccess?.end()
        scopedAccess = nil
    }

    func generateSummary(articleText: String) async throws -> [String] {
        try await analyzer.generateSummary(articleText: articleText)
    }

    func generateTags(articleText: String) async throws -> [String] {
        try await analyzer.generateTags(articleText: articleText)
    }

    func generateExtracts(articleText: String) async throws -> [Extract] {
        try await analyzer.generateExtracts(articleText: articleText)
    }

    func runQuickTest() async throws -> String {
        try await analyzer.runQuickTest()
    }
}

enum SharedLlamaInferenceError: LocalizedError {
    case noModelSelected

    var errorDescription: String? {
        switch self {
        case .noModelSelected:
            return "No model is selected or the file is not reachable."
        }
    }
}
