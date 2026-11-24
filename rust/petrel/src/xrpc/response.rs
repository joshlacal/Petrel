use std::{fmt, time::Duration};

use bytes::Bytes;
use http::{HeaderMap, Response, StatusCode};
use serde::Deserialize;

/// Metadata reported by an XRPC server, including headers on HTTP errors.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResponseMetadata {
    pub status: StatusCode,
    /// Header names are case-insensitive and stored in lowercase by `HeaderMap`.
    pub headers: HeaderMap,
}

impl ResponseMetadata {
    pub fn from_response<T>(response: &Response<T>) -> Self {
        Self {
            status: response.status(),
            headers: response.headers().clone(),
        }
    }

    pub fn rate_limit(&self) -> Option<RateLimit> {
        Some(RateLimit {
            limit: self.header("ratelimit-limit")?.trim().parse().ok()?,
            remaining: self.header("ratelimit-remaining")?.trim().parse().ok()?,
            reset: self.header("ratelimit-reset")?.trim().parse().ok()?,
            policy: self.header("ratelimit-policy").map(str::to_owned),
        })
    }

    pub fn retry_after(&self) -> Option<Duration> {
        retry_after(&self.headers)
    }

    pub fn content_labelers(&self) -> Vec<XrpcLabeler> {
        self.headers
            .get_all("atproto-content-labelers")
            .iter()
            .filter_map(|value| value.to_str().ok())
            .flat_map(XrpcLabeler::parse)
            .collect()
    }

    pub fn repo_rev(&self) -> Option<&str> {
        self.header("atproto-repo-rev")
    }

    fn header(&self, name: &str) -> Option<&str> {
        self.headers.get(name)?.to_str().ok()
    }
}

/// Numeric request quota for a server's current rate-limit window.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RateLimit {
    pub limit: u64,
    pub remaining: u64,
    /// When the window ends, in seconds since the Unix epoch.
    pub reset: u64,
    pub policy: Option<String>,
}

pub(crate) fn retry_after(headers: &HeaderMap) -> Option<Duration> {
    let seconds = headers
        .get("retry-after")?
        .to_str()
        .ok()?
        .trim()
        .parse::<f64>()
        .ok()?;
    Duration::try_from_secs_f64(seconds).ok()
}

/// Applied or requested moderation labeler.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct XrpcLabeler {
    pub did: String,
    pub redact: bool,
}

impl XrpcLabeler {
    pub fn header_value(labelers: &[Self]) -> String {
        labelers
            .iter()
            .map(|labeler| {
                if labeler.redact {
                    format!("{};redact", labeler.did)
                } else {
                    labeler.did.clone()
                }
            })
            .collect::<Vec<_>>()
            .join(", ")
    }

    pub fn parse(header: &str) -> impl Iterator<Item = Self> {
        header.split(',').filter_map(|entry| {
            let mut fields = entry.split(';').map(str::trim);
            let did = fields.next()?.to_owned();
            if did.is_empty() {
                return None;
            }
            Some(Self {
                did,
                redact: fields.any(|field| field == "redact"),
            })
        })
    }
}

/// An error envelope sent by an XRPC endpoint.
#[derive(Debug, Deserialize)]
pub struct XrpcErrorBody {
    pub error: String,
    pub message: Option<String>,
}

/// A server error can be declared in the lexicon or discovered at runtime.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum XrpcErrorKind<E> {
    Declared(E),
    Undeclared(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct XrpcError<E> {
    pub kind: XrpcErrorKind<E>,
    pub code: String,
    pub message: Option<String>,
    pub metadata: ResponseMetadata,
}

impl<E> XrpcError<E> {
    pub(crate) fn parse(
        response: &Response<Bytes>,
        diagnostic_limit: usize,
        declare: impl FnOnce(&str) -> Option<E>,
    ) -> Self {
        let body = serde_json::from_slice::<XrpcErrorBody>(response.body()).ok();
        let (code, message) = if let Some(body) = body {
            let message = body.message.map(|message| {
                let mut end = diagnostic_limit.min(message.len());
                while !message.is_char_boundary(end) {
                    end -= 1;
                }
                message[..end].to_owned()
            });
            (body.error, message)
        } else {
            let bytes = &response.body()[..response.body().len().min(diagnostic_limit)];
            let text = String::from_utf8_lossy(bytes);
            let trim = text.trim();
            (
                format!("HTTP {}", response.status().as_u16()),
                (!trim.is_empty()).then(|| trim.to_owned()),
            )
        };

        let kind = declare(&code).map_or_else(
            || XrpcErrorKind::Undeclared(code.clone()),
            XrpcErrorKind::Declared,
        );
        Self {
            kind,
            code,
            message,
            metadata: ResponseMetadata::from_response(response),
        }
    }

    pub fn rate_limit(&self) -> Option<RateLimit> {
        self.metadata.rate_limit()
    }

    pub fn retry_after(&self) -> Option<Duration> {
        self.metadata.retry_after()
    }
}

impl<E> fmt::Display for XrpcError<E> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "XRPC request returned {} ({})",
            self.metadata.status.as_u16(),
            self.code
        )
    }
}

impl<E: fmt::Debug> std::error::Error for XrpcError<E> {}

/// Raw successful response plus its metadata.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct XrpcResponse {
    pub metadata: ResponseMetadata,
    pub body: Bytes,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_case_insensitive_rate_limit_and_labeler_headers() {
        let response = Response::builder()
            .status(429)
            .header("RATELIMIT-LIMIT", "200")
            .header("RateLimit-Remaining", " 12 ")
            .header("RateLimit-Reset", "20250204")
            .header("RateLimit-Policy", "200;w=300")
            .header("Retry-After", "2")
            .header("Atproto-Content-Labelers", "did:plc:a;redact")
            .header("Atproto-Content-Labelers", "did:plc:b")
            .header("Atproto-Repo-Rev", "3lks")
            .body(())
            .unwrap();
        let mut metadata = ResponseMetadata::from_response(&response);
        assert_eq!(
            metadata.rate_limit(),
            Some(RateLimit {
                limit: 200,
                remaining: 12,
                reset: 20_250_204,
                policy: Some("200;w=300".to_owned()),
            }),
        );
        assert_eq!(metadata.retry_after(), Some(Duration::from_secs(2)));
        assert_eq!(metadata.repo_rev(), Some("3lks"));
        assert_eq!(
            XrpcLabeler::header_value(&metadata.content_labelers()),
            "did:plc:a;redact, did:plc:b"
        );

        metadata.headers.remove("ratelimit-reset");
        assert_eq!(metadata.rate_limit(), None);
    }

    #[test]
    fn parses_declared_errors_and_bounds_html_diagnostics() {
        let response = Response::builder()
            .status(400)
            .body(Bytes::from_static(
                br#"{"error":"Example","message":"bad value"}"#,
            ))
            .unwrap();
        let declared = XrpcError::parse(&response, 1024, |code| (code == "Example").then_some(7));
        let undeclared = XrpcError::<()>::parse(&response, 1024, |_| None);
        assert_eq!(declared.kind, XrpcErrorKind::Declared(7));
        assert_eq!(
            undeclared.kind,
            XrpcErrorKind::Undeclared("Example".to_owned())
        );

        let response = Response::builder()
            .status(502)
            .body(Bytes::from_static(b" <html>some error</html>"))
            .unwrap();
        let error = XrpcError::<()>::parse(&response, 7, |_| None);
        assert_eq!(error.kind, XrpcErrorKind::Undeclared("HTTP 502".to_owned()));
        assert_eq!(error.message.as_deref(), Some("<html>"));
    }
}
