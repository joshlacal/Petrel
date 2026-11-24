use std::{collections::BTreeMap, fmt, sync::Arc, time::Duration};

use bytes::Bytes;
use http::{
    HeaderMap, HeaderName, HeaderValue, Method, Request, Response, StatusCode,
    header::{ACCEPT, CONTENT_TYPE, WWW_AUTHENTICATE},
};
use petrel_core::{
    Nsid,
    error::{DecodeError, EncodeError},
    xrpc::{
        DeclaredXrpcError, ToQueryParams, UndeclaredError, XrpcInput, XrpcMethod, XrpcOutput,
        XrpcRequest,
    },
};
use url::Url;

use super::{
    AuthError, AuthProvider, ResponseMetadata, UnauthorizedAction, XrpcError, XrpcErrorBody,
    XrpcLabeler, XrpcResponse, response::retry_after,
};
use crate::{
    net::{
        Origin, RedirectPolicy, SendOptions, SharedTransport, TransportError,
        policy::{retain_anonymous_headers, validate_url_with_development},
        send_with_redirects,
    },
    rt::{BoxFuture, MaybeSend, MaybeSync},
};

const MAX_ATTEMPTS: u32 = 3;
const DIAGNOSTIC_BYTES: usize = 8 * 1024;
const PROXY: &str = "atproto-proxy";
const LABELERS: &str = "atproto-accept-labelers";

/// The error from building, sending, or interpreting a typed XRPC request.
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum Error<E: fmt::Debug = UndeclaredError> {
    #[error(transparent)]
    Xrpc(#[from] Box<XrpcError<E>>),
    #[error("could not encode XRPC input")]
    Encode(#[from] EncodeError),
    #[error("could not decode {endpoint} response (HTTP {status})")]
    Decode {
        endpoint: &'static str,
        status: StatusCode,
        #[source]
        source: DecodeError,
    },
    #[error("expected response content type {expected}, got {actual:?}")]
    ContentType {
        expected: &'static str,
        actual: Option<String>,
    },
    #[error(transparent)]
    Transport(#[from] TransportError),
    #[error(transparent)]
    Auth(#[from] AuthError),
    #[error("the server still requires a DPoP nonce after the nonce retry")]
    MaxRetries,
    #[error("invalid XRPC endpoint NSID")]
    InvalidNsid,
}

/// Per-request transport and XRPC routing overrides.
#[derive(Debug, Clone)]
pub struct CallOptions {
    pub headers: HeaderMap,
    pub proxy: Option<String>,
    pub accept_labelers: Option<Vec<XrpcLabeler>>,
    pub service: Option<Url>,
    pub transport: SendOptions,
    pub redirects: RedirectPolicy,
    pub skip_token_refresh: bool,
}

impl Default for CallOptions {
    fn default() -> Self {
        Self {
            headers: HeaderMap::new(),
            proxy: None,
            accept_labelers: None,
            service: None,
            transport: SendOptions::new(),
            redirects: RedirectPolicy::Follow,
            skip_token_refresh: false,
        }
    }
}

/// A raw XRPC body and its media type.
#[derive(Debug, Clone)]
pub struct XrpcBody {
    bytes: Bytes,
    content_type: HeaderValue,
}

impl XrpcBody {
    pub fn json(bytes: impl Into<Bytes>) -> Self {
        Self {
            bytes: bytes.into(),
            content_type: HeaderValue::from_static("application/json"),
        }
    }

    pub fn bytes(bytes: impl Into<Bytes>, content_type: &str) -> Result<Self, TransportError> {
        let header = media_type(content_type).ok_or_else(|| {
            TransportError::InvalidRequest("request content type must be type/subtype".to_owned())
        })?;
        Ok(Self {
            bytes: bytes.into(),
            content_type: header,
        })
    }
}

/// Delay implementation for retry backoff. Embedders can use their own timer.
pub trait Sleeper: MaybeSend + MaybeSync {
    fn sleep(&self, duration: Duration) -> BoxFuture<'_, ()>;
}

#[cfg(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", feature = "wasm")
))]
struct PlatformSleeper;

#[cfg(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", feature = "wasm")
))]
impl Sleeper for PlatformSleeper {
    fn sleep(&self, duration: Duration) -> BoxFuture<'_, ()> {
        Box::pin(crate::rt::sleep(duration))
    }
}

