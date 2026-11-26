use std::future::Future;
use std::marker::PhantomData;
use std::net::{IpAddr, SocketAddr};
use std::pin::Pin;
use std::sync::Arc;
use std::task::{Context, Poll};

use axum::body::Body;
use axum::extract::{
    ConnectInfo, FromRef, FromRequest, FromRequestParts, OptionalFromRequestParts, OriginalUri,
    Request,
};
use axum::http::header::{AUTHORIZATION, CONTENT_LENGTH, CONTENT_TYPE, HOST};
use axum::http::request::Parts;
use axum::http::{Extensions, HeaderMap, HeaderName, HeaderValue, StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use axum::routing::{MethodRouter, any, get, post};
use axum::{Extension, Router};
use petrel_core::{
    Bytes, DeclaredXrpcError, FromQueryParams, FromValue, ToValue, XrpcErrorBody, XrpcMethod,
    XrpcRequest,
};
use tower_layer::Layer;
use tower_service::Service;

use crate::cab::CabServerCore;
use crate::http::{OAuthHttpHeaders, OAuthHttpRequest, OAuthHttpResponse};
use crate::oauth::{
    OAuthAccessGrant, OAuthAuthorizationServer, OAuthResourceChallenge, OAuthResourceServerVerifier,
};
use crate::service_auth::{
    ServiceAuthError, ServiceAuthMethodPolicy, ServiceAuthVerifier, VerifiedServiceAuth,
};
use crate::xrpc::{XrpcServerError, decode_xrpc_json_strict, decode_xrpc_query, encode_xrpc_json};

/// Default request body limit (2 MiB) for the OAuth/CAB adapters and XRPC body extractors.
pub const DEFAULT_BODY_LIMIT: usize = 2 * 1024 * 1024;

/// Request extension setting the maximum body size read by [`StrictXrpcJson`] and
/// [`XrpcRawBody`] (default [`DEFAULT_BODY_LIMIT`]).
///
/// [`XrpcRouter::with_body_limit`] and [`XrpcRouteOptions::body_limit`] insert it; a hand-built
/// route can add `axum::Extension(XrpcBodyLimit(n))` as a layer.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct XrpcBodyLimit(pub usize);

/// Where the OAuth/CAB adapters take the client IP used as the rate-limit key.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub enum ClientIpSource {
    /// The socket peer from `ConnectInfo<SocketAddr>` (default). Behind a reverse proxy this is
    /// the proxy, so every client shares one bucket.
    #[default]
    ConnectInfo,
    /// A header set by a trusted reverse proxy (for example `X-Forwarded-For` from Caddy).
    ///
    /// Only the right-most (or sole) value is used, the one the proxy itself appended, and it
    /// must parse as an IP address. A missing or invalid value yields no client IP (the shared
    /// unauthenticated bucket), never the socket peer. Configure this only when every request
    /// reaches the service through that proxy; otherwise clients can choose their own key.
    TrustedHeader(HeaderName),
}

/// Options for [`oauth_router_with_options`] and [`cab_router_with_options`].
#[derive(Debug, Clone, PartialEq, Eq)]
#[non_exhaustive]
pub struct AxumAdapterOptions {
    /// Maximum request body in bytes; larger requests get `413` (default [`DEFAULT_BODY_LIMIT`]).
    pub body_limit: usize,
    /// Client IP source for rate limiting (default [`ClientIpSource::ConnectInfo`]).
    pub client_ip_source: ClientIpSource,
}

impl Default for AxumAdapterOptions {
    fn default() -> Self {
        Self {
            body_limit: DEFAULT_BODY_LIMIT,
            client_ip_source: ClientIpSource::ConnectInfo,
        }
    }
}

impl AxumAdapterOptions {
    /// Sets the maximum request body size in bytes.
    #[must_use]
    pub const fn with_body_limit(mut self, limit: usize) -> Self {
        self.body_limit = limit;
        self
    }

    /// Sets where the client IP is taken from.
    #[must_use]
    pub fn with_client_ip_source(mut self, source: ClientIpSource) -> Self {
        self.client_ip_source = source;
        self
    }
}

/// Mounts all [`OAuthAuthorizationServer`] endpoints onto an [`axum::Router`].
pub fn oauth_router<S>(server: Arc<OAuthAuthorizationServer>) -> Router<S>
where
    S: Clone + Send + Sync + 'static,
{
    oauth_router_with_options(server, AxumAdapterOptions::default())
}

/// [`oauth_router`] with an explicit body limit and client IP source.
pub fn oauth_router_with_options<S>(
    server: Arc<OAuthAuthorizationServer>,
    options: AxumAdapterOptions,
) -> Router<S>
where
    S: Clone + Send + Sync + 'static,
{
    let options = Arc::new(options);
    let dispatch = {
        let srv = server;
        move |req: Request<Body>| {
            let srv = srv.clone();
            let options = options.clone();
            async move {
                match axum_to_oauth_request(req, &options).await {
                    Ok(oauth_req) => oauth_to_axum_response(srv.handle(oauth_req).await),
                    Err(BodyTooLarge) => oauth_payload_too_large(options.body_limit),
                }
            }
        }
    };
    Router::new()
        .route(
            "/.well-known/oauth-authorization-server",
            any(dispatch.clone()),
        )
        .route(
            "/.well-known/oauth-protected-resource",
            any(dispatch.clone()),
        )
        .route("/oauth/jwks", any(dispatch.clone()))
        .route("/oauth/par", any(dispatch.clone()))
        .route("/oauth/authorize", any(dispatch.clone()))
        .route("/oauth/token", any(dispatch.clone()))
        .route("/oauth/revoke", any(dispatch))
}

/// Mounts all [`CabServerCore`] endpoints onto an [`axum::Router`].
pub fn cab_router<S>(cab: Arc<CabServerCore>) -> Router<S>
where
    S: Clone + Send + Sync + 'static,
{
    cab_router_with_options(cab, AxumAdapterOptions::default())
}

