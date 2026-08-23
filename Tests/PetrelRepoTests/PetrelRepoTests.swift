import Crypto
import Foundation
import Petrel
import PetrelRepo
import XCTest

final class PetrelRepoTests: XCTestCase {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let revision = "3jzfcijpj2z2a"

    func testCanonicalEmptyMSTVector() throws {
        let key = try fixedSigningKey()
        let genesis = try PublicRepositoryGenesisCodec.create(did: did, revision: revision, signingKey: key)

        XCTAssertEqual(genesis.emptyMST, Data([0xa2, 0x61, 0x65, 0x80, 0x61, 0x6c, 0xf6]))
        XCTAssertEqual(genesis.emptyMSTCID.string, "bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm")
    }

    func testUnsignedCommitIsDeterministicForFixedDIDAndRevision() throws {
        let genesis = try PublicRepositoryGenesisCodec.create(
            did: did,
            revision: revision,
            signingKey: try fixedSigningKey()
        )

        XCTAssertEqual(
            genesis.unsignedCommit.map { String(format: "%02x", $0) }.joined(),
            "a56364696478206469643a706c633a65777669376e787a796f756e367a687872687336346f697a637265766d336a7a6663696a706a327a32616464617461d82a582500017112209dfefe61dd76ea3dcae5023880b08379d57adf20482d6fdbe2759289f647677b6470726576f66776657273696f6e03"
        )
        XCTAssertEqual(CID.fromDAGCBOR(genesis.unsignedCommit).string, "bafyreifjnl4lpz2txcnru75rysfeprtj6ud2jmsck76hjrjiofrxovkq6a")
    }

    func testGenesisVerifiesWithSigningPublicKey() throws {
        let key = try fixedSigningKey()
        let genesis = try PublicRepositoryGenesisCodec.create(did: did, revision: revision, signingKey: key)

        let verified = try PublicRepositoryGenesisCodec.verify(car: genesis.car, publicKey: key.publicKey)
        XCTAssertEqual(verified.did, did)
        XCTAssertEqual(verified.revision, revision)
        XCTAssertEqual(verified.commitCID, genesis.commitCID)
        XCTAssertEqual(verified.unsignedCommit, genesis.unsignedCommit)
    }

    func testPinnedTypeScriptAndSwiftGenesisVectorsCrossVerify() throws {
        let fixture = try PinnedPublicGenesisFixture.load()
        let publicKey = try fixedSigningKey().publicKey

        let typeScriptCAR = try XCTUnwrap(Data(base64Encoded: fixture.typeScript.carBase64))
        let typeScript = try PublicRepositoryGenesisCodec.verify(
            car: typeScriptCAR,
            publicKey: publicKey
        )
        XCTAssertEqual(typeScript.did, fixture.did)
        XCTAssertEqual(typeScript.revision, fixture.revision)
        XCTAssertEqual(typeScript.emptyMSTCID.string, fixture.emptyMSTCID)
        XCTAssertEqual(typeScript.commitCID.string, fixture.typeScript.commitCID)
        XCTAssertEqual(hex(typeScript.unsignedCommit), fixture.unsignedCommitHex)

        let swiftCAR = try XCTUnwrap(Data(base64Encoded: fixture.swift.carBase64))
        let swift = try PublicRepositoryGenesisCodec.verify(
            car: swiftCAR,
            publicKey: publicKey
        )
        XCTAssertEqual(swift.did, fixture.did)
        XCTAssertEqual(swift.revision, fixture.revision)
        XCTAssertEqual(swift.emptyMSTCID.string, fixture.emptyMSTCID)
        XCTAssertEqual(swift.commitCID.string, fixture.swift.commitCID)
        XCTAssertEqual(hex(swift.unsignedCommit), fixture.unsignedCommitHex)
    }

