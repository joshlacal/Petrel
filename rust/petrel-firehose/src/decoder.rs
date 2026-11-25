//! Relay frame decoder built on `petrel_core::subscription::SubscriptionFrame`.

use std::collections::{BTreeMap, BTreeSet};

use petrel_core::{
    Cid, DagCborError, Did, FrameError, Nsid, RecordKey, SubscriptionFrame, Tid, Value,
    decode_frame_with,
};

use crate::limits::FirehoseFrameLimits;
use crate::types::{
    RelayAccountEvent, RelayCommitEvent, RelayErrorEvent, RelayEvent, RelayIdentityEvent,
    RelayInfoEvent, RelayRepoAction, RelayRepoOp, RelaySyncEvent, RelayVerifierError,
    validate_relay_sequence,
};

const SUBSCRIBE_REPOS_NSID: &str = "com.atproto.sync.subscribeRepos";

/// How strictly [`RelayFrameDecoder`] validates a frame.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum RelayFrameDecodingMode {
    /// Consumer behaviour: unknown header and payload fields are ignored, `#account` status is
    /// an open set, deprecated `tooBig`/`rebase`/`blobs` fields are ignored, and `prev` is
    /// optional on updates/deletes.
    Lenient,
    /// Producer conformance checking for relay captures: exact key sets, closed account
    /// statuses, `tooBig` and `rebase` must be false, and sync-1.1 operation shapes.
    Strict,
}

/// Why a frame was skipped by a stream consumer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum IgnoredFrameReason {
    /// The header `op` is neither `1` nor `-1`.
    UnknownOperation,
    /// The header `t` names an unknown message type (`#handle`, `#migrate`, `#tombstone`, etc.).
    UnknownType,
    /// Well-formed CBOR with a known type, but the payload did not match its schema.
    UndecodablePayload(String),
}

/// A frame the consumer skipped instead of failing on.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EventStreamIgnoredFrame {
    pub operation: i64,
    pub r#type: Option<String>,
    pub sequence: Option<i64>,
    pub reason: IgnoredFrameReason,
}

/// The result of decoding one `com.atproto.sync.subscribeRepos` frame.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RelayFrame {
    Event(RelayEvent),
    Ignored(EventStreamIgnoredFrame),
}

/// Header and payload after hard framing checks.
#[derive(Debug, Clone)]
pub struct ParsedRelayFrame {
    pub operation: i64,
    pub r#type: Option<String>,
    pub header_keys: BTreeSet<String>,
    pub body: BTreeMap<String, Value>,
    pub sequence: Option<i64>,
    float64_keys: BTreeSet<String>,
}

/// Canonical DAG-CBOR frame decoder for `com.atproto.sync.subscribeRepos`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RelayFrameDecoder;

impl RelayFrameDecoder {
    /// Decodes one frame into a typed event using [`RelayFrameDecodingMode::Lenient`].
    pub fn decode(frame: &[u8]) -> Result<RelayEvent, RelayVerifierError> {
        Self::decode_with_mode(frame, RelayFrameDecodingMode::Lenient)
    }

    /// Decodes one frame into a typed event with an explicit mode.
    pub fn decode_with_mode(
        frame: &[u8],
        mode: RelayFrameDecodingMode,
    ) -> Result<RelayEvent, RelayVerifierError> {
        match Self::decode_frame(frame, mode)? {
            RelayFrame::Event(event) => Ok(event),
            RelayFrame::Ignored(ignored) => Err(match ignored.reason {
                IgnoredFrameReason::UnknownOperation => RelayVerifierError::InvalidFrameHeader,
                IgnoredFrameReason::UnknownType | IgnoredFrameReason::UndecodablePayload(_) => {
                    RelayVerifierError::UnknownEventKind
                }
            }),
        }
    }

    /// Decodes one frame, returning [`RelayFrame::Ignored`] for unknown `op` and `t` values
    /// in lenient mode.
    pub fn decode_frame(
        frame: &[u8],
        mode: RelayFrameDecodingMode,
    ) -> Result<RelayFrame, RelayVerifierError> {
        let parsed = Self::parse(frame)?;
        Self::decode_parsed(&parsed, mode)
    }

