//! WebSocket transport abstraction and platform implementations for AT Protocol event streams.

use std::collections::BTreeMap;
use std::time::Duration;

use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use url::Url;

use crate::limits::FirehoseFrameLimits;

/// How a WebSocket transport handles incoming text frames.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub enum TextFrameHandling {
    /// Fail with [`FirehoseSubscriptionError::UnsupportedMessageFormat`]. Event streams with
    /// CBOR framing are binary-only.
    #[default]
    Reject,
    /// Deliver the UTF-8 bytes of the text frame (used by Jetstream JSON mode).
    Utf8Data,
}

/// Settings for WebSocket connections opened by the default transport factory.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FirehoseWebSocketOptions {
    /// Largest incoming message accepted (defaults to 5 MB).
    pub maximum_message_size: usize,
    /// How incoming WebSocket text frames are handled.
    pub text_frames: TextFrameHandling,
    /// Extra HTTP headers added to the upgrade request.
    pub additional_headers: BTreeMap<String, String>,
    /// Timeout covering DNS resolution, TCP connect, TLS, and WebSocket upgrade (`None` disables timeout).
    pub connect_timeout: Option<Duration>,
    /// Interval between keep-alive pings (`None` disables keep-alive pings).
    pub ping_interval: Option<Duration>,
}

impl FirehoseWebSocketOptions {
    /// Creates transport options suited for binary CBOR event streams.
    pub fn new() -> Self {
        Self {
            maximum_message_size: FirehoseFrameLimits::MAXIMUM_FRAME_BYTES,
            text_frames: TextFrameHandling::Reject,
            additional_headers: BTreeMap::new(),
            connect_timeout: Some(Duration::from_secs(30)),
            ping_interval: Some(Duration::from_secs(30)),
        }
    }

    /// Options for Jetstream (accepts UTF-8 text frames for JSON).
    pub fn jetstream() -> Self {
        Self {
            text_frames: TextFrameHandling::Utf8Data,
            ..Self::new()
        }
    }
}

impl Default for FirehoseWebSocketOptions {
    fn default() -> Self {
        Self::new()
    }
}

/// Errors produced by firehose WebSocket transport, cursor coordination, and stream logic.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum FirehoseSubscriptionError {
    /// A WebSocket text message arrived on a binary-only event stream.
    #[error("unsupported WebSocket text frame on binary stream")]
    UnsupportedMessageFormat,
    /// The WebSocket connection closed.
    #[error("WebSocket connection closed")]
    ConnectionClosed,
    /// The server sent the same sequence number twice within one connection.
    #[error("duplicate sequence number: {0}")]
    DuplicateSequence(i64),
    /// A sequence number or acknowledgement moved backwards.
    #[error("cursor regression: expected >= {expected}, received {received}")]
    CursorRegression { expected: i64, received: i64 },
    /// Legacy variant retained for source parity (streams apply backpressure instead).
    #[error("resynchronization required")]
    ResynchronizationRequired,
    /// Cursor storage failed while loading or saving.
    #[error("cursor storage failure")]
    StorageFailure,
    /// Legacy variant retained for source parity (acknowledgements may skip gaps).
    #[error("unacknowledged sequence gap")]
    UnacknowledgedSequenceGap,
    /// The server answered the WebSocket upgrade with a non-101 HTTP status.
    #[error("WebSocket upgrade rejected with HTTP {status}")]
    UpgradeRejected {
        status: u16,
        retry_after_ms: Option<u64>,
    },
    /// WebSocket transport is unavailable on this target or runtime.
    #[error("WebSocket transport unavailable: {0}")]
    WebSocketTransportUnavailable(String),
    /// The server sent a frame larger than `maximum_message_size`. Subscriptions reconnect
    /// with backoff on this error (see `oversize_frame_retry_limit`).
    #[error("WebSocket message exceeded maximum frame size")]
    FrameTooLarge,
    /// The frame following sequence `cursor` (`None`: before any decoded frame) exceeded
    /// `maximum_message_size` on `attempts` consecutive connections. Raise the limit, or store
    /// a cursor past the frame, then resubscribe.
    #[error(
        "WebSocket message after cursor {} exceeded maximum frame size on {attempts} consecutive attempts",
        cursor.map_or_else(|| "<none>".to_owned(), |c| c.to_string())
    )]
    FrameTooLargeAtCursor { cursor: Option<i64>, attempts: u32 },
    /// The transport does not support sending outgoing text frames.
    #[error("WebSocket transport cannot send frames")]
    SendingUnsupported,
    /// Target URL or resolved IP violated transport security policy.
    #[error("WebSocket security policy violation: {0}")]
    SecurityViolation(String),
    /// Transient connection or I/O error eligible for reconnect backoff.
    #[error("WebSocket network error: {0}")]
    Network(String),
}

