//! Cryptographic AT Protocol CAR, signed commit, and MST inclusion proof verification for
//! `com.atproto.sync.getRecord` responses, backed by `petrel-repo` and `petrel-crypto`.

use std::future::Future;
use std::pin::Pin;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::task::{Context, Poll};

use petrel::identity::{SigningCurve, SigningKey};
use petrel::rt::BoxFuture;
use petrel_core::{Cid, Did, Nsid, RecordKey};
use petrel_crypto::{ATProtoKeyCurve, PublicKey};
use petrel_repo::{
    BlockSource, BlockStoreError, CARError, CommitCodec, FixedSigningKey, InMemoryBlockStore,
    LimitError, LimitKind, MstKeySyntax, MstOptions, MstProof, PublicRepositoryCAR, RecordCodec,
    RecordCodecError, RecordEntry, RepositoryError, RepositoryLimits, RepositoryPath,
    RepositoryReadPolicy, SigningPublicKey, VerifiedRecordProof,
};

use crate::resolver::{LexiconRepoProofVerifier, LexiconResolutionError, VerifiedLexiconRecord};

const DEFAULT_MAX_CAR_BYTES: usize = 1_048_576;
const DEFAULT_MAX_BLOCKS: usize = 512;
const DEFAULT_MAX_BLOCK_BYTES: usize = 1_048_576;
const DEFAULT_MAX_MST_NODES: usize = 256;
const DEFAULT_MAX_MST_ENTRIES_PER_NODE: usize = 2_048;

/// Default [`LexiconRepoProofVerifier`] validating `com.atproto.sync.getRecord` CAR responses
/// against the authority DID's `#atproto` signing key (P-256 / secp256k1 via `petrel-crypto`
/// with low-S enforcement) and verifying the bounded MST inclusion proof via `petrel-repo`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DefaultLexiconRepoProofVerifier {
    car_bytes: usize,
    max_blocks: usize,
    block_bytes: usize,
    mst_nodes: usize,
    mst_entries_per_node: usize,
}

impl DefaultLexiconRepoProofVerifier {
    /// Construct a verifier with default safety bounds (`1 MiB` CAR, `512` blocks, `256` MST hops).
    pub const fn new() -> Self {
        Self {
            car_bytes: DEFAULT_MAX_CAR_BYTES,
            max_blocks: DEFAULT_MAX_BLOCKS,
            block_bytes: DEFAULT_MAX_BLOCK_BYTES,
            mst_nodes: DEFAULT_MAX_MST_NODES,
            mst_entries_per_node: DEFAULT_MAX_MST_ENTRIES_PER_NODE,
        }
    }

    /// Return the maximum accepted CAR archive size in bytes.
    pub const fn max_car_bytes(&self) -> usize {
        self.car_bytes
    }

    /// Override the maximum accepted CAR archive size in bytes.
    #[must_use]
    pub const fn with_max_car_bytes(mut self, max_car_bytes: usize) -> Self {
        self.car_bytes = max_car_bytes;
        self
    }

    /// Override the maximum number of block frames parsed from a proof CAR.
    #[must_use]
    pub const fn with_max_blocks(mut self, max_blocks: usize) -> Self {
        self.max_blocks = max_blocks;
        self
    }

    /// Override the maximum single block size in bytes.
    #[must_use]
    pub const fn with_max_block_bytes(mut self, max_block_bytes: usize) -> Self {
        self.block_bytes = max_block_bytes;
        self
    }

    /// Override the maximum number of MST nodes traversed during inclusion lookup.
    #[must_use]
    pub const fn with_max_mst_nodes(mut self, max_mst_nodes: usize) -> Self {
        self.mst_nodes = max_mst_nodes;
        self
    }

    /// Override the maximum entries allowed inside a single MST node.
    #[must_use]
    pub const fn with_max_mst_entries_per_node(mut self, max_mst_entries_per_node: usize) -> Self {
        self.mst_entries_per_node = max_mst_entries_per_node;
        self
    }

