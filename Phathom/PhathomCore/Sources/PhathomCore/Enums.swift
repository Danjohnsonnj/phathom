import Foundation

public enum ContentKind: String, Codable, CaseIterable, Sendable {
    case web
    case media
    case note
}

public enum ProcessingStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case scraping
    case embedding
    case summarizing
    case extracting
    case tagging
    case completed
    case failed
}

/// User-controlled triage status for a library item, distinct from `ProcessingStatus`.
/// Defaults to `.new` for fresh captures and is changed via Library row swipe.
public enum ReadStatus: String, Codable, CaseIterable, Sendable {
    case new
    case read
    case filed
}
