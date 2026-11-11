import Crypto
import Foundation
import PetrelCore
import PetrelCrypto
@testable import PetrelPLC
import Testing

@Suite("PLC operation signing")
struct PLCOperationSigningTests {
    private func unsignedGenesis(rotationKeys: [String]) throws -> PLCUnsignedRegularOperation {
        try PLCATProfile.genesisOperation(
            handle: "alice.example.com",
            signingKey: K256Keypair.generate().didKey,
            rotationKeys: rotationKeys,
            pdsEndpoint: "https://pds.example.com"
        )
    }

    private func expectWireSignature(_ operation: PLCSignedOperation, curve: ATProtoKeyCurve) throws {
        let text = operation.signature
        // base64url, no padding.
        #expect(text.count == 86)
        #expect(!text.contains("=") && !text.contains("+") && !text.contains("/"))
        let bytes = try JWTBase64URL.decode(text)
        #expect(bytes.count == 64)
        #expect(ATProtoSignature.isCanonical(bytes, curve: curve))
    }

    @Test("K-256 and P-256 keypairs sign genesis operations that verify", arguments: ATProtoKeyCurve.allCases)
    func signsOnBothCurves(curve: ATProtoKeyCurve) async throws {
        let signer: any ATProtoKeypair = switch curve {
        case .k256: K256Keypair.generate()
        case .p256: P256Keypair.generate()
        }
        let other = K256Keypair.generate()
        let unsigned = try unsignedGenesis(rotationKeys: [other.didKey, signer.didKey])
        let signed = try await PLCOperationCodec.sign(.regular(unsigned), with: signer)

        try expectWireSignature(signed, curve: curve)
        // The signature covers the DAG-CBOR without `sig`.
        let signature = try JWTBase64URL.decode(signed.signature)
        #expect(try signer.publicKey.isValidSignature(signature, for: PLCUnsignedOperation.regular(unsigned).signingDAGCBOR))
        #expect(try signed.signingDAGCBOR == PLCUnsignedOperation.regular(unsigned).signingDAGCBOR)

        // The signer is the second rotation key.
        #expect(try PLCOperationCodec.verify(signed, authorizedRotationKeys: unsigned.rotationKeys) == 1)

        // DID = did:plc: + first 24 chars of base32(sha256(DAG-CBOR(signed))).
        let did = try PLCOperationCodec.genesisDID(for: signed)
        let digest = try Data(SHA256.hash(data: signed.canonicalDAGCBOR))
        #expect(did == "did:plc:" + base32Encode(digest).prefix(24))
        #expect(did.count == 32)
        try PLCOperationCodec.verifyGenesis(signed, expectedDID: did)

        // Not signed by a key that is not listed.
        #expect(throws: PetrelPLCError.unauthorized("PLC operation signature is invalid")) {
            try PLCOperationCodec.verify(signed, authorizedRotationKeys: [other.didKey])
        }
    }

    @Test("an update names the CID of its predecessor and a tombstone is signed the same way")
    func signsUpdatesAndTombstones() async throws {
        let rotation = K256Keypair.generate()
        let genesis = try await PLCOperationCodec.sign(
            .regular(unsignedGenesis(rotationKeys: [rotation.didKey])), with: rotation
        )
        let update = try await PLCOperationCodec.sign(
            .regular(PLCOperationCodec.updateHandle(after: genesis, handle: "bob.example.com")),
            with: rotation
        )
        #expect(try update.prev == genesis.cid.string)
        #expect(try genesis.cid.string.hasPrefix("bafyrei"))
        #expect(try genesis.cid.codec == .dagCBOR)
        #expect(try PLCOperationCodec.verify(update, authorizedRotationKeys: [rotation.didKey]) == 0)

        let tombstone = try await PLCOperationCodec.sign(
            .tombstone(PLCOperationCodec.tombstone(after: update)), with: rotation
        )
        #expect(tombstone.isTombstone)
        #expect(try tombstone.prev == update.cid.string)
        #expect(try PLCOperationCodec.verify(tombstone, authorizedRotationKeys: [rotation.didKey]) == 0)
        #expect(try PLCOperationCodec.decodeSignedJSON(tombstone.canonicalJSON) == tombstone)
    }

    @Test("an external signer returning DER with high-S yields a canonical operation")
    func externalSigner() async throws {
        // The raw scalar, not the key, crosses into the closure: Swift
        // Crypto key types are not Sendable on Linux.
        let scalar = P256.Signing.PrivateKey().rawRepresentation
        let publicKey = try ATProtoPublicKey(P256.Signing.PrivateKey(rawRepresentation: scalar).publicKey)
        let signer = ATProtoExternalSigner(publicKey: publicKey) { request in
            // What a KMS typically returns: DER, S not normalized.
            try P256.Signing.PrivateKey(rawRepresentation: scalar)
                .signature(for: request.message).derRepresentation
        }
        let unsigned = try unsignedGenesis(rotationKeys: [signer.didKey])
        let signed = try await PLCOperationCodec.sign(.regular(unsigned), with: signer)
        try expectWireSignature(signed, curve: .p256)
        try PLCOperationCodec.verifyGenesis(signed, expectedDID: PLCOperationCodec.genesisDID(for: signed))
    }

    @Test("a signature made elsewhere over signingDAGCBOR can be attached")
    func attachesDetachedSignature() throws {
        let rotation = K256Keypair.generate()
        let unsigned = try PLCUnsignedOperation.regular(unsignedGenesis(rotationKeys: [rotation.didKey]))
        let signature = try rotation.sign(unsigned.signingDAGCBOR)
        let signed = try PLCOperationCodec.attach(signature: signature, to: unsigned)
        try PLCOperationCodec.verifyGenesis(signed, expectedDID: PLCOperationCodec.genesisDID(for: signed))

        // DER and wrong lengths are refused, not repaired.
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.attach(signature: signature.dropLast(), to: unsigned)
        }
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.attach(signature: Data(repeating: 0, count: 64), to: unsigned)
        }
    }

    private struct HighSSigner: ATProtoSigner {
        let keypair = K256Keypair.generate()
        var curve: ATProtoKeyCurve { .k256 }
        func sign(_ message: Data) async throws -> Data {
            // n - s for secp256k1: a valid but malleable signature.
            let low = try keypair.sign(message)
            let order: [UInt8] = [
                0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
                0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
                0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41,
            ]
            let s = [UInt8](low.suffix(32))
            var high = [UInt8](repeating: 0, count: 32)
            var borrow = 0
            for index in stride(from: 31, through: 0, by: -1) {
                var value = Int(order[index]) - Int(s[index]) - borrow
                borrow = value < 0 ? 1 : 0
                if value < 0 { value += 256 }
                high[index] = UInt8(value)
            }
            return low.prefix(32) + Data(high)
        }
    }

    @Test("a signer that breaks the low-S contract is refused")
    func refusesHighSSigner() async throws {
        let signer = HighSSigner()
        let unsigned = try unsignedGenesis(rotationKeys: [signer.keypair.didKey])
        await #expect(throws: PetrelPLCError.malformed("PLC signer returned a signature that is not 64-byte low-S")) {
            try await PLCOperationCodec.sign(.regular(unsigned), with: signer)
        }
    }

    @Test("signature encoding is strict: padding, non-zero trailing bits and high-S are rejected on read")
    func strictSignatureEncoding() async throws {
        let rotation = K256Keypair.generate()
        let signed = try await PLCOperationCodec.sign(
            .regular(unsignedGenesis(rotationKeys: [rotation.didKey])), with: rotation
        )
        func withSignature(_ signature: String) throws -> Data {
            var object = try #require(
                JSONSerialization.jsonObject(with: signed.canonicalJSON) as? [String: Any]
            )
            object["sig"] = signature
            return try JSONSerialization.data(withJSONObject: object)
        }
        // Sanity: the untouched operation decodes.
        #expect(try PLCOperationCodec.decodeSignedJSON(withSignature(signed.signature)) == signed)

        // Padding.
        #expect(throws: PetrelPLCError.malformed("PLC operation signature encoding is invalid")) {
            try PLCOperationCodec.decodeSignedJSON(withSignature(signed.signature + "=="))
        }

        // The last base64 character of a 64-byte value carries two data bits
        // and four bits that must be zero. Setting one of them yields a
        // string that decodes to the same 64 bytes, so a tolerant decoder
        // would accept a second spelling of the same signature — and with
        // it a second CID for the same operation.
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        let last = try #require(signed.signature.last)
        let index = try #require(alphabet.firstIndex(of: last))
        #expect(index % 16 == 0)
        let spelledDifferently = String(signed.signature.dropLast()) + String(alphabet[index + 1])
        #expect(try JWTBase64URL.decode(signed.signature).count == 64)
        #expect(throws: PetrelPLCError.malformed("PLC operation signature encoding is invalid")) {
            try PLCOperationCodec.decodeSignedJSON(withSignature(spelledDifferently))
        }

        // Standard base64 alphabet.
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.decodeSignedJSON(
                withSignature(signed.signature.replacingOccurrences(of: "_", with: "/")
                    .replacingOccurrences(of: "-", with: "+") + "+")
            )
        }

        // A high-S signature that is canonical on neither curve is malformed.
        let highS = try await HighSSigner().sign(Data("x".utf8))
        if !ATProtoSignature.isCanonical(highS, curve: .p256) {
            #expect(throws: PetrelPLCError.malformed("PLC operation signature is not canonical")) {
                try PLCOperationCodec.decodeSignedJSON(withSignature(JWTBase64URL.encode(highS)))
            }
        }
    }

    /// `n - s`: the other, "high-S" signature that ECDSA accepts for the
    /// same message and key.
    private func highSForm(of signature: Data, curve: ATProtoKeyCurve) -> Data {
        let order: [UInt8] = switch curve {
        case .k256: [
                0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
                0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
                0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41,
            ]
        case .p256: [
                0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
                0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                0xBC, 0xE6, 0xFA, 0xAD, 0xA7, 0x17, 0x9E, 0x84,
                0xF3, 0xB9, 0xCA, 0xC2, 0xFC, 0x63, 0x25, 0x51,
            ]
        }
        let s = [UInt8](signature.suffix(32))
        var high = [UInt8](repeating: 0, count: 32)
        var borrow = 0
        for index in stride(from: 31, through: 0, by: -1) {
            var value = Int(order[index]) - Int(s[index]) - borrow
            borrow = value < 0 ? 1 : 0
            if value < 0 { value += 256 }
            high[index] = UInt8(value)
        }
        return signature.prefix(32) + Data(high)
    }

    @Test(
        "a high-S signature is refused at every layer of a PLC operation, on K-256 and on P-256",
        arguments: ATProtoKeyCurve.allCases
    )
    func highSRefusedAtEveryLayer(curve: ATProtoKeyCurve) async throws {
        let rotation: any ATProtoKeypair = switch curve {
        case .k256: K256Keypair.generate()
        case .p256: P256Keypair.generate()
        }
        let unsigned = try unsignedGenesis(rotationKeys: [rotation.didKey])
        let signed = try await PLCOperationCodec.sign(.regular(unsigned), with: rotation)
        let regular = try #require(signed.regular)
        let signingBytes = try signed.signingDAGCBOR
        let low = try JWTBase64URL.decode(signed.signature)
        let high = highSForm(of: low, curve: curve)

        // The high-S form is a mathematically valid signature of the same
        // bytes by the same key, and is not low-S.
        #expect(ATProtoSignature.isLowS(low, curve: curve))
        #expect(!ATProtoSignature.isLowS(high, curve: curve))
        #expect(rotation.publicKey.isValidSignature(high, for: signingBytes, options: .allowMalleable))
        #expect(!rotation.publicKey.isValidSignature(high, for: signingBytes))

        // An operation value carrying it, built past the decoder.
        let forged = PLCSignedOperation.regularOperation(.init(
            rotationKeys: regular.rotationKeys,
            verificationMethods: regular.verificationMethods,
            alsoKnownAs: regular.alsoKnownAs,
            services: regular.services,
            prev: regular.prev,
            signature: JWTBase64URL.encode(high)
        ))
        // Accepting it would give one signed operation two CIDs, and so a
        // genesis operation two DIDs.
        #expect(try forged.cid != signed.cid)
        #expect(try forged.signingDAGCBOR == signingBytes)

        // 1. Signature verification.
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.verify(forged, authorizedRotationKeys: regular.rotationKeys)
        }
        #expect(try PLCOperationCodec.verify(signed, authorizedRotationKeys: regular.rotationKeys) == 0)
        // 2. Genesis verification.
        let forgedDID = try PLCOperationCodec.genesisDID(for: forged)
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.verifyGenesis(forged, expectedDID: forgedDID)
        }
        // 3. Audit log verification.
        #expect(throws: PetrelPLCError.self) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: forgedDID, [(forged, "2026-03-01T00:00:00.000Z")]), did: forgedDID
            )
        }
        #expect(throws: PetrelPLCError.self) {
            try PLCAuditLogVerifier.validateOperationLog([forged], did: forgedDID)
        }
        // 4. Attaching it as a detached signature, and the write rules.
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.attach(signature: high, to: .regular(unsigned))
        }
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.validateForSubmission(forged)
        }
        // 5. Decoding. A high-S value on one curve is, except with
        //    negligible probability, not low-S on the other either, and the
        //    decoder refuses a signature that is canonical on neither.
        let otherCurve: ATProtoKeyCurve = curve == .k256 ? .p256 : .k256
        if !ATProtoSignature.isCanonical(high, curve: otherCurve) {
            #expect(throws: PetrelPLCError.malformed("PLC operation signature is not canonical")) {
                try PLCOperationCodec.decodeSignedJSON(forged.canonicalJSON)
            }
        }
        // 6. As an update: a second operation with a high-S signature does
        //    not extend a valid log.
        let update = try await PLCOperationCodec.sign(
            .regular(PLCOperationCodec.updateHandle(after: signed, handle: "bob.example.com")), with: rotation
        )
        let updateRegular = try #require(update.regular)
        let forgedUpdate = try PLCSignedOperation.regularOperation(.init(
            rotationKeys: updateRegular.rotationKeys,
            verificationMethods: updateRegular.verificationMethods,
            alsoKnownAs: updateRegular.alsoKnownAs,
            services: updateRegular.services,
            prev: updateRegular.prev,
            signature: JWTBase64URL.encode(highSForm(of: JWTBase64URL.decode(update.signature), curve: curve))
        ))
        let did = try PLCOperationCodec.genesisDID(for: signed)
        #expect(throws: PetrelPLCError.unauthorized("PLC operation signature is invalid")) {
            try PLCAuditLogVerifier.verify(plcAuditEntries(did: did, [
                (signed, "2026-03-01T00:00:00.000Z"), (forgedUpdate, "2026-03-01T00:00:01.000Z"),
            ]), did: did)
        }
        _ = try PLCAuditLogVerifier.verify(plcAuditEntries(did: did, [
            (signed, "2026-03-01T00:00:00.000Z"), (update, "2026-03-01T00:00:01.000Z"),
        ]), did: did)
    }

    @Test("verification is per key: a signature that is high-S for the key's curve does not verify")
    func highSNeverVerifies() async throws {
        // Produce a real K-256 signature, then flip it to high-S and check
        // that it no longer verifies even though the mathematics would.
        let signer = HighSSigner()
        let unsigned = try PLCUnsignedOperation.regular(unsignedGenesis(rotationKeys: [signer.keypair.didKey]))
        let message = try unsigned.signingDAGCBOR
        let highS = try await signer.sign(message)
        #expect(signer.keypair.publicKey.isValidSignature(highS, for: message, options: .allowMalleable))
        #expect(!signer.keypair.publicKey.isValidSignature(highS, for: message))
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.attach(signature: highS, to: unsigned)
        }
    }
}

