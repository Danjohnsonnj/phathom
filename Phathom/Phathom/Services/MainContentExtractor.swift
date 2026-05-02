import Foundation
import SwiftSoup

/// Picks the most "article-like" subtree of a parsed HTML document using a Mozilla Readability-style
/// score: text length, comma count, link density, and class/id token cues.
/// Returns the chosen `Element` plus paragraph-preserving plain text for `rawText` / LLM / Spotlight.
/// Generic web only; Instagram/TikTok have their own structured payloads.
enum MainContentExtractor {

    struct Result {
        let root: Element
        let plainText: String
    }

    /// Hard cap on `plainText` length to match the historical 12_000 char prompt budget.
    private static let plainTextCharCap = 12_000
    /// Minimum cleaned text length on the winning candidate before we trust the heuristic; otherwise nil and the caller falls back.
    private static let minTextLength = 250
    /// Sibling threshold multiplier (Readability uses ~0.2 of winner score, with a floor of 10).
    private static let siblingThresholdFloor = 10.0
    private static let siblingThresholdRatio = 0.2

    private static let positiveTokens: [String] = [
        "article", "body", "content", "entry", "hentry", "main", "page", "post",
        "text", "blog", "story",
    ]
    private static let negativeTokens: [String] = [
        "combx", "comment", "community", "disqus", "extra", "foot", "header", "legends",
        "menu", "related", "remark", "rss", "shoutbox", "sidebar", "sponsor", "ad-",
        "agegate", "pagination", "pager", "popup", "tweet", "twitter", "share", "social",
        "subscribe", "outbrain", "taboola", "promo", "nav", "breadcrumbs",
    ]
    private static let relatedLikeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"related|share|subscribe|comments?|reply|trending|recommend|read[-_]?more|outbrain|taboola|tags?|categories?"#,
        options: .caseInsensitive
    )

    static func extract(html: String) -> Result? {
        guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return (try? SwiftSoup.parse(html)).flatMap { extract(document: $0) }
    }

    static func extract(document doc: Document) -> Result? {
        do {
            try stripGlobalNoise(in: doc)
            guard let body = doc.body() else { return nil }

            let candidates = try score(body: body)
            guard let winner = candidates.max(by: { $0.score < $1.score }) else {
                return fallbackRoot(body: body)
            }
            try cleanWithinSubtree(winner.element)

            let winnerScore = winner.score
            let threshold = max(siblingThresholdFloor, winnerScore * siblingThresholdRatio)
            let scoreByID = Dictionary(uniqueKeysWithValues: candidates.map { (ObjectIdentifier($0.element), $0.score) })

            let included = try assembleSiblings(winner: winner.element, scores: scoreByID, threshold: threshold)
            let cleanedText = paragraphPlainText(from: included)
            let textLen = cleanedText.unicodeScalars.count
            if textLen < minTextLength {
                return fallbackRoot(body: body)
            }

            let capped = clipToCharacterCount(cleanedText, max: plainTextCharCap)
            return Result(root: winner.element, plainText: capped)
        } catch {
            return nil
        }
    }

    // MARK: - Strip + clean

    private static func stripGlobalNoise(in doc: Document) throws {
        try doc.select(
            "script, style, noscript, nav, footer, aside, iframe, template, form, button, input, svg"
        ).remove()
        try doc.select(
            "[aria-hidden=true], [hidden], [role=navigation], [role=complementary], [role=banner], [role=contentinfo]"
        ).remove()
    }

    /// Within the winning subtree: remove descendants that look like related/share/comments AND are link-dense.
    private static func cleanWithinSubtree(_ root: Element) throws {
        let descendants = try root.getAllElements().array()
        for el in descendants where el !== root {
            let tokens = "\(try el.attr("class")) \(try el.attr("id"))"
            guard !tokens.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            guard matchesRelatedRegex(tokens) else { continue }
            if try linkDensity(of: el) > 0.5 {
                try el.remove()
            }
        }
    }

    private static func matchesRelatedRegex(_ s: String) -> Bool {
        guard let regex = relatedLikeRegex else { return false }
        let nsLen = (s as NSString).length
        return regex.firstMatch(in: s, options: [], range: NSRange(location: 0, length: nsLen)) != nil
    }

    // MARK: - Scoring

    private struct Candidate {
        let element: Element
        var score: Double
    }

    /// Readability heuristic: bias to ancestors of `<p>` etc., then add length/comma/class signals and penalize link density.
    private static func score(body: Element) throws -> [Candidate] {
        var byID: [ObjectIdentifier: Candidate] = [:]

        let paragraphSelectors = "p, li, pre, blockquote, h1, h2, h3, h4, h5, h6, td"
        let blocks = try body.select(paragraphSelectors).array()
        for block in blocks {
            let text = try block.text()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 25 else { continue }

            let parent = block.parent()
            if let parent {
                ensureCandidate(parent, in: &byID)
                let added = baseContribution(text: trimmed)
                byID[ObjectIdentifier(parent)]?.score += added
                if let grand = parent.parent() {
                    ensureCandidate(grand, in: &byID)
                    byID[ObjectIdentifier(grand)]?.score += added / 2.0
                }
            }
        }

        for key in byID.keys {
            guard var cand = byID[key] else { continue }
            let el = cand.element
            cand.score += try classIdAdjust(el)
            cand.score += tagBias(el.tagName().lowercased())
            let density = try linkDensity(of: el)
            cand.score *= (1.0 - density)
            byID[key] = cand
        }

        return Array(byID.values)
    }

    private static func ensureCandidate(_ el: Element, in dict: inout [ObjectIdentifier: Candidate]) {
        let key = ObjectIdentifier(el)
        if dict[key] == nil {
            dict[key] = Candidate(element: el, score: 0)
        }
    }

    private static func baseContribution(text: String) -> Double {
        let length = Double(text.unicodeScalars.count)
        let commas = Double(text.filter { $0 == "," || $0 == "\u{3001}" || $0 == "\u{FF0C}" }.count)
        let lengthScore = min(length / 100.0, 3.0)
        return 1.0 + commas + lengthScore
    }

    private static func tagBias(_ tag: String) -> Double {
        switch tag {
        case "article", "main": return 15
        case "section": return 5
        case "header", "footer", "aside", "nav": return -15
        default: return 0
        }
    }

    private static func classIdAdjust(_ el: Element) throws -> Double {
        let tokens = "\(try el.attr("class")) \(try el.attr("id"))".lowercased()
        guard !tokens.trimmingCharacters(in: .whitespaces).isEmpty else { return 0 }
        var delta: Double = 0
        for pos in positiveTokens where tokens.contains(pos) { delta += 25; break }
        for neg in negativeTokens where tokens.contains(neg) { delta -= 25; break }
        return delta
    }

    private static func linkDensity(of el: Element) throws -> Double {
        let total = try el.text().unicodeScalars.count
        guard total > 0 else { return 0 }
        var inLinks = 0
        for a in try el.select("a").array() {
            inLinks += try a.text().unicodeScalars.count
        }
        return min(1.0, Double(inLinks) / Double(total))
    }

    // MARK: - Sibling sweep + plain text

    private static func assembleSiblings(
        winner: Element,
        scores: [ObjectIdentifier: Double],
        threshold: Double
    ) throws -> [Element] {
        guard let parent = winner.parent() else { return [winner] }
        var included: [Element] = []
        for sibling in parent.children().array() {
            if sibling === winner {
                included.append(sibling)
                continue
            }
            let siblingScore = scores[ObjectIdentifier(sibling)] ?? 0
            if siblingScore >= threshold {
                included.append(sibling)
                continue
            }
            // Lone, paragraph-rich siblings without strong negative cues (stand-alone <p>) often belong to the same article.
            if sibling.tagName().lowercased() == "p" {
                let text = try sibling.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count >= 80, try linkDensity(of: sibling) < 0.25 {
                    included.append(sibling)
                }
            }
        }
        if included.isEmpty { included = [winner] }
        return included
    }

    /// Joins block-level children with `"\n\n"` so summaries/search keep paragraph rhythm.
    private static func paragraphPlainText(from elements: [Element]) -> String {
        var paragraphs: [String] = []
        let blockTags: Set<String> = [
            "p", "li", "blockquote", "pre", "h1", "h2", "h3", "h4", "h5", "h6", "tr", "section", "article",
        ]
        for root in elements {
            do {
                let blocks = try root.select(Array(blockTags).joined(separator: ", ")).array()
                if blocks.isEmpty {
                    let t = try root.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { paragraphs.append(t) }
                    continue
                }
                for el in blocks {
                    let raw = try el.text()
                    let cleaned = raw.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty { paragraphs.append(cleaned) }
                }
            } catch {
                continue
            }
        }
        if paragraphs.isEmpty { return "" }
        let unique = deduplicateAdjacent(paragraphs)
        return unique.joined(separator: "\n\n")
    }

    private static func deduplicateAdjacent(_ lines: [String]) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        for line in lines {
            let key = line.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(line)
        }
        return out
    }

    private static func clipToCharacterCount(_ s: String, max: Int) -> String {
        guard s.count > max else { return s }
        return String(s.prefix(max))
    }

    // MARK: - Fallback

    private static func fallbackRoot(body: Element) -> Result? {
        let element: Element
        do {
            if let a = try body.select("article").first() {
                element = a
            } else if let m = try body.select("main").first() {
                element = m
            } else {
                element = body
            }
        } catch {
            return nil
        }
        let text = paragraphPlainText(from: [element])
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Result(root: element, plainText: clipToCharacterCount(cleaned, max: plainTextCharCap))
    }
}