impl FirehoseSubscriptionError {
    /// Returns any parsed `Retry-After` delay associated with an [`Self::UpgradeRejected`] error.
    pub const fn retry_after(&self) -> Option<Duration> {
        match self {
            Self::UpgradeRejected {
                retry_after_ms: Some(ms),
                ..
            } => Some(Duration::from_millis(*ms)),
            _ => None,
        }
    }
}

/// One open WebSocket connection as seen by event-stream consumers.
pub trait FirehoseWebSocketSession: MaybeSend + MaybeSync + std::fmt::Debug {
    /// Waits for the next message and returns its payload.
    fn receive_message(&self) -> BoxFuture<'_, Result<Vec<u8>, FirehoseSubscriptionError>>;

    /// Closes the connection and wakes any pending [`Self::receive_message`] call.
    fn close(&self) -> BoxFuture<'_, ()>;

    /// Sends a text message to the server (used by Jetstream `options_update`).
    fn send_text<'a>(
        &'a self,
        _text: &'a str,
    ) -> BoxFuture<'a, Result<(), FirehoseSubscriptionError>> {
        Box::pin(async { Err(FirehoseSubscriptionError::SendingUnsupported) })
    }
}

/// Opens WebSocket connections for event-stream consumers.
pub trait FirehoseWebSocketSessionFactory: MaybeSend + MaybeSync + std::fmt::Debug {
    /// Opens a connection to `url` (`wss://`, or `ws://` for loopback hosts).
    fn make_session(
        &self,
        url: Url,
    ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>>;

    /// Opens a connection to `url`, offering `subprotocols` in `Sec-WebSocket-Protocol`.
    fn make_session_with_subprotocols(
        &self,
        url: Url,
        _subprotocols: Vec<String>,
    ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>> {
        self.make_session(url)
    }
}

pub(crate) fn is_loopback_host_str(host: &str) -> bool {
    let lower = host.to_ascii_lowercase();
    matches!(lower.as_str(), "localhost" | "127.0.0.1" | "[::1]" | "::1")
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
mod native {
    use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
    use std::sync::Arc;
    use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
    use std::time::Duration;

    use async_lock::Mutex;
    use futures_util::stream::{SplitSink, SplitStream};
    use futures_util::{SinkExt, StreamExt};
    use petrel::identity::{DnsResolver, HickoryResolver};
    use petrel::net::policy::{validate_resolved_addresses, validate_url_with_development};
    use petrel::rt::BoxFuture;
    use tokio::net::TcpStream;
    use tokio::sync::watch;
    use tokio::task::JoinHandle;
    use tokio_tungstenite::tungstenite::Error as WsError;
    use tokio_tungstenite::tungstenite::Message;
    use tokio_tungstenite::tungstenite::client::IntoClientRequest;
    use tokio_tungstenite::tungstenite::http::{HeaderName, HeaderValue};
    use tokio_tungstenite::tungstenite::protocol::WebSocketConfig;
    use tokio_tungstenite::{MaybeTlsStream, WebSocketStream, client_async_tls_with_config};
    use url::{Host, Url};

    use super::{
        FirehoseSubscriptionError, FirehoseWebSocketOptions, FirehoseWebSocketSession,
        FirehoseWebSocketSessionFactory, TextFrameHandling, is_loopback_host_str,
    };

    type WsStream = WebSocketStream<MaybeTlsStream<TcpStream>>;

    /// Native WebSocket session factory backed by `tokio-tungstenite` and `rustls` (webpki roots).
    #[derive(Debug, Clone)]
    pub struct TungsteniteWebSocketFactory {
        /// Transport settings applied to every opened connection.
        pub options: FirehoseWebSocketOptions,
    }

    impl TungsteniteWebSocketFactory {
        /// Creates a factory with default binary-stream options.
        pub fn new() -> Self {
            Self {
                options: FirehoseWebSocketOptions::new(),
            }
        }

        /// Creates a factory with explicit transport options.
        pub fn with_options(options: FirehoseWebSocketOptions) -> Self {
            Self { options }
        }
    }

    impl Default for TungsteniteWebSocketFactory {
        fn default() -> Self {
            Self::new()
        }
    }

    impl FirehoseWebSocketSessionFactory for TungsteniteWebSocketFactory {
        fn make_session(
            &self,
            url: Url,
        ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>>
        {
            self.make_session_with_subprotocols(url, Vec::new())
        }

        #[allow(clippy::too_many_lines)]
        fn make_session_with_subprotocols(
            &self,
            url: Url,
            subprotocols: Vec<String>,
        ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>>
        {
            let options = self.options.clone();
            Box::pin(async move {
                let host = url
                    .host_str()
                    .ok_or_else(|| {
                        FirehoseSubscriptionError::SecurityViolation("URL has no host".to_owned())
                    })?
                    .to_owned();
                let allow_loopback = is_loopback_host_str(&host);
                let origin = validate_url_with_development(&url, allow_loopback)
                    .map_err(|e| FirehoseSubscriptionError::SecurityViolation(e.to_string()))?;

                let connect_fut = async {
                    let ips = resolve_and_validate_ips(&url, &host).await?;
                    let port = origin.port();
                    let addrs: Vec<SocketAddr> = ips
                        .into_iter()
                        .map(|ip| SocketAddr::new(ip, port))
                        .collect();

                    let tcp = TcpStream::connect(addrs.as_slice())
                        .await
                        .map_err(|e| FirehoseSubscriptionError::Network(e.to_string()))?;
                    let _ = tcp.set_nodelay(true);

                    let mut request = url
                        .as_str()
                        .into_client_request()
                        .map_err(|e| FirehoseSubscriptionError::SecurityViolation(e.to_string()))?;

                    for (name, value) in &options.additional_headers {
                        let header_name = HeaderName::from_bytes(name.as_bytes()).map_err(|e| {
                            FirehoseSubscriptionError::SecurityViolation(e.to_string())
                        })?;
                        let header_value = HeaderValue::from_str(value).map_err(|e| {
                            FirehoseSubscriptionError::SecurityViolation(e.to_string())
                        })?;
                        request.headers_mut().insert(header_name, header_value);
                    }

                    if !subprotocols.is_empty() {
                        let header_value = HeaderValue::from_str(&subprotocols.join(", "))
                            .map_err(|e| {
                                FirehoseSubscriptionError::SecurityViolation(e.to_string())
                            })?;
                        request
                            .headers_mut()
                            .insert("Sec-WebSocket-Protocol", header_value);
                    }

                    let ws_config = WebSocketConfig::default()
                        .max_message_size(Some(options.maximum_message_size))
                        .max_frame_size(Some(options.maximum_message_size));

                    let (ws_stream, _) =
                        client_async_tls_with_config(request, tcp, Some(ws_config), None)
                            .await
                            .map_err(classify_ws_error)?;
                    Ok::<WsStream, FirehoseSubscriptionError>(ws_stream)
                };

                let ws_stream =
                    match options.connect_timeout {
                        Some(timeout) => tokio::time::timeout(timeout, connect_fut)
                            .await
                            .map_err(|_| {
                                FirehoseSubscriptionError::Network(
                                    "WebSocket connect timed out".to_owned(),
                                )
                            })??,
                        None => connect_fut.await?,
                    };

                let session = TungsteniteWebSocketSession::new(ws_stream, &options);
                Ok(Box::new(session) as Box<dyn FirehoseWebSocketSession>)
            })
        }
    }

    async fn resolve_and_validate_ips(
        url: &Url,
        host: &str,
    ) -> Result<Vec<IpAddr>, FirehoseSubscriptionError> {
        let ips = match url.host() {
            Some(Host::Ipv4(addr)) => vec![IpAddr::V4(addr)],
            Some(Host::Ipv6(addr)) => vec![IpAddr::V6(addr)],
            Some(Host::Domain(domain)) => {
                let answer = match HickoryResolver::system() {
                    Ok(resolver) => resolver.lookup_ip(domain).await.map_err(|e| e.to_string()),
                    Err(_) => Err("failed to initialize DNS resolver".to_owned()),
                };
                classify_dns_answer(domain, answer)?
            }
            None => {
                return Err(FirehoseSubscriptionError::SecurityViolation(
                    "URL has no host".to_owned(),
                ));
            }
        };

        validate_resolved_addresses(host, &ips)
            .map_err(|e| FirehoseSubscriptionError::SecurityViolation(e.to_string()))?;
        Ok(ips)
    }

    /// Maps a DNS answer to the addresses to connect to.
    ///
    /// A lookup error or an empty answer (NXDOMAIN and no-records both arrive as an empty set)
    /// is transient: resolvers flap and records get re-published, so it is reported as
    /// [`FirehoseSubscriptionError::Network`] and the pump reconnects with backoff. Only a
    /// policy rejection of the resolved addresses (private, reserved, or loopback IPs for a
    /// public host) is a [`FirehoseSubscriptionError::SecurityViolation`], applied afterwards by
    /// `validate_resolved_addresses`.
    fn classify_dns_answer(
        domain: &str,
        answer: Result<Vec<IpAddr>, String>,
    ) -> Result<Vec<IpAddr>, FirehoseSubscriptionError> {
        match answer {
            Ok(addrs) if !addrs.is_empty() => Ok(addrs),
            _ if is_loopback_host_str(domain) => Ok(vec![
                IpAddr::V4(Ipv4Addr::LOCALHOST),
                IpAddr::V6(Ipv6Addr::LOCALHOST),
            ]),
            Err(e) => Err(FirehoseSubscriptionError::Network(e)),
            Ok(_) => Err(FirehoseSubscriptionError::Network(format!(
                "DNS returned no IP addresses for {domain}"
            ))),
        }
    }

    /// Active WebSocket connection backed by `tokio-tungstenite`.
    #[derive(Debug)]
    pub struct TungsteniteWebSocketSession {
        reader: Mutex<SplitStream<WsStream>>,
        writer: Arc<Mutex<SplitSink<WsStream, Message>>>,
        text_frames: TextFrameHandling,
        maximum_message_size: usize,
        closed_tx: watch::Sender<bool>,
        liveness: Arc<Liveness>,
        keep_alive: Mutex<Option<JoinHandle<()>>>,
    }

    impl TungsteniteWebSocketSession {
        fn new(stream: WsStream, options: &FirehoseWebSocketOptions) -> Self {
            let (sink, reader) = stream.split();
            let writer = Arc::new(Mutex::new(sink));
            let (closed_tx, closed_rx) = watch::channel(false);
            let liveness = Arc::new(Liveness::default());
            let keep_alive = options
                .ping_interval
                .filter(|d| !d.is_zero())
                .map(|interval| {
                    Self::spawn_keep_alive(
                        Arc::clone(&writer),
                        Arc::clone(&liveness),
                        closed_tx.clone(),
                        closed_rx,
                        interval,
                    )
                });

            Self {
                reader: Mutex::new(reader),
                writer,
                text_frames: options.text_frames,
                maximum_message_size: options.maximum_message_size,
                closed_tx,
                liveness,
                keep_alive: Mutex::new(keep_alive),
            }
        }

        /// Pings every `interval` and closes the connection when a ping stays unanswered for a
        /// full interval *during which the consumer was continuously waiting in
        /// `receive_message`*.
        ///
        /// Pongs (like all frames) are only read while the consumer polls, so an interval in
        /// which the consumer was not reading says nothing about the peer: it restarts the
        /// measurement instead of counting against the connection. Pull rate therefore never
        /// kills a healthy socket, while a consumer blocked on a dead peer is unblocked within
        /// about two intervals.
        fn spawn_keep_alive(
            writer: Arc<Mutex<SplitSink<WsStream, Message>>>,
            liveness: Arc<Liveness>,
            closed_tx: watch::Sender<bool>,
            mut closed_rx: watch::Receiver<bool>,
            interval: Duration,
        ) -> JoinHandle<()> {
            tokio::spawn(async move {
                // `Some(n)`: a ping is outstanding and receive call `n` was waiting when the
                // current measurement window started.
                let mut window: Option<u64> = None;
                loop {
                    tokio::select! {
                        biased;
                        _ = closed_rx.changed() => {
                            if *closed_rx.borrow() {
                                return;
                            }
                        }
                        () = tokio::time::sleep(interval) => {}
                    }
                    if *closed_rx.borrow() {
                        return;
                    }
                    if liveness.awaiting_pong.load(Ordering::SeqCst) {
                        let current = liveness.reading_call();
                        if window.is_some() && current == window {
                            // Unanswered across a full interval of continuous reading.
                            let _ = closed_tx.send(true);
                            let mut guard = writer.lock().await;
                            let _ = guard.close().await;
                            return;
                        }
                        window = current;
                        continue;
                    }
                    liveness.awaiting_pong.store(true, Ordering::SeqCst);
                    window = liveness.reading_call();
                    let mut guard = writer.lock().await;
                    if guard.send(Message::Ping(Vec::new().into())).await.is_err() {
                        let _ = closed_tx.send(true);
                        return;
                    }
                }
            })
        }
    }

    /// Keep-alive state shared between the reader and the ping task.
    #[derive(Debug, Default)]
    struct Liveness {
        /// A ping was sent and neither a pong nor any other frame has arrived since.
        awaiting_pong: AtomicBool,
        /// A `receive_message` call is waiting on the socket.
        reading: AtomicBool,
        /// Number of `receive_message` calls that started waiting.
        read_calls: AtomicU64,
    }

    impl Liveness {
        /// Identifies the `receive_message` call waiting right now, if any.
        fn reading_call(&self) -> Option<u64> {
            self.reading
                .load(Ordering::SeqCst)
                .then(|| self.read_calls.load(Ordering::SeqCst))
        }

        fn start_reading(&self) -> ReadingGuard<'_> {
            self.read_calls.fetch_add(1, Ordering::SeqCst);
            self.reading.store(true, Ordering::SeqCst);
            ReadingGuard(self)
        }
    }

    /// Clears [`Liveness::reading`] when a receive call returns or is cancelled.
    struct ReadingGuard<'a>(&'a Liveness);

    impl Drop for ReadingGuard<'_> {
        fn drop(&mut self) {
            self.0.reading.store(false, Ordering::SeqCst);
        }
    }

    impl Drop for TungsteniteWebSocketSession {
        fn drop(&mut self) {
            let _ = self.closed_tx.send(true);
            if let Some(mut guard) = self.keep_alive.try_lock()
                && let Some(handle) = guard.take()
            {
                handle.abort();
            }
        }
    }

    impl FirehoseWebSocketSession for TungsteniteWebSocketSession {
        fn receive_message(&self) -> BoxFuture<'_, Result<Vec<u8>, FirehoseSubscriptionError>> {
            Box::pin(async move {
                let mut closed_rx = self.closed_tx.subscribe();
                if *closed_rx.borrow() {
                    return Err(FirehoseSubscriptionError::ConnectionClosed);
                }

                let mut reader = self.reader.lock().await;
                let _reading = self.liveness.start_reading();
                loop {
                    if *closed_rx.borrow() {
                        return Err(FirehoseSubscriptionError::ConnectionClosed);
                    }
                    let next = tokio::select! {
                        biased;
                        changed = closed_rx.changed() => {
                            if changed.is_err() || *closed_rx.borrow() {
                                return Err(FirehoseSubscriptionError::ConnectionClosed);
                            }
                            continue;
                        }
                        msg = reader.next() => msg,
                    };

                    // Any frame from the peer proves the connection is alive.
                    if matches!(next, Some(Ok(_))) {
                        self.liveness.awaiting_pong.store(false, Ordering::SeqCst);
                    }
                    match next {
                        Some(Ok(Message::Binary(data))) => {
                            if data.len() > self.maximum_message_size {
                                return Err(FirehoseSubscriptionError::FrameTooLarge);
                            }
                            return Ok(data.to_vec());
                        }
                        Some(Ok(Message::Text(text))) => match self.text_frames {
                            TextFrameHandling::Reject => {
                                return Err(FirehoseSubscriptionError::UnsupportedMessageFormat);
                            }
                            TextFrameHandling::Utf8Data => {
                                let bytes = text.as_bytes();
                                if bytes.len() > self.maximum_message_size {
                                    return Err(FirehoseSubscriptionError::FrameTooLarge);
                                }
                                return Ok(bytes.to_vec());
                            }
                        },
                        Some(Ok(Message::Ping(payload))) => {
                            let mut writer = self.writer.lock().await;
                            let _ = writer.send(Message::Pong(payload)).await;
                        }
                        Some(Ok(Message::Pong(_) | Message::Frame(_))) => {}
                        Some(Ok(Message::Close(_))) | None => {
                            return Err(FirehoseSubscriptionError::ConnectionClosed);
                        }
                        Some(Err(err)) => return Err(classify_ws_error(err)),
                    }
                }
            })
        }

        fn close(&self) -> BoxFuture<'_, ()> {
            Box::pin(async move {
                let _ = self.closed_tx.send(true);
                if let Some(handle) = self.keep_alive.lock().await.take() {
                    handle.abort();
                }
                let mut writer = self.writer.lock().await;
                let _ = writer.close().await;
            })
        }

        fn send_text<'a>(
            &'a self,
            text: &'a str,
        ) -> BoxFuture<'a, Result<(), FirehoseSubscriptionError>> {
            Box::pin(async move {
                if *self.closed_tx.borrow() {
                    return Err(FirehoseSubscriptionError::ConnectionClosed);
                }
                let mut writer = self.writer.lock().await;
                writer
                    .send(Message::Text(text.to_owned().into()))
                    .await
                    .map_err(classify_ws_error)
            })
        }
    }

    fn classify_ws_error(err: WsError) -> FirehoseSubscriptionError {
        match err {
            WsError::ConnectionClosed | WsError::AlreadyClosed => {
                FirehoseSubscriptionError::ConnectionClosed
            }
            WsError::Capacity(_) => FirehoseSubscriptionError::FrameTooLarge,
            WsError::Http(resp) => {
                let status = resp.status().as_u16();
                let retry_after_ms = resp
                    .headers()
                    .get("Retry-After")
                    .and_then(|v| v.to_str().ok())
                    .and_then(|s| s.trim().parse::<f64>().ok())
                    .filter(|secs| secs.is_finite() && *secs >= 0.0)
                    .map(|secs| {
                        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
                        let ms = (secs.min(86_400.0 * 365.0) * 1000.0).round() as u64;
                        ms
                    });
                FirehoseSubscriptionError::UpgradeRejected {
                    status,
                    retry_after_ms,
                }
            }
            WsError::HttpFormat(e) => FirehoseSubscriptionError::SecurityViolation(e.to_string()),
            WsError::Url(e) => FirehoseSubscriptionError::SecurityViolation(e.to_string()),
            WsError::Io(e) => FirehoseSubscriptionError::Network(e.to_string()),
            other => FirehoseSubscriptionError::Network(other.to_string()),
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn empty_or_failed_dns_answer_is_retryable_but_private_ips_are_fatal() {
            assert!(matches!(
                classify_dns_answer("relay.example.com", Ok(Vec::new())),
                Err(FirehoseSubscriptionError::Network(_))
            ));
            assert!(matches!(
                classify_dns_answer("relay.example.com", Err("SERVFAIL".to_owned())),
                Err(FirehoseSubscriptionError::Network(_))
            ));
            assert_eq!(
                classify_dns_answer("localhost", Ok(Vec::new()))
                    .unwrap()
                    .len(),
                2
            );
            let public = vec![IpAddr::V4(Ipv4Addr::new(93, 184, 216, 34))];
            assert_eq!(
                classify_dns_answer("relay.example.com", Ok(public.clone())),
                Ok(public)
            );
            // The address policy itself stays fatal.
            let private = [IpAddr::V4(Ipv4Addr::new(10, 0, 0, 1))];
            assert!(validate_resolved_addresses("relay.example.com", &private).is_err());
        }
    }
}

