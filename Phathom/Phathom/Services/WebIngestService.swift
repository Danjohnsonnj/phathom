import PhathomCore
import Foundation

enum WebIngestError: Error, LocalizedError {
    case badResponse
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .badResponse: "The server returned an unexpected response."
        case .emptyContent: "No readable text could be extracted."
        }
    }
}

enum WebIngestService {
    static func scrape(url: URL) async throws -> WebScrapeResult {
        let displayHost = url.host ?? url.absoluteString
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WebIngestError.badResponse }
        guard (200 ... 399).contains(http.statusCode) else { throw WebIngestError.badResponse }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw WebIngestError.emptyContent
        }

        let loweredHost = url.host?.lowercased() ?? ""

        if loweredHost.contains("instagram") {
            return try await scrapeInstagram(html: html, pageURL: url, displayHost: displayHost)
        }
        if loweredHost.contains("tiktok") {
            return try await scrapeTikTok(html: html, pageURL: url, displayHost: displayHost)
        }
        return try await scrapeGeneric(html: html, pageURL: url, displayHost: displayHost)
    }

    private static func scrapeInstagram(
        html: String,
        pageURL: URL,
        displayHost: String
    ) async throws -> WebScrapeResult {
        let ogDesc = extractOgProperty(html, name: "og:description")
        let ogTitleMeta = extractOgProperty(html, name: "og:title")
        let caption = InstagramSocialCaption.normalizedCaption(ogDescription: ogDesc, ogTitle: ogTitleMeta)
        guard !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WebIngestError.emptyContent
        }

        let suggested = InstagramSocialCaption.suggestedListTitle(fromNormalizedCaption: caption)

        var thumb: Data?
        if let ogImageURL = extractOgImageURL(from: html, pageURL: pageURL) {
            thumb = try? await fetchImageData(from: ogImageURL)
        }

        let pageTitle = extractPageTitle(from: html)

        return WebScrapeResult(
            text: caption,
            thumbnailData: thumb,
            displayHost: displayHost,
            pageTitle: pageTitle,
            suggestedListTitle: suggested
        )
    }

    private static func scrapeTikTok(
        html: String,
        pageURL: URL,
        displayHost: String
    ) async throws -> WebScrapeResult {
        let payload = try TikTokItemStructResolver.payload(fromHTML: html)

        var thumb: Data?
        if let coverStr = payload.coverURL, let coverURL = URL(string: coverStr) {
            thumb = try? await fetchImageData(from: coverURL)
        }
        if thumb == nil, let preload = extractPreloadImageURL(from: html, pageURL: pageURL) {
            thumb = try? await fetchImageData(from: preload)
        }

        let pageTitle = extractPageTitle(from: html)
        let suggested = SocialListTitle.fromCaption(payload.description)

        var transcriptPlain: String?
        if let track = payload.subtitleTrack, let subURL = URL(string: track.url) {
            transcriptPlain = await fetchWebVTTPlainTranscript(from: subURL)
        }

        let text = TikTokAIArticleText.assemble(
            uniqueId: payload.uniqueId,
            description: payload.description,
            transcript: transcriptPlain
        )

        return WebScrapeResult(
            text: text,
            thumbnailData: thumb,
            displayHost: displayHost,
            pageTitle: pageTitle,
            suggestedListTitle: suggested
        )
    }

    private static func scrapeGeneric(
        html: String,
        pageURL: URL,
        displayHost: String
    ) async throws -> WebScrapeResult {
        let pageTitle = extractPageTitle(from: html)
        let ogImageURL = extractOgImageURL(from: html, pageURL: pageURL)
        var thumb: Data?
        if let ogImageURL {
            thumb = try? await fetchImageData(from: ogImageURL)
        }
        let text = extractReadableText(from: html)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WebIngestError.emptyContent
        }
        return WebScrapeResult(
            text: text,
            thumbnailData: thumb,
            displayHost: displayHost,
            pageTitle: pageTitle,
            suggestedListTitle: nil
        )
    }

    private static func extractOgProperty(_ html: String, name: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            "property=[\"']\(escaped)[\"'][^>]*content=[\"']([^\"']+)[\"']",
            "content=[\"']([^\"']+)[\"'][^>]*property=[\"']\(escaped)[\"']",
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(location: 0, length: (html as NSString).length)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let raw = String(html[r])
            if !raw.isEmpty { return decodeBasicHTMLEntitiesInMeta(raw) }
        }
        return nil
    }

    private static func decodeBasicHTMLEntitiesInMeta(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private static func extractPreloadImageURL(from html: String, pageURL: URL) -> URL? {
        let pattern =
            #"<link[^>]+rel=["']preload["'][^>]*href=["']([^"']+)["'][^>]*as=["']image["']"#
        let pattern2 =
            #"<link[^>]+rel=["']preload["'][^>]*as=["']image["'][^>]*href=["']([^"']+)["']"#
        for p in [pattern, pattern2] {
            guard let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) else { continue }
            let range = NSRange(location: 0, length: (html as NSString).length)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let raw = String(html[r])
            if let u = URL(string: raw, relativeTo: pageURL)?.absoluteURL { return u }
        }
        return nil
    }

    private static func extractPageTitle(from html: String) -> String? {
        let ogPatterns = [
            #"property=["']og:title["'][^>]*content=["']([^"']+)["']"#,
            #"content=["']([^"']+)["'][^>]*property=["']og:title["']"#,
        ]
        for pattern in ogPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(location: 0, length: (html as NSString).length)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let stripped = stripHTMLTagsFromTitle(String(html[r]))
            let raw = normalizeTitleFragment(stripped)
            if !raw.isEmpty { return raw }
        }

        if let regex = try? NSRegularExpression(pattern: #"(?is)<title[^>]*>(.*?)</title>"#, options: []),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
           match.numberOfRanges > 1,
           let r = Range(match.range(at: 1), in: html) {
            let stripped = stripHTMLTagsFromTitle(String(html[r]))
            let raw = normalizeTitleFragment(stripped)
            if !raw.isEmpty { return raw }
        }

        return nil
    }

    /// Removes nested markup (e.g. `<title>Foo <b>bar</b></title>`) so the title string is plain text.
    private static func stripHTMLTagsFromTitle(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<[^>]+>"#, options: []) else { return s }
        let nsLen = (s as NSString).length
        let spaced = regex.stringByReplacingMatches(in: s, options: [], range: NSRange(location: 0, length: nsLen), withTemplate: " ")
        guard let ws = try? NSRegularExpression(pattern: #"\s+"#, options: []) else { return spaced.trimmingCharacters(in: .whitespacesAndNewlines) }
        let collapsed = ws.stringByReplacingMatches(
            in: spaced,
            options: [],
            range: NSRange(location: 0, length: (spaced as NSString).length),
            withTemplate: " "
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeTitleFragment(_ s: String) -> String {
        var t = decodeNumericHTMLEntities(in: s)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > 200 {
            t = String(t.prefix(200))
        }
        return t
    }

    /// Decodes `&#123;` and `&#x1F600;` numeric character references (common in page titles).
    private static func decodeNumericHTMLEntities(in string: String) -> String {
        let mutable = NSMutableString(string: string)
        let hexPattern = #"&#x([0-9a-fA-F]{1,8});"#
        let decPattern = #"&#(\d{1,7});"#
        guard let hexRegex = try? NSRegularExpression(pattern: hexPattern, options: []),
              let decRegex = try? NSRegularExpression(pattern: decPattern, options: []) else {
            return string
        }
        func replaceMatches(_ regex: NSRegularExpression, radix: Int?) {
            while true {
                let range = NSRange(location: 0, length: mutable.length)
                guard let m = regex.firstMatch(in: mutable as String, options: [], range: range),
                      m.numberOfRanges > 1 else { break }
                let full = m.range(at: 0)
                let digitRange = m.range(at: 1)
                let digits = mutable.substring(with: digitRange)
                let codePoint: UInt32?
                if let radix {
                    codePoint = UInt32(digits, radix: radix)
                } else {
                    codePoint = UInt32(digits, radix: 10)
                }
                let replacement: String
                if let cp = codePoint,
                   cp <= 0x10FFFF,
                   !(0xD800 ... 0xDFFF).contains(cp),
                   let scalar = UnicodeScalar(cp) {
                    replacement = String(Character(scalar))
                } else {
                    replacement = ""
                }
                mutable.replaceCharacters(in: full, with: replacement)
            }
        }
        replaceMatches(hexRegex, radix: 16)
        replaceMatches(decRegex, radix: nil)
        return mutable as String
    }

    private static func extractOgImageURL(from html: String, pageURL: URL) -> URL? {
        let patterns = [
            #"property=["']og:image["'][^>]*content=["']([^"']+)["']"#,
            #"content=["']([^"']+)["'][^>]*property=["']og:image["']"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(location: 0, length: (html as NSString).length)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let raw = String(html[r])
            if let u = URL(string: raw, relativeTo: pageURL)?.absoluteURL { return u }
        }
        return nil
    }

    private static func fetchImageData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw WebIngestError.badResponse
        }
        return data
    }

    /// Fetches TikTok WEBVTT and returns plain speech text for inclusion in `rawText`. Soft-fails to nil.
    private static func fetchWebVTTPlainTranscript(from url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200 ... 299).contains(http.statusCode) else { return nil }
        guard let vtt = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }
        let plain = WebVTTTranscriptParser.plainText(from: vtt, maxCharacters: 8_000)
        return plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : plain
    }

    private static func extractReadableText(from html: String) -> String {
        var s = html
        let stripPatterns = [
            #"(?is)<script.*?>.*?</script>"#,
            #"(?is)<style.*?>.*?</style>"#,
            #"(?is)<!--.*?-->"#,
        ]
        for p in stripPatterns {
            if let regex = try? NSRegularExpression(pattern: p, options: []) {
                let nsLen = (s as NSString).length
                s = regex.stringByReplacingMatches(in: s, options: [], range: NSRange(location: 0, length: nsLen), withTemplate: " ")
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"(?is)<[^>]+>"#, options: []) {
            let nsLen = (s as NSString).length
            s = regex.stringByReplacingMatches(in: s, options: [], range: NSRange(location: 0, length: nsLen), withTemplate: " ")
        }
        let decoded = s.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
        let parts = decoded.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }
}
