use std::collections::{BTreeMap, BTreeSet};

use petrel_core::Cid;
use serde::{Deserialize, Serialize};
use serde_json::Value as Json;

use crate::{
    at_profile::PlcAtProfile,
    error::PlcError,
    operation::{PlcOperation, PlcOperationCodec, PlcService},
    strict_json::PlcStrictJson,
};

/// Current state of a PLC identity (`GET /:did/data`, or derived from verified log).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlcDocumentData {
    pub did: String,
    pub rotation_keys: Vec<String>,
    pub verification_methods: BTreeMap<String, String>,
    pub also_known_as: Vec<String>,
    pub services: BTreeMap<String, PlcService>,
}

impl PlcDocumentData {
    /// First `at://` alias without its prefix.
    pub fn handle(&self) -> Option<&str> {
        self.also_known_as
            .iter()
            .find_map(|alias| alias.strip_prefix("at://"))
    }

    /// Endpoint of the `atproto_pds` service when its type is `AtprotoPersonalDataServer`.
    pub fn pds_endpoint(&self) -> Option<&str> {
        self.services
            .get(PlcAtProfile::PDS_SERVICE_ID)
            .filter(|svc| svc.kind == PlcAtProfile::PDS_SERVICE_TYPE)
            .map(|svc| svc.endpoint.as_str())
    }

    /// The `atproto` verification method `did:key`.
    pub fn atproto_signing_key(&self) -> Option<&str> {
        self.verification_methods
            .get(PlcAtProfile::SIGNING_KEY_ID)
            .map(String::as_str)
    }
}

/// One entry of an identity's audit log (`GET /:did/log/audit`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlcAuditEntry {
    pub did: String,
    pub operation: PlcOperation,
    pub cid: String,
    pub nullified: bool,
    pub created_at: String,
}

/// An audit log whose CIDs, genesis DID, signatures, and 72h recovery nullification
/// have all been verified offline.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlcVerifiedAuditLog {
    pub did: String,
    pub entries: Vec<PlcAuditEntry>,
    pub signers: Vec<String>,
    pub head: PlcAuditEntry,
}

impl PlcVerifiedAuditLog {
    /// Non-nullified entries in chronological directory order.
    pub fn active_entries(&self) -> Vec<&PlcAuditEntry> {
        self.entries.iter().filter(|e| !e.nullified).collect()
    }

    /// Whether the identity has been deactivated by a tombstone.
    pub fn is_tombstoned(&self) -> bool {
        self.head.operation.is_tombstone()
    }

    /// Identity state established by `head`, or `None` if tombstoned.
    pub fn document_data(&self) -> Option<PlcDocumentData> {
        self.head.operation.document_data(&self.did)
    }

    /// Verifies that `operation` can extend this log next (non-tombstoned, matching `prev`,
    /// valid rotation key signature), returning the signing rotation key's priority index.
    pub fn verify_next_operation(&self, operation: &PlcOperation) -> Result<usize, PlcError> {
        let Some(rotation_keys) = self.head.operation.rotation_keys() else {
            return Err(PlcError::Tombstoned {
                did: self.did.clone(),
            });
        };
        let Some(prev) = operation.prev() else {
            return Err(PlcError::unauthorized(
                "PLC operation prev does not name the identity's current operation",
            ));
        };
        if !PlcAuditLogVerifier::cids_match(&self.head.cid, prev) {
            return Err(PlcError::unauthorized(
                "PLC operation prev does not name the identity's current operation",
            ));
        }
        PlcOperationCodec::verify(operation, &rotation_keys)
    }
}

/// Offline verification of PLC audit and operation logs.
#[derive(Debug, Clone, Copy)]
pub struct PlcAuditLogVerifier;

