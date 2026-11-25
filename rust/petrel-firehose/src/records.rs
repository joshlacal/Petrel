//! Record extraction from `#commit` diff CARs.

use petrel_core::{Cid, Value};

use crate::car::{DEFAULT_MAX_CAR_BYTES, DiffCarBlockReader, ParsedCarArchive};
use crate::types::{RelayCommitEvent, RelayRepoAction, RelayVerifierError};

/// One record-level operation of a `#commit`, with the record decoded from `blocks`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayRecordOperation {
    pub action: RelayRepoAction,
    pub collection: String,
    pub record_key: String,
    pub cid: Option<Cid>,
    pub record: Option<Value>,
}

impl RelayRecordOperation {
    /// Returns `at://<repo>/<collection>/<rkey>`.
    pub fn uri(&self, repo: &str) -> String {
        format!("at://{}/{}/{}", repo, self.collection, self.record_key)
    }
}

impl RelayCommitEvent {
    /// Decodes the records created or updated by this commit from `self.blocks`.
    ///
    /// Pairs each operation with its block bytes, verifies `Cid::matches_content`,
    /// and decodes canonical DAG-CBOR. Call [`Self::verify`] first to authenticate
    /// the commit and its MST proof.
    pub fn records(&self) -> Result<Vec<RelayRecordOperation>, RelayVerifierError> {
        let reader = if self.blocks.is_empty() {
            None
        } else {
            Some(ParsedCarArchive::parse(
                &self.blocks,
                DEFAULT_MAX_CAR_BYTES,
                false,
            )?)
        };

        let mut out = Vec::with_capacity(self.ops.len());
        for op in &self.ops {
            let Some((collection, record_key)) = op.path.split_once('/') else {
                return Err(RelayVerifierError::InvalidRepositoryOperation);
            };
            let record = match (&op.cid, &reader) {
                (Some(cid), Some(car)) => match car.block_bytes(cid) {
                    Some(bytes) => {
                        if !cid.matches_content(bytes) {
                            return Err(RelayVerifierError::InvalidRepositoryCar);
                        }
                        let val = Value::from_dag_cbor_record(bytes)
                            .map_err(|_| RelayVerifierError::InvalidRepositoryCar)?;
                        Some(val)
                    }
                    None => None,
                },
                _ => None,
            };
            out.push(RelayRecordOperation {
                action: op.action,
                collection: collection.to_owned(),
                record_key: record_key.to_owned(),
                cid: op.cid.clone(),
                record,
            });
        }
        Ok(out)
    }
}
