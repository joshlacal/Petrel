use std::collections::{BTreeSet, VecDeque};
use std::sync::Arc;

use petrel::rt::BoxFuture;
use petrel_core::{Cid, Did, Value};

use crate::block_store::{BlockSource, BlockStore, InMemoryBlockStore, RepositoryBlock};
use crate::car::{CARByteSink, CARByteSource, DataCARByteSink, PublicRepositoryCAR};
use crate::commit::{CommitCodec, PreparedSignedCommit, VerifiedSignedCommit};
use crate::crypto::{
    CommitSigner, FixedSigningKey, RepositorySigningKeyResolver, SigningPublicKey,
};
use crate::diff::CommitOperation;
use crate::engine::RepositoryEngine;
use crate::error::RepositoryError;
use crate::genesis::GenesisCodec;
use crate::limits::RepositoryLimits;
use crate::mst::{
    MstKeySyntax, MstOptions, MstProof, MstValidation, MstWalkOptions, MstWalker, RepositoryMst,
};
use crate::record::{Record, RecordCodec};
use crate::types::{
    RepositoryPath, RepositoryReadPolicy, RepositoryState, RepositoryTid, WriteBatch, WriteOp,
};

/// Key-verification strategy used when opening or verifying a [`Repository`].
#[derive(Clone)]
pub enum OpenVerification {
    SigningKey(SigningPublicKey),
    Resolver(Arc<dyn RepositorySigningKeyResolver>),
}

impl std::fmt::Debug for OpenVerification {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::SigningKey(k) => f.debug_tuple("SigningKey").field(k).finish(),
            Self::Resolver(_) => f.debug_tuple("Resolver").field(&"<resolver>").finish(),
        }
    }
}

impl OpenVerification {
    #[allow(clippy::arc_with_non_send_sync)]
    fn as_resolver(&self) -> Arc<dyn RepositorySigningKeyResolver> {
        match self {
            Self::SigningKey(k) => Arc::new(FixedSigningKey::from_public_key(k.clone())),
            Self::Resolver(r) => Arc::clone(r),
        }
    }
}

/// Traversal order used when exporting a repository to CAR v1.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum CARExportOrder {
    /// Commit -> MST breadth-first -> record blocks in path order (`streamable`).
    #[default]
    Streamable,
    /// Commit -> MST breadth-first followed by referenced records.
    BreadthFirst,
    /// Every block stored in the underlying block store (`stored`).
    Stored,
}

/// Aggregate tree statistics populated when `verifies_tree == true`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepositoryStatistics {
    pub record_count: usize,
    pub unverifiable_record_count: usize,
    pub mst_node_count: usize,
    pub tree_depth: usize,
    pub total_mst_block_bytes: usize,
    pub total_record_block_bytes: usize,
}

/// Lightweight pointer to a record stored in a [`Repository`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RecordReference {
    pub path: RepositoryPath,
    pub cid: Cid,
}

/// Decoded repository record entry (`record(collection:recordKey:)`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RecordEntry {
    pub path: RepositoryPath,
    pub cid: Cid,
    pub bytes: Vec<u8>,
    pub policy: RepositoryReadPolicy,
}

impl RecordEntry {
    pub fn collection(&self) -> &str {
        self.path.collection_str()
    }

    pub fn record_key(&self) -> &str {
        self.path.record_key_str()
    }

    pub fn record(&self) -> Result<Record, RepositoryError> {
        Ok(RecordCodec::validate_record_bytes(
            &self.bytes,
            Some(self.path.collection()),
            &self.policy,
        )?)
    }

    pub fn json_bytes(&self) -> Result<Vec<u8>, RepositoryError> {
        let record = self.record()?;
        Ok(record
            .to_json_bytes()
            .map_err(crate::error::RecordCodecError::from)?)
    }

    pub fn json_string(&self) -> Result<String, RepositoryError> {
        let bytes = self.json_bytes()?;
        String::from_utf8(bytes)
            .map_err(|err| crate::error::RecordCodecError::InvalidDagCbor(err.to_string()).into())
    }
}

/// Inclusion or exclusion proof CAR bundle (`recordProof`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RecordProofBundle {
    pub commit_cid: Cid,
    pub path: RepositoryPath,
    pub record_cid: Option<Cid>,
    pub blocks: Vec<RepositoryBlock>,
}

impl RecordProofBundle {
    pub fn car(&self) -> Result<Vec<u8>, RepositoryError> {
        Ok(PublicRepositoryCAR::write(
            std::slice::from_ref(&self.commit_cid),
            &self.blocks,
        )?)
    }
}

/// Output of verifying a proof CAR bundle (`verifyRecordProof`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedRecordProof {
    pub commit: VerifiedSignedCommit,
    pub path: RepositoryPath,
    pub record: Option<RecordEntry>,
}