fn default_sleeper() -> Option<Arc<dyn Sleeper>> {
    #[cfg(any(
        all(not(target_arch = "wasm32"), feature = "native"),
        all(target_arch = "wasm32", feature = "wasm")
    ))]
    {
        Some(Arc::new(PlatformSleeper))
    }
    #[cfg(not(any(
        all(not(target_arch = "wasm32"), feature = "native"),
        all(target_arch = "wasm32", feature = "wasm")
    )))]
    {
        None
    }
}

/// Send generated (or raw) calls to a Personal Data Server (PDS).
#[derive(Clone)]
pub struct XrpcClient {
    base_url: Url,
    base_origin: Origin,
    transport: SharedTransport,
    auth: Option<Arc<dyn AuthProvider>>,
    sleeper: Option<Arc<dyn Sleeper>>,
    headers: HeaderMap,
    service_dids: BTreeMap<String, String>,
    labelers: Vec<XrpcLabeler>,
    request_ids: bool,
}

impl fmt::Debug for XrpcClient {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("XrpcClient")
            .field("base_origin", &self.base_origin)
            .finish_non_exhaustive()
    }
}

impl XrpcClient {
    pub fn new(base_url: Url, transport: SharedTransport) -> Result<Self, TransportError> {
        let base_origin = validate_url_with_development(&base_url, true)
            .map_err(|error| TransportError::PolicyViolation(error.to_string()))?;
        if !matches!(base_origin.scheme(), "https" | "http") || base_url.query().is_some() {
            return Err(TransportError::InvalidRequest(
                "invalid base XRPC URL".to_owned(),
            ));
        }
        let mut headers = HeaderMap::new();
        headers.insert(
            http::header::USER_AGENT,
            HeaderValue::from_static(concat!("Petrel/", env!("CARGO_PKG_VERSION"))),
        );
        Ok(Self {
            base_url,
            base_origin,
            transport,
            auth: None,
            sleeper: default_sleeper(),
            headers,
            service_dids: [
                (
                    "app.bsky".to_owned(),
                    "did:web:api.bsky.app#bsky_appview".to_owned(),
                ),
                (
                    "chat.bsky".to_owned(),
                    "did:web:api.bsky.chat#bsky_chat".to_owned(),
                ),
            ]
            .into(),
            labelers: Vec::new(),
            request_ids: false,
        })
    }

    pub fn with_auth_provider(mut self, auth: Arc<dyn AuthProvider>) -> Self {
        self.auth = Some(auth);
        self
    }

    pub fn with_sleeper(mut self, sleeper: Arc<dyn Sleeper>) -> Self {
        self.sleeper = Some(sleeper);
        self
    }

    pub fn with_headers(mut self, headers: HeaderMap) -> Self {
        self.headers.extend(headers);
        self
    }

    pub fn with_service_dids(mut self, service_dids: BTreeMap<String, String>) -> Self {
        self.service_dids = service_dids;
        self
    }

    pub fn with_labelers(mut self, labelers: Vec<XrpcLabeler>) -> Self {
        self.labelers = labelers;
        self
    }

    pub fn with_request_ids(mut self, enabled: bool) -> Self {
        self.request_ids = enabled;
        self
    }

    pub async fn send<R: XrpcRequest>(
        &self,
        params: R::Params,
        input: R::Input,
        options: &CallOptions,
    ) -> Result<R::Output, Error<R::Error>> {
        self.send_with_metadata::<R>(params, input, options)
            .await
            .map(|(output, _)| output)
    }