impl PlcAuditLogVerifier {
    /// Recovery window in milliseconds: 72 hours.
    pub const RECOVERY_WINDOW_MILLIS: i64 = 72 * 60 * 60 * 1_000;
    /// Recovery window in seconds: 72 hours.
    pub const RECOVERY_WINDOW_SECS: u64 = 72 * 60 * 60;
    /// Maximum number of log entries processed.
    pub const MAXIMUM_ENTRIES: usize = 10_000;

    /// Decodes `GET /:did/log/audit` JSON without verifying signatures or chain history.
    pub fn decode(data: &[u8], did: &str) -> Result<Vec<PlcAuditEntry>, PlcError> {
        PlcOperationCodec::validate_canonical_did(did)?;
        PlcStrictJson::validate(data)?;
        let raw_entries: Vec<Json> = serde_json::from_slice(data)
            .map_err(|_| PlcError::malformed("PLC audit log is malformed"))?;
        if raw_entries.is_empty() || raw_entries.len() > Self::MAXIMUM_ENTRIES {
            return Err(PlcError::malformed("PLC audit log is malformed"));
        }

        let mut entries = Vec::with_capacity(raw_entries.len());
        for raw in raw_entries {
            let Some(obj) = raw.as_object() else {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            };
            let Some(entry_did) = obj.get("did").and_then(Json::as_str) else {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            };
            let Some(op_val) = obj.get("operation") else {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            };
            let Some(cid_text) = obj.get("cid").and_then(Json::as_str) else {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            };
            let Some(nullified) = obj.get("nullified").and_then(Json::as_bool) else {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            };
            let Some(created_at) = obj.get("createdAt").and_then(Json::as_str) else {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            };
            if entry_did != did {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            }

            let operation = PlcOperationCodec::decode_signed_json_value(op_val)?;
            let computed_cid = operation.cid_string()?;
            if computed_cid != cid_text {
                return Err(PlcError::unauthorized("PLC audit operation CID is invalid"));
            }

            entries.push(PlcAuditEntry {
                did: entry_did.to_owned(),
                operation,
                cid: cid_text.to_owned(),
                nullified,
                created_at: created_at.to_owned(),
            });
        }
        Ok(entries)
    }

    /// Decodes and verifies a JSON `GET /:did/log/audit` response.
    pub fn verify_json(data: &[u8], did: &str) -> Result<PlcVerifiedAuditLog, PlcError> {
        let entries = Self::decode(data, did)?;
        Self::verify(&entries, did)
    }

    /// Verifies an audit log, recomputing CIDs, DID genesis binding, rotation signatures,
    /// and 72-hour recovery nullifications.
    pub fn verify(entries: &[PlcAuditEntry], did: &str) -> Result<PlcVerifiedAuditLog, PlcError> {
        PlcOperationCodec::validate_canonical_did(did)?;
        if entries.is_empty() || entries.len() > Self::MAXIMUM_ENTRIES {
            return Err(PlcError::malformed("PLC audit log is malformed"));
        }

        let timestamps = Self::validate_entries_envelope(entries, did)?;
        let mut signers = Vec::with_capacity(entries.len());
        let genesis = &entries[0].operation;
        let genesis_did = PlcOperationCodec::genesis_did(genesis)?;
        let Some(genesis_keys) = genesis.rotation_keys() else {
            return Err(PlcError::unauthorized(
                "PLC genesis DID does not match operation",
            ));
        };
        if genesis_did != did {
            return Err(PlcError::unauthorized(
                "PLC genesis DID does not match operation",
            ));
        }
        let (_, genesis_signer) = PlcOperationCodec::verify_returning_key(genesis, &genesis_keys)?;
        signers.push(genesis_signer.did_key());

        let mut active: Vec<usize> = vec![0];
        for proposed_index in 1..entries.len() {
            let signer_key = Self::replay_entry(entries, &timestamps, &mut active, proposed_index)?;
            signers.push(signer_key);
        }

        let active_set: BTreeSet<usize> = active.iter().copied().collect();
        let verified: Vec<PlcAuditEntry> = entries
            .iter()
            .enumerate()
            .map(|(idx, entry)| PlcAuditEntry {
                did: entry.did.clone(),
                operation: entry.operation.clone(),
                cid: entry.cid.clone(),
                nullified: !active_set.contains(&idx),
                created_at: entry.created_at.clone(),
            })
            .collect();
        let head = verified[active.last().copied().unwrap_or(0)].clone();

        Ok(PlcVerifiedAuditLog {
            did: did.to_owned(),
            entries: verified,
            signers,
            head,
        })
    }

