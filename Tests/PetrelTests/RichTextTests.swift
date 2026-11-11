import Foundation
@testable import Petrel
import Testing

// Ports of `packages/api/tests/rich-text.test.ts` and
// `rich-text-sanitization.test.ts` from the reference implementation, plus
// tests for behaviour the reference does not cover (untrusted offsets, link
// shortening, the builder).

private let family = "👨‍👩‍👧‍👧"

/// A facet with no features, standing in for the reference tests' `{ $type: '' }`.
private func facet(_ byteStart: Int, _ byteEnd: Int) -> AppBskyRichtextFacet {
    AppBskyRichtextFacet(
        index: AppBskyRichtextFacet.ByteSlice(byteStart: byteStart, byteEnd: byteEnd),
        features: []
    )
}

private func facetText(of facet: AppBskyRichtextFacet?, in richText: RichText) -> String {
    guard let facet else { return "" }
    return richText.slice(byteStart: facet.index.byteStart, byteEnd: facet.index.byteEnd)
}

private func range(_ facet: AppBskyRichtextFacet?) -> [Int]? {
    facet.map { [$0.index.byteStart, $0.index.byteEnd] }
}

@Suite("RichText")
struct RichTextTests {
    @Test("converts entities to facets correctly")
    func entitiesToFacets() throws {
        let richText = RichText(text: "test", entities: [
            .init(index: .init(start: 0, end: 1), type: "link", value: "https://example.com"),
            .init(index: .init(start: 1, end: 2), type: "mention", value: "did:plc:1234"),
            .init(index: .init(start: 2, end: 3), type: "other", value: "willbedropped"),
        ])
        #expect(richText.facets.count == 2)
        #expect(range(richText.facets[0]) == [0, 1])
        #expect(richText.facets[0].features == [
            .appBskyRichtextFacetLink(.init(uri: URI(uriString: "https://example.com"))),
        ])
        #expect(range(richText.facets[1]) == [1, 2])
        #expect(try richText.facets[1].features == [
            .appBskyRichtextFacetMention(.init(did: DID(didString: "did:plc:1234"))),
        ])
    }

    @Test("converts entity utf16 indices to facet utf8 indices")
    func entityIndicesAreConverted() {
        let richText = RichText(text: family + family + family, entities: [
            .init(index: .init(start: 0, end: 11), type: "link", value: "https://example.com"),
            .init(index: .init(start: 11, end: 22), type: "mention", value: "did:plc:1234"),
            .init(index: .init(start: 22, end: 33), type: "other", value: "willbedropped"),
        ])
        #expect(richText.facets.map { range($0) } == [[0, 25], [25, 50]])
    }

    @Test("facets take precedence over entities")
    func facetsWinOverEntities() {
        let richText = RichText(
            text: "test",
            facets: [facet(0, 4)],
            entities: [.init(index: .init(start: 0, end: 1), type: "link", value: "https://example.com")]
        )
        #expect(richText.facets == [facet(0, 4)])
    }

    @Test("calculates bytelength and grapheme length correctly")
    func lengths() {
        #expect(RichText(text: "Hello!").utf8Length == 6)
        #expect(RichText(text: "Hello!").graphemeLength == 6)
        #expect(RichText(text: family).utf8Length == 25)
        #expect(RichText(text: family).graphemeLength == 1)
        #expect(RichText(text: family + "🔥 good!✅").utf8Length == 38)
        #expect(RichText(text: family + "🔥 good!✅").graphemeLength == 9)
    }

    @Test("post length limits are 300 graphemes and 3000 bytes")
    func postLimits() {
        #expect(!RichText(text: String(repeating: "a", count: 300)).exceedsPostLimits)
        #expect(RichText(text: String(repeating: "a", count: 301)).exceedsPostLimits)
        // 300 graphemes, but 7500 bytes.
        #expect(RichText(text: String(repeating: family, count: 300)).exceedsPostLimits)
        #expect(!RichText(text: String(repeating: family, count: 120)).exceedsPostLimits)
    }

    @Test("recordFacets is nil without facets")
    func recordFacets() {
        #expect(RichText(text: "plain").recordFacets == nil)
        #expect(RichText(text: "plain", facets: [facet(0, 5)]).recordFacets == [facet(0, 5)])
    }
}

