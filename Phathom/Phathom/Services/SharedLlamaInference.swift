import PhathomCore
import Foundation

/// One shared `LlamaContentAnalyzer` for the process so startup warmup, the analyze pipeline, and Settings “test model” reuse the same loaded weights.
actor SharedLlamaInference {
    static let shared = SharedLlamaInference()

    private let analyzer = LlamaContentAnalyzer()
    private var loadedPath: String?

    /// If the user previously picked a GGUF that still exists, load it in the background shortly after launch (skipped when thermally throttled).
    nonisolated static func scheduleWarmFromPersistedSelection() {
        Task(priority: .utility) {
            ModelManager.validateSelection()
            guard !ThermalMonitor.shouldThrottle else { return }
            guard let url = ModelManager.selectedModelURL,
                  FileManager.default.isReadableFile(atPath: url.path) else { return }
            let path = url.standardizedFileURL.path
            try? await SharedLlamaInference.shared.ensureLoaded(path: path)
        }
    }

    func ensureLoaded(path: String) async throws {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        if loadedPath == normalized { return }
        try await analyzer.loadModel(path: normalized)
        loadedPath = normalized
    }

    func unload() async {
        await analyzer.unloadModel()
        loadedPath = nil
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
