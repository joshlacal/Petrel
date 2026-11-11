import Foundation

/// The limits an operation must satisfy to be *written*.
///
/// Operations read from a directory are not held to these: the public
/// directory serves historical operations that predate them. They apply when
/// an operation is built (``PLCUnsignedRegularOperation``), when a signature
/// is attached, and when ``PLCDirectoryClient`` submits.
///
/// Two presets are provided. ``specification`` is the did:plc specification
/// (v0.3.0). ``referenceDirectory`` adds the tighter limits the reference
/// directory server applies to incoming operations; an operation that passes
/// it will not be refused by that server for its shape or size.
///
/// String lengths are counted in UTF-8 bytes. The reference server counts
/// UTF-16 code units, which is never more, so a value within a limit here is
/// within the server's.
public struct PLCOperationLimits: Sendable, Equatable {
    /// Largest signed operation, in DAG-CBOR bytes.
    public var maximumDAGCBORBytes: Int
    /// Most rotation keys. At least one is always required, and rotation
    /// keys must be distinct P-256 or K-256 `did:key` values.
    public var maximumRotationKeys: Int
    /// Most `verificationMethods` entries. Zero entries are allowed.
    public var maximumVerificationMethods: Int
    /// Most `alsoKnownAs` entries.
    public var maximumAlsoKnownAs: Int
    /// Longest `alsoKnownAs` entry.
    public var maximumAlsoKnownAsLength: Int
    /// Whether `alsoKnownAs` may repeat a value.
    public var allowsDuplicateAlsoKnownAs: Bool
    /// Most `services` entries.
    public var maximumServices: Int
    /// Longest verification method id or service id.
    public var maximumIdentifierLength: Int
    /// Longest service `type`.
    public var maximumServiceTypeLength: Int
    /// Longest service `endpoint`.
    public var maximumServiceEndpointLength: Int
    /// Longest `did:key` string, for rotation keys and verification methods.
    public var maximumDIDKeyLength: Int

    /// Creates a custom set of limits, for a directory with rules of its own.
    public init(
        maximumDAGCBORBytes: Int,
        maximumRotationKeys: Int,
        maximumVerificationMethods: Int,
        maximumAlsoKnownAs: Int,
        maximumAlsoKnownAsLength: Int,
        allowsDuplicateAlsoKnownAs: Bool,
        maximumServices: Int,
        maximumIdentifierLength: Int,
        maximumServiceTypeLength: Int,
        maximumServiceEndpointLength: Int,
        maximumDIDKeyLength: Int
    ) {
        self.maximumDAGCBORBytes = maximumDAGCBORBytes
        self.maximumRotationKeys = maximumRotationKeys
        self.maximumVerificationMethods = maximumVerificationMethods
        self.maximumAlsoKnownAs = maximumAlsoKnownAs
        self.maximumAlsoKnownAsLength = maximumAlsoKnownAsLength
        self.allowsDuplicateAlsoKnownAs = allowsDuplicateAlsoKnownAs
        self.maximumServices = maximumServices
        self.maximumIdentifierLength = maximumIdentifierLength
        self.maximumServiceTypeLength = maximumServiceTypeLength
        self.maximumServiceEndpointLength = maximumServiceEndpointLength
        self.maximumDIDKeyLength = maximumDIDKeyLength
    }

    /// The did:plc specification: 7,500 DAG-CBOR bytes, 1–5 distinct
    /// rotation keys, at most 10 verification methods. The specification
    /// does not bound the other collections; the values here only keep a
    /// single entry from being absurd, and the byte limit bounds the whole.
    public static let specification = PLCOperationLimits(
        maximumDAGCBORBytes: 7_500,
        maximumRotationKeys: 5,
        maximumVerificationMethods: 10,
        maximumAlsoKnownAs: 32,
        maximumAlsoKnownAsLength: 2_048,
        allowsDuplicateAlsoKnownAs: true,
        maximumServices: 32,
        maximumIdentifierLength: 128,
        maximumServiceTypeLength: 2_048,
        maximumServiceEndpointLength: 2_048,
        maximumDIDKeyLength: 256
    )

    /// The specification, tightened to what the reference directory server
    /// (`did-method-plc`, `packages/server/src/constraints.ts`) accepts:
    /// 4,000 DAG-CBOR bytes; at most 10 distinct `alsoKnownAs` entries of at
    /// most 258 characters; at most 10 services; ids of at most 32
    /// characters; service types of at most 256 and endpoints of at most 512
    /// characters.
    ///
    /// The server is looser than the specification about rotation keys (it
    /// allows 10 and does not reject duplicates); this preset keeps the
    /// specification's 1–5 distinct keys.
    public static let referenceDirectory = PLCOperationLimits(
        maximumDAGCBORBytes: 4_000,
        maximumRotationKeys: 5,
        maximumVerificationMethods: 10,
        maximumAlsoKnownAs: 10,
        maximumAlsoKnownAsLength: 258,
        allowsDuplicateAlsoKnownAs: false,
        maximumServices: 10,
        maximumIdentifierLength: 32,
        maximumServiceTypeLength: 256,
        maximumServiceEndpointLength: 512,
        maximumDIDKeyLength: 256
    )
}