@Suite("RichText insert")
struct RichTextInsertTests {
    private let input = RichText(text: "hello world", facets: [facet(2, 7)])

    @Test("correctly adjusts facets (scenario A - before)")
    func before() {
        var output = input
        output.insert("test", at: 0)
        #expect(output.text == "testhello world")
        #expect(range(output.facets.first) == [6, 11])
        #expect(facetText(of: output.facets.first, in: output) == "llo w")
    }

    @Test("correctly adjusts facets (scenario B - inner)")
    func inner() {
        var output = input
        output.insert("test", at: 4)
        #expect(output.text == "helltesto world")
        #expect(range(output.facets.first) == [2, 11])
        #expect(facetText(of: output.facets.first, in: output) == "lltesto w")
    }

    @Test("correctly adjusts facets (scenario C - after)")
    func after() {
        var output = input
        output.insert("test", at: 8)
        #expect(output.text == "hello wotestrld")
        #expect(range(output.facets.first) == [2, 7])
        #expect(facetText(of: output.facets.first, in: output) == "llo w")
    }

    @Test("counts inserted text in UTF-8 bytes")
    func insertedLengthIsBytes() {
        // The reference adds the UTF-16 length here, which leaves the facet 14
        // bytes short of the text it annotated. Petrel shifts by bytes.
        var output = input
        output.insert(family, at: 0)
        #expect(range(output.facets.first) == [27, 32])
        #expect(facetText(of: output.facets.first, in: output) == "llo w")
    }

    @Test("clamps an out-of-range insertion point")
    func clampsIndex() {
        var output = input
        output.insert("!", at: 999)
        #expect(output.text == "hello world!")
        output.insert(">", at: -5)
        #expect(output.text == ">hello world!")
        #expect(facetText(of: output.facets.first, in: output) == "llo w")
    }
}

@Suite("RichText insert w/fat unicode")
struct RichTextInsertFatUnicodeTests {
    private let input = RichText(
        text: "one\(family) two\(family) three\(family)",
        facets: [facet(0, 28), facet(29, 57), facet(58, 88)]
    )

    private func texts(_ richText: RichText) -> [String] {
        richText.facets.map { facetText(of: $0, in: richText) }
    }

    @Test("correctly adjusts facets (scenario A - before)")
    func before() {
        var output = input
        output.insert("test", at: 0)
        #expect(output.text == "testone\(family) two\(family) three\(family)")
        #expect(texts(output) == ["one\(family)", "two\(family)", "three\(family)"])
    }

    @Test("correctly adjusts facets (scenario B - inner)")
    func inner() {
        var output = input
        output.insert("test", at: 3)
        #expect(output.text == "onetest\(family) two\(family) three\(family)")
        #expect(texts(output) == ["onetest\(family)", "two\(family)", "three\(family)"])
    }

    @Test("correctly adjusts facets (scenario C - after)")
    func after() {
        var output = input
        output.insert("test", at: 28)
        #expect(output.text == "one\(family)test two\(family) three\(family)")
        #expect(texts(output) == ["one\(family)", "two\(family)", "three\(family)"])
    }
}

@Suite("RichText delete")
struct RichTextDeleteTests {
    private let input = RichText(text: "hello world", facets: [facet(2, 7)])

    private func deleting(_ start: Int, _ end: Int) -> RichText {
        var output = input
        output.delete(byteStart: start, byteEnd: end)
        return output
    }

    @Test("correctly adjusts facets (scenario A - entirely outer)")
    func entirelyOuter() {
        let output = deleting(0, 9)
        #expect(output.text == "ld")
        #expect(output.facets.isEmpty)
    }

    @Test("correctly adjusts facets (scenario B - entirely after)")
    func entirelyAfter() {
        let output = deleting(7, 11)
        #expect(output.text == "hello w")
        #expect(range(output.facets.first) == [2, 7])
        #expect(facetText(of: output.facets.first, in: output) == "llo w")
    }

    @Test("correctly adjusts facets (scenario C - partially after)")
    func partiallyAfter() {
        let output = deleting(4, 11)
        #expect(output.text == "hell")
        #expect(range(output.facets.first) == [2, 4])
        #expect(facetText(of: output.facets.first, in: output) == "ll")
    }