/// Result returned by [`Repository::commit`].
#[derive(Debug, Clone)]
pub struct CommitBatchResult<B: BlockStore + 'static = InMemoryBlockStore> {
    pub repository: Repository<B>,
    pub commit: PreparedSignedCommit,
    pub previous_data_cid: Option<Cid>,
    pub operations: Vec<CommitOperation>,
    pub new_blocks: Vec<RepositoryBlock>,
    pub proof_blocks: Vec<RepositoryBlock>,
    diff_car_bytes: Vec<u8>,
}

impl<B: BlockStore + 'static> CommitBatchResult<B> {
    pub fn diff_car(&self) -> &[u8] {
        &self.diff_car_bytes
    }
}

/// High-level AT Protocol repository handle (`Repository`).
#[derive(Debug, Clone)]
pub struct Repository<B: BlockStore + 'static = InMemoryBlockStore> {
    commit: VerifiedSignedCommit,
    store: Arc<B>,
    limits: RepositoryLimits,
    policy: RepositoryReadPolicy,
    verifies_tree: bool,
    statistics: Option<RepositoryStatistics>,
    signing_key_generation: u64,
}

impl Repository<InMemoryBlockStore> {
    /// Extracts the `#atproto` signing key from DID document JSON bytes.
    pub fn signing_key_from_did_document(
        did_document_json: &[u8],
        did: &Did,
    ) -> Result<SigningPublicKey, RepositoryError> {
        Ok(SigningPublicKey::from_did_document_json(
            did_document_json,
            did,
        )?)
    }

    /// Creates a new signed empty repository in a fresh [`InMemoryBlockStore`].
    pub async fn create(did: Did, signer: &dyn CommitSigner) -> Result<Self, RepositoryError> {
        Self::create_in_store(
            did,
            signer,
            Arc::new(InMemoryBlockStore::new()),
            RepositoryLimits::standard(),
            RepositoryReadPolicy::strict(),
        )
        .await
    }

    /// Opens and verifies a repository from in-memory CAR v1 bytes.
    pub async fn open_car(
        car_bytes: &[u8],
        verification: OpenVerification,
        expected_did: Option<&Did>,
    ) -> Result<Self, RepositoryError> {
        Self::open_car_with_options(
            car_bytes,
            verification,
            expected_did,
            RepositoryLimits::network_scale(),
            RepositoryReadPolicy::strict(),
            true,
        )
        .await
    }

    pub async fn open_car_with_options(
        car_bytes: &[u8],
        verification: OpenVerification,
        expected_did: Option<&Did>,
        limits: RepositoryLimits,
        policy: RepositoryReadPolicy,
        verifies_tree: bool,
    ) -> Result<Self, RepositoryError> {
        let store = Arc::new(InMemoryBlockStore::with_limits(
            limits.max_block_count,
            limits.max_single_block_bytes,
        ));
        let parsed = PublicRepositoryCAR::load(car_bytes, store.as_ref(), &limits, &policy).await?;
        Self::open_store(
            parsed.root_cid,
            store,
            verification,
            expected_did,
            limits,
            policy,
            verifies_tree,
        )
        .await
    }

    /// Verifies an inclusion or exclusion proof CAR for `(collection, record_key)`.
    pub async fn verify_record_proof(
        car_bytes: &[u8],
        did: &Did,
        collection: &str,
        record_key: &str,
        verification: OpenVerification,
    ) -> Result<VerifiedRecordProof, RepositoryError> {
        Self::verify_record_proof_with_options(
            car_bytes,
            did,
            collection,
            record_key,
            verification,
            RepositoryLimits::network_scale(),
            RepositoryReadPolicy::strict(),
        )
        .await
    }

    pub async fn verify_record_proof_with_options(
        car_bytes: &[u8],
        did: &Did,
        collection: &str,
        record_key: &str,
        verification: OpenVerification,
        limits: RepositoryLimits,
        policy: RepositoryReadPolicy,
    ) -> Result<VerifiedRecordProof, RepositoryError> {
        let path = RepositoryPath::new(collection, record_key)?;
        let (parsed, store) =
            PublicRepositoryCAR::import_bytes(car_bytes, &limits, &policy).await?;
        let resolver = verification.as_resolver();
        let commit = CommitCodec::verify_from_store(
            &parsed.root_cid,
            &store,
            Some(did),
            resolver.as_ref(),
            &policy,
        )
        .await?;

        let mst_options = MstOptions {
            key_syntax: MstKeySyntax::StrictAtProto,
            policy,
            require_canonical_prefix: true,
            max_depth: limits.max_mst_depth,
            max_node_count: limits.max_mst_node_count,
            max_single_block_bytes: limits.max_single_block_bytes,
        };
        let proven =
            MstProof::verify_membership(&commit.data_cid, path.mst_key(), &store, &mst_options)
                .await?;

        let record = match proven {
            Some(record_cid) => {
                let bytes = store
                    .get_block(&record_cid)
                    .await?
                    .ok_or(RepositoryError::MissingBlock(record_cid.clone()))?;
                if record_cid.blessed_kind() != Some(petrel_core::cid::BlessedKind::DagCbor)
                    || !record_cid.matches_content(&bytes)
                {
                    return Err(RepositoryError::ProofFailure(format!(
                        "proven record CID hash mismatch for {record_cid}"
                    )));
                }
                let _ =
                    RecordCodec::validate_record_bytes(&bytes, Some(path.collection()), &policy)?;
                Some(RecordEntry {
                    path: path.clone(),
                    cid: record_cid,
                    bytes,
                    policy,
                })
            }
            None => None,
        };

        Ok(VerifiedRecordProof {
            commit,
            path,
            record,
        })
    }
}

