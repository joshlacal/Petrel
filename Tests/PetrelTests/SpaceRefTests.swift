import Foundation
@testable import Petrel
import Testing

/// Vectors ported from `packages/syntax/tests/aturi-string.test.ts` on
/// `bluesky-social/atproto@permissioned-data-alpha`, which is the normative
/// source for the two AT-URI grammars:
///
///     at://{authorDid}/{collection}/{rkey}                                      public
///     at:space/{spaceDid}/{spaceType}/{skey}[/{authorDid}/{collection}/{rkey}]  space
@Suite("Space references and space-aware AT-URIs")
struct SpaceRefTests {
    private let spaceURI = "at:space/did:plc:asdf123/com.example.group/default"
    private let recordInSpaceURI =
        "at:space/did:plc:asdf123/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123"
    private let publicURI = "at://did:plc:asdf123/com.atproto.feed.post/abc"

    // MARK: - Public URIs are unchanged

    @Test("a public uri parses exactly as before")
    func publicURIUnchanged() throws {
        let uri = try ATProtocolURI(uriString: publicURI)

        #expect(uri.authority == "did:plc:asdf123")
        #expect(uri.collection == "com.atproto.feed.post")
        #expect(uri.recordKey == "abc")
        #expect(uri.isSpace == false)
        #expect(uri.uriString() == publicURI)
    }

    @Test("space accessors are nil on a public uri")
    func spaceAccessorsNilOnPublicURI() throws {
        let uri = try ATProtocolURI(uriString: publicURI)

        #expect(uri.spaceDID == nil)
        #expect(uri.spaceType == nil)
        #expect(uri.skey == nil)
        #expect(uri.spaceRef == nil)
    }

    @Test("a public uri with a handle authority has no author did")
    func handleAuthorityHasNoAuthorDID() throws {
        let uri = try ATProtocolURI(uriString: "at://user.bsky.social/com.atproto.feed.post/abc")

        #expect(uri.authorDID == nil)
        #expect(uri.collection == "com.atproto.feed.post")
    }

    // MARK: - Space URIs

    @Test("a space uri exposes the space parts")
    func spaceURIExposesParts() throws {
        let uri = try ATProtocolURI(uriString: spaceURI)

        #expect(uri.isSpace)
        #expect(uri.spaceDID == "did:plc:asdf123")
        #expect(uri.spaceType == "com.example.group")
        #expect(uri.skey == "default")
    }

    /// The regression this whole change exists to prevent: assigning path segments
    /// positionally reports the `space` marker as the collection and discards the
    /// skey entirely.
    @Test("a space uri does not report the marker as its collection")
    func spaceMarkerIsNotACollection() throws {
        let uri = try ATProtocolURI(uriString: spaceURI)

        #expect(uri.collection != "space")
        #expect(uri.collection == nil)
        #expect(uri.recordKey == nil)
    }

    @Test("a record inside a space names the record's own collection and key")
    func recordInSpaceNamesTheRecord() throws {
        let uri = try ATProtocolURI(uriString: recordInSpaceURI)

        #expect(uri.isSpace)
        #expect(uri.spaceDID == "did:plc:asdf123")
        #expect(uri.spaceType == "com.example.group")
        #expect(uri.skey == "default")
        #expect(uri.authorDID == "did:plc:user1")
        #expect(uri.collection == "com.atproto.feed.post")
        #expect(uri.recordKey == "abc123")
    }

