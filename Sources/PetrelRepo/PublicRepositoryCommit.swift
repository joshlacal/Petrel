import Foundation
import Petrel
import PetrelCrypto

public enum PublicRepositoryCommitError: Error, Sendable, Equatable {
    case invalidDID
    case invalidRevision
    case revisionNotIncreasing
    case invalidDataCID
    case invalidCommitCID
    case invalidSchema
    case nonCanonicalCBOR
    case invalidSignature
    case unsupportedSigningAlgorithm
}

/// The deterministic repository-v3 commit fields. `prev` is intentionally
/// absent from this domain value because its wire representation is always
/// null. Previous commit and revision values are transaction metadata.
public struct PublicRepositoryCommitDescriptor: Sendable, Equatable {
    public let did: String
    public let revision: PublicRepositoryTID
    public let dataCID: CID

    public init(did: String, revision: String, dataCID: CID) throws {
        guard (try? DID(didString: did)) != nil else {
            throw PublicRepositoryCommitError.invalidDID
        }
        let parsedRevision: PublicRepositoryTID
        do {
            parsedRevision = try PublicRepositoryTID(revision)
        } catch {
            throw PublicRepositoryCommitError.invalidRevision
        }
        do {
            try PublicRepositoryCID.validate(dataCID)
        } catch {
            throw PublicRepositoryCommitError.invalidDataCID
        }
        self.did = did
        self.revision = parsedRevision
        self.dataCID = dataCID
    }
}

/// A locally signed commit whose invariants can only be established by the
/// codec below. There is no public unchecked initializer.
public struct PreparedPublicRepositorySignedCommit: Sendable, Equatable {
    public let descriptor: PublicRepositoryCommitDescriptor
    public let signingAlgorithm: PublicRepositorySigningAlgorithm
    public let signature: Data
    public let unsignedCommitBytes: Data
    public let signedCommitBytes: Data
    public let commitCID: CID

    fileprivate init(
        descriptor: PublicRepositoryCommitDescriptor,
        signingAlgorithm: PublicRepositorySigningAlgorithm,
        signature: Data,
        unsignedCommitBytes: Data,
        signedCommitBytes: Data,
        commitCID: CID
    ) {
        self.descriptor = descriptor
        self.signingAlgorithm = signingAlgorithm
        self.signature = signature
        self.unsignedCommitBytes = unsignedCommitBytes
        self.signedCommitBytes = signedCommitBytes
        self.commitCID = commitCID
    }
}

/// A wire commit whose canonical schema, CID, signature encoding, and
/// cryptographic signature have all been checked.
public struct VerifiedPublicRepositorySignedCommit: Sendable, Equatable {
    public let descriptor: PublicRepositoryCommitDescriptor
    public let signingAlgorithm: PublicRepositorySigningAlgorithm
    public let signature: Data
    public let unsignedCommitBytes: Data
    public let signedCommitBytes: Data
    public let commitCID: CID

    fileprivate init(
        descriptor: PublicRepositoryCommitDescriptor,
        signingAlgorithm: PublicRepositorySigningAlgorithm,
        signature: Data,
        unsignedCommitBytes: Data,
        signedCommitBytes: Data,
        commitCID: CID
    ) {
        self.descriptor = descriptor
        self.signingAlgorithm = signingAlgorithm
        self.signature = signature
        self.unsignedCommitBytes = unsignedCommitBytes
        self.signedCommitBytes = signedCommitBytes
        self.commitCID = commitCID
    }
}

/// A canonical signed commit whose schema and CID are valid, but whose
/// signature has deliberately not been checked against an account key.
public struct StructurallyValidatedPublicRepositorySignedCommit: Sendable, Equatable {
    public let descriptor: PublicRepositoryCommitDescriptor
    public let signature: Data
    public let signedCommitBytes: Data
    public let commitCID: CID

    fileprivate init(
        descriptor: PublicRepositoryCommitDescriptor,
        signature: Data,
        signedCommitBytes: Data,
        commitCID: CID
    ) {
        self.descriptor = descriptor
        self.signature = signature
        self.signedCommitBytes = signedCommitBytes
        self.commitCID = commitCID
    }
}

