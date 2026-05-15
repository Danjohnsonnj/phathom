import Foundation
import PhathomCore

/// Serializes load → inference → unload so concurrent callers (pipeline, Settings test, warmup) cannot unload mid-generation.
struct ModelSession: Sendable {
    private let inference: SharedLlamaInference

    fileprivate init(_ inference: SharedLlamaInference) {
        self.inference = inference
    }

    func summarize(_ text: String) async throws -> [String] {
        try await inference.sessionGenerateSummary(text)
    }

    func tags(_ text: String) async throws -> [String] {
        try await inference.sessionGenerateTags(text)
    }

    func tagsFromDerived(
        summaryBullets: [String],
        extracts: [Extract],
        highlights: [DerivedTagHighlight]
    ) async throws -> [String] {
        try await inference.sessionGenerateTagsFromDerived(
            summaryBullets: summaryBullets,
            extracts: extracts,
            highlights: highlights
        )
    }

    func extracts(_ text: String) async throws -> [Extract] {
        try await inference.sessionGenerateExtracts(text)
    }

    func rankAdjacentItems(
        tappedTag: String,
        sourceTagNames: [String],
        candidates: [(id: UUID, tagNames: [String])]
    ) async throws -> [UUID] {
        try await inference.sessionRankAdjacentItems(
            tappedTag: tappedTag,
            sourceTagNames: sourceTagNames,
            candidates: candidates
        )
    }

    func expandTagsSemantically(query: String, libraryTagNames: [String]) async throws -> [String] {
        try await inference.sessionExpandTagsSemantically(
            query: query,
            libraryTagNames: libraryTagNames
        )
    }

    func analyze(
        _ articleText: String,
        onPartial: @escaping (LlamaContentAnalyzer.PartialAnalysis) -> Void
    ) async throws {
        try await inference.sessionAnalyzeArticle(articleText, onPartial: onPartial)
    }

    func runQuickTest() async throws -> String {
        try await inference.sessionRunQuickTest()
    }

    func cancelInFlight() async {
        await inference.sessionCancelBridgeGeneration()
    }
}

/// One shared `LlamaContentAnalyzer` for the process so startup warmup, the analyze pipeline, and Settings “test model” reuse the same loaded weights.
actor SharedLlamaInference {
    static let shared = SharedLlamaInference()

    private let analyzer = LlamaContentAnalyzer()
    private let lifecycleLock = AsyncLock()
    private var loadedPath: String?
    /// Active security-scoped access for `loadedPath`; released in `unload()`.
    private var scopedAccess: ModelManager.ScopedAccess?

    /// If the user previously picked a GGUF that still exists, load it in the background shortly after launch (skipped when thermally throttled).
    nonisolated static func scheduleWarmFromPersistedSelection() {
        Task(priority: .utility) {
            ModelManager.validateSelection()
            guard !ThermalMonitor.shouldThrottle else { return }
            guard ModelManager.hasReadableSelection else { return }
            try? await SharedLlamaInference.shared.withSession(unloadOnExit: false, pipelineItemID: nil) { _ in }
        }
    }

    /// Ask llama.cpp to stop sampling; use when e.g. a BG task expires (does not unload — the session owns that).
    nonisolated static func signalCancelInFlight() {
        Task { await shared.sessionCancelBridgeGeneration() }
    }

    /// Acquire the lifecycle lock, load weights if needed, run `work`, then optionally unload and release the lock.
    func withSession<R: Sendable>(
        unloadOnExit: Bool = true,
        pipelineItemID: UUID?,
        _ work: @escaping (ModelSession) async throws -> R
    ) async throws -> R {
        await lifecycleLock.acquire()
        do {
            if let itemID = pipelineItemID {
                let start = Date()
                try await ensureLoadedLocked()
                PipelineMetrics.logSyncElapsed("load_model", itemID: itemID, start: start)
            } else {
                try await ensureLoadedLocked()
            }
            let result = try await work(ModelSession(self))
            if unloadOnExit { await unloadLocked() }
            await lifecycleLock.release()
            return result
        } catch {
            if unloadOnExit { await unloadLocked() }
            await lifecycleLock.release()
            throw error
        }
    }

    /// Convenience for callers that do not need `load_model` pipeline metrics (Settings, warmup).
    func withSession<R: Sendable>(
        unloadOnExit: Bool = true,
        _ work: @escaping (ModelSession) async throws -> R
    ) async throws -> R {
        try await withSession(unloadOnExit: unloadOnExit, pipelineItemID: nil, work)
    }

    // MARK: - Session entry points (only valid while lifecycle lock is held)

    private func ensureLoadedLocked() async throws {
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

    private func unloadLocked() async {
        await analyzer.unloadModel()
        loadedPath = nil
        scopedAccess?.end()
        scopedAccess = nil
    }

    fileprivate func sessionAnalyzeArticle(
        _ articleText: String,
        onPartial: @escaping (LlamaContentAnalyzer.PartialAnalysis) -> Void
    ) async throws {
        try await analyzer.analyzeArticle(articleText, onPartial: onPartial)
    }

    fileprivate func sessionGenerateSummary(_ articleText: String) async throws -> [String] {
        try await analyzer.generateSummary(articleText: articleText)
    }

    fileprivate func sessionGenerateTags(_ articleText: String) async throws -> [String] {
        try await analyzer.generateTags(articleText: articleText)
    }

    fileprivate func sessionGenerateTagsFromDerived(
        summaryBullets: [String],
        extracts: [Extract],
        highlights: [DerivedTagHighlight]
    ) async throws -> [String] {
        try await analyzer.generateTagsFromDerived(
            summaryBullets: summaryBullets,
            extracts: extracts,
            highlights: highlights
        )
    }

    fileprivate func sessionGenerateExtracts(_ articleText: String) async throws -> [Extract] {
        try await analyzer.generateExtracts(articleText: articleText)
    }

    fileprivate func sessionRunQuickTest() async throws -> String {
        try await analyzer.runQuickTest()
    }

    fileprivate func sessionRankAdjacentItems(
        tappedTag: String,
        sourceTagNames: [String],
        candidates: [(id: UUID, tagNames: [String])]
    ) async throws -> [UUID] {
        try await analyzer.rankAdjacentItems(
            tappedTag: tappedTag,
            sourceTagNames: sourceTagNames,
            candidates: candidates
        )
    }

    fileprivate func sessionExpandTagsSemantically(
        query: String,
        libraryTagNames: [String]
    ) async throws -> [String] {
        try await analyzer.expandTagsSemantically(
            query: query,
            libraryTagNames: libraryTagNames
        )
    }

    fileprivate func sessionCancelBridgeGeneration() async {
        await analyzer.cancelBridgeGeneration()
    }

    /// Same FIFO mutual exclusion as `withSession`, without loading a GGUF — for unit tests (e.g. simulators with no model file).
    internal func _test_withExclusiveLifecycleLock<R: Sendable>(
        _ work: @Sendable () async throws -> R
    ) async rethrows -> R {
        await lifecycleLock.acquire()
        do {
            let result = try await work()
            await lifecycleLock.release()
            return result
        } catch {
            await lifecycleLock.release()
            throw error
        }
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