/// [`cab_router`] with an explicit body limit and client IP source (for example a trusted
/// `X-Forwarded-For` header when the CAB runs behind a reverse proxy).
pub fn cab_router_with_options<S>(cab: Arc<CabServerCore>, options: AxumAdapterOptions) -> Router<S>
where
    S: Clone + Send + Sync + 'static,
{
    let options = Arc::new(options);
    let dispatch = {
        let cab = cab;
        move |req: Request<Body>| {
            let cab = cab.clone();
            let options = options.clone();
            async move {
                match axum_to_oauth_request(req, &options).await {
                    Ok(oauth_req) => oauth_to_axum_response(cab.handle(oauth_req).await),
                    Err(BodyTooLarge) => oauth_payload_too_large(options.body_limit),
                }
            }
        }
    };
    Router::new()
        .route("/health", any(dispatch.clone()))
        .route(
            "/.well-known/oauth-client-metadata.json",
            any(dispatch.clone()),
        )
        .route("/oauth-client-metadata.json", any(dispatch.clone()))
        .route("/.well-known/jwks.json", any(dispatch.clone()))
        .route("/nonce", any(dispatch.clone()))
        .route("/v1/nonce", any(dispatch.clone()))
        .route("/v1/devices/register", any(dispatch.clone()))
        .route("/oauth/client-assertion", any(dispatch.clone()))
        .route("/v1/assertions", any(dispatch))
}

async fn axum_to_oauth_request(
    req: Request<Body>,
    options: &AxumAdapterOptions,
) -> Result<OAuthHttpRequest, BodyTooLarge> {
    let client_ip = match &options.client_ip_source {
        ClientIpSource::ConnectInfo => req
            .extensions()
            .get::<ConnectInfo<SocketAddr>>()
            .map(|c| c.0.ip()),
        ClientIpSource::TrustedHeader(name) => {
            let ip = client_ip_from_header(req.headers(), name);
            if ip.is_none() {
                tracing::debug!(header = %name, "trusted client IP header missing or invalid");
            }
            ip
        }
    };
    let (parts, body) = req.into_parts();
    let mut headers = OAuthHttpHeaders::default();
    for (name, val) in &parts.headers {
        if let Ok(s) = val.to_str() {
            headers.add(name.as_str(), s);
        }
    }
    let bytes = read_limited(&parts.headers, body, options.body_limit).await?;
    let mut out = OAuthHttpRequest::new(parts.method.as_str(), parts.uri.path());
    if let Some(q) = parts.uri.query() {
        out = out.with_query(q);
    }
    out = out.with_headers(headers).with_body(bytes.to_vec());
    if let Some(ip) = client_ip {
        out = out.with_remote_address(ip.to_string());
    }
    Ok(out)
}

/// Right-most (or sole) value of `name`, parsed as an IP (bare, or `ip:port` / `[v6]:port`).
fn client_ip_from_header(headers: &HeaderMap, name: &HeaderName) -> Option<IpAddr> {
    let last = headers.get_all(name).iter().next_back()?.to_str().ok()?;
    let candidate = last.rsplit(',').next()?.trim();
    candidate
        .parse::<IpAddr>()
        .ok()
        .or_else(|| candidate.parse::<SocketAddr>().ok().map(|sa| sa.ip()))
}

/// Error from [`read_limited`]: the body exceeded the limit (or could not be read).
struct BodyTooLarge;

/// Reads a body of at most `limit` bytes, failing fast on an oversized `Content-Length`.
async fn read_limited(
    headers: &HeaderMap,
    body: Body,
    limit: usize,
) -> Result<axum::body::Bytes, BodyTooLarge> {
    let declared = headers
        .get(CONTENT_LENGTH)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<u64>().ok());
    if declared.is_some_and(|len| len > limit as u64) {
        return Err(BodyTooLarge);
    }
    axum::body::to_bytes(body, limit)
        .await
        .map_err(|_| BodyTooLarge)
}

fn oauth_payload_too_large(limit: usize) -> Response {
    let body = serde_json::to_vec(&serde_json::json!({
        "error": "invalid_request",
        "error_description": format!("request body exceeds {limit} bytes"),
    }))
    .unwrap_or_else(|_| b"{}".to_vec());
    (
        StatusCode::PAYLOAD_TOO_LARGE,
        [(CONTENT_TYPE, HeaderValue::from_static("application/json"))],
        body,
    )
        .into_response()
}

fn oauth_to_axum_response(resp: OAuthHttpResponse) -> Response {
    let status = StatusCode::from_u16(resp.status).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);
    let mut builder = Response::builder().status(status);
    for field in resp.headers.fields() {
        if let (Ok(name), Ok(val)) = (
            HeaderName::from_bytes(field.name.as_bytes()),
            HeaderValue::from_str(&field.value),
        ) {
            builder = builder.header(name, val);
        }
    }
    builder
        .body(Body::from(resp.body))
        .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response())
}

// ---------------------------------------------------------------------------
// DPoP Resource Server Axum Extractor
// ---------------------------------------------------------------------------

/// Configuration passed via Axum state (`FromRef`) for [`DpopResourceAuth`].
#[derive(Clone)]
pub struct DpopVerifierState {
    pub verifier: Arc<OAuthResourceServerVerifier>,
    /// Public base URL (e.g. `https://api.example.com`). Required for relative URIs unless `allow_forwarded_host_fallback` is enabled.
    pub public_base_url: Option<String>,
    /// Allow falling back to `Host` / `X-Forwarded-Proto` when `public_base_url` is `None` (default `false`; loopback/dev only).
    pub allow_forwarded_host_fallback: bool,
}

impl DpopVerifierState {
    /// Creates Axum DPoP verifier state with explicit `public_base_url` (forwarded-host fallback disabled).
    pub fn new(
        verifier: Arc<OAuthResourceServerVerifier>,
        public_base_url: Option<String>,
    ) -> Self {
        Self {
            verifier,
            public_base_url,
            allow_forwarded_host_fallback: false,
        }
    }
}

impl std::fmt::Debug for DpopVerifierState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DpopVerifierState")
            .field("public_base_url", &self.public_base_url)
            .finish_non_exhaustive()
    }
}

/// Axum `FromRequestParts` extractor authenticating OAuth 2.1 `DPoP` resource requests.
#[derive(Debug, Clone)]
pub struct DpopResourceAuth(pub OAuthAccessGrant);

