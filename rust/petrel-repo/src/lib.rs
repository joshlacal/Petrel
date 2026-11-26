//! AT Protocol public repository stack for Petrel.
//!
//! Mirrors `Sources/PetrelRepo`, `Sources/PetrelCore/CARReader.swift`, and
//! `Sources/Petrel/Core/CAR` across native and `wasm32-unknown-unknown`
//! targets:
//!
//! - CAR v1 reading and writing ([`car`])
//! - In-memory and native file-backed block stores ([`block_store`])
//! - AT Protocol Merkle Search Trees, proofs, walkers, and validation ([`mst`])
//! - Repository v3 commits, P-256 / secp256k1 signing & verification, and
//!   `IdentityResolver` key resolution seams ([`crypto`], [`commit`])
//! - Genesis initialization, diff verification, write engine, limits, and
//!   high-level [`Repository`] facade ([`genesis`], [`diff`], [`engine`],
//!   [`repository`], [`record`], [`reference`])

pub mod block_store;
pub mod car;
pub mod commit;
pub mod crypto;
pub mod diff;
pub mod engine;
pub mod error;
pub mod footprint;
pub mod genesis;
pub mod limits;
pub mod mst;
pub mod record;
pub mod reference;
pub mod repository;
pub mod types;

#[cfg(not(target_arch = "wasm32"))]
pub use block_store::FileBlockStore;
pub use block_store::{BlockMap, BlockSource, BlockStore, InMemoryBlockStore, RepositoryBlock};
pub use car::{
    CARArchive, CARByteSink, CARByteSource, CARHeader, CARReader, CARRepository, DataCARByteSink,
    DataCARByteSource, ParsedCAR, PublicRepositoryCAR,
};
#[cfg(not(target_arch = "wasm32"))]
pub use car::{FileCARByteSink, FileCARByteSource};
pub use commit::{
    CommitCodec, CommitDescriptor, LegacyCommitV2, PreparedSignedCommit,
    StructurallyValidatedSignedCommit, VerifiedSignedCommit,
};
pub use crypto::{
    CommitSigner, CommitVerifier, FixedSigningKey, IdentityResolverKeyAdapter, K256Keypair,
    P256Keypair, RepositorySigningKeyResolver, Signature, SigningAlgorithm, SigningPublicKey,
};
pub use diff::{CommitDiff, CommitOperation, VerifiedCommitDiff};
pub use engine::{PreparedMutation, RepositoryEngine, RepositoryMutationResult};
pub use error::{
    BlockStoreError, CARError, CARReaderError, CommitDiffError, CommitError, DomainError,
    EngineError, GenesisStoreError, LimitError, LimitKind, MstError, RecordCodecError,
    RecordJsonError, RepositoryError,
};
pub use footprint::RepositoryFootprint;
pub use genesis::{
    CANONICAL_EMPTY_MST_BYTES, CANONICAL_EMPTY_MST_CID, GenesisCodec, GenesisInstallation,
    GenesisStore, PersistedGenesis,
};
pub use limits::RepositoryLimits;
pub use mst::{
    MstDiff, MstDiffEntry, MstEntry, MstKeySyntax, MstOptions, MstProof, MstValidation,
    MstWalkOptions, MstWalkProgress, MstWalker, RepositoryMst,
};
pub use record::{PreparedRecord, Record, RecordCodec, RecordValue, TypedBlobReference};
pub use repository::{
    CARExportOrder, CommitBatchResult, OpenVerification, RecordEntry, RecordProofBundle,
    RecordReference, Repository, RepositoryStatistics, VerifiedRecordProof,
};
pub use types::{
    RepositoryPath, RepositoryReadPolicy, RepositoryState, RepositoryTid, WriteBatch, WriteOp,
};