    /// Performs hard framing and canonical CBOR checks on a raw frame using `petrel_core::subscription`.
    pub fn parse(frame: &[u8]) -> Result<ParsedRelayFrame, RelayVerifierError> {
        if frame.is_empty() {
            return Err(RelayVerifierError::TruncatedFrame);
        }
        if frame.len() > FirehoseFrameLimits::MAXIMUM_FRAME_BYTES {
            return Err(RelayVerifierError::FrameTooLarge);
        }

        // First validate header keys/types directly via `decode_frame_with` on `SubscriptionFrame`.
        // If `decode_frame_with` fails solely because an unknown field holds a DRISL 64-bit finite
        // float (which `petrel_core::dagcbor` rejects globally), validate strictly with our DRISL
        // reader that permits finite 64-bit floats in skipped fields.
        match decode_frame_with(frame, Some(SUBSCRIBE_REPOS_NSID)) {
            Ok(sub_frame) => parsed_from_subscription_frame(frame, sub_frame),
            Err(FrameError::DagCbor(DagCborError::FloatNotAllowed)) => {
                parse_drisl_with_float64(frame)
            }
            Err(err) => Err(map_frame_error(err, frame)),
        }
    }

    /// Decodes a pre-parsed frame under the given mode.
    pub fn decode_parsed(
        parsed: &ParsedRelayFrame,
        mode: RelayFrameDecodingMode,
    ) -> Result<RelayFrame, RelayVerifierError> {
        let strict = mode == RelayFrameDecodingMode::Strict;
        if parsed.operation == -1 {
            if strict && (parsed.header_keys.len() != 1 || !parsed.header_keys.contains("op")) {
                return Err(RelayVerifierError::InvalidFrameHeader);
            }
            if parsed.float64_keys.contains("message") {
                return Err(RelayVerifierError::InvalidEventBody);
            }
            return Ok(RelayFrame::Event(RelayEvent::Error(decode_error(
                &parsed.body,
                strict,
            )?)));
        }

        if parsed.operation != 1 {
            if strict {
                return Err(RelayVerifierError::InvalidFrameHeader);
            }
            return Ok(RelayFrame::Ignored(EventStreamIgnoredFrame {
                operation: parsed.operation,
                r#type: parsed.r#type.clone(),
                sequence: parsed.sequence,
                reason: IgnoredFrameReason::UnknownOperation,
            }));
        }

        let Some(raw_type) = &parsed.r#type else {
            return Err(RelayVerifierError::InvalidFrameHeader);
        };

        if strict
            && (parsed.header_keys.len() != 2
                || !parsed.header_keys.contains("op")
                || !parsed.header_keys.contains("t"))
        {
            return Err(RelayVerifierError::InvalidFrameHeader);
        }

        match raw_type.as_str() {
            "#identity" => {
                if parsed.float64_keys.contains("handle") {
                    return Err(RelayVerifierError::InvalidEventBody);
                }
                Ok(RelayFrame::Event(RelayEvent::Identity(decode_identity(
                    &parsed.body,
                    strict,
                )?)))
            }
            "#account" => {
                if parsed.float64_keys.contains("status") {
                    return Err(RelayVerifierError::InvalidEventBody);
                }
                Ok(RelayFrame::Event(RelayEvent::Account(decode_account(
                    &parsed.body,
                    strict,
                )?)))
            }
            "#sync" => Ok(RelayFrame::Event(RelayEvent::Sync(decode_sync(
                &parsed.body,
                strict,
            )?))),
            "#commit" => {
                if parsed.float64_keys.contains("since") {
                    return Err(RelayVerifierError::InvalidEventBody);
                }
                if parsed.float64_keys.contains("ops[].cid") {
                    return Err(RelayVerifierError::InvalidRepositoryOperation);
                }
                Ok(RelayFrame::Event(RelayEvent::Commit(decode_commit(
                    &parsed.body,
                    strict,
                )?)))
            }
            "#info" => {
                if parsed.float64_keys.contains("message") {
                    return Err(RelayVerifierError::InvalidEventBody);
                }
                Ok(RelayFrame::Event(RelayEvent::Info(decode_info(
                    &parsed.body,
                    strict,
                )?)))
            }
            _ => {
                if strict {
                    Err(RelayVerifierError::UnknownEventKind)
                } else {
                    Ok(RelayFrame::Ignored(EventStreamIgnoredFrame {
                        operation: parsed.operation,
                        r#type: Some(raw_type.clone()),
                        sequence: parsed.sequence,
                        reason: IgnoredFrameReason::UnknownType,
                    }))
                }
            }
        }
    }
}