    @Test("correctly adjusts facets (scenario D - entirely inner)")
    func entirelyInner() {
        let output = deleting(3, 5)
        #expect(output.text == "hel world")
        #expect(range(output.facets.first) == [2, 5])
        #expect(facetText(of: output.facets.first, in: output) == "l w")
    }

    @Test("correctly adjusts facets (scenario E - partially before)")
    func partiallyBefore() {
        let output = deleting(1, 5)
        #expect(output.text == "h world")
        #expect(range(output.facets.first) == [1, 3])
        #expect(facetText(of: output.facets.first, in: output) == " w")
    }

    @Test("correctly adjusts facets (scenario F - entirely before)")
    func entirelyBefore() {
        let output = deleting(0, 2)
        #expect(output.text == "llo world")
        #expect(range(output.facets.first) == [0, 5])
        #expect(facetText(of: output.facets.first, in: output) == "llo w")
    }

    @Test("ignores empty, inverted and out-of-range ranges")
    func degenerateRanges() {
        #expect(deleting(5, 5) == input)
        #expect(deleting(8, 3) == input)
        #expect(deleting(50, 60) == input)
        let clamped = deleting(-10, 2)
        #expect(clamped.text == "llo world")
        #expect(range(clamped.facets.first) == [0, 5])
    }
}

@Suite("RichText delete w/fat unicode")
struct RichTextDeleteFatUnicodeTests {
    private let input = RichText(
        text: "one\(family) two\(family) three\(family)",
        facets: [facet(29, 57)]
    )

    private func deleting(_ start: Int, _ end: Int) -> RichText {
        var output = input
        output.delete(byteStart: start, byteEnd: end)
        return output
    }

    @Test("correctly adjusts facets (scenario A - entirely outer)")
    func entirelyOuter() {
        let output = deleting(28, 58)
        #expect(output.text == "one\(family)three\(family)")
        #expect(output.facets.isEmpty)
    }

    @Test("correctly adjusts facets (scenario B - entirely after)")
    func entirelyAfter() {
        let output = deleting(57, 88)
        #expect(output.text == "one\(family) two\(family)")
        #expect(range(output.facets.first) == [29, 57])
        #expect(facetText(of: output.facets.first, in: output) == "two\(family)")
    }

    @Test("correctly adjusts facets (scenario C - partially after)")
    func partiallyAfter() {
        let output = deleting(31, 88)
        #expect(output.text == "one\(family) tw")
        #expect(range(output.facets.first) == [29, 31])
        #expect(facetText(of: output.facets.first, in: output) == "tw")
    }

    @Test("correctly adjusts facets (scenario D - entirely inner)")
    func entirelyInner() {
        let output = deleting(30, 32)
        #expect(output.text == "one\(family) t\(family) three\(family)")
        #expect(range(output.facets.first) == [29, 55])
        #expect(facetText(of: output.facets.first, in: output) == "t\(family)")
    }

    @Test("correctly adjusts facets (scenario E - partially before)")
    func partiallyBefore() {
        let output = deleting(28, 31)
        #expect(output.text == "one\(family)o\(family) three\(family)")
        #expect(range(output.facets.first) == [28, 54])
        #expect(facetText(of: output.facets.first, in: output) == "o\(family)")
    }

    @Test("correctly adjusts facets (scenario F - entirely before)")
    func entirelyBefore() {
        let output = deleting(0, 2)
        #expect(output.text == "e\(family) two\(family) three\(family)")
        #expect(range(output.facets.first) == [27, 55])
        #expect(facetText(of: output.facets.first, in: output) == "two\(family)")
    }
}

@Suite("RichText segments")
struct RichTextSegmentsTests {
    private func plain(_ text: String) -> RichTextSegment {
        RichTextSegment(text: text)
    }

    private func faceted(_ text: String, _ start: Int, _ end: Int) -> RichTextSegment {
        RichTextSegment(text: text, facet: facet(start, end))
    }

    @Test("produces an empty output for an empty input")
    func emptyInput() {
        #expect(RichText(text: "").segments() == [plain("")])
    }

