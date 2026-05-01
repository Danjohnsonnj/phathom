import Foundation

enum ContentKind: String, Codable, CaseIterable {
    case web
    case media
    case note
}

enum ProcessingStatus: String, Codable, CaseIterable {
    case pending
    case scraping
    case embedding
    case summarizing
    case tagging
    case completed
    case failed
}