#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
mod browser {
    use std::cell::{Cell, RefCell};
    use std::rc::Rc;

    use async_lock::Mutex;
    use futures_channel::mpsc;
    use futures_util::StreamExt;
    use js_sys::{Array, ArrayBuffer, Uint8Array};
    use petrel::net::policy::validate_url_with_development;
    use petrel::rt::BoxFuture;
    use url::Url;
    use wasm_bindgen::JsCast;
    use wasm_bindgen::closure::Closure;
    use web_sys::{BinaryType, CloseEvent, ErrorEvent, MessageEvent, WebSocket};

    use super::{
        FirehoseSubscriptionError, FirehoseWebSocketOptions, FirehoseWebSocketSession,
        FirehoseWebSocketSessionFactory, TextFrameHandling, is_loopback_host_str,
    };

    const BROWSER_CHANNEL_CAPACITY: usize = 256;

    /// Browser WebSocket session factory backed by `web_sys::WebSocket`.
    #[derive(Debug, Clone)]
    pub struct BrowserWebSocketFactory {
        /// Transport settings applied to every opened connection.
        pub options: FirehoseWebSocketOptions,
    }

    impl BrowserWebSocketFactory {
        /// Creates a browser WebSocket factory with default options.
        pub fn new() -> Self {
            Self {
                options: FirehoseWebSocketOptions::new(),
            }
        }

