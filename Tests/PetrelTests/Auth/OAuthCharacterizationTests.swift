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

        // For this specific fixed key, calculate expected RFC 7638 thumbprint
        let pubX963 = key.publicKey.x963Representation
        let x = pubX963.dropFirst().prefix(32)
        let y = pubX963.suffix(32)
        let xB64 = JWTBase64URL.encode(Data(x))
        let yB64 = JWTBase64URL.encode(Data(y))

        let canonicalJSON = "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(xB64)\",\"y\":\"\(yB64)\"}"
        let expectedHash = SHA256.hash(data: Data(canonicalJSON.utf8))
        let expectedThumbprint = JWTBase64URL.encode(Data(expectedHash))

        #expect(thumbprint == expectedThumbprint)
        #expect(!thumbprint.isEmpty)
        #expect(!thumbprint.contains("="))
        #expect(!thumbprint.contains("+"))
        #expect(!thumbprint.contains("/"))
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

        let pubX963 = key.publicKey.x963Representation
        let x = pubX963.dropFirst().prefix(32)
        let y = pubX963.suffix(32)
        #expect(jwkDict["x"] as? String == JWTBase64URL.encode(Data(x)))
        #expect(jwkDict["y"] as? String == JWTBase64URL.encode(Data(y)))

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

        let (proof, thumbprint) = try await core.createDPoPProofWithMaterial(
            for: method,
            url: url,
            type: .authorization,
            ephemeralKeyRawRepresentation: key.rawRepresentation,
            nonce: nonce
        )

        let parts = proof.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts.count == 3)

        let headerString = String(parts[0])
        let payloadString = String(parts[1])
        let signatureString = String(parts[2])

        // Verify unpadded base64url
        #expect(!headerString.contains("="))
        #expect(!payloadString.contains("="))
        #expect(!signatureString.contains("="))

        // Verify payload JSON
        let payloadData = try JWTBase64URL.decode(payloadString)
        let payloadDict = try #require(try JSONSerialization.jsonObject(with: payloadData) as? [String: Any])

        #expect(payloadDict["htm"] as? String == method)
        #expect(payloadDict["htu"] as? String == url)
        #expect(payloadDict["nonce"] as? String == nonce)
        #expect(payloadDict["jti"] != nil)
        #expect(payloadDict["iat"] != nil)
        #expect(payloadDict["exp"] != nil)

        // Verify signature
        let signingInput = "\(headerString).\(payloadString)"
        let signatureBytes = try JWTBase64URL.decode(signatureString)
        #expect(signatureBytes.count == 64)

        // Must be canonical low-S
        #expect(P256WireSignature.isCanonicalLowS(signatureBytes))

        // Must cryptographically verify against the public key
        let ecdsaSig = try P256.Signing.ECDSASignature(rawRepresentation: signatureBytes)
        let isValid = key.publicKey.isValidSignature(ecdsaSig, for: Data(signingInput.utf8))
        #expect(isValid)

        // Verify thumbprint
        let expectedThumbprint = try await core.calculateJWKThumbprint(jwk: core.createJWK(from: key))
        #expect(thumbprint == expectedThumbprint)
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
