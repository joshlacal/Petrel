//! Wire JSON decoders for Jetstream v2 (`xrpc.v1.json`) and legacy v1 (`/subscribe`).

use petrel_firehose::RelayRepoAction;
use serde::de::DeserializeOwned;
use serde_json::Value as JsonValue;

use crate::event::{
    JetstreamAccountEvent, JetstreamCommitEvent, JetstreamEvent, JetstreamIdentityEvent,
    JetstreamInfoEvent, JetstreamSyncEvent,
};

const PAYLOAD_TYPE_PREFIX: &str = "network.bsky.jetstream.subscribeEvents#";
const MAX_SAFE_JSON_INT: i64 = 9_007_199_254_740_991;

/// Errors returned when a Jetstream frame is not a valid JSON object envelope.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum JetstreamWireError {
    #[error("malformed Jetstream frame: {0}")]
    MalformedFrame(String),
}

/// Decoded outcome of one Jetstream WebSocket message.
#[derive(Debug, Clone, PartialEq)]
pub enum JetstreamWireFrame {
    /// Recognized event decoded into [`JetstreamEvent`].
    Message(JetstreamEvent),
    /// Protocol-level error frame.
    Error {
        name: String,
        message: Option<String>,
    },
    /// Structurally valid frame with an unknown `$type` or legacy `kind` (forward-compat skip).
    Skipped {
        r#type: Option<String>,
        seq: Option<i64>,
    },
    /// Known message type whose body was invalid or missing required fields.
    Undecodable {
        r#type: Option<String>,
        seq: Option<i64>,
        reason: String,
    },
}

/// Decoder for Jetstream v2 JSON envelopes and legacy v1 `/subscribe` objects.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct JetstreamWire;

impl JetstreamWire {
    /// Decodes a v2 `xrpc.v1.json` frame:
    /// `{"$type":"message","payload":{...}}` or `{"$type":"error","error":...,"message":...}`.
    pub fn decode_frame(data: &[u8]) -> Result<JetstreamWireFrame, JetstreamWireError> {
        let root_val: JsonValue = serde_json::from_slice(data)
            .map_err(|e| JetstreamWireError::MalformedFrame(format!("invalid JSON: {e}")))?;
        let Some(root) = root_val.as_object() else {
            return Err(JetstreamWireError::MalformedFrame(
                "frame is not a JSON object".to_owned(),
            ));
        };

        match root.get("$type").and_then(JsonValue::as_str) {
            Some("message") => {
                let Some(payload) = root.get("payload").and_then(JsonValue::as_object) else {
                    return Err(JetstreamWireError::MalformedFrame(
                        "message frame without payload object".to_owned(),
                    ));
                };
                Ok(decode_v2_payload(payload))
            }
            Some("error") => {
                let Some(name) = root.get("error").and_then(JsonValue::as_str) else {
                    return Err(JetstreamWireError::MalformedFrame(
                        "error frame without error name".to_owned(),
                    ));
                };
                let message = root
                    .get("message")
                    .and_then(JsonValue::as_str)
                    .map(str::to_owned);
                Ok(JetstreamWireFrame::Error {
                    name: name.to_owned(),
                    message,
                })
            }
            other => Ok(JetstreamWireFrame::Skipped {
                r#type: other.map(str::to_owned),
                seq: None,
            }),
        }
    }