        /// Creates a browser WebSocket factory with explicit options.
        pub fn with_options(options: FirehoseWebSocketOptions) -> Self {
            Self { options }
        }
    }

    impl Default for BrowserWebSocketFactory {
        fn default() -> Self {
            Self::new()
        }
    }

    impl FirehoseWebSocketSessionFactory for BrowserWebSocketFactory {
        fn make_session(
            &self,
            url: Url,
        ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>>
        {
            self.make_session_with_subprotocols(url, Vec::new())
        }

        #[allow(clippy::too_many_lines)]
        fn make_session_with_subprotocols(
            &self,
            url: Url,
            subprotocols: Vec<String>,
        ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>>
        {
            let options = self.options.clone();
            Box::pin(async move {
                let host = url
                    .host_str()
                    .ok_or_else(|| {
                        FirehoseSubscriptionError::SecurityViolation("URL has no host".to_owned())
                    })?
                    .to_owned();
                let allow_loopback = is_loopback_host_str(&host);
                validate_url_with_development(&url, allow_loopback)
                    .map_err(|e| FirehoseSubscriptionError::SecurityViolation(e.to_string()))?;

                let ws = if subprotocols.is_empty() {
                    WebSocket::new(url.as_str())
                } else {
                    let array = Array::new();
                    for proto in &subprotocols {
                        array.push(&wasm_bindgen::JsValue::from_str(proto));
                    }
                    WebSocket::new_with_str_sequence(url.as_str(), &array)
                }
                .map_err(|e| {
                    FirehoseSubscriptionError::WebSocketTransportUnavailable(format!("{e:?}"))
                })?;

                ws.set_binary_type(BinaryType::Arraybuffer);

                let (mut msg_tx, msg_rx) = mpsc::channel::<
                    Result<Vec<u8>, FirehoseSubscriptionError>,
                >(BROWSER_CHANNEL_CAPACITY);
                let (open_tx, open_rx) =
                    futures_channel::oneshot::channel::<Result<(), FirehoseSubscriptionError>>();
                let open_tx = Rc::new(RefCell::new(Some(open_tx)));
                let closed_flag = Rc::new(Cell::new(false));

                let onopen_tx = Rc::clone(&open_tx);
                let onopen = Closure::<dyn FnMut()>::new(move || {
                    if let Some(tx) = onopen_tx.borrow_mut().take() {
                        let _ = tx.send(Ok(()));
                    }
                });

                let mut msg_tx_on_msg = msg_tx.clone();
                let text_frames = options.text_frames;
                let max_size = options.maximum_message_size;
                let ws_on_msg = ws.clone();
                let closed_on_msg = Rc::clone(&closed_flag);
                let onmessage = Closure::<dyn FnMut(MessageEvent)>::new(move |ev: MessageEvent| {
                    let item = if let Ok(buf) = ev.data().dyn_into::<ArrayBuffer>() {
                        let arr = Uint8Array::new(&buf);
                        let len = arr.byte_length() as usize;
                        if len > max_size {
                            Err(FirehoseSubscriptionError::FrameTooLarge)
                        } else {
                            let mut out = vec![0_u8; len];
                            arr.copy_to(&mut out);
                            Ok(out)
                        }
                    } else if let Some(text) = ev.data().as_string() {
                        match text_frames {
                            TextFrameHandling::Reject => {
                                Err(FirehoseSubscriptionError::UnsupportedMessageFormat)
                            }
                            TextFrameHandling::Utf8Data => {
                                let bytes = text.into_bytes();
                                if bytes.len() > max_size {
                                    Err(FirehoseSubscriptionError::FrameTooLarge)
                                } else {
                                    Ok(bytes)
                                }
                            }
                        }
                    } else {
                        Err(FirehoseSubscriptionError::UnsupportedMessageFormat)
                    };
                    enqueue_or_close_browser_channel(&mut msg_tx_on_msg, item, || {
                        closed_on_msg.set(true);
                        ws_on_msg.set_onmessage(None);
                        let _ = ws_on_msg.close();
                    });
                });

                let onerror_open_tx = Rc::clone(&open_tx);
                let mut onerror_msg_tx = msg_tx.clone();
                let onerror = Closure::<dyn FnMut(ErrorEvent)>::new(move |ev: ErrorEvent| {
                    let msg = ev.message();
                    if let Some(tx) = onerror_open_tx.borrow_mut().take() {
                        let _ = tx.send(Err(FirehoseSubscriptionError::Network(msg.clone())));
                    }
                    let _ = onerror_msg_tx.try_send(Err(FirehoseSubscriptionError::Network(msg)));
                });

                let onclose_open_tx = Rc::clone(&open_tx);
                let onclose_closed = Rc::clone(&closed_flag);
                let onclose = Closure::<dyn FnMut(CloseEvent)>::new(move |_ev: CloseEvent| {
                    onclose_closed.set(true);
                    if let Some(tx) = onclose_open_tx.borrow_mut().take() {
                        let _ = tx.send(Err(FirehoseSubscriptionError::ConnectionClosed));
                    }
                    let _ = msg_tx.try_send(Err(FirehoseSubscriptionError::ConnectionClosed));
                    msg_tx.close_channel();
                });

                ws.set_onopen(Some(onopen.as_ref().unchecked_ref()));
                ws.set_onmessage(Some(onmessage.as_ref().unchecked_ref()));
                ws.set_onerror(Some(onerror.as_ref().unchecked_ref()));
                ws.set_onclose(Some(onclose.as_ref().unchecked_ref()));

                match open_rx.await {
                    Ok(Ok(())) => {}
                    Ok(Err(e)) => {
                        let _ = ws.close();
                        return Err(e);
                    }
                    Err(_) => {
                        let _ = ws.close();
                        return Err(FirehoseSubscriptionError::ConnectionClosed);
                    }
                }

                Ok(Box::new(BrowserWebSocketSession {
                    ws,
                    rx: Mutex::new(msg_rx),
                    closed: closed_flag,
                    _closures: (onopen, onmessage, onerror, onclose),
                }) as Box<dyn FirehoseWebSocketSession>)
            })
        }
    }

    type BrowserWsClosures = (
        Closure<dyn FnMut()>,
        Closure<dyn FnMut(MessageEvent)>,
        Closure<dyn FnMut(ErrorEvent)>,
        Closure<dyn FnMut(CloseEvent)>,
    );

    /// Active browser WebSocket session.
    pub struct BrowserWebSocketSession {
        ws: WebSocket,
        rx: Mutex<mpsc::Receiver<Result<Vec<u8>, FirehoseSubscriptionError>>>,
        closed: Rc<Cell<bool>>,
        _closures: BrowserWsClosures,
    }

    impl std::fmt::Debug for BrowserWebSocketSession {
        fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            f.debug_struct("BrowserWebSocketSession")
                .field("ready_state", &self.ws.ready_state())
                .finish_non_exhaustive()
        }
    }

