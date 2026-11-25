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
                if record_cid.hash_code() == 0x12 && !record_cid.matches_content(&bytes) {
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
            .map_err(|err| RepositoryError::ProofFailure(err.to_string()))?;
        let commit = VerifiedSignedCommit::from_prepared(&installed.commit);
        let statistics = Some(RepositoryStatistics {
            record_count: 0,
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
    pub async fn open_car_source<Src: CARByteSource + ?Sized>(
        source: &mut Src,
        store: Arc<B>,
        verification: OpenVerification,
        expected_did: Option<&Did>,
        limits: RepositoryLimits,
        policy: RepositoryReadPolicy,
        verifies_tree: bool,
    ) -> Result<Self, RepositoryError> {
        let parsed =
            PublicRepositoryCAR::load_from_source(source, store.as_ref(), &limits, &policy).await?;
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
        let commit = CommitCodec::verify_from_store(
            &commit_cid,
            store.as_ref(),
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
            };
            let (stats, entries) = MstValidation::validate_full(
                &commit.data_cid,
                store.as_ref(),
                &mst_options,
                limits.max_record_count,
                true,
            )
            .await?;
            // Enforce record codec validation against policy if required.
            if policy.requires_safe_integers
                || policy.requires_blessed_links_in_records
                || policy.requires_record_type_to_match_collection
            {
                for entry in &entries {
                    let path = RepositoryPath::from_mst_key(&entry.key)?;
                    let bytes = store
                        .get_block(&entry.value)
                        .await?
                        .ok_or_else(|| RepositoryError::MissingBlock(entry.value.clone()))?;
                    RecordCodec::validate_record_bytes(&bytes, Some(path.collection()), &policy)?;
                }
            }
            Some(RepositoryStatistics {
                record_count: stats.record_count,
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
        if let Some(ref rcid) = record_cid {
            let rec_bytes = self
                .store
                .get_block(rcid)
                .await?
                .ok_or_else(|| RepositoryError::MissingBlock(rcid.clone()))?;
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

    /// Streams a CAR v1 archive of the repository to `sink`.
    pub async fn export_car_to_sink<Sink: CARByteSink + ?Sized>(
        &self,
        sink: &Sink,
        order: CARExportOrder,
    ) -> Result<(), RepositoryError> {
        let mut blocks = Vec::new();
        blocks.push(RepositoryBlock::new(
            self.commit.cid.clone(),
            self.commit.signed_commit_bytes.clone(),
        ));

        match order {
            CARExportOrder::Streamable => {
                let mut seen: BTreeSet<Cid> = BTreeSet::new();
                seen.insert(self.commit.cid.clone());
                collect_streamable_blocks(
                    self.commit.data_cid.clone(),
                    self.store.as_ref(),
                    &self.policy,
                    &mut seen,
                    &mut blocks,
                )
                .await?;
            }
            CARExportOrder::BreadthFirst => {
                let mut seen: BTreeSet<Cid> = BTreeSet::new();
                seen.insert(self.commit.cid.clone());
                let mut queue = VecDeque::new();
                queue.push_back(self.commit.data_cid.clone());
                let mut record_cids = Vec::new();

                while let Some(node_cid) = queue.pop_front() {
                    if !seen.insert(node_cid.clone()) {
                        continue;
                    }
                    let bytes = self
                        .store
                        .get_block(&node_cid)
                        .await?
                        .ok_or_else(|| RepositoryError::MissingBlock(node_cid.clone()))?;
                    let view = crate::mst::codec::decode_mst_node(
                        &bytes,
                        MstKeySyntax::StrictAtProto,
                        &self.policy,
                        false,
                    )?;
                    blocks.push(RepositoryBlock::new(node_cid, bytes));
                    if let Some(left) = view.left {
                        queue.push_back(left);
                    }
                    for entry in view.entries {
                        record_cids.push(entry.value);
                        if let Some(right) = entry.tree {
                            queue.push_back(right);
                        }
                    }
                }
                for rcid in record_cids {
                    if !seen.insert(rcid.clone()) {
                        continue;
                    }
                    let bytes = self
                        .store
                        .get_block(&rcid)
                        .await?
                        .ok_or_else(|| RepositoryError::MissingBlock(rcid.clone()))?;
                    blocks.push(RepositoryBlock::new(rcid, bytes));
                }
            }
            CARExportOrder::Stored => {
                let mut all_cids = self.store.all_cids().await?;
                all_cids.retain(|c| c != &self.commit.cid);
                for cid in all_cids {
                    if let Some(bytes) = self.store.get_block(&cid).await? {
                        blocks.push(RepositoryBlock::new(cid, bytes));
                    }
                }
            }
        }

        PublicRepositoryCAR::write_to_sink(std::slice::from_ref(&self.commit.cid), &blocks, sink)
            .await?;
        Ok(())
    }

    fn mst_options(&self) -> MstOptions {
        MstOptions {
            key_syntax: MstKeySyntax::StrictAtProto,
            policy: self.policy,
            require_canonical_prefix: true,
            max_depth: self.limits.max_mst_depth,
            max_node_count: self.limits.max_mst_node_count,
        }
    }
}

fn collect_streamable_blocks<'a, B: BlockStore>(
    node_cid: Cid,
    store: &'a B,
    policy: &'a RepositoryReadPolicy,
    seen: &'a mut BTreeSet<Cid>,
    blocks: &'a mut Vec<RepositoryBlock>,
) -> BoxFuture<'a, Result<(), RepositoryError>> {
    Box::pin(async move {
        let bytes = store
            .get_block(&node_cid)
            .await?
            .ok_or_else(|| RepositoryError::MissingBlock(node_cid.clone()))?;
        let view =
            crate::mst::codec::decode_mst_node(&bytes, MstKeySyntax::StrictAtProto, policy, false)?;
        if seen.insert(node_cid.clone()) {
            blocks.push(RepositoryBlock::new(node_cid, bytes));
        }
        if let Some(left) = view.left {
            collect_streamable_blocks(left, store, policy, seen, blocks).await?;
        }
        for entry in view.entries {
            if seen.insert(entry.value.clone()) {
                let rec_bytes = store
                    .get_block(&entry.value)
                    .await?
                    .ok_or_else(|| RepositoryError::MissingBlock(entry.value.clone()))?;
                blocks.push(RepositoryBlock::new(entry.value, rec_bytes));
            }
            if let Some(right) = entry.tree {
                collect_streamable_blocks(right, store, policy, seen, blocks).await?;
            }
        }
        Ok(())
    })
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