impl<B: BlockStore + 'static> Repository<B> {
    /// Creates an empty signed repository inside an arbitrary [`BlockStore`].
    pub async fn create_in_store(
        did: Did,
        signer: &dyn CommitSigner,
        store: Arc<B>,
        limits: RepositoryLimits,
        policy: RepositoryReadPolicy,
    ) -> Result<Self, RepositoryError> {
        let rev = RepositoryTid::now(0)?;
        let installed = GenesisCodec::create(&did, signer, rev, 1, store.as_ref(), &limits)
            .await
            .map_err(|err| match err {
                crate::error::GenesisStoreError::Limit(e) => RepositoryError::Limit(e),
                crate::error::GenesisStoreError::Commit(e) => RepositoryError::Commit(e),
                crate::error::GenesisStoreError::BlockStore(e) => RepositoryError::BlockStore(e),
                crate::error::GenesisStoreError::Domain(e) => RepositoryError::Domain(e),
                other => RepositoryError::ProofFailure(other.to_string()),
            })?;
        let commit = VerifiedSignedCommit::from_prepared(&installed.commit);
        let statistics = Some(RepositoryStatistics {
            record_count: 0,
            unverifiable_record_count: 0,
            mst_node_count: 1,
            tree_depth: 1,
            total_mst_block_bytes: installed.empty_mst_bytes.len(),
            total_record_block_bytes: 0,
        });
        Ok(Self {
            commit,
            store,
            limits,
            policy,
            verifies_tree: true,
            statistics,
            signing_key_generation: 1,
        })
    }

    /// Streams a CAR source into `store` and opens + verifies the resulting repository.
    ///
    /// If streaming or repository verification fails, any blocks newly inserted during
    /// this import are deleted (and flushed) so `store` is left unmutated.
    pub async fn open_car_source<Src: CARByteSource + ?Sized>(
        source: &mut Src,
        store: Arc<B>,
        verification: OpenVerification,
        expected_did: Option<&Did>,
        limits: RepositoryLimits,
        policy: RepositoryReadPolicy,
        verifies_tree: bool,
    ) -> Result<Self, RepositoryError> {
        let tracker = RollbackTrackingStore::new(Arc::clone(&store));
        let parsed =
            match PublicRepositoryCAR::load_from_source(source, &tracker, &limits, &policy).await {
                Ok(parsed) => parsed,
                Err(err) => {
                    tracker.rollback().await;
                    return Err(err.into());
                }
            };
        match Self::open_store(
            parsed.root_cid,
            store,
            verification,
            expected_did,
            limits,
            policy,
            verifies_tree,
        )
        .await
        {
            Ok(repo) => Ok(repo),
            Err(err) => {
                tracker.rollback().await;
                Err(err)
            }
        }
    }

    /// Opens and verifies a repository already loaded into `store`.
    pub async fn open_store(
        commit_cid: Cid,
        store: Arc<B>,
        verification: OpenVerification,
        expected_did: Option<&Did>,
        limits: RepositoryLimits,
        policy: RepositoryReadPolicy,
        verifies_tree: bool,
    ) -> Result<Self, RepositoryError> {
        limits.validate()?;
        let resolver = verification.as_resolver();
        let commit_bytes = store
            .get_block(&commit_cid)
            .await?
            .ok_or_else(|| crate::error::CommitError::MissingBlock(commit_cid.clone()))?;
        if commit_bytes.len() > limits.max_single_block_bytes {
            return Err(RepositoryError::Limit(crate::error::LimitError::Exceeded {
                kind: crate::error::LimitKind::SingleBlockBytes,
                observed: commit_bytes.len(),
                limit: limits.max_single_block_bytes,
            }));
        }
        let commit = CommitCodec::verify(
            &commit_bytes,
            Some(&commit_cid),
            expected_did,
            resolver.as_ref(),
            &policy,
        )
        .await?;

        let statistics = if verifies_tree {
            let mst_options = MstOptions {
                key_syntax: MstKeySyntax::StrictAtProto,
                policy,
                require_canonical_prefix: true,
                max_depth: limits.max_mst_depth,
                max_node_count: limits.max_mst_node_count,
                max_single_block_bytes: limits.max_single_block_bytes,
            };
            let (stats, entries) = MstValidation::validate_full(
                &commit.data_cid,
                store.as_ref(),
                &mst_options,
                limits.max_record_count,
                true,
            )
            .await?;
            let total_reachable_blocks = 1_usize.saturating_add(stats.unique_block_count);
            if total_reachable_blocks > limits.max_block_count {
                return Err(RepositoryError::Limit(crate::error::LimitError::Exceeded {
                    kind: crate::error::LimitKind::BlockCount,
                    observed: total_reachable_blocks,
                    limit: limits.max_block_count,
                }));
            }
            // Always validate every verifiable DAG-CBOR record payload under the selected read
            // policy so invalid DAG-CBOR or non-map records fail at open time even under
            // `data_model()`, while preserving unsupported/non-blessed leaf CIDs under `data_model()`.
            for entry in &entries {
                if entry.value.blessed_kind() != Some(petrel_core::cid::BlessedKind::DagCbor) {
                    if policy.requires_blessed_record_links_in_mst {
                        return Err(RepositoryError::Mst(crate::error::MstError::UnblessedLink(
                            entry.value.to_string(),
                        )));
                    }
                    continue;
                }
                let path = RepositoryPath::from_mst_key(&entry.key)?;
                let bytes = store
                    .get_block(&entry.value)
                    .await?
                    .ok_or_else(|| RepositoryError::MissingBlock(entry.value.clone()))?;
                RecordCodec::validate_record_bytes(&bytes, Some(path.collection()), &policy)?;
            }
            Some(RepositoryStatistics {
                record_count: stats.record_count,
                unverifiable_record_count: stats.unverifiable_record_count,
                mst_node_count: stats.node_count,
                tree_depth: stats.tree_depth,
                total_mst_block_bytes: stats.total_mst_block_bytes,
                total_record_block_bytes: stats.total_record_block_bytes,
            })
        } else {
            None
        };

        Ok(Self {
            commit,
            store,
            limits,
            policy,
            verifies_tree,
            statistics,
            signing_key_generation: 1,
        })
    }

    pub fn did(&self) -> &Did {
        &self.commit.did
    }

    pub fn revision(&self) -> &RepositoryTid {
        &self.commit.rev
    }

    pub fn commit(&self) -> &VerifiedSignedCommit {
        &self.commit
    }

    pub fn store(&self) -> &Arc<B> {
        &self.store
    }

    pub fn statistics(&self) -> Option<&RepositoryStatistics> {
        self.statistics.as_ref()
    }

    pub fn state(&self) -> RepositoryState {
        RepositoryState::with_head(
            self.commit.did.clone(),
            self.commit.cid.clone(),
            self.commit.data_cid.clone(),
            self.commit.rev.clone(),
            self.signing_key_generation,
        )
    }

    /// Re-verifies commit signature and (optionally) full MST + records.
    pub async fn verify(&self, verification: OpenVerification) -> Result<(), RepositoryError> {
        let resolver = verification.as_resolver();
        let _ = CommitCodec::verify(
            &self.commit.signed_commit_bytes,
            Some(&self.commit.cid),
            Some(&self.commit.did),
            resolver.as_ref(),
            &self.policy,
        )
        .await?;
        if self.verifies_tree {
            let mst_options = self.mst_options();
            let (_stats, _) = MstValidation::validate_full(
                &self.commit.data_cid,
                self.store.as_ref(),
                &mst_options,
                self.limits.max_record_count,
                true,
            )
            .await?;
        }
        Ok(())
    }

    /// Looks up a single record CID in the MST without reading its payload.
    pub async fn record_cid(
        &self,
        collection: &str,
        record_key: &str,
    ) -> Result<Option<Cid>, RepositoryError> {
        let path = RepositoryPath::new(collection, record_key)?;
        let mut mst = RepositoryMst::open_with_options(
            self.commit.data_cid.clone(),
            Arc::clone(&self.store) as Arc<dyn BlockSource>,
            self.mst_options(),
        );
        Ok(mst.get(path.mst_key()).await?)
    }

    /// Reads and validates a single record from the repository.
    pub async fn record(
        &self,
        collection: &str,
        record_key: &str,
    ) -> Result<Option<RecordEntry>, RepositoryError> {
        let path = RepositoryPath::new(collection, record_key)?;
        let mut mst = RepositoryMst::open_with_options(
            self.commit.data_cid.clone(),
            Arc::clone(&self.store) as Arc<dyn BlockSource>,
            self.mst_options(),
        );
        let Some(cid) = mst.get(path.mst_key()).await? else {
            return Ok(None);
        };
        if cid.blessed_kind() != Some(petrel_core::cid::BlessedKind::DagCbor) {
            return Err(RepositoryError::UnsupportedRecordCid {
                path: path.mst_key().to_owned(),
                cid,
            });
        }
        let bytes = self
            .store
            .get_block(&cid)
            .await?
            .ok_or_else(|| RepositoryError::MissingBlock(cid.clone()))?;
        let _ = RecordCodec::validate_record_bytes(&bytes, Some(path.collection()), &self.policy)?;
        Ok(Some(RecordEntry {
            path,
            cid,
            bytes,
            policy: self.policy,
        }))
    }

    /// Iterates every record reference (or those within `collection`) in key order.
    pub async fn record_references(
        &self,
        collection: Option<&str>,
    ) -> Result<Vec<RecordReference>, RepositoryError> {
        let prefix = collection.map(|c| format!("{c}/"));
        let walker = MstWalker::new(MstWalkOptions {
            mst_options: self.mst_options(),
            max_record_count: self.limits.max_record_count,
            verify_block_hashes: true,
        });
        let source: Arc<dyn BlockSource> = Arc::clone(&self.store) as Arc<dyn BlockSource>;
        let (entries, _) = walker
            .collect_entries(&self.commit.data_cid, &source)
            .await?;
        let mut refs = Vec::new();
        for entry in entries {
            if let Some(p) = &prefix
                && !entry.key.starts_with(p)
            {
                continue;
            }
            let path = RepositoryPath::from_mst_key(&entry.key)?;
            refs.push(RecordReference {
                path,
                cid: entry.value,
            });
        }
        Ok(refs)
    }

    /// Lists distinct collection NSIDs present in the repository in sorted order.
    pub async fn collections(&self) -> Result<Vec<String>, RepositoryError> {
        let refs = self.record_references(None).await?;
        let set: BTreeSet<String> = refs
            .into_iter()
            .map(|r| r.path.collection_str().to_owned())
            .collect();
        Ok(set.into_iter().collect())
    }

    /// Loads and validates all records (optionally filtered by `collection`).
    pub async fn records(
        &self,
        collection: Option<&str>,
    ) -> Result<Vec<RecordEntry>, RepositoryError> {
        let refs = self.record_references(collection).await?;
        let mut out = Vec::with_capacity(refs.len());
        for item in refs {
            if item.cid.blessed_kind() != Some(petrel_core::cid::BlessedKind::DagCbor) {
                return Err(RepositoryError::UnsupportedRecordCid {
                    path: item.path.mst_key().to_owned(),
                    cid: item.cid,
                });
            }
            let bytes = self
                .store
                .get_block(&item.cid)
                .await?
                .ok_or_else(|| RepositoryError::MissingBlock(item.cid.clone()))?;
            let _ = RecordCodec::validate_record_bytes(
                &bytes,
                Some(item.path.collection()),
                &self.policy,
            )?;
            out.push(RecordEntry {
                path: item.path,
                cid: item.cid,
                bytes,
                policy: self.policy,
            });
        }
        Ok(out)
    }

    /// Invokes `visitor` for each record (optionally filtered by `collection`).
    pub async fn for_each_record<'a, F>(
        &self,
        collection: Option<&str>,
        mut visitor: F,
    ) -> Result<(), RepositoryError>
    where
        F: FnMut(RecordEntry) -> BoxFuture<'a, Result<(), RepositoryError>>,
    {
        for entry in self.records(collection).await? {
            visitor(entry).await?;
        }
        Ok(())
    }

    /// Builds an inclusion or exclusion [`RecordProofBundle`] for `(collection, record_key)`.
    pub async fn record_proof(
        &self,
        collection: &str,
        record_key: &str,
    ) -> Result<RecordProofBundle, RepositoryError> {
        let path = RepositoryPath::new(collection, record_key)?;
        let mst_options = self.mst_options();
        let proof_map = MstProof::build_proof_blocks(
            &self.commit.data_cid,
            path.mst_key(),
            self.store.as_ref(),
            &mst_options,
        )
        .await?;

        let mut mst = RepositoryMst::open_with_options(
            self.commit.data_cid.clone(),
            Arc::clone(&self.store) as Arc<dyn BlockSource>,
            mst_options,
        );
        let record_cid = mst.get(path.mst_key()).await?;

        let mut blocks =
            Vec::with_capacity(1 + proof_map.len() + usize::from(record_cid.is_some()));
        blocks.push(RepositoryBlock::new(
            self.commit.cid.clone(),
            self.commit.signed_commit_bytes.clone(),
        ));
        for (cid, bytes) in proof_map {
            blocks.push(RepositoryBlock::new(cid, bytes));
        }
        if let Some(ref rcid) = record_cid
            && let Some(rec_bytes) =
                load_export_record_block(rcid, self.store.as_ref(), &self.policy).await?
        {
            blocks.push(RepositoryBlock::new(rcid.clone(), rec_bytes));
        }

        Ok(RecordProofBundle {
            commit_cid: self.commit.cid.clone(),
            path,
            record_cid,
            blocks,
        })
    }

    /// Commits a batch of create/update/delete writes onto the current head.
    pub async fn commit_writes(
        &self,
        writes: WriteBatch,
        signer: &dyn CommitSigner,
    ) -> Result<CommitBatchResult<B>, RepositoryError> {
        let rev = RepositoryTid::next_after(
            Some(&self.commit.rev),
            crate::types::current_unix_micros(),
            0,
        )?;
        self.commit_writes_with_rev(writes, rev, signer).await
    }

    /// Commits `writes` with an explicit revision TID.
    pub async fn commit_writes_with_rev(
        &self,
        writes: WriteBatch,
        rev: RepositoryTid,
        signer: &dyn CommitSigner,
    ) -> Result<CommitBatchResult<B>, RepositoryError> {
        let state = self.state();
        let res = RepositoryEngine::apply(
            &state,
            &writes,
            Some(&self.commit.cid),
            rev,
            signer,
            Arc::clone(&self.store),
            &self.limits,
            &self.policy,
        )
        .await?;
        let diff_car_bytes = res.diff_car()?;
        let verified_commit = VerifiedSignedCommit::from_prepared(&res.commit);

        let statistics = if self.verifies_tree {
            let mst_options = self.mst_options();
            let (mst_stats, _) = MstValidation::validate_full(
                &verified_commit.data_cid,
                self.store.as_ref(),
                &mst_options,
                self.limits.max_record_count,
                true,
            )
            .await?;
            Some(RepositoryStatistics {
                record_count: mst_stats.record_count,
                unverifiable_record_count: mst_stats.unverifiable_record_count,
                mst_node_count: mst_stats.node_count,
                tree_depth: mst_stats.tree_depth,
                total_mst_block_bytes: mst_stats.total_mst_block_bytes,
                total_record_block_bytes: mst_stats.total_record_block_bytes,
            })
        } else {
            None
        };

        let next_repository = Self {
            commit: verified_commit,
            store: Arc::clone(&self.store),
            limits: self.limits,
            policy: self.policy,
            verifies_tree: self.verifies_tree,
            statistics,
            signing_key_generation: self.signing_key_generation,
        };

        Ok(CommitBatchResult {
            repository: next_repository,
            commit: res.commit,
            previous_data_cid: res.previous_data_cid,
            operations: res.operations,
            new_blocks: res.new_blocks,
            proof_blocks: res.proof_blocks,
            diff_car_bytes,
        })
    }

    /// Exports the repository as CAR v1 bytes in `.streamable` order.
    pub async fn export_car(&self) -> Result<Vec<u8>, RepositoryError> {
        let sink = DataCARByteSink::new();
        self.export_car_to_sink(&sink, CARExportOrder::Streamable)
            .await?;
        Ok(sink.into_bytes().await)
    }

    /// Streams a CAR v1 archive of the repository to `sink` without buffering block payloads.
    pub async fn export_car_to_sink<Sink: CARByteSink + ?Sized>(
        &self,
        sink: &Sink,
        order: CARExportOrder,
    ) -> Result<(), RepositoryError> {
        let header = crate::car::writer::encode_header(std::slice::from_ref(&self.commit.cid))?;
        sink.write_bytes(&header).await?;

        let mut seen: BTreeSet<Cid> = BTreeSet::new();
        stream_frame_if_unseen(
            self.commit.cid.clone(),
            &self.commit.signed_commit_bytes,
            &mut seen,
            sink,
        )
        .await?;

        match order {
            CARExportOrder::Streamable => {
                self.export_streamable_to_sink(sink, &mut seen).await?;
            }
            CARExportOrder::BreadthFirst => {
                self.export_breadth_first_to_sink(sink, &mut seen).await?;
            }
            CARExportOrder::Stored => {
                let mut all_cids = self.store.all_cids().await?;
                all_cids.retain(|c| c != &self.commit.cid);
                for cid in all_cids {
                    if !seen.contains(&cid)
                        && let Some(bytes) = self.store.get_block(&cid).await?
                    {
                        stream_frame_if_unseen(cid, &bytes, &mut seen, sink).await?;
                    }
                }
            }
        }

        sink.finish().await?;
        Ok(())
    }

    async fn export_streamable_to_sink<Sink: CARByteSink + ?Sized>(
        &self,
        sink: &Sink,
        seen: &mut BTreeSet<Cid>,
    ) -> Result<(), RepositoryError> {
        enum StreamItem {
            Node { cid: Cid, depth: usize },
            Record(Cid),
        }

        let mut stack = vec![StreamItem::Node {
            cid: self.commit.data_cid.clone(),
            depth: 0,
        }];
        let mut mst_node_count = 0_usize;
        let mut record_count = 0_usize;

        while let Some(item) = stack.pop() {
            match item {
                StreamItem::Node {
                    cid: node_cid,
                    depth,
                } => {
                    let Some((bytes, view)) = self
                        .visit_export_mst_node(&node_cid, depth, &mut mst_node_count, seen)
                        .await?
                    else {
                        continue;
                    };
                    let frame = crate::car::writer::encode_frame(&node_cid, &bytes)?;
                    sink.write_bytes(&frame).await?;
                    drop(bytes);

                    for entry in view.entries.into_iter().rev() {
                        if let Some(right) = entry.tree {
                            stack.push(StreamItem::Node {
                                cid: right,
                                depth: depth + 1,
                            });
                        }
                        stack.push(StreamItem::Record(entry.value));
                    }
                    if let Some(left) = view.left {
                        stack.push(StreamItem::Node {
                            cid: left,
                            depth: depth + 1,
                        });
                    }
                }
                StreamItem::Record(rcid) => {
                    record_count = record_count.saturating_add(1);
                    if record_count > self.limits.max_record_count {
                        return Err(RepositoryError::Mst(
                            crate::error::MstError::RecordCountExceeded {
                                count: record_count,
                                limit: self.limits.max_record_count,
                            },
                        ));
                    }
                    self.stream_export_record_if_unseen(rcid, seen, sink)
                        .await?;
                }
            }
        }
        Ok(())
    }

    async fn export_breadth_first_to_sink<Sink: CARByteSink + ?Sized>(
        &self,
        sink: &Sink,
        seen: &mut BTreeSet<Cid>,
    ) -> Result<(), RepositoryError> {
        let mut queue = VecDeque::new();
        queue.push_back((self.commit.data_cid.clone(), 0_usize));
        let mut record_cids = Vec::new();
        let mut mst_node_count = 0_usize;

        while let Some((node_cid, depth)) = queue.pop_front() {
            let Some((bytes, view)) = self
                .visit_export_mst_node(&node_cid, depth, &mut mst_node_count, seen)
                .await?
            else {
                continue;
            };
            let frame = crate::car::writer::encode_frame(&node_cid, &bytes)?;
            sink.write_bytes(&frame).await?;
            if let Some(left) = view.left {
                queue.push_back((left, depth + 1));
            }
            for entry in view.entries {
                if record_cids.len() >= self.limits.max_record_count {
                    return Err(RepositoryError::Mst(
                        crate::error::MstError::RecordCountExceeded {
                            count: record_cids.len() + 1,
                            limit: self.limits.max_record_count,
                        },
                    ));
                }
                record_cids.push(entry.value);
                if let Some(right) = entry.tree {
                    queue.push_back((right, depth + 1));
                }
            }
        }
        for rcid in record_cids {
            self.stream_export_record_if_unseen(rcid, seen, sink)
                .await?;
        }
        Ok(())
    }

    async fn visit_export_mst_node(
        &self,
        node_cid: &Cid,
        depth: usize,
        mst_node_count: &mut usize,
        seen: &mut BTreeSet<Cid>,
    ) -> Result<Option<(Vec<u8>, crate::mst::codec::MstNodeView)>, RepositoryError> {
        if depth > self.limits.max_mst_depth {
            return Err(RepositoryError::Mst(
                crate::error::MstError::DepthExceeded {
                    depth,
                    limit: self.limits.max_mst_depth,
                },
            ));
        }
        if !seen.insert(node_cid.clone()) {
            return Ok(None);
        }
        *mst_node_count = mst_node_count.saturating_add(1);
        if *mst_node_count > self.limits.max_mst_node_count {
            return Err(RepositoryError::Mst(
                crate::error::MstError::NodeCountExceeded {
                    count: *mst_node_count,
                    limit: self.limits.max_mst_node_count,
                },
            ));
        }
        let bytes = self
            .store
            .get_block(node_cid)
            .await?
            .ok_or_else(|| RepositoryError::MissingBlock(node_cid.clone()))?;
        if bytes.len() > self.limits.max_single_block_bytes {
            return Err(RepositoryError::Mst(
                crate::error::MstError::BlockTooLarge {
                    len: bytes.len(),
                    limit: self.limits.max_single_block_bytes,
                },
            ));
        }
        let view = crate::mst::codec::decode_mst_node(
            &bytes,
            MstKeySyntax::StrictAtProto,
            &self.policy,
            false,
        )?;
        Ok(Some((bytes, view)))
    }

    async fn stream_export_record_if_unseen<Sink: CARByteSink + ?Sized>(
        &self,
        rcid: Cid,
        seen: &mut BTreeSet<Cid>,
        sink: &Sink,
    ) -> Result<(), RepositoryError> {
        if !seen.contains(&rcid)
            && let Some(rec_bytes) =
                load_export_record_block(&rcid, self.store.as_ref(), &self.policy).await?
        {
            if rec_bytes.len() > self.limits.max_single_block_bytes {
                return Err(RepositoryError::Mst(
                    crate::error::MstError::BlockTooLarge {
                        len: rec_bytes.len(),
                        limit: self.limits.max_single_block_bytes,
                    },
                ));
            }
            stream_frame_if_unseen(rcid, &rec_bytes, seen, sink).await?;
        }
        Ok(())
    }

    fn mst_options(&self) -> MstOptions {
        MstOptions {
            key_syntax: MstKeySyntax::StrictAtProto,
            policy: self.policy,
            require_canonical_prefix: true,
            max_depth: self.limits.max_mst_depth,
            max_node_count: self.limits.max_mst_node_count,
            max_single_block_bytes: self.limits.max_single_block_bytes,
        }
    }
}

