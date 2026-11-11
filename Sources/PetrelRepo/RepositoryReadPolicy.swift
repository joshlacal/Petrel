import Foundation
import Petrel

/// How strictly repository content is checked when it is *read*.
///
/// The repository and data-model specifications fix the structure of a
/// repository (commit, MST nodes, CAR framing, canonical DAG-CBOR) and that is
/// always enforced. They deliberately leave a few things open, or ask readers
/// to be tolerant of them, and those are what this policy controls:
///
/// | Setting | Specification |
/// |---|---|
/// | ``requiresSafeIntegers`` | Integers are signed 64-bit; staying within 53 bits is "best practice" for writers, not a rule for readers. |
/// | ``requiresBlessedLinksInRecords`` | "Additional CID formats for referencing blobs and records may be added." |
/// | ``requiresBlessedRecordLinksInMST`` | "More flexibility is allowed in processing the leaf links from MST to records, and implementations should retain the exact CID links." |
/// | ``requiresRecordTypeToMatchCollection`` | A repository-level rule of the reference PDS on write, not of the repository format. |
/// | ``rejectsForeignCARBlocks`` | Readers "should also ignore any unnecessary or unlinked blocks." |
/// | ``requiresSingleCARRoot`` | "Additional CIDs may also be present in the roots array, with (for now) undefined meaning." |
///
/// CID policy lives in one place. Structural CIDs (commit, MST node, MST
/// node-to-node links, anything this library writes) are always required to
/// be blessed, by `CID.blessedKind`. The only CIDs a policy may relax are the
/// ones the specification says to tolerate: links inside record data and leaf
/// links to records. A relaxed link is kept byte for byte.
///
/// Use ``dataModel`` to read repositories from the network and ``strict`` in
/// a service that accepts repositories it will go on to host.
public struct RepositoryReadPolicy: Sendable, Equatable {
    /// Reject record integers outside ±(2^53 − 1).
    public var requiresSafeIntegers: Bool
    /// Reject a `cid-link` inside a record unless it is a blessed CID.
    public var requiresBlessedLinksInRecords: Bool
    /// Reject an MST whose leaf links a record through a non-blessed CID.
    public var requiresBlessedRecordLinksInMST: Bool
    /// Require a record's `$type` to equal the collection of its path.
    /// When `false`, `$type` must still be a non-empty string.
    public var requiresRecordTypeToMatchCollection: Bool
    /// Fail a CAR import on a block whose CID is not a blessed DAG-CBOR CID,
    /// instead of skipping it.
    public var rejectsForeignCARBlocks: Bool
    /// Fail a CAR import whose header lists more than one root.
    public var requiresSingleCARRoot: Bool

    /// Creates a policy.
    public init(
        requiresSafeIntegers: Bool,
        requiresBlessedLinksInRecords: Bool,
        requiresBlessedRecordLinksInMST: Bool,
        requiresRecordTypeToMatchCollection: Bool,
        rejectsForeignCARBlocks: Bool,
        requiresSingleCARRoot: Bool
    ) {
        self.requiresSafeIntegers = requiresSafeIntegers
        self.requiresBlessedLinksInRecords = requiresBlessedLinksInRecords
        self.requiresBlessedRecordLinksInMST = requiresBlessedRecordLinksInMST
        self.requiresRecordTypeToMatchCollection = requiresRecordTypeToMatchCollection
        self.rejectsForeignCARBlocks = rejectsForeignCARBlocks
        self.requiresSingleCARRoot = requiresSingleCARRoot
    }

    /// Enforce only what the specifications require of a reader.
    public static let dataModel = RepositoryReadPolicy(
        requiresSafeIntegers: false,
        requiresBlessedLinksInRecords: false,
        requiresBlessedRecordLinksInMST: false,
        requiresRecordTypeToMatchCollection: false,
        rejectsForeignCARBlocks: false,
        requiresSingleCARRoot: false
    )

    /// Additionally enforce everything the reference PDS enforces on write.
    public static let strict = RepositoryReadPolicy(
        requiresSafeIntegers: true,
        requiresBlessedLinksInRecords: true,
        requiresBlessedRecordLinksInMST: true,
        requiresRecordTypeToMatchCollection: true,
        rejectsForeignCARBlocks: true,
        requiresSingleCARRoot: true
    )

    /// The MST options this policy implies for repository paths.
    public var mstOptions: RepositoryMSTOptions {
        RepositoryMSTOptions(
            keySyntax: .repositoryPath,
            allowsNonBlessedLeafLinks: !requiresBlessedRecordLinksInMST
        )
    }
}
