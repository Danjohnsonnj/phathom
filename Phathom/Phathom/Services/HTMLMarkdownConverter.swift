import Foundation
import SwiftSoup

/// Converts fetched HTML into readable markdown for Detail **Source Content** (generic web only).
/// `rawText` / LLM prompts stay on the separate flattened plain path in `WebIngestService`.
enum HTMLMarkdownConverter {
    private static let maxUTF8Bytes = 50 * 1024

    /// Parsed and flattened markdown, or `nil` if there is no usable body or output is empty.
    /// Used as the fallback path when `MainContentExtractor` can't pick a confident subtree.
    static func convert(html: String, baseURL: URL?) -> String? {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            let doc = try SwiftSoup.parse(trimmed)
            try doc.select("script, style, noscript, nav, footer, aside").remove()

            let root: Element?
            if let a = try doc.select("article").first() {
                root = a
            } else if let m = try doc.select("main").first() {
                root = m
            } else {
                root = doc.body()
            }
            guard let root else { return nil }
            return walk(root: root, baseURL: baseURL)
        } catch {
            return nil
        }
    }

    /// Walk a pre-picked element (from `MainContentExtractor`) directly. The element is assumed already
    /// stripped of obvious noise; we still skip noisy tags defensively in `emitBlockElement`.
    static func convert(root: Element, baseURL: URL?) -> String? {
        walk(root: root, baseURL: baseURL)
    }

    private static func walk(root: Element, baseURL: URL?) -> String? {
        do {
            var ctx = EmitContext(baseURL: baseURL)
            try emitBlockChildren(of: root, ctx: &ctx)
            let normalized = normalizeOutput(ctx.output)
            let final = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            return final.isEmpty ? nil : final
        } catch {
            return nil
        }
    }

    // MARK: - Emit

    private static func emitBlockChildren(of element: Element, ctx: inout EmitContext) throws {
        for node in element.getChildNodes() {
            if let textNode = node as? TextNode {
                let t = textNode.getWholeText()
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { ctx.appendParagraph(trimmed) }
            } else if let el = node as? Element {
                try emitBlockElement(el, ctx: &ctx)
            }
        }
    }

    private static func emitBlockElement(_ el: Element, ctx: inout EmitContext) throws {
        let tag = el.tagName().lowercased()
        switch tag {
        case "script", "style", "noscript", "nav", "footer", "aside", "template", "iframe":
            return
        case "h1": try emitHeading(el, level: 1, ctx: &ctx)
        case "h2": try emitHeading(el, level: 2, ctx: &ctx)
        case "h3": try emitHeading(el, level: 3, ctx: &ctx)
        case "h4": try emitHeading(el, level: 4, ctx: &ctx)
        case "h5": try emitHeading(el, level: 5, ctx: &ctx)
        case "h6": try emitHeading(el, level: 6, ctx: &ctx)
        case "p":
            let line = try collectInline(el, baseURL: ctx.baseURL)
            ctx.appendParagraph(line)
        case "ul":
            try emitUnorderedList(el, ctx: &ctx, indent: "")
        case "ol":
            let start = Int(try el.attr("start").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
            try emitOrderedList(el, ctx: &ctx, indent: "", start: start)
        case "blockquote":
            var innerCtx = EmitContext(baseURL: ctx.baseURL)
            try emitBlockChildren(of: el, ctx: &innerCtx)
            let inner = innerCtx.output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !inner.isEmpty else { return }
            for line in inner.components(separatedBy: .newlines) {
                let row = line.trimmingCharacters(in: .whitespaces)
                if row.isEmpty {
                    ctx.append(">\n")
                } else {
                    ctx.append("> \(row)\n")
                }
            }
            ctx.append("\n")
        case "pre":
            let code = try el.text()
            ctx.append("```\n\(code)\n```\n\n")
        case "br":
            ctx.append("\n")
        case "hr":
            ctx.append("---\n\n")
        case "table":
            let flat = try el.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !flat.isEmpty { ctx.appendParagraph(flat) }
        case "li":
            /* Handled inside list emitters */
            try emitBlockChildren(of: el, ctx: &ctx)
        case "div", "section", "header", "article", "main", "figure", "figcaption", "span", "center":
            try emitBlockChildren(of: el, ctx: &ctx)
        default:
            let line = try collectInline(el, baseURL: ctx.baseURL)
            if !line.isEmpty {
                ctx.appendParagraph(line)
            } else {
                try emitBlockChildren(of: el, ctx: &ctx)
            }
        }
    }

    private static func emitHeading(_ el: Element, level: Int, ctx: inout EmitContext) throws {
        let hashes = String(repeating: "#", count: min(max(level, 1), 6))
        let text = try collectInline(el, baseURL: ctx.baseURL).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        ctx.append("\(hashes) \(text)\n\n")
    }

    private static func emitUnorderedList(_ ul: Element, ctx: inout EmitContext, indent: String) throws {
        for child in ul.getChildNodes() {
            guard let li = child as? Element, li.tagName().lowercased() == "li" else { continue }
            let prefix = indent + "- "
            let firstLine = try listItemParts(li, baseURL: ctx.baseURL)
            if !firstLine.isEmpty {
                ctx.append("\(prefix)\(firstLine)\n")
            } else {
                ctx.append("\(prefix)\n")
            }
            try emitNestedLists(in: li, ctx: &ctx, indent: indent + "  ")
        }
        ctx.append("\n")
    }

    private static func emitOrderedList(_ ol: Element, ctx: inout EmitContext, indent: String, start: Int) throws {
        var index = start
        for child in ol.getChildNodes() {
            guard let li = child as? Element, li.tagName().lowercased() == "li" else { continue }
            let prefix = "\(indent)\(index). "
            let firstLine = try listItemParts(li, baseURL: ctx.baseURL)
            if !firstLine.isEmpty {
                ctx.append("\(prefix)\(firstLine)\n")
            } else {
                ctx.append("\(prefix)\n")
            }
            try emitNestedLists(in: li, ctx: &ctx, indent: indent + "  ")
            index += 1
        }
        ctx.append("\n")
    }

    /// Pull leading non-list content as inline; return remainder handled via nested lists.
    private static func listItemParts(_ li: Element, baseURL: URL?) throws -> String {
        var chunks: [String] = []
        for node in li.getChildNodes() {
            if let el = node as? Element {
                let t = el.tagName().lowercased()
                if t == "ul" || t == "ol" { break }
            }
            if let textNode = node as? TextNode {
                let piece = textNode.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty { chunks.append(piece) }
            } else if let el = node as? Element {
                let t = el.tagName().lowercased()
                if t == "p" {
                    chunks.append(try collectInline(el, baseURL: baseURL))
                } else if t != "ul", t != "ol" {
                    chunks.append(try collectInline(el, baseURL: baseURL))
                }
            }
        }
        return chunks.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func emitNestedLists(in li: Element, ctx: inout EmitContext, indent: String) throws {
        for node in li.getChildNodes() {
            guard let el = node as? Element else { continue }
            let t = el.tagName().lowercased()
            if t == "ul" {
                try emitUnorderedList(el, ctx: &ctx, indent: indent)
            } else if t == "ol" {
                let start = Int(try el.attr("start").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                try emitOrderedList(el, ctx: &ctx, indent: indent, start: start)
            }
        }
    }

    // MARK: - Inline

    private static func collectInline(_ el: Element, baseURL: URL?) throws -> String {
        var parts: [String] = []
        for node in el.getChildNodes() {
            if let tn = node as? TextNode {
                parts.append(tn.getWholeText())
            } else if let child = node as? Element {
                let t = child.tagName().lowercased()
                switch t {
                case "br":
                    parts.append("\n")
                case "strong", "b":
                    let inner = try collectInline(child, baseURL: baseURL)
                    if !inner.isEmpty { parts.append("**\(inner)**") }
                case "em", "i":
                    let inner = try collectInline(child, baseURL: baseURL)
                    if !inner.isEmpty { parts.append("*\(inner)*") }
                case "code":
                    let inner = try child.text()
                    if !inner.isEmpty { parts.append("`\(inner)`") }
                case "a":
                    let href = try child.attr("href")
                    let inner = try collectInline(child, baseURL: baseURL)
                    let resolved = resolveHref(href, baseURL: baseURL)
                    if inner.isEmpty {
                        parts.append(resolved)
                    } else {
                        parts.append("[\(inner)](\(resolved))")
                    }
                case "span", "small", "sub", "sup", "mark", "cite", "abbr":
                    parts.append(try collectInline(child, baseURL: baseURL))
                default:
                    parts.append(try collectInline(child, baseURL: baseURL))
                }
            }
        }
        return collapseInlineSpacing(parts.joined()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolveHref(_ href: String, baseURL: URL?) -> String {
        let t = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return t }
        if let base = baseURL, let u = URL(string: t, relativeTo: base)?.absoluteURL {
            return u.absoluteString
        }
        return t
    }

    private static func collapseInlineSpacing(_ s: String) -> String {
        s.replacingOccurrences(of: #"[ \t\f\v]+"#, with: " ", options: .regularExpression)
    }

    private static func normalizeOutput(_ s: String) -> String {
        var out = s.replacingOccurrences(of: #"\R{3,}"#, with: "\n\n", options: .regularExpression)
        while out.contains("\n \n") {
            out = out.replacingOccurrences(of: "\n \n", with: "\n\n")
        }
        return out
    }

    // MARK: - Context

    private struct EmitContext {
        let baseURL: URL?
        private(set) var output = ""
        private var byteCount = 0

        init(baseURL: URL?) {
            self.baseURL = baseURL
        }

        mutating func append(_ s: String) {
            guard byteCount < HTMLMarkdownConverter.maxUTF8Bytes else { return }
            let remaining = HTMLMarkdownConverter.maxUTF8Bytes - byteCount
            let piece = s.clippedToUTF8ByteCount(remaining)
            output.append(piece)
            byteCount = output.utf8.count
        }

        mutating func appendParagraph(_ line: String) {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            append(t)
            append("\n\n")
        }
    }
}

private extension String {
    func clippedToUTF8ByteCount(_ maxBytes: Int) -> String {
        guard maxBytes > 0 else { return "" }
        var total = 0
        var result = ""
        for ch in self {
            let c = String(ch).utf8.count
            if total + c > maxBytes { break }
            result.append(ch)
            total += c
        }
        return result
    }
}
