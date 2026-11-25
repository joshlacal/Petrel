//! Repository commit/MST/proof verification backed by `petrel-repo` and `petrel-crypto`.
//!
//! Preserves `petrel-firehose`'s public trait seams (`RepoCommitVerifier`,
//! `RepositorySigningKeyResolver`, `RepositoryBlockSource`) and adapts `petrel-repo`
//! and `petrel-crypto` verifiers, commit codecs, MST traversal/validation, and
//! record validation directly without duplicating repository cryptography or MST logic.

use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::sync::Arc;
use std::time::Duration;

use async_lock::Mutex;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync, SystemTime, UNIX_EPOCH};
use petrel_core::{Cid, Did, Nsid, RecordKey, Tid, cid::BlessedKind};
use petrel_repo::block_store::{BlockSource, BlockStore, InMemoryBlockStore};
use petrel_repo::commit::CommitCodec;
use petrel_repo::crypto::{
    CommitVerifier as RepoTraitCommitVerifier,
    RepositorySigningKeyResolver as RepoTraitSigningKeyResolver, SigningAlgorithm,
    SigningPublicKey as RepoSigningPublicKey,
};
use petrel_repo::error::{BlockStoreError, CommitError, MstError};
use petrel_repo::mst::{MstKeySyntax, MstOptions, MstValidation, RepositoryMst, decode_mst_node};
use petrel_repo::record::RecordCodec;

use crate::car::{CarBlockMap, DiffCarBlockReader, ParsedCarArchive};
use crate::limits::FirehoseFrameLimits;
use crate::types::{RelayRepoAction, RelayRepoOp, RelayVerifierError};

/// Canonical empty MST block CID (`bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm`).
pub const CANONICAL_EMPTY_MST_CID: &str = petrel_repo::CANONICAL_EMPTY_MST_CID;

/// Maximum MST nodes visited in one validation pass.
pub const DEFAULT_MAX_MST_NODES: usize = 100_000;
/// Maximum entries per MST node.
pub const DEFAULT_MAX_MST_ENTRIES_PER_NODE: usize = 512;
/// Maximum record block bytes (1 MiB).
pub const DEFAULT_MAX_RECORD_BLOCK_BYTES: usize = 1024 * 1024;
/// Maximum CAR archive bytes (128 MiB).
pub const DEFAULT_MAX_CAR_BYTES: usize = 128 * 1024 * 1024;

const MAX_MST_DEPTH: usize = 128;

/// How strictly MST keys and record contents are checked.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum RepositoryReadPolicy {
    /// Strict ATProto repo rules (`collection/rkey` syntax, `$type` matches collection, blessed links).
    Strict,
    /// Data-model rules (`prev`/record flexibility for historical data).
    DataModel,
}

impl RepositoryReadPolicy {
    pub const fn to_repo_policy(self) -> petrel_repo::RepositoryReadPolicy {
        match self {
            Self::Strict => petrel_repo::RepositoryReadPolicy::strict(),
            Self::DataModel => petrel_repo::RepositoryReadPolicy::data_model(),
        }
    }
}

/// How MST keys are validated.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum RepositoryMstKeySyntax {
    /// Valid `<nsid>/<rkey>`.
    RepositoryPath,
    /// Any non-empty MST key (used for synthetic MST interop test fixtures).
    MstKey,
}

impl RepositoryMstKeySyntax {
    const fn to_repo_syntax(self) -> MstKeySyntax {
        match self {
            Self::RepositoryPath => MstKeySyntax::StrictAtProto,
            Self::MstKey => MstKeySyntax::PermissiveUtf8,
        }
    }
}

/// Bounds on repository verification.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RepositoryLimits {
    pub maximum_writes: usize,
    pub maximum_relevant_block_bytes: usize,
    pub maximum_car_bytes: usize,
    pub maximum_record_block_bytes: usize,
    pub maximum_mst_nodes: usize,
    pub maximum_mst_entries_per_node: usize,
    pub maximum_cbor_depth: usize,
}

impl Default for RepositoryLimits {
    fn default() -> Self {
        Self::STANDARD
    }
}

impl RepositoryLimits {
    pub const STANDARD: Self = Self {
        maximum_writes: FirehoseFrameLimits::MAXIMUM_OPS,
        maximum_relevant_block_bytes: FirehoseFrameLimits::MAXIMUM_COMMIT_BLOCKS_BYTES,
        maximum_car_bytes: DEFAULT_MAX_CAR_BYTES,
        maximum_record_block_bytes: DEFAULT_MAX_RECORD_BLOCK_BYTES,
        maximum_mst_nodes: DEFAULT_MAX_MST_NODES,
        maximum_mst_entries_per_node: DEFAULT_MAX_MST_ENTRIES_PER_NODE,
        maximum_cbor_depth: FirehoseFrameLimits::MAXIMUM_DEPTH,
    };
}

/// Trait seam for verifying signed repository commits (mirrors `petrel_repo::CommitVerifier`).
pub trait RepoCommitVerifier: MaybeSend + MaybeSync {
    fn verify<'a>(
        &'a self,
        did: &'a str,
        signing_input: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), RepositoryCommitError>>;
}

/// Trait seam for resolving an account's signing key by DID (mirrors `petrel_repo::RepositorySigningKeyResolver`).
pub trait RepositorySigningKeyResolver: MaybeSend + MaybeSync {
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<Box<dyn RepoCommitVerifier>, RepositoryCommitError>>;
}

/// Async block source trait seam (mirrors `petrel_repo::BlockSource`).
pub trait RepositoryBlockSource: MaybeSend + MaybeSync {
    fn block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, RepositoryCommitDiffError>>;
}

