//! Framing for AT Protocol event-stream WebSocket subscriptions.
//!
//! Supports both standard concatenated canonical DAG-CBOR framing (two objects:
//! `{"op": 1, "t": ...}` / `{"op": -1}` followed by payload) and the
//! `xrpc.v1.json` JSON envelope subprotocol (`{"$type": "message", "payload": ...}`
//! / `{"$type": "error", ...}`).

use std::collections::BTreeMap;

use crate::dagcbor::{self, Limits};
use crate::error::{DagCborError, DecodeError, EncodeError};
use crate::serde_bridge::{FromValue, ToValue};
use crate::value::Value;
use crate::xrpc::{DeclaredXrpcError, XRPC_V1_JSON_SUBPROTOCOL, XrpcSubscription};

/// Hard upper bound for a single event-stream WebSocket frame (5 MB).
pub const MAXIMUM_FRAME_BYTES: usize = 5_000_000;

/// Errors produced when decoding or encoding a subscription WebSocket frame.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum FrameError {
    /// The WebSocket frame was empty.
    #[error("empty WebSocket subscription frame")]
    Empty,
    /// The WebSocket frame exceeded [`MAXIMUM_FRAME_BYTES`].
    #[error("WebSocket subscription frame ({len} bytes) exceeds {max}-byte limit")]
    FrameTooLarge {
        /// Frame length in bytes.
        len: usize,
        /// Configured upper bound in bytes.
        max: usize,
    },
    /// Header or payload failed canonical DAG-CBOR validation.
    #[error(transparent)]
    DagCbor(#[from] DagCborError),
    /// Frame header was malformed or missing required fields.
    #[error("invalid subscription frame header: {0}")]
    InvalidHeader(&'static str),
    /// Frame lacked its payload DAG-CBOR object.
    #[error("missing payload in WebSocket subscription frame")]
    MissingPayload,
    /// Frame payload did not match the expected shape.
    #[error("invalid subscription frame payload: {0}")]
    InvalidPayload(&'static str),
    /// Subscription declared a WebSocket subprotocol that this codec does not support.
    #[error("unsupported subscription subprotocol `{0}`")]
    UnsupportedSubprotocol(&'static str),
    /// Typed subscription message decoding failed.
    #[error(transparent)]
    Decode(#[from] DecodeError),
    /// Typed subscription message encoding failed.
    #[error(transparent)]
    Encode(#[from] EncodeError),
}

/// Parsed DAG-CBOR header of a subscription WebSocket frame.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FrameHeader {
    /// Operation code (`1` = message, `-1` = error, other = unknown).
    pub op: i64,
    /// Message type discriminator (`t` header field), present for `op: 1`.
    pub message_type: Option<String>,
}

impl FrameHeader {
    /// Creates a regular message header (`op: 1`, `t: message_type`).
    pub fn message(message_type: impl Into<String>) -> Self {
        Self {
            op: 1,
            message_type: Some(message_type.into()),
        }
    }

    /// Creates an error frame header (`op: -1`).
    pub fn error() -> Self {
        Self {
            op: -1,
            message_type: None,
        }
    }
}

/// What one binary event-stream WebSocket frame contains.
#[derive(Debug, Clone, PartialEq)]
pub enum SubscriptionFrame {
    /// Regular message (`op: 1`). Payload has `$type` set to `message_type`.
    Message {
        /// Parsed frame header.
        header: FrameHeader,
        /// Fully-resolved message type (prefixed with `default_lexicon` when `t` begins with `#`).
        message_type: String,
        /// Decoded payload object with `$type` set to `message_type`.
        payload: Value,
        /// Payload `seq` field when present and an integer; `None` for unsequenced frames like `#info`.
        sequence: Option<i64>,
    },
    /// Error frame (`op: -1`). The stream must be closed after receiving this frame.
    Error {
        /// Wire error name.
        error: String,
        /// Optional human-readable error message.
        message: Option<String>,
    },
    /// Unrecognized `op` code; callers following the spec should ignore the frame.
    UnknownOperation {
        /// Unrecognized operation code.
        op: i64,
    },
}

/// Typed outcome of decoding one frame for a generated [`XrpcSubscription`].
#[derive(Debug, Clone, PartialEq)]
pub enum DecodedSubscriptionFrame<M, E> {
    /// Recognized message decoded into the subscription's typed `Message`.
    Message {
        /// Decoded typed message.
        message: M,
        /// Fully-qualified message `$type`.
        message_type: String,
        /// Payload `seq` field when present.
        sequence: Option<i64>,
    },
    /// Error frame (`op: -1`) mapped through the subscription's `Error` enum.
    Error {
        /// Mapped declared or unknown error.
        error: E,
        /// Optional human-readable message.
        message: Option<String>,
    },
    /// Unrecognized `op` code; callers should skip it.
    UnknownOperation {
        /// Unrecognized operation code.
        op: i64,
    },
    /// Regular message frame (`op: 1`) whose `message_type` is not in
    /// [`XrpcSubscription::KNOWN_MESSAGE_TYPES`]; callers should skip it.
    UnknownMessageType {
        /// Fully-qualified message `$type`.
        message_type: String,
        /// Decoded payload value.
        payload: Value,
        /// Payload `seq` field when present.
        sequence: Option<i64>,
    },
}

/// Decodes a binary subscription frame without a default lexicon prefix.
pub fn decode_frame(bytes: &[u8]) -> Result<SubscriptionFrame, FrameError> {
    decode_frame_with(bytes, None)
}

/// Decodes a binary subscription frame, resolving `#fragment` `t` headers with
/// `default_lexicon` when supplied.
pub fn decode_frame_with(
    bytes: &[u8],
    default_lexicon: Option<&str>,
) -> Result<SubscriptionFrame, FrameError> {
    if bytes.is_empty() {
        return Err(FrameError::Empty);
    }
    if bytes.len() > MAXIMUM_FRAME_BYTES {
        return Err(FrameError::FrameTooLarge {
            len: bytes.len(),
            max: MAXIMUM_FRAME_BYTES,
        });
    }

    let (header_value, remainder) = dagcbor::decode_prefix_with(bytes, Limits::STANDARD)?;
    let Value::Object(header_map) = header_value else {
        return Err(FrameError::InvalidHeader("header must be a CBOR map"));
    };
    let Some(Value::Integer(op)) = header_map.get("op") else {
        return Err(FrameError::InvalidHeader("missing or non-integer 'op'"));
    };
    let op = *op;

    match op {
        -1 => {
            if remainder.is_empty() {
                return Err(FrameError::MissingPayload);
            }
            let payload_value = dagcbor::decode_with(remainder, Limits::STANDARD)?;
            let Value::Object(error_map) = payload_value else {
                return Err(FrameError::InvalidPayload(
                    "error payload must be a CBOR map",
                ));
            };
            let Some(Value::String(error)) = error_map.get("error") else {
                return Err(FrameError::InvalidPayload(
                    "error payload missing string 'error'",
                ));
            };
            let message = match error_map.get("message") {
                Some(Value::String(text)) => Some(text.clone()),
                _ => None,
            };
            Ok(SubscriptionFrame::Error {
                error: error.clone(),
                message,
            })
        }
        1 => {
            let Some(Value::String(raw_type)) = header_map.get("t") else {
                return Err(FrameError::InvalidHeader("missing string 't' in header"));
            };
            if raw_type.is_empty() {
                return Err(FrameError::InvalidHeader("empty 't' in header"));
            }
            if remainder.is_empty() {
                return Err(FrameError::MissingPayload);
            }
            let payload_value = dagcbor::decode_with(remainder, Limits::STANDARD)?;
            let Value::Object(mut payload_map) = payload_value else {
                return Err(FrameError::InvalidPayload(
                    "message payload must be a CBOR map",
                ));
            };
            let resolved_type = resolve_message_type(raw_type, default_lexicon);
            let sequence = match payload_map.get("seq") {
                Some(Value::Integer(seq)) => Some(*seq),
                _ => None,
            };
            payload_map.insert("$type".to_owned(), Value::String(resolved_type.clone()));
            Ok(SubscriptionFrame::Message {
                header: FrameHeader {
                    op: 1,
                    message_type: Some(raw_type.clone()),
                },
                message_type: resolved_type,
                payload: Value::Object(payload_map),
                sequence,
            })
        }
        other => Ok(SubscriptionFrame::UnknownOperation { op: other }),
    }
}

/// Encodes a [`SubscriptionFrame`] as two concatenated canonical DAG-CBOR objects.
pub fn encode_frame(frame: &SubscriptionFrame) -> Result<Vec<u8>, FrameError> {
    let (header_value, payload_value) = match frame {
        SubscriptionFrame::Message {
            header,
            message_type,
            payload,
            ..
        } => {
            if header.op != 1 {
                return Err(FrameError::InvalidHeader(
                    "message frame header must have op = 1",
                ));
            }
            let wire_type = header
                .message_type
                .as_deref()
                .unwrap_or(message_type.as_str());
            if wire_type.is_empty() {
                return Err(FrameError::InvalidHeader("empty 't' in message header"));
            }
            if !matches!(payload, Value::Object(_)) {
                return Err(FrameError::InvalidPayload(
                    "message payload must be a CBOR map",
                ));
            }
            let header_map = BTreeMap::from([
                ("op".to_owned(), Value::Integer(1)),
                ("t".to_owned(), Value::String(wire_type.to_owned())),
            ]);
            (Value::Object(header_map), payload.clone())
        }
        SubscriptionFrame::Error { error, message } => {
            let header_map = BTreeMap::from([("op".to_owned(), Value::Integer(-1))]);
            let mut payload_map =
                BTreeMap::from([("error".to_owned(), Value::String(error.clone()))]);
            if let Some(text) = message {
                payload_map.insert("message".to_owned(), Value::String(text.clone()));
            }
            (Value::Object(header_map), Value::Object(payload_map))
        }
        SubscriptionFrame::UnknownOperation { op } => {
            if *op == 1 || *op == -1 {
                return Err(FrameError::InvalidHeader(
                    "unknown operation cannot use reserved op 1 or -1",
                ));
            }
            let header_map = BTreeMap::from([("op".to_owned(), Value::Integer(*op))]);
            (Value::Object(header_map), Value::Object(BTreeMap::new()))
        }
    };

    let mut out = dagcbor::encode(&header_value);
    out.extend_from_slice(&dagcbor::encode(&payload_value));
    if out.len() > MAXIMUM_FRAME_BYTES {
        return Err(FrameError::FrameTooLarge {
            len: out.len(),
            max: MAXIMUM_FRAME_BYTES,
        });
    }
    Ok(out)
}

/// Decodes one WebSocket frame into a typed [`XrpcSubscription`] message or error,
/// dispatching by [`XrpcSubscription::SUBPROTOCOL`] (standard concatenated
/// DAG-CBOR when `None`, or `xrpc.v1.json` JSON envelopes when
/// `Some("xrpc.v1.json")`).
pub fn decode_subscription_frame<S: XrpcSubscription>(
    bytes: &[u8],
) -> Result<DecodedSubscriptionFrame<S::Message, S::Error>, FrameError>
where
    S::Message: FromValue,
{
    match S::SUBPROTOCOL {
        None => decode_dag_cbor_subscription_frame::<S>(bytes),
        Some(XRPC_V1_JSON_SUBPROTOCOL) => decode_json_subscription_frame::<S>(bytes),
        Some(other) => Err(FrameError::UnsupportedSubprotocol(other)),
    }
}

/// Encodes a typed [`XrpcSubscription`] message into a framed wire message
/// matching [`XrpcSubscription::SUBPROTOCOL`] (concatenated DAG-CBOR when
/// `None`, or `xrpc.v1.json` JSON envelope when `Some("xrpc.v1.json")`).
pub fn encode_subscription_message<S: XrpcSubscription>(
    message: &S::Message,
) -> Result<Vec<u8>, FrameError>
where
    S::Message: ToValue,
{
    match S::SUBPROTOCOL {
        None => {
            let mut value = message.to_value()?;
            let Value::Object(ref mut map) = value else {
                return Err(FrameError::InvalidPayload(
                    "subscription message must encode as an object",
                ));
            };
            let Some(Value::String(full_type)) = map.remove("$type") else {
                return Err(FrameError::InvalidHeader(
                    "subscription message is missing `$type`",
                ));
            };
            let wire_type = full_type
                .strip_prefix(S::NSID)
                .filter(|suffix| suffix.starts_with('#'))
                .unwrap_or(full_type.as_str())
                .to_owned();
            encode_frame(&SubscriptionFrame::Message {
                header: FrameHeader::message(wire_type.clone()),
                message_type: wire_type,
                payload: value,
                sequence: None,
            })
        }
        Some(XRPC_V1_JSON_SUBPROTOCOL) => {
            let mut value = message.to_value()?;
            let Value::Object(ref mut map) = value else {
                return Err(FrameError::InvalidPayload(
                    "subscription message must encode as an object",
                ));
            };
            let Some(Value::String(raw_type)) = map.get("$type").cloned() else {
                return Err(FrameError::InvalidPayload(
                    "subscription message is missing `$type`",
                ));
            };
            if raw_type.is_empty() {
                return Err(FrameError::InvalidPayload(
                    "subscription message has empty `$type`",
                ));
            }
            let full_type = resolve_message_type(&raw_type, Some(S::NSID));
            map.insert("$type".to_owned(), Value::String(full_type));
            let envelope = Value::Object(BTreeMap::from([
                ("$type".to_owned(), Value::String("message".to_owned())),
                ("payload".to_owned(), value),
            ]));
            encode_json_frame(&envelope)
        }
        Some(other) => Err(FrameError::UnsupportedSubprotocol(other)),
    }
}

/// Encodes a [`XrpcSubscription`] error frame matching
/// [`XrpcSubscription::SUBPROTOCOL`].
pub fn encode_subscription_error<S: XrpcSubscription>(
    error: &S::Error,
    message: Option<&str>,
) -> Result<Vec<u8>, FrameError> {
    match S::SUBPROTOCOL {
        None => encode_frame(&SubscriptionFrame::Error {
            error: error.wire_name().to_owned(),
            message: message.map(str::to_owned),
        }),
        Some(XRPC_V1_JSON_SUBPROTOCOL) => {
            let mut envelope = BTreeMap::from([
                ("$type".to_owned(), Value::String("error".to_owned())),
                (
                    "error".to_owned(),
                    Value::String(error.wire_name().to_owned()),
                ),
            ]);
            if let Some(text) = message {
                envelope.insert("message".to_owned(), Value::String(text.to_owned()));
            }
            encode_json_frame(&Value::Object(envelope))
        }
        Some(other) => Err(FrameError::UnsupportedSubprotocol(other)),
    }
}

fn decode_dag_cbor_subscription_frame<S: XrpcSubscription>(
    bytes: &[u8],
) -> Result<DecodedSubscriptionFrame<S::Message, S::Error>, FrameError>
where
    S::Message: FromValue,
{
    match decode_frame_with(bytes, Some(S::NSID))? {
        SubscriptionFrame::Error { error, message } => Ok(DecodedSubscriptionFrame::Error {
            error: S::Error::from_wire_name(&error),
            message,
        }),
        SubscriptionFrame::UnknownOperation { op } => {
            Ok(DecodedSubscriptionFrame::UnknownOperation { op })
        }
        SubscriptionFrame::Message {
            message_type,
            payload,
            sequence,
            ..
        } => decode_message_payload::<S>(message_type, payload, sequence),
    }
}

fn decode_json_subscription_frame<S: XrpcSubscription>(
    bytes: &[u8],
) -> Result<DecodedSubscriptionFrame<S::Message, S::Error>, FrameError>
where
    S::Message: FromValue,
{
    if bytes.is_empty() {
        return Err(FrameError::Empty);
    }
    if bytes.len() > MAXIMUM_FRAME_BYTES {
        return Err(FrameError::FrameTooLarge {
            len: bytes.len(),
            max: MAXIMUM_FRAME_BYTES,
        });
    }

    let root: Value =
        serde_json::from_slice(bytes).map_err(|error| DecodeError::Json(error.to_string()))?;
    let Value::Object(mut root_map) = root else {
        return Err(FrameError::InvalidHeader(
            "JSON subscription frame must be an object",
        ));
    };
    let Some(Value::String(frame_type)) = root_map.remove("$type") else {
        return Err(FrameError::InvalidHeader(
            "missing string '$type' in JSON subscription frame",
        ));
    };

    match frame_type.as_str() {
        "message" => {
            let Some(Value::Object(mut payload_map)) = root_map.remove("payload") else {
                return Err(FrameError::InvalidPayload(
                    "message frame missing object 'payload'",
                ));
            };
            let Some(Value::String(raw_type)) = payload_map.get("$type").cloned() else {
                return Err(FrameError::InvalidPayload(
                    "message payload missing string '$type'",
                ));
            };
            if raw_type.is_empty() {
                return Err(FrameError::InvalidPayload(
                    "empty '$type' in message payload",
                ));
            }
            let message_type = resolve_message_type(&raw_type, Some(S::NSID));
            let sequence = match payload_map.get("seq") {
                Some(Value::Integer(seq)) => Some(*seq),
                _ => None,
            };
            payload_map.insert("$type".to_owned(), Value::String(message_type.clone()));
            decode_message_payload::<S>(message_type, Value::Object(payload_map), sequence)
        }
        "error" => {
            let Some(Value::String(error)) = root_map.remove("error") else {
                return Err(FrameError::InvalidPayload(
                    "error frame missing string 'error'",
                ));
            };
            let message = match root_map.remove("message") {
                Some(Value::String(text)) => Some(text),
                _ => None,
            };
            Ok(DecodedSubscriptionFrame::Error {
                error: S::Error::from_wire_name(&error),
                message,
            })
        }
        _ => {
            root_map.insert("$type".to_owned(), Value::String(frame_type.clone()));
            Ok(DecodedSubscriptionFrame::UnknownMessageType {
                message_type: frame_type,
                payload: Value::Object(root_map),
                sequence: None,
            })
        }
    }
}

fn decode_message_payload<S: XrpcSubscription>(
    message_type: String,
    payload: Value,
    sequence: Option<i64>,
) -> Result<DecodedSubscriptionFrame<S::Message, S::Error>, FrameError>
where
    S::Message: FromValue,
{
    if !S::KNOWN_MESSAGE_TYPES.is_empty()
        && !S::KNOWN_MESSAGE_TYPES.contains(&message_type.as_str())
    {
        return Ok(DecodedSubscriptionFrame::UnknownMessageType {
            message_type,
            payload,
            sequence,
        });
    }
    let message = S::Message::from_value(payload)?;
    Ok(DecodedSubscriptionFrame::Message {
        message,
        message_type,
        sequence,
    })
}

fn encode_json_frame(envelope: &Value) -> Result<Vec<u8>, FrameError> {
    let out =
        serde_json::to_vec(envelope).map_err(|error| EncodeError::Custom(error.to_string()))?;
    if out.len() > MAXIMUM_FRAME_BYTES {
        return Err(FrameError::FrameTooLarge {
            len: out.len(),
            max: MAXIMUM_FRAME_BYTES,
        });
    }
    Ok(out)
}

fn resolve_message_type(raw_type: &str, default_lexicon: Option<&str>) -> String {
    match default_lexicon {
        Some(nsid) if raw_type.starts_with('#') => format!("{nsid}{raw_type}"),
        _ => raw_type.to_owned(),
    }
}
