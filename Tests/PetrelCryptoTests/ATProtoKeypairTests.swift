import Crypto
import Foundation
import PetrelCrypto
import P256K
import Testing

@Suite("Keypairs, signers and one-call verification")
struct ATProtoKeypairTests {
    static let message = Data("AT Protocol signs SHA-256 of these bytes".utf8)

    // MARK: - Generate / sign / verify through the protocol

    @Test("Generate, sign and verify on both curves through the Signer protocol", arguments: ATProtoKeyCurve.allCases)
    func generateSignVerify(_ curve: ATProtoKeyCurve) async throws {
        let keypair: any ATProtoExportableKeypair = ATProtoCrypto.generateKeypair(curve: curve)
        let signer: any ATProtoSigner = keypair

        #expect(signer.curve == curve)
        #expect(signer.jwtAlgorithm == (curve == .p256 ? "ES256" : "ES256K"))
        #expect(keypair.publicKey.curve == curve)
        #expect(keypair.didKey.hasPrefix(curve == .p256 ? "did:key:zDn" : "did:key:zQ3"))
        #expect(keypair.didKey == "did:key:" + keypair.multikey)

        let signature = try await signer.sign(Self.message)
        #expect(signature.count == 64)
        #expect(ATProtoSignature.isCanonical(signature, curve: curve))

        let verifier: any ATProtoVerifier = keypair.publicKey
        #expect(verifier.isValidSignature(signature, for: Self.message, options: .strict))
        #expect(!verifier.isValidSignature(signature, for: Self.message + Data([0]), options: .strict))

        let verified = try ATProtoCrypto.verifySignature(
            didKey: keypair.didKey, data: Self.message, signature: signature
        )
        #expect(verified)

        // A key on the other curve, and a fresh key on the same curve, both reject it.
        for other in ATProtoKeyCurve.allCases {
            let stranger = ATProtoCrypto.generateKeypair(curve: other)
            #expect(!stranger.publicKey.isValidSignature(signature, for: Self.message, options: .allowMalleable))
        }
    }

    @Test("The default curve for new keys is K-256, like the reference implementation")
    func defaultCurveIsK256() {
        #expect(ATProtoCrypto.generateKeypair().curve == .k256)
    }

    @Test("Generated keys are distinct")
    func generatedKeysAreDistinct() {
        let p256 = Set((0 ..< 16).map { _ in P256Keypair.generate().didKey })
        let k256 = Set((0 ..< 16).map { _ in K256Keypair.generate().didKey })
        #expect(p256.count == 16)
        #expect(k256.count == 16)
    }

    // MARK: - The signature is what the underlying libraries produce and accept

    @Test("P-256 signs SHA-256(message): CryptoKit / Swift Crypto verifies it")
    func p256InteroperatesWithSwiftCrypto() throws {
        let keypair = P256Keypair.generate()
        let signature = try keypair.sign(Self.message)

        let libraryKey = try keypair.privateKey()
        #expect(libraryKey.rawRepresentation == keypair.exportRawRepresentation())
        let librarySignature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
        #expect(libraryKey.publicKey.isValidSignature(librarySignature, for: Self.message))
        // Equivalent: verifying the digest directly.
        #expect(libraryKey.publicKey.isValidSignature(librarySignature, for: SHA256.hash(data: Self.message)))

        // And the other way: a library signature verifies through Petrel
        // once canonicalized.
        let fromLibrary = try libraryKey.signature(for: Self.message).rawRepresentation
        let canonical = try ATProtoSignature.canonicalize(fromLibrary, curve: .p256)
        #expect(keypair.publicKey.isValidSignature(canonical, for: Self.message))

        // Wrapping an existing library key keeps its identity.
        #expect(P256Keypair(libraryKey).didKey == keypair.didKey)
    }

