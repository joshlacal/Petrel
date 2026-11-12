import Foundation
import PetrelCrypto
import Testing

// MARK: - Fixtures

/// A resolver that records every lookup and can serve a different key once
/// asked to refresh, as a DID-document cache does after a key rotation.
actor RecordingKeyResolver: ServiceAuthKeyResolver {
    struct Lookup: Equatable, Sendable {
        let did: String
        let keyID: String
        let forceRefresh: Bool
    }

    private(set) var lookups: [Lookup] = []
    private let cached: [String: ATProtoPublicKey]
    private let refreshed: [String: ATProtoPublicKey]
    private let failure: (any Error)?

    /// - Parameters:
    ///   - cached: keys by `did + keyID` served without a refresh.
    ///   - refreshed: keys served on a forced refresh; defaults to `cached`.
    init(
        cached: [String: ATProtoPublicKey],
        refreshed: [String: ATProtoPublicKey]? = nil,
        failure: (any Error)? = nil
    ) {
        self.cached = cached
        self.refreshed = refreshed ?? cached
        self.failure = failure
    }

    func signingKey(for did: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        try await signingKey(for: did, keyID: "#atproto", forceRefresh: forceRefresh)
    }

    func signingKey(for did: String, keyID: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        lookups.append(Lookup(did: did, keyID: keyID, forceRefresh: forceRefresh))
        if let failure { throw failure }
        guard let key = (forceRefresh ? refreshed : cached)[did + keyID] else {
            throw ServiceAuthError.keyResolutionFailed(did: did, keyID: keyID, reason: "not in DID document")
        }
        return key
    }
}

enum ServiceAuthFixture {
    static let issuer = "did:plc:abcdefghijklmnopqrstuvwx"
    static let serviceDID = "did:web:feed.example.com"
    static let audience = "did:web:feed.example.com#bsky_fg"
    static let method = "app.bsky.feed.getFeedSkeleton"
    static let now = Date(timeIntervalSince1970: 1_700_000_000)

    static func mint(
        _ signer: any ATProtoSigner,
        issuer: String = issuer,
        audience: String = audience,
        lexiconMethod: String? = method,
        keyID: String? = nil,
        nonce: String? = nil,
        lifetime: TimeInterval = 60
    ) async throws -> String {
        try await ServiceJWT.mint(
            issuer: issuer,
            audience: audience,
            lexiconMethod: lexiconMethod,
            signer: signer,
            keyID: keyID,
            nonce: nonce,
            now: now,
            lifetime: lifetime
        )
    }

    /// Signs an arbitrary header and payload, for tokens `mint` refuses to
    /// produce.
    static func handBuilt(header: String, payload: String, signer: any ATProtoSigner) async throws -> String {
        let input = "\(JWTBase64URL.encode(Data(header.utf8))).\(JWTBase64URL.encode(Data(payload.utf8)))"
        let signature = try await signer.sign(Data(input.utf8))
        return "\(input).\(JWTBase64URL.encode(signature))"
    }

    static func payload(
        iss: String = issuer,
        aud: String = audience,
        exp: Int = 1_700_000_060,
        extra: String = #","iat":1700000000,"lxm":"app.bsky.feed.getFeedSkeleton","jti":"nonce-1""#
    ) -> String {
        #"{"iss":"\#(iss)","aud":"\#(aud)","exp":\#(exp)\#(extra)}"#
    }

    static func verifier(
        for key: ATProtoPublicKey,
        audience: ServiceAuthAudience = .exactly(audience),
        replayStore: (any ServiceAuthReplayStore)? = nil
    ) -> ServiceAuthVerifier {
        ServiceAuthVerifier(
            audience: audience,
            keyResolver: StaticServiceAuthKeyResolver(keys: [issuer: key]),
            replayStore: replayStore
        )
    }

    static func rewritingSignature(_ token: String, _ transform: (Data) throws -> Data) throws -> String {
        let parts = token.split(separator: ".")
        let signature = try JWTBase64URL.decode(String(parts[2]))
        return "\(parts[0]).\(parts[1]).\(JWTBase64URL.encode(try transform(signature)))"
    }
}

// MARK: - Verifier

@Suite("ServiceAuthVerifier: Authorization header to verified caller")
struct ServiceAuthVerifierTests {
    typealias Fixture = ServiceAuthFixture

    @Test("A minted token verifies end to end on both curves", arguments: ATProtoKeyCurve.allCases)
    func roundTrip(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let token = try await Fixture.mint(keypair, nonce: "nonce-1")
        let verifier = Fixture.verifier(for: keypair.publicKey)

        let caller = try await verifier.verify(
            authorizationHeader: ServiceJWT.bearerAuthorization(token),
            method: .exactly(Fixture.method),
            now: Fixture.now
        )

        #expect(caller.issuer == Fixture.issuer)
        #expect(caller.issuerFragment == nil)
        #expect(caller.keyID == "#atproto")
        #expect(caller.audience == Fixture.audience)
        #expect(caller.lexiconMethod == Fixture.method)
        #expect(caller.nonce == "nonce-1")
        #expect(caller.expiresAt == Fixture.now.addingTimeInterval(60))
        #expect(caller.issuedAt == Fixture.now)
        #expect(caller.algorithm == curve.jwtAlgorithm)
        #expect(caller.signingKey == keypair.publicKey)
        #expect(caller.claims.iss == Fixture.issuer)
    }

