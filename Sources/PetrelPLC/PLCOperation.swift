import Crypto
import Foundation
import PetrelCore
import PetrelCrypto

/// One entry of a PLC operation's `services` map.
public struct PLCService: Codable, Sendable, Equatable {
    /// The service type, for example `AtprotoPersonalDataServer`.
    public let type: String
    /// The service URL.
    public let endpoint: String

    /// Creates a service entry.
    public init(type: String, endpoint: String) {
        self.type = type
        self.endpoint = endpoint
    }
}

/// A `plc_operation` that has not been signed yet.
///
/// The initializer applies the rules for *writing* an operation
/// (``PLCOperationLimits/specification``): 1–5 distinct P-256 or K-256
/// rotation keys, at most 10 verification methods each a syntactically valid
/// `did:key`, a canonical `prev` CID, and the 7,500-byte DAG-CBOR limit.
/// Operations read from a directory are held to looser rules; see
/// ``PLCOperationCodec/decodeSignedJSON(_:)``.
public struct PLCUnsignedRegularOperation: Sendable, Equatable {
    /// Priority-ordered rotation keys, as `did:key` strings.
    public let rotationKeys: [String]
    /// Verification method id (no `#`) to `did:key`.
    public let verificationMethods: [String: String]
    /// Priority-ordered aliases, for atproto `at://<handle>`.
    public let alsoKnownAs: [String]
    /// Service id (no `#`) to service.
    public let services: [String: PLCService]
    /// CID of the operation this one follows, or `nil` for a genesis operation.
    public let prev: String?

    /// - Throws: ``PetrelPLCError/malformed(_:)`` or
    ///   ``PetrelPLCError/invalidIdentifier(_:)`` when a write rule is broken.
    public init(
        rotationKeys: [String],
        verificationMethods: [String: String],
        alsoKnownAs: [String],
        services: [String: PLCService],
        prev: String?
    ) throws {
        self.rotationKeys = rotationKeys
        self.verificationMethods = verificationMethods
        self.alsoKnownAs = alsoKnownAs
        self.services = services
        self.prev = prev
        try PLCOperationCodec.validate(
            rotationKeys: rotationKeys,
            verificationMethods: verificationMethods,
            alsoKnownAs: alsoKnownAs,
            services: services,
            prev: prev,
            limits: .specification
        )
        guard try PLCOperationCodec.encodeSigningBytes(.regular(self)).count
            <= PLCOperationLimits.specification.maximumDAGCBORBytes else {
            throw PetrelPLCError.malformed("PLC operation exceeds 7,500 DAG-CBOR bytes")
        }
    }
}

/// A `plc_tombstone` that has not been signed yet.
public struct PLCUnsignedTombstoneOperation: Sendable, Equatable {
    /// CID of the operation being deactivated.
    public let prev: String

    /// - Throws: ``PetrelPLCError/invalidIdentifier(_:)`` unless `prev` is a
    ///   canonical base32 CIDv1 with the `dag-cbor` codec and a SHA-256 hash.
    public init(prev: String) throws {
        try PLCOperationCodec.validatePreviousCID(prev)
        self.prev = prev
    }
}

/// An operation ready to be signed.
public enum PLCUnsignedOperation: Sendable, Equatable {
    /// A `plc_operation`: creates or updates an identity.
    case regular(PLCUnsignedRegularOperation)
    /// A `plc_tombstone`: deactivates an identity.
    case tombstone(PLCUnsignedTombstoneOperation)

    /// The DAG-CBOR bytes a rotation key signs: the operation without a
    /// `sig` field.
    ///
    /// Use this with ``PLCOperationCodec/attach(signature:to:)`` when the
    /// signature is produced somewhere `ATProtoSigner` cannot reach, such as
    /// an air-gapped machine.
    public var signingDAGCBOR: Data {
        get throws { try PLCOperationCodec.encodeSigningBytes(self) }
    }

    /// CID of the operation this one follows, or `nil` for a genesis operation.
    public var prev: String? {
        switch self {
        case let .regular(operation): operation.prev
        case let .tombstone(operation): operation.prev
        }
    }
}

/// A signed `plc_operation`.
///
/// Values of this type come from ``PLCOperationCodec`` — by signing, or by
/// decoding what a directory returned — and are not validated against the
/// write rules: historical operations in the public directory carry
/// duplicate rotation keys, empty `verificationMethods` and non-ECDSA
/// verification keys.
public struct PLCSignedRegularOperation: Sendable, Equatable {
    /// Priority-ordered rotation keys, as `did:key` strings.
    public let rotationKeys: [String]
    /// Verification method id (no `#`) to `did:key`.
    public let verificationMethods: [String: String]
    /// Priority-ordered aliases.
    public let alsoKnownAs: [String]
    /// Service id (no `#`) to service.
    public let services: [String: PLCService]
    /// CID of the operation this one follows, or `nil` for a genesis operation.
    public let prev: String?
    /// The `sig` field: base64url, no padding, of the 64-byte signature.
    public let signature: String
}

