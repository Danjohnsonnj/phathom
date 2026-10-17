import PhathomCore
import SwiftUI

struct AnalyzeProgressTrack: View {
    let presentation: AnalyzeProgressPresentation
    var timelineDate: Date = .init()

    private static let trackHeight: CGFloat = 4
    private static let indeterminateSegmentFraction: CGFloat = 0.35
    private static let indeterminateCycleSeconds: Double = 1.2

    var body: some View {
        switch presentation {
        case .hidden:
            EmptyView()
        case .determinate(let fraction):
            trackCapsule(accentWidthRatio: min(1, max(0, fraction)), indeterminatePhase: nil)
        case .indeterminate:
            trackCapsule(accentWidthRatio: Self.indeterminateSegmentFraction, indeterminatePhase: indeterminatePhase)
        }
    }

    private var indeterminatePhase: CGFloat {
        let t = timelineDate.timeIntervalSinceReferenceDate
        let cycle = Self.indeterminateCycleSeconds
        return CGFloat((t.truncatingRemainder(dividingBy: cycle)) / cycle)
    }

    @ViewBuilder
    private func trackCapsule(accentWidthRatio: CGFloat, indeterminatePhase: CGFloat?) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let accentWidth = max(0, width * accentWidthRatio)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppPalette.surfaceNested)
                Capsule()
                    .fill(AppPalette.accent)
                    .frame(width: accentWidth)
                    .offset(x: indeterminateOffset(totalWidth: width, accentWidth: accentWidth, phase: indeterminatePhase))
            }
            .clipShape(Capsule())
        }
        .frame(height: Self.trackHeight)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func indeterminateOffset(totalWidth: CGFloat, accentWidth: CGFloat, phase: CGFloat?) -> CGFloat {
        guard let phase else { return 0 }
        return (totalWidth + accentWidth) * phase - accentWidth
    }
}

/// Progress track driven by estimator + clock + store (library row and Detail).
struct AnalyzeProgressItemTrack: View {
    let item: ContentItem

    @AppStorage(AnalyzeProgressSettingsStorage.enabledKey) private var analyzeProgressEnabled = false
    @State private var fallbackEstimateKey: ModelPairKey?
    @State private var fallbackEstimateKeyItemID: UUID?

    var body: some View {
        if shouldEvaluateBar, barIsEligibleForDisplay {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let presentation = presentation(at: context.date)
                AnalyzeProgressTrack(presentation: presentation, timelineDate: context.date)
            }
            .onAppear { refreshFallbackEstimateKeyIfNeeded() }
            .onChange(of: item.id) { _, _ in
                fallbackEstimateKey = nil
                fallbackEstimateKeyItemID = nil
                refreshFallbackEstimateKeyIfNeeded()
            }
            .onChange(of: item.processingStatus) { _, _ in
                refreshFallbackEstimateKeyIfNeeded()
            }
        }
    }

    private var barIsEligibleForDisplay: Bool {
        guard let estimateKey = activeEstimateKey else { return false }
        return AnalyzeProgressStore.makeStandard().lookup(key: estimateKey).sampleCount >= 3
    }

    private var activeEstimateKey: ModelPairKey? {
        AnalyzeProgressClock.entry(for: item.id)?.estimateKey ?? fallbackEstimateKey
    }

    private var shouldEvaluateBar: Bool {
        guard analyzeProgressEnabled else { return false }
        guard item.kind == .web || item.kind == .note else { return false }
        switch item.status {
        case .summarizing, .extracting, .tagging:
            return true
        default:
            return false
        }
    }

    private func refreshFallbackEstimateKeyIfNeeded() {
        guard shouldEvaluateBar else { return }
        guard AnalyzeProgressClock.entry(for: item.id) == nil else { return }
        guard fallbackEstimateKeyItemID != item.id else { return }
        fallbackEstimateKey = AnalyzeProgressModelIdentity.estimateKeyForConfiguredModels()
        fallbackEstimateKeyItemID = item.id
    }

    private func presentation(at date: Date) -> AnalyzeProgressPresentation {
        let clockEntry = AnalyzeProgressClock.entry(for: item.id)
        guard let estimateKey = clockEntry?.estimateKey ?? fallbackEstimateKey else {
            return .hidden
        }

        let totals = AnalyzeProgressStore.makeStandard().lookup(key: estimateKey)
        let cappedLength = AnalyzeProgressEstimator.cappedCharacterCount(for: item.rawText?.count ?? 0)
        let elapsedMs: Int
        let hasStartTime: Bool
        if let start = clockEntry?.startDate {
            elapsedMs = Int(date.timeIntervalSince(start) * 1000)
            hasStartTime = true
        } else {
            elapsedMs = 0
            hasStartTime = false
        }

        return AnalyzeProgressEstimator.presentation(
            sampleCount: totals.sampleCount,
            totalAnalyzeMilliseconds: totals.totalAnalyzeMilliseconds,
            totalCappedCharacters: totals.totalCappedCharacters,
            cappedLength: cappedLength,
            elapsedMilliseconds: elapsedMs,
            toggleEnabled: analyzeProgressEnabled,
            kind: item.kind,
            status: item.status,
            hasStartTime: hasStartTime
        )
    }
}

#Preview("Analyze progress track") {
    AnalyzeProgressTrackPreviewBoard()
        .padding(24)
        .frame(maxWidth: 360)
        .background(AppPalette.background)
}

private struct AnalyzeProgressTrackPreviewBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            AnalyzeProgressTrackPreviewCluster(title: "~35%", presentation: .determinate(fraction: 0.35))
            AnalyzeProgressTrackPreviewCluster(title: "~70%", presentation: .determinate(fraction: 0.70))
            AnalyzeProgressTrackPreviewCluster(title: "Indeterminate", presentation: .indeterminate, animate: true)
        }
    }
}

private struct AnalyzeProgressTrackPreviewCluster: View {
    let title: String
    let presentation: AnalyzeProgressPresentation
    var animate: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .appTypography(.captionSemibold)
                .foregroundStyle(AppPalette.textSecondary)
            ProcessingStatusBadge(
                status: .summarizing,
                contentKind: .web,
                processingDetail: "Generating summary…"
            )
            if animate {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    AnalyzeProgressTrack(presentation: presentation, timelineDate: context.date)
                }
            } else {
                AnalyzeProgressTrack(presentation: presentation)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