public enum PublicRepositoryCommitCodec {
    /// Strictly checks the canonical repository-v3 schema and CID without
    /// making any cryptographic authenticity claim.
    public static func structurallyValidate(
        signedCommitBytes: Data,
        expectedCommitCID: CID
    ) throws -> StructurallyValidatedPublicRepositorySignedCommit {
        do {
            try PublicRepositoryCID.validate(
                expectedCommitCID,
                blockBytes: signedCommitBytes
            )
        } catch {
            throw PublicRepositoryCommitError.invalidCommitCID
        }
        var parser = CommitCBORParser(signedCommitBytes)
        let decoded = try parser.parseSignedCommit()
        guard parser.isAtEnd else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        let descriptor = try PublicRepositoryCommitDescriptor(
            did: decoded.did,
            revision: decoded.revision,
            dataCID: decoded.dataCID
        )
        guard decoded.signature.count == 64 else {
            throw PublicRepositoryCommitError.invalidSignature
        }
        let canonical = try encodeSigned(descriptor, signature: decoded.signature)
        guard canonical == signedCommitBytes else {
            throw PublicRepositoryCommitError.nonCanonicalCBOR
        }
        return StructurallyValidatedPublicRepositorySignedCommit(
            descriptor: descriptor,
            signature: decoded.signature,
            signedCommitBytes: signedCommitBytes,
            commitCID: expectedCommitCID
        )
    }

    /// Returns the exact signed P-256 commit block size without invoking a
    /// signer. P-256 wire signatures are fixed-width, so the value is suitable
    /// for aggregate relevant-block budget enforcement before key use.
    static func preflightSignedCommitByteCount(
        did: String,
        revision: String,
        dataCID: CID,
        currentRevision: String?,
        signingAlgorithm: PublicRepositorySigningAlgorithm
    ) throws -> Int {
        let descriptor = try descriptor(
            did: did,
            revision: revision,
            dataCID: dataCID,
            currentRevision: currentRevision
        )
        try validateSupportedSigningAlgorithm(signingAlgorithm)
        return try encodeSigned(descriptor, signature: Data(repeating: 0, count: 64)).count
    }

    public static func encodeUnsigned(
        did: String,
        revision: String,
        dataCID: CID,
        currentRevision: String? = nil
    ) throws -> Data {
        let descriptor = try descriptor(
            did: did,
            revision: revision,
            dataCID: dataCID,
            currentRevision: currentRevision
        )
        return try encodeUnsigned(descriptor)
    }

    public static func prepare(
        did: String,
        revision: String,
        dataCID: CID,
        currentRevision: String? = nil,
        signer: any PublicRepositoryCommitSigner
    ) async throws -> PreparedPublicRepositorySignedCommit {
        let descriptor = try descriptor(
            did: did,
            revision: revision,
            dataCID: dataCID,
            currentRevision: currentRevision
        )
        try validateSupportedSigningAlgorithm(signer.signingAlgorithm)
        let unsigned = try encodeUnsigned(descriptor)
        let signature = try await signer.sign(unsignedCommitBytes: unsigned)
        try validateSignature(signature, algorithm: signer.signingAlgorithm)
        let signed = try encodeSigned(descriptor, signature: signature)
        let cid = CID.fromDAGCBOR(signed)
        try PublicRepositoryCID.validate(cid, blockBytes: signed)
        return PreparedPublicRepositorySignedCommit(
            descriptor: descriptor,
            signingAlgorithm: signer.signingAlgorithm,
            signature: signature,
            unsignedCommitBytes: unsigned,
            signedCommitBytes: signed,
            commitCID: cid
        )
    }