    pub async fn send_with_metadata<R: XrpcRequest>(
        &self,
        params: R::Params,
        input: R::Input,
        options: &CallOptions,
    ) -> Result<(R::Output, ResponseMetadata), Error<R::Error>> {
        let method = match R::METHOD {
            XrpcMethod::Query => Method::GET,
            XrpcMethod::Procedure => Method::POST,
        };
        let mut pairs = Vec::new();
        params.to_query_params(&mut pairs);
        let body = input.into_body()?;
        let content_type = match R::INPUT_ENCODING {
            Some("*/*") => {
                let supplied = options
                    .headers
                    .get(CONTENT_TYPE)
                    .and_then(|value| value.to_str().ok());
                Some(supplied.and_then(media_type).ok_or_else(|| {
                    TransportError::InvalidRequest(
                        "binary XRPC input requires a content type".to_owned(),
                    )
                })?)
            }
            Some(encoding) => Some(HeaderValue::from_static(encoding)),
            None => body
                .as_ref()
                .map(|_| HeaderValue::from_static("application/json")),
        };
        let body = body.map(|data| XrpcBody {
            bytes: data.into(),
            content_type: content_type.unwrap_or(HeaderValue::from_static("application/json")),
        });

        let call =
            self.build::<R::Error>(method, R::NSID, pairs, body, R::OUTPUT_ENCODING, options)?;
        let raw = self.execute(call, options).await?;
        let response = require_success::<R::Error>(raw)?;
        if let Some(expected) = R::OUTPUT_ENCODING {
            if expected != "*/*" {
                require_content_type::<R::Error>(&response, expected)?;
            }
        }
        let output = R::Output::from_body(response.body()).map_err(|source| Error::Decode {
            endpoint: R::NSID,
            status: response.status(),
            source,
        })?;
        Ok((output, ResponseMetadata::from_response(&response)))
    }

    pub async fn query(
        &self,
        nsid: &str,
        params: impl IntoIterator<Item = (impl AsRef<str>, impl AsRef<str>)>,
        options: &CallOptions,
    ) -> Result<XrpcResponse, Error> {
        self.raw(Method::GET, nsid, params, None, options).await
    }

    pub async fn procedure(
        &self,
        nsid: &str,
        params: impl IntoIterator<Item = (impl AsRef<str>, impl AsRef<str>)>,
        body: Option<XrpcBody>,
        options: &CallOptions,
    ) -> Result<XrpcResponse, Error> {
        self.raw(Method::POST, nsid, params, body, options).await
    }

    async fn raw(
        &self,
        method: Method,
        nsid: &str,
        params: impl IntoIterator<Item = (impl AsRef<str>, impl AsRef<str>)>,
        body: Option<XrpcBody>,
        options: &CallOptions,
    ) -> Result<XrpcResponse, Error> {
        let call = self.build(
            method,
            nsid,
            params,
            body,
            Some("application/json"),
            options,
        )?;
        let raw = self.execute(call, options).await?;
        let response = require_success::<UndeclaredError>(raw)?;
        Ok(XrpcResponse {
            metadata: ResponseMetadata::from_response(&response),
            body: response.into_body(),
        })
    }

