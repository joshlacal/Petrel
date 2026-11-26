use petrel_core::Cid;
use thiserror::Error;

/// Error returned when validating or applying [`crate::RepositoryLimits`].
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum LimitError {
    #[error("invalid repository limit configuration: {0}")]
    InvalidConfiguration(String),
    #[error("limit exceeded for {kind:?}: observed {observed}, limit {limit}")]
    Exceeded {
        kind: LimitKind,
        observed: usize,
        limit: usize,
    },
}

/// Specific ceiling enforced during repository import, mutation, or export.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum LimitKind {
    BlockCount,
    RecordCount,
    ImportCarBytes,
    RelevantBlockBytes,
    WritesPerCommit,
    SingleBlockBytes,
    MstNodeCount,
    MstDepth,
    CarRootCount,
}

/// Domain validation error for repository identifiers, paths, and writes.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum DomainError {
    #[error("invalid DID: {0}")]
    InvalidDid(String),
    #[error("invalid collection NSID: {0}")]
    InvalidCollection(String),
    #[error("collection exceeds maximum byte length ({len} > {max})")]
    CollectionTooLong { len: usize, max: usize },
    #[error("invalid record key: {0}")]
    InvalidRecordKey(String),
    #[error("record key exceeds maximum byte length ({len} > {max})")]
    RecordKeyTooLong { len: usize, max: usize },
    #[error("invalid repository path: {0}")]
    InvalidPath(String),
    #[error("repository path exceeds maximum MST key byte length ({len} > {max})")]
    PathTooLong { len: usize, max: usize },
    #[error("invalid TID: {0}")]
    InvalidTid(String),
    #[error("invalid CID: {0}")]
    InvalidCid(String),
    #[error("duplicate write target in batch: {0}")]
    DuplicateWriteTarget(String),
    #[error("empty write batch")]
    EmptyWriteBatch,
    #[error("TID overflow")]
    TidOverflow,
    #[error("TID is further in the future than permitted")]
    TidTooFarInFuture,
    #[error("revision is not strictly increasing: previous={previous}, next={next}")]
    NonIncreasingRevision { previous: String, next: String },
}

/// Error returned by strict CAR v1 parsing and writing.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum CARError {
    #[error("truncated CAR data")]
    Truncated,
    #[error("non-canonical varint encoding")]
    NonCanonicalVarint,
    #[error("varint exceeds supported bounds")]
    VarintOverflow,
    #[error("invalid CAR header: {0}")]
    InvalidHeader(String),
    #[error("unsupported CAR version {0} (expected 1)")]
    UnsupportedVersion(i64),
    #[error("CAR archive has no roots")]
    MissingRoots,
    #[error("CAR archive has {count} roots, but policy requires a single root")]
    MultipleRoots { count: usize },
    #[error("CAR root count {count} exceeds limit {limit}")]
    TooManyRoots { count: usize, limit: usize },
    #[error("invalid CID in CAR stream: {0}")]
    InvalidCid(String),
    #[error("zero-length CAR block frame")]
    ZeroLengthBlock,
    #[error("CAR frame size {len} exceeds maximum block limit {limit}")]
    BlockTooLarge { len: usize, limit: usize },
    #[error("CAR CID length exceeds frame payload")]
    CidOverrunsBlock,
    #[error("CAR block CID hash mismatch for {0}")]
    HashMismatch(String),
    #[error("conflicting duplicate block content for CID {0}")]
    ConflictingDuplicateBlock(String),
    #[error("foreign non-dag-cbor block rejected by policy: {0}")]
    ForeignBlockRejected(String),
    #[error("block store failed while reading CAR: {0}")]
    BlockStore(#[from] BlockStoreError),
    #[error("limit exceeded: {0}")]
    Limit(#[from] LimitError),
    #[error("I/O error: {0}")]
    Io(String),
}

/// Error returned by [`crate::CARReader`] / [`crate::CARRepository`], preserving
/// the diagnostic surface of `CARReader.swift` and `MSTTraverser.swift`.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum CARReaderError {
    #[error("truncated CAR data")]
    Truncated,
    #[error("non-canonical or overflowed varint")]
    InvalidVarint,
    #[error("invalid CAR header: {0}")]
    InvalidHeader(String),
    #[error("unsupported CAR version {0}")]
    UnsupportedVersion(i64),
    #[error("CAR header contains no roots")]
    MissingRoots,
    #[error("invalid CID bytes: {0}")]
    InvalidCid(String),
    #[error("unsupported multihash algorithm 0x{0:x} (expected sha2-256)")]
    UnsupportedMultihash(u64),
    #[error("CID digest mismatch for {0}")]
    HashMismatch(String),
    #[error("conflicting duplicate block for CID {0}")]
    ConflictingDuplicateBlock(String),
    #[error("missing block {0}")]
    MissingBlock(String),
    #[error("invalid MST node block: {0}")]
    InvalidMstNode(String),
    #[error("MST cycle detected at {0}")]
    MstCycle(String),
    #[error("MST depth limit exceeded")]
    MstDepthLimitExceeded,
    #[error("MST key ordering invalid: {0}")]
    InvalidMstOrder(String),
    #[error("limit exceeded: {0}")]
    Limit(#[from] LimitError),
    #[error("I/O error: {0}")]
    Io(String),
}

/// Error returned by [`crate::BlockStore`] implementations.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum BlockStoreError {
    #[error("block not found: {0}")]
    MissingBlock(Cid),
    #[error("block CID verification failed for {0}")]
    HashMismatch(Cid),
    #[error("block already exists with different bytes for {0}")]
    ConflictingBlock(Cid),
    #[error("block exceeds maximum permitted byte size ({len} > {max})")]
    BlockTooLarge { len: usize, max: usize },
    #[error("total block count {count} exceeds limit {limit}")]
    TooManyBlocks { count: usize, limit: usize },
    #[error("corrupt block store file: {0}")]
    CorruptStore(String),
    #[error("I/O error: {0}")]
    Io(String),
}