/// A signed `plc_tombstone`.
public struct PLCSignedTombstoneOperation: Sendable, Equatable {
    /// CID of the operation being deactivated.
    public let prev: String
    /// The `sig` field: base64url, no padding, of the 64-byte signature.
    public let signature: String
}

/// A signed operation in the deprecated `create` format.
///
/// Only genesis operations exist in this format, and only for identities
/// registered before the format changed in March 2023. Their DIDs are the
/// hash of these exact fields, so the format has to be read and verified
/// forever, but it must not be used for new identities and
/// ``PLCDirectoryClient`` refuses to submit one.
///
/// ``rotationKeys``, ``verificationMethods``, ``alsoKnownAs`` and
/// ``services`` give the same data in the modern shape, the way the
/// reference implementation's `normalizeOp` does.
public struct PLCSignedLegacyCreateOperation: Sendable, Equatable {
    /// The atproto signing key, as a `did:key`.
    public let signingKey: String
    /// The recovery key, as a `did:key`. Outranks ``signingKey``.
    public let recoveryKey: String
    /// The bare handle, without an `at://` prefix.
    public let handle: String
    /// The PDS URL exactly as registered. A handful of early operations
    /// carry a bare `host:port` here; ``services`` adds the scheme.
    public let service: String
    /// The `sig` field: base64url, no padding, of the 64-byte signature.
    public let signature: String

    /// `[recoveryKey, signingKey]`: the recovery key has the higher authority.
    public var rotationKeys: [String] { [recoveryKey, signingKey] }

    /// `["atproto": signingKey]`.
    public var verificationMethods: [String: String] { ["atproto": signingKey] }

    /// The handle as an `at://` URI.
    public var alsoKnownAs: [String] { [PLCATProfile.atURI(forHandle: handle)] }

    /// The PDS as an `atproto_pds` service, with `https://` added when the
    /// registered value has no scheme.
    public var services: [String: PLCService] {
        [
            PLCATProfile.pdsServiceID: PLCService(
                type: PLCATProfile.pdsServiceType,
                endpoint: PLCATProfile.withHTTPScheme(service)
            ),
        ]
    }
}

/// A signed operation of any of the three kinds a PLC directory stores.
public enum PLCSignedOperation: Sendable, Equatable {
    /// A `plc_operation`: creates or updates an identity.
    case regularOperation(PLCSignedRegularOperation)
    /// A `plc_tombstone`: deactivates an identity.
    case tombstoneOperation(PLCSignedTombstoneOperation)
    /// The deprecated `create` genesis format.
    case legacyCreateOperation(PLCSignedLegacyCreateOperation)

    /// The payload if this is a `plc_operation`. `nil` for a tombstone and
    /// for a legacy `create`; use ``documentData(did:)`` to read the state of
    /// either non-tombstone kind.
    public var regular: PLCSignedRegularOperation? {
        guard case let .regularOperation(operation) = self else { return nil }
        return operation
    }

    /// The payload if this is a legacy `create` operation.
    public var legacyCreate: PLCSignedLegacyCreateOperation? {
        guard case let .legacyCreateOperation(operation) = self else { return nil }
        return operation
    }

    /// Whether this is a `plc_tombstone`.
    public var isTombstone: Bool {
        if case .tombstoneOperation = self { return true }
        return false
    }

    /// CID of the operation this one follows, or `nil` for a genesis operation.
    public var prev: String? {
        switch self {
        case let .regularOperation(operation): operation.prev
        case let .tombstoneOperation(operation): operation.prev
        case .legacyCreateOperation: nil
        }
    }

    /// The `sig` field.
    public var signature: String {
        switch self {
        case let .regularOperation(operation): operation.signature
        case let .tombstoneOperation(operation): operation.signature
        case let .legacyCreateOperation(operation): operation.signature
        }
    }

    /// The rotation keys that may sign the operation that follows this one,
    /// in priority order. `nil` for a tombstone, which nothing may follow.
    /// A legacy `create` yields `[recoveryKey, signingKey]`.
    public var rotationKeys: [String]? {
        switch self {
        case let .regularOperation(operation): operation.rotationKeys
        case .tombstoneOperation: nil
        case let .legacyCreateOperation(operation): operation.rotationKeys
        }
    }