impl RepositoryBlockSource for CarBlockMap {
    fn block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, RepositoryCommitDiffError>> {
        Box::pin(async move { Ok(self.get(cid).map(<[u8]>::to_vec)) })
    }
}

impl RepositoryBlockSource for ParsedCarArchive {
    fn block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, RepositoryCommitDiffError>> {
        Box::pin(async move { Ok(self.block_bytes(cid).map(<[u8]>::to_vec)) })
    }
}

impl RepositoryBlockSource for BTreeMap<Cid, Vec<u8>> {
    fn block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, RepositoryCommitDiffError>> {
        Box::pin(async move { Ok(self.get(cid).cloned()) })
    }
}

/// Adapter exposing any [`petrel_repo::BlockSource`] as a [`RepositoryBlockSource`].
#[derive(Debug, Clone)]
pub struct RepoBlockSourceAdapter<T>(pub T);

impl<T: BlockSource> RepositoryBlockSource for RepoBlockSourceAdapter<T> {
    fn block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, RepositoryCommitDiffError>> {
        Box::pin(async move {
            self.0
                .get_block(cid)
                .await
                .map_err(|_| RepositoryCommitDiffError::MalformedBlocks)
        })
    }
}

/// Adapter exposing any [`petrel_repo::CommitVerifier`] as a [`RepoCommitVerifier`].
#[derive(Debug, Clone)]
pub struct RepoCommitVerifierAdapter(pub Arc<dyn RepoTraitCommitVerifier>);

impl RepoCommitVerifier for RepoCommitVerifierAdapter {
    fn verify<'a>(
        &'a self,
        _did: &'a str,
        signing_input: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), RepositoryCommitError>> {
        Box::pin(async move {
            self.0
                .verify(signing_input, signature)
                .await
                .map_err(map_repo_commit_err)
        })
    }
}

/// Adapter exposing any [`petrel_repo::RepositorySigningKeyResolver`] as a firehose
/// [`RepositorySigningKeyResolver`].
pub struct RepoSigningKeyResolverAdapter<T>(pub T);

impl<T: fmt::Debug> fmt::Debug for RepoSigningKeyResolverAdapter<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("RepoSigningKeyResolverAdapter")
            .field(&self.0)
            .finish()
    }
}

impl<T: RepoTraitSigningKeyResolver> RepositorySigningKeyResolver
    for RepoSigningKeyResolverAdapter<T>
{
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<Box<dyn RepoCommitVerifier>, RepositoryCommitError>> {
        Box::pin(async move {
            let parsed_did =
                Did::parse(did).map_err(|e| RepositoryCommitError::KeyResolution(e.to_string()))?;
            let verifier = self
                .0
                .resolve_signing_key(&parsed_did, force_refresh)
                .await
                .map_err(map_repo_commit_err)?;
            Ok(Box::new(RepoCommitVerifierAdapter(verifier)) as Box<dyn RepoCommitVerifier>)
        })
    }
}

/// Built-in P-256 / K-256 commit signature verifier backed by `petrel_repo::crypto::SigningPublicKey`.
#[derive(Clone, PartialEq, Eq)]
pub enum SigningPublicKey {
    P256(p256::ecdsa::VerifyingKey),
    K256(k256::ecdsa::VerifyingKey),
}

impl fmt::Debug for SigningPublicKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::P256(_) => f.write_str("SigningPublicKey::P256(..)"),
            Self::K256(_) => f.write_str("SigningPublicKey::K256(..)"),
        }
    }
}

impl SigningPublicKey {
    pub fn p256_from_sec1(bytes: &[u8]) -> Result<Self, RepositoryCommitError> {
        let key = RepoSigningPublicKey::from_sec1_bytes(SigningAlgorithm::P256, bytes)
            .map_err(map_repo_commit_err)?;
        Self::try_from(key)
    }

    pub fn k256_from_sec1(bytes: &[u8]) -> Result<Self, RepositoryCommitError> {
        let key = RepoSigningPublicKey::from_sec1_bytes(SigningAlgorithm::Secp256k1, bytes)
            .map_err(map_repo_commit_err)?;
        Self::try_from(key)
    }

    /// Converts into [`petrel_repo::crypto::SigningPublicKey`].
    pub fn to_repo_key(&self) -> Result<RepoSigningPublicKey, RepositoryCommitError> {
        match self {
            Self::P256(vk) => RepoSigningPublicKey::from_sec1_bytes(
                SigningAlgorithm::P256,
                vk.to_sec1_bytes().as_ref(),
            )
            .map_err(map_repo_commit_err),
            Self::K256(vk) => RepoSigningPublicKey::from_sec1_bytes(
                SigningAlgorithm::Secp256k1,
                vk.to_sec1_bytes().as_ref(),
            )
            .map_err(map_repo_commit_err),
        }
    }

    /// Verifies a raw 64-byte low-S `r||s` ECDSA signature over `signing_input` via `petrel-repo`.
    pub fn verify_raw(
        &self,
        signing_input: &[u8],
        signature: &[u8],
    ) -> Result<(), RepositoryCommitError> {
        self.to_repo_key()?
            .verify_sync(signing_input, signature)
            .map_err(map_repo_commit_err)
    }
}

impl TryFrom<RepoSigningPublicKey> for SigningPublicKey {
    type Error = RepositoryCommitError;

    fn try_from(value: RepoSigningPublicKey) -> Result<Self, Self::Error> {
        match value.algorithm() {
            SigningAlgorithm::P256 => p256::ecdsa::VerifyingKey::from_sec1_bytes(value.as_sec1())
                .map(Self::P256)
                .map_err(|_| RepositoryCommitError::InvalidKey),
            SigningAlgorithm::Secp256k1 => {
                k256::ecdsa::VerifyingKey::from_sec1_bytes(value.as_sec1())
                    .map(Self::K256)
                    .map_err(|_| RepositoryCommitError::InvalidKey)
            }
        }
    }
}

