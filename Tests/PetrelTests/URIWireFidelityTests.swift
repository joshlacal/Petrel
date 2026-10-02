import Foundation
@testable import Petrel
import Testing

/// Wire fidelity of decoded `URI` and legacy `Blob` values.
///
/// A URI decoded from the wire re-encodes, describes itself and resolves `url` from its
/// whitespace-trimmed wire text; before this, ports, userinfo and percent-escapes were
/// rebuilt away and the lossless-decode guard demoted the whole record to `unknownType`
/// (Catbird's "Post format error"). A blob decoded from the legacy `{cid, mimeType}`
/// shape re-encodes in that shape for the same reason.
@Suite("URI and Blob wire fidelity")
struct URIWireFidelityTests {
    /// Valid URIs the legacy rebuild changed on re-encode.
    static let lossyWireURIs: [String] = [
        "https://example.com:8443/x",
        "https://user@example.com/x",
        "https://user:pw@example.com:8080/x?a=1#top",
        "https://example.com:/x",
        "https://[2001:db8::1]:8443/x",
        "https://ja.wikipedia.org/wiki/日本",
        "https://example.com/caf\u{E9}",
        "https://example.com/🐦/x",
        "https://bücher.example/x",
        "https://example.com/?q=a%26b",
        "https://example.com/a%2Fb",
        "https://example.com/q?x=%e6%97%a5",
        "mailto:birds@example.com",
    ]

    /// Valid URIs whose legacy rebuild already equalled the wire text.
    static let stableWireURIs: [String] = [
        "https://example.com/x",
        "https://bsky.app/profile/alice.bsky.social/post/3kabc123",
        "https://xn--bcher-kva.example/x",
        "HTTPS://EXAMPLE.com/X",
        "https://example.com/a?b=c+d",
        "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3kabc123",
        "did:plc:z72i7hdynmk6r22z27h6tvur",
    ]

    /// The pre-fix `uriString()` for a code-built (non-at, non-did) URI.
    static func legacyRebuild(_ uri: URI) -> String {
        var components = URLComponents()
        components.scheme = uri.scheme.isEmpty ? nil : uri.scheme
        components.host = uri.authority
        components.path = uri.path ?? ""
        components.query = uri.query
        components.fragment = uri.fragment
        return components.string ?? "invalid-uri"
    }

    static func decodeURI(_ wire: String) throws -> URI {
        try JSONDecoder().decode([URI].self, from: JSONEncoder().encode([wire]))[0]
    }

    static func encodedString(_ uri: URI) throws -> String {
        try JSONDecoder().decode([String].self, from: JSONEncoder().encode([uri]))[0]
    }

    // MARK: URI

    @Test(
        "Decoded URIs re-encode, describe and resolve as their wire text",
        arguments: lossyWireURIs + stableWireURIs
    )
    func decodedURIPreservesWireText(_ wire: String) throws {
        let uri = try Self.decodeURI(wire)
        #expect(uri.uriString() == wire)
        #expect(uri.description == wire)
        #expect(try Self.encodedString(uri) == wire)
        #expect(try uri.toCBORValue() as? String == wire)
        #expect(uri.asQueryItem(name: "u")?.value == (uri.isValid() ? wire : nil))
        if !uri.isDID {
            #expect(uri.url?.absoluteString == URL(string: wire)?.absoluteString)
        }
        let again = try Self.decodeURI(Self.encodedString(uri))
        #expect(again == uri)
        #expect(again.uriString() == wire)
    }

    @Test("Port, userinfo and escapes survive into URI.url (link cards open the right URL)", arguments: [
        "https://host.example:8443/a%2Fb", "https://user@host.example:8443/a%2Fb?q=a%26b",
    ])
    func urlKeepsPortAndEscapes(_ wire: String) throws {
        let url = try #require(try Self.decodeURI(wire).url)
        #expect(url.port == 8443)
        #expect(url.absoluteString == wire)
    }

    @Test(
        "Code-built URIs keep the rebuilt encoding and stay equal to decoded ones",
        arguments: lossyWireURIs
    )
    func constructedURIsUnchanged(_ wire: String) throws {
        let built = URI(uriString: wire)
        #expect(built.uriString() == Self.legacyRebuild(built))
        #expect(built.description == Self.legacyRebuild(built))
        let decoded = try Self.decodeURI(wire)
        #expect(decoded == built)
        #expect(decoded.hashValue == built.hashValue)
        #expect(Set([decoded, built]).count == 1)
    }

    @Test("Whitespace-padded wire URIs re-encode trimmed, so the lossless guard still demotes")
    func paddedURIsStayTrimmed() throws {
        let uri = try Self.decodeURI(" https://example.com/item\n")
        #expect(uri.uriString() == "https://example.com/item")
        let record: [String: Any] = Self.postRecord(facetURI: "  https://example.com:8443/x  ")
        let decoded = try JSONDecoder().decode(ATProtocolValueContainer.self, from: JSONSerialization.data(withJSONObject: record))
        guard case let .unknownType(type, _) = decoded else {
            Issue.record("Expected padded URI record to stay demoted, got \(decoded)")
            return
        }
        #expect(type == "app.bsky.feed.post")
    }

    @Test("Invalid wire URIs keep the placeholder encoding", arguments: ["not a uri", "//example.com/x", "1http://x"])
    func invalidURIsUnchanged(_ wire: String) throws {
        let uri = try Self.decodeURI(wire)
        #expect(uri.authority == "invalid.invalid")
        #expect(uri.uriString() == "https://invalid.invalid")
        #expect(uri.url?.absoluteString == "https://invalid.invalid")
    }

    // MARK: Records

