import Foundation

public enum TikTokItemStructResolver {
    public struct Payload: Sendable {
        public var description: String
        public var uniqueId: String?
        public var coverURL: String?
        /// Spoken-audio captions when TikTok exposes a subtitle URL (usually WEBVTT).
        public var subtitleTrack: TikTokSubtitleTrack?

        public init(
            description: String,
            uniqueId: String?,
            coverURL: String?,
            subtitleTrack: TikTokSubtitleTrack? = nil
        ) {
            self.description = description
            self.uniqueId = uniqueId
            self.coverURL = coverURL
            self.subtitleTrack = subtitleTrack
        }
    }

    /// Decodes `__UNIVERSAL_DATA_FOR_REHYDRATION__` JSON from TikTok HTML.
    public static func rehydrationJSONObject(fromHTML html: String) throws -> Any {
        let pattern =
            #"<script\s+id="__UNIVERSAL_DATA_FOR_REHYDRATION__"\s+type="application/json"\s*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            throw TikTokIngestError.missingRehydrationData
        }
        let range = NSRange(location: 0, length: (html as NSString).length)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: html) else {
            throw TikTokIngestError.missingRehydrationData
        }
        let jsonText = String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonText.data(using: .utf8) else {
            throw TikTokIngestError.invalidJSON
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw TikTokIngestError.invalidJSON
        }
    }

    public static func payload(fromHTML html: String) throws -> Payload {
        let obj = try rehydrationJSONObject(fromHTML: html)
        guard let item = resolveItemStruct(from: obj) else {
            throw TikTokIngestError.missingItemStruct
        }
        let desc = (item["desc"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !desc.isEmpty else {
            throw TikTokIngestError.emptyDescription
        }
        let author = item["author"] as? [String: Any]
        let uniqueId = author?["uniqueId"] as? String
        let video = item["video"] as? [String: Any]
        let cover = firstVideoCoverURL(from: video)
        let track = bestSubtitleTrack(from: video)
        return Payload(description: desc, uniqueId: uniqueId, coverURL: cover, subtitleTrack: track)
    }

    private static func resolveItemStruct(from root: Any) -> [String: Any]? {
        let paths: [[String]] = [
            ["__DEFAULT_SCOPE__", "webapp.reflow.video.detail", "itemInfo", "itemStruct"],
            ["__DEFAULT_SCOPE__", "webapp.video-detail", "itemInfo", "itemStruct"],
        ]
        for path in paths {
            if let d = dig(root, path: path), let item = d as? [String: Any], item["desc"] != nil {
                return item
            }
        }
        return bestMatchingItemStruct(in: root)
    }

    private static func dig(_ any: Any, path: [String]) -> Any? {
        var cur: Any? = any
        for key in path {
            guard let dict = cur as? [String: Any], let next = dict[key] else { return nil }
            cur = next
        }
        return cur
    }

    private static func bestMatchingItemStruct(in root: Any) -> [String: Any]? {
        var candidates: [[String: Any]] = []
        collectItemStructCandidates(in: root, depth: 0, into: &candidates)
        return candidates.max(by: { score(itemStruct: $0) < score(itemStruct: $1) })
    }

    private static func collectItemStructCandidates(in any: Any, depth: Int, into out: inout [[String: Any]]) {
        guard depth < 22 else { return }
        if let dict = any as? [String: Any] {
            if let desc = dict["desc"] as? String, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               dict["author"] is [String: Any],
               dict["video"] is [String: Any] {
                out.append(dict)
            }
            for v in dict.values {
                collectItemStructCandidates(in: v, depth: depth + 1, into: &out)
            }
        } else if let arr = any as? [Any] {
            for v in arr {
                collectItemStructCandidates(in: v, depth: depth + 1, into: &out)
            }
        }
    }

    private static func score(itemStruct: [String: Any]) -> Int {
        let descLen = (itemStruct["desc"] as? String)?.count ?? 0
        let author = itemStruct["author"] as? [String: Any]
        let uniqueId = (author?["uniqueId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let video = itemStruct["video"] as? [String: Any]
        let hasCover = firstVideoCoverURL(from: video) != nil
        var score = min(descLen, 3_000)
        if let uniqueId, !uniqueId.isEmpty { score += 250 }
        if hasCover { score += 100 }
        return score
    }

    private static func firstVideoCoverURL(from video: [String: Any]?) -> String? {
        guard let video else { return nil }
        for key in ["cover", "shareCover", "dynamicCover", "originCover"] {
            if let s = video[key] as? String,
               s.hasPrefix("http://") || s.hasPrefix("https://") {
                return s
            }
        }
        return nil
    }

    private static func bestSubtitleTrack(from video: [String: Any]?) -> TikTokSubtitleTrack? {
        guard let video,
              let infos = video["subtitleInfos"] as? [Any],
              !infos.isEmpty else { return nil }

        var rows: [(url: String, lang: String?)] = []
        for case let row as [String: Any] in infos {
            guard let url = row["Url"] as? String,
                  url.hasPrefix("http://") || url.hasPrefix("https://") else { continue }
            let lang = (row["LanguageCodeName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            rows.append((url, lang?.isEmpty == false ? lang : nil))
        }
        guard !rows.isEmpty else { return nil }

        func isEnglish(_ lang: String?) -> Bool {
            guard let lang else { return false }
            let l = lang.lowercased()
            return l.hasPrefix("eng") || l.hasPrefix("en-") || l == "en"
        }

        if let pick = rows.first(where: { isEnglish($0.lang) }) {
            return TikTokSubtitleTrack(url: pick.url, languageCode: pick.lang)
        }
        let first = rows[0]
        return TikTokSubtitleTrack(url: first.url, languageCode: first.lang)
    }
}

public enum TikTokIngestError: Error, LocalizedError {
    case missingRehydrationData
    case invalidJSON
    case missingItemStruct
    case emptyDescription

    public var errorDescription: String? {
        switch self {
        case .missingRehydrationData:
            "TikTok page did not include expected metadata."
        case .invalidJSON:
            "Could not read TikTok page metadata."
        case .missingItemStruct:
            "Could not find video details on this TikTok page."
        case .emptyDescription:
            "This TikTok post has no caption text to capture."
        }
    }
}