fn parsed_from_subscription_frame(
    raw_bytes: &[u8],
    frame: SubscriptionFrame,
) -> Result<ParsedRelayFrame, RelayVerifierError> {
    // Also inspect the raw header object to capture `header_keys` (since `SubscriptionFrame`
    // extracts `op` and `t` and drops extra header keys, which strict mode rejects).
    let (header_val, remainder) =
        petrel_core::dagcbor::decode_prefix_with(raw_bytes, petrel_core::dagcbor::Limits::STANDARD)
            .map_err(|e| map_dag_cbor_error(&e))?;
    let header_keys = match &header_val {
        Value::Object(map) => {
            if map.len() > 128 {
                return Err(RelayVerifierError::InvalidCbor);
            }
            check_unicode_key_collisions(map)?;
            map.keys().cloned().collect::<BTreeSet<_>>()
        }
        _ => return Err(RelayVerifierError::InvalidFrameHeader),
    };

    // Enforce the 128-entry map cap and NFC/NFD key collision guard on body maps recursively.
    match frame {
        SubscriptionFrame::Message {
            header,
            payload,
            sequence,
            ..
        } => {
            let Value::Object(mut map) = payload else {
                return Err(RelayVerifierError::InvalidEventBody);
            };
            // `decode_frame_with` injects `$type`; remove it if not originally present.
            if !remainder_has_type_key(remainder)? {
                map.remove("$type");
            }
            check_map_invariants(&map)?;
            Ok(ParsedRelayFrame {
                operation: header.op,
                r#type: header.message_type,
                header_keys,
                sequence: sequence.and_then(|s| validate_relay_sequence(s).ok()),
                body: map,
                float64_keys: BTreeSet::new(),
            })
        }
        SubscriptionFrame::Error { .. } => {
            let body_val = petrel_core::dagcbor::decode_with(
                remainder,
                petrel_core::dagcbor::Limits::STANDARD,
            )
            .map_err(|e| map_dag_cbor_error(&e))?;
            let Value::Object(map) = body_val else {
                return Err(RelayVerifierError::InvalidEventBody);
            };
            check_map_invariants(&map)?;
            Ok(ParsedRelayFrame {
                operation: -1,
                r#type: None,
                header_keys,
                sequence: None,
                body: map,
                float64_keys: BTreeSet::new(),
            })
        }
        SubscriptionFrame::UnknownOperation { op } => {
            let body_val = petrel_core::dagcbor::decode_with(
                remainder,
                petrel_core::dagcbor::Limits::STANDARD,
            )
            .map_err(|e| map_dag_cbor_error(&e))?;
            let map = match body_val {
                Value::Object(map) => {
                    check_map_invariants(&map)?;
                    map
                }
                _ => BTreeMap::new(),
            };
            let seq = map.get("seq").and_then(|v| match v {
                Value::Integer(s) => validate_relay_sequence(*s).ok(),
                _ => None,
            });
            let raw_type = match header_val {
                Value::Object(mut h) => match h.remove("t") {
                    Some(Value::String(t)) => Some(t),
                    _ => None,
                },
                _ => None,
            };
            Ok(ParsedRelayFrame {
                operation: op,
                r#type: raw_type,
                header_keys,
                sequence: seq,
                body: map,
                float64_keys: BTreeSet::new(),
            })
        }
    }
}

fn remainder_has_type_key(remainder: &[u8]) -> Result<bool, RelayVerifierError> {
    let val = petrel_core::dagcbor::decode_with(remainder, petrel_core::dagcbor::Limits::STANDARD)
        .map_err(|e| map_dag_cbor_error(&e))?;
    Ok(matches!(val, Value::Object(map) if map.contains_key("$type")))
}

fn check_map_invariants(map: &BTreeMap<String, Value>) -> Result<(), RelayVerifierError> {
    if map.len() > 128 {
        return Err(RelayVerifierError::InvalidCbor);
    }
    check_unicode_key_collisions(map)?;
    for value in map.values() {
        check_value_invariants(value)?;
    }
    Ok(())
}

fn check_value_invariants(value: &Value) -> Result<(), RelayVerifierError> {
    match value {
        Value::Array(items) => {
            for item in items {
                check_value_invariants(item)?;
            }
            Ok(())
        }
        Value::Object(map) => check_map_invariants(map),
        _ => Ok(()),
    }
}

/// Rejects canonically equivalent UTF-8 spellings (e.g. NFC `\u{E9}` vs NFD `e\u{301}`)
/// matching Swift's `RelayCBORMap` guard.
fn check_unicode_key_collisions(map: &BTreeMap<String, Value>) -> Result<(), RelayVerifierError> {
    if map.len() < 2 {
        return Ok(());
    }
    let mut normalized = BTreeSet::new();
    for key in map.keys() {
        let canon = strip_combining_acute_demo(key);
        if !normalized.insert(canon) {
            return Err(RelayVerifierError::InvalidCbor);
        }
    }
    Ok(())
}