impl TryFrom<&petrel_crypto::PublicKey> for SigningPublicKey {
    type Error = RepositoryCommitError;

    fn try_from(value: &petrel_crypto::PublicKey) -> Result<Self, Self::Error> {
        match value.curve() {
            petrel_crypto::ATProtoKeyCurve::P256 => {
                Self::p256_from_sec1(value.compressed_representation())
            }
            petrel_crypto::ATProtoKeyCurve::Secp256k1 => {
                Self::k256_from_sec1(value.compressed_representation())
            }
        }
    }
}

impl RepoCommitVerifier for SigningPublicKey {
    fn verify<'a>(
        &'a self,
        _did: &'a str,
        signing_input: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), RepositoryCommitError>> {
        Box::pin(async move { self.verify_raw(signing_input, signature) })
    }
}

impl RepoCommitVerifier for RepoSigningPublicKey {
    fn verify<'a>(
        &'a self,
        _did: &'a str,
        signing_input: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), RepositoryCommitError>> {
        Box::pin(async move {
            self.verify_sync(signing_input, signature)
                .map_err(map_repo_commit_err)
        })
    }
}

impl RepoCommitVerifier for petrel_crypto::PublicKey {
    fn verify<'a>(
        &'a self,
        _did: &'a str,
        signing_input: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), RepositoryCommitError>> {
        Box::pin(async move {
            if self.verify_strict(signature, signing_input) {
                Ok(())
            } else {
                Err(RepositoryCommitError::InvalidSignature)
            }
        })
    }
}

/// Fixed signing key resolver for deterministic tests and single-key consumers.
#[derive(Debug, Clone)]
pub struct FixedRepositorySigningKey {
    pub key: SigningPublicKey,
}

impl FixedRepositorySigningKey {
    pub fn new(key: SigningPublicKey) -> Self {
        Self { key }
    }
}

impl RepositorySigningKeyResolver for FixedRepositorySigningKey {
    fn resolve_signing_key<'a>(
        &'a self,
        _did: &'a str,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<Box<dyn RepoCommitVerifier>, RepositoryCommitError>> {
        Box::pin(async move { Ok(Box::new(self.key.clone()) as Box<dyn RepoCommitVerifier>) })
    }
}

/// Wraps a [`RepositorySigningKeyResolver`] and throttles `force_refresh = true` lookups per DID
/// so repeated invalid signatures cannot trigger unbounded DID resolution traffic.
pub struct ThrottledSigningKeyResolver {
    inner: Arc<dyn RepositorySigningKeyResolver>,
    cooldown: Duration,
    last_refresh: Mutex<BTreeMap<String, SystemTime>>,
}

impl fmt::Debug for ThrottledSigningKeyResolver {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ThrottledSigningKeyResolver")
            .field("cooldown", &self.cooldown)
            .finish_non_exhaustive()
    }
}

impl ThrottledSigningKeyResolver {
    /// Default minimum interval between forced key refreshes for the same DID (60s).
    pub const DEFAULT_COOLDOWN: Duration = Duration::from_secs(60);
    const MAX_TRACKED_DIDS: usize = 4_096;

    /// Wraps `inner` with [`Self::DEFAULT_COOLDOWN`].
    pub fn new(inner: Arc<dyn RepositorySigningKeyResolver>) -> Self {
        Self::with_cooldown(inner, Self::DEFAULT_COOLDOWN)
    }

    /// Wraps `inner` with an explicit per-DID forced-refresh cooldown.
    pub fn with_cooldown(inner: Arc<dyn RepositorySigningKeyResolver>, cooldown: Duration) -> Self {
        Self {
            inner,
            cooldown,
            last_refresh: Mutex::new(BTreeMap::new()),
        }
    }
}

impl RepositorySigningKeyResolver for ThrottledSigningKeyResolver {
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<Box<dyn RepoCommitVerifier>, RepositoryCommitError>> {
        Box::pin(async move {
            let effective_force = if force_refresh && !self.cooldown.is_zero() {
                let now = SystemTime::now();
                let mut guard = self.last_refresh.lock().await;
                let within_cooldown = guard
                    .get(did)
                    .and_then(|&prev| now.duration_since(prev).ok())
                    .is_some_and(|elapsed| elapsed < self.cooldown);
                if within_cooldown {
                    false
                } else {
                    if !guard.contains_key(did)
                        && guard.len() >= Self::MAX_TRACKED_DIDS
                        && let Some(oldest_did) = guard
                            .iter()
                            .min_by_key(|(_, ts)| *ts)
                            .map(|(k, _)| k.clone())
                    {
                        guard.remove(&oldest_did);
                    }
                    guard.insert(did.to_owned(), now);
                    true
                }
            } else {
                force_refresh
            };
            self.inner.resolve_signing_key(did, effective_force).await
        })
    }
}

/// Errors from commit codec / signature verification.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum RepositoryCommitError {
    #[error("invalid commit schema")]
    InvalidSchema,
    #[error("commit CID mismatch")]
    CidMismatch,
    #[error("commit DID mismatch")]
    DidMismatch,
    #[error("invalid signing key")]
    InvalidKey,
    #[error("invalid commit signature")]
    InvalidSignature,
    #[error("key resolution failed: {0}")]
    KeyResolution(String),
}

