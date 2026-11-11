import Crypto
import Foundation
@testable import Petrel
import PetrelCrypto
import Testing

/// The typed DID document model: decoding, the claimed handle, services and keys, and the one
/// `did:web` validator.
@Suite("DID document model and did:web validation")
struct DIDResolutionDocumentTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

    private func decode(_ json: String) throws -> DIDDocument {
        try JSONDecoder().decode(DIDDocument.self, from: Data(json.utf8))
    }

    private struct DIDKeyVector: Decodable {
        let publicDidKey: String
        let privateKeyBytesBase58: String?
    }

    private func keyVectors(_ name: String) throws -> [DIDKeyVector] {
        try JSONDecoder().decode([DIDKeyVector].self, from: IdentityFixtures.vectorJSON(name))
    }

    private func document(keyID: String = "#atproto", type: String, controller: String? = nil, multibase: String) throws -> DIDDocument {
        try decode(IdentityFixtures.document(did: did, verificationMethods: [[
            "id": keyID, "type": type, "controller": controller ?? did, "publicKeyMultibase": multibase,
        ]]))
    }

    // MARK: Signing key

    @Test("Multikey: every P-256 and K-256 did:key interop vector round-trips through #atproto")
    func multikeySigningKeyVectors() throws {
        let vectors = try keyVectors("w3c_didkey_P256") + keyVectors("w3c_didkey_K256")
        #expect(vectors.count >= 2)
        for vector in vectors {
            let multibase = String(vector.publicDidKey.dropFirst("did:key:".count))
            for keyID in ["#atproto", "\(did)#atproto"] {
                let document = try document(keyID: keyID, type: "Multikey", multibase: multibase)
                #expect(try document.atprotoSigningDIDKey() == vector.publicDidKey)
                let expected = try ATProtoJWTVerificationKey(PLCDIDKeyCodec.decode(vector.publicDidKey))
                #expect(try document.atprotoSigningKey() == expected)
            }
        }
    }

    @Test("Legacy EcdsaSecp256r1VerificationKey2019: uncompressed multibase yields the same key as Multikey")
    func legacyP256SigningKey() throws {
        for vector in try keyVectors("w3c_didkey_P256") {
            let scalar = try Base58BTC.decode(try #require(vector.privateKeyBytesBase58))
            let publicKey = try P256.Signing.PrivateKey(rawRepresentation: scalar).publicKey
            // Legacy form: multibase `z` + base58btc of the uncompressed point, no multicodec.
            let legacy = "z" + Base58BTC.encode(publicKey.x963Representation)
            let document = try document(type: "EcdsaSecp256r1VerificationKey2019", multibase: legacy)

            #expect(try document.atprotoSigningDIDKey() == vector.publicDidKey)
        }
    }

    @Test("Legacy EcdsaSecp256k1VerificationKey2019: the specification's example pair is one key")
    func legacyK256SigningKey() throws {
        // The DID specification, "Legacy Representation": the same K-256 public key in the legacy
        // and the current encoding.
        let legacy = "zQYEBzXeuTM9UR3rfvNag6L3RNAs5pQZyYPsomTsgQhsxLdEgCrPTLgFna8yqCnxPpNT7DBk6Ym3dgPKNu86vt9GR"
        let multikey = "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"

        let legacyDocument = try document(type: "EcdsaSecp256k1VerificationKey2019", multibase: legacy)
        let currentDocument = try document(type: "Multikey", multibase: multikey)

        #expect(try legacyDocument.atprotoSigningDIDKey() == "did:key:" + multikey)
        #expect(try legacyDocument.atprotoSigningKey() == currentDocument.atprotoSigningKey())
    }

    @Test("The first valid #atproto key is used; invalid, foreign-controlled and other-id entries are skipped")
    func firstValidSigningKey() throws {
        let k256 = try keyVectors("w3c_didkey_K256")
        let good = String(try #require(k256.first).publicDidKey.dropFirst("did:key:".count))
        let later = String(try #require(k256.dropFirst().first).publicDidKey.dropFirst("did:key:".count))
        let document = try decode(IdentityFixtures.document(did: did, verificationMethods: [
            ["id": "#atproto_label", "type": "Multikey", "controller": did, "publicKeyMultibase": later],
            ["id": "#atproto", "type": "Multikey", "controller": did, "publicKeyMultibase": "zNotAKey"],
            ["id": "#atproto", "type": "Multikey", "controller": "did:plc:someoneelse", "publicKeyMultibase": later],
            ["id": "#atproto", "type": "JsonWebKey2020", "controller": did, "publicKeyMultibase": later],
            ["id": "did:plc:other#atproto", "type": "Multikey", "controller": did, "publicKeyMultibase": later],
            ["id": "#atproto", "type": "Multikey", "controller": did, "publicKeyMultibase": good],
            ["id": "#atproto", "type": "Multikey", "controller": did, "publicKeyMultibase": later],
        ]))

        #expect(try document.atprotoSigningDIDKey() == "did:key:" + good)
        #expect(try document.verificationKey(withID: "atproto_label").didKey == "did:key:" + later)
        #expect(document.verificationMethod(withID: "#atproto")?.publicKeyMultibase == "zNotAKey")
    }

    @Test("A document without a usable #atproto key throws a typed error")
    func missingSigningKey() throws {
        let k256 = try keyVectors("w3c_didkey_K256")
        let key = String(try #require(k256.first).publicDidKey.dropFirst("did:key:".count))
        let documents = try [
            decode(IdentityFixtures.document(did: did)),
            document(keyID: "#atproto", type: "Multikey", controller: "did:plc:someoneelse", multibase: key),
            document(keyID: "#atproto", type: "Multikey", multibase: ""),
            document(keyID: "#other", type: "Multikey", multibase: key),
            document(keyID: "#atproto", type: "Ed25519VerificationKey2020", multibase: key),
            // A P-256 legacy label on a K-256 Multikey value: the curve must match the type.
            document(keyID: "#atproto", type: "EcdsaSecp256r1VerificationKey2019", multibase: key),
        ]
        for document in documents {
            #expect(throws: IdentityError.missingSigningKey(did: did)) {
                try document.atprotoSigningKey()
            }
            #expect(throws: IdentityError.missingSigningKey(did: did)) {
                try document.atprotoSigningDIDKey()
            }
        }
        #expect(throws: IdentityError.missingVerificationMethod(did: did, id: "#atproto_label")) {
            try documents[0].verificationKey(withID: "#atproto_label")
        }
    }

    // MARK: Services

    @Test("PDS, labeler, feed generator, notification, chat and AppView services are found by id and type")
    func knownServices() throws {
        let document = try decode(IdentityFixtures.document(did: did, pds: "https://pds.example.com", services: [
            ["id": "#atproto_labeler", "type": "AtprotoLabeler", "serviceEndpoint": "https://labeler.example.com"],
            ["id": "\(did)#bsky_fg", "type": "BskyFeedGenerator", "serviceEndpoint": "https://feeds.example.com"],
            ["id": "#bsky_notif", "type": "BskyNotificationService", "serviceEndpoint": "https://notif.example.com"],
            ["id": "#bsky_chat", "type": "BskyChatService", "serviceEndpoint": "https://chat.example.com"],
            ["id": "#bsky_appview", "type": "BskyAppView", "serviceEndpoint": "https://appview.example.com:8443"],
            ["id": "#my_service", "type": "Anything", "serviceEndpoint": "https://custom.example.com/"],
        ]))

        #expect(document.pdsEndpoint?.absoluteString == "https://pds.example.com")
        #expect(document.labelerEndpoint?.absoluteString == "https://labeler.example.com")
        #expect(document.feedGeneratorEndpoint?.absoluteString == "https://feeds.example.com")
        #expect(document.notificationServiceEndpoint?.absoluteString == "https://notif.example.com")
        #expect(document.chatEndpoint?.absoluteString == "https://chat.example.com")
        #expect(try document.serviceEndpoint(.appView).absoluteString == "https://appview.example.com:8443")
        #expect(try document.serviceEndpoint(DIDServiceIdentifier(id: "my_service")).absoluteString == "https://custom.example.com/")
        #expect(document.service(DIDServiceIdentifier(id: "#my_service", type: "SomethingElse")) == nil)
        #expect(throws: IdentityError.missingService(did: did, id: "#missing")) {
            try document.serviceEndpoint(DIDServiceIdentifier(id: "#missing"))
        }
    }

    @Test("The first matching service is used, and a wrong type or a foreign DID prefix does not match")
    func firstMatchingService() throws {
        let document = try decode(IdentityFixtures.document(did: did, pds: nil, services: [
            ["id": "#atproto_pds", "type": "SomethingElse", "serviceEndpoint": "https://wrong-type.example.com"],
            ["id": "did:plc:other#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://foreign.example.com"],
            ["id": "atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://no-hash.example.com"],
            ["id": "\(did)#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://first.example.com"],
            ["id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://second.example.com"],
        ]))

        #expect(document.pdsEndpoint?.absoluteString == "https://first.example.com")
    }

    @Test("A service endpoint must be an https origin, or http on loopback, and nothing more")
    func serviceEndpointValidation() throws {
        let accepted = [
            "https://pds.example.com", "https://pds.example.com/", "https://pds.example.com:8443",
            "http://localhost:2583", "http://127.0.0.1:2583", "HTTPS://pds.example.com",
        ]
        let rejected = [
            "http://pds.example.com", "ftp://pds.example.com", "pds.example.com", "",
            "https://user:pass@pds.example.com", "https://user@pds.example.com",
            "https://pds.example.com/xrpc", "https://pds.example.com?x=1", "https://pds.example.com#frag",
            "https://", "javascript:alert(1)", "file:///etc/passwd",
        ]
        for endpoint in accepted {
            let document = try decode(IdentityFixtures.document(did: did, pds: endpoint))
            #expect(document.pdsEndpoint != nil, "\(endpoint)")
        }
        for endpoint in rejected {
            let document = try decode(IdentityFixtures.document(did: did, pds: endpoint, services: [
                // A valid later entry does not rescue an invalid first match.
                ["id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://later.example.com"],
            ]))
            #expect(document.pdsEndpoint == nil, "\(endpoint)")
            #expect(throws: IdentityError.invalidServiceEndpoint(did: did, id: "#atproto_pds"), "\(endpoint)") {
                try document.serviceEndpoint(.pds)
            }
        }
    }

    // MARK: Handle

    @Test("The claimed handle is the first syntactically valid at:// entry, lowercased")
    func claimedHandle() throws {
        let document = try decode("""
        {"id":"\(did)","alsoKnownAs":["https://example.com","example.com","at://not a handle","at://invalid..handle",
        "at://First.Example.com","at://second.example.com"]}
        """)
        #expect(document.claimedHandle?.value == "first.example.com")

        #expect(try decode(#"{"id":"\#(did)"}"#).claimedHandle == nil)
        #expect(try decode(#"{"id":"\#(did)","alsoKnownAs":["at://alice.example.com/path"]}"#).claimedHandle == nil)
        #expect(try decode(#"{"id":"\#(did)","alsoKnownAs":["AT://alice.example.com"]}"#).claimedHandle == nil)
    }

    // MARK: Decoding

    @Test("Decoding tolerates the W3C shapes AT Protocol does not use")
    func tolerantDecoding() throws {
        let document = try decode("""
        {
          "@context": "https://www.w3.org/ns/did/v1",
          "id": "\(did)",
          "alsoKnownAs": ["at://alice.example.com", 7],
          "verificationMethod": [
            {"id": "#jwk", "type": "JsonWebKey2020", "controller": "\(did)", "publicKeyJwk": {"kty": "EC"}},
            {"id": "#broken"},
            "did:example:reference",
            {"id": "#atproto", "type": "Multikey", "controller": "\(did)", "publicKeyMultibase": "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"}
          ],
          "service": [
            {"id": "#map", "type": "LinkedDomains", "serviceEndpoint": {"origins": ["https://example.com"]}},
            {"id": "#set", "type": "LinkedDomains", "serviceEndpoint": ["https://a.example.com", "https://b.example.com"]},
            {"id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://pds.example.com"}
          ],
          "authentication": ["#atproto"],
          "unknownTopLevel": {"anything": true}
        }
        """)

        #expect(document.context == ["https://www.w3.org/ns/did/v1"])
        #expect(document.alsoKnownAs == ["at://alice.example.com"])
        #expect(document.verificationMethod.map(\.id) == ["#jwk", "#atproto"])
        #expect(document.verificationMethod.first?.publicKeyMultibase == "")
        #expect(document.service.map(\.id) == ["#atproto_pds"])
        #expect(document.pdsEndpoint?.absoluteString == "https://pds.example.com")
        #expect(try document.atprotoSigningDIDKey() == "did:key:zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF")
    }

    @Test("Decoding keeps a mixed @context array's strings and accepts a document with only an id")
    func minimalAndMixedContext() throws {
        let mixed = try decode(#"{"@context":["https://www.w3.org/ns/did/v1",{"@base":"x"}],"id":"\#(did)"}"#)
        #expect(mixed.context == ["https://www.w3.org/ns/did/v1"])

        let minimal = try decode(#"{"id":"\#(did)"}"#)
        #expect(minimal.context.isEmpty && minimal.alsoKnownAs.isEmpty)
        #expect(minimal.verificationMethod.isEmpty && minimal.service.isEmpty)
    }

    @Test("A document without an id, or with a non-string id, does not decode")
    func idIsRequired() {
        #expect(throws: (any Error).self) { try decode(#"{"alsoKnownAs":[]}"#) }
        #expect(throws: (any Error).self) { try decode(#"{"id":42}"#) }
        #expect(throws: (any Error).self) { try decode(#"["not","an","object"]"#) }
    }

    @Test("A document round-trips through JSON")
    func jsonRoundTrip() throws {
        let original = try decode(IdentityFixtures.document(did: did, handles: ["alice.example.com"], verificationMethods: [
            ["id": "#atproto", "type": "Multikey", "controller": did, "publicKeyMultibase": "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"],
        ]))
        let reencoded = try JSONDecoder().decode(DIDDocument.self, from: JSONEncoder().encode(original))
        #expect(reencoded == original)
    }

    // MARK: did:web

    @Test("DIDWebIdentifier accepts hostname-level did:web and builds the document URL")
    func didWebAccepted() throws {
        let web = try DIDWebIdentifier("did:web:identity.example.com")
        #expect(web.host == "identity.example.com")
        #expect(web.port == nil)
        #expect(!web.isDevelopmentHost)
        #expect(web.documentURL.absoluteString == "https://identity.example.com/.well-known/did.json")
        #expect(web.description == "did:web:identity.example.com")

        for did in ["did:web:example.com", "did:web:a.co", "did:web:xn--ls8h.example.com", "did:web:8.cn", "did:web:sub.sub.example.org"] {
            #expect(DIDWebIdentifier.isValid(did), "\(did)")
        }
    }

    @Test("DIDWebIdentifier allows localhost, a localhost port and .test only for development")
    func didWebDevelopmentHosts() throws {
        for did in ["did:web:localhost", "did:web:localhost%3A2583", "did:web:localhost%3a2583", "did:web:pds.test"] {
            #expect(!DIDWebIdentifier.isValid(did), "\(did)")
            #expect(throws: DIDWebIdentifier.ValidationError.developmentHostNotAllowed, "\(did)") {
                try DIDWebIdentifier(did)
            }
            #expect(DIDWebIdentifier.isValid(did, allowingDevelopmentHosts: true), "\(did)")
        }

        let local = try DIDWebIdentifier("did:web:localhost%3A2583", allowingDevelopmentHosts: true)
        #expect(local.host == "localhost")
        #expect(local.port == 2583)
        #expect(local.isDevelopmentHost)
        #expect(local.documentURL.absoluteString == "http://localhost:2583/.well-known/did.json")
        let bare = try DIDWebIdentifier("did:web:localhost", allowingDevelopmentHosts: true)
        #expect(bare.documentURL.absoluteString == "http://localhost/.well-known/did.json")
        let test = try DIDWebIdentifier("did:web:pds.test", allowingDevelopmentHosts: true)
        #expect(test.documentURL.absoluteString == "https://pds.test/.well-known/did.json")
    }

    @Test("DIDWebIdentifier rejects paths, ports on other hosts, reserved TLDs and non-hostnames")
    func didWebRejected() {
        typealias Reason = DIDWebIdentifier.ValidationError
        let cases: [(did: String, reason: Reason)] = [
            ("did:web:example.com:users:alice", .pathNotSupported),
            ("did:web:example.com:", .notDIDWeb),
            ("did:web:example.com::", .notDIDWeb),
            ("did:web:localhost:path", .pathNotSupported),
            ("did:web:example.com%3A8443", .portNotAllowed),
            ("did:web:example.com%3A8443:users:bob", .pathNotSupported),
            ("did:web:localhost%3A0", .portNotAllowed),
            ("did:web:localhost%3A65536", .portNotAllowed),
            ("did:web:localhost%3A80%3A81", .portNotAllowed),
            ("did:web:localhost%3A", .portNotAllowed),
            ("did:web:localhost%3Aabc", .portNotAllowed),
            ("did:web:blah.arpa", .reservedTopLevelDomain),
            ("did:web:user.example", .reservedTopLevelDomain),
            ("did:web:service.internal", .reservedTopLevelDomain),
            ("did:web:handle.invalid", .reservedTopLevelDomain),
            ("did:web:laptop.local", .reservedTopLevelDomain),
            ("did:web:dev.localhost", .reservedTopLevelDomain),
            ("did:web:expyuzz4wqqyqhjn.onion", .reservedTopLevelDomain),
            ("did:web:name.alt", .reservedTopLevelDomain),
            ("did:web:com", .invalidHostname),
            ("did:web:127.0.0.1", .invalidHostname),
            ("did:web:192.168.0.142", .invalidHostname),
            ("did:web:Example.com", .invalidHostname),
            ("did:web:-bad.example.com", .invalidHostname),
            ("did:web:bad-.example.com", .invalidHostname),
            ("did:web:exa_mple.com", .invalidHostname),
            ("did:web:example.com%2F..%2Fx", .invalidHostname),
            ("did:web:example..com", .invalidHostname),
            ("did:web:.example.com", .invalidHostname),
            ("did:web:", .notDIDWeb),
            ("did:web:example.com/path", .notDIDWeb),
            ("did:web:example.com?x", .notDIDWeb),
            ("did:web:example.com#frag", .notDIDWeb),
            ("did:web:example.com\n", .notDIDWeb),
            ("did:web:example.com ", .notDIDWeb),
            ("did:web:exämple.com", .notDIDWeb),
            ("did:plc:ewvi7nxzyoun6zhxrhs64oiz", .notDIDWeb),
            ("DID:web:example.com", .notDIDWeb),
            ("did:WEB:example.com", .notDIDWeb),
            ("example.com", .notDIDWeb),
        ]
        for testCase in cases {
            #expect(throws: testCase.reason, "\(testCase.did.debugDescription)") {
                try DIDWebIdentifier(testCase.did, allowingDevelopmentHosts: true)
            }
        }
    }
}