    fn validate_entries_envelope(
        entries: &[PlcAuditEntry],
        did: &str,
    ) -> Result<Vec<i64>, PlcError> {
        let mut timestamps: Vec<i64> = Vec::with_capacity(entries.len());
        let mut seen_cids: BTreeSet<String> = BTreeSet::new();
        for (index, entry) in entries.iter().enumerate() {
            if entry.did != did {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            }
            let Some(ts) = plc_timestamp_milliseconds(&entry.created_at) else {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            };
            if timestamps.last().is_some_and(|&prev| ts < prev) {
                return Err(PlcError::malformed("PLC audit entry is malformed"));
            }
            timestamps.push(ts);

            let computed = entry.operation.cid_string()?;
            if computed != entry.cid || !seen_cids.insert(entry.cid.clone()) {
                return Err(PlcError::unauthorized("PLC audit operation CID is invalid"));
            }
            if index == 0 {
                if entry.operation.prev().is_some() || entry.operation.is_tombstone() {
                    return Err(PlcError::unauthorized(
                        "PLC audit does not start with genesis",
                    ));
                }
            } else if entry.operation.prev().is_none() {
                return Err(PlcError::unauthorized(
                    "PLC audit contains multiple genesis operations",
                ));
            }
        }
        Ok(timestamps)
    }

    fn replay_entry(
        entries: &[PlcAuditEntry],
        timestamps: &[i64],
        active: &mut Vec<usize>,
        proposed_index: usize,
    ) -> Result<String, PlcError> {
        let proposed = &entries[proposed_index];
        let Some(proposed_prev) = proposed.operation.prev() else {
            return Err(PlcError::unauthorized(
                "PLC audit operation prev is missing",
            ));
        };
        let Some(parent_pos) = active
            .iter()
            .position(|&idx| Self::cids_match(&entries[idx].cid, proposed_prev))
        else {
            return Err(PlcError::unauthorized(
                "PLC audit operation prev is not active",
            ));
        };
        let Some(rotation_keys) = entries[active[parent_pos]].operation.rotation_keys() else {
            return Err(PlcError::unauthorized(
                "PLC audit operation follows a tombstone",
            ));
        };

        if parent_pos == active.len() - 1 {
            let (_, key) =
                PlcOperationCodec::verify_returning_key(&proposed.operation, &rotation_keys)?;
            active.push(proposed_index);
            return Ok(key.did_key());
        }

        // Recovery fork: must strictly beat the authority of the first displaced op
        // and fall within the 72-hour window.
        let first_disputed_index = active[parent_pos + 1];
        let disputed_signer_idx =
            PlcOperationCodec::verify(&entries[first_disputed_index].operation, &rotation_keys)?;
        if disputed_signer_idx == 0 {
            return Err(PlcError::unauthorized(
                "PLC recovery cannot supersede an equal-authority operation",
            ));
        }
        let (_, recovery_key) = PlcOperationCodec::verify_returning_key(
            &proposed.operation,
            &rotation_keys[..disputed_signer_idx],
        )?;

        let recovery_age = timestamps[proposed_index] - timestamps[first_disputed_index];
        if !(0..=Self::RECOVERY_WINDOW_MILLIS).contains(&recovery_age) {
            return Err(PlcError::unauthorized(
                "PLC recovery exceeds the 72-hour window",
            ));
        }
        active.truncate(parent_pos + 1);
        active.push(proposed_index);
        Ok(recovery_key.did_key())
    }