fn map_repo_commit_err(err: CommitError) -> RepositoryCommitError {
    match err {
        CommitError::InvalidCbor(msg) if msg.starts_with("commit CID hash mismatch") => {
            RepositoryCommitError::CidMismatch
        }
        CommitError::DidMismatch { .. } => RepositoryCommitError::DidMismatch,
        CommitError::InvalidSignatureEncoding(_)
        | CommitError::InvalidSignature
        | CommitError::HighSSignature => RepositoryCommitError::InvalidSignature,
        CommitError::InvalidPublicKey(_) | CommitError::SigningFailed(_) => {
            RepositoryCommitError::InvalidKey
        }
        CommitError::KeyResolutionFailed { reason, .. } => {
            RepositoryCommitError::KeyResolution(reason)
        }
        CommitError::BlockStore(e) => RepositoryCommitError::KeyResolution(e.to_string()),
        CommitError::InvalidCbor(_)
        | CommitError::UnsupportedVersion(_)
        | CommitError::InvalidField { .. }
        | CommitError::UnblessedLink(_)
        | CommitError::CommitTooLarge { .. }
        | CommitError::MissingBlock(_) => RepositoryCommitError::InvalidSchema,
    }
}

/// Decoded and structurally validated commit fields.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommitDescriptor {
    pub did: String,
    pub revision: String,
    pub data_cid: Cid,
    pub prev: Option<Cid>,
}

/// Structurally validated signed commit (no signature check yet).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StructurallyValidatedSignedCommit {
    pub commit_cid: Cid,
    pub signed_commit_bytes: Vec<u8>,
    pub unsigned_commit_bytes: Vec<u8>,
    pub signature: Vec<u8>,
    pub descriptor: CommitDescriptor,
}

/// Verified signed commit (after signature verification).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedSignedCommit {
    pub commit_cid: Cid,
    pub signed_commit_bytes: Vec<u8>,
    pub descriptor: CommitDescriptor,
}

/// Parses and structurally validates an AT Protocol v3 signed commit block via `petrel_repo::CommitCodec`.
pub fn structurally_validate_commit(
    signed_commit_bytes: &[u8],
    expected_commit_cid: &Cid,
) -> Result<StructurallyValidatedSignedCommit, RepositoryCommitError> {
    if !expected_commit_cid.matches_content(signed_commit_bytes) {
        return Err(RepositoryCommitError::CidMismatch);
    }
    let validated = CommitCodec::structurally_validate(
        signed_commit_bytes,
        Some(expected_commit_cid),
        None,
        &petrel_repo::RepositoryReadPolicy::strict(),
    )
    .map_err(map_repo_commit_err)?;

    Ok(StructurallyValidatedSignedCommit {
        commit_cid: validated.cid,
        signed_commit_bytes: validated.signed_commit_bytes,
        unsigned_commit_bytes: validated.unsigned_commit_bytes,
        signature: validated.signature,
        descriptor: CommitDescriptor {
            did: validated.did.as_str().to_owned(),
            revision: validated.rev.as_str().to_owned(),
            data_cid: validated.data_cid,
            prev: validated.prev_cid,
        },
    })
}

/// Verifies a signed commit block using a [`RepoCommitVerifier`].
pub async fn verify_commit_with_verifier(
    signed_commit_bytes: &[u8],
    expected_commit_cid: &Cid,
    verifier: &dyn RepoCommitVerifier,
    expected_did: Option<&str>,
) -> Result<VerifiedSignedCommit, RepositoryCommitError> {
    let parsed = structurally_validate_commit(signed_commit_bytes, expected_commit_cid)?;
    if let Some(expected_did) = expected_did
        && parsed.descriptor.did != expected_did
    {
        return Err(RepositoryCommitError::DidMismatch);
    }
    verifier
        .verify(
            &parsed.descriptor.did,
            &parsed.unsigned_commit_bytes,
            &parsed.signature,
        )
        .await?;
    Ok(VerifiedSignedCommit {
        commit_cid: parsed.commit_cid,
        signed_commit_bytes: parsed.signed_commit_bytes,
        descriptor: parsed.descriptor,
    })
}

struct DidScopedCommitVerifier {
    did: String,
    verifier: Box<dyn RepoCommitVerifier>,
}

impl fmt::Debug for DidScopedCommitVerifier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("DidScopedCommitVerifier")
            .field("did", &self.did)
            .finish_non_exhaustive()
    }
}

impl RepoTraitCommitVerifier for DidScopedCommitVerifier {
    fn verify<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), CommitError>> {
        Box::pin(async move {
            self.verifier
                .verify(&self.did, unsigned_commit_bytes, signature)
                .await
                .map_err(|e| match e {
                    RepositoryCommitError::InvalidSignature => CommitError::InvalidSignature,
                    RepositoryCommitError::InvalidKey => {
                        CommitError::InvalidPublicKey(e.to_string())
                    }
                    RepositoryCommitError::KeyResolution(reason) => {
                        CommitError::KeyResolutionFailed {
                            did: self.did.clone(),
                            reason,
                        }
                    }
                    other => CommitError::InvalidCbor(other.to_string()),
                })
        })
    }
}

struct FirehoseResolverBridge<'a>(&'a dyn RepositorySigningKeyResolver);

impl RepoTraitSigningKeyResolver for FirehoseResolverBridge<'_> {
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a Did,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<Arc<dyn RepoTraitCommitVerifier>, CommitError>> {
        Box::pin(async move {
            let verifier = self
                .0
                .resolve_signing_key(did.as_str(), force_refresh)
                .await
                .map_err(|e| match e {
                    RepositoryCommitError::KeyResolution(reason) => {
                        CommitError::KeyResolutionFailed {
                            did: did.as_str().to_owned(),
                            reason,
                        }
                    }
                    RepositoryCommitError::InvalidKey => {
                        CommitError::InvalidPublicKey(e.to_string())
                    }
                    other => CommitError::KeyResolutionFailed {
                        did: did.as_str().to_owned(),
                        reason: other.to_string(),
                    },
                })?;
            #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
            let scoped: Arc<dyn RepoTraitCommitVerifier> = Arc::new(DidScopedCommitVerifier {
                did: did.as_str().to_owned(),
                verifier,
            });
            Ok(scoped)
        })
    }
}

