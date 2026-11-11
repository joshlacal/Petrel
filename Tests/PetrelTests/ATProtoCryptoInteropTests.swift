import Crypto
import Foundation
import Petrel
import Testing

/// Runs the official AT Protocol crypto interop vectors.
///
/// The three JSON files under `Tests/PetrelTests/Vectors/crypto` are
/// unmodified copies of `crypto/` in
/// https://github.com/bluesky-social/atproto-interop-tests (CC0). Every entry
/// of every file is read from disk and exercised; nothing is transcribed
/// into this source file.
///
/// Only `import Petrel` is used, which shows the crypto API is reachable
/// through the umbrella module as well as through `PetrelCrypto`.
@Suite("AT Protocol crypto interop vectors")
struct ATProtoCryptoInteropTests {
    // MARK: - Vector file shapes

    struct SignatureFixture: Decodable, Sendable, CustomTestStringConvertible {
        let comment: String
        let messageBase64: String
        let algorithm: String
        let didDocSuite: String
        let publicKeyDid: String
        let publicKeyMultibase: String
        let signatureBase64: String
        let validSignature: Bool
        let tags: [String]

        var testDescription: String { comment }

        var message: Data {
            get throws { try decodeUnpaddedBase64(messageBase64) }
        }

        var signature: Data {
            get throws { try decodeUnpaddedBase64(signatureBase64) }
        }
    }

    struct K256KeyVector: Decodable, Sendable, CustomTestStringConvertible {
        let privateKeyBytesHex: String
        let publicDidKey: String

        var testDescription: String { publicDidKey }
    }

    struct P256KeyVector: Decodable, Sendable, CustomTestStringConvertible {
        let privateKeyBytesBase58: String
        let publicDidKey: String

        var testDescription: String { publicDidKey }
    }

    static let signatureFixtures: [SignatureFixture] = loadVectors("signature-fixtures")
    static let k256Keys: [K256KeyVector] = loadVectors("w3c_didkey_K256")
    static let p256Keys: [P256KeyVector] = loadVectors("w3c_didkey_P256")

    // MARK: - Files are present and complete

    @Test("All three vector files load, with the expected coverage")
    func vectorFilesLoad() {
        #expect(Self.signatureFixtures.count == 6)
        #expect(Self.k256Keys.count == 5)
        #expect(Self.p256Keys.count == 1)

        // Same floor the reference test suite asserts.
        #expect(Self.signatureFixtures.filter { $0.tags.contains("high-s") }.count >= 2)
        #expect(Self.signatureFixtures.filter { $0.tags.contains("der-encoded") }.count >= 2)
        for algorithm in ["ES256", "ES256K"] {
            let ofCurve = Self.signatureFixtures.filter { $0.algorithm == algorithm }
            #expect(ofCurve.contains { $0.validSignature })
            #expect(ofCurve.contains { !$0.validSignature })
        }
    }

    // MARK: - signature-fixtures.json

    @Test("Strict verification matches validSignature", arguments: signatureFixtures)
    func strictVerificationMatchesFixture(_ fixture: SignatureFixture) throws {
        let message = try fixture.message
        let signature = try fixture.signature
        let verified = try ATProtoCrypto.verifySignature(
            didKey: fixture.publicKeyDid,
            data: message,
            signature: signature
        )
        #expect(verified == fixture.validSignature)

        // The curve is read from the did:key and agrees with the fixture.
        let key = try ATProtoPublicKey(didKey: fixture.publicKeyDid)
        #expect(key.jwtAlgorithm == fixture.algorithm)
        let verifiedWithExpectedAlgorithm = try ATProtoCrypto.verifySignature(
            didKey: fixture.publicKeyDid,
            data: message,
            signature: signature,
            expectedJWTAlgorithm: fixture.algorithm
        )
        #expect(verifiedWithExpectedAlgorithm == fixture.validSignature)
        #expect(key.isValidSignature(signature, for: message) == fixture.validSignature)
    }

    @Test("High-S signatures verify only when explicitly allowed", arguments: signatureFixtures.filter { $0.tags.contains("high-s") })
    func highSNeedsExplicitOption(_ fixture: SignatureFixture) throws {
        let key = try ATProtoPublicKey(didKey: fixture.publicKeyDid)
        let message = try fixture.message
        let signature = try fixture.signature

        #expect(signature.count == 64)
        #expect(!ATProtoSignature.isLowS(signature, curve: key.curve))
        #expect(fixture.validSignature == false)
        #expect(!key.isValidSignature(signature, for: message, options: .strict))
        // JWT policy: compact encoding, either S.
        #expect(key.isValidSignature(signature, for: message, options: .jwt))
        // TypeScript `allowMalleableSig: true`.
        #expect(key.isValidSignature(signature, for: message, options: .allowMalleable))
        let verifiedByDIDKey = try ATProtoCrypto.verifySignature(
            didKey: fixture.publicKeyDid, data: message, signature: signature, options: .allowMalleable
        )
        #expect(verifiedByDIDKey)

        // Folding S gives the canonical twin, which verifies strictly.
        let canonical = try ATProtoSignature.canonicalize(signature, curve: key.curve)
        #expect(canonical != signature)
        #expect(key.isValidSignature(canonical, for: message))
    }