async fn stream_frame_if_unseen<Sink: CARByteSink + ?Sized>(
    cid: Cid,
    payload: &[u8],
    seen: &mut BTreeSet<Cid>,
    sink: &Sink,
) -> Result<(), RepositoryError> {
    if seen.insert(cid.clone()) {
        let frame = crate::car::writer::encode_frame(&cid, payload)?;
        sink.write_bytes(&frame).await?;
    }
    Ok(())
}

async fn load_export_record_block<B: BlockStore + ?Sized>(
    cid: &Cid,
    store: &B,
    policy: &RepositoryReadPolicy,
) -> Result<Option<Vec<u8>>, RepositoryError> {
    if cid.blessed_kind() != Some(petrel_core::cid::BlessedKind::DagCbor)
        && !policy.requires_blessed_record_links_in_mst
    {
        return Ok(store.get_block(cid).await?);
    }
    let bytes = store
        .get_block(cid)
        .await?
        .ok_or_else(|| RepositoryError::MissingBlock(cid.clone()))?;
    Ok(Some(bytes))
}

/// Convenience helper constructing [`WriteOp::Create`] from a validated [`Record`] or [`Value`].
pub fn create_op(
    collection: &str,
    record_key: &str,
    value: &Value,
) -> Result<WriteOp, RepositoryError> {
    let path = RepositoryPath::new(collection, record_key)?;
    let prepared = RecordCodec::prepare_for_write(
        value,
        path.collection(),
        &RepositoryLimits::standard(),
        &RepositoryReadPolicy::strict(),
    )?;
    Ok(WriteOp::Create {
        path,
        record_cbor: prepared.bytes,
    })
}

