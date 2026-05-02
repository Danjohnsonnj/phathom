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
    case tagging
    case completed
    case failed
}