/// Verifies a signed commit block using a [`RepositorySigningKeyResolver`] via
/// `petrel_repo::CommitCodec::verify` (one forced refresh retry on signature mismatch).
pub async fn verify_commit_with_resolver(
    signed_commit_bytes: &[u8],
    expected_commit_cid: &Cid,
    resolver: &dyn RepositorySigningKeyResolver,
    expected_did: Option<&str>,
) -> Result<VerifiedSignedCommit, RepositoryCommitError> {
    let target_did = match expected_did {
        Some(raw) => {
            if !expected_commit_cid.matches_content(signed_commit_bytes) {
                return Err(RepositoryCommitError::CidMismatch);
            }
            Some(Did::parse(raw).map_err(|_| RepositoryCommitError::DidMismatch)?)
        }
        None => None,
    };
    let bridge = FirehoseResolverBridge(resolver);
    let verified = CommitCodec::verify(
        signed_commit_bytes,
        Some(expected_commit_cid),
        target_did.as_ref(),
        &bridge,
        &petrel_repo::RepositoryReadPolicy::strict(),
    )
    .await
    .map_err(map_repo_commit_err)?;

    Ok(VerifiedSignedCommit {
        commit_cid: verified.cid,
        signed_commit_bytes: verified.signed_commit_bytes,
        descriptor: CommitDescriptor {
            did: verified.did.as_str().to_owned(),
            revision: verified.rev.as_str().to_owned(),
            data_cid: verified.data_cid,
            prev: verified.prev_cid,
        },
    })
}

/// Typed operation for commit diff verification.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RepositoryCommitOperation {
    Create {
        path: String,
        cid: Cid,
    },
    Update {
        path: String,
        cid: Cid,
        previous: Cid,
    },
    Delete {
        path: String,
        previous: Cid,
    },
}

impl RepositoryCommitOperation {
    pub fn path(&self) -> &str {
        match self {
            Self::Create { path, .. } | Self::Update { path, .. } | Self::Delete { path, .. } => {
                path
            }
        }
    }

    pub fn record_cid(&self) -> Option<&Cid> {
        match self {
            Self::Create { cid, .. } | Self::Update { cid, .. } => Some(cid),
            Self::Delete { .. } => None,
        }
    }
}

impl RelayRepoOp {
    /// Converts this wire op into a [`RepositoryCommitOperation`].
    pub fn repository_operation(
        &self,
        key_syntax: RepositoryMstKeySyntax,
    ) -> Result<RepositoryCommitOperation, RepositoryCommitDiffError> {
        validate_mst_key(&self.path, key_syntax)
            .map_err(|()| RepositoryCommitDiffError::MalformedOperation(self.path.clone()))?;
        match (self.action, &self.cid, &self.prev) {
            (RelayRepoAction::Create, Some(cid), None) => Ok(RepositoryCommitOperation::Create {
                path: self.path.clone(),
                cid: cid.clone(),
            }),
            (RelayRepoAction::Update, Some(cid), Some(prev)) => {
                Ok(RepositoryCommitOperation::Update {
                    path: self.path.clone(),
                    cid: cid.clone(),
                    previous: prev.clone(),
                })
            }
            (RelayRepoAction::Delete, None, Some(prev)) => Ok(RepositoryCommitOperation::Delete {
                path: self.path.clone(),
                previous: prev.clone(),
            }),
            _ => Err(RepositoryCommitDiffError::MalformedOperation(
                self.path.clone(),
            )),
        }
    }
}

fn validate_mst_key(key: &str, syntax: RepositoryMstKeySyntax) -> Result<(), ()> {
    if key.is_empty() || key.len() > 1024 {
        return Err(());
    }
    match syntax {
        RepositoryMstKeySyntax::MstKey => {
            if key.as_bytes().iter().all(|&b| (0x20..=0x7e).contains(&b)) {
                Ok(())
            } else {
                Err(())
            }
        }
        RepositoryMstKeySyntax::RepositoryPath => {
            let Some((collection, rkey)) = key.split_once('/') else {
                return Err(());
            };
            if Nsid::parse(collection).is_ok() && RecordKey::parse(rkey).is_ok() {
                Ok(())
            } else {
                Err(())
            }
        }
    }
}

/// Errors returned by commit diff / MST inversion verification.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum RepositoryCommitDiffError {
    #[error("missing commit block")]
    MissingCommit,
    #[error("commit verification failed: {0}")]
    Commit(#[from] RepositoryCommitError),
    #[error("incomplete MST proof")]
    IncompleteProof,
    #[error("invalid MST node or topology")]
    InvalidTree,
    #[error("operation mismatch at path {0}")]
    OperationMismatch(String),
    #[error("previous data CID mismatch: computed {computed}, expected {expected}")]
    PreviousDataMismatch { computed: Cid, expected: Cid },
    #[error("missing record block at path {0}")]
    MissingRecord(String),
    #[error("invalid record block at path {0}")]
    InvalidRecord(String),
    #[error("duplicate operation path {0}")]
    DuplicatePath(String),
    #[error("malformed blocks CAR")]
    MalformedBlocks,
    #[error("CAR root {root} does not match commit {commit}")]
    RootMismatch { root: Cid, commit: Cid },
    #[error("revision mismatch: event {event}, commit {commit}")]
    RevisionMismatch { event: String, commit: String },
    #[error("revision {0} is in the future")]
    RevisionInFuture(String),
    #[error("too many operations ({count} > {limit})")]
    TooManyOperations { count: usize, limit: usize },
    #[error("blocks too large ({byte_count} > {limit})")]
    BlocksTooLarge { byte_count: usize, limit: usize },
    #[error("malformed operation at path {0}")]
    MalformedOperation(String),
    #[error("missing prevData on #commit event")]
    MissingPreviousData,
}

