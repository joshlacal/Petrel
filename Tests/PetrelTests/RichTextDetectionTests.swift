import Foundation
@testable import Petrel
import Testing

// Facet detection, checked against the reference suite
// `packages/api/tests/rich-text-detection.test.ts` (see Vectors/richtext/README.md).

private struct DetectionVectors: Decodable {
    struct SegmentCase: Decodable {
        let text: String
        let segments: [[String]]
    }

    struct TagCase: Decodable {
        struct Index: Decodable, Equatable {
            let byteStart: Int
            let byteEnd: Int
        }

        let text: String
        let tags: [String]
        let indices: [Index]
    }

    let segments: [SegmentCase]
    let tags: [TagCase]
    let cashtags: [TagCase]

    static func load() throws -> DetectionVectors {
        guard let url = Bundle.module.url(
            forResource: "detection", withExtension: "json", subdirectory: "Vectors/richtext"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(DetectionVectors.self, from: Data(contentsOf: url))
    }
}

/// The reference test's resolver: every handle `h` resolves to `did:fake:h`.
private let fakeResolver: @Sendable (String) async throws -> DID? = { handle in
    try DID(didString: "did:fake:\(handle)")
}

@Suite("RichText facet detection (reference vectors)")
struct RichTextDetectionTests {
    @Test("Every reference input splits into the reference segments")
    func segmentsMatchReference() async throws {
        let vectors = try DetectionVectors.load()
        #expect(vectors.segments.count == 40)
        for testCase in vectors.segments {
            var richText = RichText(text: testCase.text)
            await richText.detectFacets(resolveMention: fakeResolver)
            let actual = richText.segments().map { segment -> [String] in
                guard segment.facet != nil else { return [segment.text] }
                if let mention = segment.mention { return [segment.text, mention.did.didString()] }
                if let link = segment.link { return [segment.text, link.uri.uriString()] }
                return [segment.text, ""]
            }
            #expect(actual == testCase.segments, "input: \(testCase.text.debugDescription)")
        }
    }

    @Test("Every reference tag input yields the reference tags and byte ranges")
    func tagsMatchReference() async throws {
        let vectors = try DetectionVectors.load()
        #expect(vectors.tags.count == 39)
        for testCase in vectors.tags {
            var richText = RichText(text: testCase.text)
            await richText.detectFacets(resolveMention: fakeResolver)

            var tags: [String] = []
            var indices: [DetectionVectors.TagCase.Index] = []
            for segment in richText.segments() {
                guard let facet = segment.facet else { continue }
                if let tag = segment.tag { tags.append(tag.tag) }
                indices.append(.init(byteStart: facet.index.byteStart, byteEnd: facet.index.byteEnd))
            }
            #expect(tags == testCase.tags, "input: \(testCase.text.debugDescription)")
            #expect(indices == testCase.indices, "input: \(testCase.text.debugDescription)")
        }
    }

    @Test("Every reference cashtag input yields the reference tags and byte ranges")
    func cashtagsMatchReference() throws {
        let vectors = try DetectionVectors.load()
        #expect(vectors.cashtags.count == 18)
        for testCase in vectors.cashtags {
            var richText = RichText(text: testCase.text)
            richText.detectFacetsWithoutResolution()

            var tags: [String] = []
            var indices: [DetectionVectors.TagCase.Index] = []
            for segment in richText.segments() {
                guard let facet = segment.facet, let tag = segment.tag, tag.tag.hasPrefix("$") else { continue }
                tags.append(tag.tag)
                indices.append(.init(byteStart: facet.index.byteStart, byteEnd: facet.index.byteEnd))
            }
            #expect(tags == testCase.tags, "input: \(testCase.text.debugDescription)")
            #expect(indices == testCase.indices, "input: \(testCase.text.debugDescription)")
        }
    }

    @Test("Byte ranges select exactly the annotated text")
    func byteRangesSelectAnnotatedText() async throws {
        let text = "こんにちは @alice.test を見て https://例.example.com/パス #東京 $btc"
        var richText = RichText(text: text)
        await richText.detectFacets(resolveMention: fakeResolver)

        let annotated = richText.facets.map {
            richText.slice(byteStart: $0.index.byteStart, byteEnd: $0.index.byteEnd)
        }
        #expect(annotated == ["@alice.test", "https://例.example.com/パス", "#東京", "$btc"])
        let tags = richText.segments().compactMap(\.tag?.tag)
        #expect(tags == ["東京", "$BTC"])
    }

    @Test("Unresolved mentions stay plain text and each handle is resolved once")
    func unresolvedMentionsAreDropped() async throws {
        let calls = CallLog()
        var richText = RichText(text: "@known.test @unknown.test @known.test @broken.test")
        await richText.detectFacets { handle in
            await calls.record(handle)
            switch handle {
            case "known.test": return try DID(didString: "did:plc:known")
            case "broken.test": throw CocoaError(.fileNoSuchFile)
            default: return nil
            }
        }
        #expect(richText.facets.count == 2)
        #expect(richText.segments().compactMap { $0.mention?.did.didString() } == ["did:plc:known", "did:plc:known"])
        #expect(await calls.handles.sorted() == ["broken.test", "known.test", "unknown.test"])
    }

    @Test("Detection without resolution yields links and tags but no mentions")
    func detectionWithoutResolution() {
        var richText = RichText(text: "@alice.test wrote at bsky.app about #atproto")
        richText.detectFacetsWithoutResolution()
        #expect(richText.segments().compactMap { $0.link?.uri.uriString() } == ["https://bsky.app"])
        #expect(richText.segments().compactMap(\.tag?.tag) == ["atproto"])
        #expect(richText.segments().allSatisfy { !$0.isMention })

        let kinds = RichText.detect(in: richText.text).map(\.kind)
        #expect(kinds == [.mention(handle: "alice.test"), .link(uri: "https://bsky.app"), .tag("atproto")])
    }

    @Test("Bare domains need a real TLD and uppercase schemes are not links")
    func domainRules() {
        func links(_ text: String) -> [String] {
            RichText.detect(in: text).compactMap {
                if case let .link(uri) = $0.kind { return uri }
                return nil
            }
        }
        #expect(links("see example.museum now") == ["https://example.museum"])
        #expect(links("see example.notatld now") == [])
        #expect(links("photo.jpg and archive.tar.gz") == [])
        // As in the reference: the scheme check is case-sensitive, so this is
        // neither an `http` link nor a bare domain.
        #expect(links("HTTPS://EXAMPLE.COM") == [])
        #expect(links("EXAMPLE.COM") == [])
        // A punycode TLD is a real TLD.
        #expect(RichText.detect(in: "@name.xn--p1ai").map(\.kind) == [.mention(handle: "name.xn--p1ai")])
    }

    @Test("The TLD table is the IANA list")
    func tldTable() {
        #expect(TopLevelDomains.all.count > 1400)
        for tld in ["com", "org", "net", "social", "app", "blue", "xn--p1ai"] {
            #expect(TopLevelDomains.all.contains(tld))
        }
        #expect(!TopLevelDomains.all.contains("jpg"))
        #expect(!TopLevelDomains.all.contains("test"))
        #expect(TopLevelDomains.all.allSatisfy { $0 == $0.lowercased() && !$0.isEmpty })
    }
}

private actor CallLog {
    private(set) var handles: [String] = []

    func record(_ handle: String) {
        handles.append(handle)
    }
}
