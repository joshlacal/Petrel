use std::collections::HashMap;
use std::sync::Arc;

use async_lock::RwLock;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::{Cid, Did};

use crate::block_store::{BlockStore, RepositoryBlock};
use crate::commit::{CommitCodec, CommitDescriptor, PreparedSignedCommit};
use crate::crypto::{CommitSigner, FixedSigningKey, SigningPublicKey};
use crate::error::{GenesisStoreError, LimitError, LimitKind};
use crate::limits::RepositoryLimits;
use crate::types::{RepositoryReadPolicy, RepositoryState, RepositoryTid};

/// Canonical DAG-CBOR bytes of the AT Protocol empty MST root node
/// (`{"e": [], "l": null}`): `[0xa2, 0x61, 0x65, 0x80, 0x61, 0x6c, 0xf6]`.
pub const CANONICAL_EMPTY_MST_BYTES: &[u8] = &[0xa2, 0x61, 0x65, 0x80, 0x61, 0x6c, 0xf6];

/// Canonical `bafyrei...` CID of [`CANONICAL_EMPTY_MST_BYTES`].
pub const CANONICAL_EMPTY_MST_CID: &str =
    "bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm";

/// Result of creating an empty genesis commit (`PublicRepositoryGenesisInstallation`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GenesisInstallation {
    pub did: Did,
    pub state: RepositoryState,
    pub commit: PreparedSignedCommit,
    pub empty_mst_cid: Cid,
    pub empty_mst_bytes: Vec<u8>,
}

/// Persisted genesis record stored in a [`GenesisStore`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PersistedGenesis {
    pub did: Did,
    pub commit_cid: Cid,
    pub commit_bytes: Vec<u8>,
    pub empty_mst_cid: Cid,
    pub empty_mst_bytes: Vec<u8>,
    pub rev: RepositoryTid,
    pub signing_key_generation: u64,
}

/// Persistence interface for genesis repository snapshots (`PublicRepositoryGenesisStore`).
pub trait GenesisStore: MaybeSend + MaybeSync + std::fmt::Debug {
    fn load<'a>(
        &'a self,
        did: &'a Did,
    ) -> BoxFuture<'a, Result<Option<PersistedGenesis>, GenesisStoreError>>;

    fn save<'a>(
        &'a self,
        genesis: &'a PersistedGenesis,
    ) -> BoxFuture<'a, Result<(), GenesisStoreError>>;
}

/// Thread-safe in-memory [`GenesisStore`].
#[derive(Debug, Clone, Default)]
pub struct InMemoryGenesisStore {
    entries: Arc<RwLock<HashMap<Did, PersistedGenesis>>>,
}

impl InMemoryGenesisStore {
    pub fn new() -> Self {
        Self::default()
    }
}

impl GenesisStore for InMemoryGenesisStore {
    fn load<'a>(
        &'a self,
        did: &'a Did,
    ) -> BoxFuture<'a, Result<Option<PersistedGenesis>, GenesisStoreError>> {
        Box::pin(async move { Ok(self.entries.read().await.get(did).cloned()) })
    }

    fn save<'a>(
        &'a self,
        genesis: &'a PersistedGenesis,
    ) -> BoxFuture<'a, Result<(), GenesisStoreError>> {
        Box::pin(async move {
            self.entries
                .write()
                .await
                .insert(genesis.did.clone(), genesis.clone());
            Ok(())
        })
    }
}

/// Creates and verifies canonical empty AT Protocol repositories (`PublicRepositoryGenesisCodec`).
#[derive(Debug, Clone, Copy, Default)]
pub struct GenesisCodec;

impl GenesisCodec {
    /// Returns the canonical empty MST CID.
    pub fn canonical_empty_mst_cid() -> Cid {
        Cid::for_dag_cbor(CANONICAL_EMPTY_MST_BYTES)
    }