    /// Decodes a legacy v1 `/subscribe` frame (`{"did":...,"time_us":...,"kind":...}`),
    /// surfacing `seq == time_us` so cursor tracking works identically across dialects.
    pub fn decode_legacy_frame(data: &[u8]) -> Result<JetstreamWireFrame, JetstreamWireError> {
        let root_val: JsonValue = serde_json::from_slice(data)
            .map_err(|e| JetstreamWireError::MalformedFrame(format!("invalid JSON: {e}")))?;
        let Some(root) = root_val.as_object() else {
            return Err(JetstreamWireError::MalformedFrame(
                "frame is not a JSON object".to_owned(),
            ));
        };

        let kind = root.get("kind").and_then(JsonValue::as_str);
        let time_us = positive_integer(root.get("time_us"));
        let did = root.get("did").and_then(JsonValue::as_str);

        let (Some(did), Some(time_us), Some(kind)) = (did, time_us, kind) else {
            return Ok(JetstreamWireFrame::Undecodable {
                r#type: kind.map(str::to_owned),
                seq: time_us,
                reason: "event without did, time_us or kind".to_owned(),
            });
        };

        match kind {
            "commit" => {
                let Some(commit) = root.get("commit").and_then(JsonValue::as_object) else {
                    return Ok(JetstreamWireFrame::Undecodable {
                        r#type: Some("commit".to_owned()),
                        seq: Some(time_us),
                        reason: "commit event without a commit object".to_owned(),
                    });
                };
                match decode_commit_body(commit, time_us, did, time_us) {
                    Ok(ev) => Ok(JetstreamWireFrame::Message(JetstreamEvent::Commit(ev))),
                    Err(reason) => Ok(JetstreamWireFrame::Undecodable {
                        r#type: Some("commit".to_owned()),
                        seq: Some(time_us),
                        reason,
                    }),
                }
            }
            "identity" => Ok(JetstreamWireFrame::Message(JetstreamEvent::Identity(
                JetstreamIdentityEvent {
                    seq: time_us,
                    did: did.to_owned(),
                    time_us,
                    identity: decode_detail(root.get("identity")),
                },
            ))),
            "account" => Ok(JetstreamWireFrame::Message(JetstreamEvent::Account(
                JetstreamAccountEvent {
                    seq: time_us,
                    did: did.to_owned(),
                    time_us,
                    account: decode_detail(root.get("account")),
                },
            ))),
            other => Ok(JetstreamWireFrame::Skipped {
                r#type: Some(other.to_owned()),
                seq: Some(time_us),
            }),
        }
    }

    /// Parses a positive integer cursor/timestamp in `1..=2^53-1`, rejecting floats/bools/strings.
    pub fn positive_integer(value: Option<&JsonValue>) -> Option<i64> {
        positive_integer(value)
    }

    /// Parses an RFC3339 timestamp string into whole Unix microseconds.
    pub fn microseconds_from_rfc3339(input: &str) -> Option<i64> {
        microseconds_from_rfc3339(input)
    }
}

