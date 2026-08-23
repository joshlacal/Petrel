import Crypto
import Foundation
import Petrel
import secp256k1
import PetrelCrypto
@testable import PetrelRepo
import XCTest

final class PublicRepositoryCommitTests: XCTestCase {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let revision = "3jzfcijpj2z2a"

    func testPinnedEmptyAndNonEmptyUnsignedVectors() throws {
        let empty = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let emptyBytes = try PublicRepositoryCommitCodec.encodeUnsigned(
            did: did,
            revision: revision,
            dataCID: empty
        )
        XCTAssertEqual(
            emptyBytes.hex,
            "a56364696478206469643a706c633a65777669376e787a796f756e367a687872687336346f697a637265766d336a7a6663696a706a327a32616464617461d82a582500017112209dfefe61dd76ea3dcae5023880b08379d57adf20482d6fdbe2759289f647677b6470726576f66776657273696f6e03"
        )
        XCTAssertEqual(CID.fromDAGCBOR(emptyBytes).string, "bafyreifjnl4lpz2txcnru75rysfeprtj6ud2jmsck76hjrjiofrxovkq6a")

        let nonEmptyRoot = try CID.parse("bafyreigahoij4l65qusqdw73mvk7yrwyty3h7cuo7w2twzke7n56sfpq4u")
        let nonEmptyBytes = try PublicRepositoryCommitCodec.encodeUnsigned(
            did: did,
            revision: revision,
            dataCID: nonEmptyRoot
        )
        XCTAssertEqual(
            nonEmptyBytes.hex,
            "a56364696478206469643a706c633a65777669376e787a796f756e367a687872687336346f697a637265766d336a7a6663696a706a327a32616464617461d82a58250001711220c03b909e2fdd852501dbfb6555fc46d89e367f8a8efdb53b6544fb7be915f0e56470726576f66776657273696f6e03"
        )
        XCTAssertEqual(
            CID.fromDAGCBOR(nonEmptyBytes).string,
            "bafyreierrdujsconfh7jhegu5s6o45pg2yvmf3ncl2k527qmvesp6eygtm"
        )
    }

    func testPrepareSignsExactCanonicalBytesExactlyOnceAndKeepsMetadataOffWire() async throws {
        let signer = RecordingSigner(key: try fixedKey())
        let root = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let prepared = try await PublicRepositoryCommitCodec.prepare(
            did: did,
            revision: revision,
            dataCID: root,
            currentRevision: "3jzfcijpj2z22",
            signer: signer
        )
        let calls = await signer.calls
        XCTAssertEqual(calls, [prepared.unsignedCommitBytes])
        XCTAssertFalse(prepared.unsignedCommitBytes.contains(Data("baseCommitCID".utf8)))
        XCTAssertFalse(prepared.signedCommitBytes.contains(Data("baseCommitCID".utf8)))
        XCTAssertFalse(prepared.signedCommitBytes.contains(Data("sinceRevision".utf8)))
        XCTAssertEqual(prepared.commitCID, CID.fromDAGCBOR(prepared.signedCommitBytes))

        await assertCommitError(.revisionNotIncreasing) {
            _ = try await PublicRepositoryCommitCodec.prepare(
                did: self.did,
                revision: self.revision,
                dataCID: root,
                currentRevision: self.revision,
                signer: signer
            )
        }
        await assertCommitError(.revisionNotIncreasing) {
            _ = try await PublicRepositoryCommitCodec.prepare(
                did: self.did,
                revision: "3jzfcijpj2z22",
                dataCID: root,
                currentRevision: self.revision,
                signer: signer
            )
        }
    }

