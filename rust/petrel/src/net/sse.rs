//! WHATWG `text/event-stream` (Server-Sent Events) parser and transport client.

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
use std::{fmt, sync::Arc};

use bytes::Bytes;
use futures_util::stream::{self, Stream, StreamExt};
use http::{HeaderMap, Request, Response, StatusCode, header::CONTENT_TYPE};

use super::{DynHttpTransport, RedirectPolicy, SendOptions, TransportError, send_with_redirects};
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
use super::{
    native::{FilteringDns, map_reqwest},
    policy::{retain_anonymous_headers, validate_request_uri},
};

/// Default per-event/per-line byte ceiling (8 MiB), matching Swift `ServerSentEventParser`.
pub const DEFAULT_MAXIMUM_EVENT_BYTES: usize = 8 * 1024 * 1024;

/// One decoded event from a `text/event-stream` body.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServerSentEvent {
    /// Event type (`"message"` when the stream specifies no `event:` field).
    pub event_type: String,
    /// `data:` lines joined with `'\n'`.
    pub data: String,
    /// Last non-NUL `id:` seen on the stream at the time of dispatch.
    pub last_event_id: String,
}

/// Errors produced while opening or parsing a `text/event-stream` response.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum SseError {
    /// Underlying HTTP transport failure.
    #[error(transparent)]
    Transport(#[from] TransportError),
    /// Server returned a non-200 HTTP status.
    #[error("event stream connection failed with HTTP {status}")]
    HttpStatus {
        /// Status code returned by the server.
        status: StatusCode,
    },
    /// Response `Content-Type` header was not `text/event-stream`.
    #[error("expected Content-Type text/event-stream, got {actual:?}")]
    InvalidContentType {
        /// Actual header value if present.
        actual: Option<String>,
    },
    /// A line or accumulated event exceeded `maximum_event_bytes`.
    #[error("server-sent event exceeds {limit} bytes")]
    EventTooLarge {
        /// Maximum permitted bytes.
        limit: usize,
    },
}

/// Byte-by-byte streaming parser implementing WHATWG Server-Sent Events framing.
///
/// Handles CR, LF, and CRLF across chunk boundaries, decodes UTF-8 only on complete lines,
/// strips a single leading UTF-8 BOM, and bounds line and event accumulation.
#[derive(Debug, Clone)]
pub struct ServerSentEventParser {
    maximum_event_bytes: usize,
    line: Vec<u8>,
    after_carriage_return: bool,
    at_stream_start: bool,
    data: String,
    data_bytes: usize,
    has_data: bool,
    event_type: String,
    last_event_id: String,
}

impl Default for ServerSentEventParser {
    fn default() -> Self {
        Self::new(DEFAULT_MAXIMUM_EVENT_BYTES)
    }
}

impl ServerSentEventParser {
    /// Creates a parser bounding each line and event to `maximum_event_bytes`.
    #[must_use]
    pub const fn new(maximum_event_bytes: usize) -> Self {
        Self {
            maximum_event_bytes,
            line: Vec::new(),
            after_carriage_return: false,
            at_stream_start: true,
            data: String::new(),
            data_bytes: 0,
            has_data: false,
            event_type: String::new(),
            last_event_id: String::new(),
        }
    }

    /// Feeds the next body chunk and returns all events completed within it.
    pub fn consume(&mut self, bytes: &[u8]) -> Result<Vec<ServerSentEvent>, SseError> {
        let mut events = Vec::new();
        for &byte in bytes {
            if self.after_carriage_return {
                self.after_carriage_return = false;
                if byte == b'\n' {
                    continue;
                }
            }
            match byte {
                b'\r' => {
                    self.after_carriage_return = true;
                    if let Some(event) = self.end_line()? {
                        events.push(event);
                    }
                }
                b'\n' => {
                    if let Some(event) = self.end_line()? {
                        events.push(event);
                    }
                }
                _ => {
                    self.line.push(byte);
                    if self.line.len() > self.maximum_event_bytes {
                        return Err(SseError::EventTooLarge {
                            limit: self.maximum_event_bytes,
                        });
                    }
                }
            }
        }
        Ok(events)
    }

