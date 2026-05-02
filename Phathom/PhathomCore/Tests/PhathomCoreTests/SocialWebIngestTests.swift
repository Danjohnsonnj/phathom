import Foundation
import PhathomCore
import XCTest

final class SocialWebIngestTests: XCTestCase {
    func testSocialListTitle_wordSafeTrim() {
        let long =
            "In this clip from Eric's conversation with Robert Engels they discuss the how the writers balanced story plotting and room."
        let t = SocialListTitle.fromCaption(long)!
        XCTAssertLessThanOrEqual(t.count, 100)
        XCTAssertTrue(t.hasSuffix("balanced"))
        XCTAssertFalse(t.contains("story"))
    }

    func testSocialListTitle_shortLine() {
        XCTAssertEqual(SocialListTitle.fromCaption("Hello world")!, "Hello world")
    }

    func testSocialListTitle_usesFirstLineOnly() {
        let caption = "First line title\nSecond line should not be in title"
        XCTAssertEqual(SocialListTitle.fromCaption(caption), "First line title")
    }

    func testInstagramNormalize_statsAndQuotes() {
        let raw = """
        1,581 likes, 9 comments - meanwhile_twinpeaks on April 26, 2026: "In this clip from Eric's conversation with Robert Engels.

        #twinpeaks #podcast"
        """
        let cap = InstagramSocialCaption.normalizedCaption(ogDescription: raw, ogTitle: nil)
        XCTAssertTrue(cap.contains("Robert Engels"))
        XCTAssertTrue(cap.contains("#twinpeaks"))
        XCTAssertFalse(cap.contains("1,581 likes"))
    }

    func testInstagramNormalize_statsWithoutOpeningQuote() {
        let raw = "2,115 views, 84 comments - user_name on March 3, 2026: Caption text without leading quote #tag"
        let cap = InstagramSocialCaption.normalizedCaption(ogDescription: raw, ogTitle: nil)
        XCTAssertEqual(cap, "Caption text without leading quote #tag")
    }

    func testInstagramNormalize_fallsBackToOgTitle() {
        let title =
            "Meanwhile, a Twin Peaks podcast on Instagram: \"Caption only in title with #tag\""
        let cap = InstagramSocialCaption.normalizedCaption(ogDescription: nil, ogTitle: title)
        XCTAssertEqual(cap, "Caption only in title with #tag")
    }

    func testInstagramCaptionForListTitle_dropsAudioAttributionLine() {
        let normalized = """
        original sound · creator_handle

        Actual caption headline for this reel
        """
        let adjusted = InstagramSocialCaption.captionForListTitle(normalizedCaption: normalized)
        XCTAssertTrue(adjusted.hasPrefix("Actual caption headline"))
        XCTAssertFalse(adjusted.contains("original sound"))
    }

    func testHashtagParser_orderAndDedupe() {
        let s = "Hello #VFX #vfx #StarWars and #cgi!"
        let tags = HashtagParser.tagNames(in: s)
        XCTAssertEqual(tags, ["vfx", "starwars", "cgi"])
    }