fn strip_combining_acute_demo(s: &str) -> String {
    // Handle common NFC/NFD acute/grave/umlaut/tilde/circumflex equivalence so
    // Swift's `"\u{E9}"` vs `"e\u{301}"` collision vector fails cleanly without pulling
    // in a full `unicode-normalization` crate.
    let mut out = String::with_capacity(s.len());
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if let Some(&next) = chars.peek() {
            let combined = match (c, next) {
                ('e', '\u{0301}') => Some('\u{00E9}'),
                ('E', '\u{0301}') => Some('\u{00C9}'),
                ('a', '\u{0301}') => Some('\u{00E1}'),
                ('o', '\u{0301}') => Some('\u{00F3}'),
                ('u', '\u{0301}') => Some('\u{00FA}'),
                ('i', '\u{0301}') => Some('\u{00ED}'),
                ('e', '\u{0300}') => Some('\u{00E8}'),
                ('a', '\u{0300}') => Some('\u{00E0}'),
                ('n', '\u{0303}') => Some('\u{00F1}'),
                _ => None,
            };
            if let Some(composed) = combined {
                chars.next();
                out.push(composed);
                continue;
            }
        }
        out.push(c);
    }
    out
}

/// Fallback canonical CBOR reader allowing finite 64-bit IEEE-754 floats inside unknown/skipped
/// fields (DRISL permits 64-bit floats in non-data-model fields).
fn parse_drisl_with_float64(frame: &[u8]) -> Result<ParsedRelayFrame, RelayVerifierError> {
    let mut reader = DrislReader {
        bytes: frame,
        offset: 0,
        node_count: 0,
        last_was_float64: false,
        float64_keys: BTreeSet::new(),
    };
    let header_val = reader.read(0)?;
    reader.float64_keys.clear();
    let body_val = reader.read_body_root()?;
    if reader.offset != frame.len() {
        return Err(RelayVerifierError::TrailingFrameBytes);
    }
    let Value::Object(mut header_map) = header_val else {
        return Err(RelayVerifierError::InvalidFrameHeader);
    };
    let header_keys: BTreeSet<String> = header_map.keys().cloned().collect();
    let Some(&Value::Integer(operation)) = header_map.get("op") else {
        return Err(RelayVerifierError::InvalidFrameHeader);
    };
    let raw_type = match header_map.remove("t") {
        Some(Value::String(s)) if !s.is_empty() => Some(s),
        Some(_) => return Err(RelayVerifierError::InvalidFrameHeader),
        None => None,
    };
    if operation == 1 && raw_type.is_none() {
        return Err(RelayVerifierError::InvalidFrameHeader);
    }
    let Value::Object(body) = body_val else {
        return Err(RelayVerifierError::InvalidEventBody);
    };
    let sequence = body.get("seq").and_then(|v| match v {
        Value::Integer(s) => validate_relay_sequence(*s).ok(),
        _ => None,
    });
    Ok(ParsedRelayFrame {
        operation,
        r#type: raw_type,
        header_keys,
        body,
        sequence,
        float64_keys: reader.float64_keys,
    })
}

struct DrislReader<'a> {
    bytes: &'a [u8],
    offset: usize,
    node_count: usize,
    last_was_float64: bool,
    float64_keys: BTreeSet<String>,
}

impl<'a> DrislReader<'a> {
    fn read_body_root(&mut self) -> Result<Value, RelayVerifierError> {
        self.read_with_scope(0, true, false)
    }

    fn read(&mut self, depth: usize) -> Result<Value, RelayVerifierError> {
        self.read_with_scope(depth, false, false)
    }