    /// Creates a new signed empty genesis commit, writes the empty MST node and
    /// signed commit to `block_store`, and returns the resulting [`GenesisInstallation`].
    pub async fn create<B: BlockStore + ?Sized>(
        did: &Did,
        signer: &dyn CommitSigner,
        rev: RepositoryTid,
        signing_key_generation: u64,
        block_store: &B,
        limits: &RepositoryLimits,
    ) -> Result<GenesisInstallation, GenesisStoreError> {
        limits.validate()?;
        if signing_key_generation == 0 {
            return Err(GenesisStoreError::VerificationFailed(
                "signing_key_generation must be positive".into(),
            ));
        }
        let empty_mst_cid = Self::canonical_empty_mst_cid();
        let empty_mst_bytes = CANONICAL_EMPTY_MST_BYTES.to_vec();
        debug_assert_eq!(Cid::for_dag_cbor(&empty_mst_bytes), empty_mst_cid);

        if limits.max_block_count < 2 {
            return Err(GenesisStoreError::Limit(LimitError::Exceeded {
                kind: LimitKind::BlockCount,
                observed: 2,
                limit: limits.max_block_count,
            }));
        }
        if limits.max_mst_node_count < 1 {
            return Err(GenesisStoreError::Limit(LimitError::Exceeded {
                kind: LimitKind::MstNodeCount,
                observed: 1,
                limit: limits.max_mst_node_count,
            }));
        }
        if empty_mst_bytes.len() > limits.max_single_block_bytes {
            return Err(GenesisStoreError::Limit(LimitError::Exceeded {
                kind: LimitKind::SingleBlockBytes,
                observed: empty_mst_bytes.len(),
                limit: limits.max_single_block_bytes,
            }));
        }

        let descriptor = CommitDescriptor {
            did: did.clone(),
            rev: rev.clone(),
            data_cid: empty_mst_cid.clone(),
            prev_cid: None,
        };
        let estimated_commit_bytes =
            CommitCodec::preflight_signed_commit_byte_count(&descriptor, limits)?;
        let estimated_genesis_bytes = empty_mst_bytes.len().saturating_add(estimated_commit_bytes);
        if estimated_genesis_bytes > limits.max_relevant_block_bytes {
            return Err(GenesisStoreError::Limit(LimitError::Exceeded {
                kind: LimitKind::RelevantBlockBytes,
                observed: estimated_genesis_bytes,
                limit: limits.max_relevant_block_bytes,
            }));
        }

        let commit = CommitCodec::prepare(&descriptor, signer, limits).await?;
        let actual_genesis_bytes = empty_mst_bytes
            .len()
            .saturating_add(commit.signed_commit_bytes.len());
        if actual_genesis_bytes > limits.max_relevant_block_bytes {
            return Err(GenesisStoreError::Limit(LimitError::Exceeded {
                kind: LimitKind::RelevantBlockBytes,
                observed: actual_genesis_bytes,
                limit: limits.max_relevant_block_bytes,
            }));
        }

        block_store
            .put_blocks(&[
                RepositoryBlock::new(empty_mst_cid.clone(), empty_mst_bytes.clone()),
                RepositoryBlock::new(commit.cid.clone(), commit.signed_commit_bytes.clone()),
            ])
            .await?;

        let state = RepositoryState::with_head(
            did.clone(),
            commit.cid.clone(),
            empty_mst_cid.clone(),
            rev,
            signing_key_generation,
        );

        Ok(GenesisInstallation {
            did: did.clone(),
            state,
            commit,
            empty_mst_cid,
            empty_mst_bytes,
        })
    }

    /// Verifies that a genesis commit matches `expected_public_key`, encodes the
    /// canonical empty MST root, and passes strict v3 commit rules.
    pub async fn verify_persisted(
        genesis: &PersistedGenesis,
        public_key: &SigningPublicKey,
    ) -> Result<RepositoryState, GenesisStoreError> {
        let expected_empty_cid = Self::canonical_empty_mst_cid();
        if genesis.empty_mst_cid != expected_empty_cid
            || genesis.empty_mst_bytes.as_slice() != CANONICAL_EMPTY_MST_BYTES
        {
            return Err(GenesisStoreError::VerificationFailed(
                "genesis empty MST does not match canonical empty node".into(),
            ));
        }
        let resolver = FixedSigningKey::from_public_key(public_key.clone());
        let verified = CommitCodec::verify(
            &genesis.commit_bytes,
            Some(&genesis.commit_cid),
            Some(&genesis.did),
            &resolver,
            &RepositoryReadPolicy::strict(),
        )
        .await?;
        if verified.data_cid != expected_empty_cid {
            return Err(GenesisStoreError::VerificationFailed(format!(
                "genesis data CID {} does not match canonical empty MST {expected_empty_cid}",
                verified.data_cid
            )));
        }
        if verified.prev_cid.is_some() {
            return Err(GenesisStoreError::VerificationFailed(
                "genesis commit cannot have a prev link".into(),
            ));
        }
        Ok(RepositoryState::with_head(
            verified.did,
            verified.cid,
            verified.data_cid,
            verified.rev,
            genesis.signing_key_generation,
        ))
    }
}