    func testPreparedP256CommitRoundTripsThroughVerifiedBoundary() async throws {
        let key = try fixedKey()
        let prepared = try await PublicRepositoryCommitCodec.prepare(
            did: did,
            revision: revision,
            dataCID: CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST),
            signer: P256PublicRepositoryCommitSigner(privateKey: key)
        )
        let verified = try await PublicRepositoryCommitCodec.verify(
            signedCommitBytes: prepared.signedCommitBytes,
            expectedCommitCID: prepared.commitCID,
            verifier: P256PublicRepositoryCommitVerifier(publicKey: key.publicKey)
        )
        XCTAssertEqual(verified.descriptor, prepared.descriptor)
        XCTAssertEqual(verified.unsignedCommitBytes, prepared.unsignedCommitBytes)
        XCTAssertEqual(verified.commitCID, prepared.commitCID)
        XCTAssertEqual(verified.signature.count, 64)
    }

    func testCapturedPinnedTypeScriptSignatureVerifies() async throws {
        let root = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let unsigned = try PublicRepositoryCommitCodec.encodeUnsigned(
            did: did,
            revision: revision,
            dataCID: root
        )
        let signature = Data(hex:
            "e7e9d62f0110c4bf32bc8cfc037bc35090d9786d27d15b7dc53aeaf3cfca40b0"
                + "6d21ba806c0265d0c214d400c4d6c251c365ee2f68b23a830e8d0a2f3b8a9496"
        )
        let signed = try signedCommit(did: did, revision: revision, dataCID: root, signature: signature)
        let verified = try await PublicRepositoryCommitCodec.verify(
            signedCommitBytes: signed,
            expectedCommitCID: CID.fromDAGCBOR(signed),
            verifier: P256PublicRepositoryCommitVerifier(publicKey: try fixedKey().publicKey)
        )
        XCTAssertEqual(verified.unsignedCommitBytes, unsigned)
        XCTAssertEqual(verified.signature, signature)
        XCTAssertEqual(verified.commitCID.string, "bafyreibg4rb6b5fdkonirmsovz6h2y6r4tzks7zlgumzn3p452tl5vef7a")
    }

    func testStrictSchemaAndCanonicalCBORMatrixRejects() async throws {
        let key = try fixedKey()
        let root = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let valid = try await PublicRepositoryCommitCodec.prepare(
            did: did,
            revision: revision,
            dataCID: root,
            signer: P256PublicRepositoryCommitSigner(privateKey: key)
        )
        let signature = valid.signature
        var cases: [Data] = [
            try signedCommit(did: did, revision: revision, dataCID: root, signature: signature, prev: .missing),
            try signedCommit(did: did, revision: revision, dataCID: root, signature: signature, prev: .link),
            try signedCommit(did: did, revision: revision, dataCID: root, signature: signature, version: 2),
            try signedCommit(did: "not-a-did", revision: revision, dataCID: root, signature: signature),
            try signedCommit(did: did, revision: "bad", dataCID: root, signature: signature),
            try signedCommit(did: did, revision: revision, dataCID: root, signature: signature, extra: true),
            Data([0xb8, 0x06]) + valid.signedCommitBytes.dropFirst(),
            valid.signedCommitBytes + Data([0x00]),
        ]
        cases.append(contentsOf: [
            try rawSignedEntries([
                ("did", did), ("rev", revision), ("sig", signature),
                ("data", root.bytes), ("prev", NSNull()), ("version", 3),
            ]),
            try rawSignedEntries([
                ("did", did), ("rev", revision), ("sig", "not-bytes"),
                ("data", ATProtoLink(cid: root)), ("prev", NSNull()), ("version", 3),
            ]),
            try rawSignedEntries([
                ("did", did), ("rev", revision), ("sig", signature),
                ("data", ATProtoLink(cid: root)), ("prev", NSNull()), ("version", "3"),
            ]),
            try rawSignedEntries([
                ("did", did), ("rev", revision),
                ("data", ATProtoLink(cid: root)), ("prev", NSNull()), ("version", 3),
            ]),
            try rawSignedEntries([
                ("did", did), ("sig", signature),
                ("data", ATProtoLink(cid: root)), ("prev", NSNull()), ("version", 3),
            ]),
            try rawSignedEntries([
                ("did", did), ("rev", revision), ("sig", signature),
                ("data", ATProtoLink(cid: CID.fromBlob(Data("raw".utf8)))),
                ("prev", NSNull()), ("version", 3),
            ]),
        ])
        for bytes in cases {
            await assertRejected(
                bytes,
                key: key,
                expected: [
                    .invalidSchema, .nonCanonicalCBOR, .invalidDID,
                    .invalidRevision, .invalidDataCID,
                ]
            )
        }
    }

    func testSignatureAndCIDNegativeMatrixRejects() async throws {
        let key = try fixedKey()
        let wrongKey = P256.Signing.PrivateKey()
        let root = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let valid = try await PublicRepositoryCommitCodec.prepare(
            did: did,
            revision: revision,
            dataCID: root,
            signer: P256PublicRepositoryCommitSigner(privateKey: key)
        )
        await assertCommitError(.invalidSignature) {
            _ = try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: valid.signedCommitBytes,
                expectedCommitCID: valid.commitCID,
                verifier: P256PublicRepositoryCommitVerifier(publicKey: wrongKey.publicKey)
            )
        }
        let malformedSignatures = [
            Data(repeating: 1, count: 63),
            try key.signature(for: valid.unsignedCommitBytes).derRepresentation,
            Data(repeating: 0, count: 64),
            Data(repeating: 0xff, count: 64),
            forceHighS(valid.signature),
        ]
        for signature in malformedSignatures {
            let bytes = try signedCommit(did: did, revision: revision, dataCID: root, signature: signature)
            await assertRejected(bytes, key: key, expected: [.invalidSignature])
        }

        await assertCommitError(.invalidCommitCID) {
            _ = try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: valid.signedCommitBytes,
                expectedCommitCID: root,
                verifier: P256PublicRepositoryCommitVerifier(publicKey: key.publicKey)
            )
        }
    }

    func testStructuralValidationDoesNotAssumeP256SignatureSemantics() throws {
        let root = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let opaqueWireSignature = Data(repeating: 0xff, count: 64)
        let bytes = try signedCommit(
            did: did,
            revision: revision,
            dataCID: root,
            signature: opaqueWireSignature
        )
        let structurallyValidated = try PublicRepositoryCommitCodec.structurallyValidate(
            signedCommitBytes: bytes,
            expectedCommitCID: CID.fromDAGCBOR(bytes)
        )

        XCTAssertEqual(structurallyValidated.descriptor.did, did)
        XCTAssertEqual(structurallyValidated.descriptor.revision.value, revision)
        XCTAssertEqual(structurallyValidated.descriptor.dataCID, root)
        XCTAssertEqual(structurallyValidated.signature, opaqueWireSignature)
    }

    func testUnsupportedAlgorithmsFailBeforeSignerOrVerifierSideEffects() async throws {
        let root = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let unsupportedSigner = RecordingUnsupportedSigner()
        await assertCommitError(.unsupportedSigningAlgorithm) {
            _ = try await PublicRepositoryCommitCodec.prepare(
                did: self.did,
                revision: self.revision,
                dataCID: root,
                signer: unsupportedSigner
            )
        }
        let signerCalls = await unsupportedSigner.callCount()
        XCTAssertEqual(signerCalls, 0)

        let key = try fixedKey()
        let prepared = try await PublicRepositoryCommitCodec.prepare(
            did: did,
            revision: revision,
            dataCID: root,
            signer: P256PublicRepositoryCommitSigner(privateKey: key)
        )
        // Verification accepts the pinned TypeScript secp256k1 algorithm;
        // the concrete verifier still owns the public-key check. The writer
        // path above remains P-256-only until Swan has a secp256k1 signer.
        let referenceVerifier = RecordingUnsupportedVerifier()
        _ = try await PublicRepositoryCommitCodec.verify(
            signedCommitBytes: prepared.signedCommitBytes,
            expectedCommitCID: prepared.commitCID,
            verifier: referenceVerifier
        )
        let verifierCalls = await referenceVerifier.callCount()
        XCTAssertEqual(verifierCalls, 1)
    }

    func testSecp256k1CommitVerifierAcceptsCompactLowSSignature() async throws {
        let key = try secp256k1.Signing.PrivateKey(
            dataRepresentation: Data(repeating: 2, count: 32)
        )
        let root = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let unsigned = try PublicRepositoryCommitCodec.encodeUnsigned(
            did: did,
            revision: revision,
            dataCID: root
        )
        let signature = normalizeSecp256k1LowS(
            try key.signature(for: unsigned).compactRepresentation
        )
        let signed = try signedCommit(
            did: did,
            revision: revision,
            dataCID: root,
            signature: signature
        )
        let commitCID = CID.fromDAGCBOR(signed)

        let verified = try await PublicRepositoryCommitCodec.verify(
            signedCommitBytes: signed,
            expectedCommitCID: commitCID,
            verifier: Secp256k1Verifier(publicKeyBytes: key.publicKey.dataRepresentation)
        )

        XCTAssertEqual(verified.signingAlgorithm, .secp256k1)
        XCTAssertEqual(verified.signature, signature)
    }

    private enum Previous { case null, missing, link }

    private func signedCommit(
        did: String,
        revision: String,
        dataCID: CID,
        signature: Data,
        prev: Previous = .null,
        version: Int = 3,
        extra: Bool = false
    ) throws -> Data {
        var entries: [(key: String, value: Any)] = [
            ("did", did),
            ("version", version),
            ("data", ATProtoLink(cid: dataCID)),
            ("rev", revision),
        ]
        switch prev {
        case .null: entries.append(("prev", NSNull()))
        case .missing: break
        case .link: entries.append(("prev", ATProtoLink(cid: dataCID)))
        }
        entries.append(("sig", signature))
        if extra { entries.append(("extra", true)) }
        return try DAGCBOR.encodeValue(OrderedCBORMap(entries: entries))
    }

    private func rawSignedEntries(_ entries: [(key: String, value: Any)]) throws -> Data {
        try DAGCBOR.encodeValue(OrderedCBORMap(entries: entries))
    }

    private func assertRejected(
        _ bytes: Data,
        key: P256.Signing.PrivateKey,
        expected: [PublicRepositoryCommitError],
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: bytes,
                expectedCommitCID: CID.fromDAGCBOR(bytes),
                verifier: P256PublicRepositoryCommitVerifier(publicKey: key.publicKey)
            )
            XCTFail("expected rejection", file: file, line: line)
        } catch let error as PublicRepositoryCommitError {
            XCTAssertTrue(
                expected.contains(error),
                "unexpected commit error \(error), expected one of \(expected)",
                file: file,
                line: line
            )
        } catch {
            XCTFail("unexpected error type \(error)", file: file, line: line)
        }
    }

    private func assertCommitError(
        _ expected: PublicRepositoryCommitError,
        operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? PublicRepositoryCommitError, expected, file: file, line: line)
        }
    }

    private func fixedKey() throws -> P256.Signing.PrivateKey {
        try P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 1, count: 32))
    }

    private func forceHighS(_ signature: Data) -> Data {
        let order = Data(hex: "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551")
        let s = Data(signature.suffix(32))
        var result = [UInt8](repeating: 0, count: 32)
        var borrow = 0
        for index in result.indices.reversed() {
            let value = Int(order[index]) - borrow - Int(s[index])
            if value < 0 {
                result[index] = UInt8(value + 256)
                borrow = 1
            } else {
                result[index] = UInt8(value)
                borrow = 0
            }
        }
        return Data(signature.prefix(32)) + Data(result)
    }

    private func normalizeSecp256k1LowS(_ signature: Data) -> Data {
        precondition(signature.count == 64)
        let halfOrder = Data(hex: "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0")
        let s = Data(signature.suffix(32))
        guard s.lexicographicallyPrecedes(halfOrder) || s == halfOrder else {
            let order = Data(hex: "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141")
            var result = [UInt8](repeating: 0, count: 32)
            var borrow = 0
            for index in result.indices.reversed() {
                let value = Int(order[index]) - borrow - Int(s[index])
                if value < 0 {
                    result[index] = UInt8(value + 256)
                    borrow = 1
                } else {
                    result[index] = UInt8(value)
                    borrow = 0
                }
            }
            return Data(signature.prefix(32)) + Data(result)
        }
        return signature
    }
}