    @Test("The Authorization header must be a bearer token")
    func authorizationHeader() async throws {
        #expect(throws: ServiceAuthError.missingAuthorization) {
            try ServiceAuthVerifier.bearerToken(fromAuthorizationHeader: nil)
        }
        #expect(throws: ServiceAuthError.missingAuthorization) {
            try ServiceAuthVerifier.bearerToken(fromAuthorizationHeader: "  ")
        }
        for header in ["Basic YWRtaW46cGFzc3dvcmQ=", "Bearer", "Bearer ", "DPoP abc", "abc.def.ghi", "Bearer a b"] {
            #expect(throws: ServiceAuthError.unsupportedAuthorizationScheme, "\(header)") {
                try ServiceAuthVerifier.bearerToken(fromAuthorizationHeader: header)
            }
        }
        // RFC 7235: the scheme name is case-insensitive.
        for header in ["Bearer abc.def.ghi", "bearer abc.def.ghi", "BEARER   abc.def.ghi  "] {
            #expect(try ServiceAuthVerifier.bearerToken(fromAuthorizationHeader: header) == "abc.def.ghi")
        }

        let keypair = P256Keypair.generate()
        let verifier = Fixture.verifier(for: keypair.publicKey)
        await #expect(throws: ServiceAuthError.missingAuthorization) {
            try await verifier.verify(authorizationHeader: nil, method: .optional)
        }
        #expect(ServiceAuthError.missingAuthorization.xrpcErrorName == "MissingJwt")
        #expect(ServiceAuthError.missingAuthorization.httpStatus == 401)
    }

    // MARK: Audience

    @Test("The audience must name this service; a bare DID is opt-in")
    func audience() async throws {
        let keypair = K256Keypair.generate()
        let withFragment = try await Fixture.mint(keypair)
        let bare = try await Fixture.mint(keypair, audience: Fixture.serviceDID)
        let other = try await Fixture.mint(keypair, audience: "did:web:other.example.com#bsky_fg")
        let otherService = try await Fixture.mint(keypair, audience: "did:web:feed.example.com#atproto_labeler")

        let strict = Fixture.verifier(for: keypair.publicKey, audience: .service(did: Fixture.serviceDID, id: "bsky_fg"))
        _ = try await strict.verify(token: withFragment, method: .exactly(Fixture.method), now: Fixture.now)
        for token in [bare, other, otherService] {
            let error = await #expect(throws: ServiceAuthError.self) {
                try await strict.verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
            }
            #expect(error?.xrpcErrorName == "BadJwtAudience")
        }

        // Accepting the bare DID is a choice, and still not a wildcard.
        let lenient = Fixture.verifier(
            for: keypair.publicKey,
            audience: .service(did: Fixture.serviceDID, id: "#bsky_fg", acceptBareDID: true)
        )
        _ = try await lenient.verify(token: withFragment, method: .exactly(Fixture.method), now: Fixture.now)
        _ = try await lenient.verify(token: bare, method: .exactly(Fixture.method), now: Fixture.now)
        await #expect(throws: ServiceAuthError.audienceMismatch(actual: "did:web:feed.example.com#atproto_labeler")) {
            try await lenient.verify(token: otherService, method: .exactly(Fixture.method), now: Fixture.now)
        }

        // Skipping the check has to be asked for by name.
        let unchecked = Fixture.verifier(for: keypair.publicKey, audience: .unchecked)
        _ = try await unchecked.verify(token: other, method: .exactly(Fixture.method), now: Fixture.now)
        #expect(ServiceAuthAudience.anyOf(["a", "b"]).accepts("b"))
        #expect(!ServiceAuthAudience.anyOf(["a", "b"]).accepts("c"))
    }

    // MARK: Lexicon method

    @Test("The lxm policy: exact, exact-if-present, required, optional")
    func lexiconMethod() async throws {
        let keypair = P256Keypair.generate()
        let verifier = Fixture.verifier(for: keypair.publicKey)
        let bound = try await Fixture.mint(keypair)
        let unbound = try await Fixture.mint(keypair, lexiconMethod: nil)
        let otherMethod = "com.atproto.repo.createRecord"

        // exactly: present and equal.
        _ = try await verifier.verify(token: bound, method: .exactly(Fixture.method), now: Fixture.now)
        await #expect(throws: ServiceAuthError.lexiconMethodMismatch(expected: otherMethod, actual: Fixture.method)) {
            try await verifier.verify(token: bound, method: .exactly(otherMethod), now: Fixture.now)
        }
        await #expect(throws: ServiceAuthError.lexiconMethodMismatch(expected: Fixture.method, actual: nil)) {
            try await verifier.verify(token: unbound, method: .exactly(Fixture.method), now: Fixture.now)
        }

        // exactlyIfPresent: a method-less token passes, a wrong method does not.
        _ = try await verifier.verify(token: unbound, method: .exactlyIfPresent(Fixture.method), now: Fixture.now)
        _ = try await verifier.verify(token: bound, method: .exactlyIfPresent(Fixture.method), now: Fixture.now)
        await #expect(throws: ServiceAuthError.lexiconMethodMismatch(expected: otherMethod, actual: Fixture.method)) {
            try await verifier.verify(token: bound, method: .exactlyIfPresent(otherMethod), now: Fixture.now)
        }

        // required: any method, but one must be there.
        let viaRequired = try await verifier.verify(token: bound, method: .required, now: Fixture.now)
        #expect(viaRequired.lexiconMethod == Fixture.method)
        await #expect(throws: ServiceAuthError.lexiconMethodMismatch(expected: nil, actual: nil)) {
            try await verifier.verify(token: unbound, method: .required, now: Fixture.now)
        }

        // optional: a method-less token is verified and reported as such.
        let viaOptional = try await verifier.verify(token: unbound, method: .optional, now: Fixture.now)
        #expect(viaOptional.lexiconMethod == nil)
        #expect(viaOptional.issuer == Fixture.issuer)

        #expect(ServiceAuthError.lexiconMethodMismatch(expected: "a.b.c", actual: nil).xrpcErrorName == "BadJwtLexiconMethod")
        #expect(ServiceAuthError.lexiconMethodMismatch(expected: "a.b.c", actual: nil).message.hasPrefix("missing jwt lexicon method"))
        #expect(ServiceAuthError.lexiconMethodMismatch(expected: "a.b.c", actual: "x.y.z").message.hasPrefix("bad jwt lexicon method"))
    }

    // MARK: Header

    @Test(
        "Tokens of another kind are refused even when validly signed",
        arguments: ["at+jwt", "refresh+jwt", "dpop+jwt", "AT+JWT"]
    )
    func disallowedTypes(_ type: String) async throws {
        let keypair = K256Keypair.generate()
        let token = try await Fixture.handBuilt(
            header: #"{"typ":"\#(type)","alg":"ES256K"}"#, payload: Fixture.payload(), signer: keypair
        )
        let error = await #expect(throws: ServiceAuthError.self) {
            try await Fixture.verifier(for: keypair.publicKey)
                .verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
        }
        #expect(error == .disallowedTokenType(type))
        #expect(error?.xrpcErrorName == "BadJwtType")
    }

    @Test("Only ES256 and ES256K are accepted, and only for a key on that curve")
    func algorithms() async throws {
        let k256 = K256Keypair.generate()
        let p256 = P256Keypair.generate()

        for algorithm in ["none", "HS256", "RS256", "EdDSA", "es256k"] {
            let token = try await Fixture.handBuilt(
                header: #"{"typ":"JWT","alg":"\#(algorithm)"}"#, payload: Fixture.payload(), signer: k256
            )
            let resolver = RecordingKeyResolver(cached: [Fixture.issuer + "#atproto": k256.publicKey])
            let verifier = ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: resolver)
            await #expect(throws: ServiceAuthError.unsupportedAlgorithm(algorithm)) {
                try await verifier.verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
            }
            // An unusable algorithm never costs a DID resolution.
            #expect(await resolver.lookups.isEmpty)
        }

        // A K-256 signature labelled ES256, checked against the K-256 key.
        let mislabelled = try await Fixture.handBuilt(
            header: #"{"typ":"JWT","alg":"ES256"}"#, payload: Fixture.payload(), signer: k256
        )
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await Fixture.verifier(for: k256.publicKey)
                .verify(token: mislabelled, method: .exactly(Fixture.method), now: Fixture.now)
        }
        // An honest ES256 token checked against a K-256 key.
        let es256 = try await Fixture.mint(p256)
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await Fixture.verifier(for: k256.publicKey)
                .verify(token: es256, method: .exactly(Fixture.method), now: Fixture.now)
        }
        #expect(ServiceAuthError.invalidSignature.xrpcErrorName == "BadJwtSignature")
        #expect(ServiceAuthError.unsupportedAlgorithm("none").xrpcErrorName == "BadJwtSignature")
    }

    // MARK: Time

    @Test("Expiry is enforced with a small, configurable clock skew")
    func expiry() async throws {
        let keypair = P256Keypair.generate()
        let token = try await Fixture.mint(keypair) // exp = now + 60
        let verifier = Fixture.verifier(for: keypair.publicKey)
        let exp = Fixture.now.addingTimeInterval(60)

        // Default skew is 5 seconds.
        _ = try await verifier.verify(token: token, method: .exactly(Fixture.method), now: exp)
        _ = try await verifier.verify(token: token, method: .exactly(Fixture.method), now: exp.addingTimeInterval(5))
        await #expect(throws: ServiceAuthError.expired) {
            try await verifier.verify(token: token, method: .exactly(Fixture.method), now: exp.addingTimeInterval(6))
        }
        #expect(ServiceAuthError.expired.xrpcErrorName == "JwtExpired")

        // No skew: the reference's behaviour.
        var exact = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
        exact.clockSkew = 0
        let strict = ServiceAuthVerifier(
            configuration: exact, keyResolver: StaticServiceAuthKeyResolver(keys: [Fixture.issuer: keypair.publicKey])
        )
        _ = try await strict.verify(token: token, method: .exactly(Fixture.method), now: exp)
        await #expect(throws: ServiceAuthError.expired) {
            try await strict.verify(token: token, method: .exactly(Fixture.method), now: exp.addingTimeInterval(1))
        }

        // A nonsensical skew is treated as none, not as unlimited.
        exact.clockSkew = .infinity
        let broken = ServiceAuthVerifier(
            configuration: exact, keyResolver: StaticServiceAuthKeyResolver(keys: [Fixture.issuer: keypair.publicKey])
        )
        await #expect(throws: ServiceAuthError.expired) {
            try await broken.verify(token: token, method: .exactly(Fixture.method), now: exp.addingTimeInterval(1))
        }
    }

    @Test("Every lifetime a reference PDS issues is accepted by default; the ceiling is configurable")
    func lifetimeCeiling() async throws {
        let keypair = K256Keypair.generate()
        let resolver = StaticServiceAuthKeyResolver(keys: [Fixture.issuer: keypair.publicKey])
        let verifier = ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: resolver)
        #expect(verifier.configuration.maximumLifetime == 3600)

        // 60 s (default), 30 min (what the official app requests for
        // uploadBlob), 1 h (the most getServiceAuth grants).
        for lifetime: TimeInterval in [60, 1800, 3600] {
            let token = try await Fixture.mint(keypair, lifetime: lifetime)
            let caller = try await verifier.verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
            #expect(caller.expiresAt == Fixture.now.addingTimeInterval(lifetime))
            // Still good one second before it expires.
            _ = try await verifier.verify(
                token: token, method: .exactly(Fixture.method), now: Fixture.now.addingTimeInterval(lifetime - 1)
            )
        }

        // Longer than the ceiling: refused, whether or not iat is present.
        let twoHours = try await Fixture.handBuilt(
            header: #"{"typ":"JWT","alg":"ES256K"}"#,
            payload: Fixture.payload(exp: 1_700_007_200),
            signer: keypair
        )
        await #expect(throws: ServiceAuthError.excessiveLifetime(maximum: 3600)) {
            try await verifier.verify(token: twoHours, method: .exactly(Fixture.method), now: Fixture.now)
        }
        let twoHoursNoIssuedAt = try await Fixture.handBuilt(
            header: #"{"typ":"JWT","alg":"ES256K"}"#,
            payload: Fixture.payload(exp: 1_700_007_200, extra: #","lxm":"app.bsky.feed.getFeedSkeleton""#),
            signer: keypair
        )
        await #expect(throws: ServiceAuthError.excessiveLifetime(maximum: 3600)) {
            try await verifier.verify(token: twoHoursNoIssuedAt, method: .exactly(Fixture.method), now: Fixture.now)
        }
        // A backdated iat cannot hide a long lifetime.
        let backdated = try await Fixture.handBuilt(
            header: #"{"typ":"JWT","alg":"ES256K"}"#,
            payload: Fixture.payload(
                exp: 1_700_000_060, extra: #","iat":1699990000,"lxm":"app.bsky.feed.getFeedSkeleton""#
            ),
            signer: keypair
        )
        await #expect(throws: ServiceAuthError.excessiveLifetime(maximum: 3600)) {
            try await verifier.verify(token: backdated, method: .exactly(Fixture.method), now: Fixture.now)
        }

        // The ceiling can be raised...
        var raised = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
        raised.maximumLifetime = 3 * 60 * 60
        _ = try await ServiceAuthVerifier(configuration: raised, keyResolver: resolver)
            .verify(token: twoHours, method: .exactly(Fixture.method), now: Fixture.now)

        // ...or lowered for endpoints that should only see short tokens.
        var lowered = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
        lowered.maximumLifetime = 5 * 60
        let short = ServiceAuthVerifier(configuration: lowered, keyResolver: resolver)
        _ = try await short.verify(
            token: try await Fixture.mint(keypair, lifetime: 60), method: .exactly(Fixture.method), now: Fixture.now
        )
        await #expect(throws: ServiceAuthError.excessiveLifetime(maximum: 300)) {
            try await short.verify(
                token: try await Fixture.mint(keypair, lifetime: 30 * 60),
                method: .exactly(Fixture.method),
                now: Fixture.now
            )
        }

        // An unusable ceiling refuses everything rather than nothing.
        var broken = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
        broken.maximumLifetime = .nan
        await #expect(throws: ServiceAuthError.excessiveLifetime(maximum: 0)) {
            try await ServiceAuthVerifier(configuration: broken, keyResolver: resolver).verify(
                token: try await Fixture.mint(keypair), method: .exactly(Fixture.method), now: Fixture.now
            )
        }
        #expect(ServiceAuthError.excessiveLifetime(maximum: 3600).xrpcErrorName == "BadJwt")
    }

    @Test("iat bounds the lifetime but is not compared with the clock")
    func issuedAtIsInformational() async throws {
        let keypair = P256Keypair.generate()
        let verifier = Fixture.verifier(for: keypair.publicKey)
        // Issuer clock 20 s ahead of ours: iat in our future.
        let ahead = try await Fixture.handBuilt(
            header: #"{"typ":"JWT","alg":"ES256"}"#,
            payload: Fixture.payload(
                exp: 1_700_000_080, extra: #","iat":1700000020,"lxm":"app.bsky.feed.getFeedSkeleton""#
            ),
            signer: keypair
        )
        _ = try await verifier.verify(token: ahead, method: .exactly(Fixture.method), now: Fixture.now)

        let inverted = try await Fixture.handBuilt(
            header: #"{"typ":"JWT","alg":"ES256"}"#,
            payload: Fixture.payload(
                exp: 1_700_000_060, extra: #","iat":1700000100,"lxm":"app.bsky.feed.getFeedSkeleton""#
            ),
            signer: keypair
        )
        await #expect(throws: ServiceAuthError.malformedToken("exp is earlier than iat")) {
            try await verifier.verify(token: inverted, method: .exactly(Fixture.method), now: Fixture.now)
        }
    }

    // MARK: Key resolution and rotation

    @Test("A signature failure triggers exactly one forced refresh", arguments: ATProtoKeyCurve.allCases)
    func keyRotation(_ curve: ATProtoKeyCurve) async throws {
        let oldKey = ATProtoCrypto.generateKeypair(curve: curve)
        let newKey = ATProtoCrypto.generateKeypair(curve: curve)
        let token = try await Fixture.mint(newKey)
        let slot = Fixture.issuer + "#atproto"

        // The cache still holds the old key; the DID document has the new one.
        let rotated = RecordingKeyResolver(cached: [slot: oldKey.publicKey], refreshed: [slot: newKey.publicKey])
        let caller = try await ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: rotated)
            .verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
        #expect(caller.signingKey == newKey.publicKey)
        #expect(await rotated.lookups == [
            .init(did: Fixture.issuer, keyID: "#atproto", forceRefresh: false),
            .init(did: Fixture.issuer, keyID: "#atproto", forceRefresh: true),
        ])

        // Cache already current: one lookup, no refresh.
        let current = RecordingKeyResolver(cached: [slot: newKey.publicKey])
        _ = try await ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: current)
            .verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
        #expect(await current.lookups == [.init(did: Fixture.issuer, keyID: "#atproto", forceRefresh: false)])

        // Not the issuer's key at all: one refresh, then a signature error.
        let stranger = RecordingKeyResolver(cached: [slot: oldKey.publicKey])
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: stranger)
                .verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
        }
        #expect(await stranger.lookups.map(\.forceRefresh) == [false, true])
    }

    @Test("A rotation to the other curve is followed too")
    func keyRotationAcrossCurves() async throws {
        let oldKey = K256Keypair.generate()
        let newKey = P256Keypair.generate()
        let token = try await Fixture.mint(newKey)
        let slot = Fixture.issuer + "#atproto"
        let resolver = RecordingKeyResolver(cached: [slot: oldKey.publicKey], refreshed: [slot: newKey.publicKey])

        let caller = try await ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: resolver)
            .verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
        #expect(caller.algorithm == "ES256")
        #expect(await resolver.lookups.map(\.forceRefresh) == [false, true])
    }

    @Test("Checks that need no key run before the issuer is resolved")
    func cheapChecksFirst() async throws {
        let keypair = K256Keypair.generate()
        let resolver = RecordingKeyResolver(cached: [Fixture.issuer + "#atproto": keypair.publicKey])
        let verifier = ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: resolver)

        let expired = try await Fixture.mint(keypair)
        await #expect(throws: ServiceAuthError.expired) {
            try await verifier.verify(
                token: expired, method: .exactly(Fixture.method), now: Fixture.now.addingTimeInterval(600)
            )
        }
        let wrongAudience = try await Fixture.mint(keypair, audience: "did:web:other.example.com")
        await #expect(throws: ServiceAuthError.audienceMismatch(actual: "did:web:other.example.com")) {
            try await verifier.verify(token: wrongAudience, method: .exactly(Fixture.method), now: Fixture.now)
        }
        #expect(await resolver.lookups.isEmpty)
    }

    @Test("A resolver failure is reported as such, not as a bad signature")
    func resolverFailure() async throws {
        struct Offline: Error, CustomStringConvertible {
            var description: String { "plc.directory unreachable" }
        }
        let keypair = K256Keypair.generate()
        let token = try await Fixture.mint(keypair)

        let offline = RecordingKeyResolver(cached: [:], failure: Offline())
        let error = await #expect(throws: ServiceAuthError.self) {
            try await ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: offline)
                .verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
        }
        #expect(error == .keyResolutionFailed(
            did: Fixture.issuer, keyID: "#atproto", reason: "plc.directory unreachable"
        ))
        #expect(error?.xrpcErrorName == "BadJwtSignature")

        // An issuer the table does not know.
        await #expect(throws: ServiceAuthError.keyResolutionFailed(
            did: Fixture.issuer, keyID: "#atproto", reason: "no key on record"
        )) {
            try await ServiceAuthVerifier(
                audience: .exactly(Fixture.audience), keyResolver: StaticServiceAuthKeyResolver(keys: [:])
            ).verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
        }
    }

    // MARK: Key identifiers

    @Test("kid selects a published key, and only keys the service accepts")
    func keyIdentifier() async throws {
        let accountKey = K256Keypair.generate()
        let labelKey = K256Keypair.generate()
        let resolver = RecordingKeyResolver(cached: [
            Fixture.issuer + "#atproto": accountKey.publicKey,
            Fixture.issuer + "#atproto_label": labelKey.publicKey,
        ])

        let labelToken = try await Fixture.mint(labelKey, keyID: "#atproto_label")
        #expect(try ServiceJWT.inspect(labelToken).keyID == "#atproto_label")
        #expect(try ServiceJWT.inspect(labelToken).effectiveKeyID == "#atproto_label")

        // By default only #atproto is accepted.
        let defaultVerifier = ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: resolver)
        await #expect(throws: ServiceAuthError.keyNotAccepted(keyID: "#atproto_label")) {
            try await defaultVerifier.verify(token: labelToken, method: .exactly(Fixture.method), now: Fixture.now)
        }
        #expect(await resolver.lookups.isEmpty)

        // A service that expects labeler tokens opts in.
        var configuration = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
        configuration.acceptedKeyIDs = ["#atproto", "#atproto_label"]
        let labelVerifier = ServiceAuthVerifier(configuration: configuration, keyResolver: resolver)
        let caller = try await labelVerifier.verify(
            token: labelToken, method: .exactly(Fixture.method), now: Fixture.now
        )
        #expect(caller.keyID == "#atproto_label")
        #expect(caller.signingKey == labelKey.publicKey)
        #expect(await resolver.lookups == [
            .init(did: Fixture.issuer, keyID: "#atproto_label", forceRefresh: false),
        ])

        // Naming a key does not let another key's signature through.
        let forged = try await Fixture.mint(accountKey, keyID: "#atproto_label")
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await labelVerifier.verify(token: forged, method: .exactly(Fixture.method), now: Fixture.now)
        }

        // An explicit default kid is the default.
        let explicit = try await Fixture.mint(accountKey, keyID: "#atproto")
        #expect(try await defaultVerifier.verify(
            token: explicit, method: .exactly(Fixture.method), now: Fixture.now
        ).keyID == "#atproto")

        // kid is a fragment, never a DID URL.
        for keyID in ["atproto", "did:plc:abcdefghijklmnopqrstuvwx#atproto", "#", "#a b"] {
            let token = try await Fixture.handBuilt(
                header: #"{"typ":"JWT","alg":"ES256K","kid":"\#(keyID)"}"#, payload: Fixture.payload(), signer: accountKey
            )
            let error = await #expect(throws: ServiceAuthError.self, "\(keyID)") {
                try await labelVerifier.verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
            }
            #expect(error?.xrpcErrorName == "BadJwt")
            await #expect(throws: PetrelCryptoError.self, "\(keyID)") {
                try await Fixture.mint(accountKey, keyID: keyID)
            }
        }

        // A resolver that only knows #atproto refuses other keys by default.
        struct AtprotoOnly: ServiceAuthKeyResolver {
            let key: ATProtoPublicKey
            func signingKey(for _: String, forceRefresh _: Bool) async throws -> ATProtoPublicKey { key }
        }
        await #expect(throws: ServiceAuthError.keyNotAccepted(keyID: "#atproto_label")) {
            try await ServiceAuthVerifier(configuration: configuration, keyResolver: AtprotoOnly(key: labelKey.publicKey))
                .verify(token: labelToken, method: .exactly(Fixture.method), now: Fixture.now)
        }
    }

    @Test("A legacy issuer fragment is surfaced, and can select a key")
    func legacyIssuerFragment() async throws {
        let accountKey = K256Keypair.generate()
        let labelKey = K256Keypair.generate()
        let legacyIssuer = Fixture.issuer + "#atproto_labeler"
        let resolver = RecordingKeyResolver(cached: [
            Fixture.issuer + "#atproto": accountKey.publicKey,
            Fixture.issuer + "#atproto_label": labelKey.publicKey,
        ])

        // Signed with the account key: verifies as the account, fragment reported.
        let byAccount = try await Fixture.mint(accountKey, issuer: legacyIssuer)
        let plain = ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: resolver)
        let caller = try await plain.verify(token: byAccount, method: .exactly(Fixture.method), now: Fixture.now)
        #expect(caller.issuer == Fixture.issuer)
        #expect(caller.issuerFragment == "atproto_labeler")
        #expect(caller.keyID == "#atproto")
        #expect(caller.claims.iss == legacyIssuer)
        #expect(try ServiceJWT.inspect(byAccount).issuerDID == Fixture.issuer)
        #expect(try ServiceJWT.inspect(byAccount).issuerFragment == "atproto_labeler")

        // Signed with the labeling key, as the reference AppView expects of
        // `…#atproto_labeler` issuers: needs the mapping.
        let byLabelKey = try await Fixture.mint(labelKey, issuer: legacyIssuer)
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await plain.verify(token: byLabelKey, method: .exactly(Fixture.method), now: Fixture.now)
        }
        var configuration = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
        configuration.issuerFragmentKeyIDs = ["atproto_labeler": "#atproto_label"]
        let mapped = try await ServiceAuthVerifier(configuration: configuration, keyResolver: resolver)
            .verify(token: byLabelKey, method: .exactly(Fixture.method), now: Fixture.now)
        #expect(mapped.keyID == "#atproto_label")
        #expect(mapped.issuerFragment == "atproto_labeler")

        // The mapping does not widen what a plain account token may use.
        let plainWithLabelKey = try await Fixture.mint(labelKey)
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await ServiceAuthVerifier(configuration: configuration, keyResolver: resolver)
                .verify(token: plainWithLabelKey, method: .exactly(Fixture.method), now: Fixture.now)
        }
    }

    @Test("The issuer must be a DID")
    func issuerSyntax() async throws {
        let keypair = K256Keypair.generate()
        let verifier = Fixture.verifier(for: keypair.publicKey)
        for issuer in ["alice.example.com", "did:plc:short", "did:web:example.com:path", "did:plc:abcdefghijklmnopqrstuvwx#", "did:plc:abcdefghijklmnopqrstuvwx#a#b"] {
            let token = try await Fixture.handBuilt(
                header: #"{"typ":"JWT","alg":"ES256K"}"#, payload: Fixture.payload(iss: issuer), signer: keypair
            )
            let error = await #expect(throws: ServiceAuthError.self, "\(issuer)") {
                try await verifier.verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
            }
            #expect(error == .invalidIssuer(issuer))
            #expect(error?.xrpcErrorName == "BadJwtIss")
        }
        // did:web on localhost (with a port) is allowed for development.
        for issuer in ["did:web:localhost", "did:web:localhost%3A2583", "did:web:pds.example.com", "did:example:iss"] {
            let token = try await Fixture.handBuilt(
                header: #"{"typ":"JWT","alg":"ES256K"}"#, payload: Fixture.payload(iss: issuer), signer: keypair
            )
            let caller = try await ServiceAuthVerifier(
                audience: .exactly(Fixture.audience),
                keyResolver: StaticServiceAuthKeyResolver(keys: [issuer: keypair.publicKey])
            ).verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
            #expect(caller.issuer == issuer)
        }
    }

    // MARK: Signature encoding

    @Test("High-S signatures are accepted, as the specification requires for JWTs", arguments: ATProtoKeyCurve.allCases)
    func highS(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let token = try await Fixture.mint(keypair)
        let highS = try Fixture.rewritingSignature(token) { signature in
            // (r, s) -> (r, n - s)
            let order: [UInt8] = curve == .k256
                ? [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
                   0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B, 0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41]
                : [0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                   0xBC, 0xE6, 0xFA, 0xAD, 0xA7, 0x17, 0x9E, 0x84, 0xF3, 0xB9, 0xCA, 0xC2, 0xFC, 0x63, 0x25, 0x51]
            var s = [UInt8](signature.suffix(32))
            var borrow = 0
            for index in stride(from: 31, through: 0, by: -1) {
                let difference = Int(order[index]) - Int(s[index]) - borrow
                s[index] = UInt8(truncatingIfNeeded: difference & 0xFF)
                borrow = difference < 0 ? 1 : 0
            }
            return signature.prefix(32) + Data(s)
        }
        #expect(highS != token)
        let rewritten = try JWTBase64URL.decode(String(highS.split(separator: ".")[2]))
        #expect(!ATProtoSignature.isLowS(rewritten, curve: curve))

        let verifier = Fixture.verifier(for: keypair.publicKey)
        let caller = try await verifier.verify(token: highS, method: .exactly(Fixture.method), now: Fixture.now)
        #expect(caller.issuer == Fixture.issuer)

        // Demanding low-S is possible, but is not the default.
        var configuration = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
        configuration.signatureOptions = .strict
        let strict = ServiceAuthVerifier(
            configuration: configuration,
            keyResolver: StaticServiceAuthKeyResolver(keys: [Fixture.issuer: keypair.publicKey])
        )
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await strict.verify(token: highS, method: .exactly(Fixture.method), now: Fixture.now)
        }
        _ = try await strict.verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
    }

    @Test("A tampered payload or signature never verifies", arguments: ATProtoKeyCurve.allCases)
    func tampering(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let verifier = Fixture.verifier(for: keypair.publicKey)
        let token = try await Fixture.mint(keypair)
        let parts = token.split(separator: ".").map(String.init)

        let flipped = try Fixture.rewritingSignature(token) { signature in
            var bytes = signature
            bytes[10] ^= 0x01
            return bytes
        }
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await verifier.verify(token: flipped, method: .exactly(Fixture.method), now: Fixture.now)
        }

        // Same claims, different issuer, original signature.
        let otherIssuer = "did:plc:zzzzzzzzzzzzzzzzzzzzzzzz"
        let payload = JWTBase64URL.encode(Data(Fixture.payload(iss: otherIssuer).utf8))
        let swapped = "\(parts[0]).\(payload).\(parts[2])"
        let resolver = StaticServiceAuthKeyResolver(keys: [otherIssuer: keypair.publicKey])
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: resolver)
                .verify(token: swapped, method: .exactly(Fixture.method), now: Fixture.now)
        }
    }

    // MARK: Malformed input

    @Test("Malformed tokens and duplicate-key JSON are refused as BadJwt")
    func malformed() async throws {
        let keypair = K256Keypair.generate()
        let verifier = Fixture.verifier(for: keypair.publicKey)
        let header = #"{"typ":"JWT","alg":"ES256K"}"#
        let good = try await Fixture.mint(keypair)
        let parts = good.split(separator: ".").map(String.init)

        var tokens: [String] = [
            "",
            "abc",
            "a.b",
            "a.b.c.d",
            "\(parts[0]).\(parts[1]).",
            "\(parts[0])..\(parts[2])",
            "\(parts[0]).\(parts[1]).\(parts[2])=",
            "\(parts[0]).\(parts[1]).\(String(parts[2].dropLast(4)))",
            "\(JWTBase64URL.encode(Data("[]".utf8))).\(parts[1]).\(parts[2])",
            "\(JWTBase64URL.encode(Data(#"{"typ":"JWT"}"#.utf8))).\(parts[1]).\(parts[2])",
            String(repeating: "a", count: ServiceJWT.maximumCompactBytes + 1),
        ]
        // Duplicate members, in the payload and in the header.
        tokens.append(try await Fixture.handBuilt(
            header: header,
            payload: #"{"iss":"did:plc:abcdefghijklmnopqrstuvwx","aud":"did:web:evil.example.com","aud":"did:web:feed.example.com#bsky_fg","exp":1700000060,"lxm":"app.bsky.feed.getFeedSkeleton"}"#,
            signer: keypair
        ))
        tokens.append(try await Fixture.handBuilt(
            header: #"{"typ":"JWT","alg":"none","alg":"ES256K"}"#, payload: Fixture.payload(), signer: keypair
        ))
        // Missing or mistyped required claims.
        for payload in [
            #"{"aud":"did:web:feed.example.com#bsky_fg","exp":1700000060}"#,
            #"{"iss":"did:plc:abcdefghijklmnopqrstuvwx","exp":1700000060}"#,
            #"{"iss":"did:plc:abcdefghijklmnopqrstuvwx","aud":"did:web:feed.example.com#bsky_fg"}"#,
            #"{"iss":"did:plc:abcdefghijklmnopqrstuvwx","aud":"did:web:feed.example.com#bsky_fg","exp":"soon"}"#,
            #"{"iss":"did:plc:abcdefghijklmnopqrstuvwx","aud":["did:web:feed.example.com#bsky_fg"],"exp":1700000060}"#,
            "not json",
        ] {
            tokens.append(try await Fixture.handBuilt(header: header, payload: payload, signer: keypair))
        }
        // Unsupported critical header parameters.
        tokens.append(try await Fixture.handBuilt(
            header: #"{"typ":"JWT","alg":"ES256K","crit":["b64"],"b64":false}"#, payload: Fixture.payload(), signer: keypair
        ))
        // lxm present but not an NSID, with a policy that does not compare it.
        let badMethod = try await Fixture.handBuilt(
            header: header, payload: Fixture.payload(extra: #","lxm":"not an nsid""#), signer: keypair
        )

        for token in tokens {
            let error = await #expect(throws: ServiceAuthError.self, "\(token.prefix(60))") {
                try await verifier.verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
            }
            #expect(error?.xrpcErrorName == "BadJwt", "\(token.prefix(60)): \(String(describing: error))")
        }
        await #expect(throws: ServiceAuthError.malformedToken("lxm is not an NSID")) {
            try await verifier.verify(token: badMethod, method: .optional, now: Fixture.now)
        }
    }

    @Test("Claims the specification requires can be insisted on")
    func requiredClaims() async throws {
        let keypair = P256Keypair.generate()
        let resolver = StaticServiceAuthKeyResolver(keys: [Fixture.issuer: keypair.publicKey])
        // What the reference test "interoperates with jwts signed by other
        // libraries" sends: no typ, iat, jti or lxm.
        let minimal = try await Fixture.handBuilt(
            header: #"{"alg":"ES256"}"#, payload: Fixture.payload(extra: ""), signer: keypair
        )

        let reference = ServiceAuthVerifier(audience: .exactly(Fixture.audience), keyResolver: resolver)
        let caller = try await reference.verify(token: minimal, method: .optional, now: Fixture.now)
        #expect(caller.nonce == nil)
        #expect(caller.issuedAt == nil)

        for (requirement, claim) in [
            (ServiceAuthRequiredClaims.type, "typ"), (.issuedAt, "iat"), (.nonce, "jti"), (.specification, "typ"),
        ] {
            var configuration = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
            configuration.requiredClaims = requirement
            await #expect(throws: ServiceAuthError.missingClaim(claim)) {
                try await ServiceAuthVerifier(configuration: configuration, keyResolver: resolver)
                    .verify(token: minimal, method: .optional, now: Fixture.now)
            }
        }

        // A minted token satisfies the full specification set.
        var strict = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
        strict.requiredClaims = .specification
        _ = try await ServiceAuthVerifier(configuration: strict, keyResolver: resolver)
            .verify(token: try await Fixture.mint(keypair), method: .exactly(Fixture.method), now: Fixture.now)
    }

    // MARK: Replay

    @Test("With a replay store a token is accepted once")
    func replay() async throws {
        let keypair = K256Keypair.generate()
        let store = InMemoryServiceAuthReplayStore(clock: { Fixture.now })
        let verifier = Fixture.verifier(for: keypair.publicKey, replayStore: store)
        let token = try await Fixture.mint(keypair)

        let first = try await verifier.verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
        #expect(first.nonce != nil)
        await #expect(throws: ServiceAuthError.replayed) {
            try await verifier.verify(token: token, method: .exactly(Fixture.method), now: Fixture.now)
        }
        #expect(ServiceAuthError.replayed.xrpcErrorName == "BadJwt")

        // A fresh token from the same issuer is unaffected.
        _ = try await verifier.verify(
            token: try await Fixture.mint(keypair), method: .exactly(Fixture.method), now: Fixture.now
        )
        #expect(await store.count == 2)

        // The same nonce from another issuer is a different token.
        let otherIssuer = "did:plc:zzzzzzzzzzzzzzzzzzzzzzzz"
        let otherKey = K256Keypair.generate()
        let shared = ServiceAuthVerifier(
            audience: .exactly(Fixture.audience),
            keyResolver: StaticServiceAuthKeyResolver(keys: [Fixture.issuer: keypair.publicKey, otherIssuer: otherKey.publicKey]),
            replayStore: store
        )
        _ = try await shared.verify(
            token: try await Fixture.mint(keypair, nonce: "same"), method: .exactly(Fixture.method), now: Fixture.now
        )
        _ = try await shared.verify(
            token: try await Fixture.mint(otherKey, issuer: otherIssuer, nonce: "same"),
            method: .exactly(Fixture.method),
            now: Fixture.now
        )

        // Without a jti there is nothing to deduplicate on, so the token is refused.
        let noNonce = try await Fixture.handBuilt(
            header: #"{"typ":"JWT","alg":"ES256K"}"#,
            payload: Fixture.payload(extra: #","lxm":"app.bsky.feed.getFeedSkeleton""#),
            signer: keypair
        )
        await #expect(throws: ServiceAuthError.missingClaim("jti")) {
            try await verifier.verify(token: noNonce, method: .exactly(Fixture.method), now: Fixture.now)
        }
    }

    @Test("A token cannot be replayed during its last accepted second", arguments: [0.0, 5.0, 5.5])
    func replayThroughLastAcceptedSecond(skew: TimeInterval) async throws {
        // The expiry check compares whole seconds, so with skew s a token
        // with `exp` is accepted until just before exp + floor(s) + 1. The
        // replay record must last at least that long.
        let keypair = K256Keypair.generate()
        let token = try await Fixture.mint(keypair) // exp = now + 60
        let exp = Fixture.now.addingTimeInterval(60)
        let lastSecond = exp.addingTimeInterval(skew.rounded(.down))
        let clock = ServiceAuthSupportTests.Clock(lastSecond)
        let store = InMemoryServiceAuthReplayStore(clock: { clock.now })
        var configuration = ServiceAuthVerifier.Configuration(audience: .exactly(Fixture.audience))
        configuration.clockSkew = skew
        let verifier = ServiceAuthVerifier(
            configuration: configuration,
            keyResolver: StaticServiceAuthKeyResolver(keys: [Fixture.issuer: keypair.publicKey]),
            replayStore: store
        )

        _ = try await verifier.verify(token: token, method: .exactly(Fixture.method), now: lastSecond)
        for offset in [0.0, 0.5, 0.999] {
            clock.advance(offset - (clock.now.timeIntervalSince(lastSecond)))
            await #expect(throws: ServiceAuthError.replayed) {
                try await verifier.verify(token: token, method: .exactly(Fixture.method), now: clock.now)
            }
        }
        // One whole second later the token has expired on its own.
        clock.advance(1.0 - clock.now.timeIntervalSince(lastSecond))
        await #expect(throws: ServiceAuthError.expired) {
            try await verifier.verify(token: token, method: .exactly(Fixture.method), now: clock.now)
        }
    }

    @Test("Only authentic tokens reach the replay store")
    func replayStoreSeesOnlyVerifiedTokens() async throws {
        let keypair = K256Keypair.generate()
        let attacker = K256Keypair.generate()
        let store = InMemoryServiceAuthReplayStore(clock: { Fixture.now })
        let verifier = Fixture.verifier(for: keypair.publicKey, replayStore: store)

        // A forged token carrying the nonce the real one will use.
        let forged = try await Fixture.mint(attacker, nonce: "target")
        await #expect(throws: ServiceAuthError.invalidSignature) {
            try await verifier.verify(token: forged, method: .exactly(Fixture.method), now: Fixture.now)
        }
        #expect(await store.count == 0)
        // The real token is not locked out by it.
        _ = try await verifier.verify(
            token: try await Fixture.mint(keypair, nonce: "target"), method: .exactly(Fixture.method), now: Fixture.now
        )

        // A store that is down fails the request rather than waving it through.
        struct Down: ServiceAuthReplayStore {
            struct Unavailable: Error, CustomStringConvertible { var description: String { "redis down" } }
            func claim(nonce _: String, issuer _: String, expiresAt _: Date) async throws -> Bool {
                throw Unavailable()
            }
        }
        await #expect(throws: ServiceAuthError.replayStoreFailed("redis down")) {
            try await Fixture.verifier(for: keypair.publicKey, replayStore: Down())
                .verify(token: try await Fixture.mint(keypair), method: .exactly(Fixture.method), now: Fixture.now)
        }
    }
}