    @Test("a space uri with a handle authority is rejected")
    func handleAuthorityIsRejected() {
        #expect(throws: ATProtocolError.self) {
            try ATProtocolURI(uriString: "at:space/user.bsky.social/com.example.group/default")
        }
    }

    @Test("a space uri with a non-nsid space type is rejected")
    func nonNSIDSpaceTypeIsRejected() {
        #expect(throws: ATProtocolError.self) {
            try ATProtocolURI(uriString: "at:space/did:plc:asdf123/short/default")
        }
    }

    // MARK: - The spaces alpha form

    @Test("the spaces alpha form is rejected when parsing")
    func legacyFormIsRejected() {
        let legacy = [
            "at://did:plc:asdf123/space/com.example.group/default",
            "at://did:plc:asdf123/space/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123",
        ]
        for uri in legacy {
            #expect(throws: ATProtocolError.self, "Expected rejection for: \(uri)") {
                try ATProtocolURI(uriString: uri)
            }
            #expect(!ATProtocolURI.isValidATURI(uri))
            #expect(throws: ATProtocolError.self, "Expected rejection for: \(uri)") {
                try SpaceRef(uriString: uri)
            }
        }
    }

    @Test("fromLegacySpaceURI rewrites only the spaces alpha form")
    func fromLegacySpaceURIRewrites() {
        #expect(
            ATProtocolURI.fromLegacySpaceURI("at://did:plc:asdf123/space/com.example.group/default") == spaceURI
        )
        #expect(
            ATProtocolURI.fromLegacySpaceURI(
                "at://did:plc:asdf123/space/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123"
            ) == recordInSpaceURI
        )
        #expect(ATProtocolURI.fromLegacySpaceURI(spaceURI) == nil)
        #expect(ATProtocolURI.fromLegacySpaceURI(publicURI) == nil)
        #expect(ATProtocolURI.fromLegacySpaceURI("at://did:plc:asdf123/space") == nil)
    }

    @Test("a decoded record value may hold the spaces alpha form")
    func decodingAcceptsLegacyForm() throws {
        let legacy =
            "at://did:plc:asdf123/space/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123"
        let uri = try JSONDecoder().decode(ATProtocolURI.self, from: Data("\"\(legacy)\"".utf8))

        #expect(uri.isSpace)
        #expect(uri.spaceDID == "did:plc:asdf123")
        #expect(uri.authorDID == "did:plc:user1")
        #expect(uri.collection == "com.atproto.feed.post")
        #expect(uri.recordKey == "abc123")
        // The record's bytes are kept as written; the current form is one call away.
        #expect(uri.uriString() == legacy)
        #expect(uri.normalized().uriString() == recordInSpaceURI)
        #expect(uri.spaceRef?.uriString() == spaceURI)
        #expect(uri.asQueryItem(name: "uri")?.value == recordInSpaceURI)
    }

    @Test("decoding still rejects a handle authority in the spaces alpha form")
    func decodingRejectsLegacyHandle() {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(
                ATProtocolURI.self,
                from: Data("\"at://user.bsky.social/space/com.example.group/default\"".utf8)
            )
        }
    }

    @Test("SpaceRef decoding takes the current form only")
    func spaceRefDecodingIsStrict() {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(
                SpaceRef.self,
                from: Data("\"at://did:plc:asdf123/space/com.example.group/default\"".utf8)
            )
        }
    }

    // MARK: - spaceRef

    @Test("one check yields guaranteed parts")
    func spaceRefYieldsGuaranteedParts() throws {
        let ref = try #require(try ATProtocolURI(uriString: spaceURI).spaceRef)

        #expect(ref.spaceDID == "did:plc:asdf123")
        #expect(ref.spaceType == "com.example.group")
        #expect(ref.skey == "default")
        #expect(ref.uriString() == spaceURI)
    }

    @Test("a record uri names the space it belongs to")
    func recordURINamesItsSpace() throws {
        let ref = try #require(try ATProtocolURI(uriString: recordInSpaceURI).spaceRef)

        #expect(ref.uriString() == spaceURI)
    }

    // MARK: - SpaceRef parsing

    @Test("SpaceRef accepts the three-part form")
    func spaceRefAcceptsThreePartForm() throws {
        let ref = try SpaceRef(uriString: spaceURI)

        #expect(ref.skey == "default")
        #expect(ref.description == spaceURI)
    }

    @Test("SpaceRef rejects a record uri within a space")
    func spaceRefRejectsRecordURI() {
        #expect(throws: ATProtocolError.self) {
            try SpaceRef(uriString: recordInSpaceURI)
        }
    }

    @Test("SpaceRef rejects a public uri")
    func spaceRefRejectsPublicURI() {
        #expect(throws: ATProtocolError.self) {
            try SpaceRef(uriString: publicURI)
        }
    }

    @Test("SpaceRef rejects a bare space marker")
    func spaceRefRejectsBareMarker() {
        #expect(throws: ATProtocolError.self) {
            try SpaceRef(uriString: "at:space/did:plc:asdf123")
        }
    }

    @Test("SpaceRef requires a DID authority")
    func spaceRefRequiresDIDAuthority() {
        #expect(throws: ATProtocolError.self) {
            try SpaceRef(uriString: "at:space/user.bsky.social/com.example.group/default")
        }
    }

    @Test("SpaceRef requires an NSID space type")
    func spaceRefRequiresNSIDSpaceType() {
        #expect(throws: ATProtocolError.self) {
            try SpaceRef(uriString: "at:space/did:plc:asdf123/short/default")
        }
    }

    @Test("SpaceRef accepts valid canonical vectors")
    func spaceRefAcceptsValidCanonicalVectors() throws {
        let validURIs = [
            "at:space/did:m:v/com.example.group/default",
            "at:space/did:plc:asdf123/com.example.group/default",
            "at:space/did:plc:owner/blue.catbird.circle/3abc",
            "at:space/did:web:example.com/blue.catbird.circle/3abc",
            "at:space/did:plc:owner/com.atproto.simplespace.space/tid123",
            "at:space/did:plc:auth123/com.example.drive/self",
            "at:space/did:plc:asdf123/com.example.group/test-key_123",
            "at:space/did:plc:asdf123/com.example.group/2024-01-01",
            "at:space/did:plc:asdf123/com.example.group/rkey:~._-",
        ]

        for uri in validURIs {
            let ref = try SpaceRef(uriString: uri)
            #expect(ref.uriString() == uri)
            #expect(ref.description == uri)
        }

        let did2048 = "did:plc:" + String(repeating: "a", count: 2040)
        let validDID2048URI = "at:space/\(did2048)/com.example.group/default"
        let refDID2048 = try SpaceRef(uriString: validDID2048URI)
        #expect(refDID2048.uriString() == validDID2048URI)

        let nsid317 = "com.example." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 49)
        let validNSID317URI = "at:space/did:plc:asdf123/\(nsid317)/default"
        let refNSID317 = try SpaceRef(uriString: validNSID317URI)
        #expect(refNSID317.uriString() == validNSID317URI)

        let valid512 = "at:space/did:plc:asdf123/com.example.group/\(String(repeating: "a", count: 512))"
        let ref512 = try SpaceRef(uriString: valid512)
        #expect(ref512.uriString() == valid512)
    }

    @Test("SpaceRef rejects all malformed vectors")
    func spaceRefRejectsAllMalformedVectors() {
        let did2049 = "did:plc:" + String(repeating: "a", count: 2041)
        let nsid318 = "com.example." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 50)

        let malformedURIs = [
            // Scheme / prefix errors
            "https://example.com/space/blue.catbird.circle/3abc",
            "at:space",
            "at:/space/did:plc:asdf123/com.example.group/default",
            "at:space:did:plc:asdf123/com.example.group/default",
            "AT:SPACE/did:plc:asdf123/com.example.group/default",
            // The spaces alpha form is rejected strictly
            "at://did:plc:asdf123/space/com.example.group/default",
            "at://did:web:example.com/space/blue.catbird.circle/3abc",
            // Segment count and structure errors
            "at://did:plc:asdf123",
            "at:space/did:plc:asdf123",
            "at:space/did:plc:asdf123/com.example.group",
            "at:space/did:plc:asdf123/com.example.group/default/extra",
            "at:space/did:plc:asdf123/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123",
            "at://did:plc:asdf123/com.atproto.feed.post/abc",
            "at:space/did:plc:asdf123//default",
            "at:space/did:plc:asdf123/com.example.group/",
            "at:space//com.example.group/default",
            "at:space//did:plc:asdf123/com.example.group/default",
            "at:other/did:plc:asdf123/com.example.group/default",
            // Authority DID errors
            "at:space/user.bsky.social/com.example.group/default",
            "at:space/did::owner/blue.catbird.circle/3abc",
            "at:space/did:plc:/blue.catbird.circle/3abc",
            "at:space/invalid-did/blue.catbird.circle/3abc",
            "at:space/did:plc:ünicode/com.example.group/default",
            "at:space/\(did2049)/com.example.group/default",
            // SpaceType NSID errors
            "at:space/did:plc:asdf123/short/default",
            "at:space/did:plc:asdf123/-bad.example/3abc",
            "at:space/did:plc:asdf123/com.example.-group/default",
            "at:space/did:plc:asdf123/com.example..group/default",
            "at:space/did:plc:asdf123/1com.example.group/default",
            "at:space/did:plc:asdf123/\(nsid318)/default",
            // Skey RecordKey errors
            "at:space/did:plc:asdf123/com.example.group/.",
            "at:space/did:plc:asdf123/com.example.group/..",
            "at:space/did:plc:asdf123/com.example.group/has space",
            "at:space/did:plc:asdf123/com.example.group/has/slash",
            "at:space/did:plc:asdf123/com.example.group/has@invalid",
            "at:space/did:plc:asdf123/com.example.group/has%percent",
        ]

        for uri in malformedURIs {
            #expect(throws: (any Error).self, "Expected rejection for: \(uri)") {
                try SpaceRef(uriString: uri)
            }
        }

        let overlengthSkey = "at:space/did:plc:asdf123/com.example.group/\(String(repeating: "a", count: 513))"
        #expect(throws: (any Error).self) {
            try SpaceRef(uriString: overlengthSkey)
        }

        let overlengthURI = "at:space/did:plc:asdf123/com.example.group/\(String(repeating: "a", count: 8200))"
        #expect(throws: (any Error).self) {
            try SpaceRef(uriString: overlengthURI)
        }
    }

    @Test("SpaceRef component initializer routes through full validation")
    func spaceRefComponentInitializerValidatesFullContract() throws {
        let valid = try SpaceRef(spaceDID: "did:m:v", spaceType: "com.example.group", skey: "default")
        #expect(valid.uriString() == "at:space/did:m:v/com.example.group/default")

        let did2049 = "did:plc:" + String(repeating: "a", count: 2041)
        #expect(throws: (any Error).self) {
            try SpaceRef(spaceDID: did2049, spaceType: "com.example.group", skey: "default")
        }

        let nsid318 = "com.example." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 50)
        #expect(throws: (any Error).self) {
            try SpaceRef(spaceDID: "did:plc:asdf123", spaceType: nsid318, skey: "default")
        }

        #expect(throws: (any Error).self) {
            try SpaceRef(spaceDID: "did:plc:asdf123", spaceType: "com.example.group", skey: "has%percent")
        }
        #expect(throws: (any Error).self) {
            try SpaceRef(spaceDID: "did:plc:asdf123", spaceType: "com.example.group", skey: ".")
        }
        #expect(throws: (any Error).self) {
            try SpaceRef(spaceDID: "did:plc:asdf123", spaceType: "com.example.group", skey: "..")
        }
    }
    // MARK: - Round-tripping

    @Test("SpaceRef round-trips through JSON byte-identically")
    func spaceRefRoundTripsThroughJSON() throws {
        let ref = try SpaceRef(uriString: spaceURI)
        let encoder = JSONEncoder()
        // JSONEncoder escapes "/" as "\/" by default — valid JSON, but it would
        // make the byte comparison below a test of the encoder, not of SpaceRef.
        encoder.outputFormatting = .withoutEscapingSlashes
        let encoded = try encoder.encode(ref)
        let decoded = try JSONDecoder().decode(SpaceRef.self, from: encoded)

        #expect(String(data: encoded, encoding: .utf8) == "\"\(spaceURI)\"")
        #expect(decoded == ref)
    }

    @Test("a space uri round-trips byte-identically through ATProtocolURI")
    func spaceURIRoundTrips() throws {
        #expect(try ATProtocolURI(uriString: spaceURI).uriString() == spaceURI)
        #expect(try ATProtocolURI(uriString: recordInSpaceURI).uriString() == recordInSpaceURI)
    }

    @Test("building a record uri from a space ref matches the wire form")
    func recordURIFromSpaceRef() throws {
        let uri = try SpaceRef(uriString: spaceURI).recordURI(
            authorDID: "did:plc:user1",
            collection: "com.atproto.feed.post",
            recordKey: "abc123"
        )

        #expect(uri.uriString() == recordInSpaceURI)
    }
}
