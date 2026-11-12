import Foundation
import PetrelCrypto
@testable import PetrelOAuthServer
import Testing

@Suite("DPoP: proof validation and server nonces")
struct OAuthDPoPTests {
    private let secret = Data(repeating: 3, count: 32)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let url = "https://server.example.com/token"

    private func validator(_ store: InMemoryOAuthStore = InMemoryOAuthStore()) throws -> (OAuthDPoPProofValidator, OAuthDPoPNonceService) {
        let nonces = try OAuthDPoPNonceService(secret: secret)
        return try (OAuthDPoPProofValidator(secret: secret, nonceService: nonces, replayStore: store), nonces)
    }

    private func expectInvalid(
        _ proof: String,
        _ validator: OAuthDPoPProofValidator,
        method: String = "POST",
        target: String? = nil,
        accessToken: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        do {
            _ = try await validator.validate(
                proof, method: method, target: #require(URL(string: target ?? url)), accessToken: accessToken, now: now
            )
            Issue.record("proof was accepted", sourceLocation: sourceLocation)
        } catch {
            guard case .invalidProof? = error as? OAuthDPoPError else {
                Issue.record("expected invalidProof, got \(error)", sourceLocation: sourceLocation)
                return
            }
        }
    }

    @Test("a valid proof yields the key's RFC 7638 thumbprint", arguments: OAuthJWSAlgorithm.allCases)
    func valid(algorithm: OAuthJWSAlgorithm) async throws {
        let (validator, nonces) = try validator()
        let key = try OAuthSigningKey.generate(algorithm: algorithm)
        let proof = try makeDPoPProof(key: key, method: "POST", url: url, nonce: nonces.current(now: now), issuedAt: now)
        let validated = try await validator.validate(proof, method: "post", target: #require(URL(string: url)), now: now)
        #expect(validated.keyThumbprint == (try key.thumbprint))
        #expect(validated.key.curve == algorithm.curve)
    }

    @Test("a proof with a high-S signature is accepted")
    func highSProof() async throws {
        let (validator, nonces) = try validator()
        let key = try OAuthSigningKey.generate()
        let proof = try withHighS(
            makeDPoPProof(key: key, method: "POST", url: url, nonce: nonces.current(now: now), issuedAt: now),
            curve: .p256
        )
        _ = try await validator.validate(proof, method: "POST", target: #require(URL(string: url)), now: now)
    }

    @Test("a missing or unknown nonce asks for a nonce; the check comes after the signature")
    func nonceRequired() async throws {
        let (validator, _) = try validator()
        let key = try OAuthSigningKey.generate()
        for nonce in [nil, "made-up"] as [String?] {
            let proof = try makeDPoPProof(key: key, method: "POST", url: url, nonce: nonce, issuedAt: now)
            await #expect(throws: OAuthDPoPError.useNonce) {
                _ = try await validator.validate(proof, method: "POST", target: #require(URL(string: url)), now: now)
            }
        }
        // A forged proof is an invalid proof, not a nonce challenge.
        let other = try OAuthSigningKey.generate()
        let forged = try makeDPoPProof(key: key, method: "POST", url: url, nonce: nil, issuedAt: now)
        var parts = forged.split(separator: ".").map(String.init)
        parts[2] = try String(makeDPoPProof(key: other, method: "POST", url: url, nonce: nil, issuedAt: now).split(separator: ".")[2])
        try await expectInvalid(parts.joined(separator: "."), validator)
    }

    @Test("nonces rotate: current, previous and next are accepted, older ones are not, lifetime stays under five minutes")
    func nonceRotation() throws {
        let service = try OAuthDPoPNonceService(secret: secret, rotationInterval: 60)
        let issued = service.current(now: now)
        #expect(service.isValid(issued, now: now))
        #expect(service.current(now: now.addingTimeInterval(1)) == issued, "one nonce serves every client in an interval")
        #expect(service.current(now: now.addingTimeInterval(60)) != issued, "the nonce rotates")
        #expect(service.isValid(issued, now: now.addingTimeInterval(60)), "the previous nonce is still accepted")
        #expect(service.isValid(service.current(now: now.addingTimeInterval(60)), now: now), "the next nonce is accepted early")
        #expect(!service.isValid(issued, now: now.addingTimeInterval(120)))
        #expect(!service.isValid(issued, now: now.addingTimeInterval(300)))
        #expect(!service.isValid("", now: now))
        // A different secret produces unrelated nonces.
        #expect(try !OAuthDPoPNonceService(secret: Data(repeating: 4, count: 32)).isValid(issued, now: now))
        #expect(throws: OAuthServerError.self) { _ = try OAuthDPoPNonceService(secret: secret, rotationInterval: 101) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthDPoPNonceService(secret: Data(count: 8)) }
    }

    @Test("a jti cannot be used twice, even by the same key on another request")
    func replay() async throws {
        let (validator, nonces) = try validator()
        let key = try OAuthSigningKey.generate()
        let proof = try makeDPoPProof(key: key, method: "POST", url: url, nonce: nonces.current(now: now), issuedAt: now, jti: "one")
        _ = try await validator.validate(proof, method: "POST", target: #require(URL(string: url)), now: now)
        try await expectInvalid(proof, validator)
        // Another key may use the same jti value: the reservation is per key.
        let other = try OAuthSigningKey.generate()
        let second = try makeDPoPProof(key: other, method: "POST", url: url, nonce: nonces.current(now: now), issuedAt: now, jti: "one")
        _ = try await validator.validate(second, method: "POST", target: #require(URL(string: url)), now: now)
    }

    @Test("htm and htu must match the request")
    func methodAndTarget() async throws {
        let (validator, nonces) = try validator()
        let key = try OAuthSigningKey.generate()
        func proof(_ method: String = "POST", _ target: String? = nil) throws -> String {
            try makeDPoPProof(key: key, method: method, url: target ?? url, nonce: nonces.current(now: now), issuedAt: now)
        }
        try await expectInvalid(proof("GET"), validator)
        try await expectInvalid(proof("post"), validator, method: "POST")
        try await expectInvalid(proof("POST", "https://server.example.com/other"), validator)
        try await expectInvalid(proof("POST", "https://evil.example.com/token"), validator)
        try await expectInvalid(proof("POST", "http://server.example.com/token"), validator)
        try await expectInvalid(proof("POST", "not a url"), validator)
    }

    @Test("htu comparison uses RFC 3986 normalisation and ignores query and fragment", arguments: [
        "https://server.example.com/token",
        "HTTPS://SERVER.EXAMPLE.COM/token",
        "https://server.example.com:443/token",
        "https://server.example.com/token?foo=bar",
        "https://server.example.com/token#frag",
        "https://server.example.com/a/../token",
        "https://server.example.com/./token",
    ])
    func targetNormalisation(spelling: String) async throws {
        let (validator, nonces) = try validator()
        let key = try OAuthSigningKey.generate()
        let proof = try makeDPoPProof(key: key, method: "POST", url: spelling, nonce: nonces.current(now: now), issuedAt: now)
        _ = try await validator.validate(
            proof, method: "POST", target: #require(URL(string: url + "?actual=query")), now: now
        )
    }

    @Test("normalised targets")
    func normalisedTargets() throws {
        #expect(try OAuthDPoPProofValidator.normalizedTarget("https://Example.COM:443/a/b/../c/./d?x#y") == "https://example.com/a/c/d")
        #expect(try OAuthDPoPProofValidator.normalizedTarget("http://example.com:80") == "http://example.com/")
        #expect(try OAuthDPoPProofValidator.normalizedTarget("https://example.com:8443/x%2fy") == "https://example.com:8443/x%2Fy")
        #expect(try OAuthDPoPProofValidator.normalizedTarget("https://[::1]:8443/x") == "https://[::1]:8443/x")
        #expect(try OAuthDPoPProofValidator.normalizedTarget("https://example.com/a/") == "https://example.com/a/")
        #expect(try OAuthDPoPProofValidator.normalizedTarget("https://example.com/../../a") == "https://example.com/a")
        #expect(throws: OAuthServerError.self) { _ = try OAuthDPoPProofValidator.normalizedTarget("ftp://example.com/") }
        #expect(throws: OAuthServerError.self) { _ = try OAuthDPoPProofValidator.normalizedTarget("https://user:pw@example.com/") }
        #expect(throws: OAuthServerError.self) { _ = try OAuthDPoPProofValidator.normalizedTarget("/relative") }
    }

    @Test("ath is required when an access token is presented, and must be its hash")
    func accessTokenHash() async throws {
        let (validator, nonces) = try validator()
        let key = try OAuthSigningKey.generate()
        let nonce = nonces.current(now: now)
        let without = try makeDPoPProof(key: key, method: "GET", url: url, nonce: nonce, issuedAt: now)
        try await expectInvalid(without, validator, method: "GET", accessToken: "token-1")
        let wrong = try makeDPoPProof(key: key, method: "GET", url: url, nonce: nonce, accessToken: "token-2", issuedAt: now)
        try await expectInvalid(wrong, validator, method: "GET", accessToken: "token-1")
        let right = try makeDPoPProof(key: key, method: "GET", url: url, nonce: nonce, accessToken: "token-1", issuedAt: now)
        _ = try await validator.validate(right, method: "GET", target: #require(URL(string: url)), accessToken: "token-1", now: now)
    }

    @Test("iat window: too old and too far in the future are refused")
    func issuedAtWindow() async throws {
        let (validator, nonces) = try validator()
        let key = try OAuthSigningKey.generate()
        let nonce = nonces.current(now: now)
        try await expectInvalid(makeDPoPProof(key: key, method: "POST", url: url, nonce: nonce, issuedAt: now.addingTimeInterval(-400)), validator)
        try await expectInvalid(makeDPoPProof(key: key, method: "POST", url: url, nonce: nonce, issuedAt: now.addingTimeInterval(200)), validator)
        _ = try await validator.validate(
            makeDPoPProof(key: key, method: "POST", url: url, nonce: nonce, issuedAt: now.addingTimeInterval(-200)),
            method: "POST", target: #require(URL(string: url)), now: now
        )
    }

    @Test("structural rejections: wrong typ, no jwk, private jwk, missing claims, oversize")
    func structural() async throws {
        let (validator, nonces) = try validator()
        let key = try OAuthSigningKey.generate()
        let nonce = nonces.current(now: now)
        let claims = DPoPClaims(jti: "j", htm: "POST", htu: url, iat: Int64(now.timeIntervalSince1970), nonce: nonce)
        // typ is not dpop+jwt.
        try await expectInvalid(OAuthCompactJWT.sign(claims, with: key, type: "jwt", embedsPublicKey: true), validator)
        // kid instead of an embedded key.
        try await expectInvalid(OAuthCompactJWT.sign(claims, with: key, type: "dpop+jwt"), validator)
        // An embedded key that carries the private scalar.
        let jwk = try key.publicJWK
        let header = #"{"alg":"ES256","typ":"dpop+jwt","jwk":{"kty":"EC","crv":"P-256","x":"\#(jwk.x)","y":"\#(jwk.y)","d":"\#(JWTBase64URL.encode(key.rawRepresentation))"}}"#
        let payload = try JSONEncoder().encode(claims)
        let input = JWTBase64URL.encode(Data(header.utf8)) + "." + JWTBase64URL.encode(payload)
        try await expectInvalid(input + "." + JWTBase64URL.encode(key.signature(for: Data(input.utf8))), validator)
        // Missing jti / htm / htu.
        struct Partial: Encodable { let iat: Int64; let nonce: String }
        try await expectInvalid(
            OAuthCompactJWT.sign(Partial(iat: claims.iat, nonce: nonce), with: key, type: "dpop+jwt", embedsPublicKey: true),
            validator
        )
        // Missing iat.
        struct NoIat: Encodable { let jti: String; let htm: String; let htu: String; let nonce: String }
        try await expectInvalid(
            OAuthCompactJWT.sign(NoIat(jti: "j", htm: "POST", htu: url, nonce: nonce), with: key, type: "dpop+jwt", embedsPublicKey: true),
            validator
        )
        // Not a JWT at all, and far too large.
        try await expectInvalid("not-a-jwt", validator)
        try await expectInvalid(String(repeating: "a", count: 40000), validator)
    }

    @Test("a replay store failure is reported as unavailable, not as a valid or invalid proof")
    func unavailableStore() async throws {
        struct Broken: OAuthReplayStore {
            struct Failure: Error {}
            func claim(namespace _: OAuthReplayNamespace, digest _: Data, expiresAt _: Date, now _: Date) async throws -> Bool {
                throw Failure()
            }
        }
        let nonces = try OAuthDPoPNonceService(secret: secret)
        let validator = try OAuthDPoPProofValidator(secret: secret, nonceService: nonces, replayStore: Broken())
        let proof = try makeDPoPProof(key: OAuthSigningKey.generate(), method: "POST", url: url, nonce: nonces.current(now: now), issuedAt: now)
        await #expect(throws: OAuthDPoPError.unavailable) {
            _ = try await validator.validate(proof, method: "POST", target: #require(URL(string: url)), now: now)
        }
    }
}
