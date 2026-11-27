use petrel_core::{
    DeclaredXrpcError, DecodeError, EncodeError, FromQueryParams, FromValue, ToValue, XrpcErrorBody,
};

use crate::support::StrictJson;

/// Fixed client-facing message for [`XrpcServerError::Internal`].
pub const INTERNAL_ERROR_MESSAGE: &str = "Internal Server Error";

/// Framework-agnostic XRPC handler error capable of producing `{"error": ..., "message": ...}` JSON bodies.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum XrpcServerError<E> {
    /// Declared lexicon error defined on the endpoint (`R::Error`).
    Declared {
        status: u16,
        error: E,
        message: Option<String>,
    },
    /// Invalid request syntax, query params, content-type, or strict input schema failure (`400 InvalidRequest`).
    InvalidRequest(String),
    /// Authentication missing or invalid (`401 AuthRequired`).
    AuthRequired(String),
    /// Access token or service-auth token expired (`401 ExpiredToken`).
    ExpiredToken(String),
    /// Insufficient OAuth scope or permissions (`403 Forbidden`).
    Forbidden(String),
    /// Route / HTTP method mismatch (`405 MethodNotAllowed`).
    MethodNotAllowed(String),
    /// Internal or upstream server error (`500 InternalServerError`).
    ///
    /// The string is server-side detail: it is logged by the Axum adapter and never sent to
    /// the client, which receives [`INTERNAL_ERROR_MESSAGE`].
    Internal(String),
}

impl<E: DeclaredXrpcError> XrpcServerError<E> {
    /// Constructs a declared endpoint error (`HTTP 400` by default).
    pub fn declared(error: E, message: impl Into<Option<String>>) -> Self {
        Self::Declared {
            status: 400,
            error,
            message: message.into(),
        }
    }

    /// Constructs a declared endpoint error with an explicit HTTP status code.
    pub fn declared_with_status(status: u16, error: E, message: impl Into<Option<String>>) -> Self {
        Self::Declared {
            status,
            error,
            message: message.into(),
        }
    }

    /// HTTP status code associated with this error.
    pub const fn http_status(&self) -> u16 {
        match self {
            Self::Declared { status, .. } => *status,
            Self::InvalidRequest(_) => 400,
            Self::AuthRequired(_) | Self::ExpiredToken(_) => 401,
            Self::Forbidden(_) => 403,
            Self::MethodNotAllowed(_) => 405,
            Self::Internal(_) => 500,
        }
    }

    /// Wire `XrpcErrorBody` (`{"error": ..., "message": ...}`).
    pub fn to_wire_body(&self) -> XrpcErrorBody {
        match self {
            Self::Declared { error, message, .. } => XrpcErrorBody {
                error: error.wire_name().to_owned(),
                message: message.clone(),
            },
            Self::InvalidRequest(msg) => XrpcErrorBody {
                error: "InvalidRequest".to_owned(),
                message: Some(msg.clone()),
            },
            Self::AuthRequired(msg) => XrpcErrorBody {
                error: "AuthRequired".to_owned(),
                message: Some(msg.clone()),
            },
            Self::ExpiredToken(msg) => XrpcErrorBody {
                error: "ExpiredToken".to_owned(),
                message: Some(msg.clone()),
            },
            Self::Forbidden(msg) => XrpcErrorBody {
                error: "Forbidden".to_owned(),
                message: Some(msg.clone()),
            },
            Self::MethodNotAllowed(msg) => XrpcErrorBody {
                error: "MethodNotAllowed".to_owned(),
                message: Some(msg.clone()),
            },
            // The detail of an internal error (SQL, upstream URLs, panics) stays server-side;
            // adapters log it. Clients get a fixed message.
            Self::Internal(_) => XrpcErrorBody {
                error: "InternalServerError".to_owned(),
                message: Some(INTERNAL_ERROR_MESSAGE.to_owned()),
            },
        }
    }

    /// Serializes the XRPC error JSON payload.
    pub fn to_json_bytes(&self) -> Vec<u8> {
        serde_json::to_vec(&self.to_wire_body())
            .unwrap_or_else(|_| b"{\"error\":\"InternalServerError\"}".to_vec())
    }
}

/// Strictly decodes XRPC query parameters (`GET /xrpc/{nsid}?...`) into `P`.
pub fn decode_xrpc_query<P: FromQueryParams>(raw_query: Option<&str>) -> Result<P, DecodeError> {
    let owned_pairs: Vec<(String, String)> = match raw_query {
        Some(q) if !q.is_empty() => form_urlencoded::parse(q.as_bytes())
            .map(|(k, v)| (k.into_owned(), v.into_owned()))
            .collect(),
        _ => Vec::new(),
    };
    let borrowed: Vec<(&str, &str)> = owned_pairs
        .iter()
        .map(|(k, v)| (k.as_str(), v.as_str()))
        .collect();
    P::from_query_params(&borrowed)
}

/// Strictly decodes JSON XRPC procedure inputs using `StrictJson` + recursive [`FromValue::from_value_strict`].
///
/// Rejects duplicate keys, trailing JSON tokens, and optional fields that do not decode anywhere
/// inside nested objects/arrays. Unknown fields (and unknown open-union members) are accepted at
/// every depth, as ATProto's additive lexicon evolution requires, so an older server keeps
/// accepting requests from newer clients.
pub fn decode_xrpc_json_strict<T: FromValue>(bytes: &[u8]) -> Result<T, String> {
    StrictJson::validate(bytes).map_err(|err| err.to_string())?;
    let val: petrel_core::Value =
        serde_json::from_slice(bytes).map_err(|err| format!("invalid XRPC JSON: {err}"))?;
    T::from_value_strict(val).map_err(|err| format!("strict XRPC input validation failed: {err}"))
}

/// Encodes any [`ToValue`] XRPC output into compact JSON bytes.
pub fn encode_xrpc_json<T: ToValue>(value: &T) -> Result<Vec<u8>, EncodeError> {
    let val = value.to_value()?;
    serde_json::to_vec(&val).map_err(|err| EncodeError::Custom(err.to_string()))
}