/// Result of verifying a commit diff.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedRepositoryCommitDiff {
    pub commit: VerifiedSignedCommit,
    pub operations: Vec<RepositoryCommitOperation>,
    pub previous_data_cid: Cid,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum ClosureRole {
    /// Follow key intervals covering any op (and its adjacent delete merge children).
    TargetOps,
    /// Reverse-delete merge spine: follow leftmost child chain.
    LeftSpine,
    /// Reverse-delete merge spine: follow rightmost child chain.
    RightSpine,
}

struct ClosurePreloadCtx<'a> {
    op_keys: &'a [&'a str],
    blocks: &'a dyn RepositoryBlockSource,
    options: &'a MstOptions,
    store: &'a InMemoryBlockStore,
    seen_roles: BTreeSet<(Cid, ClosureRole)>,
    distinct_cids: BTreeSet<Cid>,
    decoded_nodes: BTreeMap<Cid, petrel_repo::mst::MstNodeView>,
    missing: BTreeSet<Cid>,
    max_nodes: usize,
}

fn collect_target_children(
    view: &petrel_repo::mst::MstNodeView,
    op_keys: &[&str],
) -> Vec<(Cid, ClosureRole)> {
    let mut load_left = false;
    let mut left_right_spine = false;
    let mut child_roles = vec![(false, false); view.entries.len()];
    for &key in op_keys {
        let pos = view
            .entries
            .partition_point(|entry| entry.key.as_str() < key);
        if pos < view.entries.len() && view.entries[pos].key == key {
            if pos == 0 {
                load_left = true;
                left_right_spine = true;
            } else {
                child_roles[pos - 1].0 = true;
                child_roles[pos - 1].1 = true;
            }
            child_roles[pos].0 = true;
            child_roles[pos].1 = true;
        } else if pos == 0 {
            load_left = true;
        } else {
            child_roles[pos - 1].0 = true;
        }
    }
    let mut out = Vec::new();
    if load_left && let Some(left_cid) = &view.left {
        out.push((left_cid.clone(), ClosureRole::TargetOps));
        if left_right_spine {
            out.push((left_cid.clone(), ClosureRole::RightSpine));
        }
    }
    for (idx, (need_ops, need_left_spine)) in child_roles.into_iter().enumerate() {
        if (need_ops || need_left_spine)
            && let Some(right_cid) = &view.entries[idx].tree
        {
            if need_ops {
                out.push((right_cid.clone(), ClosureRole::TargetOps));
            }
            if need_left_spine {
                out.push((right_cid.clone(), ClosureRole::LeftSpine));
            }
        }
    }
    out
}

async fn preload_mst_closure(
    ctx: &mut ClosurePreloadCtx<'_>,
    root_cid: &Cid,
) -> Result<(), RepositoryCommitDiffError> {
    let mut stack = vec![(root_cid.clone(), ClosureRole::TargetOps, 0_usize)];
    while let Some((node_cid, role, depth)) = stack.pop() {
        if depth > ctx.options.max_depth {
            return Err(RepositoryCommitDiffError::InvalidTree);
        }
        if !ctx.seen_roles.insert((node_cid.clone(), role)) {
            continue;
        }
        if ctx.distinct_cids.insert(node_cid.clone()) && ctx.distinct_cids.len() > ctx.max_nodes {
            return Err(RepositoryCommitDiffError::InvalidTree);
        }
        if ctx.missing.contains(&node_cid) {
            continue;
        }

        let view = if let Some(cached) = ctx.decoded_nodes.get(&node_cid) {
            cached
        } else {
            let Some(bytes) = ctx.blocks.block(&node_cid).await? else {
                ctx.missing.insert(node_cid);
                continue;
            };
            if node_cid.blessed_kind() != Some(BlessedKind::DagCbor)
                || !node_cid.matches_content(&bytes)
                || bytes.len() > ctx.options.max_single_block_bytes
            {
                return Err(RepositoryCommitDiffError::InvalidTree);
            }
            let decoded = decode_mst_node(
                &bytes,
                ctx.options.key_syntax,
                &ctx.options.policy,
                ctx.options.require_canonical_prefix,
            )
            .map_err(|_| RepositoryCommitDiffError::InvalidTree)?;
            ctx.store
                .put_block(&node_cid, &bytes)
                .await
                .map_err(|_| RepositoryCommitDiffError::InvalidTree)?;
            ctx.decoded_nodes.entry(node_cid).or_insert(decoded)
        };

        if view.entries.is_empty() {
            if let Some(left_cid) = &view.left {
                stack.push((left_cid.clone(), role, depth + 1));
            }
            continue;
        }

        let children_to_load: Vec<(Cid, ClosureRole)> = match role {
            ClosureRole::LeftSpine => view
                .left
                .as_ref()
                .map(|c| vec![(c.clone(), ClosureRole::LeftSpine)])
                .unwrap_or_default(),
            ClosureRole::RightSpine => view
                .entries
                .last()
                .and_then(|e| e.tree.as_ref())
                .map(|c| vec![(c.clone(), ClosureRole::RightSpine)])
                .unwrap_or_default(),
            ClosureRole::TargetOps => collect_target_children(view, ctx.op_keys),
        };

        for (child_cid, child_role) in children_to_load {
            stack.push((child_cid, child_role, depth + 1));
        }
    }
    Ok(())
}

fn map_mst_diff_error(err: &MstError) -> RepositoryCommitDiffError {
    match err {
        MstError::MissingBlock(_) => RepositoryCommitDiffError::IncompleteProof,
        _ => RepositoryCommitDiffError::InvalidTree,
    }
}

