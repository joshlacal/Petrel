import Crypto
import Foundation
import Petrel
import PetrelCrypto

/// The alpha deliberately exposes a small public-repository substrate: valid
/// identity state, public repository status, and export. Public record writes,
/// relays, and firehose behavior are intentionally not implied by this type.
public struct EmptyPublicRepository: Sendable, Equatable {
    public let did: String
    public let revision: String

    public init(did: String, revision: String) throws {
        try PublicRepositoryGenesisCodec.validateDID(did)
        try PublicRepositoryGenesisCodec.validateRevision(revision)
        self.did = did
        self.revision = revision
    }
}

/// A bounded, empty repository-v3 genesis CAR. It is deliberately not a
/// general MST or repository writer: it always contains exactly the signed
/// commit and the canonical empty MST block.
public struct PublicRepositoryGenesis: Sendable, Equatable {
    public let did: String
    public let revision: String
    public let emptyMST: Data
    public let emptyMSTCID: CID
    public let unsignedCommit: Data
    public let signedCommit: Data
    public let commitCID: CID
    public let car: Data

    fileprivate init(
        did: String,
        revision: String,
        emptyMST: Data,
        emptyMSTCID: CID,
        unsignedCommit: Data,
        signedCommit: Data,
        commitCID: CID,
        car: Data
    ) {
        self.did = did
        self.revision = revision
        self.emptyMST = emptyMST
        self.emptyMSTCID = emptyMSTCID
        self.unsignedCommit = unsignedCommit
        self.signedCommit = signedCommit
        self.commitCID = commitCID
        self.car = car
    }
}

/// Errors are intentionally non-descriptive at the block level: callers do
/// not need private repository bytes in order to report a malformed genesis.
public enum PublicRepositoryGenesisError: Error, Sendable, Equatable {
    case invalidDID
    case invalidRevision
    case malformedCAR
    case invalidCommit
    case invalidSignature
}

/// Canonical v3 empty-repository creation and verification. This codec keeps
/// its input bound small because the alpha has no general public-MST walker;
/// full repository CAR streaming belongs to a later implementation slice.
public enum PublicRepositoryGenesisCodec {
    /// A genesis CAR has two tiny DAG-CBOR blocks. This limit makes accidental
    /// use as a general CAR importer fail closed and bounds all local copies.
    public static let maximumCARBytes = 1_024 * 1_024

    /// The repository specification's canonical empty MST block.
    public static let canonicalEmptyMST = Data([0xa2, 0x61, 0x65, 0x80, 0x61, 0x6c, 0xf6])
    public static let canonicalEmptyMSTCID = "bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm"

    /// Builds a v3 commit over the canonical empty MST. The supplied DID is
    /// only syntax-checked; this API does not create PLC operations, resolve
    /// DID documents, or make any claim about a handle.
    public static func create(
        did: String,
        revision: String,
        signingKey: P256.Signing.PrivateKey
    ) throws -> PublicRepositoryGenesis {
        try validateDID(did)
        try validateRevision(revision)

        let (emptyMST, emptyMSTCID) = try emptyMSTBlock()
        let unsignedCommit = try encodeUnsignedCommit(did: did, revision: revision, dataCID: emptyMSTCID)
        let signature = try P256WireSignature.sign(unsignedCommit, using: signingKey)
        let signedCommit = try encodeSignedCommit(
            did: did,
            revision: revision,
            dataCID: emptyMSTCID,
            signature: signature
        )
        let commitCID = CID.fromDAGCBOR(signedCommit)
        let car = try encodeCAR(commitCID: commitCID, commit: signedCommit, emptyMSTCID: emptyMSTCID, emptyMST: emptyMST)

        return PublicRepositoryGenesis(
            did: did,
            revision: revision,
            emptyMST: emptyMST,
            emptyMSTCID: emptyMSTCID,
            unsignedCommit: unsignedCommit,
            signedCommit: signedCommit,
            commitCID: commitCID,
            car: car
        )
    }

