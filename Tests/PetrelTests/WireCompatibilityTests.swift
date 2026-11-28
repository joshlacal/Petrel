import Foundation
@testable import Petrel
import Testing

/// Wire compatibility with already-deployed peers, matching the Rust crate
/// (`rust/petrel-api/tests/wire_compat.rs`, `rust/petrel-core/tests/wire_compat.rs`):
/// records the official TypeScript SDK writes, `enum` values a newer peer adds, and
/// floats in untyped positions.
@Suite("Wire compatibility with deployed peers")
struct WireCompatibilityTests {
    private static let cid = "bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm"

    /// A post as the TypeScript SDK writes it: `$type` on facets, on their features and
    /// indexes, on reply refs, and on embed members. Same fixture as the Rust test.
    private static let tsSDKPost = Data("""
    {"$type":"app.bsky.feed.post","createdAt":"2026-11-24T12:00:00.000Z",\
    "embed":{"$type":"app.bsky.embed.external","external":{"$type":"app.bsky.embed.external#external",\
    "description":"d","title":"t","uri":"https://example.com"}},\
    "facets":[{"$type":"app.bsky.richtext.facet","features":[{"$type":"app.bsky.richtext.facet#link",\
    "uri":"https://example.com"}],"index":{"$type":"app.bsky.richtext.facet#byteSlice","byteEnd":5,"byteStart":0}},\
    {"features":[{"$type":"app.bsky.richtext.facet#tag","tag":"x"}],"index":{"byteEnd":8,"byteStart":6}}],\
    "langs":["en"],"reply":{"parent":{"$type":"com.atproto.repo.strongRef","cid":"\(cid)",\
    "uri":"at://did:plc:abc/app.bsky.feed.post/3k"},"root":{"cid":"\(cid)",\
    "uri":"at://did:plc:abc/app.bsky.feed.post/3j"}},"text":"hello #x"}
    """.utf8)

    private static func jsonObject(_ data: Data) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    // MARK: Nested $type

    @Test("A TypeScript SDK post with tagged nested objects keeps its DAG-CBOR bytes and CID")
    func tsSDKPostKeepsItsCID() throws {
        let raw = try JSONDecoder().decode(ATProtocolValueContainer.self, from: Self.tsSDKPost)
        let rawBlock = try raw.encodedDAGCBOR()
        let post = try JSONDecoder().decode(AppBskyFeedPost.self, from: Self.tsSDKPost)
        #expect(post.facets?.count == 2)

        // Every `$type` present on decode is written back, none is added.
        #expect(try Self.jsonObject(JSONEncoder().encode(post)) == Self.jsonObject(Self.tsSDKPost))
        #expect(try post.encodedDAGCBOR() == rawBlock)
        #expect(try CID.fromDAGCBOR(post.encodedDAGCBOR()) == CID.fromDAGCBOR(rawBlock))

        // Same through DAG-CBOR, the form a repository stores and signs.
        let fromBlock = try #require(CARRepository.decodeRecordCBOR(rawBlock).decoded(AppBskyFeedPost.self))
        #expect(try fromBlock.encodedDAGCBOR() == rawBlock)
    }