    fn end_line(&mut self) -> Result<Option<ServerSentEvent>, SseError> {
        let mut bytes: &[u8] = &self.line;
        if self.at_stream_start {
            self.at_stream_start = false;
            if let Some(stripped) = bytes.strip_prefix(&[0xEF, 0xBB, 0xBF]) {
                bytes = stripped;
            }
        }
        if bytes.is_empty() {
            self.line.clear();
            return Ok(self.dispatch());
        }
        if bytes.first() == Some(&b':') {
            self.line.clear();
            return Ok(None);
        }

        let (field, value) = if let Some(colon) = bytes.iter().position(|&b| b == b':') {
            let field = String::from_utf8_lossy(&bytes[..colon]).into_owned();
            let mut value = &bytes[colon + 1..];
            if let Some(rest) = value.strip_prefix(b" ") {
                value = rest;
            }
            (field, value)
        } else {
            (String::from_utf8_lossy(bytes).into_owned(), &[][..])
        };

        match field.as_str() {
            "event" => {
                self.event_type = String::from_utf8_lossy(value).into_owned();
            }
            "data" => {
                self.data_bytes = self.data_bytes.saturating_add(value.len() + 1);
                if self.data_bytes > self.maximum_event_bytes {
                    self.line.clear();
                    return Err(SseError::EventTooLarge {
                        limit: self.maximum_event_bytes,
                    });
                }
                self.data.push_str(&String::from_utf8_lossy(value));
                self.data.push('\n');
                self.has_data = true;
            }
            "id" if !value.contains(&0) => {
                self.last_event_id = String::from_utf8_lossy(value).into_owned();
            }
            _ => {}
        }

        self.line.clear();
        Ok(None)
    }

    fn dispatch(&mut self) -> Option<ServerSentEvent> {
        let has_data = self.has_data;
        let event_type = std::mem::take(&mut self.event_type);
        let mut data = std::mem::take(&mut self.data);
        self.data_bytes = 0;
        self.has_data = false;

        if !has_data {
            return None;
        }
        if data.ends_with('\n') {
            data.pop();
        }
        Some(ServerSentEvent {
            event_type: if event_type.is_empty() {
                "message".to_owned()
            } else {
                event_type
            },
            data,
            last_event_id: self.last_event_id.clone(),
        })
    }
}

/// Validates HTTP status (`200 OK`) and `Content-Type: text/event-stream` for an SSE response.
pub fn validate_sse_response_headers(
    status: StatusCode,
    headers: &HeaderMap,
) -> Result<(), SseError> {
    if status != StatusCode::OK {
        return Err(SseError::HttpStatus { status });
    }
    let content_type = headers
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .map(str::to_owned);
    let essence = content_type
        .as_deref()
        .and_then(|raw| raw.split(';').next())
        .map_or("", str::trim);
    if !essence.eq_ignore_ascii_case("text/event-stream") {
        return Err(SseError::InvalidContentType {
            actual: content_type,
        });
    }
    Ok(())
}

/// Sends a request via any [`DynHttpTransport`] with redirects disabled, validates SSE headers,
/// and parses all events from the returned body.
pub async fn fetch_events(
    transport: &dyn DynHttpTransport,
    request: Request<Bytes>,
    options: &SendOptions,
    maximum_event_bytes: usize,
) -> Result<Vec<ServerSentEvent>, SseError> {
    let response = send_with_redirects(transport, request, options, RedirectPolicy::Never).await?;
    validate_sse_response_headers(response.status(), response.headers())?;
    let mut parser = ServerSentEventParser::new(maximum_event_bytes);
    parser.consume(response.body())
}

