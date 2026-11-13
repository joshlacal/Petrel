import Foundation
@testable import Petrel
import Testing

/// What generated types write back after reading data they do not fully understand:
/// a malformed optional value (re-audit r-5) and union variants they do not know, read
/// from DAG-CBOR as a repository record is (v-4).
@Suite("Lenient decoding keeps what it cannot read")
struct LenientDecodingRoundTripTests {
    private static func jsonObject(_ data: Data) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    private static func jsonObject(_ value: some Encodable) throws -> NSDictionary {
        try jsonObject(JSONEncoder().encode(value))
    }

    private static let malformedPost = Data("""
    {
      "$type": "app.bsky.feed.post",
      "text": "hello",
      "createdAt": "2026-07-15T12:00:00.000Z",
      "langs": ["en"],
      "tags": "not-an-array"
    }
    """.utf8)

    @Test("A malformed optional field reads as nil but is written back unchanged")
    func malformedOptionalFieldSurvivesReEncoding() throws {
        let post = try JSONDecoder().decode(AppBskyFeedPost.self, from: Self.malformedPost)

        #expect(post.tags == nil)
        #expect(post.langs?.count == 1)
        #expect(post.extraFields["tags"] == .string("not-an-array"))
        #expect(try Self.jsonObject(post) == Self.jsonObject(Self.malformedPost))

        let untyped = try JSONDecoder().decode([String: ATProtocolValueContainer].self, from: Self.malformedPost)
        #expect(try post.encodedDAGCBOR() == ATProtocolValueContainer.object(untyped).encodedDAGCBOR())
    }

    @Test("A value set on the property wins over a kept raw value of the same field")
    func propertyWinsOverKeptRawValue() throws {
        let read = try JSONDecoder().decode(AppBskyFeedPost.self, from: Self.malformedPost)
        let edited = AppBskyFeedPost(
            text: read.text,
            langs: read.langs,
            tags: ["fixed"],
            createdAt: read.createdAt,
            extraFields: read.extraFields
        )

        let json = try Self.jsonObject(edited)
        #expect(json["tags"] as? [String] == ["fixed"])
        let reread = try JSONDecoder().decode(AppBskyFeedPost.self, from: JSONEncoder().encode(edited))
        #expect(reread.tags == ["fixed"])

        let cbor = try CARRepository.decodeRecordCBOR(edited.encodedDAGCBOR())
        let fromCBOR = try #require(cbor.decoded(AppBskyFeedPost.self))
        #expect(fromCBOR.tags == ["fixed"])
        // Only the property's value was written: nothing malformed is left to keep.
        #expect(fromCBOR.extraFields["tags"] == nil)
    }

    @Test("Strict decoding still rejects the malformed field")
    func strictDecodingRejects() {
        #expect(throws: DecodingError.self) {
            try ATProtoDecoding.strictJSONDecoder().decode(AppBskyFeedPost.self, from: Self.malformedPost)
        }
    }

    @Test("A record read from DAG-CBOR with unknown union variants re-encodes to the same bytes")
    func unknownUnionVariantsSurviveDAGCBOR() throws {
        let json = Data("""
        {
          "$type": "app.bsky.feed.post",
          "text": "hello world",
          "createdAt": "2026-07-15T12:00:00.000Z",
          "facets": [{
            "index": {"byteStart": 0, "byteEnd": 5},
            "features": [{"$type": "com.example.richtext.facet#sparkle", "glow": 2}]
          }],
          "embed": {"$type": "com.example.embed.hologram", "scale": 3},
          "com.example.note": "an undeclared field"
        }
        """.utf8)
        let untyped = try JSONDecoder().decode([String: ATProtocolValueContainer].self, from: json)
        let bytes = try ATProtocolValueContainer.object(untyped).encodedDAGCBOR()

        let container = try CARRepository.decodeRecordCBOR(bytes)
        let post = try #require(container.decoded(AppBskyFeedPost.self))

        guard case .unexpected? = post.embed else {
            Issue.record("an unknown embed must decode as .unexpected, got \(String(describing: post.embed))")
            return
        }
        guard case .unexpected? = post.facets?.first?.features.first else {
            Issue.record("an unknown facet feature must decode as .unexpected")
            return
        }
        #expect(try post.encodedDAGCBOR() == bytes)
        #expect(try CID.fromDAGCBOR(post.encodedDAGCBOR()) == CID.fromDAGCBOR(bytes))
    }
}