    public static func verify(
        signedCommitBytes: Data,
        expectedCommitCID: CID,
        verifier: any PublicRepositoryCommitVerifier
    ) async throws -> VerifiedPublicRepositorySignedCommit {
        do {
            try PublicRepositoryCID.validate(expectedCommitCID)
        } catch {
            throw PublicRepositoryCommitError.invalidCommitCID
        }
        guard CID.fromDAGCBOR(signedCommitBytes) == expectedCommitCID else {
            throw PublicRepositoryCommitError.invalidCommitCID
        }

        var parser = CommitCBORParser(signedCommitBytes)
        let decoded = try parser.parseSignedCommit()
        guard parser.isAtEnd else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        let descriptor = try PublicRepositoryCommitDescriptor(
            did: decoded.did,
            revision: decoded.revision,
            dataCID: decoded.dataCID
        )
        try validateSupportedVerifierAlgorithm(verifier.signingAlgorithm)
        try validateSignature(decoded.signature, algorithm: verifier.signingAlgorithm)
        let unsigned = try encodeUnsigned(descriptor)
        let canonicalSigned = try encodeSigned(descriptor, signature: decoded.signature)
        guard canonicalSigned == signedCommitBytes else {
            throw PublicRepositoryCommitError.nonCanonicalCBOR
        }
        do {
            try await verifier.verify(
                signature: decoded.signature,
                unsignedCommitBytes: unsigned,
                did: descriptor.did
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PublicRepositoryCommitError.invalidSignature
        }
        return VerifiedPublicRepositorySignedCommit(
            descriptor: descriptor,
            signingAlgorithm: verifier.signingAlgorithm,
            signature: decoded.signature,
            unsignedCommitBytes: unsigned,
            signedCommitBytes: signedCommitBytes,
            commitCID: expectedCommitCID
        )
    }

    private static func descriptor(
        did: String,
        revision: String,
        dataCID: CID,
        currentRevision: String?
    ) throws -> PublicRepositoryCommitDescriptor {
        let descriptor = try PublicRepositoryCommitDescriptor(
            did: did,
            revision: revision,
            dataCID: dataCID
        )
        if let currentRevision {
            let current: PublicRepositoryTID
            do {
                current = try PublicRepositoryTID(currentRevision)
            } catch {
                throw PublicRepositoryCommitError.invalidRevision
            }
            guard current < descriptor.revision else {
                throw PublicRepositoryCommitError.revisionNotIncreasing
            }
        }
        return descriptor
    }

    private static func encodeUnsigned(_ descriptor: PublicRepositoryCommitDescriptor) throws -> Data {
        try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "did", value: descriptor.did),
            (key: "version", value: 3),
            (key: "data", value: ATProtoLink(cid: descriptor.dataCID)),
            (key: "rev", value: descriptor.revision.value),
            (key: "prev", value: NSNull()),
        ]))
    }

    private static func encodeSigned(
        _ descriptor: PublicRepositoryCommitDescriptor,
        signature: Data
    ) throws -> Data {
        try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "did", value: descriptor.did),
            (key: "version", value: 3),
            (key: "data", value: ATProtoLink(cid: descriptor.dataCID)),
            (key: "rev", value: descriptor.revision.value),
            (key: "prev", value: NSNull()),
            (key: "sig", value: signature),
        ]))
    }

    private static func validateSignature(
        _ signature: Data,
        algorithm: PublicRepositorySigningAlgorithm
    ) throws {
        switch algorithm {
        case .p256:
            guard P256WireSignature.isCanonicalLowS(signature) else {
                throw PublicRepositoryCommitError.invalidSignature
            }
        case .secp256k1:
            guard isCanonicalSecp256k1Signature(signature) else {
                throw PublicRepositoryCommitError.invalidSignature
            }
        }
    }

    private static func validateSupportedSigningAlgorithm(
        _ algorithm: PublicRepositorySigningAlgorithm
    ) throws {
        // Swan's repository writer still emits P-256 commits. The verifier
        // path below accepts the pinned TypeScript secp256k1 form without
        // silently claiming that Swan can produce it yet.
        guard algorithm == .p256 else {
            throw PublicRepositoryCommitError.unsupportedSigningAlgorithm
        }
    }

    private static func validateSupportedVerifierAlgorithm(
        _ algorithm: PublicRepositorySigningAlgorithm
    ) throws {
        guard algorithm == .p256 || algorithm == .secp256k1 else {
            throw PublicRepositoryCommitError.unsupportedSigningAlgorithm
        }
    }

    /// The pinned TypeScript repository implementation emits compact
    /// secp256k1 signatures in low-S form. Keep this structural check in the
    /// public-repository target so a verifier cannot be called with a
    /// malleable signature, while the concrete verifier remains responsible
    /// for checking the public key and message.
    private static func isCanonicalSecp256k1Signature(_ signature: Data) -> Bool {
        let bytes = Array(signature)
        guard bytes.count == 64 else { return false }
        let halfOrder: [UInt8] = [
            0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0x5d, 0x57, 0x6e, 0x73, 0x57, 0xa4, 0x50, 0x1d,
            0xdf, 0xe9, 0x2f, 0x46, 0x68, 0x1b, 0x20, 0xa0,
        ]
        let r = bytes[..<32]
        let s = bytes[32...]
        guard r.contains(where: { $0 != 0 }),
              s.contains(where: { $0 != 0 }) else {
            return false
        }
        for (value, maximum) in zip(s, halfOrder) {
            if value != maximum { return value < maximum }
        }
        return true
    }
}