    fn build<E: fmt::Debug>(
        &self,
        method: Method,
        nsid: &str,
        params: impl IntoIterator<Item = (impl AsRef<str>, impl AsRef<str>)>,
        body: Option<XrpcBody>,
        accept: Option<&'static str>,
        options: &CallOptions,
    ) -> Result<Call, Error<E>> {
        nsid.parse::<Nsid>().map_err(|_| Error::InvalidNsid)?;
        let mut url = options.service.as_ref().unwrap_or(&self.base_url).clone();
        validate_url_with_development(&url, options.transport.allow_loopback)
            .map_err(|error| TransportError::PolicyViolation(error.to_string()))?;
        if !matches!(url.scheme(), "http" | "https") || url.query().is_some() {
            return Err(
                TransportError::InvalidRequest("invalid XRPC service URL".to_owned()).into(),
            );
        }
        url.path_segments_mut()
            .map_err(|()| TransportError::InvalidRequest("invalid XRPC service path".to_owned()))?
            .pop_if_empty()
            .extend(["xrpc", nsid]);

        let mut params = params.into_iter().peekable();
        if params.peek().is_some() {
            let mut query = url.query_pairs_mut();
            for (key, value) in params {
                query.append_pair(key.as_ref(), value.as_ref());
            }
        }

        let origin = Origin::from_url(&url)
            .map_err(|error| TransportError::PolicyViolation(error.to_string()))?;
        let same_origin = self.base_origin == origin;
        let eligible = same_origin
            && origin.host().trim_end_matches('.') != "plc.directory"
            && nsid != "com.atproto.server.createSession"
            && !options.transport.anonymous;

        let headers = self.headers(same_origin, nsid, body.as_ref(), accept, options)?;
        let request = Request::builder()
            .method(method)
            .uri(url.as_str())
            .body(body.map_or_else(Bytes::new, |body| body.bytes))
            .map_err(|error| TransportError::InvalidRequest(error.to_string()))?;
        let mut call = Call {
            request,
            origin,
            eligible,
        };
        *call.request.headers_mut() = headers;
        if !same_origin || options.transport.anonymous {
            retain_anonymous_headers(call.request.headers_mut());
        }
        if !eligible {
            for name in [
                "authorization",
                "dpop",
                "x-dpop",
                "cookie",
                "x-api-key",
                "x-auth-token",
                "proxy-authorization",
            ] {
                call.request.headers_mut().remove(name);
            }
        }
        Ok(call)
    }

    fn headers(
        &self,
        same_origin: bool,
        nsid: &str,
        body: Option<&XrpcBody>,
        accept: Option<&'static str>,
        options: &CallOptions,
    ) -> Result<HeaderMap, TransportError> {
        let mut headers = self.headers.clone();
        if let Some(accept) = accept {
            headers
                .entry(ACCEPT)
                .or_insert(HeaderValue::from_static(accept));
        }
        if let Some(body) = body {
            headers.insert(CONTENT_TYPE, body.content_type.clone());
        }
        headers.extend(options.headers.clone());

        if !same_origin || never_proxy(nsid) {
            headers.remove(PROXY);
        } else if !options.headers.contains_key(PROXY) {
            let proxy = options
                .proxy
                .as_deref()
                .or_else(|| self.mapped_service(nsid));
            if let Some(proxy) = proxy {
                set_header(&mut headers, PROXY, proxy)?;
            }
        }

        if same_origin && !options.headers.contains_key(LABELERS) {
            let labelers = options.accept_labelers.as_deref().unwrap_or(&self.labelers);
            if !labelers.is_empty() {
                set_header(&mut headers, LABELERS, &XrpcLabeler::header_value(labelers))?;
            } else if options.accept_labelers.is_some() {
                headers.remove(LABELERS);
            }
        }
        if same_origin && self.request_ids && !headers.contains_key("x-request-id") {
            let mut id = [0_u8; 16];
            if getrandom::getrandom(&mut id).is_ok() {
                set_header(
                    &mut headers,
                    "x-request-id",
                    &format!("{:032x}", u128::from_be_bytes(id)),
                )?;
            }
        }
        Ok(headers)
    }

    fn mapped_service(&self, nsid: &str) -> Option<&str> {
        self.service_dids
            .iter()
            .filter(|(prefix, _)| {
                nsid == prefix.as_str()
                    || nsid
                        .strip_prefix(prefix.as_str())
                        .is_some_and(|rest| rest.starts_with('.'))
            })
            .max_by_key(|(prefix, _)| prefix.len())
            .map(|(_, did)| did.as_str())
    }