/// Verifies MST diff inversion over partial proof blocks via `petrel_repo::mst::RepositoryMst`.
pub async fn verify_mst_inversion(
    data_cid: &Cid,
    operations: &[RepositoryCommitOperation],
    previous_data_cid: &Cid,
    blocks: &dyn RepositoryBlockSource,
    limits: &RepositoryLimits,
    key_syntax: RepositoryMstKeySyntax,
) -> Result<(), RepositoryCommitDiffError> {
    if operations.len() > limits.maximum_writes {
        return Err(RepositoryCommitDiffError::TooManyOperations {
            count: operations.len(),
            limit: limits.maximum_writes,
        });
    }

    let mut seen_paths = BTreeSet::new();
    for op in operations {
        validate_mst_key(op.path(), key_syntax)
            .map_err(|()| RepositoryCommitDiffError::MalformedOperation(op.path().to_owned()))?;
        if !seen_paths.insert(op.path().to_owned()) {
            return Err(RepositoryCommitDiffError::DuplicatePath(
                op.path().to_owned(),
            ));
        }
    }

    let mst_options = MstOptions {
        key_syntax: key_syntax.to_repo_syntax(),
        policy: petrel_repo::RepositoryReadPolicy::strict(),
        require_canonical_prefix: true,
        max_depth: limits.maximum_cbor_depth.min(MAX_MST_DEPTH),
        max_node_count: limits.maximum_mst_nodes,
        max_single_block_bytes: limits.maximum_record_block_bytes,
    };

    let store = InMemoryBlockStore::new();
    let op_keys: Vec<&str> = operations
        .iter()
        .map(RepositoryCommitOperation::path)
        .collect();
    let mut ctx = ClosurePreloadCtx {
        op_keys: &op_keys,
        blocks,
        options: &mst_options,
        store: &store,
        seen_roles: BTreeSet::new(),
        distinct_cids: BTreeSet::new(),
        decoded_nodes: BTreeMap::new(),
        missing: BTreeSet::new(),
        max_nodes: limits.maximum_mst_nodes,
    };
    preload_mst_closure(&mut ctx, data_cid).await?;

    if store
        .get_block(data_cid)
        .await
        .map_err(|_| RepositoryCommitDiffError::IncompleteProof)?
        .is_none()
    {
        return Err(RepositoryCommitDiffError::IncompleteProof);
    }

    let mut tree = RepositoryMst::open_with_options(data_cid.clone(), Arc::new(store), mst_options);
    apply_reverse_ops(&mut tree, operations).await?;

    let computed_prev = tree.root_cid().clone();
    if &computed_prev != previous_data_cid {
        return Err(RepositoryCommitDiffError::PreviousDataMismatch {
            computed: computed_prev,
            expected: previous_data_cid.clone(),
        });
    }
    Ok(())
}

async fn apply_reverse_ops(
    tree: &mut RepositoryMst,
    operations: &[RepositoryCommitOperation],
) -> Result<(), RepositoryCommitDiffError> {
    for op in operations.iter().rev() {
        let key = op.path();
        match op {
            RepositoryCommitOperation::Create { cid, .. } => {
                let current = tree.get(key).await.map_err(|e| map_mst_diff_error(&e))?;
                if current.as_ref() != Some(cid) {
                    return Err(RepositoryCommitDiffError::OperationMismatch(key.to_owned()));
                }
                tree.delete(key).await.map_err(|e| map_mst_diff_error(&e))?;
            }
            RepositoryCommitOperation::Update { cid, previous, .. } => {
                let current = tree.get(key).await.map_err(|e| map_mst_diff_error(&e))?;
                if current.as_ref() != Some(cid) {
                    return Err(RepositoryCommitDiffError::OperationMismatch(key.to_owned()));
                }
                if previous.blessed_kind() != Some(BlessedKind::DagCbor) {
                    return Err(RepositoryCommitDiffError::MalformedOperation(
                        key.to_owned(),
                    ));
                }
                tree.update(key, previous.clone())
                    .await
                    .map_err(|e| map_mst_diff_error(&e))?;
            }
            RepositoryCommitOperation::Delete { previous, .. } => {
                let current = tree.get(key).await.map_err(|e| map_mst_diff_error(&e))?;
                if current.is_some() {
                    return Err(RepositoryCommitDiffError::OperationMismatch(key.to_owned()));
                }
                if previous.blessed_kind() != Some(BlessedKind::DagCbor) {
                    return Err(RepositoryCommitDiffError::MalformedOperation(
                        key.to_owned(),
                    ));
                }
                tree.insert(key, previous.clone())
                    .await
                    .map_err(|e| map_mst_diff_error(&e))?;
            }
        }
    }
    Ok(())
}

// --- Full MST validation backed by `petrel_repo::mst::MstValidation` ---

struct RecordingBlockSource<'a> {
    inner: &'a dyn RepositoryBlockSource,
    recorded: Mutex<BTreeMap<Cid, Vec<u8>>>,
    total_bytes: Mutex<usize>,
    max_reachable_bytes: usize,
}

impl fmt::Debug for RecordingBlockSource<'_> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("RecordingBlockSource")
            .finish_non_exhaustive()
    }
}