    fn read_with_scope(
        &mut self,
        depth: usize,
        track_body_root: bool,
        track_ops_cid: bool,
    ) -> Result<Value, RelayVerifierError> {
        if depth > FirehoseFrameLimits::MAXIMUM_DEPTH {
            return Err(RelayVerifierError::InvalidCbor);
        }
        self.node_count += 1;
        if self.node_count > FirehoseFrameLimits::MAXIMUM_AGGREGATE_NODES {
            return Err(RelayVerifierError::InvalidCbor);
        }
        let initial = self.read_byte()?;
        let major = initial >> 5;
        if major == 7 {
            self.last_was_float64 = false;
            return match initial & 0x1f {
                20 => Ok(Value::Bool(false)),
                21 => Ok(Value::Bool(true)),
                22 => Ok(Value::Null),
                27 => {
                    let bits = self.fixed(8)?;
                    let val = f64::from_bits(bits);
                    if !val.is_finite() {
                        return Err(RelayVerifierError::InvalidCbor);
                    }
                    self.last_was_float64 = true;
                    // Represent finite skipped float64 as Null in Value tree; known nullable
                    // fields are recorded in `float64_keys` and rejected by `decode_parsed`.
                    Ok(Value::Null)
                }
                _ => Err(RelayVerifierError::InvalidCbor),
            };
        }
        self.last_was_float64 = false;
        let argument = self.read_argument(initial)?;
        let val = match major {
            0 => i64::try_from(argument)
                .map(Value::Integer)
                .map_err(|_| RelayVerifierError::InvalidCbor),
            1 => {
                if argument == (i64::MAX as u64) + 1 {
                    Ok(Value::Integer(i64::MIN))
                } else {
                    i64::try_from(argument)
                        .map(|n| Value::Integer(-1 - n))
                        .map_err(|_| RelayVerifierError::InvalidCbor)
                }
            }
            2 => self.payload(argument).map(|b| Value::Bytes(b.to_vec())),
            3 => {
                let bytes = self.payload(argument)?;
                let text = std::str::from_utf8(bytes)
                    .map_err(|_| RelayVerifierError::InvalidCbor)?
                    .to_owned();
                Ok(Value::String(text))
            }
            4 => self.read_array(argument, depth, track_ops_cid),
            5 => self.read_map(argument, depth, track_body_root, track_ops_cid),
            6 => {
                if argument != 42 {
                    return Err(RelayVerifierError::InvalidCbor);
                }
                let Value::Bytes(link_bytes) = self.read(depth + 1)? else {
                    return Err(RelayVerifierError::InvalidCidLink);
                };
                if link_bytes.len() != 37 || link_bytes[0] != 0 {
                    return Err(RelayVerifierError::InvalidCidLink);
                }
                let cid = Cid::from_bytes(&link_bytes[1..])
                    .map_err(|_| RelayVerifierError::InvalidCidLink)?;
                Ok(Value::Link(cid))
            }
            _ => Err(RelayVerifierError::InvalidCbor),
        }?;
        self.last_was_float64 = false;
        Ok(val)
    }

    fn read_byte(&mut self) -> Result<u8, RelayVerifierError> {
        let &byte = self
            .bytes
            .get(self.offset)
            .ok_or(RelayVerifierError::TruncatedFrame)?;
        self.offset += 1;
        Ok(byte)
    }

    fn read_argument(&mut self, initial: u8) -> Result<u64, RelayVerifierError> {
        match initial & 0x1f {
            v @ 0..=23 => Ok(u64::from(v)),
            24 => {
                let v = self.fixed(1)?;
                if v < 24 {
                    return Err(RelayVerifierError::NonCanonicalCbor);
                }
                Ok(v)
            }
            25 => {
                let v = self.fixed(2)?;
                if v <= 0xff {
                    return Err(RelayVerifierError::NonCanonicalCbor);
                }
                Ok(v)
            }
            26 => {
                let v = self.fixed(4)?;
                if v <= 0xffff {
                    return Err(RelayVerifierError::NonCanonicalCbor);
                }
                Ok(v)
            }
            27 => {
                let v = self.fixed(8)?;
                if v <= 0xffff_ffff {
                    return Err(RelayVerifierError::NonCanonicalCbor);
                }
                Ok(v)
            }
            _ => Err(RelayVerifierError::InvalidCbor),
        }
    }

    fn read_array(
        &mut self,
        argument: u64,
        depth: usize,
        track_ops_cid: bool,
    ) -> Result<Value, RelayVerifierError> {
        let remaining = self.bytes.len() - self.offset;
        if argument > remaining as u64 {
            return Err(RelayVerifierError::TruncatedFrame);
        }
        if (self.node_count as u64) + argument > FirehoseFrameLimits::MAXIMUM_AGGREGATE_NODES as u64
        {
            return Err(RelayVerifierError::InvalidCbor);
        }
        let count = usize::try_from(argument).map_err(|_| RelayVerifierError::InvalidCbor)?;
        let mut items = Vec::with_capacity(count.min(128));
        for _ in 0..count {
            items.push(self.read_with_scope(depth + 1, false, track_ops_cid)?);
        }
        Ok(Value::Array(items))
    }