    @Test("DER signatures verify only when explicitly allowed", arguments: signatureFixtures.filter { $0.tags.contains("der-encoded") })
    func derNeedsExplicitOption(_ fixture: SignatureFixture) throws {
        let key = try ATProtoPublicKey(didKey: fixture.publicKeyDid)
        let message = try fixture.message
        let signature = try fixture.signature

        #expect(signature.count != 64)
        #expect(fixture.validSignature == false)
        #expect(!key.isValidSignature(signature, for: message, options: .strict))
        // A JWS signature is always R || S (RFC 7518 3.4): DER stays invalid.
        #expect(!key.isValidSignature(signature, for: message, options: .jwt))
        // TypeScript `allowMalleableSig: true` also admits DER.
        #expect(key.isValidSignature(signature, for: message, options: .allowMalleable))

        // The DER body is a real signature: re-encoded compact it verifies.
        let compact = try ATProtoSignature.compactRepresentation(fromDER: signature, curve: key.curve)
        #expect(compact.count == 64)
        let canonical = try ATProtoSignature.canonicalize(compact, curve: key.curve)
        #expect(key.isValidSignature(canonical, for: message))
    }

    @Test("Legacy and Multikey encodings of a fixture key agree", arguments: signatureFixtures)
    func keyEncodingsAgree(_ fixture: SignatureFixture) throws {
        let fromDIDKey = try ATProtoPublicKey(didKey: fixture.publicKeyDid)

        // `publicKeyMultibase` is the pre-Multikey form: no multicodec
        // prefix, curve carried by `didDocSuite`.
        let fromLegacy = try ATProtoPublicKey(
            verificationMethodType: fixture.didDocSuite,
            publicKeyMultibase: fixture.publicKeyMultibase
        )
        #expect(fromLegacy == fromDIDKey)
        #expect(fromLegacy.curve.legacyVerificationMethodType == fixture.didDocSuite)

        // Round trips.
        #expect(fromDIDKey.didKey == fixture.publicKeyDid)
        #expect("did:key:" + fromDIDKey.multikey == fixture.publicKeyDid)
        let fromMultikey = try ATProtoPublicKey(multikey: fromDIDKey.multikey)
        #expect(fromMultikey == fromDIDKey)
        let fromMultikeyMethod = try ATProtoPublicKey(
            verificationMethodType: "Multikey", publicKeyMultibase: fromDIDKey.multikey
        )
        #expect(fromMultikeyMethod == fromDIDKey)
        let uncompressed = try fromDIDKey.uncompressedRepresentation
        #expect(uncompressed.count == 65)
        #expect(uncompressed.first == 0x04)
        let fromUncompressedLegacy = try ATProtoPublicKey(
            legacyMultibase: fromDIDKey.legacyMultibase, curve: fromDIDKey.curve
        )
        #expect(fromUncompressedLegacy == fromDIDKey)
    }