/// Error returned by strict JSON record parsing or writing.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum RecordJsonError {
    #[error("invalid UTF-8 in JSON input")]
    InvalidUtf8,
    #[error("invalid JSON syntax: {0}")]
    Syntax(String),
    #[error("duplicate key {0:?} in JSON object")]
    DuplicateKey(String),
    #[error("top-level record JSON must be an object")]
    TopLevelNotObject,
    #[error("floating-point numbers are disallowed in AT Protocol records")]
    FloatingPointDisallowed,
    #[error("integer out of range: {0}")]
    IntegerOutOfRange(String),
    #[error("invalid special AT Protocol JSON wrapper: {0}")]
    InvalidSpecialWrapper(String),
    #[error("nesting depth exceeds maximum {0}")]
    DepthExceeded(usize),
    #[error("JSON serialization failed: {0}")]
    SerializationFailed(String),
}

/// Error returned by record DAG-CBOR validation and encoding.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum RecordCodecError {
    #[error("invalid record DAG-CBOR: {0}")]
    InvalidDagCbor(String),
    #[error("record must encode as a DAG-CBOR map")]
    TopLevelNotMap,
    #[error("floating-point numbers are disallowed in AT Protocol records")]
    FloatingPointDisallowed,
    #[error("integer {0} outside AT Protocol safe range (±9007199254740991)")]
    UnsafeInteger(i64),
    #[error("unblessed CID link rejected by policy: {0}")]
    UnblessedLink(String),
    #[error("invalid blob object: {0}")]
    InvalidBlob(String),
    #[error("invalid $type field: {0}")]
    InvalidTypeField(String),
    #[error("record $type ({actual}) does not match collection ({expected})")]
    TypeCollectionMismatch { expected: String, actual: String },
    #[error("record depth exceeds maximum ({max})")]
    DepthExceeded { max: usize },
    #[error("record JSON error: {0}")]
    Json(#[from] RecordJsonError),
    #[error("record size {len} exceeds maximum block limit {limit}")]
    BlockTooLarge { len: usize, limit: usize },
}