@Suite("PLC lenient read, strict write")
struct PLCReadWriteRulesTests {
    private let k256 = [
        "did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc",
        "did:key:zQ3shP5TBe1sQfSttXty15FAEHV1DZgcxRZNxvEWnPfLFwLxJ",
        "did:key:zQ3shhCGUqDKjStzuDxPkTxN6ujddP4RkEKJJouJGRRkaLGbg",
        "did:key:zQ3shpKnbdPx3g3CmPf5cRVTPe1HtSwVn5ish3wSnDPQCbLJK",
        "did:key:zQ3shunBKsXixLxKtC5qeSG9E4J5RkGN57im31pcTzbNQnm5w",
    ]
    private let p256 = "did:key:zDnaejgmAHMLkBPMBWnkBxyGxpXx8LgE4WJAYDhwZzyoRAddF"
    private let ed25519 = "did:key:z6MkiTBz1yXLP7QKgQDeq5DgxdBdXKvg8u3Yu1B7S5K6M2HTh"
    private let service = ["atproto_pds": PLCService(type: "AtprotoPersonalDataServer", endpoint: "https://pds.example.com")]

    private func build(
        rotationKeys: [String]? = nil,
        verificationMethods: [String: String]? = nil,
        alsoKnownAs: [String] = ["at://alice.example.com"],
        services: [String: PLCService]? = nil
    ) throws -> PLCUnsignedRegularOperation {
        try PLCUnsignedRegularOperation(
            rotationKeys: rotationKeys ?? [k256[0]],
            verificationMethods: verificationMethods ?? ["atproto": p256],
            alsoKnownAs: alsoKnownAs,
            services: services ?? service,
            prev: nil
        )
    }