    @Test("A tampered message or a different key never verifies", arguments: signatureFixtures.filter(\.validSignature))
    func tamperingFailsVerification(_ fixture: SignatureFixture) throws {
        let key = try ATProtoPublicKey(didKey: fixture.publicKeyDid)
        let message = try fixture.message
        let signature = try fixture.signature

        var tamperedMessage = message
        tamperedMessage[tamperedMessage.startIndex] ^= 0x01
        var tamperedSignature = signature
        tamperedSignature[tamperedSignature.startIndex + 5] ^= 0x01

        for options in [ATProtoSignatureVerificationOptions.strict, .jwt, .allowMalleable] {
            #expect(key.isValidSignature(signature, for: message, options: options))
            #expect(!key.isValidSignature(signature, for: tamperedMessage, options: options))
            #expect(!key.isValidSignature(tamperedSignature, for: message, options: options))
            #expect(!key.isValidSignature(Data(signature.dropLast()), for: message, options: options))
            #expect(!key.isValidSignature(signature + Data([0]), for: message, options: options))
        }

        // Every other key in the file, on either curve, rejects it.
        for other in Self.signatureFixtures where other.publicKeyDid != fixture.publicKeyDid {
            let otherKey = try ATProtoPublicKey(didKey: other.publicKeyDid)
            #expect(!otherKey.isValidSignature(signature, for: message, options: .allowMalleable))
        }

        // Asking for the other curve's algorithm is an error, not `false`.
        let wrongAlgorithm = fixture.algorithm == "ES256" ? "ES256K" : "ES256"
        #expect(throws: PetrelCryptoError.self) {
            try ATProtoCrypto.verifySignature(
                didKey: fixture.publicKeyDid,
                data: message,
                signature: signature,
                expectedJWTAlgorithm: wrongAlgorithm
            )
        }
    }

    @Test("The pre-existing did:key verifier agrees with every fixture", arguments: signatureFixtures)
    func legacyVerifierAgrees(_ fixture: SignatureFixture) throws {
        let key = try PLCDIDKeyCodec.decode(fixture.publicKeyDid)
        // This older entry point reports a non-canonical signature by
        // throwing rather than returning false.
        let verified = (try? key.verify(
            signature: fixture.signature,
            signingInput: fixture.message,
            algorithm: fixture.algorithm
        )) ?? false
        #expect(verified == fixture.validSignature)
        let bridged = try key.publicKey()
        let direct = try ATProtoPublicKey(didKey: fixture.publicKeyDid)
        #expect(bridged == direct)
        #expect(key.multikey == String(fixture.publicKeyDid.dropFirst("did:key:".count)))
    }

    // MARK: - w3c_didkey_K256.json

    @Test("K-256 private key derives the published did:key", arguments: k256Keys)
    func k256PrivateKeyDerivesDIDKey(_ vector: K256KeyVector) async throws {
        let keypair = try K256Keypair(hex: vector.privateKeyBytesHex)
        #expect(keypair.didKey == vector.publicDidKey)
        #expect(keypair.curve == .k256)
        #expect(keypair.jwtAlgorithm == "ES256K")
        let exportedHex = try keypair.exportHex()
        #expect(exportedHex == vector.privateKeyBytesHex)

        // Same key through the curve-agnostic entry point and through the
        // self-describing private multikey.
        let generic = try ATProtoCrypto.importKeypair(curve: .k256, hex: vector.privateKeyBytesHex)
        #expect(generic.didKey == vector.publicDidKey)
        let restored = try ATProtoCrypto.importKeypair(privateMultibase: keypair.exportMultibase())
        #expect(restored.didKey == vector.publicDidKey)
        #expect(restored.curve == .k256)

        // The derived key signs something the published did:key verifies.
        let message = Data("w3c K-256 vector".utf8)
        let signature = try await generic.sign(message)
        #expect(ATProtoSignature.isCanonical(signature, curve: .k256))
        let verified = try ATProtoCrypto.verifySignature(
            didKey: vector.publicDidKey, data: message, signature: signature
        )
        #expect(verified)
    }

    // MARK: - w3c_didkey_P256.json

    @Test("P-256 private key derives the published did:key", arguments: p256Keys)
    func p256PrivateKeyDerivesDIDKey(_ vector: P256KeyVector) async throws {
        // The file gives the bare scalar in base58btc, without a multibase
        // prefix.
        let scalar = try Base58BTC.decode(vector.privateKeyBytesBase58)
        #expect(scalar.count == 32)

        let keypair = try P256Keypair(rawRepresentation: scalar)
        #expect(keypair.didKey == vector.publicDidKey)
        #expect(keypair.curve == .p256)
        #expect(keypair.jwtAlgorithm == "ES256")
        #expect(Base58BTC.encode(keypair.exportRawRepresentation()) == vector.privateKeyBytesBase58)

        // The same scalar as multibase (z + base58btc).
        let fromMultibase = try P256Keypair(multibase: "z" + vector.privateKeyBytesBase58)
        #expect(fromMultibase.didKey == vector.publicDidKey)
        let restored = try ATProtoCrypto.importKeypair(privateMultibase: keypair.exportMultibase())
        #expect(restored.didKey == vector.publicDidKey)
        #expect(restored.curve == .p256)

        let message = Data("w3c P-256 vector".utf8)
        let signature = try await restored.sign(message)
        #expect(ATProtoSignature.isCanonical(signature, curve: .p256))
        let verified = try ATProtoCrypto.verifySignature(
            didKey: vector.publicDidKey, data: message, signature: signature
        )
        #expect(verified)
    }
}

// MARK: - Loading

private func loadVectors<T: Decodable>(_ name: String) -> [T] {
    guard let url = Bundle.module.url(
        forResource: name, withExtension: "json", subdirectory: "Vectors/crypto"
    ) else {
        Issue.record("missing vector file Vectors/crypto/\(name).json")
        return []
    }
    do {
        return try JSONDecoder().decode([T].self, from: Data(contentsOf: url))
    } catch {
        Issue.record("could not decode Vectors/crypto/\(name).json: \(error)")
        return []
    }
}

/// The fixtures use standard-alphabet base64 without `=` padding.
private func decodeUnpaddedBase64(_ value: String) throws -> Data {
    let padded = value + String(repeating: "=", count: (4 - value.utf8.count % 4) % 4)
    guard let data = Data(base64Encoded: padded) else {
        throw PetrelCryptoError.malformed("fixture is not base64")
    }
    return data
}