    @Test("produces a single segment when no facets are present")
    func noFacets() {
        #expect(RichText(text: "hello").segments() == [plain("hello")])
    }

    @Test("produces 3 segments with 1 entity in the middle")
    func middle() {
        let input = RichText(text: "one two three", facets: [facet(4, 7)])
        #expect(input.segments() == [plain("one "), faceted("two", 4, 7), plain(" three")])
    }

    @Test("produces 2 segments with 1 entity in the byteStart")
    func atStart() {
        let input = RichText(text: "one two three", facets: [facet(0, 7)])
        #expect(input.segments() == [faceted("one two", 0, 7), plain(" three")])
    }

    @Test("produces 2 segments with 1 entity in the end")
    func atEnd() {
        let input = RichText(text: "one two three", facets: [facet(4, 13)])
        #expect(input.segments() == [plain("one "), faceted("two three", 4, 13)])
    }

    @Test("produces 1 segments with 1 entity around the entire string")
    func whole() {
        let input = RichText(text: "one two three", facets: [facet(0, 13)])
        #expect(input.segments() == [faceted("one two three", 0, 13)])
    }

    @Test("produces 5 segments with 3 facets covering each word")
    func eachWord() {
        let input = RichText(text: "one two three", facets: [facet(0, 3), facet(4, 7), facet(8, 13)])
        #expect(input.segments() == [
            faceted("one", 0, 3), plain(" "), faceted("two", 4, 7), plain(" "), faceted("three", 8, 13),
        ])
    }

    @Test("uses utf8 indices")
    func utf8Indices() {
        let input = RichText(
            text: "one\(family) two\(family) three\(family)",
            facets: [facet(0, 28), facet(29, 57), facet(58, 88)]
        )
        #expect(input.segments() == [
            faceted("one\(family)", 0, 28), plain(" "),
            faceted("two\(family)", 29, 57), plain(" "),
            faceted("three\(family)", 58, 88),
        ])
    }

    @Test("correctly identifies mentions and links")
    func mentionsAndLinks() throws {
        let unknown = try JSONDecoder().decode(
            AppBskyRichtextFacet.self,
            from: Data(#"{"index":{"byteStart":8,"byteEnd":13},"features":[{"$type":"other"}]}"#.utf8)
        )
        let input = try RichText(text: "one two three", facets: [
            AppBskyRichtextFacet(
                index: .init(byteStart: 0, byteEnd: 3),
                features: [.appBskyRichtextFacetMention(.init(did: DID(didString: "did:plc:123")))]
            ),
            AppBskyRichtextFacet(
                index: .init(byteStart: 4, byteEnd: 7),
                features: [.appBskyRichtextFacetLink(.init(uri: URI(uriString: "https://example.com")))]
            ),
            unknown,
        ])
        let segments = input.segments()
        #expect(segments.map(\.isLink) == [false, false, true, false, false])
        #expect(segments.map(\.isMention) == [true, false, false, false, false])
        #expect(segments.map(\.isTag) == [false, false, false, false, false])
        #expect(segments[4].facet == unknown)
    }

    @Test("skips facets that incorrectly overlap (left edge)")
    func overlapLeft() {
        let input = RichText(text: "one two three", facets: [facet(0, 3), facet(2, 9), facet(8, 13)])
        #expect(input.segments() == [faceted("one", 0, 3), plain(" two "), faceted("three", 8, 13)])
    }

    @Test("skips facets that incorrectly overlap (right edge)")
    func overlapRight() {
        let input = RichText(text: "one two three", facets: [facet(0, 3), facet(4, 9), facet(8, 13)])
        #expect(input.segments() == [faceted("one", 0, 3), plain(" "), faceted("two t", 4, 9), plain("hree")])
    }

    @Test("doesn't duplicate text when negative-length facets are present")
    func negativeLengthFacets() {
        let input = RichText(text: "hello world", facets: [
            facet(6, 0), // invalid negative-length
            facet(6, 11), // valid normal facet
            facet(0, 0), // valid zero-length
        ])
        #expect(input.segments().map(\.text).joined() == "hello world")
        // The invalid one is removed.
        #expect(input.facets.count == 2)
    }

    @Test("a facet covering only whitespace yields a plain segment")
    func whitespaceOnlyFacet() {
        let input = RichText(text: "one   three", facets: [facet(3, 6)])
        #expect(input.segments() == [plain("one"), plain("   "), plain("three")])
    }
}