    /// A syntactically complete `plc_operation` with a real, canonical
    /// signature taken from the vendored corpus, and arbitrary fields.
    private func readableJSON(_ fields: [String: Any]) throws -> Data {
        let sample = try #require(PLCVectors.exportEntries("export-sequenced.jsonl").first)
        var object: [String: Any] = [
            "type": "plc_operation",
            "rotationKeys": [k256[0]],
            "verificationMethods": ["atproto": p256],
            "alsoKnownAs": ["at://alice.example.com"],
            "services": ["atproto_pds": ["type": "AtprotoPersonalDataServer", "endpoint": "https://pds.example.com"]],
            "prev": NSNull(),
            "sig": sample.operation.signature,
        ]
        object.merge(fields) { _, new in new }
        return try JSONSerialization.data(withJSONObject: object)
    }

    @Test("rotation keys: 1 to 5, distinct, P-256 or K-256 when writing; anything when reading")
    func rotationKeys() throws {
        _ = try build(rotationKeys: Array(k256.prefix(5)))
        _ = try build(rotationKeys: [p256])
        #expect(throws: PetrelPLCError.self) { try build(rotationKeys: []) }
        #expect(throws: PetrelPLCError.self) { try build(rotationKeys: k256 + [p256]) }
        #expect(throws: PetrelPLCError.self) { try build(rotationKeys: [k256[0], k256[0]]) }
        #expect(throws: PetrelPLCError.invalidIdentifier("PLC rotation key must be a P-256 or K-256 did:key")) {
            try build(rotationKeys: [ed25519])
        }