    /// The identity state this operation establishes, in the shape
    /// `GET /:did/data` returns. `nil` for a tombstone.
    public func documentData(did: String) -> PLCDocumentData? {
        switch self {
        case let .regularOperation(operation):
            PLCDocumentData(
                did: did,
                rotationKeys: operation.rotationKeys,
                verificationMethods: operation.verificationMethods,
                alsoKnownAs: operation.alsoKnownAs,
                services: operation.services
            )
        case .tombstoneOperation:
            nil
        case let .legacyCreateOperation(operation):
            PLCDocumentData(
                did: did,
                rotationKeys: operation.rotationKeys,
                verificationMethods: operation.verificationMethods,
                alsoKnownAs: operation.alsoKnownAs,
                services: operation.services
            )
        }
    }

    /// The DAG-CBOR bytes the signature covers: the operation in its own
    /// format, without the `sig` field.
    public var signingDAGCBOR: Data {
        get throws { try PLCOperationCodec.encode(self, includingSignature: false) }
    }

    /// The DAG-CBOR bytes that are hashed for the operation's CID and, for a
    /// genesis operation, for the DID.
    public var canonicalDAGCBOR: Data {
        get throws { try PLCOperationCodec.encode(self, includingSignature: true) }
    }

    /// The operation as JSON with sorted keys, the form `POST /:did` takes.
    public var canonicalJSON: Data {
        get throws { try PLCOperationCodec.encodeSignedJSON(self) }
    }

    /// CIDv1 (`dag-cbor`, SHA-256) of ``canonicalDAGCBOR``. This is what the
    /// next operation names in `prev`.
    public var cid: CID {
        get throws { try CID.fromDAGCBOR(canonicalDAGCBOR) }
    }
}

/// Encoding, signing, hashing and verification of PLC operations.
public enum PLCOperationCodec {
    /// The specification's limit on an operation's DAG-CBOR size.
    public static let maximumDAGCBORBytes = PLCOperationLimits.specification.maximumDAGCBORBytes

    /// The largest JSON document ``decodeSignedJSON(_:)`` will parse.
    public static let maximumOperationJSONBytes = 64 * 1_024

    // MARK: Signing

    /// Signs an operation with any AT Protocol signer: an in-memory
    /// `K256Keypair` or `P256Keypair`, a Secure Enclave key, or an
    /// `ATProtoExternalSigner` wrapping a KMS or hardware token.
    ///
    /// The signature must come back as 64 bytes `r || s` with low-S, which
    /// is the `ATProtoSigner` contract; anything else is refused rather than
    /// repaired. When the signer also exposes its public key, the signature
    /// is checked against it before it is used.
    ///
    /// The signer has to be a rotation key of the operation named in `prev`
    /// (or, for a genesis operation, of the operation itself). That is the
    /// directory's rule and is not checked here, because this function does
    /// not see the previous operation; ``PLCDirectoryClient`` checks it.
    ///
    /// - Throws: Whatever the signer throws; ``PetrelPLCError/malformed(_:)``
    ///   for a non-canonical signature; ``PetrelPLCError/unauthorized(_:)``
    ///   if the signature does not verify against the signer's own key.
    public static func sign(
        _ operation: PLCUnsignedOperation,
        with signer: any ATProtoSigner
    ) async throws -> PLCSignedOperation {
        let signingBytes = try encodeSigningBytes(operation)
        let signature = try await signer.sign(signingBytes)
        guard ATProtoSignature.isCanonical(signature, curve: signer.curve) else {
            throw PetrelPLCError.malformed(
                "PLC signer returned a signature that is not 64-byte low-S"
            )
        }
        if let keypair = signer as? any ATProtoKeypair {
            guard keypair.publicKey.isValidSignature(signature, for: signingBytes) else {
                throw PetrelPLCError.unauthorized(
                    "PLC signer returned a signature that does not verify against its public key"
                )
            }
        }
        return try attach(signature: signature, to: operation)
    }

    /// Signs an operation with an in-memory Swift Crypto P-256 key.
    public static func sign(
        _ operation: PLCUnsignedOperation,
        using key: P256.Signing.PrivateKey
    ) throws -> PLCSignedOperation {
        let signingBytes = try encodeSigningBytes(operation)
        let signature = try P256Keypair(key).sign(signingBytes)
        return try attach(signature: signature, to: operation)
    }