impl BlockSource for RecordingBlockSource<'_> {
    fn get_block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, BlockStoreError>> {
        Box::pin(async move {
            {
                let rec = self.recorded.lock().await;
                if let Some(existing) = rec.get(cid) {
                    return Ok(Some(existing.clone()));
                }
            }
            let Some(bytes) = self
                .inner
                .block(cid)
                .await
                .map_err(|e| BlockStoreError::CorruptStore(e.to_string()))?
            else {
                return Ok(None);
            };
            let mut total = self.total_bytes.lock().await;
            let next_total =
                total
                    .checked_add(bytes.len())
                    .ok_or(BlockStoreError::TooManyBlocks {
                        count: usize::MAX,
                        limit: self.max_reachable_bytes,
                    })?;
            if next_total > self.max_reachable_bytes {
                return Err(BlockStoreError::TooManyBlocks {
                    count: next_total,
                    limit: self.max_reachable_bytes,
                });
            }
            *total = next_total;
            self.recorded
                .lock()
                .await
                .insert(cid.clone(), bytes.clone());
            Ok(Some(bytes))
        })
    }
}

/// Validates a full MST tree via `petrel_repo::mst::MstValidation::validate_full`
/// and validates every reachable record block via `petrel_repo::record::RecordCodec`.
pub(crate) async fn validate_full_mst(
    root_cid: &Cid,
    blocks: &dyn RepositoryBlockSource,
    limits: &RepositoryLimits,
    policy: RepositoryReadPolicy,
    max_reachable_bytes: usize,
) -> Result<ValidatedMst, RelayVerifierError> {
    if root_cid.blessed_kind() != Some(BlessedKind::DagCbor) {
        return Err(RelayVerifierError::InvalidRepositoryCar);
    }

    let recorder = RecordingBlockSource {
        inner: blocks,
        recorded: Mutex::new(BTreeMap::new()),
        total_bytes: Mutex::new(0),
        max_reachable_bytes,
    };
    let mst_options = MstOptions {
        key_syntax: MstKeySyntax::StrictAtProto,
        policy: policy.to_repo_policy(),
        require_canonical_prefix: true,
        max_depth: limits.maximum_cbor_depth.min(MAX_MST_DEPTH),
        max_node_count: limits.maximum_mst_nodes,
        max_single_block_bytes: limits.maximum_record_block_bytes,
    };
    let max_record_count = DEFAULT_MAX_MST_NODES.max(limits.maximum_mst_nodes);

    let (_stats, entries) =
        MstValidation::validate_full(root_cid, &recorder, &mst_options, max_record_count, false)
            .await
            .map_err(|err| match err {
                MstError::BlockStore(BlockStoreError::TooManyBlocks { .. }) => {
                    RelayVerifierError::RepositoryCarTooLarge
                }
                _ => RelayVerifierError::InvalidRepositoryCar,
            })?;

    let mst_blocks = recorder.recorded.into_inner();
    let mut total_bytes = *recorder.total_bytes.lock().await;

    let mut records = BTreeMap::new();
    let mut record_cids = BTreeSet::new();
    let mut expected_collections: BTreeMap<Cid, BTreeSet<String>> = BTreeMap::new();
    for entry in entries {
        let Some((col, _)) = entry.key.split_once('/') else {
            return Err(RelayVerifierError::InvalidRepositoryCar);
        };
        if entry.value.blessed_kind() == Some(BlessedKind::DagCbor) {
            record_cids.insert(entry.value.clone());
            expected_collections
                .entry(entry.value.clone())
                .or_default()
                .insert(col.to_owned());
        }
        if records.insert(entry.key, entry.value).is_some() {
            return Err(RelayVerifierError::InvalidRepositoryCar);
        }
    }

    for (cid, collections) in &expected_collections {
        let bytes = blocks
            .block(cid)
            .await
            .map_err(|_| RelayVerifierError::InvalidRepositoryCar)?
            .ok_or(RelayVerifierError::InvalidRepositoryCar)?;
        if !cid.matches_content(&bytes) || bytes.len() > limits.maximum_record_block_bytes {
            return Err(RelayVerifierError::InvalidRepositoryCar);
        }
        total_bytes = total_bytes
            .checked_add(bytes.len())
            .filter(|&t| t <= max_reachable_bytes)
            .ok_or(RelayVerifierError::RepositoryCarTooLarge)?;
        for col in collections {
            validate_record_block(&bytes, col, policy)
                .map_err(|()| RelayVerifierError::InvalidRepositoryCar)?;
        }
    }

    Ok(ValidatedMst {
        records,
        mst_blocks,
        record_cids,
    })
}

pub(crate) struct ValidatedMst {
    pub records: BTreeMap<String, Cid>,
    pub mst_blocks: BTreeMap<Cid, Vec<u8>>,
    pub record_cids: BTreeSet<Cid>,
}

pub(crate) fn validate_record_block(
    bytes: &[u8],
    expected_collection: &str,
    policy: RepositoryReadPolicy,
) -> Result<(), ()> {
    let parsed_nsid = (policy == RepositoryReadPolicy::Strict)
        .then(|| Nsid::parse(expected_collection).map_err(|_| ()))
        .transpose()?;
    let repo_policy = policy.to_repo_policy();
    RecordCodec::validate_record_bytes(bytes, parsed_nsid.as_ref(), &repo_policy)
        .map(|_| ())
        .map_err(|_| ())
}

pub(crate) fn require_rev_not_in_future(
    revision: &str,
    now: SystemTime,
    max_clock_skew: Duration,
) -> Result<(), RepositoryCommitDiffError> {
    let Ok(tid) = Tid::parse(revision) else {
        return Ok(());
    };
    let now_micros = now
        .duration_since(UNIX_EPOCH)
        .map_or(0u64, |d| u64::try_from(d.as_micros()).unwrap_or(u64::MAX));
    let skew_micros = u64::try_from(max_clock_skew.as_micros()).unwrap_or(u64::MAX);
    if tid.timestamp_micros() > now_micros.saturating_add(skew_micros) {
        return Err(RepositoryCommitDiffError::RevisionInFuture(
            revision.to_owned(),
        ));
    }
    Ok(())
}
