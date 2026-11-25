use std::fmt;

use serde::Deserialize;
use serde_json::Value as Json;

use crate::{
    error::PlcError,
    operation::{PlcOperation, PlcOperationCodec},
    strict_json::PlcStrictJson,
};

/// Pagination cursor for `GET /export`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PlcExportCursor {
    /// Sequenced export cursor (`sequenced_op` format); `Sequence(0)` starts from the beginning.
    Sequence(u64),
    /// Legacy timestamp cursor (`YYYY-MM-DDTHH:mm:ss.sssZ`).
    Timestamp(String),
}

impl fmt::Display for PlcExportCursor {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Sequence(seq) => write!(f, "{seq}"),
            Self::Timestamp(ts) => f.write_str(ts),
        }
    }
}

/// One line of a PLC directory export or `/export/stream`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlcExportEntry {
    pub did: String,
    pub operation: PlcOperation,
    pub cid: String,
    pub created_at: String,
    pub sequence: Option<u64>,
    pub nullified: Option<bool>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ExportEnvelope {
    did: String,
    cid: String,
    created_at: String,
    seq: Option<u64>,
    nullified: Option<bool>,
    #[serde(rename = "type")]
    kind: Option<String>,
}

impl PlcExportEntry {
    /// Cursor that continues an export immediately after this entry.
    pub fn cursor(&self) -> PlcExportCursor {
        match self.sequence {
            Some(seq) => PlcExportCursor::Sequence(seq),
            None => PlcExportCursor::Timestamp(self.created_at.clone()),
        }
    }

    /// Decodes one JSON line and verifies its CID against its operation.
    pub fn from_json_line(data: &[u8]) -> Result<Self, PlcError> {
        PlcStrictJson::validate(data)?;

        let envelope: ExportEnvelope = serde_json::from_slice(data)
            .map_err(|_| PlcError::malformed("PLC export entry is malformed"))?;
        let raw: Json = serde_json::from_slice(data)
            .map_err(|_| PlcError::malformed("PLC export entry is malformed"))?;
        let Some(op_val) = raw.get("operation") else {
            return Err(PlcError::malformed("PLC export entry is malformed"));
        };

        PlcOperationCodec::validate_canonical_did(&envelope.did)?;
        if envelope
            .kind
            .as_deref()
            .is_some_and(|kind| kind != "sequenced_op")
        {
            return Err(PlcError::malformed("PLC export entry type is unsupported"));
        }
        let operation = PlcOperationCodec::decode_signed_json_value(op_val)?;
        let computed = operation.cid_string()?;
        if computed != envelope.cid {
            return Err(PlcError::unauthorized(
                "PLC export operation CID is invalid",
            ));
        }

        Ok(Self {
            did: envelope.did,
            operation,
            cid: envelope.cid,
            created_at: envelope.created_at,
            sequence: envelope.seq,
            nullified: envelope.nullified,
        })
    }

    /// Decodes a JSON-lines export payload, skipping blank lines.
    pub fn decode_json_lines(data: &[u8]) -> Result<Vec<Self>, PlcError> {
        let mut entries = Vec::new();
        for line in data.split(|&b| b == b'\n') {
            let trimmed = trim_ascii_whitespace(line);
            if trimmed.is_empty() {
                continue;
            }
            entries.push(Self::from_json_line(trimmed)?);
        }
        Ok(entries)
    }
}

fn trim_ascii_whitespace(mut bytes: &[u8]) -> &[u8] {
    while let Some((&first, rest)) = bytes.split_first() {
        if first.is_ascii_whitespace() {
            bytes = rest;
        } else {
            break;
        }
    }
    while let Some((&last, rest)) = bytes.split_last() {
        if last.is_ascii_whitespace() {
            bytes = rest;
        } else {
            break;
        }
    }
    bytes
}