@Suite("RichText sanitize: cleanNewlines")
struct RichTextSanitizeTests {
    private func cleaned(_ text: String) -> String {
        RichText(text: text).sanitized(cleanNewlines: true).text
    }

    @Test("removes more than two consecutive new lines")
    func consecutiveNewlines() {
        #expect(
            cleaned("test\n\n\n\n\ntest\n\n\n\n\n\n\ntest\n\n\n\n\n\n\ntest\n\n\n\n\n\n\ntest")
                == "test\n\ntest\n\ntest\n\ntest\n\ntest"
        )
    }

    @Test("removes more than two consecutive new lines w/fat unicode")
    func consecutiveNewlinesFatUnicode() {
        #expect(
            cleaned("test\(family)\n\n\n\n\n\(family)test\n\n\n\n\n\n\ntest\(family)\n\n\n\n\n\n\ntest\n\n\n\n\n\n\n\(family)test")
                == "test\(family)\n\n\(family)test\n\ntest\(family)\n\ntest\n\n\(family)test"
        )
    }

    @Test("removes more than two consecutive new lines with spaces")
    func newlinesWithSpaces() {
        #expect(
            cleaned("test\n\n\n\n\ntest\n \n \n \n \n\n\ntest\n\n\n\n\n\n\ntest\n\n\n\n\n  \n\ntest")
                == "test\n\ntest\n\ntest\n\ntest\n\ntest"
        )
    }

    @Test("returns original string if there are no consecutive new lines")
    func noConsecutiveNewlines() {
        #expect(cleaned("test\n\ntest\n\ntest\n\ntest\n\ntest") == "test\n\ntest\n\ntest\n\ntest\n\ntest")
    }

    @Test("returns original string if there are no new lines")
    func noNewlines() {
        #expect(cleaned("test test          test test test") == "test test          test test test")
    }

    @Test("returns empty string if input is empty")
    func emptyInput() {
        #expect(cleaned("") == "")
    }

    @Test("works with different types of new line characters")
    func newlineKinds() {
        #expect(
            cleaned("test\r\ntest\n\rtest\rtest\n\n\n\ntest\n\r \n \n \n \n\n\ntest")
                == "test\r\ntest\n\rtest\rtest\n\ntest\n\ntest"
        )
    }

    @Test(
        "removes more than two consecutive new lines with zero-width characters",
        arguments: ["\u{200B}", "\u{200C}", "\u{200D}", "\u{00AD}", "\u{2060}"]
    )
    func zeroWidthCharacters(_ invisible: String) {
        let pair = invisible + invisible
        #expect(
            cleaned("test\n\n\n\n\ntest\n\(pair)\n\n\n\ntest\n \(pair) \n\n\n\ntest\n\n\n\n\n\n\ntest")
                == "test\n\ntest\n\ntest\n\ntest\n\ntest"
        )
    }

    @Test("cleanNewlines can be requested at creation")
    func cleanOnInit() {
        #expect(RichText(text: "a\n\n\n\nb", cleanNewlines: true).text == "a\n\nb")
    }

    @Test("preserves entities as expected")
    func preservesFacets() {
        let input = RichText(
            text: "test\n\n\n\n\ntest\n\n\n\n\n\n\ntest\n\n\n\n\n\n\ntest\n\n\n\n\n\n\ntest",
            facets: [facet(0, 13), facet(13, 24), facet(9, 15), facet(4, 9)]
        )
        // Facets are sorted by start on creation.
        #expect(input.facets.map { facetText(of: $0, in: input) } == [
            "test\n\n\n\n\ntest", "\n\n\n\n\n", "test\n\n", "\n\n\n\n\n\n\ntest",
        ])

        let output = input.sanitized(cleanNewlines: true)
        #expect(output.text == "test\n\ntest\n\ntest\n\ntest\n\ntest")
        #expect(output.facets.map { facetText(of: $0, in: output) } == ["test\n\ntest", "test", "test"])
    }

    @Test("preserves entities as expected w/fat unicode")
    func preservesFacetsFatUnicode() {
        let unit = "\(family)test\n\n\n\n\n"
        let string = String(repeating: unit, count: 7)
        var cursor = string.startIndex
        func makeFacet(_ match: String) -> AppBskyRichtextFacet {
            guard let found = string.range(of: match, range: cursor ..< string.endIndex) else {
                return facet(0, 0)
            }
            cursor = found.upperBound
            let byteStart = string[..<found.lowerBound].utf8.count
            return facet(byteStart, byteStart + match.utf8.count)
        }
        let input = RichText(text: string, facets: [
            makeFacet("\(family)test\n\n\n\n\n\(family)test"),
            makeFacet("\n\n\n\n\n\(family)test"),
            makeFacet("\(family)test\n\n"),
            makeFacet("\n\n"),
        ])
        #expect(input.facets.map { facetText(of: $0, in: input) } == [
            "\(family)test\n\n\n\n\n\(family)test", "\n\n\n\n\n\(family)test", "\(family)test\n\n", "\n\n",
        ])

        let output = input.sanitized(cleanNewlines: true)
        #expect(output.text == String(repeating: "\(family)test\n\n", count: 7))
        #expect(output.facets.map { facetText(of: $0, in: output) } == [
            "\(family)test\n\n\(family)test", "\(family)test", "\(family)test",
        ])
    }
}