    func testWrongKeyAndCriticalTamperingReject() throws {
        let key = try fixedSigningKey()
        let genesis = try PublicRepositoryGenesisCodec.create(did: did, revision: revision, signingKey: key)

        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(
            car: genesis.car,
            publicKey: P256.Signing.PrivateKey().publicKey
        ))
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(
            car: makeCAR(commit: signedCommit(prev: .missing, signature: try key.signature(for: unsignedCommit(prev: .missing)).rawRepresentation)),
            publicKey: key.publicKey
        ))
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(
            car: makeCAR(commit: signedCommit(prev: .nonNull, signature: try key.signature(for: unsignedCommit(prev: .nonNull)).rawRepresentation)),
            publicKey: key.publicKey
        ))

        var invalidSignature = Data(repeating: 0, count: 64)
        invalidSignature[0] = 1
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(
            car: makeCAR(commit: signedCommit(prev: .null, signature: invalidSignature)),
            publicKey: key.publicKey
        ))

        // Swift Crypto accepts either algebraically equivalent ECDSA scalar,
        // while the pinned TypeScript verifier requires low-S ES256. A high-S
        // signature is therefore a valid local signature that this wire codec
        // must still reject.
        let highS = forceHighS(
            try key.signature(for: unsignedCommit(prev: .null)).rawRepresentation
        )
        XCTAssertTrue(key.publicKey.isValidSignature(
            try P256.Signing.ECDSASignature(rawRepresentation: highS),
            for: try unsignedCommit(prev: .null)
        ))
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(
            car: makeCAR(commit: signedCommit(prev: .null, signature: highS)),
            publicKey: key.publicKey
        ))

        var corrupted = genesis.car
        corrupted[corrupted.index(before: corrupted.endIndex)] ^= 0x01
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(car: corrupted, publicKey: key.publicKey))

        let swapped = makeCARBytes(
            root: genesis.commitCID,
            blocks: [(genesis.emptyMSTCID, genesis.emptyMST), (genesis.commitCID, genesis.signedCommit)]
        )
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(car: swapped, publicKey: key.publicKey))

        let extra = makeCARBytes(
            root: genesis.commitCID,
            blocks: [
                (genesis.commitCID, genesis.signedCommit),
                (genesis.emptyMSTCID, genesis.emptyMST),
                (genesis.emptyMSTCID, genesis.emptyMST),
            ]
        )
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(car: extra, publicKey: key.publicKey))
    }

    func testRevisionValidatorAcceptsCurrentLeadingIAndRejectsLegacyOrUppercase() throws {
        let key = try fixedSigningKey()
        XCTAssertNoThrow(try PublicRepositoryGenesisCodec.create(
            did: did,
            revision: "i234567abcdef",
            signingKey: key
        ))
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.create(
            did: did,
            revision: "1234567890123",
            signingKey: key
        ))
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.create(
            did: did,
            revision: "I234567abcdef",
            signingKey: key
        ))
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.create(
            did: "not-a-did",
            revision: revision,
            signingKey: key
        ))
        XCTAssertNoThrow(try EmptyPublicRepository(did: did, revision: "i234567abcdef"))
        XCTAssertThrowsError(try EmptyPublicRepository(did: did, revision: "0"))
    }

    func testStrictCommitFieldsRejectEvenWhenResigned() throws {
        let key = try fixedSigningKey()
        let emptyCID = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let nonEmptyDataCID = CID.fromDAGCBOR(Data([0xf6]))
        let cases: [(did: String, revision: String, dataCID: CID, version: Int)] = [
            (did: "not-a-did", revision: revision, dataCID: emptyCID, version: 3),
            (did: did, revision: revision, dataCID: emptyCID, version: 2),
            (did: did, revision: "123", dataCID: emptyCID, version: 3),
            (did: did, revision: revision, dataCID: nonEmptyDataCID, version: 3),
        ]

        for input in cases {
            let unsigned = try unsignedCommit(
                did: input.did,
                revision: input.revision,
                dataCID: input.dataCID,
                version: input.version,
                prev: .null
            )
            let signed = try signedCommit(
                did: input.did,
                revision: input.revision,
                dataCID: input.dataCID,
                version: input.version,
                prev: .null,
                signature: try key.signature(for: unsigned).rawRepresentation
            )
            XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(
                car: makeCAR(commit: signed),
                publicKey: key.publicKey
            ))
        }
    }

    func testCARCardinalityAndRootMappingReject() throws {
        let key = try fixedSigningKey()
        let genesis = try PublicRepositoryGenesisCodec.create(did: did, revision: revision, signingKey: key)
        let onlyCommit = makeCARBytes(root: genesis.commitCID, blocks: [(genesis.commitCID, genesis.signedCommit)])
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(car: onlyCommit, publicKey: key.publicKey))

        let remappedRoot = makeCARBytes(root: genesis.emptyMSTCID, blocks: [
            (genesis.commitCID, genesis.signedCommit),
            (genesis.emptyMSTCID, genesis.emptyMST),
        ])
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(car: remappedRoot, publicKey: key.publicKey))
    }

    func testHostileHeaderLengthRejectsBeforeCARReaderCanOverflow() throws {
        // Canonical LEB128 for Int.max. The ninth byte leaves CARReader's
        // internal offset at 9, so its subsequent unchecked `offset + length`
        // would overflow without the genesis framing preflight.
        let hostileHeader = Data(repeating: 0xff, count: 8) + Data([0x7f])
        XCTAssertThrowsError(try PublicRepositoryGenesisCodec.verify(
            car: hostileHeader,
            publicKey: try fixedSigningKey().publicKey
        ))
    }

    private func fixedSigningKey() throws -> P256.Signing.PrivateKey {
        try P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 1, count: 32))
    }

    private enum Previous {
        case null
        case missing
        case nonNull
    }

    private func unsignedCommit(
        did: String? = nil,
        revision: String? = nil,
        dataCID: CID? = nil,
        version: Int = 3,
        prev: Previous
    ) throws -> Data {
        let commitDID = did ?? self.did
        let commitRevision = revision ?? self.revision
        let commitDataCID = dataCID ?? CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        var fields: [(key: String, value: Any)] = [
            (key: "did", value: commitDID),
            (key: "version", value: version),
            (key: "data", value: ATProtoLink(cid: commitDataCID)),
            (key: "rev", value: commitRevision),
        ]
        switch prev {
        case .null: fields.append((key: "prev", value: NSNull()))
        case .missing: break
        case .nonNull: fields.append((key: "prev", value: ATProtoLink(cid: commitDataCID)))
        }
        return try DAGCBOR.encodeValue(OrderedCBORMap(entries: fields))
    }

    private func signedCommit(
        did: String? = nil,
        revision: String? = nil,
        dataCID: CID? = nil,
        version: Int = 3,
        prev: Previous,
        signature: Data
    ) throws -> Data {
        let commitDID = did ?? self.did
        let commitRevision = revision ?? self.revision
        let commitDataCID = dataCID ?? CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        var fields: [(key: String, value: Any)] = [
            (key: "did", value: commitDID),
            (key: "version", value: version),
            (key: "data", value: ATProtoLink(cid: commitDataCID)),
            (key: "rev", value: commitRevision),
        ]
        switch prev {
        case .null: fields.append((key: "prev", value: NSNull()))
        case .missing: break
        case .nonNull: fields.append((key: "prev", value: ATProtoLink(cid: commitDataCID)))
        }
        fields.append((key: "sig", value: signature))
        return try DAGCBOR.encodeValue(OrderedCBORMap(entries: fields))
    }

    private func makeCAR(commit: Data) throws -> Data {
        let commitCID = CID.fromDAGCBOR(commit)
        let empty = PublicRepositoryGenesisCodec.canonicalEmptyMST
        return makeCARBytes(
            root: commitCID,
            blocks: [(commitCID, commit), (CID.fromDAGCBOR(empty), empty)]
        )
    }

    private func makeCARBytes(root: CID, blocks: [(CID, Data)]) -> Data {
        let header = try! DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "roots", value: [ATProtoLink(cid: root)]),
            (key: "version", value: 1),
        ]))
        var car = Data()
        appendVarint(header.count, to: &car)
        car.append(header)
        for (cid, data) in blocks {
            appendVarint(cid.bytes.count + data.count, to: &car)
            car.append(cid.bytes)
            car.append(data)
        }
        return car
    }

    private func appendVarint(_ value: Int, to data: inout Data) {
        var value = UInt64(value)
        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            data.append(byte)
        } while value != 0
    }

    private func forceHighS(_ signature: Data) -> Data {
        precondition(signature.count == 64)
        let r = signature.prefix(32)
        let s = Data(signature.suffix(32))
        let halfOrder = Data([
            0x7f, 0xff, 0xff, 0xff, 0x80, 0x00, 0x00, 0x00,
            0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xde, 0x73, 0x7d, 0x56, 0xd3, 0x8b, 0xcf, 0x42,
            0x79, 0xdc, 0xd6, 0x61, 0x7e, 0x31, 0x92, 0xa8,
        ])
        guard compareBytes(s, halfOrder) != .orderedDescending else {
            return signature
        }
        let order = Data([
            0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
            0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51,
        ])
        var result = [UInt8](repeating: 0, count: 32)
        var borrow = 0
        for index in result.indices.reversed() {
            let minuend = Int(order[index]) - borrow
            let subtrahend = Int(s[index])
            if minuend >= subtrahend {
                result[index] = UInt8(minuend - subtrahend)
                borrow = 0
            } else {
                result[index] = UInt8(minuend + 256 - subtrahend)
                borrow = 1
            }
        }
        precondition(borrow == 0)
        return Data(r) + Data(result)
    }

    private func compareBytes(_ lhs: Data, _ rhs: Data) -> ComparisonResult {
        for (left, right) in zip(lhs, rhs) {
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

private struct PinnedPublicGenesisFixture: Decodable {
    struct CAR: Decodable {
        let commitCID: String
        let carBase64: String
    }

    let did: String
    let revision: String
    let emptyMSTCID: String
    let unsignedCommitHex: String
    let typeScript: CAR
    let swift: CAR

    static func load() throws -> PinnedPublicGenesisFixture {
        let json = """
        {
          "profile": "permissioned-data-0016-2026-07-03",
          "referenceCommit": "3f6c96d5d2d25438bd40fa89d6ecc37865f8e354",
          "did": "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
          "revision": "3jzfcijpj2z2a",
          "signingKeyDID": "did:key:zDnaeXxvmFHMHjqgQTbadpWG7gPHwnga1i7SMwxrV2BSdUjAD",
          "emptyMSTCID": "bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm",
          "unsignedCommitHex": "a56364696478206469643a706c633a65777669376e787a796f756e367a687872687336346f697a637265766d336a7a6663696a706a327a32616464617461d82a582500017112209dfefe61dd76ea3dcae5023880b08379d57adf20482d6fdbe2759289f647677b6470726576f66776657273696f6e03",
          "typeScript": {
            "commitCID": "bafyreibg4rb6b5fdkonirmsovz6h2y6r4tzks7zlgumzn3p452tl5vef7a",
            "carBase64": "OqJlcm9vdHOB2CpYJQABcRIgJuRD4PSjU5qIsk6ufH1j0eTyqX8rNRmW7fzupr7UhfhndmVyc2lvbgHgAQFxEiAm5EPg9KNTmoiyTq58fWPR5PKpfys1GZbt/O6mvtSF+KZjZGlkeCBkaWQ6cGxjOmV3dmk3bnh6eW91bjZ6aHhyaHM2NG9pemNyZXZtM2p6ZmNpanBqMnoyYWNzaWdYQOfp1i8BEMS/MryM/AN7w1CQ2XhtJ9FbfcU66vPPykCwbSG6gGwCZdDCFNQAxNbCUcNl7i9osjqDDo0KLzuKlJZkZGF0YdgqWCUAAXESIJ3+/mHdduo9yuUCOICwg3nVet8gSC1v2+J1kon2R2d7ZHByZXb2Z3ZlcnNpb24DKwFxEiCd/v5h3XbqPcrlAjiAsIN51XrfIEgtb9vidZKJ9kdne6JhZYBhbPY="
          },
          "swift": {
            "commitCID": "bafyreics3ioqqtnjo232z53jrzsg4cbchnxo5nh2uepy5usvojds5dbxzu",
            "carBase64": "OqJlcm9vdHOB2CpYJQABcRIgUtodCE2pdres92mOZG4IIjtu7rT6oR+O0lVyRy6MN81ndmVyc2lvbgHgAQFxEiBS2h0ITal2t6z3aY5kbggiO27utPqhH47SVXJHLow3zaZjZGlkeCBkaWQ6cGxjOmV3dmk3bnh6eW91bjZ6aHhyaHM2NG9pemNyZXZtM2p6ZmNpanBqMnoyYWNzaWdYQB5HYJ+6+EbpENfYyjjia3Huj6F8ARm5GC7HmX4ft+f2Nmv+uxMsJDj/E0thgrdjrS1oIm3BMeD+gRPx5HTyUVBkZGF0YdgqWCUAAXESIJ3+/mHdduo9yuUCOICwg3nVet8gSC1v2+J1kon2R2d7ZHByZXb2Z3ZlcnNpb24DKwFxEiCd/v5h3XbqPcrlAjiAsIN51XrfIEgtb9vidZKJ9kdne6JhZYBhbPY="
          }
        }
        """
        return try JSONDecoder().decode(Self.self, from: Data(json.utf8))
    }
}