    /// Convert a `petrel::identity::SigningKey` into a validated `petrel_crypto::PublicKey`.
    pub fn crypto_public_key(
        signing_key: &SigningKey,
    ) -> Result<PublicKey, LexiconResolutionError> {
        let curve = match signing_key.curve() {
            SigningCurve::P256 => ATProtoKeyCurve::P256,
            SigningCurve::Secp256k1 => ATProtoKeyCurve::Secp256k1,
        };
        PublicKey::from_sec1(curve, signing_key.as_sec1())
            .map_err(|err| proof_err(format!("invalid authority signing key: {err}")))
    }

    /// Construct [`RepositoryLimits`] matching this verifier's configured bounds.
    pub fn repository_limits(&self) -> RepositoryLimits {
        let mut limits = RepositoryLimits::network_scale();
        let max_blocks = self
            .max_blocks
            .clamp(1, RepositoryLimits::MAXIMUM_PERMITTED_BLOCK_COUNT);
        let max_car = self
            .car_bytes
            .clamp(1, RepositoryLimits::MAXIMUM_PERMITTED_IMPORT_CAR_BYTES);
        let max_block_bytes = self
            .block_bytes
            .clamp(1, RepositoryLimits::MAXIMUM_PERMITTED_SINGLE_BLOCK_BYTES);
        limits.max_block_count = max_blocks;
        limits.max_record_count = max_blocks;
        limits.max_import_car_bytes = max_car;
        limits.max_relevant_block_bytes =
            max_car.min(RepositoryLimits::MAXIMUM_PERMITTED_RELEVANT_BLOCK_BYTES);
        limits.max_single_block_bytes = max_block_bytes;
        limits.max_mst_node_count = self.mst_nodes.clamp(1, max_blocks);
        limits.max_mst_depth = self
            .mst_nodes
            .clamp(1, RepositoryLimits::MAXIMUM_PERMITTED_MST_DEPTH);
        limits.max_car_roots = 1;
        limits
    }

    /// Verify `car_bytes` using `petrel_repo` CAR/commit/MST verification with all configured
    /// bounds enforced (including `max_mst_nodes` and `max_mst_entries_per_node`), preserving
    /// the underlying [`VerifiedRecordProof`] and [`RepositoryError`].
    pub fn verify_with_repository(
        &self,
        car_bytes: &[u8],
        did: &Did,
        collection: &Nsid,
        rkey: &RecordKey,
        public_key: &PublicKey,
    ) -> Result<VerifiedRecordProof, RepositoryError> {
        if self.max_blocks == 0 || self.block_bytes == 0 || self.mst_nodes == 0 {
            return Err(LimitError::InvalidConfiguration(
                "proof verifier block and MST node limits must be positive".into(),
            )
            .into());
        }
        if car_bytes.is_empty() {
            return Err(CARError::Truncated.into());
        }
        if car_bytes.len() > self.car_bytes {
            return Err(CARError::Limit(LimitError::Exceeded {
                kind: LimitKind::ImportCarBytes,
                observed: car_bytes.len(),
                limit: self.car_bytes,
            })
            .into());
        }

        let limits = self.repository_limits();
        let policy = RepositoryReadPolicy::strict();
        let key_resolver = FixedSigningKey::from_public_key(SigningPublicKey::from(public_key));
        let verifier = *self;

        poll_ready(async move {
            let path = RepositoryPath::new(collection.as_str(), rkey.as_str())?;
            let (parsed, store) =
                PublicRepositoryCAR::import_bytes(car_bytes, &limits, &policy).await?;
            let commit = CommitCodec::verify_from_store(
                &parsed.root_cid,
                &store,
                Some(did),
                &key_resolver,
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
            let bounded_source = BoundedMstBlockSource {
                inner: &store,
                max_nodes: verifier.mst_nodes,
                max_entries_per_node: verifier.mst_entries_per_node,
                seen_nodes: AtomicUsize::new(0),
            };
            let proven = MstProof::verify_membership(
                &commit.data_cid,
                path.mst_key(),
                &bounded_source,
                &mst_options,
            )
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
                    let _ = RecordCodec::validate_record_bytes(
                        &bytes,
                        Some(path.collection()),
                        &policy,
                    )?;
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
        })
    }
}

impl Default for DefaultLexiconRepoProofVerifier {
    fn default() -> Self {
        Self::new()
    }
}

impl LexiconRepoProofVerifier for DefaultLexiconRepoProofVerifier {
    fn verify_record_proof(
        &self,
        car_bytes: &[u8],
        did: &Did,
        collection: &Nsid,
        rkey: &RecordKey,
        signing_key: &SigningKey,
    ) -> Result<VerifiedLexiconRecord, LexiconResolutionError> {
        let public_key = Self::crypto_public_key(signing_key)?;
        let proven = self
            .verify_with_repository(car_bytes, did, collection, rkey, &public_key)
            .map_err(map_repository_error)?;

        let Some(record) = proven.record else {
            return Err(proof_err(
                "record is provably absent from signed repository MST",
            ));
        };

        Ok(VerifiedLexiconRecord {
            cid: record.cid,
            record_cbor: record.bytes,
        })
    }
}

#[derive(Debug)]
struct BoundedMstBlockSource<'a> {
    inner: &'a InMemoryBlockStore,
    max_nodes: usize,
    max_entries_per_node: usize,
    seen_nodes: AtomicUsize,
}