@Suite("RichText builder and link shortening")
struct RichTextBuilderTests {
    @Test("append builds text and facets together")
    func builder() throws {
        var richText = RichText(text: "")
        richText.append("Thanks ")
        try richText.appendMention("@alice.example", did: DID(didString: "did:plc:alice"))
        richText.append(" – see ")
        richText.appendLink("the spec", uri: URI(uriString: "https://atproto.com/specs/label"))
        richText.append(" ")
        richText.appendTag("#日本語", tag: "日本語")

        #expect(richText.text == "Thanks @alice.example – see the spec #日本語")
        let segments = richText.segments()
        #expect(segments.map(\.text) == ["Thanks ", "@alice.example", " – see ", "the spec", " ", "#日本語"])
        #expect(segments[1].mention?.did.didString() == "did:plc:alice")
        #expect(segments[3].link?.uri.uriString() == "https://atproto.com/specs/label")
        #expect(segments[5].tag?.tag == "日本語")
    }

    @Test("shortenedURL drops the scheme and trims long paths")
    func shortenedURL() {
        #expect(RichText.shortenedURL("https://bsky.app") == "bsky.app")
        #expect(RichText.shortenedURL("https://bsky.app/") == "bsky.app")
        #expect(RichText.shortenedURL("https://bsky.app/profile") == "bsky.app/profile")
        #expect(RichText.shortenedURL("https://Example.com/a/very/long/path?q=1#frag") == "example.com/a/very/long/...")
        #expect(RichText.shortenedURL("http://localhost:2583/xrpc/com.atproto.server.describeServer") == "localhost:2583/xrpc/com.atp...")
        // Not an http(s) URL: unchanged.
        #expect(RichText.shortenedURL("bsky.app/profile/someone/post/abc") == "bsky.app/profile/someone/post/abc")
        #expect(RichText.shortenedURL("mailto:someone@example.com") == "mailto:someone@example.com")
        #expect(RichText.shortenedURL("not a url") == "not a url")
    }

    @Test("shorteningLinks rewrites the visible text and keeps every facet on its text")
    func shorteningLinks() {
        var richText = RichText(
            text: "\(family) read https://example.com/a/very/long/path/to/an/article?utm=1 and #tag then https://bsky.app"
        )
        richText.detectFacetsWithoutResolution()
        let shortened = richText.shorteningLinks()

        #expect(shortened.text == "\(family) read example.com/a/very/long/... and #tag then bsky.app")
        #expect(shortened.facets.map { facetText(of: $0, in: shortened) } == [
            "example.com/a/very/long/...", "#tag", "bsky.app",
        ])
        // The link targets are untouched.
        #expect(shortened.segments().compactMap { $0.link?.uri.uriString() } == [
            "https://example.com/a/very/long/path/to/an/article?utm=1", "https://bsky.app",
        ])
    }
}