    @Test("K-256 signs SHA-256(message): libsecp256k1 verifies it")
    func k256InteroperatesWithLibsecp256k1() throws {
        let keypair = K256Keypair.generate()
        let signature = try keypair.sign(Self.message)

        let libraryKey = try P256K.Signing.PrivateKey(dataRepresentation: keypair.exportRawRepresentation())
        #expect(libraryKey.publicKey.dataRepresentation == keypair.publicKey.compressedRepresentation)
        let librarySignature = try P256K.Signing.ECDSASignature(compactRepresentation: signature)
        #expect(libraryKey.publicKey.isValidSignature(librarySignature, for: Self.message))

        let fromLibrary = libraryKey.signature(for: Self.message).compactRepresentation
        #expect(keypair.publicKey.isValidSignature(fromLibrary, for: Self.message))
        // RFC 6979: same key, same message, same signature.
        #expect(fromLibrary == signature)
        #expect(try keypair.sign(Self.message) == signature)
    }

    // MARK: - Import / export

    @Test("Private key round-trips through raw bytes, hex and multibase", arguments: ATProtoKeyCurve.allCases)
    func importExportRoundTrip(_ curve: ATProtoKeyCurve) async throws {
        let original = ATProtoCrypto.generateKeypair(curve: curve)
        let raw = try original.exportRawRepresentation()
        let hex = try original.exportHex()
        let multibase = try original.exportMultibase()

        #expect(raw.count == 32)
        #expect(hex.count == 64)
        #expect(hex == hex.lowercased())
        #expect(multibase.hasPrefix("z"))

        let fromRaw = try ATProtoCrypto.importKeypair(curve: curve, rawRepresentation: raw)
        let fromHex = try ATProtoCrypto.importKeypair(curve: curve, hex: hex)
        let fromUppercaseHex = try ATProtoCrypto.importKeypair(curve: curve, hex: hex.uppercased())
        let fromMultibase = try ATProtoCrypto.importKeypair(privateMultibase: multibase)
        let bareMultibase = "z" + Base58BTC.encode(raw)

        let typed: any ATProtoExportableKeypair
        let typedFromBare: any ATProtoExportableKeypair
        switch curve {
        case .p256:
            typed = try P256Keypair(multibase: multibase)
            typedFromBare = try P256Keypair(multibase: bareMultibase)
        case .k256:
            typed = try K256Keypair(multibase: multibase)
            typedFromBare = try K256Keypair(multibase: bareMultibase)
        }

        for restored in [fromRaw, fromHex, fromUppercaseHex, fromMultibase, typed, typedFromBare] {
            #expect(restored.curve == curve)
            #expect(restored.didKey == original.didKey)
            #expect(try restored.exportRawRepresentation() == raw)
            let signature = try await restored.sign(Self.message)
            #expect(original.publicKey.isValidSignature(signature, for: Self.message))
        }

        // The private multikey carries its curve in a multicodec prefix:
        // p256-priv 0x1306 -> 86 26, secp256k1-priv 0x1301 -> 81 26.
        let decoded = try Base58BTC.decode(String(multibase.dropFirst()))
        #expect(decoded.count == 34)
        #expect(decoded.prefix(2) == (curve == .p256 ? Data([0x86, 0x26]) : Data([0x81, 0x26])))
        #expect(decoded.dropFirst(2) == raw)
    }

    @Test("A private multikey for one curve is refused by the other curve's keypair")
    func privateMultikeyCurveMismatch() throws {
        let p256 = try P256Keypair.generate().exportMultibase()
        let k256 = try K256Keypair.generate().exportMultibase()

        #expect(throws: PetrelCryptoError.self) { _ = try K256Keypair(multibase: p256) }
        #expect(throws: PetrelCryptoError.self) { _ = try P256Keypair(multibase: k256) }

        // A bare scalar does not name a curve, so the curve-agnostic import refuses it.
        let bare = "z" + Base58BTC.encode(P256Keypair.generate().exportRawRepresentation())
        #expect(throws: PetrelCryptoError.self) { _ = try ATProtoCrypto.importKeypair(privateMultibase: bare) }

        // Unknown multicodec (ed25519-priv, 0x1300 -> 80 26).
        let ed25519 = "z" + Base58BTC.encode(Data([0x80, 0x26]) + Data(repeating: 7, count: 32))
        #expect(throws: PetrelCryptoError.self) { _ = try ATProtoCrypto.importKeypair(privateMultibase: ed25519) }
    }