    /// Verifies a linear operation log (`GET /:did/log`) and returns the resulting state,
    /// or `None` if it ends in a tombstone.
    pub fn validate_operation_log(
        operations: &[PlcOperation],
        did: &str,
    ) -> Result<Option<PlcDocumentData>, PlcError> {
        let Some((first, rest)) = operations.split_first() else {
            return Err(PlcError::malformed("PLC operation log is malformed"));
        };
        if operations.len() > Self::MAXIMUM_ENTRIES {
            return Err(PlcError::malformed("PLC operation log is malformed"));
        }
        PlcOperationCodec::verify_genesis(first, did)?;
        let mut previous = first;
        for op in rest {
            let Some(rotation_keys) = previous.rotation_keys() else {
                return Err(PlcError::unauthorized("PLC operation follows a tombstone"));
            };
            let prev_cid = previous.cid_string()?;
            let Some(prev) = op.prev() else {
                return Err(PlcError::unauthorized(
                    "PLC operation prev does not match the log",
                ));
            };
            if !Self::cids_match(&prev_cid, prev) {
                return Err(PlcError::unauthorized(
                    "PLC operation prev does not match the log",
                ));
            }
            let _ = PlcOperationCodec::verify(op, &rotation_keys)?;
            previous = op;
        }
        Ok(previous.document_data(did))
    }

    /// Compares a canonical lowercase CID against a candidate (tolerating uppercase base32 on read).
    pub(crate) fn cids_match(canonical: &str, candidate: &str) -> bool {
        if canonical == candidate {
            return true;
        }
        let lower = candidate.to_ascii_lowercase();
        Cid::parse(&lower).is_ok_and(|cid| cid.to_string() == canonical)
    }
}

/// Parses an ISO-8601 `YYYY-MM-DDTHH:mm:ss.sssZ` timestamp into Unix epoch milliseconds.
pub fn plc_timestamp_milliseconds(value: &str) -> Option<i64> {
    let bytes = value.as_bytes();
    if bytes.len() != 24
        || bytes[4] != b'-'
        || bytes[7] != b'-'
        || bytes[10] != b'T'
        || bytes[13] != b':'
        || bytes[16] != b':'
        || bytes[19] != b'.'
        || bytes[23] != b'Z'
    {
        return None;
    }
    let number = |range: std::ops::Range<usize>| -> Option<i64> {
        let mut result: i64 = 0;
        for &b in &bytes[range] {
            if !b.is_ascii_digit() {
                return None;
            }
            result = result * 10 + i64::from(b - b'0');
        }
        Some(result)
    };
    let year = number(0..4)?;
    let month = number(5..7)?;
    let day = number(8..10)?;
    let hour = number(11..13)?;
    let minute = number(14..16)?;
    let second = number(17..19)?;
    let millisecond = number(20..23)?;
    if !(1..=12).contains(&month) || hour > 23 || minute > 59 || second > 59 {
        return None;
    }
    let is_leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    let days_in_month = [
        31,
        if is_leap { 29 } else { 28 },
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31,
    ];
    let max_day = days_in_month[usize::try_from(month - 1).ok()?];
    if day < 1 || day > max_day {
        return None;
    }

    let shifted_year = if month <= 2 { year - 1 } else { year };
    let era = if shifted_year >= 0 {
        shifted_year
    } else {
        shifted_year - 399
    } / 400;
    let year_of_era = shifted_year - era * 400;
    let day_of_year = (153 * (month + if month > 2 { -3 } else { 9 }) + 2) / 5 + day - 1;
    let day_of_era = year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year;
    let days = era * 146_097 + day_of_era - 719_468;
    Some((((days * 24 + hour) * 60 + minute) * 60 + second) * 1_000 + millisecond)
}