        for keys in [[], k256 + [p256], [k256[0], k256[0]], [ed25519], ["not a key"]] {
            let operation = try PLCOperationCodec.decodeSignedJSON(readableJSON(["rotationKeys": keys]))
            #expect(operation.regular?.rotationKeys == keys)
            _ = try operation.cid
            #expect(throws: PetrelPLCError.self) {
                try PLCOperationCodec.validateForSubmission(operation)
            }
        }
    }

    @Test("verification methods: at most 10 syntactically valid did:keys of any type when writing")
    func verificationMethods() throws {
        _ = try build(verificationMethods: [:])
        _ = try build(verificationMethods: ["atproto": ed25519, "other": k256[0]])
        let ten = Dictionary(uniqueKeysWithValues: (0 ..< 10).map { ("key\($0)", ed25519) })
        _ = try build(verificationMethods: ten)
        var eleven = ten
        eleven["key10"] = ed25519
        #expect(throws: PetrelPLCError.malformed("PLC operation may contain at most 10 verification methods")) {
            try build(verificationMethods: eleven)
        }
        for invalid in ["z6MkiTBz1yXLP7QKgQDeq5DgxdBdXKvg8u3Yu1B7S5K6M2HTh", "did:key:", "did:key:z", "did:key:z0OIl", "did:web:example.com", "did:key:" + String(repeating: "z", count: 260)] {
            #expect(throws: PetrelPLCError.self, "\(invalid)") {
                try build(verificationMethods: ["atproto": invalid])
            }
        }

        // Reading holds none of this against a historical operation.
        let operation = try PLCOperationCodec.decodeSignedJSON(readableJSON(["verificationMethods": eleven]))
        #expect(operation.regular?.verificationMethods.count == 11)
        let odd = try PLCOperationCodec.decodeSignedJSON(readableJSON(["verificationMethods": ["x": "anything"]]))
        #expect(odd.regular?.verificationMethods == ["x": "anything"])
    }

    @Test("size: 7,500 DAG-CBOR bytes by the specification, 4,000 for the reference directory")
    func sizeLimits() async throws {
        #expect(PLCOperationCodec.maximumDAGCBORBytes == 7_500)
        let rotation = K256Keypair.generate()
        // Ten aliases and five services, each within the reference server's
        // per-field limits: about 5 kB in all.
        let medium = try await PLCOperationCodec.sign(.regular(build(
            rotationKeys: [rotation.didKey],
            alsoKnownAs: (0 ..< 10).map { "https://example.com/\($0)/" + String(repeating: "a", count: 220) },
            services: Dictionary(uniqueKeysWithValues: (0 ..< 5).map {
                ("service\($0)", PLCService(
                    type: "Example", endpoint: "https://example.com/" + String(repeating: "e", count: 480)
                ))
            })
        )), with: rotation)
        #expect(try (4_001 ... 7_500).contains(medium.canonicalDAGCBOR.count))
        try PLCOperationCodec.validateForSubmission(medium)
        #expect(throws: PetrelPLCError.malformed("PLC operation exceeds 4000 DAG-CBOR bytes")) {
            try PLCOperationCodec.validateForSubmission(medium, limits: .referenceDirectory)
        }
        // Over the specification's limit: cannot even be built.
        #expect(throws: PetrelPLCError.malformed("PLC operation exceeds 7,500 DAG-CBOR bytes")) {
            try build(alsoKnownAs: (0 ..< 4).map { "https://example.com/\($0)/" + String(repeating: "a", count: 1_900) })
        }
        // A small operation passes both presets.
        let small = try await PLCOperationCodec.sign(.regular(build(rotationKeys: [rotation.didKey])), with: rotation)
        try PLCOperationCodec.validateForSubmission(small, limits: .referenceDirectory)
    }

    @Test("the reference directory preset applies the server's collection limits")
    func referenceDirectoryLimits() async throws {
        let rotation = K256Keypair.generate()
        func signed(_ unsigned: PLCUnsignedRegularOperation) async throws -> PLCSignedOperation {
            try await PLCOperationCodec.sign(.regular(unsigned), with: rotation)
        }
        let elevenAliases = try await signed(build(
            rotationKeys: [rotation.didKey], alsoKnownAs: (0 ..< 11).map { "at://h\($0).example.com" }
        ))
        let duplicateAlias = try await signed(build(
            rotationKeys: [rotation.didKey], alsoKnownAs: ["at://a.example.com", "at://a.example.com"]
        ))
        let longServiceID = try await signed(build(
            rotationKeys: [rotation.didKey],
            services: [String(repeating: "s", count: 33): PLCService(type: "T", endpoint: "https://e.example")]
        ))
        for operation in [elevenAliases, duplicateAlias, longServiceID] {
            try PLCOperationCodec.validateForSubmission(operation, limits: .specification)
            #expect(throws: PetrelPLCError.self) {
                try PLCOperationCodec.validateForSubmission(operation, limits: .referenceDirectory)
            }
        }
    }

    @Test("operation structure is strict on read, as the reference schemas are")
    func strictStructure() throws {
        _ = try PLCOperationCodec.decodeSignedJSON(readableJSON([:]))
        // An unknown field.
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.decodeSignedJSON(readableJSON(["extra": "x"]))
        }
        // `prev` must be present, as null, on a genesis operation.
        var object = try #require(JSONSerialization.jsonObject(with: readableJSON([:])) as? [String: Any])
        object["prev"] = nil
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.decodeSignedJSON(JSONSerialization.data(withJSONObject: object))
        }
        // A service with an extra field.
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.decodeSignedJSON(readableJSON(
                ["services": ["atproto_pds": ["type": "T", "endpoint": "https://e.example", "x": "y"]]]
            ))
        }
        // A legacy create whose prev is not null.
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.decodeSignedJSON(JSONSerialization.data(withJSONObject: [
                "type": "create", "signingKey": k256[0], "recoveryKey": k256[1],
                "handle": "alice.example.com", "service": "https://pds.example.com",
                "prev": "bafyreig2iwkavnqsibui4muzj7bbs5rnpxf332w3fgdzyusjkaqoxp7xfq",
                "sig": PLCVectors.exportEntries("export-legacy.jsonl")[0].operation.signature,
            ]))
        }
        // An unknown operation type.
        #expect(throws: PetrelPLCError.malformed("PLC operation type is unsupported")) {
            try PLCOperationCodec.decodeSignedJSON(readableJSON(["type": "plc_future"]))
        }
    }

    @Test("the atproto profile builds what the reference formatAtprotoOp builds")
    func atprotoProfile() throws {
        let operation = try PLCATProfile.genesisOperation(
            handle: "at://Alice.Example.COM",
            signingKey: p256,
            rotationKeys: [k256[0], k256[1]],
            pdsEndpoint: "pds.example.com"
        )
        #expect(operation.alsoKnownAs == ["at://alice.example.com"])
        #expect(operation.verificationMethods == ["atproto": p256])
        #expect(operation.rotationKeys == [k256[0], k256[1]])
        #expect(operation.services == [
            "atproto_pds": PLCService(type: "AtprotoPersonalDataServer", endpoint: "https://pds.example.com"),
        ])
        #expect(operation.prev == nil)

        #expect(try PLCATProfile.pdsEndpoint("http://localhost:2583/") == "http://localhost:2583")
        #expect(try PLCATProfile.pdsEndpoint("https://pds.example.com:8443") == "https://pds.example.com:8443")
        for invalid in ["ftp://pds.example.com", "https://pds.example.com/xrpc", "https://u:p@pds.example.com", "https://pds.example.com?x=1", ""] {
            #expect(throws: PetrelPLCError.self, "\(invalid)") { try PLCATProfile.pdsEndpoint(invalid) }
        }
        #expect(throws: PetrelPLCError.self) { try PLCATProfile.handleURI("not a handle") }
        #expect(throws: PetrelPLCError.self) { try PLCATProfile.signingDIDKey(ed25519) }
    }

    @Test("updates carry every untouched field over and follow the reference's handle rule")
    func updateDrafts() async throws {
        let rotation = K256Keypair.generate()
        let genesis = try await PLCOperationCodec.sign(.regular(PLCUnsignedRegularOperation(
            rotationKeys: [rotation.didKey],
            verificationMethods: ["atproto": p256, "other": ed25519],
            alsoKnownAs: ["https://alice.example.com", "at://alice.example.com", "at://second.example.com"],
            services: service.merging(["feed": PLCService(type: "BskyFeedGenerator", endpoint: "https://feed.example.com")]) { $1 },
            prev: nil
        )), with: rotation)

        let handle = try PLCOperationCodec.updateHandle(after: genesis, handle: "Bob.Example.com")
        // The first at:// alias is replaced in place; the rest are kept.
        #expect(handle.alsoKnownAs == ["https://alice.example.com", "at://bob.example.com", "at://second.example.com"])
        #expect(handle.verificationMethods == genesis.regular?.verificationMethods)
        #expect(handle.services == genesis.regular?.services)
        #expect(try handle.prev == genesis.cid.string)

        let pds = try PLCOperationCodec.updatePDS(after: genesis, endpoint: "https://new.example.com")
        #expect(pds.services["atproto_pds"]?.endpoint == "https://new.example.com")
        #expect(pds.services["feed"]?.endpoint == "https://feed.example.com")

        let key = try PLCOperationCodec.updateAtprotoKey(after: genesis, signingKey: k256[2])
        #expect(key.verificationMethods == ["atproto": k256[2], "other": ed25519])

        let keys = try PLCOperationCodec.updateRotationKeys(after: genesis, rotationKeys: [k256[3], rotation.didKey])
        #expect(keys.rotationKeys == [k256[3], rotation.didKey])
        #expect(keys.alsoKnownAs == genesis.regular?.alsoKnownAs)

        // With no at:// alias, the handle goes first.
        var draft = PLCOperationDraft(rotationKeys: [], verificationMethods: [:], alsoKnownAs: ["https://x.example"], services: [:])
        try draft.setHandle("carol.example.com")
        #expect(draft.alsoKnownAs == ["at://carol.example.com", "https://x.example"])

        // An update is held to the write rules.
        #expect(throws: PetrelPLCError.self) {
            try PLCOperationCodec.updateRotationKeys(after: genesis, rotationKeys: [])
        }
        // Nothing follows a tombstone.
        let tombstone = try await PLCOperationCodec.sign(.tombstone(PLCOperationCodec.tombstone(after: genesis)), with: rotation)
        #expect(throws: PetrelPLCError.self) { try PLCOperationCodec.updateHandle(after: tombstone, handle: "x.example.com") }
        #expect(throws: PetrelPLCError.self) { try PLCOperationCodec.tombstone(after: tombstone) }
    }

    @Test("an update after a legacy create starts from the normalized state")
    func updateAfterLegacyCreate() throws {
        let did = PLCVectors.Organisation.support
        let entries = try PLCAuditLogVerifier.decode(PLCVectors.auditLogJSON(did: did), did: did)
        let legacy = try #require(entries.first?.operation.legacyCreate)
        let update = try PLCOperationCodec.updatePDS(after: entries[0].operation, endpoint: "https://pds.example.com")
        #expect(update.prev == entries[0].cid)
        #expect(update.rotationKeys == [legacy.recoveryKey, legacy.signingKey])
        #expect(update.verificationMethods == ["atproto": legacy.signingKey])
        #expect(update.alsoKnownAs == ["at://support-team.bsky.social"])
        #expect(update.services["atproto_pds"]?.endpoint == "https://pds.example.com")
    }

    @Test("a DID document is rendered the way the directory renders it")
    func didDocumentRendering() throws {
        // The example in the specification's "Presentation as DID Document".
        let data = PLCDocumentData(
            did: "did:plc:7iza6de2dwap2sbkpav7c6c6",
            rotationKeys: [
                "did:key:zDnaedvvAsDE6H3BDdBejpx9ve2Tz95cymyCAKF66JbyMh1Lt",
                "did:key:zDnaeh9v2RmcMo13Du2d6pjUf5bZwtauYxj3n9dYjw4EZUAR7",
            ],
            verificationMethods: ["atproto": "did:key:zDnaeh9v2RmcMo13Du2d6pjUf5bZwtauYxj3n9dYjw4EZUAR7"],
            alsoKnownAs: ["at://alice.test"],
            services: ["atproto_pds": PLCService(type: "AtprotoPersonalDataServer", endpoint: "https://example.test")]
        )
        let document = PLCDIDDocument(data: data)
        #expect(document.context == [
            "https://www.w3.org/ns/did/v1",
            "https://w3id.org/security/multikey/v1",
            "https://w3id.org/security/suites/ecdsa-2019/v1",
        ])
        #expect(document.id == data.did)
        #expect(document.alsoKnownAs == ["at://alice.test"])
        #expect(document.verificationMethod == [.init(
            id: "did:plc:7iza6de2dwap2sbkpav7c6c6#atproto",
            type: "Multikey",
            controller: "did:plc:7iza6de2dwap2sbkpav7c6c6",
            publicKeyMultibase: "zDnaeh9v2RmcMo13Du2d6pjUf5bZwtauYxj3n9dYjw4EZUAR7"
        )])
        #expect(document.service == [.init(
            id: "#atproto_pds", type: "AtprotoPersonalDataServer", serviceEndpoint: "https://example.test"
        )])
        #expect(document.handle == "alice.test")
        #expect(document.pdsEndpoint == "https://example.test")
        #expect(document.atprotoSigningKey?.curve == .p256)
        #expect(data.handle == "alice.test")
        #expect(data.pdsEndpoint == "https://example.test")

        // A verification method of another key type (allowed since spec
        // v0.2) renders as a Multikey and adds no curve-specific context.
        let ed25519Data = PLCDocumentData(
            did: data.did,
            rotationKeys: data.rotationKeys,
            verificationMethods: ["atproto": k256[0], "other": ed25519],
            alsoKnownAs: [],
            services: [:]
        )
        let ed25519Document = PLCDIDDocument(data: ed25519Data)
        #expect(ed25519Document.context == [
            "https://www.w3.org/ns/did/v1",
            "https://w3id.org/security/multikey/v1",
            "https://w3id.org/security/suites/secp256k1-2019/v1",
        ])
        #expect(ed25519Document.verificationMethod.last?.type == "Multikey")
        #expect(ed25519Document.verificationMethod.last?.publicKeyMultibase == String(ed25519.dropFirst(8)))

        // JSON round trip, with the JSON-LD key.
        let encoded = try JSONEncoder().encode(document)
        #expect(String(decoding: encoded, as: UTF8.self).contains("\"@context\""))
        #expect(try JSONDecoder().decode(PLCDIDDocument.self, from: encoded) == document)
    }
}
