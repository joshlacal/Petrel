import Crypto
import Foundation
@testable import Petrel
import PetrelCrypto
import Testing

@Suite("OAuth and DPoP Characterization Tests")
struct OAuthCharacterizationTests {
    // Fixed P-256 private key raw 32 bytes for deterministic tests
    static let fixedRawPrivateKeyBytes: [UInt8] = [
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
    ]

    private func makeFixedKey() throws -> P256.Signing.PrivateKey {
        try P256.Signing.PrivateKey(rawRepresentation: Data(Self.fixedRawPrivateKeyBytes))
    }

    private func makeOAuthCore() -> OAuthCore {
        let storage = KeychainStorage(namespace: "test.characterization.\(UUID().uuidString)")
        let accountManager = MockAccountManager(account: Account(
            did: "did:plc:characterization",
            handle: "char.test",
            pdsURL: URL(string: "https://pds.example.com")!
        ))
        let networkService = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
        let config = OAuthConfig(
            clientId: "https://app.example/oauth/client-metadata.json",
            redirectUri: "app.example://oauth/callback",
            scope: "atproto transition:generic"
        )
        return OAuthCore(
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            oauthConfig: config,
            didResolver: MockDIDResolver()
        )
    }

    @Test("JWK thumbprint calculation is deterministic and matches RFC 7638")
    func jwkThumbprintMatchesRFC7638() async throws {
        let key = try makeFixedKey()
        let core = makeOAuthCore()

        let jwk = try await core.createJWK(from: key)
        let thumbprint = try await core.calculateJWKThumbprint(jwk: jwk)

        // Golden vector pinned literals for fixed key (no leading zeros)
        #expect(jwk.x == "UVw9brnjlrkE0_7Kf1T9zQzB6Ze_N13KUVrQpsO0A18")
        #expect(jwk.y == "RTa-OlDzGPv5pUdZAqIhUCvvDVfgjFOyzApW8X2fk1Q")
        #expect(thumbprint == "6UoWwDCkLjV0J-pQG8c0THxbVhBcpR0AZDift1Yl5DM")
        #expect(!thumbprint.contains("="))
        #expect(!thumbprint.contains("+"))
        #expect(!thumbprint.contains("/"))

        // Leading-zero Y coordinate case (scalar 43): 32-byte fixed-width encoding must be preserved
        let keyWithLeadingZeroY = try P256.Signing.PrivateKey(
            rawRepresentation: Data([
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2b,
            ])
        )
        let jwkZeroY = try await core.createJWK(from: keyWithLeadingZeroY)
        let thumbprintZeroY = try await core.calculateJWKThumbprint(jwk: jwkZeroY)
        #expect(jwkZeroY.x == "mGriUG8f8QTQQjCGHY9LSY9LxMbQCbMPdUTcEpuC0o0")
        #expect(jwkZeroY.y == "ADzMwKZGDgrjKKTZfTx7YdhvxiicGJ8lJREMRBuwfpc")
        #expect(jwkZeroY.y.hasPrefix("A"))
        #expect(jwkZeroY.x.count == 43)
        #expect(jwkZeroY.y.count == 43)
        #expect(thumbprintZeroY == "WZsjbh58q8kl1WsGShqtiycImZtCgGbukDn4RAacMig")

        // Leading-zero X coordinate case (scalar 379): 32-byte fixed-width encoding must be preserved
        let keyWithLeadingZeroX = try P256.Signing.PrivateKey(
            rawRepresentation: Data([
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x7b,
            ])
        )
        let jwkZeroX = try await core.createJWK(from: keyWithLeadingZeroX)
        let thumbprintZeroX = try await core.calculateJWKThumbprint(jwk: jwkZeroX)
        #expect(jwkZeroX.x == "AFVDiUrz0A7X10Cr29dclrBod7eH219w7qeLkKjXwAo")
        #expect(jwkZeroX.y == "u0yFo9jqKe-q-iRAaRLdhNWxTcMr9lbvbGvVil2UP5I")
        #expect(jwkZeroX.x.hasPrefix("A"))
        #expect(jwkZeroX.x.count == 43)
        #expect(jwkZeroX.y.count == 43)
        #expect(thumbprintZeroX == "7Yxe6c_3bAa6kiaK1G-BZmi9EeNsUmlcbdnrtLeuK4E")
    }

    @Test("DPoP precomputed material header structure matches JOSE wire format")
    func dpopHeaderStructureMatchesWireFormat() async throws {
        let key = try makeFixedKey()
        let core = makeOAuthCore()

        let material = try await core.precomputeDPoPMaterial(for: key)

        // Header Base64 decoded
        let headerData = try JWTBase64URL.decode(material.headerBase64)
        let jsonObject = try JSONSerialization.jsonObject(with: headerData) as? [String: Any]
        let header = try #require(jsonObject)

        #expect(header["typ"] as? String == "dpop+jwt")
        #expect(header["alg"] as? String == "ES256")

        let jwkDict = try #require(header["jwk"] as? [String: Any])
        #expect(jwkDict["kty"] as? String == "EC")
        #expect(jwkDict["crv"] as? String == "P-256")
        #expect(jwkDict["x"] as? String == "UVw9brnjlrkE0_7Kf1T9zQzB6Ze_N13KUVrQpsO0A18")
        #expect(jwkDict["y"] as? String == "RTa-OlDzGPv5pUdZAqIhUCvvDVfgjFOyzApW8X2fk1Q")

        #expect(material.thumbprint == "6UoWwDCkLjV0J-pQG8c0THxbVhBcpR0AZDift1Yl5DM")

        // Member set check
        let jwkKeys = Set(jwkDict.keys)
        #expect(jwkKeys == ["kty", "crv", "x", "y"])

        let headerKeys = Set(header.keys)
        #expect(headerKeys == ["typ", "alg", "jwk"])
    }

