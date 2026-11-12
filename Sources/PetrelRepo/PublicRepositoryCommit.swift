import Foundation
import Petrel
import PetrelCrypto

/// Why a commit object was refused.
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
    /// The `prev` field is present but is not a blessed commit CID.
    case invalidPreviousCommitCID
    /// The commit's `version` is neither 3 nor (where a caller asked for the
    /// legacy reader) 2.
    case unsupportedVersion
    /// The signing key for the commit's DID could not be obtained.
    case signingKeyUnavailable
}

/// The fields of a repository-v3 commit, without its signature.
///
/// `prev` is carried exactly as it appears on the wire. The specification
/// makes it "CID link, nullable": current implementations write `null`, but a
/// commit that links its predecessor is valid, and its signature covers that
/// link, so the value has to survive a decode and re-encode unchanged.
public struct PublicRepositoryCommitDescriptor: Sendable, Equatable {
    /// The account DID.
    public let did: String
    /// The repository revision (`rev`), a TID.
    public let revision: PublicRepositoryTID
    /// CID of the MST root node (`data`).
    public let dataCID: CID
    /// CID of the previous commit (`prev`), or `nil` when the field is null.
    public let previousCommitCID: CID?

    /// Creates a descriptor with a null `prev`.
    public init(did: String, revision: String, dataCID: CID) throws {
        try self.init(did: did, revision: revision, dataCID: dataCID, previousCommitCID: nil)
    }