    async fn execute<E: fmt::Debug>(
        &self,
        call: Call,
        options: &CallOptions,
    ) -> Result<Response<Bytes>, Error<E>> {
        let auth = self.auth.as_deref().filter(|_| call.eligible);
        let origin = call.origin.to_string();
        let safe_method = matches!(*call.request.method(), Method::GET | Method::HEAD);
        let mut retried_nonce = false;
        let mut retried_auth = false;

        for attempt in 1..=MAX_ATTEMPTS {
            let ready = prepare(auth, call.request.clone(), options.skip_token_refresh).await?;
            let (request, auth_context) = ready;
            let was_proxied = request.headers().contains_key(PROXY);
            let redirects =
                if auth_context.is_some() || request.headers().contains_key("authorization") {
                    RedirectPolicy::Never
                } else {
                    options.redirects
                };
            let response = send_with_redirects(
                self.transport.as_ref(),
                request,
                &options.transport,
                redirects,
            )
            .await;
            let response = match response {
                Ok(response) => response,
                Err(error) => {
                    if attempt < MAX_ATTEMPTS
                        && retryable_transport(&error, safe_method)
                        && self.wait(backoff(attempt, 10, 0.3)).await
                    {
                        continue;
                    }
                    return Err(error.into());
                }
            };

            let status = response.status();
            if let Some((provider, context)) = auth.zip(auth_context.as_ref()) {
                let nonce = response
                    .headers()
                    .get("dpop-nonce")
                    .and_then(|value| value.to_str().ok());
                if let Some(nonce) = nonce {
                    provider.update_dpop_nonce(&origin, nonce, context).await;
                }
                if status == StatusCode::UNAUTHORIZED || status == StatusCode::BAD_REQUEST {
                    let body = XrpcErrorBody::parse(response.body());
                    let code = body.as_ref().map(|body| body.error.as_str());
                    if status == StatusCode::UNAUTHORIZED && nonce_challenge(&response, code) {
                        if retried_nonce || attempt == MAX_ATTEMPTS {
                            return Err(Error::MaxRetries);
                        }
                        if nonce.is_some() {
                            retried_nonce = true;
                            continue;
                        }
                        return Ok(response);
                    }

                    let rejected_session = (status == StatusCode::UNAUTHORIZED
                        && (!was_proxied || code.is_some_and(session_error)))
                        || (status == StatusCode::BAD_REQUEST && code == Some("ExpiredToken"));
                    if rejected_session
                        && !retried_auth
                        && !options.skip_token_refresh
                        && attempt < MAX_ATTEMPTS
                        && provider.handle_unauthorized(&response, context).await?
                            == UnauthorizedAction::Retry
                    {
                        retried_auth = true;
                        continue;
                    }
                }
            }

            if status.is_server_error()
                && status != StatusCode::NOT_IMPLEMENTED
                && safe_method
                && attempt < MAX_ATTEMPTS
                && self
                    .wait(retry_after(response.headers()).map_or_else(
                        || backoff(attempt, 8, 0.2),
                        |delay| delay.min(Duration::from_secs(30)),
                    ))
                    .await
            {
                continue;
            }
            return Ok(response);
        }

        unreachable!("every attempt returns or is followed by an attempt within the limit")
    }

    async fn wait(&self, duration: Duration) -> bool {
        let Some(sleeper) = &self.sleeper else {
            return false;
        };
        sleeper.sleep(duration).await;
        true
    }
}

struct Call {
    request: Request<Bytes>,
    origin: Origin,
    eligible: bool,
}

async fn prepare(
    auth: Option<&dyn AuthProvider>,
    request: Request<Bytes>,
    skip_refresh: bool,
) -> Result<(Request<Bytes>, Option<super::AuthCtx>), AuthError> {
    let Some(auth) = auth else {
        return Ok((request, None));
    };
    if !skip_refresh {
        match auth.refresh_if_needed().await {
            Ok(()) => {}
            Err(AuthError::NoSession) => return Ok((request, None)),
            Err(error) => return Err(error),
        }
    }
    let (signed, context) = match auth.prepare(request.clone()).await {
        Ok(signed) => signed,
        Err(AuthError::NoSession) => return Ok((request, None)),
        Err(error) => return Err(error),
    };
    if signed.uri() != request.uri() || signed.method() != request.method() {
        return Err(AuthError::Other(
            "auth provider changed the request target".to_owned(),
        ));
    }
    let present = context.did.is_some() || context.jkt.is_some();
    Ok((signed, present.then_some(context)))
}

