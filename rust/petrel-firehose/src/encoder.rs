//! Canonical DAG-CBOR firehose frame encoder using `petrel_core::subscription`.

use std::collections::BTreeMap;

use petrel_core::{Cid, FrameError, FrameHeader, SubscriptionFrame, Value, encode_frame};

use crate::limits::{FirehoseFrameEncoderError, FirehoseFrameLimits};
use crate::types::{
    PublicFirehoseAccountMaterial, PublicFirehoseCommitMaterial, PublicFirehoseIdentityMaterial,
    PublicFirehoseRepoAction, PublicFirehoseRepoOp, PublicFirehoseSyncMaterial,
};

/// Encodes complete firehose frames: canonical DAG-CBOR header object
/// concatenated with canonical DAG-CBOR body object.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FirehoseFrameEncoder;

impl FirehoseFrameEncoder {
    /// Encodes a `#commit` frame.
    pub fn commit_frame(
        seq: i64,
        material: &PublicFirehoseCommitMaterial,
        diff_car: &[u8],
    ) -> Result<Vec<u8>, FirehoseFrameEncoderError> {
        FirehoseFrameLimits::validate_sequence(seq)?;
        if diff_car.len() > FirehoseFrameLimits::MAXIMUM_COMMIT_BLOCKS_BYTES {
            return Err(FirehoseFrameEncoderError::BlocksTooLarge {
                actual: diff_car.len(),
                maximum: FirehoseFrameLimits::MAXIMUM_COMMIT_BLOCKS_BYTES,
            });
        }
        let ops = encode_ops(&material.ops)?;

        let mut body = BTreeMap::new();
        body.insert("seq".to_owned(), Value::Integer(seq));
        body.insert("rebase".to_owned(), Value::Bool(false));
        body.insert("tooBig".to_owned(), Value::Bool(false));
        body.insert("repo".to_owned(), Value::String(material.did.clone()));
        body.insert(
            "commit".to_owned(),
            Value::Link(parse_cid(&material.commit_cid)?),
        );
        body.insert("rev".to_owned(), Value::String(material.rev.clone()));
        body.insert(
            "since".to_owned(),
            material
                .since
                .as_ref()
                .map_or(Value::Null, |s| Value::String(s.clone())),
        );
        body.insert("blocks".to_owned(), Value::Bytes(diff_car.to_vec()));
        body.insert("ops".to_owned(), Value::Array(ops));
        body.insert("blobs".to_owned(), Value::Array(Vec::new()));
        body.insert("time".to_owned(), Value::String(material.time.clone()));
        if let Some(prev_data_cid) = &material.prev_data_cid {
            body.insert(
                "prevData".to_owned(),
                Value::Link(parse_cid(prev_data_cid)?),
            );
        }

        encode_message("#commit", body)
    }

    /// Encodes a `#sync` frame.
    pub fn sync_frame(
        seq: i64,
        material: &PublicFirehoseSyncMaterial,
        commit_car: &[u8],
    ) -> Result<Vec<u8>, FirehoseFrameEncoderError> {
        FirehoseFrameLimits::validate_sequence(seq)?;
        if commit_car.len() > FirehoseFrameLimits::MAXIMUM_SYNC_BLOCKS_BYTES {
            return Err(FirehoseFrameEncoderError::BlocksTooLarge {
                actual: commit_car.len(),
                maximum: FirehoseFrameLimits::MAXIMUM_SYNC_BLOCKS_BYTES,
            });
        }
        let mut body = BTreeMap::new();
        body.insert("seq".to_owned(), Value::Integer(seq));
        body.insert("did".to_owned(), Value::String(material.did.clone()));
        body.insert("blocks".to_owned(), Value::Bytes(commit_car.to_vec()));
        body.insert("rev".to_owned(), Value::String(material.rev.clone()));
        body.insert("time".to_owned(), Value::String(material.time.clone()));
        encode_message("#sync", body)
    }

    /// Encodes an `#identity` frame.
    pub fn identity_frame(
        seq: i64,
        material: &PublicFirehoseIdentityMaterial,
    ) -> Result<Vec<u8>, FirehoseFrameEncoderError> {
        FirehoseFrameLimits::validate_sequence(seq)?;
        let mut body = BTreeMap::new();
        body.insert("seq".to_owned(), Value::Integer(seq));
        body.insert("did".to_owned(), Value::String(material.did.clone()));
        body.insert("time".to_owned(), Value::String(material.time.clone()));
        if let Some(handle) = &material.handle {
            body.insert("handle".to_owned(), Value::String(handle.clone()));
        }
        encode_message("#identity", body)
    }