    /// Creates a descriptor.
    ///
    /// - Parameters:
    ///   - did: The account DID.
    ///   - revision: The `rev` TID.
    ///   - dataCID: The MST root CID; must be a blessed DAG-CBOR CID.
    ///   - previousCommitCID: The `prev` link, or `nil` for null.
    public init(did: String, revision: String, dataCID: CID, previousCommitCID: CID?) throws {
        if let previousCommitCID {
            do {
                try PublicRepositoryCID.validate(previousCommitCID)
            } catch {
                throw PublicRepositoryCommitError.invalidPreviousCommitCID
            }
        }
        self.previousCommitCID = previousCommitCID
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

/// A version-2 commit: the layout repositories used before `rev` became
/// mandatory. Read-only. Petrel never writes one.
///
/// Version 2 differs from version 3 in two ways: `rev` may be absent, and
/// `prev` normally links the previous commit. The signature rule is the same
/// (ECDSA over the DAG-CBOR of the commit without `sig`).
public struct LegacyRepositoryCommitV2: Sendable, Equatable {
    /// The account DID.
    public let did: String
    /// The revision, if the commit carries one.
    public let revision: String?
    /// CID of the MST root node.
    public let dataCID: CID
    /// CID of the previous commit, or `nil` when the field is null.
    public let previousCommitCID: CID?
    /// The 64-byte signature.
    public let signature: Data
    /// The exact bytes the signature covers.
    public let unsignedCommitBytes: Data
    /// The exact signed commit block.
    public let signedCommitBytes: Data
    /// CID of the signed commit block.
    public let commitCID: CID
    /// Whether ``PublicRepositoryCommitCodec/verifyLegacyV2(signedCommitBytes:expectedCommitCID:publicKey:)``
    /// checked the signature. `false` for a value from `decodeLegacyV2`.
    public let isSignatureVerified: Bool
}

/// Supplies the signing key an account currently publishes.
///
/// Implement this over DID resolution: return the key from the
/// `#atproto` verification method of the account's DID document. The commit
/// codec calls it once with `forceRefresh: false` and, only if the signature
/// does not verify against that key, once more with `forceRefresh: true`, so
/// a cached document that predates a key rotation is refreshed exactly once.
public protocol RepositorySigningKeyResolver: Sendable {
    /// Returns the atproto signing key for `did`.
    ///
    /// - Parameters:
    ///   - did: The account DID named in the commit.
    ///   - forceRefresh: `true` when a cached answer has just failed to verify
    ///     a signature and must be bypassed.
    func signingKey(for did: String, forceRefresh: Bool) async throws -> ATProtoPublicKey
}

/// A ``RepositorySigningKeyResolver`` that always answers with one key.
public struct FixedRepositorySigningKey: RepositorySigningKeyResolver {
    /// The key returned for every DID.
    public let publicKey: ATProtoPublicKey

    /// Creates a resolver that answers with `publicKey`.
    public init(_ publicKey: ATProtoPublicKey) {
        self.publicKey = publicKey
    }

    public func signingKey(for _: String, forceRefresh _: Bool) async throws -> ATProtoPublicKey {
        publicKey
    }
}

/// Encodes, signs and verifies repository commit objects.
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
        let descriptor = try Self.descriptor(fromVersion3: decoded)
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

    /// Returns the exact signed commit block size without invoking a signer.
    /// Wire signatures are 64 bytes on both curves, so the value is suitable
    /// for commit-diff budget enforcement before key use.
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

    /// Builds and signs a version-3 commit with any AT Protocol signer.
    ///
    /// This is the entry point for both curves: pass a `K256Keypair`, a
    /// `P256Keypair`, a Secure Enclave signer or an `ATProtoExternalSigner`.
    ///
    /// - Parameters:
    ///   - did: The account DID.
    ///   - revision: The new `rev`.
    ///   - dataCID: The MST root the commit points at.
    ///   - currentRevision: The previous `rev`; the new one must be greater.
    ///   - signer: Signs the DAG-CBOR of the unsigned commit.
    public static func prepare(
        did: String,
        revision: String,
        dataCID: CID,
        currentRevision: String? = nil,
        signer: any ATProtoSigner
    ) async throws -> PreparedPublicRepositorySignedCommit {
        try await prepare(
            did: did,
            revision: revision,
            dataCID: dataCID,
            currentRevision: currentRevision,
            signer: ATProtoRepositoryCommitSigner(signer)
        )
    }

    /// Builds and signs a version-3 commit through the repository signer
    /// protocol.
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

    /// Verifies a signed version-3 commit against a known public key.
    ///
    /// Checks, in order: the block hashes to `expectedCommitCID`; the bytes
    /// are the canonical DAG-CBOR of the commit schema; the signature is 64
    /// bytes, in range and low-S for the key's curve; and the signature
    /// verifies over the DAG-CBOR of the commit without `sig`.
    ///
    /// - Parameters:
    ///   - signedCommitBytes: The commit block.
    ///   - expectedCommitCID: The CID the block is expected to have.
    ///   - publicKey: The account's signing key, on either curve.
    /// - Throws: ``PublicRepositoryCommitError``.
    public static func verify(
        signedCommitBytes: Data,
        expectedCommitCID: CID,
        publicKey: ATProtoPublicKey
    ) throws -> VerifiedPublicRepositorySignedCommit {
        let parsed = try parseVersion3(
            signedCommitBytes: signedCommitBytes,
            expectedCommitCID: expectedCommitCID
        )
        let algorithm = PublicRepositorySigningAlgorithm(publicKey.curve)
        try validateSignature(parsed.signature, algorithm: algorithm)
        guard publicKey.isValidSignature(parsed.signature, for: parsed.unsigned, options: .strict) else {
            throw PublicRepositoryCommitError.invalidSignature
        }
        return VerifiedPublicRepositorySignedCommit(
            descriptor: parsed.descriptor,
            signingAlgorithm: algorithm,
            signature: parsed.signature,
            unsignedCommitBytes: parsed.unsigned,
            signedCommitBytes: signedCommitBytes,
            commitCID: expectedCommitCID
        )
    }

    /// Verifies a signed version-3 commit against the key its DID publishes.
    ///
    /// The resolver is asked for the key of the DID *named in the commit*.
    /// If the signature does not verify, the resolver is asked once more with
    /// `forceRefresh: true` and the check is repeated, which is the
    /// refresh-and-retry step the sync specification asks consumers to make
    /// before treating a commit as invalid.
    ///
    /// - Parameters:
    ///   - signedCommitBytes: The commit block.
    ///   - expectedCommitCID: The CID the block is expected to have.
    ///   - keyResolver: Looks up the account's signing key.
    ///   - expectedDID: If given, the commit must be for this DID.
    /// - Throws: ``PublicRepositoryCommitError``; `.signingKeyUnavailable`
    ///   when the resolver fails, `.invalidDID` when `expectedDID` does not
    ///   match.
    public static func verify(
        signedCommitBytes: Data,
        expectedCommitCID: CID,
        keyResolver: any RepositorySigningKeyResolver,
        expectedDID: String? = nil
    ) async throws -> VerifiedPublicRepositorySignedCommit {
        let parsed = try parseVersion3(
            signedCommitBytes: signedCommitBytes,
            expectedCommitCID: expectedCommitCID
        )
        if let expectedDID, expectedDID != parsed.descriptor.did {
            throw PublicRepositoryCommitError.invalidDID
        }
        var lastError = PublicRepositoryCommitError.invalidSignature
        for forceRefresh in [false, true] {
            let key: ATProtoPublicKey
            do {
                key = try await keyResolver.signingKey(
                    for: parsed.descriptor.did,
                    forceRefresh: forceRefresh
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw PublicRepositoryCommitError.signingKeyUnavailable
            }
            do {
                return try verify(
                    signedCommitBytes: signedCommitBytes,
                    expectedCommitCID: expectedCommitCID,
                    publicKey: key
                )
            } catch let error as PublicRepositoryCommitError where error == .invalidSignature {
                lastError = error
            }
        }
        throw lastError
    }

    /// Verifies a signed version-3 commit through the repository verifier
    /// protocol.
    public static func verify(
        signedCommitBytes: Data,
        expectedCommitCID: CID,
        verifier: any PublicRepositoryCommitVerifier
    ) async throws -> VerifiedPublicRepositorySignedCommit {
        let parsed = try parseVersion3(
            signedCommitBytes: signedCommitBytes,
            expectedCommitCID: expectedCommitCID
        )
        try validateSignature(parsed.signature, algorithm: verifier.signingAlgorithm)
        do {
            try await verifier.verify(
                signature: parsed.signature,
                unsignedCommitBytes: parsed.unsigned,
                did: parsed.descriptor.did
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PublicRepositoryCommitError.invalidSignature
        }
        return VerifiedPublicRepositorySignedCommit(
            descriptor: parsed.descriptor,
            signingAlgorithm: verifier.signingAlgorithm,
            signature: parsed.signature,
            unsignedCommitBytes: parsed.unsigned,
            signedCommitBytes: signedCommitBytes,
            commitCID: expectedCommitCID
        )
    }

    /// Reads the `version` field of a commit block without validating the
    /// rest of it, so a caller can route version-2 commits to the legacy
    /// reader.
    ///
    /// - Throws: ``PublicRepositoryCommitError/invalidSchema`` if the block is
    ///   not a commit-shaped DAG-CBOR map.
    public static func commitVersion(ofSignedCommitBytes bytes: Data) throws -> Int {
        var parser = CommitCBORParser(bytes)
        let decoded = try parser.parseSignedCommit()
        guard parser.isAtEnd else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        return decoded.version
    }

    /// Strictly decodes a version-2 commit without checking its signature.
    ///
    /// - Throws: ``PublicRepositoryCommitError``; `.unsupportedVersion` if
    ///   the block is not version 2.
    public static func decodeLegacyV2(
        signedCommitBytes: Data,
        expectedCommitCID: CID
    ) throws -> LegacyRepositoryCommitV2 {
        try parseLegacyV2(
            signedCommitBytes: signedCommitBytes,
            expectedCommitCID: expectedCommitCID,
            publicKey: nil
        )
    }

    /// Strictly decodes a version-2 commit and verifies its signature.
    public static func verifyLegacyV2(
        signedCommitBytes: Data,
        expectedCommitCID: CID,
        publicKey: ATProtoPublicKey
    ) throws -> LegacyRepositoryCommitV2 {
        try parseLegacyV2(
            signedCommitBytes: signedCommitBytes,
            expectedCommitCID: expectedCommitCID,
            publicKey: publicKey
        )
    }

    private static func parseLegacyV2(
        signedCommitBytes: Data,
        expectedCommitCID: CID,
        publicKey: ATProtoPublicKey?
    ) throws -> LegacyRepositoryCommitV2 {
        do {
            try PublicRepositoryCID.validate(expectedCommitCID, blockBytes: signedCommitBytes)
        } catch {
            throw PublicRepositoryCommitError.invalidCommitCID
        }
        var parser = CommitCBORParser(signedCommitBytes)
        let decoded = try parser.parseSignedCommit()
        guard parser.isAtEnd else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        guard decoded.version == 2 else {
            throw PublicRepositoryCommitError.unsupportedVersion
        }
        guard (try? DID(didString: decoded.did)) != nil else {
            throw PublicRepositoryCommitError.invalidDID
        }
        guard decoded.signature.count == 64 else {
            throw PublicRepositoryCommitError.invalidSignature
        }
        var entries: [(key: String, value: Any)] = [
            (key: "did", value: decoded.did),
            (key: "version", value: 2),
            (key: "data", value: ATProtoLink(cid: decoded.dataCID)),
            (key: "prev", value: decoded.previousCommitCID.map { ATProtoLink(cid: $0) } ?? NSNull()),
        ]
        if let revision = decoded.revision {
            entries.append((key: "rev", value: revision))
        }
        let unsigned = try DAGCBOR.encodeValue(OrderedCBORMap(entries: entries))
        let signed = try DAGCBOR.encodeValue(OrderedCBORMap(
            entries: entries + [(key: "sig", value: decoded.signature)]
        ))
        guard signed == signedCommitBytes else {
            throw PublicRepositoryCommitError.nonCanonicalCBOR
        }
        if let publicKey {
            guard ATProtoSignature.isCanonical(decoded.signature, curve: publicKey.curve),
                  publicKey.isValidSignature(decoded.signature, for: unsigned, options: .strict) else {
                throw PublicRepositoryCommitError.invalidSignature
            }
        }
        return LegacyRepositoryCommitV2(
            did: decoded.did,
            revision: decoded.revision,
            dataCID: decoded.dataCID,
            previousCommitCID: decoded.previousCommitCID,
            signature: decoded.signature,
            unsignedCommitBytes: unsigned,
            signedCommitBytes: signedCommitBytes,
            commitCID: expectedCommitCID,
            isSignatureVerified: publicKey != nil
        )
    }

    private struct ParsedVersion3 {
        let descriptor: PublicRepositoryCommitDescriptor
        let signature: Data
        let unsigned: Data
    }

    /// Everything about a version-3 commit that does not need a key: CID,
    /// schema, canonical encoding.
    private static func parseVersion3(
        signedCommitBytes: Data,
        expectedCommitCID: CID
    ) throws -> ParsedVersion3 {
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
        let descriptor = try Self.descriptor(fromVersion3: decoded)
        let unsigned = try encodeUnsigned(descriptor)
        let canonicalSigned = try encodeSigned(descriptor, signature: decoded.signature)
        guard canonicalSigned == signedCommitBytes else {
            throw PublicRepositoryCommitError.nonCanonicalCBOR
        }
        return ParsedVersion3(descriptor: descriptor, signature: decoded.signature, unsigned: unsigned)
    }

    private static func descriptor(
        fromVersion3 decoded: DecodedCommitFields
    ) throws -> PublicRepositoryCommitDescriptor {
        guard decoded.version == 3 else {
            throw decoded.version == 2
                ? PublicRepositoryCommitError.unsupportedVersion
                : PublicRepositoryCommitError.invalidSchema
        }
        guard let revision = decoded.revision else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        return try PublicRepositoryCommitDescriptor(
            did: decoded.did,
            revision: revision,
            dataCID: decoded.dataCID,
            previousCommitCID: decoded.previousCommitCID
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
            (key: "prev", value: previousLink(descriptor)),
        ]))
    }

    private static func previousLink(_ descriptor: PublicRepositoryCommitDescriptor) -> Any {
        descriptor.previousCommitCID.map { ATProtoLink(cid: $0) as Any } ?? NSNull()
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
            (key: "prev", value: previousLink(descriptor)),
            (key: "sig", value: signature),
        ]))
    }

    /// Structural signature check: 64 bytes, both scalars in range, low-S.
    /// The half-order constants live in `PetrelCrypto` (`ATProtoSignature`);
    /// there is no second copy here.
    private static func validateSignature(
        _ signature: Data,
        algorithm: PublicRepositorySigningAlgorithm
    ) throws {
        guard ATProtoSignature.isCanonical(signature, curve: algorithm.curve) else {
            throw PublicRepositoryCommitError.invalidSignature
        }
    }

    /// Both blessed curves can sign and verify. The hook stays so a future
    /// algorithm is refused here, before any signer is invoked.
    private static func validateSupportedSigningAlgorithm(
        _ algorithm: PublicRepositorySigningAlgorithm
    ) throws {
        switch algorithm {
        case .p256, .secp256k1:
            return
        }
    }
}

