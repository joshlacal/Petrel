import Foundation
import PetrelCrypto
@testable import PetrelOAuthServer
import Testing

/// Flips a low-S `r || s` signature to its high-S twin `r || (n - s)`.
func highSTwin(_ signature: Data, curve: OAuthJSONWebKey.Curve) -> Data {
    let order: [UInt8] = curve == .p256
        ? [
            0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0xBC, 0xE6, 0xFA, 0xAD, 0xA7, 0x17, 0x9E, 0x84, 0xF3, 0xB9, 0xCA, 0xC2, 0xFC, 0x63, 0x25, 0x51,
        ]
        : [
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
            0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B, 0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41,
        ]
    let bytes = Array(signature)
    var result = [UInt8](repeating: 0, count: 32)
    var borrow = 0
    for index in stride(from: 31, through: 0, by: -1) {
        var value = Int(order[index]) - Int(bytes[32 + index]) - borrow
        if value < 0 { value += 256; borrow = 1 } else { borrow = 0 }
        result[index] = UInt8(value)
    }
    return Data(bytes[..<32]) + Data(result)
}

/// Re-signs nothing: swaps the signature segment of a compact JWT for its
/// high-S twin, which is an equally valid ECDSA signature.
func withHighS(_ compact: String, curve: OAuthJSONWebKey.Curve) throws -> String {
    var parts = compact.split(separator: ".").map(String.init)
    let signature = try JWTBase64URL.decode(parts[2], maxBytes: 64)
    parts[2] = JWTBase64URL.encode(highSTwin(signature, curve: curve))
    return parts.joined(separator: ".")
}

@Suite("JOSE: JWK, JWKS and compact JWT")
struct OAuthJOSETests {
    struct Claims: Codable, Equatable {
        var iss: String?
        var aud: String?
        var iat: Double?
        var exp: Double?
        var nbf: Double?
        var jti: String?
        var custom: String?
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("thumbprint matches the published value for the RFC 7515 and RFC 9449 example keys")
    func thumbprintKnownAnswers() throws {
        // RFC 7515 Appendix A.3 key; value computed independently (SHA-256 of the RFC 7638 canonical form).
        let first = try OAuthJSONWebKey(
            x: "MKBCTNIcKUSDii11ySs3526iDZ8AiTo7Tu6KPAqv7D4", y: "4Etl6SRW2YiLUrN5vfvVHuhp7x8PxltmWWlbbM4IFyM"
        )
        #expect(first.thumbprint() == "cn-I_WNMClehiVp51i_0VpOENW1upEerA8sEam5hn-s")
        // RFC 9449 §6.1 states this thumbprint for the key used in its examples.
        let second = try OAuthJSONWebKey(
            x: "l8tFrhx-34tV3hRICRDY9zCkDlpBhF42UQUfWVAWBFs", y: "9VE4jf_Ok_o64zbTTlcuNJajHmt6v9TDVrU0CdvGRDA"
        )
        #expect(second.thumbprint() == "0ZcOCORZNYy-DWpqq30jZyJGHTN0d2HglBV3uiguA4I")
        // kid, alg and use are not part of the thumbprint.
        let decorated = try OAuthJSONWebKey(x: second.x, y: second.y, keyID: "k", algorithm: .es256, use: "sig")
        #expect(decorated.thumbprint() == second.thumbprint())
    }

    @Test("the RFC 7515 Appendix A.3 ES256 example verifies")
    func rfc7515Example() throws {
        let key = try OAuthJSONWebKey(
            x: "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU", y: "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0"
        )
        let compact = "eyJhbGciOiJFUzI1NiJ9."
            + "eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ."
            + "DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8ISlSApmWQxfKTUJqPP3-Kg6NU1Q"
        let verified = try OAuthCompactJWT.verify(
            compact, key: key, constraints: .init(now: Date(timeIntervalSince1970: 1_300_819_000))
        )
        #expect(verified.registeredClaims.issuer == "joe")
        #expect(verified.registeredClaims.expiresAt == 1_300_819_380)
        // The same token is expired a day later.
        #expect(throws: OAuthServerError.expired) {
            _ = try OAuthCompactJWT.verify(
                compact, key: key, constraints: .init(now: Date(timeIntervalSince1970: 1_300_919_000))
            )
        }
    }

