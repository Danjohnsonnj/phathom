#if DEBUG
import Foundation

/// Hand-built markdown + HTML with `data-md-*` spans for WK spike (indexer not built yet).
enum SourceContentSpikeFixtures {
    static let canonicalMarkdown: String = """
    # Spike Title

    Paragraph with **bold** word and [link](https://example.com) text.

    - Alpha item
    - Beta item

    > Quoted words

    Inline `tick` code.
    """.trimmingCharacters(in: .whitespacesAndNewlines)

    /// UTF-16 range of first occurrence of `needle` in canonical markdown.
    static func utf16Range(of needle: String, in markdown: String = canonicalMarkdown) -> (start: Int, end: Int) {
        guard let range = markdown.range(of: needle) else {
            fatalError("needle not found: \(needle)")
        }
        let start = markdown.utf16.distance(
            from: markdown.utf16.startIndex,
            to: range.lowerBound.samePosition(in: markdown.utf16)!
        )
        let end = markdown.utf16.distance(
            from: markdown.utf16.startIndex,
            to: range.upperBound.samePosition(in: markdown.utf16)!
        )
        return (start, end)
    }

    private static func span(_ visible: String, in md: String = canonicalMarkdown) -> String {
        let r = utf16Range(of: visible, in: md)
        let escaped = visible
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
        return "<span data-md-start=\"\(r.start)\" data-md-end=\"\(r.end)\">\(escaped)</span>"
    }

    static var fixtureBodyHTML: String {
        let title = span("Spike Title")
        let paraLead = span("Paragraph with ")
        let bold = span("bold")
        let paraMid = span(" word and ")
        let link = span("link")
        let paraTail = span(" text.")
        let alpha = span("Alpha item")
        let beta = span("Beta item")
        let quote = span("Quoted words")
        let tick = span("tick")
        return """
        <h1>\(title)</h1>
        <p>\(paraLead)<strong>\(bold)</strong>\(paraMid)<a href="https://example.com">\(link)</a>\(paraTail)</p>
        <ul><li>\(alpha)</li><li>\(beta)</li></ul>
        <blockquote><p>\(quote)</p></blockquote>
        <p>Inline <code>\(tick)</code> code.</p>
        """
    }

    static func wrapDocument(body: String, collapsed: Bool = false) -> String {
        let collapsedClass = collapsed ? " phathom-source-collapsed" : ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(sourceContentCSS)
        </style>
        </head>
        <body class="phathom-source\(collapsedClass)">
        \(body)
        </body>
        </html>
        """
    }

    static var sourceContentCSS: String {
        """
        :root {
          --text-primary: #fffcf2;
          --text-secondary: #ccc5b9;
          --text-tertiary: rgba(204, 197, 185, 0.72);
          --accent: #eb5e28;
          --surface-nested: #353330;
          --bg: #252422;
        }
        body.phathom-source {
          font: -apple-system-body;
          font-size: 16px;
          line-height: 1.5;
          color: var(--text-primary);
          background: var(--bg);
          margin: 0;
          padding: 16px;
          -webkit-text-size-adjust: 100%;
        }
        body.phathom-source-collapsed {
          max-height: 12em;
          overflow: hidden;
        }
        h1, h2 {
          font-weight: 600;
          border-bottom: 1px solid var(--text-tertiary);
          padding-bottom: 0.3em;
          margin: 1.5em 0 1em;
        }
        h1 { font-size: 2em; }
        a { color: var(--accent); }
        blockquote {
          border-left: 0.2em solid var(--text-tertiary);
          margin: 0 0 1em;
          padding-left: 1em;
          color: var(--text-secondary);
        }
        pre, code {
          font-family: ui-monospace, monospace;
          font-size: 0.85em;
        }
        pre {
          background: var(--surface-nested);
          border-radius: 6px;
          padding: 16px;
          overflow-x: auto;
        }
        code { background: rgba(53, 51, 48, 0.55); padding: 0.1em 0.25em; border-radius: 4px; }
        mark.phathom-highlight {
          background: rgba(235, 94, 40, 0.35);
          border-radius: 2px;
        }
        ul { padding-left: 1.25em; }
        """
    }

    /// Sample highlight: word "bold" in paragraph.
    static var sampleHighlightRange: (start: Int, end: Int, id: String) {
        let r = utf16Range(of: "bold")
        return (r.start, r.end, "spike-highlight-1")
    }

    /// JSON passed into `phathomSpikeSelfTest`.
    static var selfTestExpectationsJSON: String {
        let bold = utf16Range(of: "bold")
        let link = utf16Range(of: "link")
        let paraLead = utf16Range(of: "Paragraph with ")
        let boldR = utf16Range(of: "bold")
        let expectations: [[String: Any]] = [
            [
                "name": "single_bold",
                "kind": "single",
                "start": bold.start,
                "end": bold.end,
                "wantStart": bold.start,
                "wantEnd": bold.end,
                "wantText": "bold",
            ],
            [
                "name": "single_link_label",
                "kind": "single",
                "start": link.start,
                "end": link.end,
                "wantStart": link.start,
                "wantEnd": link.end,
                "wantText": "link",
            ],
            [
                "name": "across_bold_and_link",
                "kind": "across",
                "startA": paraLead.start,
                "endA": paraLead.end,
                "startB": link.start,
                "endB": link.end,
                "wantStart": paraLead.start,
                "wantEnd": link.end,
            ],
            [
                "name": "across_emphasis_boundary",
                "kind": "across",
                "startA": paraLead.start,
                "endA": paraLead.end,
                "startB": boldR.start,
                "endB": boldR.end,
                "wantStart": paraLead.start,
                "wantEnd": boldR.end,
            ],
        ]
        let data = try! JSONSerialization.data(withJSONObject: expectations)
        return String(data: data, encoding: .utf8)!
    }

    static let parityMarkdown: String = """
    # Parity Sample

    Opening paragraph with **emphasis** and [a link](https://example.com).

    - List one
    - List two

    > Blockquote line

    Inline `code` and a fence below.

    ```
    println("hi")
    ```

    | Col A | Col B |
    | ----- | ----- |
    | r1a   | r1b   |
    """

    static var parityBodyHTML: String {
        let md = parityMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        func s(_ t: String) -> String { span(t, in: md) }
        return """
        <h1>\(s("Parity Sample"))</h1>
        <p>\(s("Opening paragraph with "))<strong>\(s("emphasis"))</strong>\(s(" and "))<a href="https://example.com">\(s("a link"))</a>.</p>
        <ul><li>\(s("List one"))</li><li>\(s("List two"))</li></ul>
        <blockquote><p>\(s("Blockquote line"))</p></blockquote>
        <p>\(s("Inline "))<code>\(s("code"))</code>\(s(" and a fence below."))</p>
        <pre><code>\(s("println(\"hi\")"))</code></pre>
        <table>
        <thead><tr><th>\(s("Col A"))</th><th>\(s("Col B"))</th></tr></thead>
        <tbody><tr><td>\(s("r1a"))</td><td>\(s("r1b"))</td></tr></tbody>
        </table>
        """
    }
}
#endif