/// Error returned by MST operations, codec, proof verification, or validation.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum MstError {
    #[error("invalid MST node encoding: {0}")]
    InvalidNode(String),
    #[error("non-canonical MST encoding or structure: {0}")]
    NonCanonical(String),
    #[error("invalid MST key: {0}")]
    InvalidKey(String),
    #[error("unblessed CID link in MST: {0}")]
    UnblessedLink(String),
    #[error("key already exists: {0}")]
    DuplicateKey(String),
    #[error("key does not exist: {0}")]
    MissingKey(String),
    #[error("missing block in store: {0}")]
    MissingBlock(Cid),
    #[error("MST cycle detected at {0}")]
    CycleDetected(Cid),
    #[error("MST depth {depth} exceeds limit {limit}")]
    DepthExceeded { depth: usize, limit: usize },
    #[error("MST node count {count} exceeds limit {limit}")]
    NodeCountExceeded { count: usize, limit: usize },
    #[error("MST record count {count} exceeds limit {limit}")]
    RecordCountExceeded { count: usize, limit: usize },
    #[error("MST block size {len} exceeds maximum block limit {limit}")]
    BlockTooLarge { len: usize, limit: usize },
    #[error("key {key:?} height {actual} does not match expected tree height {expected}")]
    KeyHeightMismatch {
        key: String,
        actual: usize,
        expected: usize,
    },
    #[error("key ordering violation: previous={previous:?}, next={next:?}")]
    KeyOrderViolation { previous: String, next: String },
    #[error("proof verification failed: {0}")]
    InvalidProof(String),
    #[error("block store error: {0}")]
    BlockStore(#[from] BlockStoreError),
    #[error("domain error: {0}")]
    Domain(#[from] DomainError),
}

/// Error returned by commit encoding, decoding, signing, or verification.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum CommitError {
    #[error("invalid commit CBOR: {0}")]
    InvalidCbor(String),
    #[error("unsupported commit version {0}")]
    UnsupportedVersion(i64),
    #[error("invalid commit field {field}: {reason}")]
    InvalidField { field: &'static str, reason: String },
    #[error("commit DID mismatch: expected {expected}, actual {actual}")]
    DidMismatch { expected: String, actual: String },
    #[error("unblessed CID link in commit field {0}")]
    UnblessedLink(&'static str),
    #[error("invalid signature encoding: {0}")]
    InvalidSignatureEncoding(String),
    #[error("high-S signature rejected")]
    HighSSignature,
    #[error("signature verification failed")]
    InvalidSignature,
    #[error("invalid public key: {0}")]
    InvalidPublicKey(String),
    #[error("signing failed: {0}")]
    SigningFailed(String),
    #[error("key resolution failed for {did}: {reason}")]
    KeyResolutionFailed { did: String, reason: String },
    #[error("signed commit byte size {len} exceeds ceiling {limit}")]
    CommitTooLarge { len: usize, limit: usize },
    #[error("missing commit block {0}")]
    MissingBlock(Cid),
    #[error("block store error: {0}")]
    BlockStore(#[from] BlockStoreError),
}

/// Error returned by [`crate::CommitDiff`] verification.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum CommitDiffError {
    #[error("invalid commit diff operation: {0}")]
    InvalidOperation(String),
    #[error("missing block {0}")]
    MissingBlock(Cid),
    #[error("MST error while verifying diff: {0}")]
    Mst(#[from] MstError),
    #[error("commit error while verifying diff: {0}")]
    Commit(#[from] CommitError),
    #[error("computed previous data CID {computed} does not match expected {expected:?}")]
    PreviousDataMismatch {
        computed: Cid,
        expected: Option<Cid>,
    },
    #[error("computed resulting data CID {computed} does not match commit data CID {expected}")]
    ResultDataMismatch { computed: Cid, expected: Cid },
    #[error("block store error: {0}")]
    BlockStore(#[from] BlockStoreError),
    #[error("domain error: {0}")]
    Domain(#[from] DomainError),
}

/// Error returned by [`crate::RepositoryEngine::apply`].
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum EngineError {
    #[error("repository state DID mismatch: expected {expected}, actual {actual}")]
    DidMismatch { expected: String, actual: String },
    #[error("signing key generation must be positive (got {0})")]
    InvalidSigningKeyGeneration(u64),
    #[error("head commit mismatch: expected {expected:?}, state has {actual:?}")]
    CommitMismatch {
        expected: Option<Cid>,
        actual: Option<Cid>,
    },
    #[error("domain error: {0}")]
    Domain(#[from] DomainError),
    #[error("limit error: {0}")]
    Limit(#[from] LimitError),
    #[error("record codec error: {0}")]
    Record(#[from] RecordCodecError),
    #[error("MST error: {0}")]
    Mst(#[from] MstError),
    #[error("commit error: {0}")]
    Commit(#[from] CommitError),
    #[error("block store error: {0}")]
    BlockStore(#[from] BlockStoreError),
    #[error("relevant commit block bytes ({total}) exceed budget ({budget})")]
    RelevantBlocksExceedBudget { total: usize, budget: usize },
}

/// Error returned by genesis creation or persistence stores.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum GenesisStoreError {
    #[error("genesis already installed for DID {0}")]
    AlreadyExists(String),
    #[error("corrupt persisted genesis payload: {0}")]
    CorruptPayload(String),
    #[error("genesis commit verification failed: {0}")]
    VerificationFailed(String),
    #[error("domain error: {0}")]
    Domain(#[from] DomainError),
    #[error("limit error: {0}")]
    Limit(#[from] LimitError),
    #[error("commit error: {0}")]
    Commit(#[from] CommitError),
    #[error("block store error: {0}")]
    BlockStore(#[from] BlockStoreError),
    #[error("I/O error: {0}")]
    Io(String),
}

/// Top-level error returned by the [`crate::Repository`] facade.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum RepositoryError {
    #[error("CAR error: {0}")]
    Car(#[from] CARError),
    #[error("block store error: {0}")]
    BlockStore(#[from] BlockStoreError),
    #[error("commit error: {0}")]
    Commit(#[from] CommitError),
    #[error("MST error: {0}")]
    Mst(#[from] MstError),
    #[error("record error: {0}")]
    Record(#[from] RecordCodecError),
    #[error("diff error: {0}")]
    Diff(#[from] CommitDiffError),
    #[error("engine error: {0}")]
    Engine(#[from] EngineError),
    #[error("domain error: {0}")]
    Domain(#[from] DomainError),
    #[error("limit error: {0}")]
    Limit(#[from] LimitError),
    #[error("record not found at {0}")]
    RecordNotFound(String),
    #[error("unsupported non-blessed record CID at {path}: {cid}")]
    UnsupportedRecordCid { path: String, cid: Cid },
    #[error("repository did not verify full tree structure")]
    TreeNotVerified,
    #[error("missing block {0}")]
    MissingBlock(Cid),
    #[error("proof failure: {0}")]
    ProofFailure(String),
}
