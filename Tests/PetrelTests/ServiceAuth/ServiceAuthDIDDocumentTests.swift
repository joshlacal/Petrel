import Foundation
import Petrel
import PetrelCrypto
import Testing

/// Issuer → DID document → signing key → verified request: the path the
/// specification describes for a receiving service.
@Suite("Service auth: keys from DID documents")
struct ServiceAuthDIDDocumentTests {
    static let account = "did:plc:abcdefghijklmnopqrstuvwx"
    static let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// A DID document as a PLC directory or a did:web host serves it.
    static func document(
        did: String = account,
        methods: [(id: String, type: String, multibase: String)]
    ) throws -> DIDDocument {
        let entries = methods.map {
            #"{"id":"\#($0.id)","type":"\#($0.type)","controller":"\#(did)","publicKeyMultibase":"\#($0.multibase)"}"#
        }
        let json = #"""
        {
          "@context": ["https://www.w3.org/ns/did/v1", "https://w3id.org/security/multikey/v1"],
          "id": "\#(did)",
          "alsoKnownAs": ["at://alice.example.com"],
          "verificationMethod": [\#(entries.joined(separator: ","))],
          "service": [{"id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://pds.example.com"}]
        }
        """#
        return try JSONDecoder().decode(DIDDocument.self, from: Data(json.utf8))
    }

    /// A DID-document source whose contents can change, as a directory's do
    /// when an account rotates its key. It serves a stale copy until asked
    /// to refresh.
    actor Directory {
        private var live: [String: DIDDocument] = [:]
        private var cache: [String: DIDDocument] = [:]
        private(set) var fetches = 0

        func publish(_ document: DIDDocument) {
            live[document.id] = document
        }

        func document(for did: String, forceRefresh: Bool) throws -> DIDDocument {
            if !forceRefresh, let cached = cache[did] {
                return cached
            }
            fetches += 1
            guard let document = live[did] else {
                throw URLError(.resourceUnavailable)
            }
            cache[did] = document
            return document
        }
    }

    @Test("The #atproto key is read from a Multikey verification method", arguments: ATProtoKeyCurve.allCases)
    func multikey(_ curve: ATProtoKeyCurve) throws {
        let key = ATProtoCrypto.generateKeypair(curve: curve).publicKey
        // PLC documents use the full DID URL as the id; did:web documents often the bare fragment.
        for id in ["\(Self.account)#atproto", "#atproto"] {
            let document = try Self.document(methods: [(id, "Multikey", key.multikey)])
            let resolved = try DIDDocumentServiceAuthKeyResolver.signingKey(in: document, did: Self.account)
            #expect(resolved == key)
            #expect(resolved.curve == curve)
        }
    }

    @Test("The legacy 2019 verification method types are read too", arguments: ATProtoKeyCurve.allCases)
    func legacyVerificationMethods(_ curve: ATProtoKeyCurve) throws {
        let key = ATProtoCrypto.generateKeypair(curve: curve).publicKey
        let document = try Self.document(methods: [
            ("\(Self.account)#atproto", curve.legacyVerificationMethodType, key.legacyMultibase),
        ])
        #expect(try DIDDocumentServiceAuthKeyResolver.signingKey(in: document, did: Self.account) == key)
    }

    @Test("Other published keys are selected by fragment, never substituted")
    func keySelection() throws {
        let signingKey = K256Keypair.generate().publicKey
        let labelKey = K256Keypair.generate().publicKey
        let document = try Self.document(methods: [
            ("\(Self.account)#atproto_label", "Multikey", labelKey.multikey),
            ("\(Self.account)#atproto", "Multikey", signingKey.multikey),
        ])
        #expect(try DIDDocumentServiceAuthKeyResolver.signingKey(in: document, did: Self.account) == signingKey)
        #expect(try DIDDocumentServiceAuthKeyResolver.signingKey(
            in: document, did: Self.account, keyID: "#atproto_label"
        ) == labelKey)

        #expect(throws: ServiceAuthError.keyResolutionFailed(
            did: Self.account, keyID: "#missing", reason: "DID document has no verification method #missing"
        )) {
            try DIDDocumentServiceAuthKeyResolver.signingKey(in: document, did: Self.account, keyID: "#missing")
        }
    }

    @Test("A document for another DID, or without a usable key, is refused")
    func unusableDocuments() throws {
        let key = K256Keypair.generate().publicKey
        let other = "did:plc:zzzzzzzzzzzzzzzzzzzzzzzz"

        // A source that answers with someone else's document.
        let wrongSubject = try Self.document(did: other, methods: [("\(other)#atproto", "Multikey", key.multikey)])
        #expect(throws: ServiceAuthError.keyResolutionFailed(
            did: Self.account, keyID: "#atproto", reason: "DID document is for \(other)"
        )) {
            try DIDDocumentServiceAuthKeyResolver.signingKey(in: wrongSubject, did: Self.account)
        }

        // No verification methods at all.
        let empty = try Self.document(methods: [])
        #expect(throws: ServiceAuthError.self) {
            try DIDDocumentServiceAuthKeyResolver.signingKey(in: empty, did: Self.account)
        }

        // A key type the protocol does not use, and a corrupt key.
        for (type, multibase) in [
            ("Ed25519VerificationKey2020", "z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"),
            ("Multikey", "zNotAKey"),
            ("Multikey", ""),
        ] {
            let document = try Self.document(methods: [("\(Self.account)#atproto", type, multibase)])
            let error = #expect(throws: ServiceAuthError.self, "\(type)") {
                try DIDDocumentServiceAuthKeyResolver.signingKey(in: document, did: Self.account)
            }
            #expect(error?.xrpcErrorName == "BadJwtSignature")
        }
    }

    // MARK: End to end

    /// The server-side example from the `ServiceAuth` documentation
    /// article: a feed generator authenticating `getFeedSkeleton`.
    struct FeedGenerator {
        static let serviceDID = "did:web:feed.example.com"
        let verifier: ServiceAuthVerifier

        init(directory: Directory) {
            // DID documents → keys, cached, with forced refreshes rate-limited.
            let keys = CachingServiceAuthKeyResolver(
                upstream: DIDDocumentServiceAuthKeyResolver { did, forceRefresh in
                    try await directory.document(for: did, forceRefresh: forceRefresh)
                },
                // The article uses the default (30 s). This test rotates the
                // key milliseconds after the first lookup, so it turns the
                // refresh rate limit off.
                minimumRefreshInterval: 0
            )
            verifier = ServiceAuthVerifier(
                // Requests proxied by a PDS may still carry the bare DID.
                audience: .service(did: Self.serviceDID, id: "bsky_fg", acceptBareDID: true),
                keyResolver: keys,
                replayStore: InMemoryServiceAuthReplayStore()
            )
        }

        /// Returns the viewer's DID, or the XRPC error to answer with.
        func viewer(authorizationHeader: String?) async -> Result<String, ServiceAuthError> {
            do {
                let caller = try await verifier.verify(
                    authorizationHeader: authorizationHeader,
                    method: .exactly("app.bsky.feed.getFeedSkeleton")
                )
                return .success(caller.issuer)
            } catch {
                return .failure(error)
            }
        }
    }

    @Test("A feed generator authenticates a proxied request from the issuer's DID document")
    func feedGeneratorEndToEnd() async throws {
        let directory = Directory()
        let accountKey = K256Keypair.generate()
        try await directory.publish(Self.document(methods: [
            ("\(Self.account)#atproto", "Multikey", accountKey.publicKey.multikey),
        ]))
        let feedGenerator = FeedGenerator(directory: directory)

        // The PDS mints a token for the account and forwards the request.
        func proxiedRequest(signedWith signer: any ATProtoSigner, audience: String = "did:web:feed.example.com#bsky_fg") async throws -> String {
            try await ServiceJWT.bearerAuthorization(ServiceJWT.mint(
                issuer: Self.account,
                audience: audience,
                lexiconMethod: "app.bsky.feed.getFeedSkeleton",
                signer: signer
            ))
        }

        let header = try await proxiedRequest(signedWith: accountKey)
        #expect(await feedGenerator.viewer(authorizationHeader: header) == .success(Self.account))
        // The same token again is a replay.
        #expect(await feedGenerator.viewer(authorizationHeader: header) == .failure(.replayed))
        // A PDS that still strips the service fragment is accepted too.
        let bare = try await proxiedRequest(signedWith: accountKey, audience: "did:web:feed.example.com")
        #expect(await feedGenerator.viewer(authorizationHeader: bare) == .success(Self.account))
        #expect(await directory.fetches == 1)

        // The account rotates its signing key. The feed generator's cache is
        // stale, the first check fails, and one forced refresh fixes it.
        let rotatedKey = P256Keypair.generate()
        try await directory.publish(Self.document(methods: [
            ("\(Self.account)#atproto", "Multikey", rotatedKey.publicKey.multikey),
        ]))
        let afterRotation = try await proxiedRequest(signedWith: rotatedKey)
        #expect(await feedGenerator.viewer(authorizationHeader: afterRotation) == .success(Self.account))
        #expect(await directory.fetches == 2)
        // The retired key no longer authenticates anyone.
        let stale = try await proxiedRequest(signedWith: accountKey)
        #expect(await feedGenerator.viewer(authorizationHeader: stale) == .failure(.invalidSignature))

        // What the service answers when authentication fails.
        let missing = await feedGenerator.viewer(authorizationHeader: nil)
        guard case let .failure(error) = missing else {
            Issue.record("a request without a token was accepted")
            return
        }
        #expect(error.httpStatus == 401)
        #expect(error.xrpcErrorName == "MissingJwt")
        #expect(error.message == "missing jwt")

        // An issuer whose DID does not resolve.
        let stranger = try await ServiceJWT.bearerAuthorization(ServiceJWT.mint(
            issuer: "did:plc:zzzzzzzzzzzzzzzzzzzzzzzz",
            audience: "did:web:feed.example.com#bsky_fg",
            lexiconMethod: "app.bsky.feed.getFeedSkeleton",
            signer: K256Keypair.generate()
        ))
        guard case let .failure(unresolved) = await feedGenerator.viewer(authorizationHeader: stranger),
              case .keyResolutionFailed = unresolved else {
            Issue.record("an unresolvable issuer was accepted")
            return
        }
    }

    @Test("A labeler's requests verify under its labeling key when the service opts in")
    func labelerKey() async throws {
        let labeler = "did:web:labeler.example.com"
        let signingKey = K256Keypair.generate()
        let labelKey = K256Keypair.generate()
        let directory = Directory()
        try await directory.publish(Self.document(did: labeler, methods: [
            ("\(labeler)#atproto", "Multikey", signingKey.publicKey.multikey),
            ("\(labeler)#atproto_label", "Multikey", labelKey.publicKey.multikey),
        ]))
        let resolver = DIDDocumentServiceAuthKeyResolver { did, forceRefresh in
            try await directory.document(for: did, forceRefresh: forceRefresh)
        }
        let token = try await ServiceJWT.mint(
            issuer: labeler,
            audience: "did:web:appview.example.com#bsky_appview",
            lexiconMethod: "com.atproto.label.queryLabels",
            signer: labelKey,
            keyID: "#atproto_label",
            now: Self.now
        )

        var configuration = ServiceAuthVerifier.Configuration(
            audience: .exactly("did:web:appview.example.com#bsky_appview")
        )
        await #expect(throws: ServiceAuthError.keyNotAccepted(keyID: "#atproto_label")) {
            try await ServiceAuthVerifier(configuration: configuration, keyResolver: resolver)
                .verify(token: token, method: .exactly("com.atproto.label.queryLabels"), now: Self.now)
        }
        configuration.acceptedKeyIDs.insert("#atproto_label")
        let caller = try await ServiceAuthVerifier(configuration: configuration, keyResolver: resolver)
            .verify(token: token, method: .exactly("com.atproto.label.queryLabels"), now: Self.now)
        #expect(caller.issuer == labeler)
        #expect(caller.keyID == "#atproto_label")
        #expect(caller.signingKey == labelKey.publicKey)
    }
}