    /// Combines an operation with a signature produced elsewhere over
    /// ``PLCUnsignedOperation/signingDAGCBOR``.
    ///
    /// - Parameters:
    ///   - signature: 64 bytes `r || s`, low-S. DER and high-S are refused;
    ///     convert a trusted local signer's output with
    ///     `ATProtoSignature.canonicalize(_:curve:)` first.
    ///   - operation: The operation whose ``PLCUnsignedOperation/signingDAGCBOR``
    ///     was signed.
    /// - Throws: ``PetrelPLCError/malformed(_:)``.
    public static func attach(
        signature: Data,
        to operation: PLCUnsignedOperation
    ) throws -> PLCSignedOperation {
        guard isCanonicalOnASupportedCurve(signature) else {
            throw PetrelPLCError.malformed("PLC operation signature is not canonical")
        }
        let encoded = signature.plcBase64URL
        let signed: PLCSignedOperation
        switch operation {
        case let .regular(value):
            signed = .regularOperation(.init(
                rotationKeys: value.rotationKeys,
                verificationMethods: value.verificationMethods,
                alsoKnownAs: value.alsoKnownAs,
                services: value.services,
                prev: value.prev,
                signature: encoded
            ))
        case let .tombstone(value):
            signed = .tombstoneOperation(.init(prev: value.prev, signature: encoded))
        }
        try validateForSubmission(signed, limits: .specification)
        return signed
    }

    /// Reconstructs a regular `prev: null` operation from its stored parts
    /// and an existing signature, applying the write rules.
    public static func reconstructGenesis(
        signingDIDKey: String,
        rotationDIDKey: String,
        canonicalHandle: String,
        pdsOrigin: String,
        signature: String
    ) throws -> PLCSignedOperation {
        let unsigned = try PLCUnsignedRegularOperation(
            rotationKeys: [rotationDIDKey],
            verificationMethods: ["atproto": signingDIDKey],
            alsoKnownAs: ["at://\(canonicalHandle)"],
            services: [
                PLCATProfile.pdsServiceID: PLCService(
                    type: PLCATProfile.pdsServiceType,
                    endpoint: pdsOrigin
                ),
            ],
            prev: nil
        )
        return try attach(signature: decodeCanonicalSignature(signature), to: .regular(unsigned))
    }

    // MARK: Identity

    /// Derives the DID of a genesis operation:
    /// `did:plc:` + the first 24 characters of
    /// base32(SHA-256(DAG-CBOR(signed operation))).
    ///
    /// Works for a regular genesis operation and for a legacy `create`,
    /// which is hashed in its own format.
    ///
    /// - Throws: ``PetrelPLCError/malformed(_:)`` for a tombstone or an
    ///   operation whose `prev` is not null.
    public static func genesisDID(for operation: PLCSignedOperation) throws -> String {
        guard operation.prev == nil, !operation.isTombstone else {
            throw PetrelPLCError.malformed(
                "PLC genesis must be a regular or legacy create operation with null prev"
            )
        }
        let digest = try Data(SHA256.hash(data: operation.canonicalDAGCBOR))
        return "did:plc:" + String(base32Encode(digest).prefix(24))
    }

    /// Checks that `operation` is the genesis of `expectedDID`: the DID is
    /// the operation's hash, and the operation is signed by one of its own
    /// rotation keys.
    ///
    /// - Throws: ``PetrelPLCError/unauthorized(_:)`` when either check fails.
    public static func verifyGenesis(
        _ operation: PLCSignedOperation,
        expectedDID: String
    ) throws {
        try validateCanonicalDID(expectedDID)
        guard try genesisDID(for: operation) == expectedDID,
              let rotationKeys = operation.rotationKeys else {
            throw PetrelPLCError.unauthorized("PLC genesis DID does not match operation")
        }
        _ = try verify(operation, authorizedRotationKeys: rotationKeys)
    }

    /// Verifies an operation's signature against the rotation keys that were
    /// in force when it was submitted: the keys of the operation named in
    /// `prev`, or the operation's own keys for a genesis operation.
    ///
    /// Signature encoding is enforced strictly, as the specification
    /// requires: base64url without padding and with zero trailing bits,
    /// exactly 64 bytes, low-S on the curve of the key being tried. The key
    /// list is taken as it is: duplicates and unparseable entries occur in
    /// historical operations and simply never match.
    ///
    /// - Returns: The index in `authorizedRotationKeys` of the first key the
    ///   signature verifies against. A lower index is a higher authority.
    /// - Throws: ``PetrelPLCError/unauthorized(_:)`` if no key matches;
    ///   ``PetrelPLCError/malformed(_:)`` if the signature is not canonically
    ///   encoded.
    public static func verify(
        _ operation: PLCSignedOperation,
        authorizedRotationKeys: [String]
    ) throws -> Int {
        try verifyReturningKey(operation, authorizedRotationKeys: authorizedRotationKeys).index
    }