    @Test("Invalid private scalars are rejected", arguments: LowSBoundaryTests.curves)
    func invalidScalarsAreRejected(_ parameters: LowSBoundaryTests.Curve) throws {
        let curve = parameters.curve
        let order = try TestUInt256(hex: parameters.orderHex)
        let invalid: [Data] = [
            Data(),
            Data(repeating: 0, count: 32), // zero
            order.data, // n
            Data(repeating: 0xff, count: 32), // > n
            Data(repeating: 1, count: 31), // short
            Data(repeating: 1, count: 33), // long
        ]
        for scalar in invalid {
            #expect(throws: PetrelCryptoError.self) {
                _ = try ATProtoCrypto.importKeypair(curve: curve, rawRepresentation: scalar)
            }
        }
        for hex in ["", "zz", String(repeating: "0", count: 64), String(repeating: "1", count: 63), String(repeating: "g", count: 64)] {
            #expect(throws: PetrelCryptoError.self) {
                _ = try ATProtoCrypto.importKeypair(curve: curve, hex: hex)
            }
        }
        for multibase in ["", "z", "abc", "z0OIl", "m" + String(repeating: "1", count: 32)] {
            #expect(throws: PetrelCryptoError.self) {
                _ = try ATProtoCrypto.importKeypair(privateMultibase: multibase)
            }
        }

        // The largest valid scalar is n - 1.
        let largest = try ATProtoCrypto.importKeypair(curve: curve, rawRepresentation: order.subtracting(.one).data)
        #expect(try largest.exportRawRepresentation() == order.subtracting(.one).data)
        // The smallest is 1, whose public key is the curve generator.
        let smallest = try ATProtoCrypto.importKeypair(curve: curve, rawRepresentation: TestUInt256.one.data)
        let generatorX = curve == .p256
            ? "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296"
            : "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        #expect(Hex.encode(smallest.publicKey.compressedRepresentation.dropFirst()) == generatorX)
    }

    @Test("Describing a keypair never prints the private scalar")
    func descriptionDoesNotLeak() throws {
        let p256 = P256Keypair.generate()
        let k256 = K256Keypair.generate()
        let p256Secret = p256.exportRawRepresentation()
        let k256Secret = k256.exportRawRepresentation()
        let renderings: [(text: String, secret: Data)] = [
            (String(describing: p256), p256Secret),
            (String(reflecting: p256), p256Secret),
            ("\(p256)", p256Secret),
            (String(describing: k256), k256Secret),
            (String(reflecting: k256), k256Secret),
            ("\(k256)", k256Secret),
        ]
        for (text, secret) in renderings {
            #expect(!text.lowercased().contains(Hex.encode(secret)))
            #expect(!text.contains(Base58BTC.encode(secret)))
            #expect(!text.contains(secret.base64EncodedString()))
            #expect(text.contains("did:key:z"))
        }
    }

    @Test("Strict JWT verification refuses high-S with the same error on both curves", arguments: ATProtoKeyCurve.allCases)
    func strictHighSErrorIsUniform(_ curve: ATProtoKeyCurve) async throws {
        let keypair: any ATProtoExportableKeypair = ATProtoCrypto.generateKeypair(curve: curve)
        let signature = try await keypair.sign(Self.message)
        let highS = try highSTwin(of: signature, curve: curve)
        let key = try ATProtoJWTVerificationKey(keypair.publicKey)

        #expect(try key.verify(signature: signature, signingInput: Self.message, algorithm: keypair.jwtAlgorithm))
        #expect(throws: PetrelCryptoError.unauthorized("JWT signature is not a canonical low-S compact signature")) {
            try key.verify(signature: highS, signingInput: Self.message, algorithm: keypair.jwtAlgorithm)
        }
        // The lax JWT policy still accepts it, as RFC 7518 requires.
        #expect(try key.verify(signature: highS, signingInput: Self.message, algorithm: keypair.jwtAlgorithm, options: .jwt))
    }

    @Test("Reflection (dump, Mirror) never reaches the private scalar")
    func reflectionDoesNotLeak() throws {
        let keypairs: [Any] = [P256Keypair.generate(), K256Keypair.generate()]
        for keypair in keypairs {
            var dumped = ""
            dump(keypair, to: &dumped)
            #expect(!dumped.contains("rawRepresentation"), "\(dumped)")
            #expect(dumped.contains("did:key:z"), "\(dumped)")
            // `dump` prints every byte of a `Data` child on its own line.
            let byteLines = dumped.split(separator: "\n").filter { $0.contains("- ") && UInt8($0.split(separator: " ").last ?? "") != nil }
            #expect(byteLines.count < 32, "\(dumped)")

            let mirror = Mirror(reflecting: keypair)
            #expect(!mirror.children.contains { $0.value is Data })
            #expect(!mirror.children.contains { $0.label == "rawRepresentation" })
        }
    }

    // MARK: - verifySignature(didKey:data:signature:)

    @Test("verifySignature throws for an unusable key and returns false for a bad signature")
    func verifySignatureErrorsVersusFalse() throws {
        let keypair = K256Keypair.generate()
        let signature = try keypair.sign(Self.message)

        // Bad signature bytes: false, not an error.
        for bad in [Data(), Data(repeating: 0, count: 64), Data(repeating: 0xff, count: 64), Data(signature.dropLast()), signature + signature] {
            let verified = try ATProtoCrypto.verifySignature(didKey: keypair.didKey, data: Self.message, signature: bad)
            #expect(!verified)
        }

        // Unusable key: an error.
        for badKey in ["", "did:key:", "did:key:z", "did:web:example.com", keypair.multikey, "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"] {
            #expect(throws: PetrelCryptoError.self) {
                _ = try ATProtoCrypto.verifySignature(didKey: badKey, data: Self.message, signature: signature)
            }
        }

        // Curve mismatch against an expected JWT algorithm: an error.
        #expect(throws: PetrelCryptoError.self) {
            _ = try ATProtoCrypto.verifySignature(
                didKey: keypair.didKey, data: Self.message, signature: signature, expectedJWTAlgorithm: "ES256"
            )
        }
        let matched = try ATProtoCrypto.verifySignature(
            didKey: keypair.didKey, data: Self.message, signature: signature, expectedJWTAlgorithm: "ES256K"
        )
        #expect(matched)
    }

    @Test("Strict is the default; lax modes are opt-in", arguments: ATProtoKeyCurve.allCases)
    func strictByDefault(_ curve: ATProtoKeyCurve) async throws {
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)
        let signature = try await keypair.sign(Self.message)
        let highS = try highSTwin(of: signature, curve: curve)
        let der = try derEncoding(of: signature, curve: curve)
        let highSDER = try derEncoding(of: highS, curve: curve)

        func verify(_ candidate: Data, _ options: ATProtoSignatureVerificationOptions? = nil) throws -> Bool {
            if let options {
                return try ATProtoCrypto.verifySignature(
                    didKey: keypair.didKey, data: Self.message, signature: candidate, options: options
                )
            }
            return try ATProtoCrypto.verifySignature(didKey: keypair.didKey, data: Self.message, signature: candidate)
        }

        // Default == strict: compact low-S only.
        #expect(try verify(signature))
        #expect(try !verify(highS))
        #expect(try !verify(der))
        #expect(try !verify(highSDER))
        #expect(try verify(signature, .strict))
        #expect(try !verify(highS, .strict))

        // .jwt: compact, either S. DER is still refused.
        #expect(try verify(signature, .jwt))
        #expect(try verify(highS, .jwt))
        #expect(try !verify(der, .jwt))
        #expect(try !verify(highSDER, .jwt))

        // .allowMalleable: either S, either encoding.
        #expect(try verify(signature, .allowMalleable))
        #expect(try verify(highS, .allowMalleable))
        #expect(try verify(der, .allowMalleable))
        #expect(try verify(highSDER, .allowMalleable))

        // DER allowed but high-S not: a custom policy.
        let derLowSOnly = ATProtoSignatureVerificationOptions(allowHighS: false, allowDER: true)
        #expect(try verify(der, derLowSOnly))
        #expect(try !verify(highSDER, derLowSOnly))
        #expect(try !verify(highS, derLowSOnly))

        // No policy accepts a signature over different bytes.
        for options in [ATProtoSignatureVerificationOptions.strict, .jwt, .allowMalleable] {
            for candidate in [signature, highS, der, highSDER] {
                let verified = try ATProtoCrypto.verifySignature(
                    didKey: keypair.didKey, data: Data("other".utf8), signature: candidate, options: options
                )
                #expect(!verified)
            }
        }
    }

    // MARK: - External signers

    @Test("An external signer returning DER or high-S is normalized and checked", arguments: ATProtoKeyCurve.allCases)
    func externalSignerNormalizes(_ curve: ATProtoKeyCurve) async throws {
        let backing = ATProtoCrypto.generateKeypair(curve: curve)
        let expected = try await backing.sign(Self.message)

        // Simulates an HSM: signs, then answers in an arbitrary encoding.
        for encode in [ExternalEncoding.compactLowS, .compactHighS, .derLowS, .derHighS] {
            let signer = ATProtoExternalSigner(publicKey: backing.publicKey) { request in
                #expect(request.curve == curve)
                #expect(request.sha256Digest == Data(SHA256.hash(data: request.message)))
                let canonical = try await backing.sign(request.message)
                return try encode.apply(to: canonical, curve: curve)
            }
            #expect(signer.curve == curve)
            #expect(signer.didKey == backing.didKey)

            let signature = try await signer.sign(Self.message)
            #expect(ATProtoSignature.isCanonical(signature, curve: curve))
            #expect(backing.publicKey.isValidSignature(signature, for: Self.message))
            if curve == .k256 {
                // Deterministic on K-256, so the normalized result is exactly the in-process one.
                #expect(signature == expected)
            }
        }
    }

    @Test("An external signer that answers with the wrong key or garbage fails closed", arguments: ATProtoKeyCurve.allCases)
    func externalSignerFailsClosed(_ curve: ATProtoKeyCurve) async throws {
        let declared = ATProtoCrypto.generateKeypair(curve: curve)
        let actual = ATProtoCrypto.generateKeypair(curve: curve)

        let wrongKey = ATProtoExternalSigner(publicKey: declared.publicKey) { request in
            try await actual.sign(request.message)
        }
        await #expect(throws: PetrelCryptoError.self) { _ = try await wrongKey.sign(Self.message) }

        // Double hashing: the backend hashed a digest it was meant to sign as-is.
        let doubleHash = ATProtoExternalSigner(publicKey: declared.publicKey) { request in
            try await declared.sign(request.sha256Digest)
        }
        await #expect(throws: PetrelCryptoError.self) { _ = try await doubleHash.sign(Self.message) }

        let garbage = ATProtoExternalSigner(publicKey: declared.publicKey) { _ in Data(repeating: 0xab, count: 70) }
        await #expect(throws: PetrelCryptoError.self) { _ = try await garbage.sign(Self.message) }

        struct BackendDown: Error {}
        let failing = ATProtoExternalSigner(publicKey: declared.publicKey) { _ in throw BackendDown() }
        await #expect(throws: BackendDown.self) { _ = try await failing.sign(Self.message) }
    }

    // MARK: - Hash and random helpers

    @Test("sha256 and randomBytes")
    func hashAndRandomHelpers() {
        // FIPS 180-2 test vector.
        #expect(
            ATProtoCrypto.sha256Hex(Data("abc".utf8))
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        #expect(ATProtoCrypto.sha256(Data("abc".utf8)) == Data(SHA256.hash(data: Data("abc".utf8))))
        #expect(ATProtoCrypto.sha256(Data()).count == 32)

        #expect(ATProtoCrypto.randomBytes(count: 0).isEmpty)
        #expect(ATProtoCrypto.randomBytes(count: 32).count == 32)
        #expect(ATProtoCrypto.randomBytes(count: 32) != ATProtoCrypto.randomBytes(count: 32))
    }

    // MARK: - Secure Enclave

    #if canImport(CryptoKit) && canImport(Security) && (os(iOS) || os(macOS) || os(visionOS))
        /// Whether this process can actually create an enclave key. False in
        /// the simulator, on virtualized CI Macs, and for a process that
        /// lacks the entitlement; the test is then reported as skipped.
        static let canCreateSecureEnclaveKey: Bool =
            SecureEnclaveP256Signer.isAvailable && (try? SecureEnclaveP256Signer.generate()) != nil

        @Test(
            "A Secure Enclave key signs canonical signatures and restores from its blob",
            .enabled(if: canCreateSecureEnclaveKey, "no usable Secure Enclave in this environment")
        )
        func secureEnclaveSigner() async throws {
            let signer = try SecureEnclaveP256Signer.generate()
            #expect(signer.curve == .p256)
            #expect(signer.jwtAlgorithm == "ES256")
            #expect(signer.didKey.hasPrefix("did:key:zDn"))

            let generic: any ATProtoSigner = signer
            for index in 0 ..< 8 {
                let message = Data("secure enclave \(index)".utf8)
                let signature = try await generic.sign(message)
                #expect(ATProtoSignature.isCanonical(signature, curve: .p256))
                let verified = try ATProtoCrypto.verifySignature(
                    didKey: signer.didKey, data: message, signature: signature
                )
                #expect(verified)
            }

            let restored = try SecureEnclaveP256Signer(dataRepresentation: signer.dataRepresentation)
            #expect(restored.publicKey == signer.publicKey)
            let signature = try restored.sign(Self.message)
            #expect(signer.publicKey.isValidSignature(signature, for: Self.message))
        }
    #endif
}