// MARK: - Minting

@Suite("ServiceJWT.mint: tokens as the specification describes them")
struct ServiceJWTMintTests {
    typealias Fixture = ServiceAuthFixture

    private func decodedSegments(_ token: String) throws -> (header: [String: Any], payload: [String: Any]) {
        let parts = token.split(separator: ".")
        let header = try JSONSerialization.jsonObject(with: JWTBase64URL.decode(String(parts[0]))) as? [String: Any]
        let payload = try JSONSerialization.jsonObject(with: JWTBase64URL.decode(String(parts[1]))) as? [String: Any]
        return (try #require(header), try #require(payload))
    }

    @Test("Header and claims carry exactly the specified fields", arguments: ATProtoKeyCurve.allCases)
    func fields(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let token = try await Fixture.mint(keypair)
        let (header, payload) = try decodedSegments(token)

        #expect(header["alg"] as? String == curve.jwtAlgorithm)
        #expect(header["typ"] as? String == "JWT")
        #expect(header["kid"] == nil)
        #expect(Set(header.keys) == ["alg", "typ"])

        #expect(payload["iss"] as? String == Fixture.issuer)
        #expect(payload["aud"] as? String == Fixture.audience)
        #expect(payload["lxm"] as? String == Fixture.method)
        #expect(payload["iat"] as? Int == 1_700_000_000)
        #expect(payload["exp"] as? Int == 1_700_000_060)
        #expect(Set(payload.keys) == ["iss", "aud", "lxm", "iat", "exp", "jti"])

        // jti: 16 random bytes, hex, as the reference implementation.
        let nonce = try #require(payload["jti"] as? String)
        #expect(nonce.count == 32)
        #expect(nonce.allSatisfy { $0.isHexDigit })
        let second = try decodedSegments(try await Fixture.mint(keypair)).payload["jti"] as? String
        #expect(second != nonce)

        // The signature is 64-byte compact and low-S.
        let signature = try JWTBase64URL.decode(String(token.split(separator: ".")[2]))
        #expect(ATProtoSignature.isCanonical(signature, curve: curve))
    }

    @Test("lxm is omitted when not given, and kid is emitted when given")
    func optionalFields() async throws {
        let keypair = K256Keypair.generate()
        let unbound = try await Fixture.mint(keypair, lexiconMethod: nil)
        #expect(try decodedSegments(unbound).payload["lxm"] == nil)
        #expect(try ServiceJWT.inspect(unbound).lexiconMethod == nil)

        let withKey = try await Fixture.mint(keypair, keyID: "#atproto_label", nonce: "fixed")
        let (header, payload) = try decodedSegments(withKey)
        #expect(header["kid"] as? String == "#atproto_label")
        #expect(payload["jti"] as? String == "fixed")
        let inspection = try ServiceJWT.inspect(withKey)
        #expect(inspection.type == "JWT")
        #expect(inspection.keyID == "#atproto_label")
        #expect(inspection.expiresAt == Fixture.now.addingTimeInterval(60))
    }

    @Test("Lifetimes up to one hour can be minted; nothing longer")
    func lifetimes() async throws {
        let keypair = P256Keypair.generate()
        #expect(ServiceJWT.defaultLifetime == 60)
        #expect(ServiceJWT.maximumLifetime == 3600)
        for lifetime: TimeInterval in [1, 60, 1800, 3600] {
            let token = try await Fixture.mint(keypair, lifetime: lifetime)
            #expect(try ServiceJWT.inspect(token).claims.exp == 1_700_000_000 + Int64(lifetime))
        }
        for lifetime: TimeInterval in [0, -1, 0.5, 3601, .infinity, .nan] {
            await #expect(throws: PetrelCryptoError.self, "\(lifetime)") {
                try await Fixture.mint(keypair, lifetime: lifetime)
            }
        }
    }

