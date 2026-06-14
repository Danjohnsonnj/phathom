import Foundation

/// Settings smoke path for production vision bookmarks (Phase 1+). Runs via `SharedLlamaInference` + `VisionContentAnalyzer`.
public enum VisionModelSmokeTest {
    /// ~10-minute wall-clock guard for Settings vision test.
    private static let timeoutNanoseconds: UInt64 = 600 * 1_000_000_000

    public nonisolated static func describe(jpegData: Data) async throws -> String {
        guard !jpegData.isEmpty else {
            throw VisionModelSmokeTestError.emptyImage
        }

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await SharedLlamaInference.shared.withSession(role: .vision) { session in
                    try await session.runVisionSmokeTest(jpegData: jpegData)
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                SharedLlamaInference.signalCancelInFlight()
                throw VisionModelSmokeTestError.timeout
            }
            guard let first = try await group.next() else {
                SharedLlamaInference.signalCancelInFlight()
                throw VisionModelSmokeTestError.timeout
            }
            group.cancelAll()
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw VisionModelSmokeTestError.emptyDescription
            }
            return trimmed
        }
    }
}

public enum VisionModelSmokeTestError: LocalizedError, Sendable {
    case emptyImage
    case emptyDescription
    case timeout

    public var errorDescription: String? {
        switch self {
        case .emptyImage:
            "Choose a test photo before running the vision test."
        case .emptyDescription:
            "Vision model returned an empty description."
        case .timeout:
            "Vision test timed out. Try a smaller photo or relaunch fresh."
        }
    }
}
