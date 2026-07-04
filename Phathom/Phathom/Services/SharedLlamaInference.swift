import Foundation
import PhathomCore

/// Which GGUF bookmark `SharedLlamaInference` prefers when acquiring a session.
public enum ModelSessionRole: Sendable {
    /// Primary bookmark (`ModelManager.openSelection`).
    case primary
    /// Optional tagging bookmark first; falls back to primary when tagging missing or load fails.
    case taggingPreferred
    /// Vision VLM text GGUF + mmproj — unloads primary/tagging before session (8 GB memory policy).
    case vision
}

extension ModelSessionRole: Equatable {
    public nonisolated static func == (lhs: ModelSessionRole, rhs: ModelSessionRole) -> Bool {
        switch (lhs, rhs) {
        case (.primary, .primary), (.taggingPreferred, .taggingPreferred), (.vision, .vision):
            return true
        default:
            return false
        }
    }
}

/// Serializes load → inference → unload so concurrent callers (pipeline, Settings test, warmup) cannot unload mid-generation.
public struct ModelSession: Sendable {
    private let inference: SharedLlamaInference

    fileprivate init(_ inference: SharedLlamaInference) {
        self.inference = inference
    }

    public func summarize(_ text: String) async throws -> [String] {
        try await inference.sessionGenerateSummary(text)
    }

    public func tags(_ text: String) async throws -> [String] {
        try await inference.sessionGenerateTags(text)
    }

    public func tagsFromDerived(
        summaryBullets: [String],
        extracts: [Extract],
        highlights: [DerivedTagHighlight],
        subjectSeed: [String] = []
    ) async throws -> [String] {
        try await inference.sessionGenerateTagsFromDerived(
            summaryBullets: summaryBullets,
            extracts: extracts,
            highlights: highlights,
            subjectSeed: subjectSeed
        )
    }

    public func extracts(_ text: String) async throws -> [Extract] {
        try await inference.sessionGenerateExtracts(text)
    }