impl BlockSource for BoundedMstBlockSource<'_> {
    fn get_block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, BlockStoreError>> {
        Box::pin(async move {
            let block = self.inner.get_block(cid).await?;
            let Some(bytes) = block else {
                return Ok(None);
            };
            let visited = self.seen_nodes.fetch_add(1, Ordering::Relaxed) + 1;
            if visited > self.max_nodes {
                return Err(BlockStoreError::CorruptStore(format!(
                    "MST traversal exceeded maximum node limit ({})",
                    self.max_nodes
                )));
            }
            if let Some(entry_count) = canonical_mst_entry_count(&bytes)
                && entry_count > u64::try_from(self.max_entries_per_node).unwrap_or(u64::MAX)
            {
                return Err(BlockStoreError::CorruptStore(format!(
                    "MST node entry count {entry_count} exceeds limit {}",
                    self.max_entries_per_node
                )));
            }
            Ok(Some(bytes))
        })
    }
}

/// Inspects a canonical DAG-CBOR MST node block (`{"e": [...], "l": ...}`) in O(1) without
/// allocating entry arrays or values, returning the `"e"` array item count if present.
fn canonical_mst_entry_count(bytes: &[u8]) -> Option<u64> {
    // Canonical DAG-CBOR sorts equal-length keys lexicographically: `"e"` before `"l"` in a 2-key map.
    let [0xa2, 0x61, b'e', rest @ ..] = bytes else {
        return None;
    };
    let (&head, tail) = rest.split_first()?;
    if (head >> 5) != 4 {
        return None;
    }
    let additional = head & 0x1f;
    match additional {
        0..=23 => Some(u64::from(additional)),
        24 => tail.first().copied().map(u64::from),
        25 => Some(u64::from(u16::from_be_bytes(
            tail.get(..2)?.try_into().ok()?,
        ))),
        26 => Some(u64::from(u32::from_be_bytes(
            tail.get(..4)?.try_into().ok()?,
        ))),
        27 => Some(u64::from_be_bytes(tail.get(..8)?.try_into().ok()?)),
        _ => None,
    }
}

fn map_repository_error(err: RepositoryError) -> LexiconResolutionError {
    match err {
        RepositoryError::Record(
            inner @ (RecordCodecError::TypeCollectionMismatch { .. }
            | RecordCodecError::InvalidTypeField(_)),
        ) => LexiconResolutionError::InvalidRecord {
            message: inner.to_string(),
        },
        other => proof_err(other.to_string()),
    }
}

fn proof_err(message: impl Into<String>) -> LexiconResolutionError {
    LexiconResolutionError::ProofVerificationFailed {
        message: message.into(),
    }
}

fn poll_ready<F: Future>(future: F) -> F::Output {
    let waker = futures_util::task::noop_waker();
    let mut cx = Context::from_waker(&waker);
    let mut pinned = std::pin::pin!(future);
    match Pin::as_mut(&mut pinned).poll(&mut cx) {
        Poll::Ready(out) => out,
        Poll::Pending => panic!("in-memory petrel-repo proof verification yielded Poll::Pending"),
    }
}
