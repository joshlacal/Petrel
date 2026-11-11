import Crypto
import Foundation
import PetrelCrypto
import secp256k1
import Testing

@Suite("Public key encodings: did:key, Multikey, legacy multibase")
struct ATProtoPublicKeyTests {
    // "Encoded Examples" in the Cryptography specification.
    static let specP256Multikey = "zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo"
    static let specK256Multikey = "zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc"

    // "Legacy Representation" example in the DID specification: one K-256
    // key, legacy (uncompressed, no multicodec) and preferred (Multikey).
    static let specLegacyK256 = "zQYEBzXeuTM9UR3rfvNag6L3RNAs5pQZyYPsomTsgQhsxLdEgCrPTLgFna8yqCnxPpNT7DBk6Ym3dgPKNu86vt9GR"
    static let specPreferredK256 = "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"

    @Test("Specification examples parse and re-encode exactly")
    func specificationExamples() throws {
        let p256 = try ATProtoPublicKey(multikey: Self.specP256Multikey)
        #expect(p256.curve == .p256)
        #expect(p256.multikey == Self.specP256Multikey)
        #expect(p256.didKey == "did:key:" + Self.specP256Multikey)
        #expect(p256.multikeyBytes.prefix(2) == Data([0x80, 0x24]))
        #expect(p256.multikeyBytes.count == 35)

        let k256 = try ATProtoPublicKey(didKey: "did:key:" + Self.specK256Multikey)
        #expect(k256.curve == .k256)
        #expect(k256.multikey == Self.specK256Multikey)
        #expect(k256.multikeyBytes.prefix(2) == Data([0xe7, 0x01]))
        #expect(k256.description == "did:key:" + Self.specK256Multikey)
    }

    @Test("The DID specification's legacy K-256 key is the same key as its Multikey form")
    func legacyAndPreferredAreTheSameKey() throws {
        let legacy = try ATProtoPublicKey(legacyMultibase: Self.specLegacyK256, curve: .k256)
        let preferred = try ATProtoPublicKey(multikey: Self.specPreferredK256)
        #expect(legacy == preferred)
        #expect(legacy.multikey == Self.specPreferredK256)
        #expect(try preferred.legacyMultibase == Self.specLegacyK256)

        // Through the verification-method entry point, as an identity resolver would call it.
        let fromLegacyMethod = try ATProtoPublicKey(
            verificationMethodType: "EcdsaSecp256k1VerificationKey2019",
            publicKeyMultibase: Self.specLegacyK256
        )
        let fromMultikeyMethod = try ATProtoPublicKey(
            verificationMethodType: "Multikey",
            publicKeyMultibase: Self.specPreferredK256
        )
        #expect(fromLegacyMethod == fromMultikeyMethod)

        // And through the older codec.
        let viaCodec = try PLCDIDKeyCodec.decodeLegacyMultibase(Self.specLegacyK256, curve: .secp256k1)
        #expect(viaCodec.multikey == Self.specPreferredK256)
        #expect(try PLCDIDKeyCodec.decodeMultikey(Self.specPreferredK256) == viaCodec)
    }

