import Foundation
@testable import Petrel
import Testing

/// Regression tests for BCP-47 tag fidelity in `LanguageCodeContainer`.
///
/// `Locale.Language` drops region and script subtags the moment you ask it for
/// `languageCode` (`en-US` → `en`). Re-deriving the tag that way on encode
/// mutates the record: the lossless-decode guard in `ATProtocolValueContainer`
/// then sees a changed shared field, demotes the record to `.unknownType`, and
/// Catbird renders "Post format error" for every post whose `langs` carries a
/// region- or script-qualified tag.
struct LanguageCodeContainerFidelityTests {
    @Test(
        "Region- and script-qualified tags survive a decode/encode round trip",
        arguments: ["en", "en-US", "en-GB", "pt-BR", "zh-Hans", "zh-Hans-CN", "es-419", "ja"]
    )
    func tagRoundTripsVerbatim(_ tag: String) throws {
        let json = Data("\"\(tag)\"".utf8)
        let decoded = try JSONDecoder().decode(LanguageCodeContainer.self, from: json)
        #expect(decoded.languageTag == tag)

        let reencoded = try JSONEncoder().encode(decoded)
        #expect(String(decoding: reencoded, as: UTF8.self) == "\"\(tag)\"")
        #expect(try decoded.toCBORValue() as? String == tag)
    }

    @Test("A caller-supplied tag keeps its subtags")
    func stringInitializerKeepsSubtags() {
        #expect(LanguageCodeContainer(languageCode: "pt-BR").languageTag == "pt-BR")
        #expect(LanguageCodeContainer(languageCode: "pt-BR").lang.languageCode?.identifier == "pt")
    }

    @Test("Reassigning lang drops the stale wire tag")
    func mutatingLangInvalidatesWireTag() {
        var container = LanguageCodeContainer(languageCode: "en-US")
        #expect(container.languageTag == "en-US")
        container.lang = Locale.Language(bcp47LanguageTag: "fr")
        #expect(container.languageTag == "fr")
    }

    @Test("Query parameters carry the full tag")
    func queryItemKeepsSubtags() {
        let item = LanguageCodeContainer(languageCode: "zh-Hans").asQueryItem(name: "lang")
        #expect(item?.value == "zh-Hans")
    }

    /// Verbatim wire record for
    /// at://did:plc:4uqzdijb5ndnhttyak2xk6hc/app.bsky.feed.post/3msv3pu73im2w,
    /// which Catbird tombstoned as "Post format error" solely because of `langs`.
    @Test("A wire record with a region-qualified lang decodes as a known type")
    func regionQualifiedLangRecordDispatchesTyped() throws {
        let json = """
        {
          "$type": "app.bsky.feed.post",
          "createdAt": "2026-08-12T12:06:42.658236Z",
          "embed": {
            "$type": "app.bsky.embed.record",
            "record": {
              "$type": "com.atproto.repo.strongRef",
              "cid": "bafyreic3maf7tpjm2gwje6fkiiygztpxzigadwyahlfyo6ojnkixtcghuu",
              "uri": "at://did:plc:4uqzdijb5ndnhttyak2xk6hc/app.bsky.feed.post/3mlrpnvrxxa2y"
            }
          },
          "langs": ["en-US"],
          "text": "it was an implied d**th threat to another gay coworker :("
        }
        """
        let container = try JSONDecoder().decode(
            ATProtocolValueContainer.self, from: Data(json.utf8)
        )
        guard case let .knownType(value) = container, let post = value as? AppBskyFeedPost else {
            Issue.record("Expected .knownType(AppBskyFeedPost), got \(container)")
            return
        }
        #expect(post.langs?.map(\.languageTag) == ["en-US"])
    }
}
