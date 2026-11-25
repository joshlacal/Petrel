use std::future::Future;
use std::marker::PhantomData;
use std::net::SocketAddr;
use std::pin::Pin;
use std::sync::Arc;
use std::task::{Context, Poll};

use axum::Router;
use axum::body::Body;
use axum::extract::{ConnectInfo, FromRef, FromRequest, FromRequestParts, Request};
use axum::http::header::{AUTHORIZATION, CONTENT_TYPE, HOST};
use axum::http::request::Parts;
use axum::http::{HeaderMap, HeaderName, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{any, get, post};
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

const MAX_AXUM_BODY_BYTES: usize = 2 * 1024 * 1024;

/// Mounts all [`OAuthAuthorizationServer`] endpoints onto an [`axum::Router`].
pub fn oauth_router<S>(server: Arc<OAuthAuthorizationServer>) -> Router<S>
where
    S: Clone + Send + Sync + 'static,
{
    let dispatch = {
        let srv = server;
        move |req: Request<Body>| {
            let srv = srv.clone();
            async move {
                let oauth_req = axum_to_oauth_request(req).await;
                oauth_to_axum_response(srv.handle(oauth_req).await)
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
    let dispatch = {
        let cab = cab;
        move |req: Request<Body>| {
            let cab = cab.clone();
            async move {
                let oauth_req = axum_to_oauth_request(req).await;
                oauth_to_axum_response(cab.handle(oauth_req).await)
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

async fn axum_to_oauth_request(req: Request<Body>) -> OAuthHttpRequest {
    let addr = req
        .extensions()
        .get::<ConnectInfo<SocketAddr>>()
        .map(|c| c.0);
    let (parts, body) = req.into_parts();
    let mut headers = OAuthHttpHeaders::default();
    for (name, val) in &parts.headers {
        if let Ok(s) = val.to_str() {
            headers.add(name.as_str(), s);
        }
    }
    let bytes = axum::body::to_bytes(body, MAX_AXUM_BODY_BYTES)
        .await
        .map(|b| b.to_vec())
        .unwrap_or_default();
    let mut out = OAuthHttpRequest::new(parts.method.as_str(), parts.uri.path());
    if let Some(q) = parts.uri.query() {
        out = out.with_query(q);
    }
    out = out.with_headers(headers).with_body(bytes);
    if let Some(sa) = addr {
        out = out.with_remote_address(sa.ip().to_string());
    }
    out
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
        let target_url = reconstruct_request_url(parts, &cfg)?;
        let grant = cfg
            .verifier
            .authenticate(parts.method.as_str(), &target_url, &headers)
            .await?;
        Ok(Self(grant))
    }
}

fn reconstruct_request_url(
    parts: &Parts,
    cfg: &DpopVerifierState,
) -> Result<String, OAuthResourceChallenge> {
    let path = parts.uri.path();
    if let Some(ref base) = cfg.public_base_url {
        return Ok(format!("{}{}", base.trim_end_matches('/'), path));
    }
    if let (Some(scheme), Some(authority)) = (parts.uri.scheme_str(), parts.uri.authority()) {
        return Ok(format!("{scheme}://{authority}{path}"));
    }
    if !cfg.allow_forwarded_host_fallback {
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
    /// Creates service-auth extractor/layer state with `Optional` method matching (individual XRPC paths can still match `/xrpc/{nsid}`).
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
        if let Some(existing) = parts.extensions.get::<VerifiedServiceAuth>() {
            return Ok(Self(existing.clone()));
        }
        let cfg = ServiceAuthState::from_ref(state);
        let auth_hdr = parts
            .headers
            .get(AUTHORIZATION)
            .and_then(|v| v.to_str().ok());
        let policy = effective_policy_for_path(&cfg.default_policy, parts.uri.path());
        let verified = cfg
            .verifier
            .verify_authorization_header(auth_hdr, &policy)
            .await
            .map_err(ServiceAuthRejection)?;
        parts.extensions.insert(verified.clone());
        Ok(Self(verified))
    }
}

fn effective_policy_for_path(
    base: &ServiceAuthMethodPolicy,
    path: &str,
) -> ServiceAuthMethodPolicy {
    if matches!(base, ServiceAuthMethodPolicy::Optional)
        && let Some(nsid) = path.strip_prefix("/xrpc/")
        && !nsid.is_empty()
        && !nsid.contains('/')
    {
        return ServiceAuthMethodPolicy::ExactlyIfPresent(nsid.to_owned());
    }
    base.clone()
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
            let policy = effective_policy_for_path(&state.default_policy, req.uri().path());
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

impl IntoResponse for XrpcRejection {
    fn into_response(self) -> Response {
        let body = serde_json::to_vec(&XrpcErrorBody {
            error: self.error,
            message: self.message,
        })
        .unwrap_or_else(|_| b"{}".to_vec());
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        (self.status, headers, body).into_response()
    }
}

impl<E: DeclaredXrpcError> IntoResponse for XrpcServerError<E> {
    fn into_response(self) -> Response {
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

/// Axum extractor decoding strict XRPC JSON input via `StrictJson` + `FromValue::from_value_strict`.
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
        let bytes = axum::body::to_bytes(req.into_body(), MAX_AXUM_BODY_BYTES)
            .await
            .map_err(|err| XrpcRejection {
                status: StatusCode::PAYLOAD_TOO_LARGE,
                error: "InvalidRequest".to_owned(),
                message: Some(err.to_string()),
            })?;
        decode_xrpc_json_strict::<T>(&bytes)
            .map(Self)
            .map_err(|msg| XrpcRejection {
                status: StatusCode::BAD_REQUEST,
                error: "InvalidRequest".to_owned(),
                message: Some(msg),
            })
    }
}

/// Axum extractor reading raw binary XRPC request payloads (`petrel_core::Bytes`).
#[derive(Debug, Clone)]
pub struct XrpcRawBody(pub Bytes);

impl<S> FromRequest<S> for XrpcRawBody
where
    S: Send + Sync,
{
    type Rejection = XrpcRejection;

    async fn from_request(req: Request<Body>, _state: &S) -> Result<Self, Self::Rejection> {
        let bytes = axum::body::to_bytes(req.into_body(), MAX_AXUM_BODY_BYTES)
            .await
            .map_err(|err| XrpcRejection {
                status: StatusCode::PAYLOAD_TOO_LARGE,
                error: "InvalidRequest".to_owned(),
                message: Some(err.to_string()),
            })?;
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

/// Fluent typed Axum router registering [`petrel_core::XrpcRequest`] endpoints at `/xrpc/{R::NSID}`.
#[derive(Debug)]
pub struct XrpcRouter<S = ()> {
    router: Router<S>,
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
        }
    }

    /// Registers a typed XRPC `Query` (`GET /xrpc/{R::NSID}`) returning JSON `R::Output`.
    #[must_use]
    pub fn query<R, F, Fut>(mut self, handler: F) -> Self
    where
        R: XrpcRequest,
        R::Params: FromQueryParams + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        F: Fn(S, R::Params) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        debug_assert_eq!(R::METHOD, XrpcMethod::Query);
        let path = format!("/xrpc/{}", R::NSID);
        self.router = self.router.route(
            &path,
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
        );
        self
    }

    /// Registers a typed XRPC `Query` authenticated via [`VerifiedServiceAuth`].
    #[must_use]
    pub fn authenticated_query<R, F, Fut>(mut self, handler: F) -> Self
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
        let path = format!("/xrpc/{}", R::NSID);
        self.router = self.router.route(
            &path,
            get(
                move |axum::extract::State(state): axum::extract::State<S>,
                      ServiceAuth(auth): ServiceAuth,
                      XrpcParams(params): XrpcParams<R::Params>| {
                    let handler = handler.clone();
                    async move {
                        let out = handler(state, auth, params).await?;
                        XrpcOutputResponse::<R>::json(&out)
                    }
                },
            ),
        );
        self
    }

    /// Registers a typed XRPC `Procedure` (`POST /xrpc/{R::NSID}`) with strict JSON `R::Input` and JSON `R::Output`.
    #[must_use]
    pub fn procedure<R, F, Fut>(mut self, handler: F) -> Self
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
        let path = format!("/xrpc/{}", R::NSID);
        self.router = self.router.route(
            &path,
            post(
                move |axum::extract::State(state): axum::extract::State<S>,
                      XrpcParams(params): XrpcParams<R::Params>,
                      StrictXrpcJson(input): StrictXrpcJson<R::Input>| {
                    let handler = handler.clone();
                    async move {
                        let out = handler(state, params, input).await?;
                        XrpcOutputResponse::<R>::json(&out)
                    }
                },
            ),
        );
        self
    }

    /// Registers an authenticated XRPC `Procedure` with strict JSON `R::Input` and JSON `R::Output`.
    #[must_use]
    pub fn authenticated_procedure<R, F, Fut>(mut self, handler: F) -> Self
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
        let path = format!("/xrpc/{}", R::NSID);
        self.router = self.router.route(
            &path,
            post(
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
            ),
        );
        self
    }

    /// Registers a typed XRPC `Procedure` (`POST /xrpc/{R::NSID}`) with empty input (`R::Input = ()`) and empty output.
    #[must_use]
    pub fn procedure_unit<R, F, Fut>(mut self, handler: F) -> Self
    where
        R: XrpcRequest<Input = (), Output = ()>,
        R::Params: FromQueryParams + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        F: Fn(S, R::Params) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<(), XrpcServerError<R::Error>>> + Send + 'static,
    {
        debug_assert_eq!(R::METHOD, XrpcMethod::Procedure);
        let path = format!("/xrpc/{}", R::NSID);
        self.router = self.router.route(
            &path,
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
        );
        self
    }

    /// Registers a raw binary XRPC `Procedure` (`POST /xrpc/{R::NSID}`, `R::Input = Bytes`) returning JSON `R::Output`.
    #[must_use]
    pub fn procedure_bytes<R, F, Fut>(mut self, handler: F) -> Self
    where
        R: XrpcRequest<Input = Bytes>,
        R::Params: FromQueryParams + Send + 'static,
        R::Output: ToValue + Send + 'static,
        R::Error: DeclaredXrpcError + Send + 'static,
        F: Fn(S, R::Params, Bytes) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<R::Output, XrpcServerError<R::Error>>> + Send + 'static,
    {
        debug_assert_eq!(R::METHOD, XrpcMethod::Procedure);
        let path = format!("/xrpc/{}", R::NSID);
        self.router = self.router.route(
            &path,
            post(
                move |axum::extract::State(state): axum::extract::State<S>,
                      XrpcParams(params): XrpcParams<R::Params>,
                      XrpcRawBody(body): XrpcRawBody| {
                    let handler = handler.clone();
                    async move {
                        let out = handler(state, params, body).await?;
                        XrpcOutputResponse::<R>::json(&out)
                    }
                },
            ),
        );
        self
    }

    /// Merges arbitrary pre-built routes into the underlying Axum router.
    #[must_use]
    pub fn merge_router(mut self, other: Router<S>) -> Self {
        self.router = self.router.merge(other);
        self
    }

    /// Applies state `state` and returns a stateless [`axum::Router`].
    pub fn with_state(self, state: S) -> Router<()> {
        self.router.with_state(state)
    }

    /// Unwraps the underlying [`axum::Router<S>`].
    pub fn into_router(self) -> Router<S> {
        self.router
    }
}