fn require_success<E: DeclaredXrpcError>(
    response: Response<Bytes>,
) -> Result<Response<Bytes>, Error<E>> {
    if response.status().is_success() {
        return Ok(response);
    }
    let error = XrpcError::parse(&response, DIAGNOSTIC_BYTES, |name| {
        let mapped = E::from_wire_name(name);
        mapped.is_declared().then_some(mapped)
    });
    Err(Box::new(error).into())
}

fn require_content_type<E: fmt::Debug>(
    response: &Response<Bytes>,
    expected: &'static str,
) -> Result<(), Error<E>> {
    let actual = response
        .headers()
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok());
    let matches = actual
        .and_then(|actual| actual.split(';').next())
        .is_some_and(|actual| actual.trim().eq_ignore_ascii_case(expected));
    if matches {
        Ok(())
    } else {
        Err(Error::ContentType {
            expected,
            actual: actual.map(str::to_owned),
        })
    }
}

fn media_type(value: &str) -> Option<HeaderValue> {
    let (kind, subtype) = value.split(';').next()?.trim().split_once('/')?;
    let valid = |part: &str| {
        !part.is_empty()
            && part
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b"!#$%&'+-.^_`|~".contains(&b))
    };
    if valid(kind) && valid(subtype) {
        HeaderValue::from_str(value).ok()
    } else {
        None
    }
}

fn set_header(
    headers: &mut HeaderMap,
    name: &'static str,
    value: &str,
) -> Result<(), TransportError> {
    let value = HeaderValue::from_str(value)
        .map_err(|_| TransportError::InvalidRequest(format!("invalid {name} header")))?;
    headers.insert(HeaderName::from_static(name), value);
    Ok(())
}

fn never_proxy(nsid: &str) -> bool {
    matches!(
        nsid,
        "app.bsky.actor.getPreferences" | "app.bsky.actor.putPreferences"
    )
}

fn nonce_challenge(response: &Response<Bytes>, code: Option<&str>) -> bool {
    code == Some("use_dpop_nonce")
        || response
            .headers()
            .get_all(WWW_AUTHENTICATE)
            .iter()
            .filter_map(|value| value.to_str().ok())
            .any(|value| {
                value.split([',', ' ']).any(|attribute| {
                    matches!(
                        attribute,
                        "error=\"use_dpop_nonce\"" | "error=use_dpop_nonce"
                    )
                })
            })
}

fn session_error(code: &str) -> bool {
    matches!(
        code,
        "AccountSessionExpired"
            | "AuthenticationRequired"
            | "ExpiredToken"
            | "InvalidToken"
            | "invalid_token"
            | "use_dpop_nonce"
            | "AuthMissing"
    )
}

fn retryable_transport(error: &TransportError, safe_method: bool) -> bool {
    matches!(error, TransportError::Connect(_))
        || safe_method
            && matches!(
                error,
                TransportError::Timeout | TransportError::ConnectionLost(_)
            )
}

fn backoff(attempt: u32, max_seconds: u64, spread: f64) -> Duration {
    let mut random_bytes = [0_u8; 2];
    let variation = getrandom::getrandom(&mut random_bytes).map_or(1.0, |()| {
        let fraction = f64::from(u16::from_ne_bytes(random_bytes)) / f64::from(u16::MAX);
        1.0 + spread * (2.0 * fraction - 1.0)
    });
    let delay = Duration::from_secs((1_u64 << (attempt - 1)).min(max_seconds));
    delay.mul_f64(variation)
}