impl IntoResponse for OAuthResourceChallenge {
    fn into_response(self) -> Response {
        let status = StatusCode::from_u16(self.status).unwrap_or(StatusCode::UNAUTHORIZED);
        let mut headers = HeaderMap::new();
        if let Ok(val) = HeaderValue::from_str(&self.www_authenticate) {
            headers.insert(HeaderName::from_static("www-authenticate"), val);
        }
        if let Some(ref nonce) = self.dpop_nonce
            && let Ok(val) = HeaderValue::from_str(nonce)
        {
            headers.insert(HeaderName::from_static("dpop-nonce"), val);
        }
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        let body = serde_json::to_vec(&serde_json::json!({
            "error": self.error,
            "error_description": self.error_description,
        }))
        .unwrap_or_else(|_| b"{}".to_vec());
        (status, headers, body).into_response()
    }
}

impl<S> FromRequestParts<S> for DpopResourceAuth
where
    S: Send + Sync,
    DpopVerifierState: FromRef<S>,
{
    type Rejection = OAuthResourceChallenge;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let cfg = DpopVerifierState::from_ref(state);
        let mut headers = OAuthHttpHeaders::default();
        for (name, val) in &parts.headers {
            if let Ok(s) = val.to_str() {
                headers.add(name.as_str(), s);
            }
        }
        let target_url = reconstruct_request_url(
            parts,
            cfg.public_base_url.as_deref(),
            cfg.allow_forwarded_host_fallback,
        )?;
        let grant = cfg
            .verifier
            .authenticate(parts.method.as_str(), &target_url, &headers)
            .await?;
        Ok(Self(grant))
    }
}

fn reconstruct_request_url(
    parts: &Parts,
    public_base_url: Option<&str>,
    allow_forwarded_host_fallback: bool,
) -> Result<String, OAuthResourceChallenge> {
    // The DPoP `htu` names the URL the client called, so use the pre-`Router::nest` path.
    let path = original_path(&parts.extensions, &parts.uri);
    if let Some(base) = public_base_url {
        return Ok(format!("{}{}", base.trim_end_matches('/'), path));
    }
    if let (Some(scheme), Some(authority)) = (parts.uri.scheme_str(), parts.uri.authority()) {
        return Ok(format!("{scheme}://{authority}{path}"));
    }
    if !allow_forwarded_host_fallback {
        return Err(OAuthResourceChallenge::unauthorized(
            "invalid_token",
            "resource server public_base_url is not configured",
            None,
        ));
    }
    let host = parts
        .headers
        .get(HOST)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("localhost");
    let scheme = parts
        .headers
        .get("x-forwarded-proto")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("http");
    Ok(format!("{scheme}://{host}{path}"))
}

/// Path of the request as the client sent it, before any `Router::nest` prefix stripping.
fn original_path<'a>(extensions: &'a Extensions, uri: &'a Uri) -> &'a str {
    extensions
        .get::<OriginalUri>()
        .map_or_else(|| uri.path(), |original| original.0.path())
}

/// Tower layer adding the resource server's current `DPoP-Nonce` to every response that does
/// not already carry one, so clients holding a stale nonce can rotate without a `401` round trip.
///
/// [`DpopResourceAuth`] cannot write response headers itself; apply this layer to the routes it
/// protects.
#[derive(Clone)]
pub struct DpopNonceLayer {
    verifier: Arc<OAuthResourceServerVerifier>,
}

impl std::fmt::Debug for DpopNonceLayer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DpopNonceLayer").finish_non_exhaustive()
    }
}

impl DpopNonceLayer {
    /// Creates a layer issuing nonces from `verifier`.
    pub fn new(verifier: Arc<OAuthResourceServerVerifier>) -> Self {
        Self { verifier }
    }
}

impl<S> Layer<S> for DpopNonceLayer {
    type Service = DpopNonceService<S>;

    fn layer(&self, inner: S) -> Self::Service {
        DpopNonceService {
            inner,
            verifier: self.verifier.clone(),
        }
    }
}

/// Tower service wrapped by [`DpopNonceLayer`].
#[derive(Clone)]
pub struct DpopNonceService<S> {
    inner: S,
    verifier: Arc<OAuthResourceServerVerifier>,
}

impl<S: std::fmt::Debug> std::fmt::Debug for DpopNonceService<S> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DpopNonceService")
            .field("inner", &self.inner)
            .finish_non_exhaustive()
    }
}

impl<S, B> Service<Request<B>> for DpopNonceService<S>
where
    S: Service<Request<B>, Response = Response>,
    S::Future: Send + 'static,
{
    type Response = Response;
    type Error = S::Error;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, req: Request<B>) -> Self::Future {
        let fut = self.inner.call(req);
        let verifier = self.verifier.clone();
        Box::pin(async move {
            let mut resp = fut.await?;
            let name = HeaderName::from_static("dpop-nonce");
            if !resp.headers().contains_key(&name)
                && let Ok(val) = HeaderValue::from_str(&verifier.current_nonce())
            {
                resp.headers_mut().insert(name, val);
            }
            Ok(resp)
        })
    }
}

// ---------------------------------------------------------------------------
// Service Auth Layer & Axum Extractor
// ---------------------------------------------------------------------------

/// Axum state carrying a [`ServiceAuthVerifier`] and default [`ServiceAuthMethodPolicy`].
#[derive(Clone)]
pub struct ServiceAuthState {
    pub verifier: Arc<ServiceAuthVerifier>,
    pub default_policy: ServiceAuthMethodPolicy,
}

impl std::fmt::Debug for ServiceAuthState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ServiceAuthState")
            .field("default_policy", &self.default_policy)
            .finish_non_exhaustive()
    }
}

impl ServiceAuthState {
    /// Creates service-auth extractor/layer state with `Optional` method matching: on
    /// `/xrpc/{nsid}` paths a present `lxm` must match, but tokens without `lxm` pass.
    ///
    /// Typed [`XrpcRouter`] authenticated routes ignore this default and require `lxm` equal to
    /// their NSID (see [`XrpcLxmBinding`]). For hand-built routes and [`ServiceAuthLayer`], use
    /// `with_policy(ServiceAuthMethodPolicy::MatchRoute)` to require route-bound `lxm`.
    pub fn new(verifier: Arc<ServiceAuthVerifier>) -> Self {
        Self {
            verifier,
            default_policy: ServiceAuthMethodPolicy::Optional,
        }
    }

    /// Overrides the default method policy enforced by [`ServiceAuthLayer`] / [`ServiceAuthExtractor`].
    #[must_use]
    pub fn with_policy(mut self, policy: ServiceAuthMethodPolicy) -> Self {
        self.default_policy = policy;
        self
    }
}

