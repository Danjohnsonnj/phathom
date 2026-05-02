//
//  MainContentExtractorTests.swift
//  PhathomTests
//

import Foundation
import SwiftSoup
import Testing
@testable import Phathom

struct MainContentExtractorTests {

    private static func longParagraph(_ index: Int) -> String {
        // ~120 chars with commas to clear the 25-char threshold and earn comma bonuses.
        "Paragraph \(index): the quick brown fox jumps over the lazy dog, and then it keeps trotting along the riverbank, hopeful, contented."
    }

    @Test func articleBeatsRelatedAside() throws {
        var paragraphs = ""
        for i in 0 ..< 20 { paragraphs += "<p>\(Self.longParagraph(i))</p>" }
        let html = """
        <html><body>
        <header><nav><a href="/x">Home</a></nav></header>
        <article id="post-body" class="article-content">
            <h1>The Title</h1>
            \(paragraphs)
        </article>
        <aside class="related-links">
            <h3>Related</h3>
            <ul>
                <li><a href="/a">Linky one</a></li>
                <li><a href="/b">Linky two</a></li>
                <li><a href="/c">Linky three</a></li>
            </ul>
        </aside>
        <footer>Copyright 2024</footer>
        </body></html>
        """
        let result = try #require(MainContentExtractor.extract(html: html))
        #expect(result.plainText.contains("Paragraph 0:"))
        #expect(!result.plainText.contains("Linky one"))
        #expect(!result.plainText.contains("Copyright"))
        let md = try #require(HTMLMarkdownConverter.convert(root: result.root, baseURL: nil))
        #expect(md.contains("# The Title"))
        #expect(!md.contains("Linky one"))
    }

    @Test func postBodyDivWithoutSemanticTags() throws {
        var paragraphs = ""
        for i in 0 ..< 20 { paragraphs += "<p>\(Self.longParagraph(i))</p>" }
        let html = """
        <html><body>
        <div class="site-header">Header bar</div>
        <div class="post-body">
            \(paragraphs)
        </div>
        <div class="comments">
            <p>Short hot take that nobody asked for, ever.</p>
        </div>
        </body></html>
        """
        let result = try #require(MainContentExtractor.extract(html: html))
        let cls = try result.root.attr("class")
        #expect(cls.contains("post-body"))
        #expect(result.plainText.contains("Paragraph 0:"))
        #expect(!result.plainText.contains("Short hot take"))
    }

    @Test func siblingSweepIncludesLooseParagraphs() throws {
        var paragraphs = ""
        for i in 0 ..< 20 { paragraphs += "<p>\(Self.longParagraph(i))</p>" }
        let html = """
        <html><body>
        <div id="content" class="entry-content">
            \(paragraphs)
        </div>
        <div class="comments-section">
            <h3>Comments</h3>
            <p>Some commenter says hi which is more than twenty five characters of text.</p>
        </div>
        </body></html>
        """
        let result = try #require(MainContentExtractor.extract(html: html))
        #expect(result.plainText.contains("Paragraph 0:"))
        #expect(!result.plainText.contains("Some commenter"))
    }

    @Test func linkDenseListNotChosen() throws {
        var paragraphs = ""
        for i in 0 ..< 25 { paragraphs += "<p>\(Self.longParagraph(i))</p>" }
        var links = ""
        for i in 0 ..< 50 { links += "<li><a href=\"/x\(i)\">Link target number \(i) with a longer label</a></li>" }
        let html = """
        <html><body>
        <article class="article-body">\(paragraphs)</article>
        <ul class="related">\(links)</ul>
        </body></html>
        """
        let result = try #require(MainContentExtractor.extract(html: html))
        #expect(result.plainText.contains("Paragraph 0:"))
        let linkMatches = result.plainText.components(separatedBy: "Link target number").count - 1
        #expect(linkMatches < 5)
    }

    @Test func fallbackNilWhenNoQualifyingContent() {
        let html = """
        <html><body>
        <nav><a href="/a">A</a><a href="/b">B</a></nav>
        <footer>tiny footer</footer>
        </body></html>
        """
        let result = MainContentExtractor.extract(html: html)
        #expect(result == nil)
    }

    @Test func plainTextRespects12kCap() throws {
        var paragraphs = ""
        for i in 0 ..< 1_000 {
            paragraphs += "<p>\(Self.longParagraph(i)) Extra padding so the paragraphs grow long enough to exceed the cap quickly.</p>"
        }
        let html = "<html><body><article class=\"post-body\">\(paragraphs)</article></body></html>"
        let result = try #require(MainContentExtractor.extract(html: html))
        #expect(result.plainText.count <= 12_000)
    }

    @Test func convertRootSkipsArticleSelection() throws {
        let html = """
        <html><body>
        <article><h1>Outer</h1><p>outer body</p></article>
        <div id="custom"><h1>Inner</h1><p>inner body</p></div>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)
        let inner = try #require(try doc.select("#custom").first())
        let md = try #require(HTMLMarkdownConverter.convert(root: inner, baseURL: nil))
        #expect(md.contains("# Inner"))
        #expect(md.contains("inner body"))
        #expect(!md.contains("# Outer"))
        #expect(!md.contains("outer body"))
    }
}