    public func rankAdjacentItems(
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

    public func expandTagsSemantically(query: String, libraryTagNames: [String]) async throws -> [String] {
        try await inference.sessionExpandTagsSemantically(
            query: query,
            libraryTagNames: libraryTagNames
        )
    }

    public func analyze(
        _ articleText: String,
        onPartial: @escaping (LlamaContentAnalyzer.PartialAnalysis) -> Void
    ) async throws {
        try await inference.sessionAnalyzeArticle(articleText, onPartial: onPartial)
    }

    public func runQuickTest() async throws -> String {
        try await inference.sessionRunQuickTest()
    }

    /// Settings smoke: describe a JPEG via production vision bookmarks (`ModelSessionRole.vision`).
    public func runVisionSmokeTest(jpegData: Data) async throws -> String {
        try await inference.sessionRunVisionSmokeTest(jpegData: jpegData)
    }

    /// Pipeline / recovery: describe photo bytes via `ModelSessionRole.vision` session.
    public func describeImage(jpegData: Data) async throws -> String {
        try await inference.sessionDescribeImage(jpegData: jpegData)
    }

    public func cancelInFlight() async {
        await inference.sessionCancelBridgeGeneration()
    }
}

/// One shared `LlamaContentAnalyzer` for the process so startup warmup, the analyze pipeline, and Settings “test model” reuse the same loaded weights.
public actor SharedLlamaInference {
    public static let shared = SharedLlamaInference()

    private let llamaRuntime = LlamaCppRuntime()
    private let analyzer: LlamaContentAnalyzer
    private let visionAnalyzer: VisionContentAnalyzer
    private let lifecycleLock = AsyncLock()
    private var loadedPath: String?
    /// Active security-scoped access for `loadedPath`; released in `unload()`.
    private var scopedAccess: ModelManager.ScopedAccess?
    /// Set during `ensureLoadedLocked(role: .taggingPreferred)` so Settings can report fallback after `runQuickTest`.
    public private(set) var lastTaggingPreferredUsedPrimaryFallback = false

    private init() {
        analyzer = LlamaContentAnalyzer(bridge: llamaRuntime)
        visionAnalyzer = VisionContentAnalyzer(runtime: llamaRuntime)
    }

    /// If the user previously picked a GGUF that still exists, load it in the background shortly after launch (skipped when thermally throttled).
    public nonisolated static func scheduleWarmFromPersistedSelection() {
        Task(priority: .utility) {
            ModelManager.validateSelection()
            guard !ThermalMonitor.shouldThrottle else { return }
            guard ModelManager.hasReadableSelection else { return }
            try? await SharedLlamaInference.shared.withSession(
                role: .primary,
                unloadOnExit: false,
                pipelineItemID: nil,
                rewarmPrimaryAfterVision: true
            ) { _ in }
        }
    }

    /// Ask llama.cpp to stop sampling; use when e.g. a BG task expires (does not unload — the session owns that).
    public nonisolated static func signalCancelInFlight() {
        Task { await shared.sessionCancelBridgeGeneration() }
    }

    /// Acquire the lifecycle lock, load weights if needed, run `work`, then optionally unload and release the lock.
    public func withSession<R: Sendable>(
        role: ModelSessionRole = .primary,
        unloadOnExit: Bool = true,
        pipelineItemID: UUID?,
        rewarmPrimaryAfterVision: Bool = true,
        _ work: @escaping (ModelSession) async throws -> R
    ) async throws -> R {
        if role == .vision {
            return try await withExclusiveVisionWorkload(
                unloadOnExit: unloadOnExit,
                rewarmPrimaryAfterVision: rewarmPrimaryAfterVision
            ) {
                try await ensureVisionBookmarksReadableLocked()
                return try await work(ModelSession(self))
            }
        }

        await lifecycleLock.acquire()
        do {
            if let itemID = pipelineItemID {
                let start = Date()
                try await ensureLoadedLocked(role: role)
                PipelineMetrics.logSyncElapsed("load_model", itemID: itemID, start: start)
            } else {
                try await ensureLoadedLocked(role: role)
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
    public func withSession<R: Sendable>(
        role: ModelSessionRole = .primary,
        unloadOnExit: Bool = true,
        rewarmPrimaryAfterVision: Bool = true,
        _ work: @escaping (ModelSession) async throws -> R
    ) async throws -> R {
        try await withSession(
            role: role,
            unloadOnExit: unloadOnExit,
            pipelineItemID: nil,
            rewarmPrimaryAfterVision: rewarmPrimaryAfterVision,
            work
        )
    }

    // MARK: - Session entry points (only valid while lifecycle lock is held)

    private func ensureLoadedLocked(role: ModelSessionRole) async throws {
        switch role {
        case .primary:
            try await ensureLoadedFromPrimaryBookmarkLocked()
        case .taggingPreferred:
            lastTaggingPreferredUsedPrimaryFallback = false
            if let tagAccess = ModelManager.openTaggingSelection() {
                do {
                    try await swapToLoadedModelIfNeeded(access: tagAccess)
                    return
                } catch {
                    lastTaggingPreferredUsedPrimaryFallback = true
                    #if DEBUG
                    print("[SharedLlamaInference] tagging model load failed, falling back to primary: \(error.localizedDescription)")
                    #endif
                }
            } else {
                lastTaggingPreferredUsedPrimaryFallback = true
            }
            try await ensureLoadedFromPrimaryBookmarkLocked()
        case .vision:
            break
        }
    }

    private func ensureVisionBookmarksReadableLocked() throws {
        guard ModelManager.hasReadableVisionSelection else {
            throw SharedLlamaInferenceError.noVisionModelSelected
        }
    }

    /// Unloads primary/tagging weights and holds the lifecycle lock for vision-only work (VLM loads elsewhere).
    private func withExclusiveVisionWorkload<R: Sendable>(
        unloadOnExit: Bool = true,
        rewarmPrimaryAfterVision: Bool = true,
        _ work: @Sendable () async throws -> R
    ) async throws -> R {
        await lifecycleLock.acquire()
        await unloadLocked()
        do {
            let result = try await work()
            if unloadOnExit { await unloadLocked() }
            await lifecycleLock.release()
            if rewarmPrimaryAfterVision {
                Self.scheduleWarmFromPersistedSelection()
            }
            return result
        } catch {
            if unloadOnExit { await unloadLocked() }
            await lifecycleLock.release()
            if rewarmPrimaryAfterVision {
                Self.scheduleWarmFromPersistedSelection()
            }
            throw error
        }
    }

    private func ensureLoadedFromPrimaryBookmarkLocked() async throws {
        guard let access = ModelManager.openSelection() else {
            ModelManager.setLastLoadFailed(true)
            throw SharedLlamaInferenceError.noModelSelected
        }
        try await swapToLoadedModelIfNeeded(access: access)
    }

    private func swapToLoadedModelIfNeeded(access: ModelManager.ScopedAccess) async throws {
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
        await visionAnalyzer.unloadModel()
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
        highlights: [DerivedTagHighlight],
        subjectSeed: [String] = []
    ) async throws -> [String] {
        try await analyzer.generateTagsFromDerived(
            summaryBullets: summaryBullets,
            extracts: extracts,
            highlights: highlights,
            subjectSeed: subjectSeed
        )
    }

    fileprivate func sessionGenerateExtracts(_ articleText: String) async throws -> [Extract] {
        try await analyzer.generateExtracts(articleText: articleText)
    }

    fileprivate func sessionRunQuickTest() async throws -> String {
        try await analyzer.runQuickTest()
    }

    fileprivate func sessionRunVisionSmokeTest(jpegData: Data) async throws -> String {
        guard let textAccess = ModelManager.openVisionTextSelection(),
              let mmprojAccess = ModelManager.openVisionMmprojSelection()
        else {
            throw SharedLlamaInferenceError.noVisionModelSelected
        }
        defer {
            textAccess.end()
            mmprojAccess.end()
        }
        let result = try await visionAnalyzer.describeImage(
            jpegData: jpegData,
            textModelPath: textAccess.path,
            mmprojPath: mmprojAccess.path
        )
        return result.description
    }

    fileprivate func sessionDescribeImage(jpegData: Data) async throws -> String {
        let result = try await sessionDescribeImageResult(jpegData: jpegData)
        return result.description
    }

    fileprivate func sessionDescribeImageResult(jpegData: Data) async throws -> VisionDescribeResult {
        guard let textAccess = ModelManager.openVisionTextSelection(),
              let mmprojAccess = ModelManager.openVisionMmprojSelection()
        else {
            throw SharedLlamaInferenceError.noVisionModelSelected
        }
        defer {
            textAccess.end()
            mmprojAccess.end()
        }
        return try await visionAnalyzer.describeImage(
            jpegData: jpegData,
            textModelPath: textAccess.path,
            mmprojPath: mmprojAccess.path
        )
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
        await visionAnalyzer.cancelGeneration()
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

public enum SharedLlamaInferenceError: LocalizedError {
    case noModelSelected
    case noVisionModelSelected

    public var errorDescription: String? {
        switch self {
        case .noModelSelected:
            return "No model is selected or the file is not reachable."
        case .noVisionModelSelected:
            return "No vision model is selected or the text GGUF and mmproj files are not reachable."
        }
    }
}
