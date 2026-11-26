//! HTTP transport abstraction and Jetstream v2 XRPC endpoints (`planSnapshot`, `getBlock`,
//! `getSegment`, `getZstdDictionary`).

use std::sync::Arc;

use bytes::Bytes;
use petrel::net::{SendOptions, SharedTransport, TransportError};
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use serde::{Deserialize, Serialize};
use url::Url;

use crate::event::{JetstreamFilter, JetstreamKind};

/// Default archive download response byte ceiling for `getSegment` (128 MiB, matching
/// `petrel`'s `ReqwestTransport` and `FetchTransport` upper bound).
pub const DEFAULT_MAX_SEGMENT_BYTES: u64 = 128 * 1024 * 1024;
const SEGMENT_DOWNLOAD_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(300);

/// Object-safe HTTP transport for Jetstream XRPC calls and archive downloads.
pub trait JetstreamHttpTransport: MaybeSend + MaybeSync + std::fmt::Debug {
    /// Sends one HTTP request and returns its status + response body bytes.
    fn send(
        &self,
        request: http::Request<Bytes>,
    ) -> BoxFuture<'_, Result<http::Response<Bytes>, TransportError>>;

    /// Sends one HTTP request with an explicit decoded response byte limit override.
    fn send_with_max_bytes(
        &self,
        request: http::Request<Bytes>,
        _max_response_bytes: Option<u64>,
    ) -> BoxFuture<'_, Result<http::Response<Bytes>, TransportError>> {
        self.send(request)
    }
}

/// [`JetstreamHttpTransport`] backed by `petrel::net::SharedTransport` (`ReqwestTransport` on
/// native, `FetchTransport` on `wasm32`).
#[derive(Clone)]
pub struct PetrelJetstreamHttpTransport {
    transport: SharedTransport,
}

impl std::fmt::Debug for PetrelJetstreamHttpTransport {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PetrelJetstreamHttpTransport")
            .finish_non_exhaustive()
    }
}

impl PetrelJetstreamHttpTransport {
    /// Wraps an existing `petrel` `SharedTransport`.
    pub fn new(transport: SharedTransport) -> Self {
        Self { transport }
    }

    fn send_with_options(
        &self,
        request: http::Request<Bytes>,
        max_response_bytes: Option<u64>,
    ) -> BoxFuture<'_, Result<http::Response<Bytes>, TransportError>> {
        Box::pin(async move {
            let mut options = SendOptions::new();
            let host = request
                .uri()
                .host()
                .map(str::to_ascii_lowercase)
                .unwrap_or_default();
            if matches!(host.as_str(), "localhost" | "127.0.0.1" | "[::1]" | "::1") {
                options.allow_loopback = true;
            }
            let is_segment = request
                .uri()
                .path()
                .ends_with("/network.bsky.jetstream.getSegment");
            options.max_response_bytes =
                max_response_bytes.or_else(|| is_segment.then_some(DEFAULT_MAX_SEGMENT_BYTES));
            if is_segment || max_response_bytes.is_some() {
                options.timeout = Some(SEGMENT_DOWNLOAD_TIMEOUT);
            }
            self.transport.send_dyn(request, &options).await
        })
    }
}

impl JetstreamHttpTransport for PetrelJetstreamHttpTransport {
    fn send(
        &self,
        request: http::Request<Bytes>,
    ) -> BoxFuture<'_, Result<http::Response<Bytes>, TransportError>> {
        self.send_with_options(request, None)
    }

    fn send_with_max_bytes(
        &self,
        request: http::Request<Bytes>,
        max_response_bytes: Option<u64>,
    ) -> BoxFuture<'_, Result<http::Response<Bytes>, TransportError>> {
        self.send_with_options(request, max_response_bytes)
    }
}

/// Returns the platform default [`JetstreamHttpTransport`].
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub fn default_http_transport() -> Result<Arc<dyn JetstreamHttpTransport>, TransportError> {
    let transport = petrel::net::ReqwestTransport::new()?;
    Ok(Arc::new(PetrelJetstreamHttpTransport::new(Arc::new(
        transport,
    ))))
}

