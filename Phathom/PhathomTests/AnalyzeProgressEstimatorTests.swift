//
//  AnalyzeProgressEstimatorTests.swift
//  PhathomTests
//

import PhathomCore
import Testing
@testable import Phathom

struct AnalyzeProgressEstimatorTests {

    private static let totalsMs = 30_000
    private static let totalsChars = 3_000

    private func visibleBase(
        sampleCount: Int = 3,
        toggleEnabled: Bool = true,
        kind: ContentKind = .web,
        status: ProcessingStatus = .summarizing
    ) -> (
        sampleCount: Int,
        totalAnalyzeMilliseconds: Int,
        totalCappedCharacters: Int,
        cappedLength: Int,
        elapsedMilliseconds: Int,
        toggleEnabled: Bool,
        kind: ContentKind,
        status: ProcessingStatus,
        hasStartTime: Bool
    ) {
        (
            sampleCount: sampleCount,
            totalAnalyzeMilliseconds: Self.totalsMs,
            totalCappedCharacters: Self.totalsChars,
            cappedLength: 1_000,
            elapsedMilliseconds: 500,
            toggleEnabled: toggleEnabled,
            kind: kind,
            status: status,
            hasStartTime: true
        )
    }

    @Test func longerCappedLengthYieldsLongerEstimate() {
        let short = AnalyzeProgressEstimator.estimatedMilliseconds(
            totalAnalyzeMilliseconds: 60_000,
            totalCappedCharacters: 6_000,
            cappedLength: 3_000
        )
        let long = AnalyzeProgressEstimator.estimatedMilliseconds(
            totalAnalyzeMilliseconds: 60_000,
            totalCappedCharacters: 6_000,
            cappedLength: 6_000
        )
        #expect(short == 30_000)
        #expect(long == 60_000)
        #expect(long! > short!)
    }

    @Test func sourceLengthAboveCapIsCapped() {
        #expect(AnalyzeProgressEstimator.cappedCharacterCount(for: 12_000) == 12_000)
        #expect(AnalyzeProgressEstimator.cappedCharacterCount(for: 20_000) == 12_000)
        let estimate = AnalyzeProgressEstimator.estimatedMilliseconds(
            totalAnalyzeMilliseconds: 12_000,
            totalCappedCharacters: 12_000,
            cappedLength: AnalyzeProgressEstimator.cappedCharacterCount(for: 20_000)
        )
        #expect(estimate == 12_000)
    }