// MARK: - Helpers

/// `(r, n - s)` computed with the test's own arithmetic.
func highSTwin(of signature: Data, curve: ATProtoKeyCurve) throws -> Data {
    let parameters = LowSBoundaryTests.curves.first { $0.curve == curve }!
    let order = try TestUInt256(hex: parameters.orderHex)
    let s = try TestUInt256(data: Data(signature.suffix(32)))
    return Data(signature.prefix(32)) + order.subtracting(s).data
}

/// ASN.1 DER `SEQUENCE { INTEGER r, INTEGER s }`, encoded by hand so the
/// test does not depend on either library's encoder.
func derEncoding(of signature: Data, curve _: ATProtoKeyCurve) throws -> Data {
    func integer(_ bytes: Data) -> Data {
        var magnitude = Array(bytes.drop(while: { $0 == 0 }))
        if magnitude.isEmpty { magnitude = [0] }
        if magnitude[0] & 0x80 != 0 { magnitude.insert(0, at: 0) }
        return Data([0x02, UInt8(magnitude.count)] + magnitude)
    }
    let body = integer(signature.prefix(32)) + integer(signature.suffix(32))
    precondition(body.count < 128)
    return Data([0x30, UInt8(body.count)]) + body
}

enum ExternalEncoding: Sendable {
    case compactLowS, compactHighS, derLowS, derHighS

    func apply(to canonical: Data, curve: ATProtoKeyCurve) throws -> Data {
        switch self {
        case .compactLowS: return canonical
        case .compactHighS: return try highSTwin(of: canonical, curve: curve)
        case .derLowS: return try derEncoding(of: canonical, curve: curve)
        case .derHighS: return try derEncoding(of: highSTwin(of: canonical, curve: curve), curve: curve)
        }
    }
}