/// Returns the browser default [`JetstreamHttpTransport`].
#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
#[allow(clippy::arc_with_non_send_sync)]
pub fn default_http_transport() -> Result<Arc<dyn JetstreamHttpTransport>, TransportError> {
    let transport = petrel::net::FetchTransport;
    Ok(Arc::new(PetrelJetstreamHttpTransport::new(Arc::new(
        transport,
    ))))
}

/// Non-2xx XRPC response returned by Jetstream HTTP endpoints.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("Jetstream XRPC HTTP {status}{}{}", .error.as_deref().map_or(String::new(), |e| format!(" ({e})")), .message.as_deref().map_or(String::new(), |m| format!(": {m}")))]
pub struct JetstreamXrpcError {
    pub status: u16,
    pub error: Option<String>,
    pub message: Option<String>,
}

/// Combined error returned by [`JetstreamXrpcClient`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum JetstreamHttpError {
    #[error(transparent)]
    Xrpc(#[from] JetstreamXrpcError),
    #[error(transparent)]
    Transport(#[from] TransportError),
    #[error("invalid Jetstream endpoint URL: {0}")]
    InvalidUrl(String),
    #[error("invalid JSON response: {0}")]
    Decode(String),
}

/// Request payload for `network.bsky.jetstream.planSnapshot`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SnapshotPlanRequest {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub kinds: Option<Vec<JetstreamKind>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dids: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub collections: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub after_seq: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub before_seq: Option<i64>,
}

impl SnapshotPlanRequest {
    /// Builds a snapshot plan request from a [`JetstreamFilter`].
    pub fn from_filter(
        filter: &JetstreamFilter,
        after_seq: Option<i64>,
        before_seq: Option<i64>,
    ) -> Self {
        Self {
            kinds: (!filter.kinds.is_empty()).then(|| filter.kinds.clone()),
            dids: (!filter.dids.is_empty()).then(|| filter.dids.clone()),
            collections: (!filter.collections.is_empty()).then(|| filter.collections.clone()),
            after_seq,
            before_seq,
        }
    }
}

/// Inclusive range of block indices within a segment.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct SnapshotBlockRange {
    pub first: usize,
    pub last: usize,
}

/// One segment entry in a [`SnapshotPlan`].
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SnapshotPlanSegment {
    pub name: String,
    pub index: usize,
    pub checksum: String,
    pub min_seq: i64,
    pub max_seq: i64,
    pub mode: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub blocks: Option<Vec<SnapshotBlockRange>>,
}

/// Planner statistics returned inside [`SnapshotPlan`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SnapshotPlanStats {
    pub segments_examined: usize,
    pub segments_matched: usize,
    pub blocks_matched: usize,
    pub entries: usize,
}

/// Response payload from `network.bsky.jetstream.planSnapshot`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SnapshotPlan {
    pub planned_through_seq: i64,
    pub sealed_tip_seq: i64,
    pub segments: Vec<SnapshotPlanSegment>,
    pub stats: SnapshotPlanStats,
}

#[derive(Deserialize)]
struct XrpcErrorEnvelope {
    error: Option<String>,
    message: Option<String>,
}

/// Client for Jetstream v2 archive/dictionary HTTP XRPC endpoints.
#[derive(Debug, Clone)]
pub struct JetstreamXrpcClient {
    pub host: Url,
    pub transport: Arc<dyn JetstreamHttpTransport>,
    /// Optional raw API key sent as `Authorization: Bearer <key>` on HTTP backfill requests.
    pub api_key: Option<String>,
    /// Maximum decoded byte limit for whole-segment downloads (`getSegment`).
    pub max_segment_bytes: u64,
}

impl JetstreamXrpcClient {
    /// Creates an XRPC client for `host`.
    pub fn new(
        host: Url,
        transport: Arc<dyn JetstreamHttpTransport>,
        api_key: Option<String>,
    ) -> Self {
        Self {
            host,
            transport,
            api_key,
            max_segment_bytes: DEFAULT_MAX_SEGMENT_BYTES,
        }
    }