/// Wraps [`fetch_events`] into a stream interface for transport-agnostic callers.
pub fn events_via_transport<'a>(
    transport: &'a dyn DynHttpTransport,
    request: Request<Bytes>,
    options: &'a SendOptions,
    maximum_event_bytes: usize,
) -> impl Stream<Item = Result<ServerSentEvent, SseError>> + 'a {
    stream::once(fetch_events(
        transport,
        request,
        options,
        maximum_event_bytes,
    ))
    .flat_map(|result| match result {
        Ok(events) => stream::iter(events.into_iter().map(Ok)).left_stream(),
        Err(error) => stream::once(async move { Err(error) }).right_stream(),
    })
}

/// Helper for streaming SSE events incrementally over native `reqwest::Client`.
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub struct NativeSseClient {
    client: reqwest::Client,
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
impl fmt::Debug for NativeSseClient {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("NativeSseClient").finish_non_exhaustive()
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
impl NativeSseClient {
    /// Builds a redirect-free `reqwest` SSE client enforcing `validate_resolved_addresses` on `dns`.
    pub fn new(dns: impl crate::identity::DnsResolver + 'static) -> Result<Self, TransportError> {
        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .retry(reqwest::retry::never())
            .no_proxy()
            .dns_resolver(Arc::new(FilteringDns(Arc::new(dns))))
            .build()
            .map_err(map_reqwest)?;
        Ok(Self { client })
    }

    /// Creates a client backed by the system resolver with DNS policy enforcement (redirect-free, no proxy).
    pub fn system() -> Result<Self, TransportError> {
        let resolver = crate::identity::HickoryResolver::system()
            .map_err(|error| TransportError::Connect(error.to_string()))?;
        Self::new(resolver)
    }

    /// Opens an incremental `text/event-stream` response without following redirects.
    pub async fn connect(
        &self,
        request: Request<Bytes>,
        options: &SendOptions,
        maximum_event_bytes: usize,
    ) -> Result<NativeSseStream, SseError> {
        let (mut parts, body) = request.into_parts();
        let (url, origin) = validate_request_uri(&parts.uri, options)
            .map_err(|error| TransportError::PolicyViolation(error.to_string()))?;
        if !matches!(origin.scheme(), "http" | "https") {
            return Err(TransportError::InvalidRequest(
                "SSE client requires HTTP or HTTPS".to_owned(),
            )
            .into());
        }
        if options.anonymous {
            retain_anonymous_headers(&mut parts.headers);
        }
        parts.headers.remove(http::header::HOST);
        let mut req = self
            .client
            .request(parts.method, url)
            .headers(parts.headers);
        if let Some(timeout) = options.timeout {
            req = req.timeout(timeout);
        }
        if !body.is_empty() {
            req = req.body(body);
        }
        let response = req.send().await.map_err(map_reqwest)?;
        let status = response.status();
        let headers = response.headers().clone();
        validate_sse_response_headers(status, &headers)?;
        Ok(NativeSseStream {
            response,
            parser: ServerSentEventParser::new(maximum_event_bytes),
            pending: std::collections::VecDeque::new(),
            eof: false,
        })
    }
}

/// Incremental native SSE event stream.
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub struct NativeSseStream {
    response: reqwest::Response,
    parser: ServerSentEventParser,
    pending: std::collections::VecDeque<ServerSentEvent>,
    eof: bool,
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
impl fmt::Debug for NativeSseStream {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("NativeSseStream")
            .field("eof", &self.eof)
            .finish_non_exhaustive()
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
impl NativeSseStream {
    /// Reads and parses the next [`ServerSentEvent`], returning `Ok(None)` at clean EOF.
    pub async fn next_event(&mut self) -> Result<Option<ServerSentEvent>, SseError> {
        loop {
            if let Some(event) = self.pending.pop_front() {
                return Ok(Some(event));
            }
            if self.eof {
                return Ok(None);
            }
            if let Some(chunk) = self
                .response
                .chunk()
                .await
                .map_err(|error| TransportError::ConnectionLost(error.to_string()))?
            {
                for event in self.parser.consume(&chunk)? {
                    self.pending.push_back(event);
                }
            } else {
                self.eof = true;
                return Ok(None);
            }
        }
    }
}

#[allow(dead_code)]
fn _assert_response_type(_: &Response<Bytes>) {}