    /// Encodes an `#account` frame.
    pub fn account_frame(
        seq: i64,
        material: &PublicFirehoseAccountMaterial,
    ) -> Result<Vec<u8>, FirehoseFrameEncoderError> {
        FirehoseFrameLimits::validate_sequence(seq)?;
        if material.active != material.status.is_none() {
            return Err(FirehoseFrameEncoderError::InvalidAccountStatus);
        }
        let mut body = BTreeMap::new();
        body.insert("seq".to_owned(), Value::Integer(seq));
        body.insert("did".to_owned(), Value::String(material.did.clone()));
        body.insert("time".to_owned(), Value::String(material.time.clone()));
        body.insert("active".to_owned(), Value::Bool(material.active));
        if let Some(status) = material.status {
            body.insert(
                "status".to_owned(),
                Value::String(status.as_str().to_owned()),
            );
        }
        encode_message("#account", body)
    }

    /// Encodes an `#info` frame.
    pub fn info_frame(
        name: &str,
        message: Option<&str>,
    ) -> Result<Vec<u8>, FirehoseFrameEncoderError> {
        let mut body = BTreeMap::new();
        body.insert("name".to_owned(), Value::String(name.to_owned()));
        if let Some(message) = message {
            body.insert("message".to_owned(), Value::String(message.to_owned()));
        }
        encode_message("#info", body)
    }

    /// Encodes an error frame (`op: -1`).
    pub fn error_frame(
        error: &str,
        message: Option<&str>,
    ) -> Result<Vec<u8>, FirehoseFrameEncoderError> {
        let frame = SubscriptionFrame::Error {
            error: error.to_owned(),
            message: message.map(str::to_owned),
        };
        encode_frame(&frame).map_err(map_frame_error)
    }
}

fn encode_ops(ops: &[PublicFirehoseRepoOp]) -> Result<Vec<Value>, FirehoseFrameEncoderError> {
    if ops.len() > FirehoseFrameLimits::MAXIMUM_OPS {
        return Err(FirehoseFrameEncoderError::TooManyOperations(ops.len()));
    }
    let mut out = Vec::with_capacity(ops.len());
    for (index, op) in ops.iter().enumerate() {
        match op.action {
            PublicFirehoseRepoAction::Create => {
                if op.cid.is_none() || op.prev.is_some() {
                    return Err(FirehoseFrameEncoderError::InvalidOperation {
                        index,
                        reason: "create requires cid and no prev".to_owned(),
                    });
                }
            }
            PublicFirehoseRepoAction::Update => {
                if op.cid.is_none() || op.prev.is_none() {
                    return Err(FirehoseFrameEncoderError::InvalidOperation {
                        index,
                        reason: "update requires cid and prev".to_owned(),
                    });
                }
            }
            PublicFirehoseRepoAction::Delete => {
                if op.cid.is_some() || op.prev.is_none() {
                    return Err(FirehoseFrameEncoderError::InvalidOperation {
                        index,
                        reason: "delete requires no cid and a prev".to_owned(),
                    });
                }
            }
        }
        let cid_value = match &op.cid {
            Some(cid) => Value::Link(parse_cid(cid)?),
            None => Value::Null,
        };
        let mut map = BTreeMap::new();
        map.insert("cid".to_owned(), cid_value);
        map.insert("path".to_owned(), Value::String(op.path.clone()));
        map.insert(
            "action".to_owned(),
            Value::String(match op.action {
                PublicFirehoseRepoAction::Create => "create".to_owned(),
                PublicFirehoseRepoAction::Update => "update".to_owned(),
                PublicFirehoseRepoAction::Delete => "delete".to_owned(),
            }),
        );
        if let Some(prev) = &op.prev {
            map.insert("prev".to_owned(), Value::Link(parse_cid(prev)?));
        }
        out.push(Value::Object(map));
    }
    Ok(out)
}

fn parse_cid(raw: &str) -> Result<Cid, FirehoseFrameEncoderError> {
    Cid::parse(raw).map_err(|_| FirehoseFrameEncoderError::InvalidCid(raw.to_owned()))
}

fn encode_message(
    wire_type: &str,
    body: BTreeMap<String, Value>,
) -> Result<Vec<u8>, FirehoseFrameEncoderError> {
    let frame = SubscriptionFrame::Message {
        header: FrameHeader::message(wire_type),
        message_type: wire_type.to_owned(),
        payload: Value::Object(body),
        sequence: None,
    };
    encode_frame(&frame).map_err(map_frame_error)
}

fn map_frame_error(err: FrameError) -> FirehoseFrameEncoderError {
    match err {
        FrameError::FrameTooLarge { len, .. } => FirehoseFrameEncoderError::FrameTooLarge(len),
        other => FirehoseFrameEncoderError::Encode(other.to_string()),
    }
}