    /// Calls `POST /xrpc/network.bsky.jetstream.planSnapshot`.
    pub async fn plan_snapshot(
        &self,
        request: &SnapshotPlanRequest,
    ) -> Result<SnapshotPlan, JetstreamHttpError> {
        let url = self.build_url("network.bsky.jetstream.planSnapshot", &[]);
        let body =
            serde_json::to_vec(request).map_err(|e| JetstreamHttpError::Decode(e.to_string()))?;
        let mut builder = http::Request::builder()
            .method(http::Method::POST)
            .uri(url.as_str())
            .header(http::header::CONTENT_TYPE, "application/json")
            .header(http::header::ACCEPT, "application/json");
        if let Some(key) = &self.api_key {
            builder = builder.header(http::header::AUTHORIZATION, format!("Bearer {key}"));
        }
        let req = builder
            .body(Bytes::from(body))
            .map_err(|e| JetstreamHttpError::InvalidUrl(e.to_string()))?;
        let resp = self.transport.send(req).await?;
        validate_response(&resp)?;
        serde_json::from_slice(resp.body()).map_err(|e| JetstreamHttpError::Decode(e.to_string()))
    }

    /// Calls `GET /xrpc/network.bsky.jetstream.getBlock`.
    pub async fn get_block(
        &self,
        segment: &str,
        block_index: usize,
    ) -> Result<Vec<u8>, JetstreamHttpError> {
        let idx_str = block_index.to_string();
        let url = self.build_url(
            "network.bsky.jetstream.getBlock",
            &[("segment", segment), ("blockIndex", &idx_str)],
        );
        let req = self.make_get(&url)?;
        let resp = self.transport.send(req).await?;
        validate_response(&resp)?;
        Ok(resp.body().to_vec())
    }

    /// Calls `GET /xrpc/network.bsky.jetstream.getSegment` returning raw `.jss` bytes.
    pub async fn get_segment(&self, name: &str) -> Result<Vec<u8>, JetstreamHttpError> {
        let url = self.build_url("network.bsky.jetstream.getSegment", &[("name", name)]);
        let req = self.make_get(&url)?;
        let resp = self
            .transport
            .send_with_max_bytes(req, Some(self.max_segment_bytes))
            .await?;
        validate_response(&resp)?;
        Ok(resp.body().to_vec())
    }

    /// Calls `GET /xrpc/network.bsky.jetstream.getZstdDictionary`.
    pub async fn get_zstd_dictionary(
        &self,
        id: Option<u32>,
    ) -> Result<Vec<u8>, JetstreamHttpError> {
        let id_str = id.map(|v| v.to_string());
        let query = match id_str.as_deref() {
            Some(v) => vec![("id", v)],
            None => Vec::new(),
        };
        let url = self.build_url("network.bsky.jetstream.getZstdDictionary", &query);
        let req = self.make_get(&url)?;
        let resp = self
            .transport
            .send_with_max_bytes(req, Some(crate::zstd::DEFAULT_MAX_DICTIONARY_BYTES as u64))
            .await?;
        validate_response(&resp)?;
        Ok(resp.body().to_vec())
    }

    fn make_get(&self, url: &Url) -> Result<http::Request<Bytes>, JetstreamHttpError> {
        let mut builder = http::Request::builder()
            .method(http::Method::GET)
            .uri(url.as_str());
        if let Some(key) = &self.api_key {
            builder = builder.header(http::header::AUTHORIZATION, format!("Bearer {key}"));
        }
        builder
            .body(Bytes::new())
            .map_err(|e| JetstreamHttpError::InvalidUrl(e.to_string()))
    }

    fn build_url(&self, nsid: &str, query: &[(&str, &str)]) -> Url {
        let mut url = self.host.clone();
        let base = url.path().trim_end_matches('/');
        let path = if base.is_empty() {
            format!("/xrpc/{nsid}")
        } else {
            format!("{base}/xrpc/{nsid}")
        };
        url.set_path(&path);
        url.set_query(None);
        if !query.is_empty() {
            let mut pairs = url.query_pairs_mut();
            for (k, v) in query {
                pairs.append_pair(k, v);
            }
        }
        url
    }
}

fn validate_response(resp: &http::Response<Bytes>) -> Result<(), JetstreamHttpError> {
    let status = resp.status().as_u16();
    if (200..300).contains(&status) {
        return Ok(());
    }
    let env = serde_json::from_slice::<XrpcErrorEnvelope>(resp.body()).ok();
    Err(JetstreamHttpError::Xrpc(JetstreamXrpcError {
        status,
        error: env.as_ref().and_then(|e| e.error.clone()),
        message: env.and_then(|e| e.message),
    }))
}