/// Convenience helper constructing [`WriteOp::Update`] from a [`Value`].
pub fn update_op(
    collection: &str,
    record_key: &str,
    value: &Value,
) -> Result<WriteOp, RepositoryError> {
    let path = RepositoryPath::new(collection, record_key)?;
    let prepared = RecordCodec::prepare_for_write(
        value,
        path.collection(),
        &RepositoryLimits::standard(),
        &RepositoryReadPolicy::strict(),
    )?;
    Ok(WriteOp::Update {
        path,
        record_cbor: prepared.bytes,
    })
}

#[derive(Debug)]
struct RollbackTrackingStore<B: ?Sized> {
    inner: Arc<B>,
    inserted: std::sync::Mutex<Vec<Cid>>,
}

impl<B: ?Sized> RollbackTrackingStore<B> {
    fn new(inner: Arc<B>) -> Self {
        Self {
            inner,
            inserted: std::sync::Mutex::new(Vec::new()),
        }
    }
}

impl<B: BlockStore + ?Sized> RollbackTrackingStore<B> {
    async fn rollback(self) {
        let cids = match self.inserted.lock() {
            Ok(mut guard) => std::mem::take(&mut *guard),
            Err(poisoned) => std::mem::take(&mut *poisoned.into_inner()),
        };
        if cids.is_empty() {
            return;
        }
        for cid in cids.into_iter().rev() {
            let _ = self.inner.delete_block(&cid).await;
        }
        let _ = self.inner.flush().await;
    }
}

