import Crypto
import Foundation
@testable import PetrelCrypto
import secp256k1
import XCTest

final class ServiceJWTTests: XCTestCase {
    private let p256Key = P256.Signing.PrivateKey()
    private let issuerPLC = "did:plc:abcdefghijklmnopqrstuvwx"
    private let issuerWeb = "did:web:api.bsky.app"
    private let audience = "did:web:api.bsky.app"

    // MARK: - Mint & Inspect & Verify (ES256)

    func testES256MintInspectAndVerifyRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = try ServiceJWT.mint(
            issuer: issuerPLC,
            audience: audience,
            method: "app.bsky.actor.getProfile",
            eventID: "event-12345",
            key: p256Key,
            now: now,
            lifetime: 60
        )

        // Inspect
        let inspection = try ServiceJWT.inspect(token)
        XCTAssertEqual(inspection.algorithm, "ES256")
        XCTAssertEqual(inspection.issuer, issuerPLC)
        XCTAssertEqual(inspection.claims.iss, issuerPLC)
        XCTAssertEqual(inspection.claims.aud, audience)
        XCTAssertEqual(inspection.claims.lxm, "app.bsky.actor.getProfile")
        XCTAssertEqual(inspection.claims.jti, "event-12345")
        XCTAssertEqual(inspection.claims.iat, 1_700_000_000)
        XCTAssertEqual(inspection.claims.exp, 1_700_000_060)

        // Verify with ATProtoJWTVerificationKey
        let verifier = ATProtoJWTVerificationKey.p256(p256Key.publicKey)
        let verified = try ServiceJWT.verify(token, publicKey: verifier, now: now)
        XCTAssertEqual(verified.iss, issuerPLC)
        XCTAssertEqual(verified.aud, audience)
        XCTAssertEqual(verified.lxm, "app.bsky.actor.getProfile")
        XCTAssertEqual(verified.jti, "event-12345")
        XCTAssertEqual(verified.iat, 1_700_000_000)
        XCTAssertEqual(verified.exp, 1_700_000_060)

        // Verify with PLCDIDVerificationKey
        let plcKey = PLCDIDVerificationKey.p256(p256Key.publicKey)
        let verifiedFromPLC = try ServiceJWT.verify(token, publicKey: plcKey, now: now)
        XCTAssertEqual(verifiedFromPLC.iss, issuerPLC)

