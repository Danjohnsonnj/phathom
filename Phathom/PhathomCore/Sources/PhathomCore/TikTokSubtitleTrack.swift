import Foundation

public struct TikTokSubtitleTrack: Sendable, Equatable {
    public var url: String
    public var languageCode: String?

    public init(url: String, languageCode: String?) {
        self.url = url
        self.languageCode = languageCode
    }
}
