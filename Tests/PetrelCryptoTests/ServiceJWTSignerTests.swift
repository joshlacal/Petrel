import Foundation
import PetrelCrypto
import Testing

/// Service JWTs minted and verified through the curve-agnostic key API.
/// Claim validation itself is covered by `ServiceJWTTests`.
@Suite("Service JWTs through ATProtoSigner and ATProtoPublicKey")
struct ServiceJWTSignerTests {
    static let issuer = "did:plc:abcdefghijklmnopqrstuvwx"
    static let audience = "did:web:api.bsky.app"
    static let method = "com.atproto.repo.getRecord"
    static let now = Date(timeIntervalSince1970: 1_700_000_000)

    static func mint(_ signer: any ATProtoSigner, eventID: String = "event-1") async throws -> String {
        try await ServiceJWT.mint(
            issuer: issuer, audience: audience, method: method, eventID: eventID, signer: signer, now: now
        )
    }

    @Test("Mint with any signer, verify with the public key", arguments: ATProtoKeyCurve.allCases)
    func mintAndVerify(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let token = try await Self.mint(keypair)

        let inspection = try ServiceJWT.inspect(token)
        #expect(inspection.algorithm == curve.jwtAlgorithm)
        #expect(inspection.issuer == Self.issuer)

        let claims = try ServiceJWT.verify(
            token, publicKey: keypair.publicKey, expectedAudience: Self.audience, expectedMethod: Self.method, now: Self.now
        )
        #expect(claims.iss == Self.issuer)
        #expect(claims.aud == Self.audience)
        #expect(claims.lxm == Self.method)
        #expect(claims.jti == "event-1")
        #expect(claims.exp == 1_700_000_060)

        // The same token verifies through the older entry points.
        let viaDIDKey = try ServiceJWT.verify(token, didKey: keypair.didKey, now: Self.now)
        #expect(viaDIDKey == claims)
        let viaLegacyKey = try ServiceJWT.verify(token, publicKey: PLCDIDVerificationKey(keypair.publicKey), now: Self.now)
        #expect(viaLegacyKey == claims)

        // The signature is the wire form.
        let signature = try JWTBase64URL.decode(String(token.split(separator: ".")[2]))
        #expect(ATProtoSignature.isCanonical(signature, curve: curve))

        // Another key, on either curve, does not verify it.
        for other in ATProtoKeyCurve.allCases {
            let stranger = ATProtoCrypto.generateKeypair(curve: other).publicKey
            #expect(throws: PetrelCryptoError.self) {
                _ = try ServiceJWT.verify(token, publicKey: stranger, now: Self.now)
            }
        }
    }

    @Test("A high-S JWT signature is accepted by default and rejected when strict", arguments: ATProtoKeyCurve.allCases)
    func highSPolicy(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let token = try await Self.mint(keypair)
        let parts = token.split(separator: ".").map(String.init)
        let highS = try highSTwin(of: JWTBase64URL.decode(parts[2]), curve: curve)
        let highSToken = "\(parts[0]).\(parts[1]).\(JWTBase64URL.encode(highS))"

        let claims = try ServiceJWT.verify(highSToken, publicKey: keypair.publicKey, now: Self.now)
        #expect(claims.jti == "event-1")
        let viaDIDKey = try ServiceJWT.verify(highSToken, didKey: keypair.didKey, now: Self.now)
        #expect(viaDIDKey == claims)

        #expect(throws: PetrelCryptoError.self) {
            _ = try ServiceJWT.verify(highSToken, publicKey: keypair.publicKey, signatureOptions: .strict, now: Self.now)
        }
        // Strict still accepts the canonical token.
        let strictClaims = try ServiceJWT.verify(token, publicKey: keypair.publicKey, signatureOptions: .strict, now: Self.now)
        #expect(strictClaims == claims)
    }

    @Test("A DER-encoded JWT signature is not a JWS signature", arguments: ATProtoKeyCurve.allCases)
    func derIsNotAJWSSignature(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let token = try await Self.mint(keypair)
        let parts = token.split(separator: ".").map(String.init)
        let der = try derEncoding(of: JWTBase64URL.decode(parts[2]), curve: curve)
        let derToken = "\(parts[0]).\(parts[1]).\(JWTBase64URL.encode(der))"

        for options in [ATProtoSignatureVerificationOptions.strict, .jwt] {
            #expect(throws: PetrelCryptoError.self) {
                _ = try ServiceJWT.verify(derToken, publicKey: keypair.publicKey, signatureOptions: options, now: Self.now)
            }
        }
        #expect(throws: PetrelCryptoError.self) {
            _ = try ServiceJWT.verify(derToken, didKey: keypair.didKey, now: Self.now)
        }
    }

    @Test("A tampered payload or signature is rejected under every policy", arguments: ATProtoKeyCurve.allCases)
    func tamperingIsRejected(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let token = try await Self.mint(keypair)
        let other = try await Self.mint(keypair, eventID: "event-2")
        let parts = token.split(separator: ".").map(String.init)
        let otherParts = other.split(separator: ".").map(String.init)

        // event-2's claims under event-1's signature.
        let spliced = "\(parts[0]).\(otherParts[1]).\(parts[2])"
        var signature = try JWTBase64URL.decode(parts[2])
        signature[signature.startIndex + 40] ^= 0x01
        let flipped = "\(parts[0]).\(parts[1]).\(JWTBase64URL.encode(signature))"

        for options in [ATProtoSignatureVerificationOptions.strict, .jwt, .allowMalleable] {
            for candidate in [spliced, flipped] {
                #expect(throws: PetrelCryptoError.self) {
                    _ = try ServiceJWT.verify(
                        candidate, publicKey: keypair.publicKey, signatureOptions: options, now: Self.now
                    )
                }
            }
        }
    }

    @Test("Minting through an external signer")
    func mintThroughExternalSigner() async throws {
        let backing = K256Keypair.generate()
        let signer = ATProtoExternalSigner(publicKey: backing.publicKey) { request in
            // A remote signer that answers in DER with whichever S it likes.
            try derEncoding(of: highSTwin(of: backing.sign(request.message), curve: .k256), curve: .k256)
        }
        let token = try await Self.mint(signer)
        #expect(try ServiceJWT.inspect(token).algorithm == "ES256K")
        let claims = try ServiceJWT.verify(token, publicKey: backing.publicKey, signatureOptions: .strict, now: Self.now)
        #expect(claims.jti == "event-1")
    }

    @Test("A signer that breaks the wire contract cannot mint")
    func nonCanonicalSignerIsRefused() async throws {
        struct RawSigner: ATProtoSigner {
            let curve: ATProtoKeyCurve
            let output: @Sendable (Data) throws -> Data
            func sign(_ message: Data) async throws -> Data { try output(message) }
        }
        let keypair = P256Keypair.generate()

        let highS = RawSigner(curve: .p256) { try highSTwin(of: keypair.sign($0), curve: .p256) }
        await #expect(throws: PetrelCryptoError.self) { _ = try await Self.mint(highS) }

        let der = RawSigner(curve: .p256) { try derEncoding(of: keypair.sign($0), curve: .p256) }
        await #expect(throws: PetrelCryptoError.self) { _ = try await Self.mint(der) }

        let empty = RawSigner(curve: .k256) { _ in Data() }
        await #expect(throws: PetrelCryptoError.self) { _ = try await Self.mint(empty) }

        // Invalid claims are refused before the signer is ever called.
        let neverCalled = RawSigner(curve: .p256) { _ in
            Issue.record("signer must not be called for invalid claims")
            return Data()
        }
        await #expect(throws: PetrelCryptoError.self) {
            _ = try await ServiceJWT.mint(
                issuer: "not-a-did", audience: Self.audience, method: Self.method, eventID: "x", signer: neverCalled
            )
        }
    }
}
