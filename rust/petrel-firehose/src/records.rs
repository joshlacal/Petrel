//! Record extraction from `#commit` diff CARs.

use petrel_core::{Cid, Value};

use crate::car::{DEFAULT_MAX_CAR_BYTES, DiffCarBlockReader, ParsedCarArchive};
use crate::types::{RelayCommitEvent, RelayRepoAction, RelayRepoOp, RelayVerifierError};

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

/// Why one operation of a `#commit` could not be turned into a [`RelayRecordOperation`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("commit operation {index} ({path}) failed: {error}")]
pub struct RelayRecordOperationError {
    /// Position of the operation in [`RelayCommitEvent::ops`].
    pub index: usize,
    pub action: RelayRepoAction,
    pub path: String,
    pub error: RelayVerifierError,
}

impl RelayCommitEvent {
    /// Decodes the records created or updated by this commit from `self.blocks`.
    ///
    /// Pairs each operation with its block bytes, verifies `Cid::matches_content`,
    /// and decodes canonical DAG-CBOR. Call [`Self::verify`] first to authenticate
    /// the commit and its MST proof.
    ///
    /// All-or-nothing: the first failing operation fails the whole commit. Use
    /// [`Self::record_results`] to keep the operations that do decode.
    pub fn records(&self) -> Result<Vec<RelayRecordOperation>, RelayVerifierError> {
        self.record_results()?
            .into_iter()
            .map(|result| result.map_err(|failure| failure.error))
            .collect()
    }

    /// Per-operation variant of [`Self::records`]: one result per entry of `self.ops`, in order.
    ///
    /// The outer error covers commit-level failures (the `blocks` CAR does not parse). A bad
    /// path, a block whose bytes do not match its CID, or a block that is not a valid record
    /// fails only its own operation.
    pub fn record_results(
        &self,
    ) -> Result<Vec<Result<RelayRecordOperation, RelayRecordOperationError>>, RelayVerifierError>
    {
        let reader = if self.blocks.is_empty() {
            None
        } else {
            Some(ParsedCarArchive::parse(
                &self.blocks,
                DEFAULT_MAX_CAR_BYTES,
                false,
            )?)
        };

        Ok(self
            .ops
            .iter()
            .enumerate()
            .map(|(index, op)| {
                decode_operation(op, reader.as_ref()).map_err(|error| RelayRecordOperationError {
                    index,
                    action: op.action,
                    path: op.path.clone(),
                    error,
                })
            })
            .collect())
    }
}

fn decode_operation(
    op: &RelayRepoOp,
    reader: Option<&ParsedCarArchive>,
) -> Result<RelayRecordOperation, RelayVerifierError> {
    let Some((collection, record_key)) = op.path.split_once('/') else {
        return Err(RelayVerifierError::InvalidRepositoryOperation);
    };
    let record = match (&op.cid, reader) {
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
    Ok(RelayRecordOperation {
        action: op.action,
        collection: collection.to_owned(),
        record_key: record_key.to_owned(),
        cid: op.cid.clone(),
        record,
    })
}
