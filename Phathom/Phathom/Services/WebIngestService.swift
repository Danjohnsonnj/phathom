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
    static func scrape(url: URL) async throws -> (text: String, thumbnailData: Data?, displayHost: String) {
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

        let host = url.host ?? url.absoluteString
        let ogImageURL = extractOgImageURL(from: html, pageURL: url)
        var thumb: Data?
        if let ogImageURL {
            thumb = try? await fetchImageData(from: ogImageURL)
        }

        let text = extractReadableText(from: html)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WebIngestError.emptyContent
        }

        return (text, thumb, host)
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