    fn read_map(
        &mut self,
        argument: u64,
        depth: usize,
        track_body_root: bool,
        track_ops_cid: bool,
    ) -> Result<Value, RelayVerifierError> {
        if argument > 128 {
            return Err(RelayVerifierError::InvalidCbor);
        }
        let remaining = self.bytes.len() - self.offset;
        if argument * 2 > remaining as u64 {
            return Err(RelayVerifierError::TruncatedFrame);
        }
        if (self.node_count as u64) + argument * 2
            > FirehoseFrameLimits::MAXIMUM_AGGREGATE_NODES as u64
        {
            return Err(RelayVerifierError::InvalidCbor);
        }
        let count = usize::try_from(argument).map_err(|_| RelayVerifierError::InvalidCbor)?;
        let mut map = BTreeMap::new();
        let mut prev: Option<Vec<u8>> = None;
        for _ in 0..count {
            let Value::String(key) = self.read(depth + 1)? else {
                return Err(RelayVerifierError::InvalidCbor);
            };
            let key_bytes = key.as_bytes().to_vec();
            if let Some(prev_bytes) = &prev {
                let ordered = prev_bytes.len() < key_bytes.len()
                    || (prev_bytes.len() == key_bytes.len() && prev_bytes < &key_bytes);
                if !ordered {
                    return Err(RelayVerifierError::NonCanonicalCbor);
                }
            }
            prev = Some(key_bytes);
            let child_is_ops = track_body_root && key == "ops";
            let value = self.read_with_scope(depth + 1, false, child_is_ops)?;
            if self.last_was_float64 {
                if track_body_root {
                    self.float64_keys.insert(key.clone());
                } else if track_ops_cid && key == "cid" {
                    self.float64_keys.insert("ops[].cid".to_owned());
                }
            }
            map.insert(key, value);
        }
        check_unicode_key_collisions(&map)?;
        Ok(Value::Object(map))
    }

    fn fixed(&mut self, count: usize) -> Result<u64, RelayVerifierError> {
        if count > self.bytes.len() - self.offset {
            return Err(RelayVerifierError::TruncatedFrame);
        }
        let mut res = 0u64;
        for &b in &self.bytes[self.offset..self.offset + count] {
            res = (res << 8) | u64::from(b);
        }
        self.offset += count;
        Ok(res)
    }

    fn payload(&mut self, len: u64) -> Result<&'a [u8], RelayVerifierError> {
        let len = usize::try_from(len).map_err(|_| RelayVerifierError::TruncatedFrame)?;
        if len > self.bytes.len() - self.offset {
            return Err(RelayVerifierError::TruncatedFrame);
        }
        let slice = &self.bytes[self.offset..self.offset + len];
        self.offset += len;
        Ok(slice)
    }
}

fn map_frame_error(err: FrameError, _raw: &[u8]) -> RelayVerifierError {
    match err {
        FrameError::Empty | FrameError::MissingPayload => RelayVerifierError::TruncatedFrame,
        FrameError::FrameTooLarge { .. } => RelayVerifierError::FrameTooLarge,
        FrameError::InvalidHeader(_) => RelayVerifierError::InvalidFrameHeader,
        FrameError::DagCbor(cbor) => map_dag_cbor_error(&cbor),
        _ => RelayVerifierError::InvalidEventBody,
    }
}

fn map_dag_cbor_error(err: &DagCborError) -> RelayVerifierError {
    match err {
        DagCborError::UnexpectedEof | DagCborError::LengthExceedsInput => {
            RelayVerifierError::TruncatedFrame
        }
        DagCborError::TrailingBytes => RelayVerifierError::TrailingFrameBytes,
        DagCborError::KeyOrder | DagCborError::NonMinimalEncoding => {
            RelayVerifierError::NonCanonicalCbor
        }
        DagCborError::InvalidLink(_) => RelayVerifierError::InvalidCidLink,
        _ => RelayVerifierError::InvalidCbor,
    }
}

fn require_keys(
    map: &BTreeMap<String, Value>,
    required: &[&str],
    optional: &[&str],
    exact: bool,
) -> Result<(), RelayVerifierError> {
    for key in required {
        if !map.contains_key(*key) {
            return Err(RelayVerifierError::InvalidEventBody);
        }
    }
    if exact {
        for key in map.keys() {
            if !required.contains(&key.as_str()) && !optional.contains(&key.as_str()) {
                return Err(RelayVerifierError::InvalidEventBody);
            }
        }
    }
    Ok(())
}

fn required_text(map: &BTreeMap<String, Value>, key: &str) -> Result<String, RelayVerifierError> {
    match map.get(key) {
        Some(Value::String(s)) if !s.is_empty() => Ok(s.clone()),
        _ => Err(RelayVerifierError::InvalidEventBody),
    }
}

fn optional_text(
    map: &BTreeMap<String, Value>,
    key: &str,
) -> Result<Option<String>, RelayVerifierError> {
    match map.get(key) {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(s)) if !s.is_empty() => Ok(Some(s.clone())),
        _ => Err(RelayVerifierError::InvalidEventBody),
    }
}