    /// As ``verify(_:authorizedRotationKeys:)``, also reporting the key.
    static func verifyReturningKey(
        _ operation: PLCSignedOperation,
        authorizedRotationKeys: [String]
    ) throws -> (index: Int, key: ATProtoPublicKey) {
        let signature = try decodeCanonicalSignature(operation.signature)
        let signingBytes = try operation.signingDAGCBOR
        for (index, keyText) in authorizedRotationKeys.enumerated() {
            guard let key = try? ATProtoPublicKey(didKey: keyText) else { continue }
            if key.isValidSignature(signature, for: signingBytes, options: .strict) {
                return (index, key)
            }
        }
        throw PetrelPLCError.unauthorized("PLC operation signature is invalid")
    }

    // MARK: Decoding

    /// Decodes one signed operation from JSON, in any of the three formats.
    ///
    /// This is the *read* path and accepts everything the public directory
    /// serves. Structure is strict (exact field sets, as the reference
    /// implementation's schemas are) and so is signature encoding, but field
    /// contents are not held to the write rules: rotation keys may repeat,
    /// `verificationMethods` may be empty or hold any `did:key`. Use
    /// ``validateForSubmission(_:limits:)`` to apply the write rules.
    ///
    /// - Throws: ``PetrelPLCError/malformed(_:)``.
    public static func decodeSignedJSON(_ data: Data) throws -> PLCSignedOperation {
        guard !data.isEmpty, data.count <= maximumOperationJSONBytes else {
            throw PetrelPLCError.malformed("PLC operation JSON exceeds its bound")
        }
        try StrictJSON.validate(data)
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            throw PetrelPLCError.malformed("PLC operation JSON is malformed")
        }
        return try decodeSigned(jsonObject: object)
    }

    /// Decodes an operation from an already-parsed JSON value. The caller is
    /// responsible for having run ``StrictJSON`` over the source bytes.
    static func decodeSigned(jsonObject: Any) throws -> PLCSignedOperation {
        guard let object = jsonObject as? [String: Any],
              let type = object["type"] as? String else {
            throw PetrelPLCError.malformed("PLC operation JSON is malformed")
        }
        let operation: PLCSignedOperation
        switch type {
        case "plc_operation":
            let expected: Set<String> = [
                "type", "rotationKeys", "verificationMethods", "alsoKnownAs",
                "services", "prev", "sig",
            ]
            guard Set(object.keys) == expected,
                  let rotationKeys = object["rotationKeys"] as? [String],
                  let verificationMethods = object["verificationMethods"] as? [String: String],
                  let alsoKnownAs = object["alsoKnownAs"] as? [String],
                  let rawServices = object["services"] as? [String: Any],
                  let signature = object["sig"] as? String else {
                throw PetrelPLCError.malformed("PLC regular operation JSON is malformed")
            }
            let prev: String?
            if object["prev"] is NSNull {
                prev = nil
            } else if let value = object["prev"] as? String {
                prev = value
            } else {
                throw PetrelPLCError.malformed("PLC operation prev is malformed")
            }
            operation = try .regularOperation(.init(
                rotationKeys: rotationKeys,
                verificationMethods: verificationMethods,
                alsoKnownAs: alsoKnownAs,
                services: decodeServices(rawServices),
                prev: prev,
                signature: signature
            ))
        case "plc_tombstone":
            guard Set(object.keys) == ["type", "prev", "sig"],
                  let prev = object["prev"] as? String,
                  let signature = object["sig"] as? String else {
                throw PetrelPLCError.malformed("PLC tombstone JSON is malformed")
            }
            operation = .tombstoneOperation(.init(prev: prev, signature: signature))
        case "create":
            let expected: Set<String> = [
                "type", "signingKey", "recoveryKey", "handle", "service", "prev", "sig",
            ]
            guard Set(object.keys) == expected,
                  let signingKey = object["signingKey"] as? String,
                  let recoveryKey = object["recoveryKey"] as? String,
                  let handle = object["handle"] as? String,
                  let service = object["service"] as? String,
                  object["prev"] is NSNull,
                  let signature = object["sig"] as? String else {
                throw PetrelPLCError.malformed("PLC legacy create operation JSON is malformed")
            }
            operation = .legacyCreateOperation(.init(
                signingKey: signingKey,
                recoveryKey: recoveryKey,
                handle: handle,
                service: service,
                signature: signature
            ))
        default:
            throw PetrelPLCError.malformed("PLC operation type is unsupported")
        }
        // A signature that is not canonical on either curve can never verify,
        // so it is reported as a malformed operation rather than later as a
        // failed verification.
        guard try isCanonicalOnASupportedCurve(decodeCanonicalSignature(operation.signature)) else {
            throw PetrelPLCError.malformed("PLC operation signature is not canonical")
        }
        return operation
    }

    static func decodeServices(_ rawServices: [String: Any]) throws -> [String: PLCService] {
        var services = [String: PLCService]()
        for (name, rawService) in rawServices {
            guard let service = rawService as? [String: Any],
                  Set(service.keys) == ["type", "endpoint"],
                  let serviceType = service["type"] as? String,
                  let endpoint = service["endpoint"] as? String else {
                throw PetrelPLCError.malformed("PLC operation service is malformed")
            }
            services[name] = .init(type: serviceType, endpoint: endpoint)
        }
        return services
    }

    // MARK: Write validation

    /// Applies the rules for *submitting* an operation to a directory.
    ///
    /// A tombstone only needs a canonical `prev`. A regular operation must
    /// satisfy `limits`. A legacy `create` is always refused: the
    /// specification forbids the deprecated format for new identities and
    /// the directory does not accept it.
    ///
    /// - Parameters:
    ///   - operation: The signed operation about to be sent.
    ///   - limits: ``PLCOperationLimits/specification`` by default; pass
    ///     ``PLCOperationLimits/referenceDirectory`` to also apply the
    ///     tighter limits the reference directory server enforces.
    /// - Throws: ``PetrelPLCError/malformed(_:)`` or
    ///   ``PetrelPLCError/invalidIdentifier(_:)``.
    public static func validateForSubmission(
        _ operation: PLCSignedOperation,
        limits: PLCOperationLimits = .specification
    ) throws {
        switch operation {
        case let .regularOperation(value):
            try validate(
                rotationKeys: value.rotationKeys,
                verificationMethods: value.verificationMethods,
                alsoKnownAs: value.alsoKnownAs,
                services: value.services,
                prev: value.prev,
                limits: limits
            )
        case let .tombstoneOperation(value):
            try validatePreviousCID(value.prev)
        case .legacyCreateOperation:
            throw PetrelPLCError.malformed(
                "the legacy create operation format cannot be submitted; build a plc_operation"
            )
        }
        guard try isCanonicalOnASupportedCurve(decodeCanonicalSignature(operation.signature)) else {
            throw PetrelPLCError.malformed("PLC operation signature is not canonical")
        }
        guard try encode(operation, includingSignature: true).count <= limits.maximumDAGCBORBytes else {
            throw PetrelPLCError.malformed(
                "PLC operation exceeds \(limits.maximumDAGCBORBytes) DAG-CBOR bytes"
            )
        }
    }

    static func validate(
        rotationKeys: [String],
        verificationMethods: [String: String],
        alsoKnownAs: [String],
        services: [String: PLCService],
        prev: String?,
        limits: PLCOperationLimits
    ) throws {
        guard !rotationKeys.isEmpty,
              rotationKeys.count <= limits.maximumRotationKeys,
              Set(rotationKeys).count == rotationKeys.count else {
            throw PetrelPLCError.malformed(
                "PLC operation must contain 1...\(limits.maximumRotationKeys) unique rotation keys"
            )
        }
        for key in rotationKeys {
            guard key.utf8.count <= limits.maximumDIDKeyLength,
                  (try? ATProtoPublicKey(didKey: key)) != nil else {
                throw PetrelPLCError.invalidIdentifier(
                    "PLC rotation key must be a P-256 or K-256 did:key"
                )
            }
        }
        guard verificationMethods.count <= limits.maximumVerificationMethods else {
            throw PetrelPLCError.malformed(
                "PLC operation may contain at most \(limits.maximumVerificationMethods) verification methods"
            )
        }
        for (name, value) in verificationMethods {
            try validateMapName(name, maximumLength: limits.maximumIdentifierLength)
            guard value.utf8.count <= limits.maximumDIDKeyLength, isSyntacticDIDKey(value) else {
                throw PetrelPLCError.invalidIdentifier(
                    "PLC verification method must be a did:key with a base58btc multibase value"
                )
            }
        }
        guard alsoKnownAs.count <= limits.maximumAlsoKnownAs else {
            throw PetrelPLCError.malformed(
                "PLC operation may contain at most \(limits.maximumAlsoKnownAs) alsoKnownAs entries"
            )
        }
        if !limits.allowsDuplicateAlsoKnownAs, Set(alsoKnownAs).count != alsoKnownAs.count {
            throw PetrelPLCError.malformed("PLC operation alsoKnownAs entries must be unique")
        }
        for alias in alsoKnownAs {
            try validateWireString(
                alias, field: "alsoKnownAs", maximumLength: limits.maximumAlsoKnownAsLength
            )
        }
        guard services.count <= limits.maximumServices else {
            throw PetrelPLCError.malformed(
                "PLC operation may contain at most \(limits.maximumServices) services"
            )
        }
        for (name, service) in services {
            try validateMapName(name, maximumLength: limits.maximumIdentifierLength)
            try validateWireString(
                service.type, field: "service type", maximumLength: limits.maximumServiceTypeLength
            )
            try validateWireString(
                service.endpoint,
                field: "service endpoint",
                maximumLength: limits.maximumServiceEndpointLength
            )
        }
        if let prev {
            try validatePreviousCID(prev)
        }
    }

    static func validatePreviousCID(_ value: String) throws {
        do {
            let cid = try CID.parse(value)
            guard cid.string == value,
                  cid.codec == .dagCBOR,
                  cid.multihash.algorithm == Multihash.sha256Code,
                  cid.multihash.length == Multihash.sha256Length,
                  cid.multihash.digest.count == Int(Multihash.sha256Length) else {
                throw PetrelPLCError.invalidIdentifier("PLC previous operation CID")
            }
        } catch let error as PetrelPLCError {
            throw error
        } catch {
            throw PetrelPLCError.invalidIdentifier("PLC previous operation CID")
        }
    }

    static func validateCanonicalDID(_ did: String) throws {
        guard did.utf8.count == 32,
              did.hasPrefix("did:plc:"),
              did.dropFirst(8).utf8.allSatisfy({
                  ($0 >= UInt8(ascii: "a") && $0 <= UInt8(ascii: "z")) ||
                      ($0 >= UInt8(ascii: "2") && $0 <= UInt8(ascii: "7"))
              }) else {
            throw PetrelPLCError.invalidIdentifier("canonical did:plc")
        }
    }

    /// The specification's syntax rule for a verification method key:
    /// `did:key:` followed by a base58btc multibase string. No key type is
    /// excluded.
    static func isSyntacticDIDKey(_ value: String) -> Bool {
        let prefix = "did:key:z"
        guard value.hasPrefix(prefix) else { return false }
        let body = value.dropFirst(prefix.count)
        return !body.isEmpty && body.utf8.allSatisfy { base58Alphabet.contains($0) }
    }

    private static let base58Alphabet = Set(
        "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8
    )

    private static func validateMapName(_ value: String, maximumLength: Int) throws {
        guard !value.isEmpty, value.utf8.count <= maximumLength,
              value.utf8.allSatisfy({ $0 >= 0x21 && $0 <= 0x7e }) else {
            throw PetrelPLCError.malformed("PLC operation map key is invalid")
        }
    }

    private static func validateWireString(
        _ value: String, field: String, maximumLength: Int
    ) throws {
        guard !value.isEmpty, value.utf8.count <= maximumLength,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw PetrelPLCError.malformed(
                "PLC operation \(field) is invalid: each entry must be 1...\(maximumLength) UTF-8 bytes"
                    + " with no control characters"
            )
        }
    }

    // MARK: Encoding

    static func encodeSigningBytes(_ operation: PLCUnsignedOperation) throws -> Data {
        switch operation {
        case let .regular(value):
            return try DAGCBOR.encodeValue(regularMap(
                rotationKeys: value.rotationKeys,
                verificationMethods: value.verificationMethods,
                alsoKnownAs: value.alsoKnownAs,
                services: value.services,
                prev: value.prev,
                signature: nil
            ))
        case let .tombstone(value):
            return try DAGCBOR.encodeValue(tombstoneMap(prev: value.prev, signature: nil))
        }
    }

    static func encode(_ operation: PLCSignedOperation, includingSignature: Bool) throws -> Data {
        switch operation {
        case let .regularOperation(value):
            return try DAGCBOR.encodeValue(regularMap(
                rotationKeys: value.rotationKeys,
                verificationMethods: value.verificationMethods,
                alsoKnownAs: value.alsoKnownAs,
                services: value.services,
                prev: value.prev,
                signature: includingSignature ? value.signature : nil
            ))
        case let .tombstoneOperation(value):
            return try DAGCBOR.encodeValue(tombstoneMap(
                prev: value.prev,
                signature: includingSignature ? value.signature : nil
            ))
        case let .legacyCreateOperation(value):
            var entries: [(key: String, value: Any)] = [
                (key: "type", value: "create"),
                (key: "signingKey", value: value.signingKey),
                (key: "recoveryKey", value: value.recoveryKey),
                (key: "handle", value: value.handle),
                (key: "service", value: value.service),
                (key: "prev", value: NSNull()),
            ]
            if includingSignature {
                entries.append((key: "sig", value: value.signature))
            }
            return try DAGCBOR.encodeValue(OrderedCBORMap(entries: entries))
        }
    }

    static func encodeSignedJSON(_ operation: PLCSignedOperation) throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonObject(operation), options: [.sortedKeys])
    }

    static func jsonObject(_ operation: PLCSignedOperation) -> [String: Any] {
        switch operation {
        case let .regularOperation(value):
            return [
                "type": "plc_operation",
                "rotationKeys": value.rotationKeys,
                "verificationMethods": value.verificationMethods,
                "alsoKnownAs": value.alsoKnownAs,
                "services": value.services.mapValues { [
                    "type": $0.type,
                    "endpoint": $0.endpoint,
                ] },
                "prev": value.prev ?? NSNull(),
                "sig": value.signature,
            ]
        case let .tombstoneOperation(value):
            return [
                "type": "plc_tombstone",
                "prev": value.prev,
                "sig": value.signature,
            ]
        case let .legacyCreateOperation(value):
            return [
                "type": "create",
                "signingKey": value.signingKey,
                "recoveryKey": value.recoveryKey,
                "handle": value.handle,
                "service": value.service,
                "prev": NSNull(),
                "sig": value.signature,
            ]
        }
    }

    private static func regularMap(
        rotationKeys: [String],
        verificationMethods: [String: String],
        alsoKnownAs: [String],
        services: [String: PLCService],
        prev: String?,
        signature: String?
    ) -> OrderedCBORMap {
        let serviceValues: [String: Any] = services.mapValues { service in
            OrderedCBORMap(entries: [
                (key: "type", value: service.type),
                (key: "endpoint", value: service.endpoint),
            ])
        }
        var entries: [(key: String, value: Any)] = [
            (key: "type", value: "plc_operation"),
            (key: "rotationKeys", value: rotationKeys),
            (key: "verificationMethods", value: verificationMethods),
            (key: "alsoKnownAs", value: alsoKnownAs),
            (key: "services", value: serviceValues),
            (key: "prev", value: prev ?? NSNull()),
        ]
        if let signature {
            entries.append((key: "sig", value: signature))
        }
        return OrderedCBORMap(entries: entries)
    }

    private static func tombstoneMap(prev: String, signature: String?) -> OrderedCBORMap {
        var entries: [(key: String, value: Any)] = [
            (key: "type", value: "plc_tombstone"),
            (key: "prev", value: prev),
        ]
        if let signature {
            entries.append((key: "sig", value: signature))
        }
        return OrderedCBORMap(entries: entries)
    }

    // MARK: Signatures

    /// Decodes a `sig` field under the specification's encoding rules:
    /// base64url alphabet, no padding, zero trailing bits, exactly 64 bytes.
    static func decodeCanonicalSignature(_ value: String) throws -> Data {
        guard let decoded = Data(plcBase64URL: value),
              decoded.count == ATProtoSignature.compactByteCount,
              decoded.plcBase64URL == value else {
            throw PetrelPLCError.malformed("PLC operation signature encoding is invalid")
        }
        return decoded
    }

    /// Whether 64 signature bytes hold in-range scalars with low-S on P-256
    /// or on K-256. Which curve applies is only known once a key is tried.
    static func isCanonicalOnASupportedCurve(_ signature: Data) -> Bool {
        ATProtoKeyCurve.allCases.contains { ATProtoSignature.isCanonical(signature, curve: $0) }
    }
}

extension Data {
    /// Decodes unpadded base64url. Returns `nil` for padding or any
    /// character outside the URL-safe alphabet.
    init?(plcBase64URL value: String) {
        guard !value.isEmpty,
              !value.contains("="),
              value.utf8.allSatisfy({
                  ($0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z")) ||
                      ($0 >= UInt8(ascii: "a") && $0 <= UInt8(ascii: "z")) ||
                      ($0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9")) ||
                      $0 == UInt8(ascii: "-") || $0 == UInt8(ascii: "_")
              }) else {
            return nil
        }
        var padded = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        padded.append(String(repeating: "=", count: (4 - padded.count % 4) % 4))
        self.init(base64Encoded: padded)
    }

    /// Unpadded base64url.
    var plcBase64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