private struct CommitCBORParser {
    private let bytes: [UInt8]
    private(set) var offset = 0

    init(_ data: Data) {
        bytes = Array(data)
    }

    var isAtEnd: Bool { offset == bytes.count }

    mutating func parseSignedCommit() throws -> (
        did: String,
        revision: String,
        dataCID: CID,
        signature: Data
    ) {
        guard try readLength(major: 5) == 6 else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        guard try readText() == "did" else { throw schemaOrCanonical() }
        let did = try readText()
        guard try readText() == "rev" else { throw schemaOrCanonical() }
        let revision = try readText()
        guard try readText() == "sig" else { throw schemaOrCanonical() }
        let signature = try readBytes()
        guard try readText() == "data" else { throw schemaOrCanonical() }
        let dataCID = try readRequiredLink()
        guard try readText() == "prev" else { throw schemaOrCanonical() }
        guard readByte() == 0xf6 else { throw PublicRepositoryCommitError.invalidSchema }
        guard try readText() == "version" else { throw schemaOrCanonical() }
        guard try readUnsigned() == 3 else { throw PublicRepositoryCommitError.invalidSchema }
        return (did, revision, dataCID, signature)
    }

    private mutating func readRequiredLink() throws -> CID {
        guard try readLength(major: 6) == 42 else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        let payload = try readBytes()
        guard payload.count == 37, payload.first == 0 else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        do {
            let cid = try CID(bytes: Data(payload.dropFirst()))
            try PublicRepositoryCID.validate(cid)
            return cid
        } catch {
            throw PublicRepositoryCommitError.invalidDataCID
        }
    }

    private mutating func readText() throws -> String {
        let length = try readLength(major: 3)
        guard length <= bytes.count - offset else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        let slice = bytes[offset ..< offset + length]
        offset += length
        guard let value = String(bytes: slice, encoding: .utf8) else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        return value
    }

    private mutating func readBytes() throws -> Data {
        let length = try readLength(major: 2)
        guard length <= bytes.count - offset else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        let result = Data(bytes[offset ..< offset + length])
        offset += length
        return result
    }

    private mutating func readUnsigned() throws -> UInt64 {
        try readArgument(expectedMajor: 0)
    }

    private mutating func readLength(major: UInt8) throws -> Int {
        let argument = try readArgument(expectedMajor: major)
        guard argument <= UInt64(Int.max) else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        return Int(argument)
    }

    private mutating func readArgument(expectedMajor: UInt8) throws -> UInt64 {
        guard let initial = readByte(), initial >> 5 == expectedMajor else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        switch initial & 0x1f {
        case 0 ... 23:
            return UInt64(initial & 0x1f)
        case 24:
            let value = try readFixed(1)
            guard value >= 24 else { throw PublicRepositoryCommitError.nonCanonicalCBOR }
            return value
        case 25:
            let value = try readFixed(2)
            guard value > UInt8.max else { throw PublicRepositoryCommitError.nonCanonicalCBOR }
            return value
        case 26:
            let value = try readFixed(4)
            guard value > UInt16.max else { throw PublicRepositoryCommitError.nonCanonicalCBOR }
            return value
        case 27:
            let value = try readFixed(8)
            guard value > UInt32.max else { throw PublicRepositoryCommitError.nonCanonicalCBOR }
            return value
        default:
            throw PublicRepositoryCommitError.invalidSchema
        }
    }

    private mutating func readFixed(_ count: Int) throws -> UInt64 {
        guard count <= bytes.count - offset else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        var value: UInt64 = 0
        for byte in bytes[offset ..< offset + count] {
            value = (value << 8) | UInt64(byte)
        }
        offset += count
        return value
    }

    private mutating func readByte() -> UInt8? {
        guard offset < bytes.count else { return nil }
        defer { offset += 1 }
        return bytes[offset]
    }

    private func schemaOrCanonical() -> PublicRepositoryCommitError {
        .invalidSchema
    }
}