    @Test("sign and verify round-trip", arguments: OAuthJWSAlgorithm.allCases)
    func roundTrip(algorithm: OAuthJWSAlgorithm) throws {
        let key = try OAuthSigningKey.generate(algorithm: algorithm, keyID: "kid-1")
        let token = try OAuthCompactJWT.sign(Claims(iss: "me", custom: "value"), with: key, type: "test+jwt")
        let header = try OAuthCompactJWT.unverifiedHeader(token)
        #expect(header.algorithm == algorithm.rawValue)
        #expect(header.keyID == "kid-1")
        #expect(header.type == "test+jwt")
        let verified = try OAuthCompactJWT.verify(token, key: key.publicJWK, expectedType: "test+jwt")
        #expect(try OAuthCompactJWT.decodeClaims(Claims.self, from: verified).custom == "value")

        // The key survives export and import of its raw scalar.
        let restored = try OAuthSigningKey(algorithm: algorithm, rawRepresentation: key.rawRepresentation, keyID: "kid-1")
        #expect(try restored.publicJWK == key.publicJWK)
        #expect(!key.description.contains(key.rawRepresentation.base64EncodedString()))
    }

    @Test("a high-S signature is accepted for JOSE tokens and refused in canonical mode", arguments: OAuthJWSAlgorithm.allCases)
    func highS(algorithm: OAuthJWSAlgorithm) throws {
        let key = try OAuthSigningKey.generate(algorithm: algorithm)
        let lowS = try OAuthCompactJWT.sign(Claims(iss: "me"), with: key)
        let highS = try withHighS(lowS, curve: algorithm.curve)
        #expect(highS != lowS)
        _ = try OAuthCompactJWT.verify(highS, key: key.publicJWK, signatureEncoding: .joseInteroperable)
        _ = try OAuthCompactJWT.verify(lowS, key: key.publicJWK, signatureEncoding: .canonicalLowS)
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthCompactJWT.verify(highS, key: key.publicJWK, signatureEncoding: .canonicalLowS)
        }
    }

    @Test("the header algorithm must be the key's algorithm; none is never accepted")
    func algorithmConfusion() throws {
        let p256 = try OAuthSigningKey.generate(algorithm: .es256)
        let k256 = try OAuthSigningKey.generate(algorithm: .es256k)
        let token = try OAuthCompactJWT.sign(Claims(iss: "me"), with: p256)
        #expect(throws: OAuthServerError.self) { _ = try OAuthCompactJWT.verify(token, key: k256.publicJWK) }

        let unsigned = JWTBase64URL.encode(Data(#"{"alg":"none"}"#.utf8)) + "." + JWTBase64URL.encode(Data("{}".utf8)) + "."
        #expect(throws: OAuthServerError.self) { _ = try OAuthCompactJWT.verify(unsigned, key: p256.publicJWK) }
        let parts = token.split(separator: ".").map(String.init)
        let relabelled = JWTBase64URL.encode(Data(#"{"alg":"none"}"#.utf8)) + "." + parts[1] + "." + parts[2]
        #expect(throws: OAuthServerError.self) { _ = try OAuthCompactJWT.verify(relabelled, key: p256.publicJWK) }
    }

    @Test("structural rejections: crit, b64, duplicate members, wrong typ, oversize, tampering")
    func structuralRejections() throws {
        let key = try OAuthSigningKey.generate()
        let token = try OAuthCompactJWT.sign(Claims(iss: "me"), with: key, type: "a+jwt")
        let parts = token.split(separator: ".").map(String.init)
        func resigned(header: String, payload: String = #"{"iss":"me"}"#) throws -> String {
            let input = JWTBase64URL.encode(Data(header.utf8)) + "." + JWTBase64URL.encode(Data(payload.utf8))
            return try input + "." + JWTBase64URL.encode(key.signature(for: Data(input.utf8)))
        }
        let jwk = try key.publicJWK
        #expect(throws: OAuthServerError.self) { _ = try OAuthCompactJWT.verify(resigned(header: #"{"alg":"ES256","crit":["x"]}"#), key: jwk) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthCompactJWT.verify(resigned(header: #"{"alg":"ES256","b64":false}"#), key: jwk) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthCompactJWT.verify(resigned(header: #"{"alg":"ES256","alg":"ES256"}"#), key: jwk) }
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthCompactJWT.verify(resigned(header: #"{"alg":"ES256"}"#, payload: #"{"iss":"a","iss":"b"}"#), key: jwk)
        }
        #expect(throws: OAuthServerError.self) { _ = try OAuthCompactJWT.verify(token, key: jwk, expectedType: "b+jwt") }
        #expect(throws: OAuthServerError.self) { _ = try OAuthCompactJWT.verify(parts[0] + "." + parts[1], key: jwk) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthCompactJWT.verify(token + "=", key: jwk) }
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthCompactJWT.verify(parts[0] + "." + JWTBase64URL.encode(Data(#"{"iss":"you"}"#.utf8)) + "." + parts[2], key: jwk)
        }
        let huge = try resigned(header: #"{"alg":"ES256"}"#, payload: "{\"x\":\"" + String(repeating: "a", count: 40000) + "\"}")
        #expect(throws: OAuthServerError.malformed("JWT is too large")) { _ = try OAuthCompactJWT.verify(huge, key: jwk) }
    }

    @Test("registered claims: fractional NumericDate, exp, nbf, max age, lifetime, issuer and audience")
    func registeredClaims() throws {
        let key = try OAuthSigningKey.generate()
        let jwk = try key.publicJWK
        let t = now.timeIntervalSince1970
        func verify(_ claims: Claims, _ constraints: OAuthJWTVerificationConstraints) throws -> OAuthVerifiedJWT {
            try OAuthCompactJWT.verify(OAuthCompactJWT.sign(claims, with: key), key: jwk, constraints: constraints)
        }
        // A fractional iat is legal and accepted.
        let fractional = try verify(Claims(iat: t - 0.5, exp: t + 30.25), .init(now: now, requireIssuedAt: true, requireExpiration: true))
        #expect(fractional.registeredClaims.issuedAt == Int64(t) - 1)

        #expect(throws: OAuthServerError.expired) { _ = try verify(Claims(exp: t - 61), .init(now: now)) }
        _ = try verify(Claims(exp: t - 30), .init(now: now)) // inside the clock-skew tolerance
        #expect(throws: OAuthServerError.self) { _ = try verify(Claims(iat: t + 120), .init(now: now)) }
        #expect(throws: OAuthServerError.self) { _ = try verify(Claims(nbf: t + 120), .init(now: now)) }
        #expect(throws: OAuthServerError.expired) { _ = try verify(Claims(iat: t - 400), .init(now: now, maximumAge: 300)) }
        #expect(throws: OAuthServerError.self) { _ = try verify(Claims(iat: t, exp: t + 3600), .init(now: now, maxLifetime: 300)) }
        #expect(throws: OAuthServerError.self) { _ = try verify(Claims(), .init(now: now, requireIssuedAt: true)) }
        #expect(throws: OAuthServerError.self) { _ = try verify(Claims(), .init(now: now, requireExpiration: true)) }
        #expect(throws: OAuthServerError.self) { _ = try verify(Claims(iss: "a"), .init(expectedIssuer: "b", now: now)) }
        #expect(throws: OAuthServerError.self) { _ = try verify(Claims(aud: "a"), .init(expectedAudience: "b", now: now)) }
        _ = try verify(Claims(iss: "a", aud: "b"), .init(expectedIssuer: "a", expectedAudience: "b", now: now))
    }

    @Test("an array-valued aud is accepted when it contains the expected audience")
    func audienceArray() throws {
        let key = try OAuthSigningKey.generate()
        struct ArrayAudience: Encodable { let aud: [String] }
        let token = try OAuthCompactJWT.sign(ArrayAudience(aud: ["x", "y"]), with: key)
        _ = try OAuthCompactJWT.verify(token, key: key.publicJWK, constraints: .init(expectedAudience: "y"))
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthCompactJWT.verify(token, key: key.publicJWK, constraints: .init(expectedAudience: "z"))
        }
    }

    @Test("JWK validation: private material, off-curve points, wrong lengths and mismatched alg are refused")
    func jwkValidation() throws {
        let key = try OAuthSigningKey.generate()
        let jwk = try key.publicJWK
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKey(x: jwk.x, y: jwk.x) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKey(x: "AAAA", y: jwk.y) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKey(x: jwk.x + "=", y: jwk.y) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKey(x: jwk.x, y: jwk.y, algorithm: .es256k) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKey(x: jwk.x, y: jwk.y, use: "enc") }
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKey(curve: .secp256k1, x: jwk.x, y: jwk.y) }
        let withPrivate = #"{"kty":"EC","crv":"P-256","x":"\#(jwk.x)","y":"\#(jwk.y)","d":"AAAA"}"#
        #expect(throws: (any Error).self) { _ = try JSONDecoder().decode(OAuthJSONWebKey.self, from: Data(withPrivate.utf8)) }
        let round = try JSONDecoder().decode(OAuthJSONWebKey.self, from: JSONEncoder().encode(jwk))
        #expect(round == jwk)
    }

    @Test("JWKS: other key types are skipped, private material fails the set, kid selection is fail-closed")
    func jwks() throws {
        let first = try OAuthSigningKey.generate(keyID: "a").publicJWK
        let second = try OAuthSigningKey.generate(algorithm: .es256k, keyID: "b").publicJWK
        func ec(_ key: OAuthJSONWebKey) -> String {
            #"{"kty":"EC","crv":"\#(key.curve.rawValue)","x":"\#(key.x)","y":"\#(key.y)","kid":"\#(key.keyID ?? "")"}"#
        }
        let mixed = #"{"keys":[{"kty":"RSA","n":"AQAB","e":"AQAB","kid":"rsa"},{"kty":"OKP","crv":"Ed25519","x":"AAAA"},"#
            + #"{"kty":"EC","crv":"P-384","x":"AAAA","y":"AAAA"},\#(ec(first)),\#(ec(second))]}"#
        let set = try OAuthJSONWebKeySet.decodeValidated(Data(mixed.utf8))
        #expect(set.keys.map(\.keyID) == ["a", "b"])
        #expect(try set.select(keyID: "b").curve == .secp256k1)
        #expect(throws: OAuthServerError.self) { _ = try set.select(keyID: "missing") }
        #expect(throws: OAuthServerError.self) { _ = try set.select(keyID: nil) }
        #expect(try OAuthJSONWebKeySet(keys: [first]).select(keyID: nil) == first)

        let leaked = #"{"keys":[{"kty":"RSA","n":"AQAB","e":"AQAB","d":"AQAB"},\#(ec(first))]}"#
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKeySet.decodeValidated(Data(leaked.utf8)) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKeySet.decodeValidated(Data(#"{"keys":[\#(ec(first)),\#(ec(first))]}"#.utf8)) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKeySet.decodeValidated(Data(#"{"keys":[{"kty":"RSA","n":"AQAB","e":"AQAB"}]}"#.utf8)) }
        #expect(throws: OAuthServerError.self) { _ = try OAuthJSONWebKeySet.decodeValidated(Data(#"{"keys":[],"keys":[]}"#.utf8)) }
        // A malformed key of a supported kind is an error, not something to skip.
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthJSONWebKeySet.decodeValidated(Data(#"{"keys":[{"kty":"EC","crv":"P-256","x":"AAAA","y":"AAAA"}]}"#.utf8))
        }
    }

    @Test("PKCE S256: the RFC 7636 Appendix B vector, and verifier and challenge syntax")
    func pkce() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        #expect(OAuthPKCE.s256Challenge(for: verifier) == challenge)
        #expect(OAuthPKCE.verifyS256(verifier: verifier, challenge: challenge))
        #expect(!OAuthPKCE.verifyS256(verifier: verifier + "x", challenge: challenge))
        #expect(OAuthPKCE.isValidVerifier(verifier))
        #expect(!OAuthPKCE.isValidVerifier(String(verifier.dropLast())))
        #expect(!OAuthPKCE.isValidVerifier(String(repeating: "a", count: 129)))
        #expect(!OAuthPKCE.isValidVerifier(String(repeating: "a", count: 42) + "+"))
        #expect(OAuthPKCE.isValidS256Challenge(challenge))
        #expect(!OAuthPKCE.isValidS256Challenge(verifier.lowercased() + "="))
    }
}