@Suite("RichText with untrusted offsets")
struct RichTextUntrustedOffsetTests {
    @Test("slices clamp and decode leniently")
    func sliceClamps() {
        let richText = RichText(text: "héllo")
        #expect(richText.slice(byteStart: -4, byteEnd: 2) == "h\u{FFFD}")
        #expect(richText.slice(byteStart: 0, byteEnd: 99) == "héllo")
        #expect(richText.slice(byteStart: 4, byteEnd: 1) == "")
        #expect(richText.slice(byteStart: 50, byteEnd: 60) == "")
    }

    @Test(
        "malformed facets never trap and never lose or duplicate text",
        arguments: [
            [(-5, 3)], [(-9, -2)], [(3, 400)], [(400, 500)], [(Int.min, Int.max)], [(Int.max, Int.max)],
            [(2, 2)], [(0, 1), (0, 1)], [(0, 6), (2, 4), (3, 9)], [(1, 2)], [(9, 4), (-1, -1), (5, 5)],
        ] as [[(Int, Int)]]
    )
    func malformedFacets(_ ranges: [(Int, Int)]) {
        let text = "h\(family)é 日本語 end"
        let richText = RichText(text: text, facets: ranges.map { facet($0.0, $0.1) })
        // Lenient decoding may turn a split character into U+FFFD; apart from
        // that, the segments never contain more than the original text.
        let joined = richText.segments().map(\.text).joined().replacingOccurrences(of: "\u{FFFD}", with: "")
        #expect(joined.utf8.count <= text.utf8.count)

        var edited = richText
        edited.insert("x", at: 3)
        edited.delete(byteStart: 1, byteEnd: 6)
        #expect(edited.facets.allSatisfy { $0.index.byteStart <= $0.index.byteEnd })
        _ = edited.segments()
        _ = edited.shorteningLinks()
        _ = edited.sanitized(cleanNewlines: true)
    }

    @Test("fuzz: random text, facets and edits never trap and keep invariants")
    func fuzz() {
        var generator = SplitMix64(seed: 0x5EED_CAFE)
        let alphabet = ["a", "é", "日", "🦋", family, " ", "\n", "#", "@", ".", "\u{200B}", "🇯🇵", "e\u{301}", "\r\n"]
        for _ in 0 ..< 3000 {
            let text = (0 ..< Int(generator.next() % 14)).map { _ in
                alphabet[Int(generator.next() % UInt64(alphabet.count))]
            }.joined()
            let length = text.utf8.count
            func offset() -> Int {
                switch generator.next() % 8 {
                case 0: return -Int(generator.next() % 50)
                case 1: return length + Int(generator.next() % 50)
                case 2: return generator.next() % 2 == 0 ? Int.max : Int.min
                default: return length == 0 ? 0 : Int(generator.next() % UInt64(length + 1))
                }
            }
            let facets = (0 ..< Int(generator.next() % 5)).map { _ in facet(offset(), offset()) }
            var richText = RichText(text: text, facets: facets)

            // Facets are sorted and never inverted.
            #expect(richText.facets.allSatisfy { $0.index.byteStart <= $0.index.byteEnd })
            #expect(richText.facets.map(\.index.byteStart) == richText.facets.map(\.index.byteStart).sorted())

            // In-range, character-aligned facets reproduce the text exactly.
            let boundaries = Set(text.indices.map { text.utf8.distance(from: text.startIndex, to: $0) } + [length])
            let aligned = richText.facets.allSatisfy {
                boundaries.contains($0.index.byteStart) && boundaries.contains($0.index.byteEnd)
            }
            let segments = richText.segments()
            if aligned {
                #expect(segments.map(\.text).joined() == text)
            }
            #expect(segments.allSatisfy { $0.facet == nil || !JSText.isBlank($0.text) })

            richText.insert("ö", at: offset())
            richText.delete(byteStart: offset(), byteEnd: offset())
            #expect(richText.facets.allSatisfy { $0.index.byteStart <= $0.index.byteEnd })
            _ = richText.segments()
            _ = richText.sanitized(cleanNewlines: true)
            _ = richText.shorteningLinks()
            _ = RichText.detect(in: richText.text)
        }
    }
}

/// Deterministic generator so the fuzz test is reproducible.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
