import Foundation
@testable import Petrel
import Testing

/// Vectors ported from `packages/syntax/tests/aturi-string.test.ts` on
/// `bluesky-social/atproto@permissioned-data`, which is the normative source for
/// the two AT-URI grammars:
///
///     at://{authorDid}/{collection}/{rkey}                                        public
///     at://{spaceDid}/space/{spaceType}/{skey}[/{authorDid}/{collection}/{rkey}]  space
@Suite("Space references and space-aware AT-URIs")
struct SpaceRefTests {
    private let spaceURI = "at://did:plc:asdf123/space/com.example.group/default"
    private let recordInSpaceURI =
        "at://did:plc:asdf123/space/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123"
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

    @Test("a handle authority has no space parts")
    func handleAuthorityHasNoSpaceParts() throws {
        let uri = try ATProtocolURI(uriString: "at://user.bsky.social/space/com.example.group/default")

        #expect(uri.spaceDID == nil)
        #expect(uri.spaceRef == nil)
    }

    @Test("a non-nsid space type has no space parts")
    func nonNSIDSpaceTypeHasNoSpaceParts() throws {
        let uri = try ATProtocolURI(uriString: "at://did:plc:asdf123/space/short/default")

        #expect(uri.spaceType == nil)
        #expect(uri.spaceRef == nil)
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
            try SpaceRef(uriString: "at://did:plc:asdf123/space")
        }
    }

    @Test("SpaceRef requires a DID authority")
    func spaceRefRequiresDIDAuthority() {
        #expect(throws: ATProtocolError.self) {
            try SpaceRef(uriString: "at://user.bsky.social/space/com.example.group/default")
        }
    }

    @Test("SpaceRef requires an NSID space type")
    func spaceRefRequiresNSIDSpaceType() {
        #expect(throws: ATProtocolError.self) {
            try SpaceRef(uriString: "at://did:plc:asdf123/space/short/default")
        }
    }

    @Test("SpaceRef accepts valid canonical vectors")
    func spaceRefAcceptsValidCanonicalVectors() throws {
        let validURIs = [
            "at://did:m:v/space/com.example.group/default",
            "at://did:plc:asdf123/space/com.example.group/default",
            "at://did:plc:owner/space/blue.catbird.circle/3abc",
            "at://did:web:example.com/space/blue.catbird.circle/3abc",
            "at://did:plc:owner/space/com.atproto.simplespace.space/tid123",
            "at://did:plc:auth123/space/com.example.drive/self",
            "at://did:plc:asdf123/space/com.example.group/test-key_123",
            "at://did:plc:asdf123/space/com.example.group/2024-01-01",
            "at://did:plc:asdf123/space/com.example.group/rkey:~._-",
        ]

        for uri in validURIs {
            let ref = try SpaceRef(uriString: uri)
            #expect(ref.uriString() == uri)
            #expect(ref.description == uri)
        }

        let did2048 = "did:plc:" + String(repeating: "a", count: 2040)
        let validDID2048URI = "at://\(did2048)/space/com.example.group/default"
        let refDID2048 = try SpaceRef(uriString: validDID2048URI)
        #expect(refDID2048.uriString() == validDID2048URI)

        let nsid317 = "com.example." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 63) + "." + String(repeating: "a", count: 49)
        let validNSID317URI = "at://did:plc:asdf123/space/\(nsid317)/default"
        let refNSID317 = try SpaceRef(uriString: validNSID317URI)
        #expect(refNSID317.uriString() == validNSID317URI)

        let valid512 = "at://did:plc:asdf123/space/com.example.group/\(String(repeating: "a", count: 512))"
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
            "at:/did:plc:asdf123/space/com.example.group/default",
            "AT://did:plc:asdf123/space/com.example.group/default",
            // Segment count and structure errors
            "at://did:plc:asdf123",
            "at://did:plc:asdf123/space",
            "at://did:plc:asdf123/space/com.example.group",
            "at://did:plc:asdf123/space/com.example.group/default/extra",
            "at://did:plc:asdf123/space/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123",
            "at://did:plc:asdf123/com.atproto.feed.post/abc",
            "at://did:plc:asdf123/space//default",
            "at://did:plc:asdf123/space/com.example.group/",
            "at:///space/com.example.group/default",
            "at://did:plc:asdf123//com.example.group/default",
            "at://did:plc:asdf123/other/com.example.group/default",
            // Authority DID errors
            "at://user.bsky.social/space/com.example.group/default",
            "at://did::owner/space/blue.catbird.circle/3abc",
            "at://did:plc:/space/blue.catbird.circle/3abc",
            "at://invalid-did/space/blue.catbird.circle/3abc",
            "at://did:plc:ünicode/space/com.example.group/default",
            "at://\(did2049)/space/com.example.group/default",
            // SpaceType NSID errors
            "at://did:plc:asdf123/space/short/default",
            "at://did:plc:asdf123/space/-bad.example/3abc",
            "at://did:plc:asdf123/space/com.example.-group/default",
            "at://did:plc:asdf123/space/com.example..group/default",
            "at://did:plc:asdf123/space/1com.example.group/default",
            "at://did:plc:asdf123/space/\(nsid318)/default",
            // Skey RecordKey errors
            "at://did:plc:asdf123/space/com.example.group/.",
            "at://did:plc:asdf123/space/com.example.group/..",
            "at://did:plc:asdf123/space/com.example.group/has space",
            "at://did:plc:asdf123/space/com.example.group/has/slash",
            "at://did:plc:asdf123/space/com.example.group/has@invalid",
            "at://did:plc:asdf123/space/com.example.group/has%percent",
        ]

        for uri in malformedURIs {
            #expect(throws: (any Error).self, "Expected rejection for: \(uri)") {
                try SpaceRef(uriString: uri)
            }
        }

        let overlengthSkey = "at://did:plc:asdf123/space/com.example.group/\(String(repeating: "a", count: 513))"
        #expect(throws: (any Error).self) {
            try SpaceRef(uriString: overlengthSkey)
        }

        let overlengthURI = "at://did:plc:asdf123/space/com.example.group/\(String(repeating: "a", count: 8200))"
        #expect(throws: (any Error).self) {
            try SpaceRef(uriString: overlengthURI)
        }
    }

    @Test("SpaceRef component initializer routes through full validation")
    func spaceRefComponentInitializerValidatesFullContract() throws {
        let valid = try SpaceRef(spaceDID: "did:m:v", spaceType: "com.example.group", skey: "default")
        #expect(valid.uriString() == "at://did:m:v/space/com.example.group/default")

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