fn decode_v2_payload(payload: &serde_json::Map<String, JsonValue>) -> JetstreamWireFrame {
    let raw_seq = positive_integer(payload.get("seq"));
    let Some(type_str) = payload.get("$type").and_then(JsonValue::as_str) else {
        return JetstreamWireFrame::Undecodable {
            r#type: None,
            seq: raw_seq,
            reason: "payload without $type".to_owned(),
        };
    };
    let Some(name) = type_str.strip_prefix(PAYLOAD_TYPE_PREFIX) else {
        return JetstreamWireFrame::Skipped {
            r#type: Some(type_str.to_owned()),
            seq: raw_seq,
        };
    };

    let envelope_failure = "payload without a valid seq, did or time";
    match name {
        "commit" => {
            let Some((seq, did, time_us)) = decode_envelope(payload) else {
                return JetstreamWireFrame::Undecodable {
                    r#type: Some(name.to_owned()),
                    seq: raw_seq,
                    reason: envelope_failure.to_owned(),
                };
            };
            match decode_commit_body(payload, seq, did, time_us) {
                Ok(ev) => JetstreamWireFrame::Message(JetstreamEvent::Commit(ev)),
                Err(reason) => JetstreamWireFrame::Undecodable {
                    r#type: Some(name.to_owned()),
                    seq: raw_seq,
                    reason,
                },
            }
        }
        "identity" => {
            let Some((seq, did, time_us)) = decode_envelope(payload) else {
                return JetstreamWireFrame::Undecodable {
                    r#type: Some(name.to_owned()),
                    seq: raw_seq,
                    reason: envelope_failure.to_owned(),
                };
            };
            JetstreamWireFrame::Message(JetstreamEvent::Identity(JetstreamIdentityEvent {
                seq,
                did: did.to_owned(),
                time_us,
                identity: decode_detail(payload.get("identity")),
            }))
        }
        "account" => {
            let Some((seq, did, time_us)) = decode_envelope(payload) else {
                return JetstreamWireFrame::Undecodable {
                    r#type: Some(name.to_owned()),
                    seq: raw_seq,
                    reason: envelope_failure.to_owned(),
                };
            };
            JetstreamWireFrame::Message(JetstreamEvent::Account(JetstreamAccountEvent {
                seq,
                did: did.to_owned(),
                time_us,
                account: decode_detail(payload.get("account")),
            }))
        }
        "sync" => {
            let Some((seq, did, time_us)) = decode_envelope(payload) else {
                return JetstreamWireFrame::Undecodable {
                    r#type: Some(name.to_owned()),
                    seq: raw_seq,
                    reason: envelope_failure.to_owned(),
                };
            };
            JetstreamWireFrame::Message(JetstreamEvent::Sync(JetstreamSyncEvent {
                seq,
                did: did.to_owned(),
                time_us,
                sync: decode_detail(payload.get("sync")),
            }))
        }
        "info" => {
            let Some(info_name) = payload.get("name").and_then(JsonValue::as_str) else {
                return JetstreamWireFrame::Undecodable {
                    r#type: Some(name.to_owned()),
                    seq: raw_seq,
                    reason: "info without name".to_owned(),
                };
            };
            JetstreamWireFrame::Message(JetstreamEvent::Info(JetstreamInfoEvent {
                name: info_name.to_owned(),
                message: payload
                    .get("message")
                    .and_then(JsonValue::as_str)
                    .map(str::to_owned),
            }))
        }
        _ => JetstreamWireFrame::Skipped {
            r#type: Some(name.to_owned()),
            seq: raw_seq,
        },
    }
}

fn decode_envelope(payload: &serde_json::Map<String, JsonValue>) -> Option<(i64, &str, i64)> {
    let seq = positive_integer(payload.get("seq"))?;
    let did = payload.get("did").and_then(JsonValue::as_str)?;
    let time = payload.get("time").and_then(JsonValue::as_str)?;
    let time_us = microseconds_from_rfc3339(time)?;
    Some((seq, did, time_us))
}

fn decode_commit_body(
    payload: &serde_json::Map<String, JsonValue>,
    seq: i64,
    did: &str,
    time_us: i64,
) -> Result<JetstreamCommitEvent, String> {
    let rev = payload
        .get("rev")
        .and_then(JsonValue::as_str)
        .ok_or_else(|| "commit without rev".to_owned())?;
    let op_str = payload
        .get("operation")
        .and_then(JsonValue::as_str)
        .ok_or_else(|| "commit without a valid operation".to_owned())?;
    let operation = RelayRepoAction::from_wire(op_str)
        .ok_or_else(|| "commit without a valid operation".to_owned())?;
    let collection = payload
        .get("collection")
        .and_then(JsonValue::as_str)
        .ok_or_else(|| "commit without collection".to_owned())?;
    let rkey = payload
        .get("rkey")
        .and_then(JsonValue::as_str)
        .ok_or_else(|| "commit without rkey".to_owned())?;
    let cid = payload
        .get("cid")
        .and_then(JsonValue::as_str)
        .map(str::to_owned);
    let record_json = payload
        .get("record")
        .filter(|v| !v.is_null())
        .and_then(|v| serde_json::to_vec(v).ok());

    Ok(JetstreamCommitEvent {
        seq,
        did: did.to_owned(),
        time_us,
        rev: rev.to_owned(),
        operation,
        collection: collection.to_owned(),
        rkey: rkey.to_owned(),
        cid,
        record_json,
    })
}

fn decode_detail<T: DeserializeOwned>(value: Option<&JsonValue>) -> Option<T> {
    let val = value?;
    if !val.is_object() {
        return None;
    }
    let bytes = serde_json::to_vec(val).ok()?;
    serde_json::from_slice(&bytes).ok()
}

