import Foundation

/// Unified output from web ingest after fetching a URL.
public struct WebScrapeResult: Sendable {
    public var text: String
    public var thumbnailData: Data?
    public var displayHost: String
    public var pageTitle: String?
    /// Caption-derived title when the user did not supply a title (Instagram / TikTok).
    public var suggestedListTitle: String?

    public init(
        text: String,
        thumbnailData: Data?,
        displayHost: String,
        pageTitle: String?,
        suggestedListTitle: String? = nil
    ) {
        self.text = text
        self.thumbnailData = thumbnailData
        self.displayHost = displayHost
        self.pageTitle = pageTitle
        self.suggestedListTitle = suggestedListTitle
    }
}
