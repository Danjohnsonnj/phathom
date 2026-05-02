//
//  HTMLMarkdownConverterTests.swift
//  PhathomTests
//

import Foundation
import Testing
@testable import Phathom

struct HTMLMarkdownConverterTests {

    @Test func headings() {
        let html = """
        <html><body><article>
        <h1>Main Title</h1>
        <h2>Section</h2>
        <p>Hi</p>
        </article></body></html>
        """
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(md!.contains("# Main Title"))
        #expect(md!.contains("## Section"))
        #expect(md!.contains("Hi"))
    }

    @Test func unorderedList() {
        let html = "<main><ul><li>Alpha</li><li>Beta</li></ul></main>"
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(md!.contains("- Alpha"))
        #expect(md!.contains("- Beta"))
    }

    @Test func orderedList() {
        let html = "<article><ol><li>One</li><li>Two</li></ol></article>"
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(md!.contains("1. One"))
        #expect(md!.contains("2. Two"))
    }

    @Test func orderedListStartAttribute() {
        let html = "<body><ol start=\"3\"><li>Third</li></ol></body>"
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(md!.contains("3. Third"))
    }

    @Test func blockquote() {
        let html = "<article><blockquote><p>Quoted line</p></blockquote></article>"
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(md!.contains("> Quoted line"))
    }

    @Test func relativeLinkResolved() {
        let html = "<body><p><a href=\"/path/to/page\">Click</a></p></body>"
        let base = URL(string: "https://example.com/news/")!
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: base)
        #expect(md != nil)
        #expect(md!.contains("[Click](https://example.com/path/to/page)"))
    }

    @Test func lineBreakInParagraph() {
        let html = "<body><p>Line one<br>Line two</p></body>"
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(md!.contains("Line one"))
        #expect(md!.contains("Line two"))
    }

    @Test func preformattedCodeBlock() {
        let html = "<body><pre>let x = 1\nprint(x)</pre></body>"
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(md!.contains("```"))
        #expect(md!.contains("let x = 1"))
    }

    @Test func scriptRemoved() {
        let html = """
        <body><article>
        <script>evil()</script>
        <p>Safe text</p>
        </article></body>
        """
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(!md!.contains("evil"))
        #expect(md!.contains("Safe text"))
    }

    @Test func emptyArticle() {
        let html = "<html><body><article></article></body></html>"
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md == nil)
    }

    @Test func respectsMaxUTF8ByteCap() {
        var paras = ""
        for i in 0 ..< 5_000 {
            paras += "<p>Hello world paragraph \(i) with filler text for length.</p>"
        }
        let html = "<article>\(paras)</article>"
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(md!.utf8.count <= 50 * 1024)
    }

    @Test func strongAndEmphasis() {
        let html = "<body><p><strong>Bold</strong> and <em>italic</em></p></body>"
        let md = HTMLMarkdownConverter.convert(html: html, baseURL: nil)
        #expect(md != nil)
        #expect(md!.contains("**Bold**"))
        #expect(md!.contains("*italic*"))
    }
}