    static func postRecord(facetURI: String? = nil, externalURI: String? = nil, images: [[String: Any]]? = nil) -> [String: Any] {
        var record: [String: Any] = ["$type": "app.bsky.feed.post", "text": "see link", "createdAt": "2026-09-01T00:00:00.000Z"]
        if let facetURI {
            record["facets"] = [[
                "index": ["byteStart": 0, "byteEnd": 3],
                "features": [["$type": "app.bsky.richtext.facet#link", "uri": facetURI]],
            ]]
        }
        if let externalURI {
            record["embed"] = [
                "$type": "app.bsky.embed.external",
                "external": ["uri": externalURI, "title": "t", "description": "d"],
            ]
        }
        if let images {
            record["embed"] = ["$type": "app.bsky.embed.images", "images": images]
        }
        return record
    }

    /// The same value as a raw container, for the DAG-CBOR decode path.
    static func container(_ value: Any) -> ATProtocolValueContainer {
        switch value {
        case let string as String: .string(string)
        case let int as Int: .number(int)
        case let array as [Any]: .array(array.map(container))
        case let object as [String: Any]: .object(object.mapValues(container))
        default: fatalError("unsupported test value \(value)")
        }
    }

    static func expectTypedPost(_ record: [String: Any], file: String = #fileID, line: Int = #line) throws -> AppBskyFeedPost? {
        let json = try JSONDecoder().decode(ATProtocolValueContainer.self, from: JSONSerialization.data(withJSONObject: record))
        let raw = container(record)
        let cbor = try ATProtocolValueContainer.decodedFromDAGCBOR(raw.encodedDAGCBOR())
        for decoded in [json, cbor] {
            guard case let .knownType(value) = decoded, value is AppBskyFeedPost else {
                Issue.record("Expected .knownType(AppBskyFeedPost), got \(decoded)")
                return nil
            }
            #expect(ATProtocolValueContainer.isSpecTolerantMatch(typed: decoded, raw: raw))
        }
        guard case let .knownType(value) = json else { return nil }
        return value as? AppBskyFeedPost
    }

    @Test("Posts with unusual link-facet URIs stay typed on JSON and DAG-CBOR paths", arguments: lossyWireURIs)
    func facetLinkPostsStayTyped(_ wire: String) throws {
        let post = try Self.expectTypedPost(Self.postRecord(facetURI: wire))
        guard case let .appBskyRichtextFacetLink(link)? = post?.facets?.first?.features.first else {
            Issue.record("missing link facet")
            return
        }
        #expect(link.uri.uriString() == wire)
    }

    @Test("Posts with unusual link-card URIs stay typed on JSON and DAG-CBOR paths", arguments: lossyWireURIs)
    func externalEmbedPostsStayTyped(_ wire: String) throws {
        let post = try Self.expectTypedPost(Self.postRecord(externalURI: wire))
        guard case let .appBskyEmbedExternal(external)? = post?.embed else {
            Issue.record("missing external embed")
            return
        }
        #expect(external.external.uri.uriString() == wire)
    }

    // MARK: Blob

    static let legacyCID = "bafkreifqkz7gikummmwlitlxwfqnverjhacyeu4i3dytnmhn5bmuowkzoy"

    @Test("Legacy {cid, mimeType} blobs re-encode in their own shape")
    func legacyBlobRoundTrips() throws {
        let wire = Data(#"{"cid":"\#(Self.legacyCID)","mimeType":"image/jpeg"}"#.utf8)
        let blob = try JSONDecoder().decode(Blob.self, from: wire)
        #expect(blob.type == "blob" && blob.size == 0 && blob.ref == nil && blob.cid == Self.legacyCID)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        #expect(try encoder.encode(blob) == wire)

        let cbor = try #require(try blob.toCBORValue() as? OrderedCBORMap)
        #expect(cbor.entries.map(\.key) == ["cid", "mimeType"])

        let modern = Blob(type: "blob", mimeType: "image/jpeg", size: 0, cid: Self.legacyCID)
        #expect(blob == modern)
        #expect(blob.hashValue == modern.hashValue)
        #expect(try encoder.encode(modern) != wire)
        #expect(try JSONDecoder().decode(Blob.self, from: encoder.encode(blob)) == blob)
    }

    @Test("Legacy-shaped blobs that also carry size keep the modern re-encode")
    func hybridLegacyBlobUnchanged() throws {
        let wire = Data(#"{"cid":"\#(Self.legacyCID)","mimeType":"image/jpeg","size":5}"#.utf8)
        let blob = try JSONDecoder().decode(Blob.self, from: wire)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let encoded = try #require(String(data: encoder.encode(blob), encoding: .utf8))
        #expect(encoded == #"{"$type":"blob","cid":"\#(Self.legacyCID)","mimeType":"image/jpeg","size":0}"#)
    }

    @Test("Posts with legacy image blobs stay typed on JSON and DAG-CBOR paths")
    func legacyBlobPostsStayTyped() throws {
        let images: [[String: Any]] = [
            ["alt": "", "image": ["cid": Self.legacyCID, "mimeType": "image/jpeg"]],
            ["alt": "second", "image": ["cid": Self.legacyCID, "mimeType": "image/png"]],
        ]
        let post = try Self.expectTypedPost(Self.postRecord(images: images))
        guard case let .appBskyEmbedImages(embed)? = post?.embed else {
            Issue.record("missing images embed")
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for (index, image) in embed.images.enumerated() {
            let encoded = try JSONSerialization.jsonObject(with: encoder.encode(image.image)) as? NSDictionary
            #expect(encoded == images[index]["image"] as? NSDictionary)
        }
    }
}