    impl Drop for BrowserWebSocketSession {
        fn drop(&mut self) {
            self.closed.set(true);
            self.ws.set_onopen(None);
            self.ws.set_onmessage(None);
            self.ws.set_onerror(None);
            self.ws.set_onclose(None);
            let _ = self.ws.close();
        }
    }

    impl FirehoseWebSocketSession for BrowserWebSocketSession {
        fn receive_message(&self) -> BoxFuture<'_, Result<Vec<u8>, FirehoseSubscriptionError>> {
            Box::pin(async move {
                let mut rx = self.rx.lock().await;
                match rx.next().await {
                    Some(res) => res,
                    None => Err(FirehoseSubscriptionError::ConnectionClosed),
                }
            })
        }

        fn close(&self) -> BoxFuture<'_, ()> {
            Box::pin(async move {
                self.closed.set(true);
                let _ = self.ws.close();
            })
        }

        fn send_text<'a>(
            &'a self,
            text: &'a str,
        ) -> BoxFuture<'a, Result<(), FirehoseSubscriptionError>> {
            Box::pin(async move {
                if self.closed.get() {
                    return Err(FirehoseSubscriptionError::ConnectionClosed);
                }
                self.ws
                    .send_with_str(text)
                    .map_err(|e| FirehoseSubscriptionError::Network(format!("{e:?}")))
            })
        }
    }

    /// Enqueues a browser WebSocket message or closes the socket/channel on buffer overflow
    /// so subsequent frames are never silently skipped without cursor recovery.
    fn enqueue_or_close_browser_channel(
        tx: &mut mpsc::Sender<Result<Vec<u8>, FirehoseSubscriptionError>>,
        item: Result<Vec<u8>, FirehoseSubscriptionError>,
        on_close: impl FnOnce(),
    ) -> bool {
        if tx.try_send(item).is_ok() {
            return true;
        }
        tx.close_channel();
        on_close();
        false
    }

    #[cfg(test)]
    mod tests {
        use futures_util::StreamExt;

        use super::*;

        #[wasm_bindgen_test::wasm_bindgen_test]
        async fn browser_channel_overflow_closes_socket_and_channel_instead_of_dropping() {
            // `futures_channel::mpsc::channel(1)` yields 1 shared + 1 sender-reserved slot = 2.
            let (mut tx, mut rx) = mpsc::channel(1);
            let mut closed_calls = 0usize;

            assert!(enqueue_or_close_browser_channel(
                &mut tx,
                Ok(vec![1]),
                || {
                    closed_calls += 1;
                }
            ));
            assert!(enqueue_or_close_browser_channel(
                &mut tx,
                Ok(vec![2]),
                || {
                    closed_calls += 1;
                }
            ));
            // Third frame overflows capacity=2: closes channel and triggers socket close callback.
            assert!(!enqueue_or_close_browser_channel(
                &mut tx,
                Ok(vec![3]),
                || {
                    closed_calls += 1;
                }
            ));
            assert_eq!(closed_calls, 1);

            // Subsequent frames after overflow are rejected too.
            assert!(!enqueue_or_close_browser_channel(
                &mut tx,
                Ok(vec![4]),
                || {
                    closed_calls += 1;
                }
            ));
            assert_eq!(closed_calls, 2);

            // Buffered frames drain cleanly in order, followed by EOF so the pump reconnects.
            assert_eq!(rx.next().await.unwrap().unwrap(), vec![1]);
            assert_eq!(rx.next().await.unwrap().unwrap(), vec![2]);
            assert!(rx.next().await.is_none());
        }
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub use native::{TungsteniteWebSocketFactory, TungsteniteWebSocketSession};

#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
pub use browser::{BrowserWebSocketFactory, BrowserWebSocketSession};

/// Returns the default platform WebSocket session factory configured with `options`.
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub fn default_websocket_factory(
    options: FirehoseWebSocketOptions,
) -> std::sync::Arc<dyn FirehoseWebSocketSessionFactory> {
    std::sync::Arc::new(TungsteniteWebSocketFactory::with_options(options))
}

/// Returns the default browser WebSocket session factory configured with `options`.
#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
pub fn default_websocket_factory(
    options: FirehoseWebSocketOptions,
) -> std::sync::Arc<dyn FirehoseWebSocketSessionFactory> {
    std::sync::Arc::new(BrowserWebSocketFactory::with_options(options))
}