/// XRPC JSON rejection returned when service-auth JWT verification fails (`{"error": "AuthRequired"|"ExpiredToken", "message": ...}`).
#[derive(Debug, Clone)]
pub struct ServiceAuthRejection(pub ServiceAuthError);

impl IntoResponse for ServiceAuthRejection {
    fn into_response(self) -> Response {
        let status = if matches!(self.0, ServiceAuthError::ReplayStoreFailed(_)) {
            StatusCode::SERVICE_UNAVAILABLE
        } else {
            StatusCode::from_u16(self.0.http_status()).unwrap_or(StatusCode::UNAUTHORIZED)
        };
        if let Some(detail) = self.0.internal_detail() {
            tracing::warn!(
                error = self.0.xrpc_error_name(),
                detail,
                "service auth backend failure"
            );
        }
        // `message()` never includes backend detail (resolver / replay-store reasons).
        let payload = XrpcErrorBody {
            error: self.0.xrpc_error_name().to_owned(),
            message: Some(self.0.message()),
        };
        let body = serde_json::to_vec(&payload).unwrap_or_else(|_| b"{}".to_vec());
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        headers.insert(
            HeaderName::from_static("www-authenticate"),
            HeaderValue::from_static("Bearer"),
        );
        (status, headers, body).into_response()
    }
}

/// Axum `FromRequestParts` extractor verifying `Authorization: Bearer <service-auth-jwt>`
/// (reusing an already-verified extension if [`ServiceAuthLayer`] ran upstream).
#[derive(Debug, Clone)]
pub struct ServiceAuth(pub VerifiedServiceAuth);

impl<S> FromRequestParts<S> for ServiceAuth
where
    S: Send + Sync,
    ServiceAuthState: FromRef<S>,
{
    type Rejection = ServiceAuthRejection;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let cfg = ServiceAuthState::from_ref(state);
        let policy = resolve_policy(
            &cfg.default_policy,
            &parts.extensions,
            original_path(&parts.extensions, &parts.uri),
        );
        if let Some(existing) = parts.extensions.get::<VerifiedServiceAuth>() {
            // A layer upstream verified the token under its own policy; a typed XRPC route
            // still enforces its own `lxm` binding on top.
            if parts.extensions.get::<XrpcRouteNsid>().is_some() {
                policy
                    .check(existing.lexicon_method.as_deref())
                    .map_err(ServiceAuthRejection)?;
            }
            return Ok(Self(existing.clone()));
        }
        let auth_hdr = parts
            .headers
            .get(AUTHORIZATION)
            .and_then(|v| v.to_str().ok());
        let verified = cfg
            .verifier
            .verify_authorization_header(auth_hdr, &policy)
            .await
            .map_err(ServiceAuthRejection)?;
        parts.extensions.insert(verified.clone());
        Ok(Self(verified))
    }
}

/// `Option<ServiceAuth>` for optional-auth routes: no `Authorization` header gives `None`; a
/// header that is present but fails verification is still rejected.
impl<S> OptionalFromRequestParts<S> for ServiceAuth
where
    S: Send + Sync,
    ServiceAuthState: FromRef<S>,
{
    type Rejection = ServiceAuthRejection;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &S,
    ) -> Result<Option<Self>, Self::Rejection> {
        if parts.extensions.get::<VerifiedServiceAuth>().is_none()
            && !parts.headers.contains_key(AUTHORIZATION)
        {
            return Ok(None);
        }
        <Self as FromRequestParts<S>>::from_request_parts(parts, state)
            .await
            .map(Some)
    }
}

/// How a typed [`XrpcRouter`] authenticated route binds the service-auth `lxm` claim.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash)]
pub enum XrpcLxmBinding {
    /// `lxm` must be present and equal to the route's NSID (default).
    #[default]
    Required,
    /// `lxm` must equal the route's NSID when present; tokens without `lxm` are accepted.
    /// Compatibility opt-down for callers that do not yet mint `lxm`.
    IfPresent,
}

impl XrpcLxmBinding {
    fn policy(self, nsid: &str) -> ServiceAuthMethodPolicy {
        match self {
            Self::Required => ServiceAuthMethodPolicy::Exactly(nsid.to_owned()),
            Self::IfPresent => ServiceAuthMethodPolicy::ExactlyIfPresent(nsid.to_owned()),
        }
    }
}

/// Request extension naming the NSID of the typed XRPC route being served.
#[derive(Debug, Clone, Copy)]
struct XrpcRouteNsid(&'static str);

/// NSID of a `.../xrpc/{nsid}` path (last segment), if any.
fn route_nsid_from_path(path: &str) -> Option<&str> {
    let (_, nsid) = path.rsplit_once("/xrpc/")?;
    (!nsid.is_empty() && !nsid.contains('/')).then_some(nsid)
}

/// The method policy for one request.
///
/// A typed [`XrpcRouter`] route binds `lxm` to its own NSID. Otherwise the state's default
/// applies: `Optional` is upgraded to `ExactlyIfPresent(nsid)` on XRPC paths, and `MatchRoute`
/// becomes `Exactly(nsid)`, staying `MatchRoute` (which always fails) when no NSID can be
/// derived from the path.
fn resolve_policy(
    default: &ServiceAuthMethodPolicy,
    extensions: &Extensions,
    path: &str,
) -> ServiceAuthMethodPolicy {
    if let Some(XrpcRouteNsid(nsid)) = extensions.get::<XrpcRouteNsid>() {
        let binding = extensions
            .get::<XrpcLxmBinding>()
            .copied()
            .unwrap_or_default();
        return binding.policy(nsid);
    }
    match (default, route_nsid_from_path(path)) {
        (ServiceAuthMethodPolicy::Optional, Some(nsid)) => {
            ServiceAuthMethodPolicy::ExactlyIfPresent(nsid.to_owned())
        }
        (ServiceAuthMethodPolicy::MatchRoute, Some(nsid)) => {
            ServiceAuthMethodPolicy::Exactly(nsid.to_owned())
        }
        _ => default.clone(),
    }
}

/// Tower/Axum middleware layer verifying AT Protocol service-auth JWTs before handlers run
/// and inserting [`VerifiedServiceAuth`] into request extensions.
#[derive(Clone)]
pub struct ServiceAuthLayer {
    state: ServiceAuthState,
}

impl std::fmt::Debug for ServiceAuthLayer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ServiceAuthLayer")
            .field("state", &self.state)
            .finish()
    }
}