    @Test("DPoP proof generation produces valid, verifiable compact JWS")
    func dpopProofGenerationProducesVerifiableJWS() async throws {
        let key = try makeFixedKey()
        let core = makeOAuthCore()

        let url = "https://pds.example.com/xrpc/app.bsky.actor.getProfile"
        let method = "GET"
        let nonce = "test-nonce-123"

        let beforeTime = Int(Date().timeIntervalSince1970)

        let (proof1, thumbprint1) = try await core.createDPoPProofWithMaterial(
            for: method,
            url: url,
            type: .authorization,
            ephemeralKeyRawRepresentation: key.rawRepresentation,
            nonce: nonce
        )

        let (proof2, thumbprint2) = try await core.createDPoPProofWithMaterial(
            for: method,
            url: url,
            type: .authorization,
            ephemeralKeyRawRepresentation: key.rawRepresentation,
            nonce: nonce
        )

        let afterTime = Int(Date().timeIntervalSince1970)

        // Proof 1 validation
        let parts1 = proof1.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts1.count == 3)

        let headerString1 = String(parts1[0])
        let payloadString1 = String(parts1[1])
        let signatureString1 = String(parts1[2])

        #expect(!headerString1.contains("="))
        #expect(!payloadString1.contains("="))
        #expect(!signatureString1.contains("="))

        let payloadData1 = try JWTBase64URL.decode(payloadString1)
        let payloadDict1 = try #require(try JSONSerialization.jsonObject(with: payloadData1) as? [String: Any])

        #expect(payloadDict1["htm"] as? String == method)
        #expect(payloadDict1["htu"] as? String == url)
        #expect(payloadDict1["nonce"] as? String == nonce)

        let jti1 = try #require(payloadDict1["jti"] as? String)
        #expect(!jti1.isEmpty)

        let iat1 = try #require(payloadDict1["iat"] as? Int)
        #expect(iat1 >= beforeTime && iat1 <= afterTime)

        let exp1 = try #require(payloadDict1["exp"] as? Int)
        #expect(exp1 > iat1)
        #expect(exp1 > afterTime)

        // Proof 2 validation & distinct claims assertion
        let parts2 = proof2.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts2.count == 3)

        let payloadData2 = try JWTBase64URL.decode(String(parts2[1]))
        let payloadDict2 = try #require(try JSONSerialization.jsonObject(with: payloadData2) as? [String: Any])

        let jti2 = try #require(payloadDict2["jti"] as? String)
        #expect(!jti2.isEmpty)
        #expect(jti1 != jti2)

        let iat2 = try #require(payloadDict2["iat"] as? Int)
        #expect(iat2 >= beforeTime && iat2 <= afterTime)

        let exp2 = try #require(payloadDict2["exp"] as? Int)
        #expect(exp2 > iat2)
        #expect(exp2 > afterTime)

        // Signature verification (Proof 1)
        let signingInput1 = "\(headerString1).\(payloadString1)"
        let signatureBytes1 = try JWTBase64URL.decode(signatureString1)
        #expect(signatureBytes1.count == 64)
        #expect(P256WireSignature.isCanonicalLowS(signatureBytes1))
        let ecdsaSig1 = try P256.Signing.ECDSASignature(rawRepresentation: signatureBytes1)
        let isValid1 = key.publicKey.isValidSignature(ecdsaSig1, for: Data(signingInput1.utf8))
        #expect(isValid1)

        // Signature verification (Proof 2)
        let signingInput2 = "\(String(parts2[0])).\(String(parts2[1]))"
        let signatureBytes2 = try JWTBase64URL.decode(String(parts2[2]))
        #expect(signatureBytes2.count == 64)
        #expect(P256WireSignature.isCanonicalLowS(signatureBytes2))
        let ecdsaSig2 = try P256.Signing.ECDSASignature(rawRepresentation: signatureBytes2)
        let isValid2 = key.publicKey.isValidSignature(ecdsaSig2, for: Data(signingInput2.utf8))
        #expect(isValid2)

        // Verify thumbprints match pinned literal
        #expect(thumbprint1 == "6UoWwDCkLjV0J-pQG8c0THxbVhBcpR0AZDift1Yl5DM")
        #expect(thumbprint2 == "6UoWwDCkLjV0J-pQG8c0THxbVhBcpR0AZDift1Yl5DM")
    }

    @Test("ATH calculation matches SHA256 base64url")
    func athCalculation() async {
        let core = makeOAuthCore()
        let token = "secret-access-token-xyz-123"
        let ath = await core.calculateATH(from: token)

        let expectedHash = SHA256.hash(data: Data(token.utf8))
        let expectedATH = JWTBase64URL.encode(Data(expectedHash))

        #expect(ath == expectedATH)
    }
}