    @Test func sampleCountThreeIsFirstVisibleBar() {
        var base = visibleBase(sampleCount: 3)
        let visible = AnalyzeProgressEstimator.presentation(
            sampleCount: base.sampleCount,
            totalAnalyzeMilliseconds: base.totalAnalyzeMilliseconds,
            totalCappedCharacters: base.totalCappedCharacters,
            cappedLength: base.cappedLength,
            elapsedMilliseconds: base.elapsedMilliseconds,
            toggleEnabled: base.toggleEnabled,
            kind: base.kind,
            status: base.status,
            hasStartTime: base.hasStartTime
        )
        if case .determinate = visible {
            // expected
        } else {
            Issue.record("Expected determinate bar at sample count 3, got \(visible)")
        }

        base = visibleBase(sampleCount: 2)
        #expect(
            AnalyzeProgressEstimator.presentation(
                sampleCount: base.sampleCount,
                totalAnalyzeMilliseconds: base.totalAnalyzeMilliseconds,
                totalCappedCharacters: base.totalCappedCharacters,
                cappedLength: base.cappedLength,
                elapsedMilliseconds: base.elapsedMilliseconds,
                toggleEnabled: base.toggleEnabled,
                kind: base.kind,
                status: base.status,
                hasStartTime: base.hasStartTime
            ) == .hidden
        )
    }

    @Test func mediaStaysHidden() {
        let base = visibleBase(kind: .media, status: .summarizing)
        #expect(
            AnalyzeProgressEstimator.presentation(
                sampleCount: base.sampleCount,
                totalAnalyzeMilliseconds: base.totalAnalyzeMilliseconds,
                totalCappedCharacters: base.totalCappedCharacters,
                cappedLength: base.cappedLength,
                elapsedMilliseconds: base.elapsedMilliseconds,
                toggleEnabled: base.toggleEnabled,
                kind: base.kind,
                status: base.status,
                hasStartTime: base.hasStartTime
            ) == .hidden
        )
    }

    @Test func nonAnalyzeStatusesStayHidden() {
        for status in [ProcessingStatus.pending, .embedding, .completed, .failed] {
            let base = visibleBase(status: status)
            #expect(
                AnalyzeProgressEstimator.presentation(
                    sampleCount: base.sampleCount,
                    totalAnalyzeMilliseconds: base.totalAnalyzeMilliseconds,
                    totalCappedCharacters: base.totalCappedCharacters,
                    cappedLength: base.cappedLength,
                    elapsedMilliseconds: base.elapsedMilliseconds,
                    toggleEnabled: base.toggleEnabled,
                    kind: base.kind,
                    status: base.status,
                    hasStartTime: base.hasStartTime
                ) == .hidden
            )
        }
    }

    @Test func toggleOffStaysHidden() {
        let base = visibleBase(toggleEnabled: false)
        #expect(
            AnalyzeProgressEstimator.presentation(
                sampleCount: base.sampleCount,
                totalAnalyzeMilliseconds: base.totalAnalyzeMilliseconds,
                totalCappedCharacters: base.totalCappedCharacters,
                cappedLength: base.cappedLength,
                elapsedMilliseconds: base.elapsedMilliseconds,
                toggleEnabled: base.toggleEnabled,
                kind: base.kind,
                status: base.status,
                hasStartTime: base.hasStartTime
            ) == .hidden
        )
    }

    @Test func overrunIsIndeterminate() {
        let base = visibleBase()
        #expect(
            AnalyzeProgressEstimator.presentation(
                sampleCount: base.sampleCount,
                totalAnalyzeMilliseconds: base.totalAnalyzeMilliseconds,
                totalCappedCharacters: base.totalCappedCharacters,
                cappedLength: base.cappedLength,
                elapsedMilliseconds: 15_000,
                estimatedMilliseconds: 10_000,
                toggleEnabled: base.toggleEnabled,
                kind: base.kind,
                status: base.status,
                hasStartTime: base.hasStartTime
            ) == .indeterminate
        )
    }

    @Test func missingStartTimeIsIndeterminateWhenBarWouldShow() {
        let base = visibleBase()
        #expect(
            AnalyzeProgressEstimator.presentation(
                sampleCount: base.sampleCount,
                totalAnalyzeMilliseconds: base.totalAnalyzeMilliseconds,
                totalCappedCharacters: base.totalCappedCharacters,
                cappedLength: base.cappedLength,
                elapsedMilliseconds: base.elapsedMilliseconds,
                toggleEnabled: base.toggleEnabled,
                kind: base.kind,
                status: base.status,
                hasStartTime: false
            ) == .indeterminate
        )
    }

    @Test func shouldRecordOnlyCompletedWebOrNote() {
        #expect(AnalyzeProgressEstimator.shouldRecord(kind: .web, reachedCompleted: true))
        #expect(AnalyzeProgressEstimator.shouldRecord(kind: .note, reachedCompleted: true))
        #expect(!AnalyzeProgressEstimator.shouldRecord(kind: .web, reachedCompleted: false))
        #expect(!AnalyzeProgressEstimator.shouldRecord(kind: .note, reachedCompleted: false))
        #expect(!AnalyzeProgressEstimator.shouldRecord(kind: .media, reachedCompleted: true))
        #expect(!AnalyzeProgressEstimator.shouldRecord(kind: .media, reachedCompleted: false))
    }

    @Test func zeroTotalCharactersDoNotDivideOrShowBar() {
        #expect(
            AnalyzeProgressEstimator.rateMillisecondsPerCharacter(
                totalAnalyzeMilliseconds: 5_000,
                totalCappedCharacters: 0
            ) == nil
        )
        let base = visibleBase()
        #expect(
            AnalyzeProgressEstimator.presentation(
                sampleCount: base.sampleCount,
                totalAnalyzeMilliseconds: 5_000,
                totalCappedCharacters: 0,
                cappedLength: base.cappedLength,
                elapsedMilliseconds: base.elapsedMilliseconds,
                toggleEnabled: base.toggleEnabled,
                kind: base.kind,
                status: base.status,
                hasStartTime: base.hasStartTime
            ) == .hidden
        )
        #expect(
            AnalyzeProgressEstimator.estimatedMilliseconds(
                totalAnalyzeMilliseconds: 5_000,
                totalCappedCharacters: 0,
                cappedLength: 1_000
            ) == nil
        )
    }

    @Test func noteKindCanShowDeterminateBar() {
        let base = visibleBase(kind: .note, status: .tagging)
        let result = AnalyzeProgressEstimator.presentation(
            sampleCount: base.sampleCount,
            totalAnalyzeMilliseconds: base.totalAnalyzeMilliseconds,
            totalCappedCharacters: base.totalCappedCharacters,
            cappedLength: base.cappedLength,
            elapsedMilliseconds: 1_000,
            toggleEnabled: base.toggleEnabled,
            kind: base.kind,
            status: base.status,
            hasStartTime: base.hasStartTime
        )
        if case let .determinate(fraction) = result {
            #expect(fraction > 0)
            #expect(fraction < 1)
        } else {
            Issue.record("Expected determinate fraction for note, got \(result)")
        }
    }
}