impl ServiceAuthLayer {
    /// Creates a Tower layer enforcing ATProto service-auth JWT verification.
    pub fn new(verifier: Arc<ServiceAuthVerifier>) -> Self {
        Self {
            state: ServiceAuthState::new(verifier),
        }
    }

    /// Creates a Tower layer with explicit [`ServiceAuthMethodPolicy`].
    pub fn with_policy(
        verifier: Arc<ServiceAuthVerifier>,
        policy: ServiceAuthMethodPolicy,
    ) -> Self {
        Self {
            state: ServiceAuthState::new(verifier).with_policy(policy),
        }
    }
}

impl<S> Layer<S> for ServiceAuthLayer {
    type Service = ServiceAuthMiddleware<S>;

    fn layer(&self, inner: S) -> Self::Service {
        ServiceAuthMiddleware {
            inner,
            state: self.state.clone(),
        }
    }
}

/// Tower service wrapped by [`ServiceAuthLayer`].
#[derive(Clone)]
pub struct ServiceAuthMiddleware<S> {
    inner: S,
    state: ServiceAuthState,
}

impl<S: std::fmt::Debug> std::fmt::Debug for ServiceAuthMiddleware<S> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ServiceAuthMiddleware")
            .field("inner", &self.inner)
            .finish_non_exhaustive()
    }
}

impl<S, B> Service<Request<B>> for ServiceAuthMiddleware<S>
where
    S: Service<Request<B>, Response = Response> + Clone + Send + 'static,
    S::Future: Send + 'static,
    B: Send + 'static,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, mut req: Request<B>) -> Self::Future {
        let clone = self.inner.clone();
        let mut inner = std::mem::replace(&mut self.inner, clone);
        let state = self.state.clone();
        Box::pin(async move {
            let auth_hdr = req
                .headers()
                .get(AUTHORIZATION)
                .and_then(|v| v.to_str().ok())
                .map(str::to_owned);
            let policy = resolve_policy(
                &state.default_policy,
                req.extensions(),
                original_path(req.extensions(), req.uri()),
            );
            match state
                .verifier
                .verify_authorization_header(auth_hdr.as_deref(), &policy)
                .await
            {
                Ok(verified) => {
                    req.extensions_mut().insert(verified);
                    inner.call(req).await
                }
                Err(err) => Ok(ServiceAuthRejection(err).into_response()),
            }
        })
    }
}

// ---------------------------------------------------------------------------
// Typed XRPC Router & Extractors
// ---------------------------------------------------------------------------

/// Rejection produced by [`XrpcParams`], [`StrictXrpcJson`], or [`XrpcRawBody`].
#[derive(Debug, Clone)]
pub struct XrpcRejection {
    pub status: StatusCode,
    pub error: String,
    pub message: Option<String>,
}

impl XrpcRejection {
    fn payload_too_large(limit: usize) -> Self {
        Self {
            status: StatusCode::PAYLOAD_TOO_LARGE,
            error: "PayloadTooLarge".to_owned(),
            message: Some(format!("request body exceeds {limit} bytes")),
        }
    }
}

impl IntoResponse for XrpcRejection {
    fn into_response(self) -> Response {
        xrpc_error_response(self.status, self.error, self.message)
    }
}

fn xrpc_error_response(status: StatusCode, error: String, message: Option<String>) -> Response {
    let body =
        serde_json::to_vec(&XrpcErrorBody { error, message }).unwrap_or_else(|_| b"{}".to_vec());
    let mut headers = HeaderMap::new();
    headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    (status, headers, body).into_response()
}

impl<E: DeclaredXrpcError> IntoResponse for XrpcServerError<E> {
    fn into_response(self) -> Response {
        if let Self::Internal(detail) = &self {
            tracing::error!(detail = %detail, "XRPC handler internal error");
        }
        let status = StatusCode::from_u16(self.http_status()).unwrap_or(StatusCode::BAD_REQUEST);
        let body = self.to_json_bytes();
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        (status, headers, body).into_response()
    }
}

/// Axum extractor parsing typed XRPC query parameters (`P: FromQueryParams`).
#[derive(Debug, Clone)]
pub struct XrpcParams<P>(pub P);

impl<S, P> FromRequestParts<S> for XrpcParams<P>
where
    S: Send + Sync,
    P: FromQueryParams + Send,
{
    type Rejection = XrpcRejection;

    fn from_request_parts(
        parts: &mut Parts,
        _state: &S,
    ) -> impl Future<Output = Result<Self, Self::Rejection>> + Send {
        let res = decode_xrpc_query::<P>(parts.uri.query())
            .map(Self)
            .map_err(|err| XrpcRejection {
                status: StatusCode::BAD_REQUEST,
                error: "InvalidRequest".to_owned(),
                message: Some(format!("invalid query parameters: {err}")),
            });
        std::future::ready(res)
    }
}

/// Reads the request body up to its [`XrpcBodyLimit`] (default [`DEFAULT_BODY_LIMIT`]).
async fn read_xrpc_body(req: Request<Body>) -> Result<axum::body::Bytes, XrpcRejection> {
    let limit = req
        .extensions()
        .get::<XrpcBodyLimit>()
        .map_or(DEFAULT_BODY_LIMIT, |l| l.0);
    let (parts, body) = req.into_parts();
    read_limited(&parts.headers, body, limit)
        .await
        .map_err(|_| XrpcRejection::payload_too_large(limit))
}

/// Axum extractor decoding XRPC JSON input via `StrictJson` + `FromValue::from_value_strict`.
///
/// "Strict" means malformed optional fields fail the request instead of reading as absent;
/// unknown fields are accepted at every depth (see [`decode_xrpc_json_strict`]). The body is
/// capped by the request's [`XrpcBodyLimit`]; larger bodies get `413 PayloadTooLarge`.
#[derive(Debug, Clone)]
pub struct StrictXrpcJson<T>(pub T);

