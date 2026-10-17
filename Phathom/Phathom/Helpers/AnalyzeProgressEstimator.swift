import Foundation
import PhathomCore

/// Pure logic for summary-progress rate, visibility, and bar presentation (slice 1).
enum AnalyzeProgressPresentation: Equatable, Sendable {
    case hidden
    case determinate(fraction: Double)
    case indeterminate
}

enum AnalyzeProgressEstimator {
    nonisolated static let characterCap = 12_000

    /// Source length after the same cap applied before analyze (`String(raw.prefix(12_000))`).
    nonisolated static func cappedCharacterCount(for sourceCharacterCount: Int) -> Int {
        min(max(sourceCharacterCount, 0), characterCap)
    }

    nonisolated static func rateMillisecondsPerCharacter(
        totalAnalyzeMilliseconds: Int,
        totalCappedCharacters: Int
    ) -> Double? {
        guard totalCappedCharacters > 0 else { return nil }
        return Double(totalAnalyzeMilliseconds) / Double(totalCappedCharacters)
    }

    nonisolated static func estimatedMilliseconds(
        totalAnalyzeMilliseconds: Int,
        totalCappedCharacters: Int,
        cappedLength: Int
    ) -> Int? {
        guard let rate = rateMillisecondsPerCharacter(
            totalAnalyzeMilliseconds: totalAnalyzeMilliseconds,
            totalCappedCharacters: totalCappedCharacters
        ) else { return nil }
        let length = max(cappedLength, 0)
        return Int((rate * Double(length)).rounded())
    }

    /// Records only a finished web or note analyze pass (`reachedCompleted` is pipeline completion, not status enum).
    nonisolated static func shouldRecord(kind: ContentKind, reachedCompleted: Bool) -> Bool {
        guard reachedCompleted else { return false }
        return kind == .web || kind == .note
    }

    nonisolated static func presentation(
        sampleCount: Int,
        totalAnalyzeMilliseconds: Int,
        totalCappedCharacters: Int,
        cappedLength: Int,
        elapsedMilliseconds: Int,
        estimatedMilliseconds explicitEstimate: Int? = nil,
        toggleEnabled: Bool,
        kind: ContentKind,
        status: ProcessingStatus,
        hasStartTime: Bool
    ) -> AnalyzeProgressPresentation {
        guard toggleEnabled else { return .hidden }
        guard sampleCount >= 3 else { return .hidden }
        guard kind == .web || kind == .note else { return .hidden }
        switch status {
        case .summarizing, .extracting, .tagging:
            break
        default:
            return .hidden
        }

        guard totalCappedCharacters > 0 else { return .hidden }

        let estimate: Int
        if let explicitEstimate {
            estimate = explicitEstimate
        } else if let derived = estimatedMilliseconds(
            totalAnalyzeMilliseconds: totalAnalyzeMilliseconds,
            totalCappedCharacters: totalCappedCharacters,
            cappedLength: cappedLength
        ) {
            estimate = derived
        } else {
            return .hidden
        }

        guard hasStartTime else { return .indeterminate }

        if estimate > 0, elapsedMilliseconds >= estimate {
            return .indeterminate
        }

        guard estimate > 0 else { return .indeterminate }

        let fraction = min(1.0, max(0.0, Double(elapsedMilliseconds) / Double(estimate)))
        return .determinate(fraction: fraction)
    }
}