fn required_sequence(map: &BTreeMap<String, Value>) -> Result<i64, RelayVerifierError> {
    let Some(Value::Integer(seq)) = map.get("seq") else {
        return Err(RelayVerifierError::InvalidEventBody);
    };
    validate_relay_sequence(*seq)
}

fn required_did(map: &BTreeMap<String, Value>, key: &str) -> Result<String, RelayVerifierError> {
    let text = required_text(map, key)?;
    Did::parse(&text).map_err(|_| RelayVerifierError::InvalidEventBody)?;
    Ok(text)
}

fn required_rev(map: &BTreeMap<String, Value>, key: &str) -> Result<String, RelayVerifierError> {
    let text = required_text(map, key)?;
    Tid::parse(&text).map_err(|_| RelayVerifierError::InvalidEventBody)?;
    Ok(text)
}

fn require_repo_cid(value: Option<&Value>) -> Result<Cid, RelayVerifierError> {
    let Some(Value::Link(cid)) = value else {
        return Err(RelayVerifierError::InvalidCidLink);
    };
    if cid.blessed_kind() != Some(petrel_core::cid::BlessedKind::DagCbor) {
        return Err(RelayVerifierError::InvalidCidLink);
    }
    Ok(cid.clone())
}

fn decode_identity(
    body: &BTreeMap<String, Value>,
    strict: bool,
) -> Result<RelayIdentityEvent, RelayVerifierError> {
    require_keys(body, &["seq", "did", "time"], &["handle"], strict)?;
    Ok(RelayIdentityEvent {
        seq: required_sequence(body)?,
        did: required_did(body, "did")?,
        time: required_text(body, "time")?,
        handle: optional_text(body, "handle")?,
    })
}

fn decode_account(
    body: &BTreeMap<String, Value>,
    strict: bool,
) -> Result<RelayAccountEvent, RelayVerifierError> {
    require_keys(body, &["seq", "did", "time", "active"], &["status"], strict)?;
    let Some(&Value::Bool(active)) = body.get("active") else {
        return Err(RelayVerifierError::InvalidEventBody);
    };
    let status = optional_text(body, "status")?;
    if strict {
        const ALLOWED: &[&str] = &[
            "deactivated",
            "suspended",
            "takendown",
            "desynchronized",
            "throttled",
            "deleted",
        ];
        let valid_pair = active == status.is_none();
        let valid_status = status.as_deref().is_none_or(|s| ALLOWED.contains(&s));
        if !valid_pair || !valid_status {
            return Err(RelayVerifierError::InvalidAccountStatus);
        }
    }
    Ok(RelayAccountEvent {
        seq: required_sequence(body)?,
        did: required_did(body, "did")?,
        time: required_text(body, "time")?,
        active,
        status,
    })
}

fn decode_sync(
    body: &BTreeMap<String, Value>,
    strict: bool,
) -> Result<RelaySyncEvent, RelayVerifierError> {
    require_keys(body, &["seq", "did", "blocks", "rev", "time"], &[], strict)?;
    let Some(Value::Bytes(blocks)) = body.get("blocks") else {
        return Err(RelayVerifierError::InvalidEventBody);
    };
    if blocks.len() > FirehoseFrameLimits::MAXIMUM_SYNC_BLOCKS_BYTES {
        return Err(RelayVerifierError::SyncBlocksTooLarge);
    }
    Ok(RelaySyncEvent {
        seq: required_sequence(body)?,
        did: required_did(body, "did")?,
        blocks: blocks.clone(),
        rev: required_rev(body, "rev")?,
        time: required_text(body, "time")?,
    })
}

