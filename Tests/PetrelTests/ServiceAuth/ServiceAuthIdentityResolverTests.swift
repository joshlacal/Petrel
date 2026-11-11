import Foundation
@testable import Petrel
import PetrelCrypto
import Testing

/// `IdentityResolver` as the key source of `ServiceAuthVerifier`: the issuer's
/// DID is resolved over (stubbed) HTTP to its DID document, and the token is
/// verified against the key found there.
@Suite("Service auth: issuer keys through IdentityResolver")
struct ServiceAuthIdentityResolverTests {
    static let account = "did:plc:abcdefghijklmnopqrstuvwx"
    static let labeler = "did:web:labeler.example.com"
    static let audience = "did:web:feed.example.com#bsky_fg"
    static let method = "app.bsky.feed.getFeedSkeleton"

    static func method(_ did: String, _ fragment: String, _ key: ATProtoPublicKey) -> [String: String] {
        ["id": "\(did)\(fragment)", "type": "Multikey", "controller": did, "publicKeyMultibase": key.multikey]
    }

    static func mint(
        _ signer: any ATProtoSigner,
        issuer: String = account,
        lexiconMethod: String = method,
        keyID: String? = nil
    ) async throws -> String {
        try await ServiceJWT.bearerAuthorization(ServiceJWT.mint(
            issuer: issuer, audience: audience, lexiconMethod: lexiconMethod, signer: signer, keyID: keyID
        ))
    }

    @Test("A did:plc issuer is resolved through the PLC directory and verified", arguments: ATProtoKeyCurve.allCases)
    func plcIssuer(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let http = MockIdentityHTTP()
        http.on("plc.directory/\(Self.account)", body: IdentityFixtures.document(
            did: Self.account, verificationMethods: [Self.method(Self.account, "#atproto", keypair.publicKey)]
        ))

        // The snippet from the IdentityResolver conformance documentation.
        let verifier = ServiceAuthVerifier(
            audience: .service(did: "did:web:feed.example.com", id: "bsky_fg", acceptBareDID: true),
            keyResolver: CachingServiceAuthKeyResolver(
                upstream: IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())
            )
        )
        let caller = try await verifier.verify(
            authorizationHeader: try await Self.mint(keypair),
            method: .exactly("app.bsky.feed.getFeedSkeleton")
        )

        #expect(caller.issuer == Self.account)
        #expect(caller.signingKey == keypair.publicKey)
        #expect(caller.algorithm == curve.jwtAlgorithm)
        // A second request from the same account costs no further fetch.
        _ = try await verifier.verify(
            authorizationHeader: try await Self.mint(keypair), method: .exactly(Self.method)
        )
        #expect(http.requestCount(containing: "plc.directory") == 1)
    }

    @Test("After a key rotation, one forced refresh fetches the new DID document")
    func rotation() async throws {
        let oldKey = K256Keypair.generate()
        let newKey = P256Keypair.generate()
        let http = MockIdentityHTTP()
        http.on("plc.directory/\(Self.account)", body: IdentityFixtures.document(
            did: Self.account, verificationMethods: [Self.method(Self.account, "#atproto", oldKey.publicKey)]
        ))
        // The resolver is used directly here, so its own cache is the only one.
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())
        let verifier = ServiceAuthVerifier(audience: .exactly(Self.audience), keyResolver: resolver)

        _ = try await verifier.verify(
            authorizationHeader: try await Self.mint(oldKey), method: .exactly(Self.method)
        )
        #expect(http.requestCount(containing: "plc.directory") == 1)

        // The account rotates; the directory now serves the new key.
        http.on("plc.directory/\(Self.account)", body: IdentityFixtures.document(
            did: Self.account, verificationMethods: [Self.method(Self.account, "#atproto", newKey.publicKey)]
        ))
        let caller = try await verifier.verify(
            authorizationHeader: try await Self.mint(newKey), method: .exactly(Self.method)
        )
        #expect(caller.signingKey == newKey.publicKey)
        #expect(http.requestCount(containing: "plc.directory") == 2)

        // The retired key is refused, at the cost of one more refresh.
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await verifier.verify(
                authorizationHeader: try await Self.mint(oldKey), method: .exactly(Self.method)
            )
        }
        #expect(http.requestCount(containing: "plc.directory") == 3)
    }

    @Test("A did:web labeler signing with #atproto_label is verified when that key is accepted")
    func labelerKey() async throws {
        let signingKey = K256Keypair.generate()
        let labelKey = K256Keypair.generate()
        let http = MockIdentityHTTP()
        http.on("labeler.example.com/.well-known/did.json", body: IdentityFixtures.document(
            did: Self.labeler,
            pds: nil,
            verificationMethods: [
                Self.method(Self.labeler, "#atproto", signingKey.publicKey),
                Self.method(Self.labeler, "#atproto_label", labelKey.publicKey),
            ]
        ))
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())
        let token = try await Self.mint(
            labelKey, issuer: Self.labeler, lexiconMethod: "com.atproto.label.queryLabels", keyID: "#atproto_label"
        )

        var configuration = ServiceAuthVerifier.Configuration(audience: .exactly(Self.audience))
        await #expect(throws: ServiceAuthError.keyNotAccepted(keyID: "#atproto_label")) {
            try await ServiceAuthVerifier(configuration: configuration, keyResolver: resolver)
                .verify(authorizationHeader: token, method: .exactly("com.atproto.label.queryLabels"))
        }
        #expect(http.requests.isEmpty)

        configuration.acceptedKeyIDs.insert("#atproto_label")
        let caller = try await ServiceAuthVerifier(configuration: configuration, keyResolver: resolver)
            .verify(authorizationHeader: token, method: .exactly("com.atproto.label.queryLabels"))
        #expect(caller.issuer == Self.labeler)
        #expect(caller.keyID == "#atproto_label")
        #expect(caller.signingKey == labelKey.publicKey)

        // The same resolver hands out each key under its own identifier.
        #expect(try await resolver.signingKey(for: Self.labeler, forceRefresh: false) == signingKey.publicKey)
        #expect(try await resolver.signingKey(
            for: Self.labeler, keyID: "#atproto_label", forceRefresh: false
        ) == labelKey.publicKey)
    }

    @Test("An issuer that does not resolve, or publishes no usable key, is a key-resolution failure")
    func unresolvable() async throws {
        let keypair = K256Keypair.generate()
        let http = MockIdentityHTTP()
        http.on("plc.directory/\(Self.account)", status: 404, body: #"{"message":"DID not registered"}"#)
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())
        let verifier = ServiceAuthVerifier(audience: .exactly(Self.audience), keyResolver: resolver)

        let error = await #expect(throws: ServiceAuthError.self) {
            try await verifier.verify(
                authorizationHeader: try await Self.mint(keypair), method: .exactly(Self.method)
            )
        }
        guard case let .keyResolutionFailed(did, keyID, _) = error else {
            Issue.record("expected keyResolutionFailed, got \(String(describing: error))")
            return
        }
        #expect(did == Self.account)
        #expect(keyID == "#atproto")
        #expect(error?.xrpcErrorName == "BadJwtSignature")

        // A document without an #atproto verification method.
        http.on("plc.directory/\(Self.account)", body: IdentityFixtures.document(did: Self.account))
        let missingKey = await #expect(throws: ServiceAuthError.self) {
            try await verifier.verify(
                authorizationHeader: try await Self.mint(keypair), method: .exactly(Self.method)
            )
        }
        guard case .keyResolutionFailed = missingKey else {
            Issue.record("expected keyResolutionFailed, got \(String(describing: missingKey))")
            return
        }
    }
}