    /// Strictly validates the only CAR shape this initial foundation imports:
    /// one commit root followed by the canonical empty MST. It rejects extra
    /// blocks and non-canonical framing before exposing decoded values.
    public static func verify(
        car: Data,
        publicKey: P256.Signing.PublicKey
    ) throws -> PublicRepositoryGenesis {
        guard !car.isEmpty, car.count <= maximumCARBytes else {
            throw PublicRepositoryGenesisError.malformedCAR
        }

        // CARReader is deliberately a general-purpose reader and parses its
        // length prefixes before it can apply this genesis codec's narrow
        // limits. Validate every frame length with checked subtraction before
        // handing untrusted bytes to it, so a hostile Int.max varint cannot
        // reach its unchecked offset addition.
        try preflightCARFraming(car)

        // Keep the Petrel CAR parser on the validation path after the bounded
        // framing preflight. The genesis parser below adds the exact
        // cardinality and ordering constraints CARReader does not impose for
        // general CARs.
        let reader: CARReader
        do {
            reader = try CARReader(data: car)
        } catch {
            throw PublicRepositoryGenesisError.malformedCAR
        }

        let parsed = try parseGenesisCAR(car, reader: reader)
        let (emptyMST, emptyMSTCID) = try emptyMSTBlock()
        guard parsed.blocks[0].cid == parsed.root,
              parsed.blocks[0].cid == CID.fromDAGCBOR(parsed.blocks[0].data),
              parsed.blocks[1].cid == emptyMSTCID,
              parsed.blocks[1].data == emptyMST,
              parsed.blocks[1].cid == CID.fromDAGCBOR(parsed.blocks[1].data),
              try reader.rawBlockData(for: CARReader.cidHex(from: parsed.root)) == parsed.blocks[0].data,
              try reader.rawBlockData(for: CARReader.cidHex(from: emptyMSTCID)) == parsed.blocks[1].data else {
            throw PublicRepositoryGenesisError.malformedCAR
        }

        let decoded = try decodeCommit(parsed.blocks[0].data, reader: reader, cid: parsed.root)
        try validateDID(decoded.did)
        try validateRevision(decoded.revision)
        guard decoded.dataCID == emptyMSTCID else { throw PublicRepositoryGenesisError.invalidCommit }

        let unsignedCommit = try encodeUnsignedCommit(
            did: decoded.did,
            revision: decoded.revision,
            dataCID: decoded.dataCID
        )
        let canonicalSignedCommit = try encodeSignedCommit(
            did: decoded.did,
            revision: decoded.revision,
            dataCID: decoded.dataCID,
            signature: decoded.signature
        )
        guard canonicalSignedCommit == parsed.blocks[0].data else {
            throw PublicRepositoryGenesisError.invalidCommit
        }

        let signature: P256.Signing.ECDSASignature
        do {
            signature = try P256WireSignature.decodeCanonical(decoded.signature)
        } catch {
            throw PublicRepositoryGenesisError.invalidSignature
        }
        guard publicKey.isValidSignature(signature, for: unsignedCommit) else {
            throw PublicRepositoryGenesisError.invalidSignature
        }

        return PublicRepositoryGenesis(
            did: decoded.did,
            revision: decoded.revision,
            emptyMST: emptyMST,
            emptyMSTCID: emptyMSTCID,
            unsignedCommit: unsignedCommit,
            signedCommit: parsed.blocks[0].data,
            commitCID: parsed.root,
            car: car
        )
    }

    /// AT Protocol permits DID methods beyond the two Swan account-management
    /// methods. Genesis creation therefore validates generic canonical DID
    /// syntax without attempting network resolution or method-specific policy.
    /// Callers supply the already-canonical identifier they control.
    public static func validateDID(_ did: String) throws {
        guard (try? DID(didString: did)) != nil else {
            throw PublicRepositoryGenesisError.invalidDID
        }
    }