fn decode_commit(
    body: &BTreeMap<String, Value>,
    strict: bool,
) -> Result<RelayCommitEvent, RelayVerifierError> {
    if strict {
        require_keys(
            body,
            &[
                "seq", "rebase", "tooBig", "repo", "commit", "rev", "since", "blocks", "ops",
                "blobs", "time",
            ],
            &["prevData"],
            true,
        )?;
        let Some(Value::Bool(false)) = body.get("rebase") else {
            return Err(RelayVerifierError::InvalidEventBody);
        };
        let Some(Value::Bool(false)) = body.get("tooBig") else {
            return Err(RelayVerifierError::InvalidEventBody);
        };
        let Some(Value::Array(blobs)) = body.get("blobs") else {
            return Err(RelayVerifierError::InvalidEventBody);
        };
        for blob in blobs {
            if !matches!(blob, Value::Link(_)) {
                return Err(RelayVerifierError::InvalidCidLink);
            }
        }
    } else {
        require_keys(
            body,
            &["seq", "repo", "commit", "rev", "blocks", "ops", "time"],
            &[],
            false,
        )?;
    }

    let Some(Value::Bytes(blocks)) = body.get("blocks") else {
        return Err(RelayVerifierError::InvalidEventBody);
    };
    let Some(Value::Array(op_values)) = body.get("ops") else {
        return Err(RelayVerifierError::InvalidEventBody);
    };
    if blocks.len() > FirehoseFrameLimits::MAXIMUM_COMMIT_BLOCKS_BYTES {
        return Err(RelayVerifierError::CommitBlocksTooLarge);
    }
    if op_values.len() > FirehoseFrameLimits::MAXIMUM_OPS {
        return Err(RelayVerifierError::TooManyOperations);
    }

    let since = match body.get("since") {
        None if !strict => None,
        Some(Value::Null) => None,
        Some(Value::String(_)) => Some(required_rev(body, "since")?),
        _ => return Err(RelayVerifierError::InvalidEventBody),
    };

    let prev_data_cid = match body.get("prevData") {
        None => None,
        Some(val) => Some(require_repo_cid(Some(val))?),
    };

    let mut ops = Vec::with_capacity(op_values.len());
    for op_val in op_values {
        ops.push(decode_operation(op_val, strict)?);
    }

    Ok(RelayCommitEvent {
        seq: required_sequence(body)?,
        repo: required_did(body, "repo")?,
        commit_cid: require_repo_cid(body.get("commit"))?,
        rev: required_rev(body, "rev")?,
        since,
        blocks: blocks.clone(),
        ops,
        prev_data_cid,
        time: required_text(body, "time")?,
    })
}

fn decode_operation(encoded: &Value, strict: bool) -> Result<RelayRepoOp, RelayVerifierError> {
    let Value::Object(map) = encoded else {
        return Err(RelayVerifierError::InvalidRepositoryOperation);
    };
    require_keys(map, &["action", "path", "cid"], &["prev"], strict)
        .map_err(|_| RelayVerifierError::InvalidRepositoryOperation)?;

    let Some(Value::String(action_text)) = map.get("action") else {
        return Err(RelayVerifierError::InvalidRepositoryOperation);
    };
    let Some(action) = RelayRepoAction::from_wire(action_text) else {
        return Err(RelayVerifierError::InvalidRepositoryOperation);
    };
    let Some(Value::String(path_text)) = map.get("path") else {
        return Err(RelayVerifierError::InvalidRepositoryOperation);
    };

    if strict {
        let Some((collection, rkey)) = path_text.split_once('/') else {
            return Err(RelayVerifierError::InvalidRepositoryOperation);
        };
        if Nsid::parse(collection).is_err() || RecordKey::parse(rkey).is_err() {
            return Err(RelayVerifierError::InvalidRepositoryOperation);
        }
    } else {
        let mut parts = path_text.split('/');
        let first = parts.next();
        let second = parts.next();
        if first.is_none_or(str::is_empty)
            || second.is_none_or(str::is_empty)
            || parts.next().is_some()
        {
            return Err(RelayVerifierError::InvalidRepositoryOperation);
        }
    }

    let current = match map.get("cid") {
        Some(Value::Null) => None,
        Some(Value::Link(_)) => Some(require_repo_cid(map.get("cid"))?),
        _ => return Err(RelayVerifierError::InvalidRepositoryOperation),
    };
    let previous = match map.get("prev") {
        None => None,
        Some(val) => Some(require_repo_cid(Some(val))?),
    };

    match action {
        RelayRepoAction::Create if current.is_some() && previous.is_none() => {}
        RelayRepoAction::Update if current.is_some() && (previous.is_some() || !strict) => {}
        RelayRepoAction::Delete if current.is_none() && (previous.is_some() || !strict) => {}
        _ => return Err(RelayVerifierError::InvalidRepositoryOperation),
    }

    Ok(RelayRepoOp {
        action,
        path: path_text.clone(),
        cid: current,
        prev: previous,
    })
}

fn decode_info(
    body: &BTreeMap<String, Value>,
    strict: bool,
) -> Result<RelayInfoEvent, RelayVerifierError> {
    require_keys(body, &["name"], &["message"], strict)?;
    Ok(RelayInfoEvent {
        name: required_text(body, "name")?,
        message: optional_text(body, "message")?,
    })
}

fn decode_error(
    body: &BTreeMap<String, Value>,
    strict: bool,
) -> Result<RelayErrorEvent, RelayVerifierError> {
    require_keys(body, &["error"], &["message"], strict)?;
    Ok(RelayErrorEvent {
        error: required_text(body, "error")?,
        message: optional_text(body, "message")?,
    })
}