    @Test("A legacy uncompressed key whose Y is not on the curve is rejected", arguments: ATProtoKeyCurve.allCases)
    func corruptedYIsRejected(_ curve: ATProtoKeyCurve) throws {
        let key = ATProtoCrypto.generateKeypair(curve: curve).publicKey
        let uncompressed = try key.uncompressedRepresentation
        #expect(uncompressed.count == 65)

        // Sanity: the untouched point parses to the same key.
        let intact = try ATProtoPublicKey(legacyMultibase: "z" + Base58BTC.encode(uncompressed), curve: curve)
        #expect(intact == key)

        // Flip the lowest bit of Y. The result has the same X and a Y of
        // the opposite parity that does not satisfy the curve equation.
        var corrupted = uncompressed
        corrupted[corrupted.endIndex - 1] ^= 0x01
        let multibase = "z" + Base58BTC.encode(corrupted)

        #expect(throws: PetrelCryptoError.self) {
            _ = try ATProtoPublicKey(legacyMultibase: multibase, curve: curve)
        }
        #expect(throws: PetrelCryptoError.self) {
            _ = try ATProtoPublicKey(curve: curve, sec1Representation: corrupted)
        }
        #expect(throws: PetrelCryptoError.self) {
            _ = try ATProtoPublicKey(
                verificationMethodType: curve.legacyVerificationMethodType, publicKeyMultibase: multibase
            )
        }
        #expect(throws: PetrelCryptoError.self) {
            _ = try PLCDIDKeyCodec.decodeLegacyMultibase(multibase, curve: curve == .p256 ? .p256 : .secp256k1)
        }

        // Garbage Y entirely.
        let garbage = Data(uncompressed.prefix(33)) + Data(repeating: 0x5a, count: 32)
        #expect(throws: PetrelCryptoError.self) {
            _ = try PLCDIDKeyCodec.decodeLegacyMultibase(
                "z" + Base58BTC.encode(garbage), curve: curve == .p256 ? .p256 : .secp256k1
            )
        }
    }

    @Test("Compressed and uncompressed encodings denote one key", arguments: ATProtoKeyCurve.allCases)
    func oneKeyOneIdentity(_ curve: ATProtoKeyCurve) throws {
        let key = ATProtoCrypto.generateKeypair(curve: curve).publicKey
        let compressed = key.compressedRepresentation
        let uncompressed = try key.uncompressedRepresentation

        #expect(compressed.count == 33)
        #expect(compressed.first == 0x02 || compressed.first == 0x03)
        #expect(uncompressed.first == 0x04)
        #expect(uncompressed.dropFirst().prefix(32) == compressed.dropFirst())
        // Compression keeps the parity of Y.
        #expect(compressed.first == 0x02 + (uncompressed.last! & 1))

        let fromCompressed = try ATProtoPublicKey(curve: curve, sec1Representation: compressed)
        let fromUncompressed = try ATProtoPublicKey(curve: curve, sec1Representation: uncompressed)
        #expect(fromCompressed == fromUncompressed)
        #expect(fromCompressed.hashValue == fromUncompressed.hashValue)
        #expect(fromUncompressed.didKey == key.didKey)

        // A point is tied to its curve: the same bytes are (almost surely)
        // not a point on the other one, and never the same key.
        let otherCurve: ATProtoKeyCurve = curve == .p256 ? .k256 : .p256
        if let reinterpreted = try? ATProtoPublicKey(curve: otherCurve, sec1Representation: compressed) {
            #expect(reinterpreted != key)
            #expect(reinterpreted.didKey != key.didKey)
        }
    }

    @Test("Non-canonical or foreign multikeys are rejected")
    func nonCanonicalMultikeysAreRejected() throws {
        let p256 = P256Keypair.generate().publicKey
        let k256 = K256Keypair.generate().publicKey
        func multikey(_ bytes: Data) -> String { "z" + Base58BTC.encode(bytes) }

        let rejected: [String] = try [
            "",
            "z",
            // Not base58btc multibase.
            "m" + p256.multikey.dropFirst(),
            String(p256.multikey.dropFirst()),
            // Uncompressed point behind the multicodec prefix.
            multikey(Data([0x80, 0x24]) + p256.uncompressedRepresentation),
            multikey(Data([0xe7, 0x01]) + k256.uncompressedRepresentation),
            // Legacy form (no multicodec prefix) passed as a multikey.
            multikey(p256.compressedRepresentation),
            multikey(k256.compressedRepresentation),
            // X is not a field element.
            multikey(Data([0x80, 0x24]) + Data([0x02]) + Data(repeating: 0xff, count: 32)),
            multikey(Data([0xe7, 0x01]) + Data([0x02]) + Data(repeating: 0xff, count: 32)),
            // Truncated and extended.
            multikey(p256.multikeyBytes.dropLast()),
            multikey(k256.multikeyBytes + Data([0x00])),
            // Other key types: ed25519-pub (0xed 0x01), p384-pub (0x81 0x24).
            multikey(Data([0xed, 0x01]) + Data(repeating: 7, count: 32)),
            multikey(Data([0x81, 0x24]) + Data(repeating: 7, count: 33)),
            // A private multikey is not a public key.
            P256Keypair.generate().exportMultibase(),
            // Non-minimal base58: a leading "1" adds a zero byte.
            "z1" + p256.multikey.dropFirst(),
            // Characters outside the base58 alphabet.
            "z0" + p256.multikey.dropFirst(2),
            p256.multikey + " ",
        ]
        for value in rejected {
            #expect(throws: PetrelCryptoError.self, "\(value)") { _ = try ATProtoPublicKey(multikey: value) }
            #expect(throws: PetrelCryptoError.self, "\(value)") { _ = try ATProtoPublicKey(didKey: "did:key:" + value) }
            #expect(throws: PetrelCryptoError.self, "\(value)") { _ = try PLCDIDKeyCodec.decodeMultikey(value) }
            #expect(throws: PetrelCryptoError.self, "\(value)") { _ = try PLCDIDKeyCodec.decode("did:key:" + value) }
        }

        // did:key needs its exact prefix.
        for value in [p256.multikey, "DID:KEY:" + p256.multikey, "did:web:" + p256.multikey, " " + p256.didKey] {
            #expect(throws: PetrelCryptoError.self) { _ = try ATProtoPublicKey(didKey: value) }
        }

        // An unknown verification method type is an error naming the type.
        #expect(throws: PetrelCryptoError.unsupportedAlgorithm("verification method type Ed25519VerificationKey2020")) {
            _ = try ATProtoPublicKey(
                verificationMethodType: "Ed25519VerificationKey2020", publicKeyMultibase: p256.multikey
            )
        }
        // A legacy suite with the other curve's key does not parse as that curve's key.
        #expect(throws: PetrelCryptoError.self) {
            _ = try ATProtoPublicKey(
                verificationMethodType: "EcdsaSecp256k1VerificationKey2019",
                publicKeyMultibase: "z" + Base58BTC.encode(p256.uncompressedRepresentation)
            )
        }
    }

    // MARK: - Bridges to the older key types

    @Test("K-256 did:key encoding matches libsecp256k1's compressed point")
    func k256DIDKeyEncodingGolden() throws {
        // d = 1: the public key is the generator, whose compressed encoding
        // is the well-known 02 79be667e...
        let keypair = try K256Keypair(rawRepresentation: Data(repeating: 0, count: 31) + Data([1]))
        #expect(
            Hex.encode(keypair.publicKey.compressedRepresentation)
                == "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        )
        // base58btc(e7 01 || point), computed with an independent encoder.
        #expect(keypair.didKey == "did:key:zQ3shVc2UkAfJCdc1TR8E66J85h48P43r93q8jGPkPpjF9Ef9")

        let libraryKey = try secp256k1.Signing.PrivateKey(dataRepresentation: keypair.exportRawRepresentation())
        let legacy = PLCDIDVerificationKey.secp256k1(libraryKey.publicKey.dataRepresentation)
        #expect(legacy.didKey == keypair.didKey)
    }

    @Test("An uncompressed K-256 point always encodes to the canonical did:key")
    func uncompressedK256IsCompressedOnEncode() throws {
        let key = K256Keypair.generate().publicKey
        let uncompressed = try key.uncompressedRepresentation

        // Validating initializer.
        let validated = try PLCDIDVerificationKey(secp256k1PublicKey: uncompressed)
        #expect(validated.didKey == key.didKey)
        guard case let .secp256k1(stored) = validated else {
            Issue.record("expected a secp256k1 key")
            return
        }
        #expect(stored == key.compressedRepresentation)

        // A case built by hand from the uncompressed point used to yield a
        // 67-byte, undecodable did:key.
        let handBuilt = PLCDIDVerificationKey.secp256k1(uncompressed)
        #expect(handBuilt.didKey == key.didKey)
        #expect(handBuilt.didKeyBytes.count == 35)
        #expect(handBuilt == validated)
        #expect(try PLCDIDKeyCodec.decode(handBuilt.didKey) == validated)
        #expect(try handBuilt.publicKey() == key)

        #expect(throws: PetrelCryptoError.self) {
            _ = try PLCDIDVerificationKey(secp256k1PublicKey: Data(repeating: 4, count: 65))
        }
    }

    @Test("A K-256 verification key has one identity whichever encoding it came from")
    func k256VerificationKeyIdentityIsNormalized() throws {
        let keypair = K256Keypair.generate()
        let compressed = keypair.publicKey.compressedRepresentation
        let uncompressed = try keypair.publicKey.uncompressedRepresentation

        let fromCompressed = try ATProtoJWTVerificationKey(secp256k1PublicKey: compressed)
        let fromUncompressed = try ATProtoJWTVerificationKey(secp256k1PublicKey: uncompressed)
        let handBuilt = ATProtoJWTVerificationKey.secp256k1PublicKey(uncompressed)

        #expect(fromCompressed == fromUncompressed)
        #expect(fromCompressed == handBuilt)
        #expect(fromCompressed.deterministicIdentity == fromUncompressed.deterministicIdentity)
        #expect(fromCompressed.deterministicIdentity == handBuilt.deterministicIdentity)
        #expect(fromCompressed.recoveryVerifierIdentity == handBuilt.recoveryVerifierIdentity)
        #expect(try fromUncompressed.publicKey() == keypair.publicKey)
        #expect(try ATProtoJWTVerificationKey(keypair.publicKey) == fromCompressed)

        // All three verify the same signature.
        let message = Data("one key, one identity".utf8)
        let signature = try keypair.sign(message)
        for key in [fromCompressed, fromUncompressed, handBuilt] {
            #expect(try key.verify(signature: signature, signingInput: message, algorithm: "ES256K"))
        }
    }

    @Test("Bridging between ATProtoPublicKey and the older key enums is lossless", arguments: ATProtoKeyCurve.allCases)
    func bridgesAreLossless(_ curve: ATProtoKeyCurve) throws {
        let key = ATProtoCrypto.generateKeypair(curve: curve).publicKey

        let plc = try PLCDIDVerificationKey(key)
        #expect(plc.didKey == key.didKey)
        #expect(plc.multikey == key.multikey)
        #expect(try plc.publicKey() == key)
        #expect(try PLCDIDKeyCodec.decode(key.didKey) == plc)
        #expect(try PLCDIDKeyCodec.decodeMultikey(key.multikey) == plc)

        let jwt = try ATProtoJWTVerificationKey(key)
        #expect(try jwt.publicKey() == key)
        #expect(ATProtoJWTVerificationKey(plc) == jwt)

        if curve == .p256 {
            #expect(try key.p256Key().compressedRepresentation == key.compressedRepresentation)
            #expect(try ATProtoPublicKey(key.p256Key()) == key)
        } else {
            #expect(throws: PetrelCryptoError.self) { _ = try key.p256Key() }
        }
    }

    @Test("The older verification entry point is strict; the options overload can relax it", arguments: ATProtoKeyCurve.allCases)
    func legacyVerifyStrictAndLax(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let key = try ATProtoJWTVerificationKey(keypair.publicKey)
        let message = Data("strict by default".utf8)
        let signature = try await keypair.sign(message)
        let highS = try highSTwin(of: signature, curve: curve)
        let algorithm = curve.jwtAlgorithm

        #expect(try key.verify(signature: signature, signingInput: message, algorithm: algorithm))
        #expect(try key.verify(signature: signature, signingInput: message, algorithm: algorithm, options: .strict))
        #expect(try key.verify(signature: signature, signingInput: message, algorithm: algorithm, options: .jwt))

        // High-S: an error on the strict path, accepted under .jwt.
        #expect(throws: PetrelCryptoError.self) {
            _ = try key.verify(signature: highS, signingInput: message, algorithm: algorithm)
        }
        #expect(throws: PetrelCryptoError.self) {
            _ = try key.verify(signature: highS, signingInput: message, algorithm: algorithm, options: .strict)
        }
        #expect(try key.verify(signature: highS, signingInput: message, algorithm: algorithm, options: .jwt))

        // Wrong message under .jwt: false.
        #expect(try !key.verify(signature: highS, signingInput: message + Data([1]), algorithm: algorithm, options: .jwt))

        // Algorithm / curve mismatch is an error under every policy.
        let wrongAlgorithm = curve == .p256 ? "ES256K" : "ES256"
        for options in [ATProtoSignatureVerificationOptions.strict, .jwt, .allowMalleable] {
            #expect(throws: PetrelCryptoError.self) {
                _ = try key.verify(signature: signature, signingInput: message, algorithm: wrongAlgorithm, options: options)
            }
        }
    }
}