private actor RecordingSigner: PublicRepositoryCommitSigner {
    let signingAlgorithm: PublicRepositorySigningAlgorithm = .p256
    private let key: P256.Signing.PrivateKey
    private(set) var calls: [Data] = []

    init(key: P256.Signing.PrivateKey) {
        self.key = key
    }

    func sign(unsignedCommitBytes: Data) async throws -> Data {
        calls.append(unsignedCommitBytes)
        return try P256WireSignature.sign(unsignedCommitBytes, using: key)
    }
}

private actor RecordingUnsupportedSigner: PublicRepositoryCommitSigner {
    nonisolated let signingAlgorithm: PublicRepositorySigningAlgorithm = .secp256k1
    private var calls = 0

    func sign(unsignedCommitBytes _: Data) async throws -> Data {
        calls += 1
        return Data(repeating: 1, count: 64)
    }

    func callCount() -> Int { calls }
}

private actor RecordingUnsupportedVerifier: PublicRepositoryCommitVerifier {
    nonisolated let signingAlgorithm: PublicRepositorySigningAlgorithm = .secp256k1
    nonisolated let verificationIdentity = "test:unsupported"
    private var calls = 0

    func verify(signature _: Data, unsignedCommitBytes _: Data, did _: String) async throws {
        calls += 1
    }

    func callCount() -> Int { calls }
}