    @Test("A nested object writes back the $type it was decoded with, outside extraFields and equality")
    func nestedTypeIsKeptButNotCompared() throws {
        let post = try JSONDecoder().decode(AppBskyFeedPost.self, from: Self.tsSDKPost)
        let facet = try #require(post.facets?.first)
        #expect(facet.extraFields.isEmpty)
        #expect(try Self.jsonObject(JSONEncoder().encode(facet))["$type"] as? String == "app.bsky.richtext.facet")
        let parent = try #require(post.reply?.parent)
        #expect(try Self.jsonObject(JSONEncoder().encode(parent))["$type"] as? String == "com.atproto.repo.strongRef")
        #expect(try Self.jsonObject(JSONEncoder().encode(#require(post.reply?.root)))["$type"] == nil)

        // The tag is wire detail: a tagged and an untagged decode of the same value are equal.
        let untagged = try JSONDecoder().decode(
            ComAtprotoRepoStrongRef.self,
            from: Data(#"{"cid":"\#(Self.cid)","uri":"at://did:plc:abc/app.bsky.feed.post/3k"}"#.utf8)
        )
        #expect(parent == untagged)
        #expect(parent.hashValue == untagged.hashValue)

        guard case let .appBskyRichtextFacetLink(link)? = facet.features.first else {
            Issue.record("the first feature must decode as a link")
            return
        }
        // The union owns the tag and writes it itself.
        #expect(link.extraFields.isEmpty)
    }

    @Test("An untagged nested object stays untagged")
    func untaggedObjectStaysUntagged() throws {
        let json = Data(#"{"features":[],"index":{"byteEnd":1,"byteStart":0}}"#.utf8)
        let facet = try JSONDecoder().decode(AppBskyRichtextFacet.self, from: json)
        #expect(facet.extraFields.isEmpty)
        #expect(try Self.jsonObject(JSONEncoder().encode(facet)) == Self.jsonObject(json))
    }

    @Test("A union member decoded from the wire equals one decoded on its own")
    func unionMemberEqualsStandaloneMember() throws {
        let post = try JSONDecoder().decode(AppBskyFeedPost.self, from: Self.tsSDKPost)
        let standalone = try JSONDecoder().decode(
            AppBskyRichtextFacet.Link.self,
            from: Data(#"{"uri":"https://example.com"}"#.utf8)
        )
        #expect(post.facets?.first?.features.first == .appBskyRichtextFacetLink(standalone))

        // Re-encoding the union writes its tag exactly once.
        let feature = try #require(post.facets?.first?.features.first)
        let reencoded = try Self.jsonObject(JSONEncoder().encode(feature))
        #expect(reencoded["$type"] as? String == "app.bsky.richtext.facet#link")
        #expect(try JSONDecoder().decode(AppBskyRichtextFacet.AppBskyRichtextFacetFeaturesUnion.self, from: JSONEncoder().encode(feature)) == feature)
    }

    // MARK: Open enum strings

    @Test("A lexicon enum value a newer peer added decodes and is written back unchanged")
    func unknownEnumValueRoundTrips() throws {
        typealias Kinds = NetworkBskyJetstreamPlanSnapshot.InputKinds
        let json = Data(#"{"kinds":["commit","futureKind"]}"#.utf8)
        let input = try JSONDecoder().decode(NetworkBskyJetstreamPlanSnapshot.Input.self, from: json)
        #expect(input.kinds == [.value_commit, .unknown("futureKind")])
        #expect(try Self.jsonObject(JSONEncoder().encode(input))["kinds"] as? [String] == ["commit", "futureKind"])

        #expect(Kinds(rawValue: "identity") == .value_identity)
        #expect(Kinds(rawValue: "brandNew")?.rawValue == "brandNew")
        // Equality and hashing follow the wire string.
        #expect(Kinds.unknown("commit") == .value_commit)
        #expect(Set([Kinds.unknown("commit"), .value_commit]).count == 1)
        #expect(try Kinds.unknown("brandNew").toCBORValue() as? String == "brandNew")
    }

    // MARK: Floats

    @Test("A number with an exact integer value reads as an integer")
    func integralFloatReadsAsInteger() throws {
        let json = Data(#"{"a":1.0,"b":-2e2,"c":30.000}"#.utf8)
        for decoder in [JSONDecoder(), ATProtoDecoding.strictJSONDecoder()] {
            let value = try decoder.decode([String: ATProtocolValueContainer].self, from: json)
            #expect(value["a"] == .number(1))
            #expect(value["b"] == .number(-200))
            #expect(value["c"] == .number(30))
        }
    }

    @Test("A fractional number in an untyped position survives a lenient decode")
    func fractionalFloatSurvivesLenientDecode() throws {
        let json = Data(#"{"error":"X","unknownField":{"list":[1,2.5],"score":0.75}}"#.utf8)
        let value = try JSONDecoder().decode(ATProtocolValueContainer.self, from: json)
        guard case let .object(fields) = value, case let .object(inner)? = fields["unknownField"] else {
            Issue.record("expected an object, got \(value)")
            return
        }
        #expect(inner["score"] == .float(0.75))
        #expect(inner["list"] == .array([.number(1), .float(2.5)]))
        #expect(try Self.jsonObject(JSONEncoder().encode(value)) == Self.jsonObject(json))

        // An undeclared field of a typed object is an untyped position too.
        let post = try JSONDecoder().decode(
            AppBskyFeedPost.self,
            from: Data(#"{"$type":"app.bsky.feed.post","text":"t","createdAt":"2026-11-24T12:00:00.000Z","score":0.5}"#.utf8)
        )
        #expect(post.extraFields["score"] == .float(0.5))
    }

    @Test("A fractional number has no DAG-CBOR form")
    func fractionalFloatHasNoDAGCBORForm() throws {
        let value = try JSONDecoder().decode(ATProtocolValueContainer.self, from: Data(#"{"score":0.75}"#.utf8))
        #expect(throws: DAGCBORError.floatingPointNotAllowed) { try value.encodedDAGCBOR() }

        let post = try JSONDecoder().decode(
            AppBskyFeedPost.self,
            from: Data(#"{"$type":"app.bsky.feed.post","text":"t","createdAt":"2026-11-24T12:00:00.000Z","score":0.5}"#.utf8)
        )
        #expect(throws: DAGCBORError.floatingPointNotAllowed) { try post.encodedDAGCBOR() }
    }

    @Test("Strict decoding refuses a fractional number")
    func strictDecodingRefusesFloat() {
        #expect(throws: DecodingError.self) {
            try ATProtoDecoding.strictJSONDecoder().decode(
                ATProtocolValueContainer.self,
                from: Data(#"{"score":0.75}"#.utf8)
            )
        }
    }

    @Test("A fractional number in a typed integer field is still an error")
    func floatInTypedIntegerFieldFails() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                AppBskyRichtextFacet.ByteSlice.self,
                from: Data(#"{"byteStart":1.5,"byteEnd":2}"#.utf8)
            )
        }
        // Through the in-memory container decoder as well.
        let container = ATProtocolValueContainer.object(["byteStart": .float(1.5), "byteEnd": .number(2)])
        #expect(throws: DecodingError.self) {
            try AppBskyRichtextFacet.ByteSlice(from: ATProtocolValueContainerDecoder(value: container))
        }
    }
}