    @Test("Invalid arguments are refused with a message naming them")
    func invalidArguments() async throws {
        let keypair = P256Keypair.generate()
        await #expect(throws: PetrelCryptoError.malformed("service authentication issuer is not a DID")) {
            try await Fixture.mint(keypair, issuer: "alice.example.com")
        }
        await #expect(throws: PetrelCryptoError.malformed(
            "service authentication audience is not a DID with an optional #service fragment"
        )) {
            try await Fixture.mint(keypair, audience: "https://feed.example.com")
        }
        await #expect(throws: PetrelCryptoError.malformed("service authentication lexicon method is not an NSID")) {
            try await Fixture.mint(keypair, lexiconMethod: "getFeedSkeleton")
        }
        await #expect(throws: PetrelCryptoError.malformed(
            "service authentication nonce must be 1-256 printable ASCII characters"
        )) {
            try await Fixture.mint(keypair, nonce: "has space")
        }
    }
}

// MARK: - Resolvers and stores

@Suite("Service-auth key resolvers and replay store")
struct ServiceAuthSupportTests {
    final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Date
        init(_ value: Date) { self.value = value }
        var now: Date { lock.withLock { value } }
        func advance(_ seconds: TimeInterval) { lock.withLock { value = value.addingTimeInterval(seconds) } }
    }

    @Test("The caching resolver serves from cache and rate-limits forced refreshes")
    func cachingResolver() async throws {
        let did = ServiceAuthFixture.issuer
        let oldKey = K256Keypair.generate().publicKey
        let newKey = K256Keypair.generate().publicKey
        let upstream = RecordingKeyResolver(cached: [did + "#atproto": oldKey], refreshed: [did + "#atproto": newKey])
        let clock = Clock(ServiceAuthFixture.now)
        let resolver = CachingServiceAuthKeyResolver(
            upstream: upstream, timeToLive: 600, minimumRefreshInterval: 30, clock: { clock.now }
        )

        // First lookup goes upstream, un-forced; repeats are served from cache.
        #expect(try await resolver.signingKey(for: did, forceRefresh: false) == oldKey)
        #expect(try await resolver.signingKey(for: did, forceRefresh: false) == oldKey)
        #expect(await upstream.lookups.map(\.forceRefresh) == [false])

        // A forced refresh right after a fetch is answered from cache: a burst
        // of forged tokens cannot turn into a burst of DID resolutions.
        #expect(try await resolver.signingKey(for: did, forceRefresh: true) == oldKey)
        #expect(await upstream.lookups.count == 1)

        // Once the interval has passed, a forced refresh reaches upstream.
        clock.advance(31)
        #expect(try await resolver.signingKey(for: did, forceRefresh: true) == newKey)
        #expect(await upstream.lookups.map(\.forceRefresh) == [false, true])
        #expect(try await resolver.signingKey(for: did, forceRefresh: false) == newKey)
        #expect(await upstream.lookups.count == 2)

        // After the time to live, the entry is refetched.
        clock.advance(601)
        #expect(try await resolver.signingKey(for: did, forceRefresh: false) == newKey)
        #expect(await upstream.lookups.count == 3)

        // Wrapped around a rotating upstream, the verifier still follows the rotation.
        await resolver.removeAll()
        #expect(try await resolver.signingKey(for: did, forceRefresh: false) == oldKey)
    }

    /// An upstream whose lookups block until released, so concurrent callers
    /// overlap with an in-flight fetch.
    actor GatedKeyResolver: ServiceAuthKeyResolver {
        private(set) var calls = 0
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private var isOpen = false
        private let key: ATProtoPublicKey
        private let failure: (any Error)?

        init(key: ATProtoPublicKey, failure: (any Error)? = nil) {
            self.key = key
            self.failure = failure
        }

        func signingKey(for did: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
            try await signingKey(for: did, keyID: "#atproto", forceRefresh: forceRefresh)
        }

        func signingKey(for did: String, keyID: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
            calls += 1
            if !isOpen {
                await withCheckedContinuation { waiters.append($0) }
            }
            if let failure { throw failure }
            return key
        }

        func release() {
            isOpen = true
            for waiter in waiters { waiter.resume() }
            waiters.removeAll()
        }
    }

    /// Runs `count` concurrent lookups against `resolver` while `upstream`
    /// is held, then releases it.
    static func concurrentLookups(
        _ count: Int,
        resolver: CachingServiceAuthKeyResolver,
        upstream: GatedKeyResolver,
        forceRefresh: Bool = false
    ) async -> [Result<ATProtoPublicKey, any Error>] {
        await withTaskGroup(of: Result<ATProtoPublicKey, any Error>.self) { group in
            for _ in 0..<count {
                group.addTask {
                    do {
                        return .success(try await resolver.signingKey(
                            for: ServiceAuthFixture.issuer, forceRefresh: forceRefresh
                        ))
                    } catch {
                        return .failure(error)
                    }
                }
            }
            // Wait for the first fetch, then give the other callers ample
            // time to arrive while it is still suspended.
            while await upstream.calls == 0 { await Task.yield() }
            try? await Task.sleep(nanoseconds: 100_000_000)
            await upstream.release()
            var results: [Result<ATProtoPublicKey, any Error>] = []
            for await result in group { results.append(result) }
            return results
        }
    }

    @Test("Concurrent lookups of one key share a single upstream fetch")
    func cachingResolverCoalescesInFlightLookups() async throws {
        let key = K256Keypair.generate().publicKey
        let upstream = GatedKeyResolver(key: key)
        let resolver = CachingServiceAuthKeyResolver(upstream: upstream, minimumRefreshInterval: 30)

        let results = await Self.concurrentLookups(20, resolver: resolver, upstream: upstream)
        #expect(results.count == 20)
        #expect(try results.allSatisfy { try $0.get() == key })
        #expect(await upstream.calls == 1)
    }

    @Test("Callers sharing a failed fetch all see the error, and the next lookup retries")
    func cachingResolverSharesFailures() async throws {
        struct Offline: Error {}
        let upstream = GatedKeyResolver(key: K256Keypair.generate().publicKey, failure: Offline())
        let resolver = CachingServiceAuthKeyResolver(upstream: upstream, minimumRefreshInterval: 30)

        let results = await Self.concurrentLookups(10, resolver: resolver, upstream: upstream)
        #expect(results.count == 10)
        #expect(results.allSatisfy { if case .failure(let error) = $0 { error is Offline } else { false } })
        #expect(await upstream.calls == 1)

        // Failures are not cached: the next lookup asks upstream again.
        await #expect(throws: Offline.self) {
            try await resolver.signingKey(for: ServiceAuthFixture.issuer, forceRefresh: false)
        }
        #expect(await upstream.calls == 2)
    }

    @Test("The closure resolver passes the key identifier through")
    func closureResolver() async throws {
        let key = P256Keypair.generate().publicKey
        let resolver = ClosureServiceAuthKeyResolver { did, keyID, forceRefresh in
            #expect(did == "did:web:labeler.example.com")
            #expect(!forceRefresh)
            guard keyID == "#atproto_label" || keyID == "#atproto" else {
                throw ServiceAuthError.keyNotAccepted(keyID: keyID)
            }
            return key
        }
        #expect(try await resolver.signingKey(for: "did:web:labeler.example.com", forceRefresh: false) == key)
        #expect(try await resolver.signingKey(
            for: "did:web:labeler.example.com", keyID: "#atproto_label", forceRefresh: false
        ) == key)
    }

    @Test("The in-memory replay store forgets expired tokens and refuses to overflow")
    func replayStore() async throws {
        let clock = Clock(ServiceAuthFixture.now)
        let store = InMemoryServiceAuthReplayStore(capacity: 2, clock: { clock.now })
        let soon = ServiceAuthFixture.now.addingTimeInterval(60)

        #expect(try await store.claim(nonce: "a", issuer: "did:plc:one", expiresAt: soon))
        #expect(try await !store.claim(nonce: "a", issuer: "did:plc:one", expiresAt: soon))
        #expect(try await store.claim(nonce: "a", issuer: "did:plc:two", expiresAt: soon))

        // Full of live entries: refuse rather than forget one.
        await #expect(throws: InMemoryServiceAuthReplayStore.CapacityExceeded(capacity: 2)) {
            try await store.claim(nonce: "b", issuer: "did:plc:one", expiresAt: soon)
        }

        // Once they have expired there is room again, and the old nonce is
        // no longer remembered (the token itself can no longer be presented).
        clock.advance(61)
        #expect(try await store.claim(nonce: "b", issuer: "did:plc:one", expiresAt: clock.now.addingTimeInterval(60)))
        #expect(await store.count == 1)
    }
}