private struct Secp256k1Verifier: PublicRepositoryCommitVerifier {
    let signingAlgorithm: PublicRepositorySigningAlgorithm = .secp256k1
    let verificationIdentity = "test-secp256k1"
    let publicKeyBytes: Data

    func verify(
        signature: Data,
        unsignedCommitBytes: Data,
        did _: String
    ) async throws {
        let publicKey = try secp256k1.Signing.PublicKey(
            dataRepresentation: publicKeyBytes,
            format: .compressed
        )
        let compact = try secp256k1.Signing.ECDSASignature(
            compactRepresentation: signature
        )
        guard publicKey.isValidSignature(compact, for: unsignedCommitBytes) else {
            throw PublicRepositoryCommitError.invalidSignature
        }
    }
}

private extension Data {
    /// Test-only parser for reviewed, hard-coded hexadecimal vectors. A typo is
    /// a test-source invariant failure rather than an untrusted input path.
    init(hex: String) {
        precondition(hex.count.isMultiple(of: 2))
        var result = Data()
        result.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let end = hex.index(index, offsetBy: 2)
            result.append(UInt8(hex[index ..< end], radix: 16)!)
            index = end
        }
        self = result
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }

    func contains(_ other: Data) -> Bool {
        range(of: other) != nil
    }
}