impl<B: BlockStore + ?Sized> BlockSource for RollbackTrackingStore<B> {
    fn get_block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, crate::error::BlockStoreError>> {
        self.inner.get_block(cid)
    }

    fn contains_block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<bool, crate::error::BlockStoreError>> {
        self.inner.contains_block(cid)
    }
}

impl<B: BlockStore + ?Sized> BlockStore for RollbackTrackingStore<B> {
    fn put_block<'a>(
        &'a self,
        cid: &'a Cid,
        bytes: &'a [u8],
    ) -> BoxFuture<'a, Result<(), crate::error::BlockStoreError>> {
        Box::pin(async move {
            let already_present = self.inner.contains_block(cid).await?;
            self.inner.put_block(cid, bytes).await?;
            if !already_present {
                match self.inserted.lock() {
                    Ok(mut guard) => guard.push(cid.clone()),
                    Err(poisoned) => poisoned.into_inner().push(cid.clone()),
                }
            }
            Ok(())
        })
    }

    fn delete_block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<bool, crate::error::BlockStoreError>> {
        self.inner.delete_block(cid)
    }

    fn flush(&self) -> BoxFuture<'_, Result<(), crate::error::BlockStoreError>> {
        self.inner.flush()
    }

    fn len(&self) -> BoxFuture<'_, Result<usize, crate::error::BlockStoreError>> {
        self.inner.len()
    }

    fn total_bytes(&self) -> BoxFuture<'_, Result<usize, crate::error::BlockStoreError>> {
        self.inner.total_bytes()
    }

    fn all_cids(&self) -> BoxFuture<'_, Result<Vec<Cid>, crate::error::BlockStoreError>> {
        self.inner.all_cids()
    }
}