/// The raw fields of a version-2 or version-3 commit block.
private struct DecodedCommitFields {
    let did: String
    let revision: String?
    let dataCID: CID
    let previousCommitCID: CID?
    let signature: Data
    let version: Int
}

private struct CommitCBORParser {
    private let bytes: [UInt8]
    private(set) var offset = 0

    init(_ data: Data) {
        bytes = Array(data)
    }

    var isAtEnd: Bool { offset == bytes.count }

    /// Parses the commit map in canonical key order (shorter keys first, then
    /// bytewise): `did`, `rev`, `sig`, `data`, `prev`, `version`. A version-2
    /// commit may omit `rev`, giving five entries.
    mutating func parseSignedCommit() throws -> DecodedCommitFields {
        let entryCount = try readLength(major: 5)
        guard entryCount == 6 || entryCount == 5 else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        guard try readText() == "did" else { throw schemaOrCanonical() }
        let did = try readText()
        var revision: String?
        if entryCount == 6 {
            guard try readText() == "rev" else { throw schemaOrCanonical() }
            revision = try readText()
        }
        guard try readText() == "sig" else { throw schemaOrCanonical() }
        let signature = try readBytes()
        guard try readText() == "data" else { throw schemaOrCanonical() }
        let dataCID = try readRequiredLink(failure: .invalidDataCID)
        guard try readText() == "prev" else { throw schemaOrCanonical() }
        let previous: CID?
        if peekByte() == 0xf6 {
            offset += 1
            previous = nil
        } else {
            previous = try readRequiredLink(failure: .invalidPreviousCommitCID)
        }
        guard try readText() == "version" else { throw schemaOrCanonical() }
        let version = try readUnsigned()
        guard version == 3 || version == 2 else {
            throw PublicRepositoryCommitError.unsupportedVersion
        }
        guard version == 2 || revision != nil else {
            throw PublicRepositoryCommitError.invalidSchema
        }
        return DecodedCommitFields(
            did: did,
            revision: revision,
            dataCID: dataCID,
            previousCommitCID: previous,
            signature: signature,
            version: Int(version)
        )
    }

    private func peekByte() -> UInt8? {
        offset < bytes.count ? bytes[offset] : nil
    }

    private mutating func readRequiredLink(
        failure: PublicRepositoryCommitError
    ) throws -> CID {
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
            throw failure
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