pub(crate) fn positive_integer(value: Option<&JsonValue>) -> Option<i64> {
    let JsonValue::Number(num) = value? else {
        return None;
    };
    if let Some(i) = num.as_i64() {
        return (1..=MAX_SAFE_JSON_INT).contains(&i).then_some(i);
    }
    if let Some(u) = num.as_u64() {
        let i = i64::try_from(u).ok()?;
        return (1..=MAX_SAFE_JSON_INT).contains(&i).then_some(i);
    }
    // Note: serde_json preserves exact integral floats? Wait: Swift rejects `1000000.5` AND accepts exact integers.
    // Wait: what about `10.0`? In JSON `10.0` is parsed as `f64` by serde_json; if fractional == 0, check if exact int?
    // Actually JSON spec integer timestamps/seqs have no decimal point, or if finite integral float:
    None
}

pub(crate) fn microseconds_from_rfc3339(s: &str) -> Option<i64> {
    // Expected: YYYY-MM-DDTHH:MM:SS[.frac](Z|+HH:MM|-HH:MM)
    let bytes = s.as_bytes();
    if bytes.len() < 20 {
        return None;
    }
    let year: i64 = s.get(0..4)?.parse().ok()?;
    if bytes.get(4) != Some(&b'-') {
        return None;
    }
    let month: u32 = s.get(5..7)?.parse().ok()?;
    if bytes.get(7) != Some(&b'-') {
        return None;
    }
    let day: u32 = s.get(8..10)?.parse().ok()?;
    if !matches!(bytes.get(10), Some(b'T' | b't' | b' ')) {
        return None;
    }
    let hour: u32 = s.get(11..13)?.parse().ok()?;
    if bytes.get(13) != Some(&b':') {
        return None;
    }
    let minute: u32 = s.get(14..16)?.parse().ok()?;
    if bytes.get(16) != Some(&b':') {
        return None;
    }
    let second: u32 = s.get(17..19)?.parse().ok()?;

    if !(1..=12).contains(&month)
        || !(1..=31).contains(&day)
        || hour > 23
        || minute > 59
        || second > 60
    {
        return None;
    }

    let mut idx = 19;
    let mut micros: i64 = 0;
    if bytes.get(idx) == Some(&b'.') {
        idx += 1;
        let frac_start = idx;
        while idx < bytes.len() && bytes[idx].is_ascii_digit() {
            idx += 1;
        }
        let frac_digits = &s[frac_start..idx];
        if frac_digits.is_empty() {
            return None;
        }
        let mut padded = [b'0'; 6];
        for (dst, &src) in padded.iter_mut().zip(frac_digits.as_bytes().iter()) {
            *dst = src;
        }
        let padded_str = std::str::from_utf8(&padded).ok()?;
        micros = padded_str.parse().ok()?;
    }

    let tz_str = &s[idx..];
    let tz_offset_secs: i64 = if tz_str == "Z" || tz_str == "z" {
        0
    } else if tz_str.len() == 6
        && matches!(tz_str.as_bytes()[0], b'+' | b'-')
        && tz_str.as_bytes()[3] == b':'
    {
        let sign: i64 = if tz_str.as_bytes()[0] == b'+' { 1 } else { -1 };
        let off_h: i64 = tz_str[1..3].parse().ok()?;
        let off_m: i64 = tz_str[4..6].parse().ok()?;
        if off_h > 23 || off_m > 59 {
            return None;
        }
        sign * (off_h * 3600 + off_m * 60)
    } else {
        return None;
    };

    let days = days_from_civil(year, month, day);
    let secs = days * 86_400 + i64::from(hour) * 3_600 + i64::from(minute) * 60 + i64::from(second)
        - tz_offset_secs;
    secs.checked_mul(1_000_000)?.checked_add(micros)
}

/// Howard Hinnant's civil-to-days algorithm (days since 1970-01-01).
fn days_from_civil(year: i64, month: u32, day: u32) -> i64 {
    let m = i64::from(month);
    let y = year - i64::from(m <= 2);
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let doy = (153 * (m + if m > 2 { -3 } else { 9 }) + 2) / 5 + i64::from(day) - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}
