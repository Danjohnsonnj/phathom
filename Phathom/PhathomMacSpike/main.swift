import Foundation
import PhathomCore
import PhathomInference

@main
enum PhathomMacSpikeMain {
    static func main() async {
        do {
            try await run()
            print("[PhathomMacSpike] overall=PASS peak_mb=\(String(format: "%.1f", SpikeMemory.peakMegabytes()))")
            exit(0)
        } catch {
            fputs("[PhathomMacSpike] overall=FAIL error=\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        SpikeMemory.resetPeakTracking()

        let primaryGGUF = try SpikePaths.requireEnv("PHATHOM_SPIKE_GGUF")
        let visionGGUF = try SpikePaths.requireEnv("PHATHOM_SPIKE_VISION_GGUF")
        let mmproj = try SpikePaths.requireEnv("PHATHOM_SPIKE_MMPROJ")
        let articlePath = try SpikePaths.fixturePath("article.md", envKey: "PHATHOM_SPIKE_ARTICLE")
        let jpegPath = try SpikePaths.fixturePath("sample.jpg", envKey: "PHATHOM_SPIKE_JPEG")

        guard FileManager.default.fileExists(atPath: primaryGGUF) else {
            throw SpikeError.stepFailed("Primary GGUF not found: \(primaryGGUF)")
        }
        guard FileManager.default.fileExists(atPath: visionGGUF) else {
            throw SpikeError.stepFailed("Vision GGUF not found: \(visionGGUF)")
        }
        guard FileManager.default.fileExists(atPath: mmproj) else {
            throw SpikeError.stepFailed("mmproj not found: \(mmproj)")
        }

        let article = try String(contentsOfFile: articlePath, encoding: .utf8)
        let jpegData = try Data(contentsOf: URL(fileURLWithPath: jpegPath))

        // Step 1 — load primary GGUF + quick test
        let textRuntime = LlamaCppRuntime()
        let analyzer = LlamaContentAnalyzer(bridge: textRuntime)
        let loadStart = Date()
        try await analyzer.loadModel(path: primaryGGUF)
        SpikeMemory.recordSample()
        let loadWall = Date().timeIntervalSince(loadStart)
        let quickStart = Date()
        let quick = try await analyzer.runQuickTest()
        SpikeMemory.recordSample()
        let quickWall = Date().timeIntervalSince(quickStart)
        SpikeReporter.logStep(
            1,
            "load_gguf",
            wallSeconds: loadWall + quickWall,
            peakMB: SpikeMemory.peakMegabytes(),
            detail: String(format: "load_s=%.2f quick_s=%.2f quick_test_chars=%d", loadWall, quickWall, quick.count)
        )

        // Step 2 — full analyze (summary + extracts)
        let analyzeStart = Date()
        var summaryBullets = 0
        var extractCount = 0
        try await analyzer.analyzeArticle(article) { partial in
            switch partial {
            case .summary(let bullets):
                summaryBullets = bullets.count
            case .extracts(let extracts):
                extractCount = extracts.count
            }
        }
        if summaryBullets == 0,
           extractCount > 0,
           LlamaContentAnalyzer.sourceWordCount(article) > LlamaContentAnalyzer.minimumSourceWordsForSummary {
            let retryBullets = try await analyzer.summarizeArticle(article)
            summaryBullets = retryBullets.count
        }
        SpikeMemory.recordSample()
        guard summaryBullets > 0 else {
            throw SpikeError.stepFailed("Analyze produced no summary bullets.")
        }
        guard extractCount > 0 else {
            throw SpikeError.stepFailed("Analyze produced no extracts.")
        }
        let analyzeWall = Date().timeIntervalSince(analyzeStart)
        SpikeReporter.logStep(
            2,
            "analyze_article",
            wallSeconds: analyzeWall,
            peakMB: SpikeMemory.peakMegabytes(),
            detail: "summary=\(summaryBullets) extracts=\(extractCount)"
        )

        await analyzer.unloadModel()
        SpikeMemory.recordSample()

        // Step 3 — vision describe
        let visionRuntime = LlamaCppRuntime()
        let visionAnalyzer = VisionContentAnalyzer(runtime: visionRuntime)
        let visionStart = Date()
        let visionResult = try await visionAnalyzer.describeImage(
            jpegData: jpegData,
            textModelPath: visionGGUF,
            mmprojPath: mmproj
        )
        SpikeMemory.recordSample()
        let visionWall = Date().timeIntervalSince(visionStart)
        let descriptionChars = visionResult.description.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard descriptionChars > 0 else {
            throw SpikeError.stepFailed("Vision describe returned empty text.")
        }
        SpikeReporter.logStep(
            3,
            "vision_describe",
            wallSeconds: visionWall,
            peakMB: SpikeMemory.peakMegabytes(),
            detail: "profile=\(visionResult.profile.rawValue) chars=\(descriptionChars)"
        )
    }
}