        // Verify with did:key string
        let didKey = plcKey.didKey
        let verifiedFromDIDKey = try ServiceJWT.verify(token, didKey: didKey, now: now)
        XCTAssertEqual(verifiedFromDIDKey.iss, issuerPLC)
    }

    // MARK: - Mint & Inspect & Verify (ES256K)

    func testES256KMintInspectAndVerifyRoundTrip() throws {
        let secpKey = try secp256k1.Signing.PrivateKey()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = try ServiceJWT.mint(
            issuer: issuerWeb,
            audience: audience,
            method: "com.atproto.repo.getRecord",
            eventID: "secp-event-999",
            key: secpKey,
            now: now,
            lifetime: 60
        )

        // Inspect
        let inspection = try ServiceJWT.inspect(token)
        XCTAssertEqual(inspection.algorithm, "ES256K")
        XCTAssertEqual(inspection.issuer, issuerWeb)
        XCTAssertEqual(inspection.claims.iss, issuerWeb)
        XCTAssertEqual(inspection.claims.aud, audience)
        XCTAssertEqual(inspection.claims.lxm, "com.atproto.repo.getRecord")
        XCTAssertEqual(inspection.claims.jti, "secp-event-999")
        XCTAssertEqual(inspection.claims.iat, 1_700_000_000)
        XCTAssertEqual(inspection.claims.exp, 1_700_000_060)

        // Verify with ATProtoJWTVerificationKey
        let secpVerifier = try ATProtoJWTVerificationKey(secp256k1PublicKey: secpKey.publicKey.dataRepresentation)
        let verified = try ServiceJWT.verify(token, publicKey: secpVerifier, now: now)
        XCTAssertEqual(verified.iss, issuerWeb)
        XCTAssertEqual(verified.aud, audience)
        XCTAssertEqual(verified.lxm, "com.atproto.repo.getRecord")

        // Verify with PLCDIDVerificationKey
        let plcKey = PLCDIDVerificationKey.secp256k1(secpKey.publicKey.dataRepresentation)
        let verifiedFromPLC = try ServiceJWT.verify(token, publicKey: plcKey, now: now)
        XCTAssertEqual(verifiedFromPLC.iss, issuerWeb)

        // Verify with did:key string
        let didKey = plcKey.didKey
        let verifiedFromDIDKey = try ServiceJWT.verify(token, didKey: didKey, now: now)
        XCTAssertEqual(verifiedFromDIDKey.iss, issuerWeb)
    }

    // MARK: - Backward Compatibility Types: ProxyServiceJWT & SpaceServiceJWT

    func testProxyServiceJWTAndSpaceServiceJWTCompatibility() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let proxyToken = try ProxyServiceJWT.create(
            issuer: issuerPLC,
            audience: audience,
            method: "app.bsky.feed.getTimeline",
            eventID: "proxy-jti",
            key: p256Key,
            now: now,
            lifetime: 60
        )
        let proxyClaims = try SpaceServiceJWT.verify(
            proxyToken,
            publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey),
            now: now
        )
        XCTAssertEqual(proxyClaims.iss, issuerPLC)
        XCTAssertEqual(proxyClaims.lxm, "app.bsky.feed.getTimeline")

        let spaceToken = try SpaceServiceJWT.create(
            issuer: issuerPLC,
            audience: audience,
            method: "com.atproto.space.notifyWrite",
            eventID: "space-jti",
            key: p256Key,
            now: now,
            lifetime: 60
        )
        let spaceInspection = try SpaceServiceJWT.inspect(spaceToken)
        XCTAssertEqual(spaceInspection.algorithm, "ES256")
        XCTAssertEqual(spaceInspection.claims.jti, "space-jti")
    }

    func testCollectionOfMethodsAcceptedAcrossNamespaces() throws {
        for method in [
            "app.bsky.actor.getProfile",
            "app.bsky.feed.getTimeline",
            "tools.ozone.moderation.emitEvent",
            "com.atproto.repo.getRecord",
            "com.atproto.server.createSession",
            "chat.bsky.convo.sendMessage",
        ] {
            XCTAssertNoThrow(
                try ServiceJWT.mint(
                    issuer: issuerPLC,
                    audience: audience,
                    method: method,
                    eventID: "method-test",
                    key: p256Key
                )
            )
            XCTAssertTrue(ServiceJWT.isNSID(method))
            XCTAssertTrue(ProxyServiceJWT.isNSID(method))
        }
    }

    // MARK: - Negative Mint Tests

    func testRejectsMalformedInputsOnMint() {
        // Non-NSID methods
        for badMethod in ["not an nsid", "single", "two.segments", "bad..dots", "inv@lid.char.nsid"] {
            XCTAssertThrowsError(
                try ServiceJWT.mint(
                    issuer: issuerPLC,
                    audience: audience,
                    method: badMethod,
                    eventID: "j",
                    key: p256Key
                )
            ) { error in
                XCTAssertEqual(error as? PetrelCryptoError, .malformed("service authentication claims are invalid"))
            }
        }

        // Bad issuer DID
        for badDID in ["nope", "http://example.com", "did:", "did:plc", "did:plc:tooshort", "did:plc:invalid*chars!here"] {
            XCTAssertThrowsError(
                try ServiceJWT.mint(
                    issuer: badDID,
                    audience: audience,
                    method: "app.bsky.actor.getProfile",
                    eventID: "j",
                    key: p256Key
                )
            )
        }

        // Empty / bad audience
        XCTAssertThrowsError(
            try ServiceJWT.mint(
                issuer: issuerPLC,
                audience: "",
                method: "app.bsky.actor.getProfile",
                eventID: "j",
                key: p256Key
            )
        )

        // Invalid lifetimes
        XCTAssertThrowsError(
            try ServiceJWT.mint(
                issuer: issuerPLC,
                audience: audience,
                method: "app.bsky.actor.getProfile",
                eventID: "j",
                key: p256Key,
                lifetime: 0
            )
        )
        XCTAssertThrowsError(
            try ServiceJWT.mint(
                issuer: issuerPLC,
                audience: audience,
                method: "app.bsky.actor.getProfile",
                eventID: "j",
                key: p256Key,
                lifetime: -10
            )
        )
        XCTAssertThrowsError(
            try ServiceJWT.mint(
                issuer: issuerPLC,
                audience: audience,
                method: "app.bsky.actor.getProfile",
                eventID: "j",
                key: p256Key,
                lifetime: 3600
            )
        )
    }

    // MARK: - Negative Verification Tests: Expiry & Time Policy

    func testExpiredTokenThrowsExpired() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = try ServiceJWT.mint(
            issuer: issuerPLC,
            audience: audience,
            method: "app.bsky.actor.getProfile",
            eventID: "expired-test",
            key: p256Key,
            now: now,
            lifetime: 60
        )

        // Verifying 121 seconds later with 60s clockSkew (exp is 1_700_000_060, cutoff is 1_700_000_061)
        let later = Date(timeIntervalSince1970: 1_700_000_121)
        XCTAssertThrowsError(
            try ServiceJWT.verify(
                token,
                publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey),
                now: later,
                clockSkew: 60
            )
        ) { error in
            XCTAssertEqual(error as? PetrelCryptoError, .expired)
        }
    }

    func testTokenWithoutIssuedAtCannotOutliveConfiguredMaximum() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let nowSeconds = Int64(now.timeIntervalSince1970)
        let skew: TimeInterval = 60
        let maximumLifetime: TimeInterval = 300

        func token(exp: Int64, iat: Int64? = nil) throws -> String {
            let headerData = try JSONEncoder().encode(["alg": "ES256", "typ": "JWT"])
            var claimsDict: [String: Any] = [
                "iss": issuerPLC,
                "aud": audience,
                "exp": exp,
                "lxm": "app.bsky.actor.getProfile",
                "jti": "custom-time-jwt",
            ]
            if let iat {
                claimsDict["iat"] = iat
            }
            let claimsData = try JSONSerialization.data(withJSONObject: claimsDict, options: [.sortedKeys])
            let signingInput = "\(JWTBase64URL.encode(headerData)).\(JWTBase64URL.encode(claimsData))"
            let signature = try P256WireSignature.sign(Data(signingInput.utf8), using: p256Key)
            return "\(signingInput).\(JWTBase64URL.encode(signature))"
        }

        func verify(_ compact: String) throws -> ServiceJWT.Claims {
            try ServiceJWT.verify(
                compact,
                publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey),
                now: now,
                clockSkew: skew,
                maximumLifetime: maximumLifetime
            )
        }

        // Expire a year in the future with absent iat -> refused
        let distant = try token(exp: nowSeconds + 365 * 24 * 60 * 60)
        XCTAssertNil(try ServiceJWT.inspect(distant).claims.iat)
        XCTAssertThrowsError(try verify(distant)) { error in
            XCTAssertEqual(error as? PetrelCryptoError, .unauthorized("service authentication time claims are invalid"))
        }

        // One second past the skew-widened ceiling is still refused
        let justOver = try token(exp: nowSeconds + Int64(skew) + Int64(maximumLifetime) + 1)
        XCTAssertThrowsError(try verify(justOver))

        // In window verifies
        let inWindow = try token(exp: nowSeconds + Int64(maximumLifetime))
        XCTAssertEqual(try verify(inWindow).exp, nowSeconds + Int64(maximumLifetime))

        // Backdated stated lifetime exceeds maximum -> refused
        let backdated = try token(
            exp: nowSeconds + Int64(maximumLifetime),
            iat: nowSeconds - Int64(maximumLifetime)
        )
        XCTAssertThrowsError(try verify(backdated))
    }

    // MARK: - Negative Verification Tests: Signature Tampering & Curve Mismatch

    func testTamperedSignatureIsRejected() throws {
        let token = try ServiceJWT.mint(
            issuer: issuerPLC,
            audience: audience,
            method: "app.bsky.actor.getProfile",
            eventID: "tamper-sig",
            key: p256Key
        )
        let parts = token.split(separator: ".")
        var sigData = try JWTBase64URL.decode(String(parts[2]))
        sigData[sigData.startIndex] ^= 0xff // flip bits
        let tamperedToken = "\(parts[0]).\(parts[1]).\(JWTBase64URL.encode(sigData))"

        XCTAssertThrowsError(
            try ServiceJWT.verify(
                tamperedToken,
                publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey)
            )
        ) { error in
            XCTAssertEqual(error as? PetrelCryptoError, .unauthorized("service authentication signature is invalid"))
        }
    }

    func testTamperedPayloadIsRejected() throws {
        let token = try ServiceJWT.mint(
            issuer: issuerPLC,
            audience: audience,
            method: "app.bsky.actor.getProfile",
            eventID: "tamper-payload",
            key: p256Key
        )
        let parts = token.split(separator: ".")
        let tamperedPayload = JWTBase64URL.encode(Data("{\"iss\":\"did:plc:tampered\"}".utf8))
        let tamperedToken = "\(parts[0]).\(tamperedPayload).\(parts[2])"

        XCTAssertThrowsError(
            try ServiceJWT.verify(
                tamperedToken,
                publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey)
            )
        )
    }

    func testWrongCurveVerificationIsRejected() throws {
        let secpKey = try secp256k1.Signing.PrivateKey()
        let es256kToken = try ServiceJWT.mint(
            issuer: issuerPLC,
            audience: audience,
            method: "app.bsky.actor.getProfile",
            eventID: "curve-mismatch",
            key: secpKey
        )

        // Attempt to verify ES256K token against P256 public key
        XCTAssertThrowsError(
            try ServiceJWT.verify(
                es256kToken,
                publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey)
            )
        ) { error in
            XCTAssertEqual(error as? PetrelCryptoError, .unauthorized("JWT algorithm does not match verification key"))
        }

        let es256Token = try ServiceJWT.mint(
            issuer: issuerPLC,
            audience: audience,
            method: "app.bsky.actor.getProfile",
            eventID: "curve-mismatch-2",
            key: p256Key
        )

        // Attempt to verify ES256 token against secp256k1 public key
        let secpVerifier = try ATProtoJWTVerificationKey(secp256k1PublicKey: secpKey.publicKey.dataRepresentation)
        XCTAssertThrowsError(
            try ServiceJWT.verify(
                es256Token,
                publicKey: secpVerifier
            )
        ) { error in
            XCTAssertEqual(error as? PetrelCryptoError, .unauthorized("JWT algorithm or signature is invalid"))
        }
    }

    func testHighSSignatureRejected() throws {
        let token = try ServiceJWT.mint(
            issuer: issuerPLC,
            audience: audience,
            method: "app.bsky.actor.getProfile",
            eventID: "high-s-test",
            key: p256Key
        )
        let parts = token.split(separator: ".")
        let canonicalSig = try JWTBase64URL.decode(String(parts[2]))
        let highS = highSVariant(of: canonicalSig)
        let highSToken = "\(parts[0]).\(parts[1]).\(JWTBase64URL.encode(highS))"

        XCTAssertThrowsError(
            try ServiceJWT.verify(
                highSToken,
                publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey)
            )
        )
    }

    // MARK: - Negative Verification Tests: Malformed Token & Header Types

    func testRejectsDisallowedTokenTypes() throws {
        for disallowedTyp in ["at+jwt", "refresh+jwt", "dpop+jwt", "AT+JWT"] {
            let headerData = try JSONEncoder().encode(["alg": "ES256", "typ": disallowedTyp])
            let claimsData = try JSONEncoder().encode(ServiceJWT.Claims(
                iss: issuerPLC,
                aud: audience,
                iat: 1_700_000_000,
                exp: 1_700_000_060,
                lxm: "app.bsky.actor.getProfile",
                jti: "typ-test"
            ))
            let signingInput = "\(JWTBase64URL.encode(headerData)).\(JWTBase64URL.encode(claimsData))"
            let signature = try P256WireSignature.sign(Data(signingInput.utf8), using: p256Key)
            let badTypToken = "\(signingInput).\(JWTBase64URL.encode(signature))"

            XCTAssertThrowsError(
                try ServiceJWT.verify(
                    badTypToken,
                    publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey)
                )
            ) { error in
                XCTAssertEqual(error as? PetrelCryptoError, .unauthorized("service authentication token is invalid"))
            }
        }
    }

    func testRejectsMalformedTokens() {
        for malformed in [
            "",
            "one",
            "one.two",
            "one.two.three.four",
            "bad base64.bad base64.bad base64",
            "eyJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJkaWQ6cGxjOmFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eCJ9", // only 2 parts
        ] {
            XCTAssertThrowsError(
                try ServiceJWT.verify(
                    malformed,
                    publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey)
                )
            )
        }
    }

    func testStrictJSONRejectsDuplicateKeysInClaims() throws {
        let headerData = try JSONEncoder().encode(["alg": "ES256", "typ": "JWT"])
        let duplicateClaimsJSON = "{\"iss\":\"\(issuerPLC)\",\"iss\":\"\(issuerPLC)\",\"aud\":\"\(audience)\",\"exp\":1700000060,\"lxm\":\"app.bsky.actor.getProfile\",\"jti\":\"dup-key\"}"
        let signingInput = "\(JWTBase64URL.encode(headerData)).\(JWTBase64URL.encode(Data(duplicateClaimsJSON.utf8)))"
        let signature = try P256WireSignature.sign(Data(signingInput.utf8), using: p256Key)
        let dupToken = "\(signingInput).\(JWTBase64URL.encode(signature))"

        XCTAssertThrowsError(
            try ServiceJWT.verify(
                dupToken,
                publicKey: ATProtoJWTVerificationKey.p256(p256Key.publicKey)
            )
        ) { error in
            XCTAssertEqual(error as? PetrelCryptoError, .malformed("duplicate JSON member"))
        }
    }
}

private func highSVariant(of canonicalSignature: Data) -> Data {
    precondition(canonicalSignature.count == 64)
    let order: [UInt8] = [
        0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
        0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51,
    ]
    let lowS = Array(canonicalSignature.suffix(32))
    var highS = Array(repeating: UInt8.zero, count: 32)
    var borrow = 0
    for index in stride(from: 31, through: 0, by: -1) {
        var value = Int(order[index]) - Int(lowS[index]) - borrow
        if value < 0 {
            value += 256
            borrow = 1
        } else {
            borrow = 0
        }
        highS[index] = UInt8(value)
    }
    precondition(borrow == 0)
    return Data(canonicalSignature.prefix(32)) + Data(highS)
}
