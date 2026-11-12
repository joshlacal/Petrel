import Foundation
@testable import Petrel
import Testing

@Suite("RichText Facet Conversion")
struct RichTextFacetTests {
    @Test("Link facets respect UTF-8 byte offsets")
    func linkFacetByteOffsets() throws {
        var attributed = AttributedString(
            "fair enough!! it’s good they let you migrate back to bsky.social PDSs now though"
        )
        let linkRange = attributed.range(of: "bsky.social")
        #expect(linkRange != nil)
        if let range = linkRange {
            attributed[range].link = URL(string: "https://bsky.social")
        }

        let facets = try #require(try attributed.toFacets())
        #expect(facets.count == 1)

        let byteSlice = facets[0].index
        #expect(byteSlice.byteStart == 55)
        #expect(byteSlice.byteEnd == 66)
    }
}

#if canImport(SwiftUI)
    import SwiftUI

    @Suite("RichText AttributedString bridge")
    struct RichTextAttributedStringTests {
        private func post(_ text: String, _ facets: [AppBskyRichtextFacet]) -> AppBskyFeedPost {
            AppBskyFeedPost(text: text, facets: facets, createdAt: ATProtocolDate(date: Date(timeIntervalSince1970: 0)))
        }

        private func tagFacet(_ start: Int, _ end: Int, _ tag: String) -> AppBskyRichtextFacet {
            AppBskyRichtextFacet(
                index: .init(byteStart: start, byteEnd: end),
                features: [.appBskyRichtextFacetTag(.init(tag: tag))]
            )
        }

        @Test(
            "Tags round-trip exactly through AttributedString",
            arguments: ["swift", "Swift", "日本語", "🦋", "two words", "100%", "c++", "a/b", "/leading", "#️⃣tag", "tag?x=1#y"]
        )
        func tagsRoundTrip(_ tag: String) throws {
            let text = "#\(tag) end"
            let original = tagFacet(0, 1 + tag.utf8.count, tag)
            let attributed = post(text, [original]).facetsAsAttributedString

            #expect(String(attributed.characters) == text)
            let facets = try #require(try attributed.toFacets())
            #expect(facets == [original])
        }

        @Test("A tag that is a valid URL host keeps the tag://<tag> link form")
        func plainTagLinkForm() {
            let attributed = post("#swift", [tagFacet(0, 6, "swift")]).facetsAsAttributedString
            #expect(attributed.runs.first?.link?.absoluteString == "tag://swift")
        }

        @Test("A tag recovered from a link alone survives without the attribute")
        func tagFromLinkOnly() throws {
            for tag in ["日本語", "two words", "100%", "swift"] {
                var attributed = AttributedString("#\(tag)")
                attributed.link = RichTextLinkURL.tagURL(tag)
                let facets = try #require(try attributed.toFacets())
                #expect(facets.first?.features == [.appBskyRichtextFacetTag(.init(tag: tag))])
            }
        }

        @Test(
            "Mentions round-trip exactly through AttributedString",
            arguments: ["did:plc:z72i7hdynmk6r22z27h6tvur", "did:web:example.com", "did:web:localhost%3A2583"]
        )
        func mentionsRoundTrip(_ did: String) throws {
            let original = try AppBskyRichtextFacet(
                index: .init(byteStart: 3, byteEnd: 9),
                features: [.appBskyRichtextFacetMention(.init(did: DID(didString: did)))]
            )
            let attributed = post("hi @alice!", [original]).facetsAsAttributedString
            let facets = try #require(try attributed.toFacets())
            #expect(facets == [original])
        }

        @Test(
            "Malformed byte offsets from the network are skipped, never trapped on",
            arguments: [(-1, 4), (-8, -2), (4, 2), (0, 999), (999, 1000), (Int.min, Int.max), (3, 3)]
        )
        func malformedOffsets(_ start: Int, _ end: Int) {
            let text = "hello #tag"
            let attributed = post(text, [tagFacet(start, end, "tag")]).facetsAsAttributedString
            #expect(String(attributed.characters) == text)
            #expect(attributed.runs.allSatisfy { $0.link == nil })
        }

        @Test("String.index(atUTF8Offset:) rejects negative and out-of-range offsets")
        func utf8OffsetIndex() {
            let text = "héllo"
            #expect(text.index(atUTF8Offset: -1) == nil)
            #expect(text.index(atUTF8Offset: Int.min) == nil)
            #expect(text.index(atUTF8Offset: 7) == nil)
            #expect(text.index(atUTF8Offset: 2) == nil) // inside "é"
            #expect(text.index(atUTF8Offset: 0) == text.startIndex)
            #expect(text.index(atUTF8Offset: 6) == text.endIndex)
            #expect(text.index(atUTF8Offset: 3).map { text[$0] } == "l")
        }

        @Test("Offsets inside a character widen to the whole character")
        func midCharacterOffsets() throws {
            // "👨‍👩‍👧‍👧" is one character of 25 bytes; "e\u{301}" one of 3; "🇯🇵" one of 8.
            let family = "👨‍👩‍👧‍👧"
            let text = "a\(family)e\u{301}🇯🇵\r\nz"
            let cases: [(Int, Int, String)] = [
                (1, 5, family), // ends after the first scalar of the ZWJ sequence
                (26, 27, "e\u{301}"), // base letter without its combining mark
                (29, 33, "🇯🇵"), // first regional indicator only
                (37, 38, "\r\n"), // CR without LF
            ]
            for (start, end, expected) in cases {
                let attributed = post(text, [tagFacet(start, end, "t")]).facetsAsAttributedString
                let tagged = attributed.runs.filter { $0.link != nil }
                #expect(tagged.count == 1, "range \(start)..<\(end)")
                let run = try #require(tagged.first)
                #expect(String(attributed[run.range].characters) == expected, "range \(start)..<\(end)")
            }
        }
    }
#endif