    /// Repository v3 revisions are 13 sortable-base32 characters. This is
    /// intentionally broader than Petrel's timestamp-oriented TID validator:
    /// `a` through `j`, including `i`, are valid leading characters here.
    public static func validateRevision(_ revision: String) throws {
        let bytes = Array(revision.utf8)
        let alphabet = Set("234567abcdefghijklmnopqrstuvwxyz".utf8)
        let validLeading = Set("234567abcdefghij".utf8)
        guard bytes.count == 13,
              let first = bytes.first,
              validLeading.contains(first),
              bytes.allSatisfy(alphabet.contains) else {
            throw PublicRepositoryGenesisError.invalidRevision
        }
    }

    private struct ParsedBlock {
        let cid: CID
        let data: Data
    }

    private struct ParsedCAR {
        let root: CID
        let blocks: [ParsedBlock]
    }

    private struct DecodedCommit {
        let did: String
        let revision: String
        let dataCID: CID
        let signature: Data
    }

    private static func emptyMSTBlock() throws -> (Data, CID) {
        let encoded = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "e", value: [Any]()),
            (key: "l", value: NSNull()),
        ]))
        guard encoded == canonicalEmptyMST else { throw PublicRepositoryGenesisError.invalidCommit }
        let cid = CID.fromDAGCBOR(encoded)
        guard cid.string == canonicalEmptyMSTCID else { throw PublicRepositoryGenesisError.invalidCommit }
        return (encoded, cid)
    }

    private static func encodeUnsignedCommit(did: String, revision: String, dataCID: CID) throws -> Data {
        try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "did", value: did),
            (key: "version", value: 3),
            (key: "data", value: ATProtoLink(cid: dataCID)),
            (key: "rev", value: revision),
            (key: "prev", value: NSNull()),
        ]))
    }

    private static func encodeSignedCommit(
        did: String,
        revision: String,
        dataCID: CID,
        signature: Data
    ) throws -> Data {
        try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "did", value: did),
            (key: "version", value: 3),
            (key: "data", value: ATProtoLink(cid: dataCID)),
            (key: "rev", value: revision),
            (key: "prev", value: NSNull()),
            (key: "sig", value: signature),
        ]))
    }

    private static func encodeCAR(
        commitCID: CID,
        commit: Data,
        emptyMSTCID: CID,
        emptyMST: Data
    ) throws -> Data {
        let header = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "roots", value: [ATProtoLink(cid: commitCID)]),
            (key: "version", value: 1),
        ]))
        var car = Data()
        appendCanonicalVarint(header.count, to: &car)
        car.append(header)
        appendBlock(cid: commitCID, data: commit, to: &car)
        appendBlock(cid: emptyMSTCID, data: emptyMST, to: &car)
        guard car.count <= maximumCARBytes else { throw PublicRepositoryGenesisError.malformedCAR }
        return car
    }

    private static func parseGenesisCAR(_ car: Data, reader: CARReader) throws -> ParsedCAR {
        var offset = 0
        let headerLength = try readCanonicalVarint(car, offset: &offset)
        guard headerLength <= car.count - offset else { throw PublicRepositoryGenesisError.malformedCAR }
        let header = Data(car[offset ..< offset + headerLength])
        offset += headerLength

        guard reader.roots.count == 1 else { throw PublicRepositoryGenesisError.malformedCAR }
        let root = reader.roots[0]
        let expectedHeader = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "roots", value: [ATProtoLink(cid: root)]),
            (key: "version", value: 1),
        ]))
        guard header == expectedHeader else { throw PublicRepositoryGenesisError.malformedCAR }

        var blocks: [ParsedBlock] = []
        while offset < car.count {
            let blockLength = try readCanonicalVarint(car, offset: &offset)
            guard blockLength > 36, blockLength <= car.count - offset else {
                throw PublicRepositoryGenesisError.malformedCAR
            }
            let blockEnd = offset + blockLength
            let cidData = Data(car[offset ..< offset + 36])
            let cid: CID
            do {
                cid = try CID(bytes: cidData)
            } catch {
                throw PublicRepositoryGenesisError.malformedCAR
            }
            guard cid.bytes == cidData, cid.bytes.count == 36 else {
                throw PublicRepositoryGenesisError.malformedCAR
            }
            blocks.append(ParsedBlock(cid: cid, data: Data(car[offset + 36 ..< blockEnd])))
            offset = blockEnd
        }
        guard blocks.count == 2 else { throw PublicRepositoryGenesisError.malformedCAR }
        return ParsedCAR(root: root, blocks: blocks)
    }

    /// Performs only checked CARv1 frame walking. It runs before `CARReader`
    /// and must not decode or allocate attacker-selected block lengths.
    private static func preflightCARFraming(_ car: Data) throws {
        var offset = 0
        let headerLength = try readCanonicalVarint(car, offset: &offset)
        guard headerLength <= car.count - offset else { throw PublicRepositoryGenesisError.malformedCAR }
        offset += headerLength

        while offset < car.count {
            let blockLength = try readCanonicalVarint(car, offset: &offset)
            guard blockLength > 0, blockLength <= car.count - offset else {
                throw PublicRepositoryGenesisError.malformedCAR
            }
            offset += blockLength
        }
        guard offset == car.count else { throw PublicRepositoryGenesisError.malformedCAR }
    }

    private static func decodeCommit(_ data: Data, reader: CARReader, cid: CID) throws -> DecodedCommit {
        let value: Any
        do {
            value = try reader.decodeBlock(for: CARReader.cidHex(from: cid)) ?? NSNull()
        } catch {
            throw PublicRepositoryGenesisError.invalidCommit
        }
        guard let map = value as? [String: Any],
              map.count == 6,
              Set(map.keys) == Set(["did", "version", "data", "rev", "prev", "sig"]),
              let did = map["did"] as? String,
              let version = map["version"] as? UInt64, version == 3,
              let dataCID = map["data"] as? CID,
              let revision = map["rev"] as? String,
              map["prev"] is NSNull,
              let signature = map["sig"] as? Data,
              signature.count == 64 else {
            throw PublicRepositoryGenesisError.invalidCommit
        }
        return DecodedCommit(did: did, revision: revision, dataCID: dataCID, signature: signature)
    }

    private static func appendBlock(cid: CID, data: Data, to output: inout Data) {
        appendCanonicalVarint(cid.bytes.count + data.count, to: &output)
        output.append(cid.bytes)
        output.append(data)
    }

    private static func appendCanonicalVarint(_ value: Int, to output: inout Data) {
        precondition(value >= 0)
        var remaining = UInt64(value)
        repeat {
            var byte = UInt8(remaining & 0x7f)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            output.append(byte)
        } while remaining != 0
    }

    private static func readCanonicalVarint(_ data: Data, offset: inout Int) throws -> Int {
        let start = offset
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count {
            let byte = data[offset]
            offset += 1
            guard shift < 64 else { throw PublicRepositoryGenesisError.malformedCAR }
            let portion = UInt64(byte & 0x7f)
            guard shift < 63 || portion <= 1 else { throw PublicRepositoryGenesisError.malformedCAR }
            value |= portion << shift
            if byte & 0x80 == 0 {
                guard value <= UInt64(Int.max) else { throw PublicRepositoryGenesisError.malformedCAR }
                var canonical = Data()
                appendCanonicalVarint(Int(value), to: &canonical)
                guard canonical == data[start ..< offset] else {
                    throw PublicRepositoryGenesisError.malformedCAR
                }
                return Int(value)
            }
            shift += 7
        }
        throw PublicRepositoryGenesisError.malformedCAR
    }
}

/// Retains an explicit compile-time dependency on Petrel's canonical CID/CAR
/// implementation for users who need to type public repository identifiers.
public typealias PetrelCID = CID
