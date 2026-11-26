use std::collections::BTreeMap;
use std::sync::Arc;

use petrel_core::{Cid, Did};

use crate::block_store::{BlockSource, InMemoryBlockStore};
use crate::car::PublicRepositoryCAR;
use crate::commit::{CommitCodec, VerifiedSignedCommit};
use crate::crypto::{FixedSigningKey, SigningPublicKey};
use crate::error::RepositoryError;
use crate::limits::RepositoryLimits;
use crate::mst::{MstKeySyntax, MstOptions, MstValidation, RepositoryMst};
use crate::record::{Record, RecordCodec};
use crate::types::{RepositoryPath, RepositoryReadPolicy};

/// Imported repository snapshot used for reference comparisons (`PublicRepositoryReferenceImport`).
#[derive(Debug, Clone)]
pub struct ReferenceImportedRepository {
    pub commit: VerifiedSignedCommit,
    pub store: Arc<InMemoryBlockStore>,
    pub records: BTreeMap<String, (Cid, Vec<u8>)>,
    pub mst_node_count: usize,
}

/// Reference surface matching `PublicRepositoryReferenceSurface` / `PublicRepositoryReferenceImport`
/// in Swift for differential testing across Swift, TypeScript, and Rust.
#[derive(Debug, Clone, Copy, Default)]
pub struct ReferenceSurface;

impl ReferenceSurface {
    /// Imports a CAR archive strictly (without DID resolution) against a pinned
    /// [`SigningPublicKey`] and validates every MST node and record block.
    pub async fn import_car(
        car_bytes: &[u8],
        public_key: &SigningPublicKey,
        expected_did: Option<&Did>,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<ReferenceImportedRepository, RepositoryError> {
        let (parsed, store) = PublicRepositoryCAR::import_bytes(car_bytes, limits, policy).await?;
        let store = Arc::new(store);
        let resolver = FixedSigningKey::from_public_key(public_key.clone());
        let commit = CommitCodec::verify_from_store(
            &parsed.root_cid,
            store.as_ref(),
            expected_did,
            &resolver,
            policy,
        )
        .await?;

        let mst_options = MstOptions {
            key_syntax: MstKeySyntax::StrictAtProto,
            policy: *policy,
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

        let mut records = BTreeMap::new();
        for entry in entries {
            let path = RepositoryPath::from_mst_key(&entry.key)?;
            let bytes = store
                .get_block(&entry.value)
                .await?
                .ok_or_else(|| RepositoryError::MissingBlock(entry.value.clone()))?;
            let _ = RecordCodec::validate_record_bytes(&bytes, Some(path.collection()), policy)?;
            records.insert(entry.key, (entry.value, bytes));
        }

        Ok(ReferenceImportedRepository {
            commit,
            store,
            records,
            mst_node_count: stats.node_count,
        })
    }

    /// Reads and validates a single record directly from a reference import.
    pub async fn read_record(
        imported: &ReferenceImportedRepository,
        collection: &str,
        record_key: &str,
        policy: &RepositoryReadPolicy,
    ) -> Result<Option<(Cid, Record)>, RepositoryError> {
        let path = RepositoryPath::new(collection, record_key)?;
        let mut mst = RepositoryMst::open_with_options(
            imported.commit.data_cid.clone(),
            Arc::clone(&imported.store) as Arc<dyn BlockSource>,
            MstOptions {
                policy: *policy,
                ..MstOptions::default()
            },
        );
        let Some(cid) = mst.get(path.mst_key()).await? else {
            return Ok(None);
        };
        let bytes = imported
            .store
            .get_block(&cid)
            .await?
            .ok_or_else(|| RepositoryError::MissingBlock(cid.clone()))?;
        let record = RecordCodec::validate_record_bytes(&bytes, Some(path.collection()), policy)?;
        Ok(Some((cid, record)))
    }
}