    func testTikTokResolver_knownPath() throws {
        let desc = "Caption with #tiktok"
        let json: [String: Any] = [
            "__DEFAULT_SCOPE__": [
                "webapp.reflow.video.detail": [
                    "itemInfo": [
                        "itemStruct": [
                            "desc": desc,
                            "author": ["uniqueId": "creator_name"],
                            "video": ["cover": "https://example.com/a.jpg"],
                        ],
                    ],
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let html =
            "<html><script id=\"__UNIVERSAL_DATA_FOR_REHYDRATION__\" type=\"application/json\">"
            + String(data: data, encoding: .utf8)! + "</script></html>"
        let payload = try TikTokItemStructResolver.payload(fromHTML: html)
        XCTAssertEqual(payload.description, desc)
        XCTAssertEqual(payload.uniqueId, "creator_name")
        XCTAssertEqual(payload.coverURL, "https://example.com/a.jpg")
        XCTAssertNil(payload.subtitleTrack)
    }

    func testTikTokResolver_recursiveFallback() throws {
        let desc = "Nested #find"
        let inner: [String: Any] = [
            "desc": desc,
            "author": [:],
            "video": ["cover": "https://cdn.test/cover.jpg"],
        ]
        let json: [String: Any] = ["a": ["b": ["c": inner]]]
        let data = try JSONSerialization.data(withJSONObject: json)
        let html =
            "<html><script id=\"__UNIVERSAL_DATA_FOR_REHYDRATION__\" type=\"application/json\">"
            + String(data: data, encoding: .utf8)! + "</script></html>"
        let payload = try TikTokItemStructResolver.payload(fromHTML: html)
        XCTAssertEqual(payload.description, desc)
    }

    func testTikTokResolver_recursiveFallback_picksBestCandidate() throws {
        let short: [String: Any] = [
            "desc": "short",
            "author": [:],
            "video": [:],
        ]
        let rich: [String: Any] = [
            "desc": "Longer caption that should win because it is richer and includes a creator id.",
            "author": ["uniqueId": "winning_creator"],
            "video": ["cover": "https://cdn.test/win.jpg"],
        ]
        let json: [String: Any] = ["outer": ["first": short, "second": rich]]
        let data = try JSONSerialization.data(withJSONObject: json)
        let html =
            "<html><script id=\"__UNIVERSAL_DATA_FOR_REHYDRATION__\" type=\"application/json\">"
            + String(data: data, encoding: .utf8)! + "</script></html>"
        let payload = try TikTokItemStructResolver.payload(fromHTML: html)
        XCTAssertEqual(payload.uniqueId, "winning_creator")
        XCTAssertEqual(payload.coverURL, "https://cdn.test/win.jpg")
    }

    func testWebVTT_plainText_stripsTiming() {
        let vtt = """
        WEBVTT

        00:00:00.000 --> 00:00:01.900
        Hello world.

        00:00:02.000 --> 00:00:03.000
        Second cue line.
        """
        let plain = WebVTTTranscriptParser.plainText(from: vtt, maxCharacters: 10_000)
        XCTAssertTrue(plain.contains("Hello world."))
        XCTAssertTrue(plain.contains("Second cue line."))
        XCTAssertFalse(plain.contains("-->"))
    }

    func testTikTokResolver_prefersEnglishSubtitleTrack() throws {
        let desc = "Caption #tag"
        let json: [String: Any] = [
            "__DEFAULT_SCOPE__": [
                "webapp.reflow.video.detail": [
                    "itemInfo": [
                        "itemStruct": [
                            "desc": desc,
                            "author": ["uniqueId": "u"],
                            "video": [
                                "cover": "https://example.com/a.jpg",
                                "subtitleInfos": [
                                    [
                                        "Url": "https://cdn.test/es.vtt",
                                        "LanguageCodeName": "spa-ES",
                                    ],
                                    [
                                        "Url": "https://cdn.test/en.vtt",
                                        "LanguageCodeName": "eng-US",
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let html =
            "<html><script id=\"__UNIVERSAL_DATA_FOR_REHYDRATION__\" type=\"application/json\">"
            + String(data: data, encoding: .utf8)! + "</script></html>"
        let payload = try TikTokItemStructResolver.payload(fromHTML: html)
        XCTAssertEqual(payload.subtitleTrack?.url, "https://cdn.test/en.vtt")
        XCTAssertEqual(payload.subtitleTrack?.languageCode, "eng-US")
    }

    func testTikTokAIArticleText_assembleWithTranscript() {
        let text = TikTokAIArticleText.assemble(
            uniqueId: "creator",
            description: "Cap line #hello",
            transcript: "Spoken one. Spoken two."
        )
        XCTAssertTrue(text.hasPrefix("Author: @creator"))
        XCTAssertTrue(text.contains("Transcript:\nSpoken one. Spoken two."))
        XCTAssertTrue(text.contains("Post caption:\nCap line #hello"))
    }

    func testTikTokAIArticleText_assembleWithoutTranscript() {
        let text = TikTokAIArticleText.assemble(uniqueId: nil, description: "Only caption #x", transcript: nil)
        XCTAssertFalse(text.contains("Transcript:"))
        XCTAssertTrue(text.contains("Post caption:\nOnly caption #x"))
    }

    func testHashtagParser_findsTagsInTikTokAssembly() {
        let text = TikTokAIArticleText.assemble(
            uniqueId: "u",
            description: "Post #alpha",
            transcript: "Say #beta aloud."
        )
        XCTAssertEqual(HashtagParser.tagNames(in: text), ["beta", "alpha"])
    }
}
