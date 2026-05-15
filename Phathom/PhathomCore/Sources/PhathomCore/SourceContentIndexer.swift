import Foundation
import Markdown

/// Converts canonical `sourceMarkdown` to themed HTML with `data-md-*` UTF-16 offset spans.
public enum SourceContentIndexer {
    public static let currentVersion: Int = 1

    public struct Result: Sendable {
        public let html: String
        public let version: Int
    }

    /// Index canonical markdown into display HTML with UTF-16 offset spans.
    /// - Parameter markdown: Canonical stored `sourceMarkdown` (already trimmed at ingest).
    /// - Returns: HTML body fragment + version, or `nil` if markdown is empty.
    public static func index(markdown: String) -> Result? {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let document = Document(parsing: trimmed, options: [.parseBlockDirectives, .parseSymbolLinks])
        var visitor = HTMLVisitor(source: trimmed)
        visitor.visit(document)
        return Result(html: visitor.html, version: currentVersion)
    }
}

private struct HTMLVisitor: MarkupVisitor {
    typealias Result = Void

    let source: String
    private(set) var html: String = ""

    init(source: String) {
        self.source = source
    }

    mutating func defaultVisit(_ markup: any Markup) -> Void {
        for child in markup.children {
            visit(child)
        }
    }

    // MARK: - Block elements

    mutating func visitDocument(_ document: Document) -> Void {
        for child in document.children {
            visit(child)
        }
    }

    mutating func visitHeading(_ heading: Heading) -> Void {
        let tag = "h\(min(heading.level, 6))"
        html += "<\(tag)>"
        visitInlineChildren(heading)
        html += "</\(tag)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> Void {
        html += "<p>"
        visitInlineChildren(paragraph)
        html += "</p>\n"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> Void {
        html += "<ul>\n"
        for item in list.listItems {
            visit(item)
        }
        html += "</ul>\n"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> Void {
        html += "<ol>\n"
        for item in list.listItems {
            visit(item)
        }
        html += "</ol>\n"
    }

    mutating func visitListItem(_ item: ListItem) -> Void {
        html += "<li>"
        for child in item.children {
            if child is Paragraph {
                visitInlineChildren(child as! Paragraph)
            } else {
                visit(child)
            }
        }
        html += "</li>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> Void {
        html += "<blockquote>\n"
        for child in blockQuote.children {
            visit(child)
        }
        html += "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> Void {
        html += "<pre><code>"
        let code = codeBlock.code
        if !code.isEmpty {
            if let range = codeBlock.range {
                let (start, end) = utf16Offsets(for: range)
                let fenceContentStart = findFenceContentStart(in: source, blockStart: start)
                let fenceContentEnd = findFenceContentEnd(in: source, blockEnd: end)
                let content = escapeHTML(code.trimmingCharacters(in: .newlines))
                html += "<span data-md-start=\"\(fenceContentStart)\" data-md-end=\"\(fenceContentEnd)\">\(content)</span>"
            } else {
                html += escapeHTML(code)
            }
        }
        html += "</code></pre>\n"
    }

    mutating func visitThematicBreak(_ break: ThematicBreak) -> Void {
        html += "<hr>\n"
    }

    mutating func visitTable(_ table: Table) -> Void {
        html += "<table>\n"
        let head = table.head
        html += "<thead><tr>"
        for cell in head.cells {
            html += "<th>"
            visitInlineChildren(cell)
            html += "</th>"
        }
        html += "</tr></thead>\n"
        html += "<tbody>\n"
        for row in table.body.rows {
            html += "<tr>"
            for cell in row.cells {
                html += "<td>"
                visitInlineChildren(cell)
                html += "</td>"
            }
            html += "</tr>\n"
        }
        html += "</tbody>\n</table>\n"
    }

    // MARK: - Inline elements

    mutating func visitStrong(_ strong: Strong) -> Void {
        html += "<strong>"
        visitInlineChildren(strong)
        html += "</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> Void {
        html += "<em>"
        visitInlineChildren(emphasis)
        html += "</em>"
    }

    mutating func visitInlineCode(_ code: InlineCode) -> Void {
        html += "<code>"
        if let range = code.range {
            let (start, end) = utf16Offsets(for: range)
            let innerStart = start + 1
            let innerEnd = end - 1
            let content = escapeHTML(code.code)
            html += "<span data-md-start=\"\(innerStart)\" data-md-end=\"\(innerEnd)\">\(content)</span>"
        } else {
            html += escapeHTML(code.code)
        }
        html += "</code>"
    }

    mutating func visitLink(_ link: Link) -> Void {
        let href = link.destination ?? ""
        html += "<a href=\"\(escapeHTML(href))\">"
        visitInlineChildren(link)
        html += "</a>"
    }

    mutating func visitImage(_ image: Image) -> Void {
        let alt = image.plainText
        let src = image.source ?? ""
        html += "<img alt=\"\(escapeHTML(alt))\" src=\"\(escapeHTML(src))\">"
    }

    mutating func visitText(_ text: Text) -> Void {
        guard let range = text.range else {
            html += escapeHTML(text.string)
            return
        }
        let (start, end) = utf16Offsets(for: range)
        let content = escapeHTML(text.string)
        html += "<span data-md-start=\"\(start)\" data-md-end=\"\(end)\">\(content)</span>"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Void {
        html += " "
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> Void {
        html += "<br>"
    }

    // MARK: - Helpers

    private mutating func visitInlineChildren(_ markup: some Markup) {
        for child in markup.children {
            visit(child)
        }
    }

    private func utf16Offsets(for range: SourceRange) -> (start: Int, end: Int) {
        let startLine = range.lowerBound.line - 1
        let startCol = range.lowerBound.column - 1
        let endLine = range.upperBound.line - 1
        let endCol = range.upperBound.column - 1

        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }

        var startOffset = 0
        for i in 0 ..< startLine where i < lines.count {
            startOffset += lines[i].utf16.count + 1
        }
        if startLine < lines.count {
            let line = lines[startLine]
            let colOffset = min(startCol, line.utf16.count)
            startOffset += colOffset
        }

        var endOffset = 0
        for i in 0 ..< endLine where i < lines.count {
            endOffset += lines[i].utf16.count + 1
        }
        if endLine < lines.count {
            let line = lines[endLine]
            let colOffset = min(endCol, line.utf16.count)
            endOffset += colOffset
        }

        return (startOffset, endOffset)
    }

    private func findFenceContentStart(in source: String, blockStart: Int) -> Int {
        let utf16 = Array(source.utf16)
        var i = blockStart
        while i < utf16.count {
            if utf16[i] == 0x0A {
                return i + 1
            }
            i += 1
        }
        return blockStart
    }

    private func findFenceContentEnd(in source: String, blockEnd: Int) -> Int {
        let utf16 = Array(source.utf16)
        var i = blockEnd - 1
        while i > 0 && utf16[i] == 0x60 {
            i -= 1
        }
        while i > 0 && utf16[i] == 0x0A {
            i -= 1
        }
        return i + 1
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