impl<S, T> FromRequest<S> for StrictXrpcJson<T>
where
    S: Send + Sync,
    T: FromValue,
{
    type Rejection = XrpcRejection;

    async fn from_request(req: Request<Body>, _state: &S) -> Result<Self, Self::Rejection> {
        if let Some(ct) = req
            .headers()
            .get(CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
        {
            let mime = ct.split(';').next().unwrap_or("").trim();
            if !mime.eq_ignore_ascii_case("application/json") {
                return Err(XrpcRejection {
                    status: StatusCode::UNSUPPORTED_MEDIA_TYPE,
                    error: "InvalidRequest".to_owned(),
                    message: Some(format!(
                        "expected application/json Content-Type, got {mime}"
                    )),
                });
            }
        }
        let bytes = read_xrpc_body(req).await?;
        decode_xrpc_json_strict::<T>(&bytes)
            .map(Self)
            .map_err(|msg| XrpcRejection {
                status: StatusCode::BAD_REQUEST,
                error: "InvalidRequest".to_owned(),
                message: Some(msg),
            })
    }
}

/// Axum extractor reading raw binary XRPC request payloads (`petrel_core::Bytes`), capped by the
/// request's [`XrpcBodyLimit`].
#[derive(Debug, Clone)]
pub struct XrpcRawBody(pub Bytes);

impl<S> FromRequest<S> for XrpcRawBody
where
    S: Send + Sync,
{
    type Rejection = XrpcRejection;

    async fn from_request(req: Request<Body>, _state: &S) -> Result<Self, Self::Rejection> {
        let bytes = read_xrpc_body(req).await?;
        Ok(Self(Bytes(bytes.to_vec())))
    }
}

/// Typed XRPC response wrapper serializing `R::Output` JSON or raw bytes and `XrpcServerError<R::Error>`.
#[derive(Debug)]
pub struct XrpcOutputResponse<R: XrpcRequest> {
    body: Vec<u8>,
    content_type: &'static str,
    _marker: PhantomData<fn() -> R>,
}

impl<R: XrpcRequest> XrpcOutputResponse<R>
where
    R::Output: ToValue,
{
    /// Encodes a typed lexicon output struct as `application/json`.
    pub fn json(output: &R::Output) -> Result<Self, XrpcServerError<R::Error>> {
        let body =
            encode_xrpc_json(output).map_err(|err| XrpcServerError::Internal(err.to_string()))?;
        Ok(Self {
            body,
            content_type: "application/json",
            _marker: PhantomData,
        })
    }
}

impl<R: XrpcRequest> XrpcOutputResponse<R> {
    /// Returns an empty `200 OK` response (for procedures with `Output = ()`).
    pub fn empty() -> Self {
        Self {
            body: Vec::new(),
            content_type: "application/json",
            _marker: PhantomData,
        }
    }

    /// Returns a raw binary body (`R::OUTPUT_ENCODING` or `application/octet-stream`).
    pub fn bytes(bytes: Bytes) -> Self {
        Self {
            body: bytes.0,
            content_type: R::OUTPUT_ENCODING.unwrap_or("application/octet-stream"),
            _marker: PhantomData,
        }
    }
}

impl<R: XrpcRequest> IntoResponse for XrpcOutputResponse<R> {
    fn into_response(self) -> Response {
        let mut headers = HeaderMap::new();
        if !self.body.is_empty() {
            headers.insert(CONTENT_TYPE, HeaderValue::from_static(self.content_type));
        }
        (StatusCode::OK, headers, self.body).into_response()
    }
}

/// Per-route options for the `*_with` registration methods of [`XrpcRouter`].
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
#[non_exhaustive]
pub struct XrpcRouteOptions {
    body_limit: Option<usize>,
    lxm_binding: Option<XrpcLxmBinding>,
}

impl XrpcRouteOptions {
    /// Options inheriting every router-wide default.
    pub const fn new() -> Self {
        Self {
            body_limit: None,
            lxm_binding: None,
        }
    }

    /// Overrides the router-wide body limit for this route (bytes).
    #[must_use]
    pub const fn body_limit(mut self, limit: usize) -> Self {
        self.body_limit = Some(limit);
        self
    }

    /// Overrides the router-wide `lxm` binding for this authenticated route.
    #[must_use]
    pub const fn lxm_binding(mut self, binding: XrpcLxmBinding) -> Self {
        self.lxm_binding = Some(binding);
        self
    }

    fn apply<S>(self, mut route: MethodRouter<S>) -> MethodRouter<S>
    where
        S: Clone + Send + Sync + 'static,
    {
        if let Some(limit) = self.body_limit {
            route = route.layer(Extension(XrpcBodyLimit(limit)));
        }
        if let Some(binding) = self.lxm_binding {
            route = route.layer(Extension(binding));
        }
        route
    }
}

/// Marks `route` as the typed XRPC route for `nsid`, so [`ServiceAuth`] binds `lxm` to it.
fn bind_route_nsid<S>(route: MethodRouter<S>, nsid: &'static str) -> MethodRouter<S>
where
    S: Clone + Send + Sync + 'static,
{
    route.layer(Extension(XrpcRouteNsid(nsid)))
}

async fn xrpc_not_found(uri: OriginalUri) -> Response {
    if route_nsid_from_path(uri.0.path()).is_some() {
        xrpc_error_response(
            StatusCode::NOT_IMPLEMENTED,
            "MethodNotImplemented".to_owned(),
            Some("Method Not Implemented".to_owned()),
        )
    } else {
        xrpc_error_response(
            StatusCode::NOT_FOUND,
            "NotFound".to_owned(),
            Some("Not Found".to_owned()),
        )
    }
}

async fn xrpc_method_not_allowed(method: axum::http::Method) -> Response {
    xrpc_error_response(
        StatusCode::BAD_REQUEST,
        "InvalidRequest".to_owned(),
        Some(format!("Incorrect HTTP method ({method})")),
    )
}

/// Fluent typed Axum router registering [`petrel_core::XrpcRequest`] endpoints at `/xrpc/{R::NSID}`.
///
/// Router-wide settings ([`Self::with_body_limit`], [`Self::with_lxm_binding`],
/// [`Self::with_xrpc_fallbacks`]) apply when the router is finished ([`Self::with_state`] /
/// [`Self::into_router`]), so their position in the builder chain does not matter. Per-route
/// [`XrpcRouteOptions`] override them.
#[derive(Debug)]
pub struct XrpcRouter<S = ()> {
    router: Router<S>,
    body_limit: Option<usize>,
    lxm_binding: Option<XrpcLxmBinding>,
    fallbacks: bool,
}

impl<S> Default for XrpcRouter<S>
where
    S: Clone + Send + Sync + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}

impl<S> XrpcRouter<S>
where
    S: Clone + Send + Sync + 'static,
{
    /// Creates an empty typed XRPC router.
    pub fn new() -> Self {
        Self {
            router: Router::new(),
            body_limit: None,
            lxm_binding: None,
            fallbacks: false,
        }
    }

    /// Sets the router-wide request body limit in bytes (default [`DEFAULT_BODY_LIMIT`]).
    #[must_use]
    pub const fn with_body_limit(mut self, limit: usize) -> Self {
        self.body_limit = Some(limit);
        self
    }

    /// Sets how authenticated routes bind the service-auth `lxm` claim (default
    /// [`XrpcLxmBinding::Required`]: present and equal to the route NSID).
    #[must_use]
    pub const fn with_lxm_binding(mut self, binding: XrpcLxmBinding) -> Self {
        self.lxm_binding = Some(binding);
        self
    }

    /// Answers unknown paths and wrong HTTP methods with XRPC error envelopes:
    /// `501 MethodNotImplemented` for an unknown `/xrpc/{nsid}`, `404 NotFound` for other paths,
    /// and `400 InvalidRequest` for a known NSID called with the wrong method.
    ///
    /// Opt-in because it installs a router fallback, and [`Router::merge`] panics when both
    /// merged routers have one.
    #[must_use]
    pub const fn with_xrpc_fallbacks(mut self) -> Self {
        self.fallbacks = true;
        self
    }

    fn add_route(mut self, nsid: &'static str, route: MethodRouter<S>) -> Self {
        let path = format!("/xrpc/{nsid}");
        self.router = self.router.route(&path, route);
        self
    }

    /// Registers a typed XRPC `Query` (`GET /xrpc/{R::NSID}`) returning JSON `R::Output`.
    #[must_use]
    pub fn query<R, F, Fut>(self, handler: F) -> Self
    where
        R: XrpcRequest,
        R::Params: FromQueryParams + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        F: Fn(S, R::Params) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        debug_assert_eq!(R::METHOD, XrpcMethod::Query);
        self.add_route(
            R::NSID,
            get(
                move |axum::extract::State(state): axum::extract::State<S>,
                      XrpcParams(params): XrpcParams<R::Params>| {
                    let handler = handler.clone();
                    async move {
                        let out = handler(state, params).await?;
                        XrpcOutputResponse::<R>::json(&out)
                    }
                },
            ),
        )
    }

    /// Registers a typed XRPC `Query` authenticated via [`VerifiedServiceAuth`].
    ///
    /// The token's `lxm` must equal `R::NSID` unless the router or route opts down with
    /// [`XrpcLxmBinding::IfPresent`].
    #[must_use]
    pub fn authenticated_query<R, F, Fut>(self, handler: F) -> Self
    where
        R: XrpcRequest,
        R::Params: FromQueryParams + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        ServiceAuthState: FromRef<S>,
        F: Fn(S, VerifiedServiceAuth, R::Params) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        self.authenticated_query_with::<R, F, Fut>(XrpcRouteOptions::new(), handler)
    }

    /// [`Self::authenticated_query`] with per-route options.
    #[must_use]
    pub fn authenticated_query_with<R, F, Fut>(self, options: XrpcRouteOptions, handler: F) -> Self
    where
        R: XrpcRequest,
        R::Params: FromQueryParams + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        ServiceAuthState: FromRef<S>,
        F: Fn(S, VerifiedServiceAuth, R::Params) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        debug_assert_eq!(R::METHOD, XrpcMethod::Query);
        let route = get(
            move |axum::extract::State(state): axum::extract::State<S>,
                  ServiceAuth(auth): ServiceAuth,
                  XrpcParams(params): XrpcParams<R::Params>| {
                let handler = handler.clone();
                async move {
                    let out = handler(state, auth, params).await?;
                    XrpcOutputResponse::<R>::json(&out)
                }
            },
        );
        self.add_route(R::NSID, options.apply(bind_route_nsid(route, R::NSID)))
    }

    /// Registers a typed XRPC `Procedure` (`POST /xrpc/{R::NSID}`) with strict JSON `R::Input` and JSON `R::Output`.
    #[must_use]
    pub fn procedure<R, F, Fut>(self, handler: F) -> Self
    where
        R: XrpcRequest,
        R::Params: FromQueryParams + Send + 'static,
        R::Input: FromValue + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        F: Fn(S, R::Params, R::Input) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        self.procedure_with::<R, F, Fut>(XrpcRouteOptions::new(), handler)
    }

    /// [`Self::procedure`] with per-route options (for example a larger body limit).
    #[must_use]
    pub fn procedure_with<R, F, Fut>(self, options: XrpcRouteOptions, handler: F) -> Self
    where
        R: XrpcRequest,
        R::Params: FromQueryParams + Send + 'static,
        R::Input: FromValue + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        F: Fn(S, R::Params, R::Input) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        debug_assert_eq!(R::METHOD, XrpcMethod::Procedure);
        let route = post(
            move |axum::extract::State(state): axum::extract::State<S>,
                  XrpcParams(params): XrpcParams<R::Params>,
                  StrictXrpcJson(input): StrictXrpcJson<R::Input>| {
                let handler = handler.clone();
                async move {
                    let out = handler(state, params, input).await?;
                    XrpcOutputResponse::<R>::json(&out)
                }
            },
        );
        self.add_route(R::NSID, options.apply(route))
    }

    /// Registers an authenticated XRPC `Procedure` with strict JSON `R::Input` and JSON `R::Output`.
    ///
    /// The token's `lxm` must equal `R::NSID` unless the router or route opts down with
    /// [`XrpcLxmBinding::IfPresent`]. Authentication runs before the body is read.
    #[must_use]
    pub fn authenticated_procedure<R, F, Fut>(self, handler: F) -> Self
    where
        R: XrpcRequest,
        R::Params: FromQueryParams + Send + 'static,
        R::Input: FromValue + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        ServiceAuthState: FromRef<S>,
        F: Fn(S, VerifiedServiceAuth, R::Params, R::Input) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        self.authenticated_procedure_with::<R, F, Fut>(XrpcRouteOptions::new(), handler)
    }

    /// [`Self::authenticated_procedure`] with per-route options.
    #[must_use]
    pub fn authenticated_procedure_with<R, F, Fut>(
        self,
        options: XrpcRouteOptions,
        handler: F,
    ) -> Self
    where
        R: XrpcRequest,
        R::Params: FromQueryParams + Send + 'static,
        R::Input: FromValue + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        ServiceAuthState: FromRef<S>,
        F: Fn(S, VerifiedServiceAuth, R::Params, R::Input) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        debug_assert_eq!(R::METHOD, XrpcMethod::Procedure);
        let route = post(
            move |axum::extract::State(state): axum::extract::State<S>,
                  ServiceAuth(auth): ServiceAuth,
                  XrpcParams(params): XrpcParams<R::Params>,
                  StrictXrpcJson(input): StrictXrpcJson<R::Input>| {
                let handler = handler.clone();
                async move {
                    let out = handler(state, auth, params, input).await?;
                    XrpcOutputResponse::<R>::json(&out)
                }
            },
        );
        self.add_route(R::NSID, options.apply(bind_route_nsid(route, R::NSID)))
    }

    /// Registers a typed XRPC `Procedure` (`POST /xrpc/{R::NSID}`) with empty input (`R::Input = ()`) and empty output.
    #[must_use]
    pub fn procedure_unit<R, F, Fut>(self, handler: F) -> Self
    where
        R: XrpcRequest<Input = (), Output = ()>,
        R::Params: FromQueryParams + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        F: Fn(S, R::Params) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<(), XrpcServerError<R::Error>>> + Send + 'static,
    {
        debug_assert_eq!(R::METHOD, XrpcMethod::Procedure);
        self.add_route(
            R::NSID,
            post(
                move |axum::extract::State(state): axum::extract::State<S>,
                      XrpcParams(params): XrpcParams<R::Params>| {
                    let handler = handler.clone();
                    async move {
                        handler(state, params).await?;
                        Ok::<_, XrpcServerError<R::Error>>(XrpcOutputResponse::<R>::empty())
                    }
                },
            ),
        )
    }

    /// Registers a raw binary XRPC `Procedure` (`POST /xrpc/{R::NSID}`, `R::Input = Bytes`) returning JSON `R::Output`.
    #[must_use]
    pub fn procedure_bytes<R, F, Fut>(self, handler: F) -> Self
    where
        R: XrpcRequest<Input = Bytes>,
        R::Params: FromQueryParams + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        F: Fn(S, R::Params, Bytes) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        self.procedure_bytes_with::<R, F, Fut>(XrpcRouteOptions::new(), handler)
    }

    /// [`Self::procedure_bytes`] with per-route options (for example a larger body limit).
    #[must_use]
    pub fn procedure_bytes_with<R, F, Fut>(self, options: XrpcRouteOptions, handler: F) -> Self
    where
        R: XrpcRequest<Input = Bytes>,
        R::Params: FromQueryParams + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        F: Fn(S, R::Params, Bytes) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        debug_assert_eq!(R::METHOD, XrpcMethod::Procedure);
        let route = post(
            move |axum::extract::State(state): axum::extract::State<S>,
                  XrpcParams(params): XrpcParams<R::Params>,
                  XrpcRawBody(body): XrpcRawBody| {
                let handler = handler.clone();
                async move {
                    let out = handler(state, params, body).await?;
                    XrpcOutputResponse::<R>::json(&out)
                }
            },
        );
        self.add_route(R::NSID, options.apply(route))
    }

    /// Merges arbitrary pre-built routes into the underlying Axum router.
    #[must_use]
    pub fn merge_router(mut self, other: Router<S>) -> Self {
        self.router = self.router.merge(other);
        self
    }

    /// Applies state `state` and returns a stateless [`axum::Router`].
    pub fn with_state(self, state: S) -> Router<()> {
        self.into_router().with_state(state)
    }

    /// Unwraps the underlying [`axum::Router<S>`], applying router-wide settings.
    pub fn into_router(self) -> Router<S> {
        let mut router = self.router;
        if self.fallbacks {
            router = router
                .fallback(xrpc_not_found)
                .method_not_allowed_fallback(xrpc_method_not_allowed);
        }
        if let Some(binding) = self.lxm_binding {
            router = router.layer(Extension(binding));
        }
        if let Some(limit) = self.body_limit {
            router = router.layer(Extension(XrpcBodyLimit(limit)));
        }
        router
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn route_nsid_from_path_takes_last_xrpc_segment() {
        assert_eq!(route_nsid_from_path("/xrpc/com.a.b"), Some("com.a.b"));
        assert_eq!(route_nsid_from_path("/api/xrpc/com.a.b"), Some("com.a.b"));
        assert_eq!(route_nsid_from_path("/xrpc/"), None);
        assert_eq!(route_nsid_from_path("/xrpc/com.a.b/extra"), None);
        assert_eq!(route_nsid_from_path("/health"), None);
    }

    #[test]
    fn dpop_htu_uses_original_uri_under_nest() {
        let (mut parts, ()) = Request::get("/resource").body(()).unwrap().into_parts();
        parts
            .extensions
            .insert(OriginalUri("/api/v1/resource?x=1".parse().unwrap()));
        let htu = reconstruct_request_url(&parts, Some("https://api.example.com/"), false).unwrap();
        assert_eq!(htu, "https://api.example.com/api/v1/resource");
    }

    #[test]
    fn client_ip_header_uses_rightmost_valid_value() {
        let name = HeaderName::from_static("x-forwarded-for");
        let mut headers = HeaderMap::new();
        headers.append(&name, HeaderValue::from_static("198.51.100.9, 203.0.113.1"));
        assert_eq!(
            client_ip_from_header(&headers, &name),
            Some("203.0.113.1".parse().unwrap())
        );
        headers.append(&name, HeaderValue::from_static("[2001:db8::1]:443"));
        assert_eq!(
            client_ip_from_header(&headers, &name),
            Some("2001:db8::1".parse().unwrap())
        );
        headers.insert(&name, HeaderValue::from_static("not-an-ip"));
        assert_eq!(client_ip_from_header(&headers, &name), None);
    }
}
