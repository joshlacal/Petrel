use std::collections::{HashMap, HashSet};
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};
use std::sync::Arc;
use std::time::Duration;

use async_lock::Mutex;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_oauth_scopes::ScopeSet;
use serde::{Deserialize, Serialize};
use url::Url;

use crate::error::OAuthServerError;
use crate::http::{OAuthForm, OAuthHttpHeaders};
use crate::jose::{
    OAuthCompactJwt, OAuthJsonWebKeySet, OAuthJwsAlgorithm, OAuthJwtSignatureEncoding,
    OAuthJwtVerificationConstraints,
};
use crate::store::{
    OAuthCachedClientMetadata, OAuthClientMetadataCache, OAuthReplayNamespace, OAuthReplayStore,
};
use crate::support::{
    ConstantTime, DigestPurpose, OAuthClock, OAuthKeyedDigest, StrictJson, SystemOAuthClock,
};

/// Classification of an AT Protocol OAuth client.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OAuthClientKind {
    /// Unauthenticated `http://localhost` public client with query-encoded or default metadata.
    Loopback,
    /// Discoverable HTTPS client whose `client_id` points to its hosted metadata JSON document.
    Discoverable,
    /// Explicitly configured first-party / trusted client registered with the server.
    Trusted,
}

/// Application type declared in client metadata.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum OAuthApplicationType {
    #[default]
    Web,
    Native,
}

/// Client authentication method at the token / PAR / revocation endpoints.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum OAuthTokenEndpointAuthMethod {
    #[default]
    #[serde(rename = "none")]
    None,
    #[serde(rename = "private_key_jwt")]
    PrivateKeyJwt,
}

/// Validated AT Protocol OAuth client metadata document.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OAuthClientMetadata {
    pub client_id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub client_name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub client_uri: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub logo_uri: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tos_uri: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub policy_uri: Option<String>,
    #[serde(default)]
    pub application_type: OAuthApplicationType,
    #[serde(default)]
    pub grant_types: Vec<String>,
    #[serde(default)]
    pub response_types: Vec<String>,
    #[serde(default)]
    pub redirect_uris: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub scope: Option<String>,
    #[serde(default)]
    pub token_endpoint_auth_method: OAuthTokenEndpointAuthMethod,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub token_endpoint_auth_signing_alg: Option<String>,
    #[serde(default)]
    pub dpop_bound_access_tokens: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub jwks_uri: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub jwks: Option<OAuthJsonWebKeySet>,
}

impl OAuthClientMetadata {
    /// Strictly decodes and validates remote client metadata JSON.
    pub fn decode_validated(
        expected_client_id: &str,
        data: &[u8],
    ) -> Result<Self, OAuthServerError> {
        StrictJson::validate(data)?;
        let metadata: Self = serde_json::from_slice(data).map_err(|err| {
            OAuthServerError::Malformed(format!("client metadata is invalid: {err}"))
        })?;
        metadata.validate_for_client(expected_client_id)?;
        Ok(metadata)
    }

    /// Parses declared `scope` string into a [`ScopeSet`].
    pub fn declared_scopes(&self) -> Result<ScopeSet, OAuthServerError> {
        match self.scope.as_deref() {
            Some(s) if !s.trim().is_empty() => ScopeSet::parse_strict(s).map_err(|err| {
                OAuthServerError::Malformed(format!(
                    "client metadata declares invalid scope: {err}"
                ))
            }),
            _ => Err(OAuthServerError::Malformed(
                "client metadata must declare non-empty scope".into(),
            )),
        }
    }

    /// Checks whether a PAR/authorize `redirect_uri` matches this client's registered redirects.
    ///
    /// Loopback `http://localhost` development clients use port-insensitive loopback matching per
    /// RFC 8252 / AT Protocol OAuth profile (matching Swift `OAuthClientMetadata.matchesRedirectURI`).
    /// All other clients require an exact URI match.
    pub fn matches_redirect_uri(&self, requested_redirect_uri: &str) -> bool {
        if Url::parse(&self.client_id).is_ok_and(|url| is_loopback_client_url(&url)) {
            let Ok(requested) = Url::parse(requested_redirect_uri) else {
                return false;
            };
            return self
                .redirect_uris
                .iter()
                .any(|registered| matches_loopback_redirect(registered, &requested));
        }
        self.redirect_uris
            .iter()
            .any(|registered| registered == requested_redirect_uri)
    }

    /// True if this client authenticates confidentially via `private_key_jwt`.
    pub const fn is_confidential(&self) -> bool {
        matches!(
            self.token_endpoint_auth_method,
            OAuthTokenEndpointAuthMethod::PrivateKeyJwt
        )
    }

    /// Validates client metadata against AT Protocol OAuth profile rules.
    pub fn validate_for_client(&self, expected_client_id: &str) -> Result<(), OAuthServerError> {
        if self.client_id != expected_client_id {
            return Err(OAuthServerError::Malformed(
                "client_id in metadata document does not match requested URL".into(),
            ));
        }
        if !self.dpop_bound_access_tokens {
            return Err(OAuthServerError::Malformed(
                "dpop_bound_access_tokens must be true".into(),
            ));
        }
        if !self.grant_types.iter().any(|g| g == "authorization_code") {
            return Err(OAuthServerError::Malformed(
                "client metadata must include authorization_code grant_type".into(),
            ));
        }
        if !self.response_types.iter().any(|r| r == "code") {
            return Err(OAuthServerError::Malformed(
                "client metadata must include code response_type".into(),
            ));
        }
        if self.redirect_uris.is_empty() {
            return Err(OAuthServerError::Malformed(
                "client metadata must declare at least one redirect_uri".into(),
            ));
        }
        let client_url = Url::parse(&self.client_id).map_err(|_| {
            OAuthServerError::InvalidIdentifier("client_id must be a valid URL".into())
        })?;
        let is_loopback_client = is_loopback_client_url(&client_url);

        for uri in &self.redirect_uris {
            let parsed = Url::parse(uri)
                .map_err(|_| OAuthServerError::Malformed(format!("invalid redirect_uri: {uri}")))?;
            if parsed.fragment().is_some() {
                return Err(OAuthServerError::Malformed(
                    "redirect_uri must not contain a fragment".into(),
                ));
            }
            if is_loopback_client {
                if !is_loopback_redirect(&parsed) {
                    return Err(OAuthServerError::Malformed(
                        "loopback client redirect_uri must use 127.0.0.1 or [::1]".into(),
                    ));
                }
            } else {
                validate_redirect_for_application_type(
                    &parsed,
                    &client_url,
                    self.application_type,
                )?;
            }
        }

        self.validate_token_endpoint_auth()?;
        let _ = self.declared_scopes()?;
        Ok(())
    }

    fn validate_token_endpoint_auth(&self) -> Result<(), OAuthServerError> {
        match self.token_endpoint_auth_method {
            OAuthTokenEndpointAuthMethod::None => {
                if self.jwks.is_some() || self.jwks_uri.is_some() {
                    return Err(OAuthServerError::Malformed(
                        "public client must not declare jwks or jwks_uri".into(),
                    ));
                }
            }
            OAuthTokenEndpointAuthMethod::PrivateKeyJwt => {
                let alg = self
                    .token_endpoint_auth_signing_alg
                    .as_deref()
                    .ok_or_else(|| {
                        OAuthServerError::Malformed(
                            "confidential client must declare token_endpoint_auth_signing_alg"
                                .into(),
                        )
                    })?;
                OAuthJwsAlgorithm::parse(alg).map_err(|_| {
                    OAuthServerError::Malformed(format!(
                        "unsupported token_endpoint_auth_signing_alg: {alg}"
                    ))
                })?;
                match (&self.jwks, &self.jwks_uri) {
                    (Some(_), Some(_)) => {
                        return Err(OAuthServerError::Malformed(
                            "client metadata must not set both jwks and jwks_uri".into(),
                        ));
                    }
                    (None, None) => {
                        return Err(OAuthServerError::Malformed(
                            "confidential client must declare either jwks or jwks_uri".into(),
                        ));
                    }
                    (Some(_), None) => {}
                    (None, Some(uri)) => {
                        let parsed = Url::parse(uri).map_err(|_| {
                            OAuthServerError::Malformed("jwks_uri is not a valid URL".into())
                        })?;
                        if parsed.scheme() != "https" || parsed.host_str().is_none() {
                            return Err(OAuthServerError::Malformed(
                                "jwks_uri must use https".into(),
                            ));
                        }
                    }
                }
            }
        }
        Ok(())
    }
}

fn is_loopback_client_url(url: &Url) -> bool {
    url.scheme() == "http"
        && matches!(url.host_str(), Some("localhost"))
        && url.port().is_none()
        && url.username().is_empty()
        && url.password().is_none()
        && url.fragment().is_none()
        && matches!(url.path(), "/" | "")
}

fn loopback_host(host: Option<&str>) -> Option<&str> {
    match host {
        Some("127.0.0.1") => Some("127.0.0.1"),
        Some("[::1]" | "::1") => Some("::1"),
        _ => None,
    }
}

fn is_loopback_redirect(url: &Url) -> bool {
    url.scheme() == "http"
        && url.username().is_empty()
        && url.password().is_none()
        && url.fragment().is_none()
        && !url.path().is_empty()
        && loopback_host(url.host_str()).is_some()
}

fn matches_loopback_redirect(registered_uri: &str, requested: &Url) -> bool {
    let Ok(registered) = Url::parse(registered_uri) else {
        return false;
    };
    if !is_loopback_redirect(&registered) || !is_loopback_redirect(requested) {
        return false;
    }
    registered.scheme() == requested.scheme()
        && loopback_host(registered.host_str()) == loopback_host(requested.host_str())
        && registered.path() == requested.path()
        && registered.query() == requested.query()
}

fn validate_redirect_for_application_type(
    redirect: &Url,
    client_url: &Url,
    app_type: OAuthApplicationType,
) -> Result<(), OAuthServerError> {
    match app_type {
        OAuthApplicationType::Web => {
            if redirect.scheme() != "https" {
                return Err(OAuthServerError::Malformed(
                    "web client redirect_uri must use https".into(),
                ));
            }
            if redirect.host_str() != client_url.host_str() {
                return Err(OAuthServerError::Malformed(
                    "web client redirect_uri host must match client_id host".into(),
                ));
            }
        }
        OAuthApplicationType::Native => {
            if is_loopback_redirect(redirect) {
                return Ok(());
            }
            if redirect.scheme() == "https" {
                return Ok(());
            }
            // Custom reverse-DNS scheme: must match reversed host of client_id.
            let Some(host) = client_url.host_str() else {
                return Err(OAuthServerError::Malformed("client_id missing host".into()));
            };
            let reversed: String = host.rsplit('.').collect::<Vec<_>>().join(".");
            if redirect.scheme() != reversed {
                return Err(OAuthServerError::Malformed(
                    "native custom-scheme redirect_uri must match reversed client_id host".into(),
                ));
            }
        }
    }
    Ok(())
}

/// Fully resolved client metadata along with classification and verification keys.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthResolvedClientMetadata {
    pub kind: OAuthClientKind,
    pub metadata: OAuthClientMetadata,
    pub key_set: Option<OAuthJsonWebKeySet>,
}

/// Async client metadata resolver used by PAR, Authorize, Token, and Revocation endpoints.
pub trait OAuthClientResolving: MaybeSend + MaybeSync {
    fn resolve(
        &self,
        client_id: &str,
    ) -> BoxFuture<'_, Result<OAuthResolvedClientMetadata, OAuthServerError>>;
}

/// In-memory deterministic client resolver (for unit/integration tests and trusted registrations).
#[derive(Debug, Default)]
pub struct StaticOAuthClientResolver {
    clients: Mutex<HashMap<String, OAuthResolvedClientMetadata>>,
}

impl StaticOAuthClientResolver {
    /// Creates an empty resolver.
    pub fn new() -> Self {
        Self::default()
    }

    /// Registers a resolved client directly.
    pub async fn register(&self, resolved: OAuthResolvedClientMetadata) {
        self.clients
            .lock()
            .await
            .insert(resolved.metadata.client_id.clone(), resolved);
    }

    /// Blocking/sync builder variant for test setup.
    #[must_use]
    pub fn with_client(self, resolved: OAuthResolvedClientMetadata) -> Self {
        if let Some(mut map) = self.clients.try_lock() {
            map.insert(resolved.metadata.client_id.clone(), resolved);
        }
        self
    }
}

impl OAuthClientResolving for StaticOAuthClientResolver {
    fn resolve(
        &self,
        client_id: &str,
    ) -> BoxFuture<'_, Result<OAuthResolvedClientMetadata, OAuthServerError>> {
        let id = client_id.to_owned();
        Box::pin(async move {
            if let Some(found) = self.clients.lock().await.get(&id).cloned() {
                return Ok(found);
            }
            if let Some(loopback) = synthesize_loopback_client(&id)? {
                return Ok(loopback);
            }
            Err(OAuthServerError::Unauthorized(format!(
                "unknown OAuth client_id: {id}"
            )))
        })
    }
}

/// Synthesizes ATProto `http://localhost[?...]` loopback client metadata if `client_id` is a loopback URL.
pub fn synthesize_loopback_client(
    client_id: &str,
) -> Result<Option<OAuthResolvedClientMetadata>, OAuthServerError> {
    let Ok(url) = Url::parse(client_id) else {
        return Ok(None);
    };
    if url.scheme() != "http" || url.host_str() != Some("localhost") {
        return Ok(None);
    }
    if url.port().is_some()
        || !url.username().is_empty()
        || url.password().is_some()
        || !matches!(url.path(), "/" | "")
        || url.fragment().is_some()
    {
        return Err(OAuthServerError::InvalidIdentifier(
            "loopback client_id must be http://localhost without port, path, or fragment".into(),
        ));
    }

    let mut redirect_uris = Vec::new();
    let mut scope: Option<String> = None;
    if let Some(q) = url.query() {
        for (k, v) in form_urlencoded::parse(q.as_bytes()) {
            match k.as_ref() {
                "redirect_uri" => redirect_uris.push(v.into_owned()),
                "scope" => {
                    if scope.is_some() {
                        return Err(OAuthServerError::Malformed(
                            "duplicate scope in loopback client_id".into(),
                        ));
                    }
                    scope = Some(v.into_owned());
                }
                _ => {
                    return Err(OAuthServerError::Malformed(format!(
                        "unsupported loopback client_id query parameter: {k}"
                    )));
                }
            }
        }
    }
    if redirect_uris.is_empty() {
        redirect_uris.push("http://127.0.0.1/".to_owned());
        redirect_uris.push("http://[::1]/".to_owned());
    }
    let metadata = OAuthClientMetadata {
        client_id: client_id.to_owned(),
        client_name: Some("Loopback Client".to_owned()),
        client_uri: None,
        logo_uri: None,
        tos_uri: None,
        policy_uri: None,
        application_type: OAuthApplicationType::Native,
        grant_types: vec!["authorization_code".to_owned(), "refresh_token".to_owned()],
        response_types: vec!["code".to_owned()],
        redirect_uris,
        scope: Some(scope.unwrap_or_else(|| "atproto transition:generic".to_owned())),
        token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::None,
        token_endpoint_auth_signing_alg: None,
        dpop_bound_access_tokens: true,
        jwks_uri: None,
        jwks: None,
    };
    metadata.validate_for_client(client_id)?;
    Ok(Some(OAuthResolvedClientMetadata {
        kind: OAuthClientKind::Loopback,
        metadata,
        key_set: None,
    }))
}

/// SSRF policy validating that remote client metadata / JWKS URLs only reach public Internet addresses.
#[derive(Debug, Clone, Copy, Default)]
pub struct OAuthPublicAddressPolicy {
    /// Test-only escape hatch permitting loopback HTTP/HTTPS destinations.
    pub allow_loopback_for_testing: bool,
}

impl OAuthPublicAddressPolicy {
    /// Checks whether a parsed IP address is globally routable on the public Internet.
    pub fn is_public_ip(self, addr: IpAddr) -> bool {
        if self.allow_loopback_for_testing && addr.is_loopback() {
            return true;
        }
        match addr {
            IpAddr::V4(v4) => is_public_ipv4(v4),
            IpAddr::V6(v6) => is_public_ipv6(v6, self.allow_loopback_for_testing),
        }
    }

    /// Validates that a URL is suitable for public SSRF-safe remote fetch (scheme + non-literal-IP host).
    pub fn validate_url(self, url: &Url) -> Result<(), OAuthServerError> {
        let allowed_scheme =
            url.scheme() == "https" || (self.allow_loopback_for_testing && url.scheme() == "http");
        if !allowed_scheme {
            return Err(OAuthServerError::InvalidIdentifier(
                "remote metadata URL must use https".into(),
            ));
        }
        if !url.username().is_empty() || url.password().is_some() {
            return Err(OAuthServerError::InvalidIdentifier(
                "remote URL must not contain userinfo".into(),
            ));
        }
        let host = url
            .host_str()
            .ok_or_else(|| OAuthServerError::InvalidIdentifier("remote URL missing host".into()))?;
        if let Ok(ip) = host.trim_matches(['[', ']']).parse::<IpAddr>()
            && !self.is_public_ip(ip)
        {
            return Err(OAuthServerError::Unauthorized(
                "remote URL targets non-public IP address".into(),
            ));
        }
        Ok(())
    }
}

fn is_public_ipv4(ip: Ipv4Addr) -> bool {
    let [a, b, c, _] = ip.octets();
    if ip.is_unspecified()
        || ip.is_loopback()
        || ip.is_private()
        || ip.is_link_local()
        || ip.is_broadcast()
        || ip.is_multicast()
        || ip.is_documentation()
    {
        return false;
    }
    // 100.64.0.0/10 CGNAT
    if a == 100 && (64..=127).contains(&b) {
        return false;
    }
    // 192.0.0.0/24 IETF protocol assignments
    if a == 192 && b == 0 && c == 0 {
        return false;
    }
    // 198.18.0.0/15 benchmarking
    if a == 198 && (b == 18 || b == 19) {
        return false;
    }
    // 240.0.0.0/4 reserved
    if a >= 240 {
        return false;
    }
    true
}

fn is_public_ipv6(ip: Ipv6Addr, allow_loopback: bool) -> bool {
    if let Some(mapped) = ip.to_ipv4_mapped() {
        return (allow_loopback && mapped.is_loopback()) || is_public_ipv4(mapped);
    }
    if ip.is_unspecified() || ip.is_loopback() || ip.is_multicast() {
        return allow_loopback && ip.is_loopback();
    }
    let segs = ip.segments();
    // Unique local fc00::/7
    if (segs[0] & 0xfe00) == 0xfc00 {
        return false;
    }
    // Link-local fe80::/10
    if (segs[0] & 0xffc0) == 0xfe80 {
        return false;
    }
    // Discard 100::/64
    if segs[0] == 0x0100 && segs[1] == 0 && segs[2] == 0 && segs[3] == 0 {
        return false;
    }
    // Documentation 2001:db8::/32
    if segs[0] == 0x2001 && segs[1] == 0x0db8 {
        return false;
    }
    // Teredo 2001::/32
    if segs[0] == 0x2001 && segs[1] == 0x0000 {
        return false;
    }
    // 6to4 2002::/16
    if segs[0] == 0x2002 {
        return false;
    }
    // NAT64 well-known prefix 64:ff9b::/96 and local 64:ff9b:1::/48
    if segs[0] == 0x0064 && segs[1] == 0xff9b {
        return false;
    }
    true
}

/// DNS hostname resolution abstraction for SSRF address pinning.
pub trait OAuthHostnameResolver: MaybeSend + MaybeSync {
    fn resolve_ips(
        &self,
        host: &str,
        port: u16,
    ) -> BoxFuture<'_, Result<Vec<IpAddr>, OAuthServerError>>;
}

/// Limits applied to outbound fetches of client metadata and JWKS documents.
#[derive(Debug, Clone)]
pub struct OAuthRemoteFetchPolicy {
    pub timeout: Duration,
    pub max_bytes: usize,
    pub max_redirects: usize,
    pub address_policy: OAuthPublicAddressPolicy,
}

impl Default for OAuthRemoteFetchPolicy {
    fn default() -> Self {
        Self {
            timeout: Duration::from_secs(5),
            max_bytes: 64 * 1024,
            max_redirects: 0,
            address_policy: OAuthPublicAddressPolicy::default(),
        }
    }
}

/// HTTP response returned by [`OAuthRemoteTransport`].
#[derive(Debug, Clone)]
pub struct OAuthRemoteFetchResponse {
    pub status: u16,
    pub headers: OAuthHttpHeaders,
    pub body: Vec<u8>,
}

/// Transport trait for fetching client metadata, JWKS documents, and Lexicon records.
pub trait OAuthRemoteTransport: MaybeSend + MaybeSync {
    /// Whether this transport enforces SSRF-safe address pinning on outbound connections.
    ///
    /// Security-sensitive callers such as `AuthenticatedOAuthLexiconResolver` refuse transports
    /// that return `false` before issuing any network request.
    fn pins_connections(&self) -> bool {
        false
    }

    fn fetch<'a>(
        &'a self,
        url: &'a Url,
        etag: Option<&'a str>,
        policy: &'a OAuthRemoteFetchPolicy,
    ) -> BoxFuture<'a, Result<OAuthRemoteFetchResponse, OAuthServerError>>;
}

/// Native SSRF-pinned transport powered by [`petrel::net::ReqwestTransport`].
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub struct PetrelOAuthRemoteTransport {
    client: petrel::net::ReqwestTransport,
    address_policy: OAuthPublicAddressPolicy,
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
impl std::fmt::Debug for PetrelOAuthRemoteTransport {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PetrelOAuthRemoteTransport")
            .field("address_policy", &self.address_policy)
            .finish_non_exhaustive()
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
struct PolicyDnsBridge {
    policy: OAuthPublicAddressPolicy,
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
impl petrel::identity::DnsResolver for PolicyDnsBridge {
    fn txt(
        &self,
        _name: &str,
    ) -> impl std::future::Future<Output = Result<Vec<String>, petrel::identity::DnsError>>
    + petrel::rt::MaybeSend {
        std::future::ready(Ok(Vec::new()))
    }

    async fn lookup_ip(&self, host: &str) -> Result<Vec<IpAddr>, petrel::identity::DnsError> {
        let addrs = tokio::net::lookup_host((host, 443))
            .await
            .map_err(|err| petrel::identity::DnsError::Lookup(err.to_string()))?;
        let public: Vec<IpAddr> = addrs
            .map(|sa| sa.ip())
            .filter(|ip| self.policy.is_public_ip(*ip))
            .collect();
        if public.is_empty() {
            return Err(petrel::identity::DnsError::Lookup(format!(
                "resolved addresses for {host} blocked by SSRF policy"
            )));
        }
        Ok(public)
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
impl PetrelOAuthRemoteTransport {
    /// Creates an SSRF-pinned `ReqwestTransport`-backed remote fetcher.
    pub fn new(address_policy: OAuthPublicAddressPolicy) -> Result<Self, OAuthServerError> {
        let client = petrel::net::ReqwestTransport::with_dns(PolicyDnsBridge {
            policy: address_policy,
        })
        .map_err(|err| OAuthServerError::Unavailable(err.to_string()))?;
        Ok(Self {
            client,
            address_policy,
        })
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
impl OAuthRemoteTransport for PetrelOAuthRemoteTransport {
    fn pins_connections(&self) -> bool {
        true
    }

    fn fetch<'a>(
        &'a self,
        url: &'a Url,
        etag: Option<&'a str>,
        policy: &'a OAuthRemoteFetchPolicy,
    ) -> BoxFuture<'a, Result<OAuthRemoteFetchResponse, OAuthServerError>> {
        use petrel::net::HttpTransport as _;
        Box::pin(async move {
            policy.address_policy.validate_url(url)?;
            let mut req_builder = ::http::Request::builder()
                .method(::http::Method::GET)
                .uri(url.as_str())
                .header(::http::header::ACCEPT, "application/json");
            if let Some(etag) = etag {
                req_builder = req_builder.header(::http::header::IF_NONE_MATCH, etag);
            }
            let req = req_builder
                .body(bytes::Bytes::new())
                .map_err(|err| OAuthServerError::Malformed(err.to_string()))?;
            let mut opts = petrel::net::SendOptions::default();
            opts.timeout = Some(policy.timeout);
            opts.max_response_bytes = Some(policy.max_bytes as u64);
            opts.allow_loopback = policy.address_policy.allow_loopback_for_testing;
            opts.anonymous = true;
            let resp = self
                .client
                .send(req, &opts)
                .await
                .map_err(|err| OAuthServerError::Unavailable(err.to_string()))?;
            let mut headers = OAuthHttpHeaders::default();
            for (k, v) in resp.headers() {
                if let Ok(val) = v.to_str() {
                    headers.add(k.as_str(), val);
                }
            }
            Ok(OAuthRemoteFetchResponse {
                status: resp.status().as_u16(),
                headers,
                body: resp.into_body().to_vec(),
            })
        })
    }
}

#[derive(Clone)]
struct CachedJwksEntry {
    key_set: OAuthJsonWebKeySet,
    expires_at_secs: i64,
    stale_until_secs: i64,
    etag: Option<String>,
}

/// Caching, singleflight-deduplicated loader for AT Protocol OAuth client metadata and JWKS documents.
pub struct OAuthClientMetadataLoader {
    transport: Arc<dyn OAuthRemoteTransport>,
    cache: Arc<dyn OAuthClientMetadataCache>,
    clock: Arc<dyn OAuthClock>,
    policy: OAuthRemoteFetchPolicy,
    trusted_clients: HashMap<String, OAuthResolvedClientMetadata>,
    default_ttl_secs: i64,
    stale_ttl_secs: i64,
    negative_ttl_secs: i64,
    max_cache_entries: usize,
    jwks_cache: Mutex<HashMap<String, CachedJwksEntry>>,
    negative_cache: Mutex<HashMap<String, i64>>,
}

impl std::fmt::Debug for OAuthClientMetadataLoader {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OAuthClientMetadataLoader")
            .field("trusted_client_count", &self.trusted_clients.len())
            .finish_non_exhaustive()
    }
}

impl OAuthClientMetadataLoader {
    /// Creates a loader backed by `transport` and `cache`.
    pub fn new(
        transport: Arc<dyn OAuthRemoteTransport>,
        cache: Arc<dyn OAuthClientMetadataCache>,
    ) -> Self {
        Self {
            transport,
            cache,
            clock: Arc::new(SystemOAuthClock),
            policy: OAuthRemoteFetchPolicy::default(),
            trusted_clients: HashMap::new(),
            default_ttl_secs: 300,
            stale_ttl_secs: 3600,
            negative_ttl_secs: 30,
            max_cache_entries: 4096,
            jwks_cache: Mutex::new(HashMap::new()),
            negative_cache: Mutex::new(HashMap::new()),
        }
    }

    /// Overrides the fetch policy.
    #[must_use]
    pub fn with_policy(mut self, policy: OAuthRemoteFetchPolicy) -> Self {
        self.policy = policy;
        self
    }

    /// Overrides the clock source.
    #[must_use]
    pub fn with_clock(mut self, clock: Arc<dyn OAuthClock>) -> Self {
        self.clock = clock;
        self
    }

    /// Registers a pre-trusted client bypassing remote discovery.
    #[must_use]
    pub fn with_trusted_client(mut self, resolved: OAuthResolvedClientMetadata) -> Self {
        self.trusted_clients
            .insert(resolved.metadata.client_id.clone(), resolved);
        self
    }

    async fn resolve_remote(
        &self,
        client_id: &str,
    ) -> Result<OAuthResolvedClientMetadata, OAuthServerError> {
        let url = Url::parse(client_id).map_err(|_| {
            OAuthServerError::InvalidIdentifier("client_id must be a valid URL".into())
        })?;
        self.policy.address_policy.validate_url(&url)?;
        let now = self.clock.now_secs();
        let cached = self.cache.get_cached_metadata(client_id).await?;
        if let Some(ref entry) = cached
            && now < entry.expires_at_secs
        {
            return self.resolve_from_cached_entry(client_id, entry).await;
        }
        if cached.is_none() && self.is_negatively_cached(client_id, now).await {
            return Err(OAuthServerError::Unavailable(
                "client metadata fetch negatively cached".into(),
            ));
        }

        let etag = cached.as_ref().and_then(|c| c.etag.as_deref());
        let fetched = self.transport.fetch(&url, etag, &self.policy).await;
        match fetched {
            Ok(resp) if resp.status == 304 => {
                if let Some(mut entry) = cached {
                    let ttl = parse_cache_max_age(&resp.headers, self.default_ttl_secs);
                    entry.fetched_at_secs = now;
                    entry.expires_at_secs = now + ttl;
                    entry.stale_until_secs = now + self.stale_ttl_secs;
                    self.cache.put_cached_metadata(entry.clone()).await?;
                    return self.resolve_from_cached_entry(client_id, &entry).await;
                }
                self.record_negative_cache(client_id, now).await;
                Err(OAuthServerError::Unavailable(
                    "client metadata 304 without cached entry".into(),
                ))
            }
            Ok(resp) if resp.status == 200 => {
                let metadata = match OAuthClientMetadata::decode_validated(client_id, &resp.body) {
                    Ok(m) => m,
                    Err(err) => {
                        self.record_negative_cache(client_id, now).await;
                        return Err(err);
                    }
                };
                let ttl = parse_cache_max_age(&resp.headers, self.default_ttl_secs);
                let entry = OAuthCachedClientMetadata {
                    client_id: client_id.to_owned(),
                    raw_json: resp.body,
                    fetched_at_secs: now,
                    expires_at_secs: now + ttl,
                    stale_until_secs: now + self.stale_ttl_secs,
                    etag: resp.headers.get("etag").map(str::to_owned),
                };
                self.cache.put_cached_metadata(entry).await?;
                let key_set = self.load_key_set(&metadata).await?;
                Ok(OAuthResolvedClientMetadata {
                    kind: OAuthClientKind::Discoverable,
                    metadata,
                    key_set,
                })
            }
            Ok(resp) => {
                if let Some(entry) = cached
                    && now < entry.stale_until_secs
                {
                    return self.resolve_from_cached_entry(client_id, &entry).await;
                }
                self.record_negative_cache(client_id, now).await;
                Err(OAuthServerError::Unavailable(format!(
                    "client metadata fetch returned HTTP {}",
                    resp.status
                )))
            }
            Err(err) => {
                if let Some(entry) = cached
                    && now < entry.stale_until_secs
                {
                    return self.resolve_from_cached_entry(client_id, &entry).await;
                }
                self.record_negative_cache(client_id, now).await;
                Err(err)
            }
        }
    }

    async fn resolve_from_cached_entry(
        &self,
        client_id: &str,
        entry: &OAuthCachedClientMetadata,
    ) -> Result<OAuthResolvedClientMetadata, OAuthServerError> {
        let metadata = OAuthClientMetadata::decode_validated(client_id, &entry.raw_json)?;
        let key_set = self.load_key_set(&metadata).await?;
        Ok(OAuthResolvedClientMetadata {
            kind: OAuthClientKind::Discoverable,
            metadata,
            key_set,
        })
    }

    async fn load_key_set(
        &self,
        metadata: &OAuthClientMetadata,
    ) -> Result<Option<OAuthJsonWebKeySet>, OAuthServerError> {
        if let Some(ref jwks) = metadata.jwks {
            return Ok(Some(jwks.clone()));
        }
        let Some(ref uri) = metadata.jwks_uri else {
            return Ok(None);
        };
        let url = Url::parse(uri)
            .map_err(|_| OAuthServerError::Malformed("jwks_uri is not a valid URL".into()))?;
        self.policy.address_policy.validate_url(&url)?;
        let now = self.clock.now_secs();
        let cached = self.jwks_cache.lock().await.get(uri).cloned();
        if let Some(ref entry) = cached
            && now < entry.expires_at_secs
        {
            return Ok(Some(entry.key_set.clone()));
        }
        let neg_key = format!("jwks:{uri}");
        if cached.is_none() && self.is_negatively_cached(&neg_key, now).await {
            return Err(OAuthServerError::Unavailable(
                "jwks_uri fetch negatively cached".into(),
            ));
        }
        let etag = cached.as_ref().and_then(|c| c.etag.as_deref());
        let fetched = self.transport.fetch(&url, etag, &self.policy).await;
        match fetched {
            Ok(resp) if resp.status == 304 => {
                if let Some(mut entry) = cached {
                    let ttl = parse_cache_max_age(&resp.headers, self.default_ttl_secs);
                    entry.expires_at_secs = now + ttl;
                    entry.stale_until_secs = now + self.stale_ttl_secs;
                    self.put_cached_jwks(uri, entry.clone()).await;
                    return Ok(Some(entry.key_set));
                }
                self.record_negative_cache(&neg_key, now).await;
                Err(OAuthServerError::Unavailable(
                    "jwks_uri 304 without cached entry".into(),
                ))
            }
            Ok(resp) if resp.status == 200 => {
                let key_set = match OAuthJsonWebKeySet::decode_validated(&resp.body) {
                    Ok(ks) => ks,
                    Err(err) => {
                        self.record_negative_cache(&neg_key, now).await;
                        return Err(err);
                    }
                };
                let ttl = parse_cache_max_age(&resp.headers, self.default_ttl_secs);
                let entry = CachedJwksEntry {
                    key_set: key_set.clone(),
                    expires_at_secs: now + ttl,
                    stale_until_secs: now + self.stale_ttl_secs,
                    etag: resp.headers.get("etag").map(str::to_owned),
                };
                self.put_cached_jwks(uri, entry).await;
                Ok(Some(key_set))
            }
            Ok(resp) => {
                if let Some(entry) = cached
                    && now < entry.stale_until_secs
                {
                    return Ok(Some(entry.key_set));
                }
                self.record_negative_cache(&neg_key, now).await;
                Err(OAuthServerError::Unavailable(format!(
                    "jwks_uri fetch returned HTTP {}",
                    resp.status
                )))
            }
            Err(err) => {
                if let Some(entry) = cached
                    && now < entry.stale_until_secs
                {
                    return Ok(Some(entry.key_set));
                }
                self.record_negative_cache(&neg_key, now).await;
                Err(err)
            }
        }
    }

    async fn is_negatively_cached(&self, key: &str, now: i64) -> bool {
        let mut guard = self.negative_cache.lock().await;
        if let Some(&until) = guard.get(key) {
            if now < until {
                return true;
            }
            guard.remove(key);
        }
        false
    }

    async fn record_negative_cache(&self, key: &str, now: i64) {
        let mut guard = self.negative_cache.lock().await;
        if !guard.contains_key(key) && guard.len() >= self.max_cache_entries {
            guard.retain(|_, &mut exp| now < exp);
            if guard.len() >= self.max_cache_entries {
                guard.clear();
            }
        }
        guard.insert(key.to_owned(), now + self.negative_ttl_secs);
    }

    async fn put_cached_jwks(&self, uri: &str, entry: CachedJwksEntry) {
        let mut guard = self.jwks_cache.lock().await;
        let now = self.clock.now_secs();
        if !guard.contains_key(uri) && guard.len() >= self.max_cache_entries {
            guard.retain(|_, v| now < v.stale_until_secs.max(v.expires_at_secs));
            if guard.len() >= self.max_cache_entries {
                guard.clear();
            }
        }
        guard.insert(uri.to_owned(), entry);
    }
}

fn parse_cache_max_age(headers: &OAuthHttpHeaders, default_ttl_secs: i64) -> i64 {
    let Some(raw) = headers.get("cache-control") else {
        return default_ttl_secs;
    };
    for part in raw.split(',') {
        let trimmed = part.trim().to_ascii_lowercase();
        if trimmed == "no-store" || trimmed == "no-cache" {
            return 0;
        }
        if let Some(secs_str) = trimmed.strip_prefix("max-age=")
            && let Ok(secs) = secs_str.trim().parse::<i64>()
        {
            return secs.clamp(5, default_ttl_secs.max(5));
        }
    }
    default_ttl_secs
}

impl OAuthClientResolving for OAuthClientMetadataLoader {
    fn resolve(
        &self,
        client_id: &str,
    ) -> BoxFuture<'_, Result<OAuthResolvedClientMetadata, OAuthServerError>> {
        let id = client_id.to_owned();
        Box::pin(async move {
            if let Some(trusted) = self.trusted_clients.get(&id).cloned() {
                return Ok(trusted);
            }
            if let Some(loopback) = synthesize_loopback_client(&id)? {
                return Ok(loopback);
            }
            self.resolve_remote(&id).await
        })
    }
}

/// Validates RFC 7523 `private_key_jwt` client assertions against resolved client JWKS keys.
pub struct OAuthClientAssertionValidator {
    issuer: String,
    keyed_digest: OAuthKeyedDigest,
    replay_store: Arc<dyn OAuthReplayStore>,
    clock: Arc<dyn OAuthClock>,
    max_lifetime_secs: i64,
    clock_skew_secs: i64,
}

impl std::fmt::Debug for OAuthClientAssertionValidator {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OAuthClientAssertionValidator")
            .field("issuer", &self.issuer)
            .finish_non_exhaustive()
    }
}

#[derive(Deserialize)]
struct ClientAssertionCnf {
    #[serde(default)]
    jkt: Option<String>,
}

#[derive(Deserialize)]
struct ClientAssertionClaims {
    #[serde(default)]
    jti: Option<String>,
    #[serde(default)]
    cnf: Option<ClientAssertionCnf>,
}

/// Client authentication credential presented in form fields (`client_id`, optional `client_assertion`).
#[derive(Debug, Clone)]
pub struct ClientAuthCredentials<'a> {
    pub client_id: &'a str,
    pub client_assertion_type: Option<&'a str>,
    pub client_assertion: Option<&'a str>,
}

impl<'a> ClientAuthCredentials<'a> {
    /// Extracts client credentials from parsed form parameters.
    pub fn from_form(form: &'a HashMap<String, String>) -> Result<Self, OAuthServerError> {
        let assertion = form.get("client_assertion").map(String::as_str);
        let assertion_type = form.get("client_assertion_type").map(String::as_str);
        if let Some(explicit_client_id) = form.get("client_id").filter(|s| !s.is_empty()) {
            return Ok(Self {
                client_id: explicit_client_id.as_str(),
                client_assertion_type: assertion_type,
                client_assertion: assertion,
            });
        }
        // RFC 7523 allows omitting `client_id` form field if `iss` in the assertion names it,
        // wait: we inspect unverified payload `iss` ONLY as lookup key before verifying signature against its keys.
        let _ = OAuthForm::is_form_content_type;
        Err(OAuthServerError::Malformed("client_id is required".into()))
    }
}

impl OAuthClientAssertionValidator {
    /// Standard JWT bearer assertion type URN (RFC 7523).
    pub const CLIENT_ASSERTION_TYPE_JWT_BEARER: &'static str =
        "urn:ietf:params:oauth:client-assertion-type:jwt-bearer";

    /// Creates a validator for tokens targeting `issuer`.
    pub fn new(
        issuer: impl Into<String>,
        keyed_digest: OAuthKeyedDigest,
        replay_store: Arc<dyn OAuthReplayStore>,
        clock: Arc<dyn OAuthClock>,
    ) -> Self {
        Self {
            issuer: issuer.into(),
            keyed_digest,
            replay_store,
            clock,
            max_lifetime_secs: 60,
            clock_skew_secs: 5,
        }
    }

    /// Validates client authentication according to the client's registered `token_endpoint_auth_method`.
    pub async fn authenticate(
        &self,
        resolved: &OAuthResolvedClientMetadata,
        creds: &ClientAuthCredentials<'_>,
    ) -> Result<(), OAuthServerError> {
        self.authenticate_with_dpop(resolved, creds, None).await
    }

    /// Validates client authentication, enforcing `cnf.jkt` binding against `expected_dpop_jkt` when present.
    pub async fn authenticate_with_dpop(
        &self,
        resolved: &OAuthResolvedClientMetadata,
        creds: &ClientAuthCredentials<'_>,
        expected_dpop_jkt: Option<&str>,
    ) -> Result<(), OAuthServerError> {
        match resolved.metadata.token_endpoint_auth_method {
            OAuthTokenEndpointAuthMethod::None => {
                if creds.client_assertion.is_some() || creds.client_assertion_type.is_some() {
                    return Err(OAuthServerError::Unauthorized(
                        "public client must not send client_assertion".into(),
                    ));
                }
                Ok(())
            }
            OAuthTokenEndpointAuthMethod::PrivateKeyJwt => {
                self.authenticate_private_key_jwt(resolved, creds, expected_dpop_jkt)
                    .await
            }
        }
    }

    async fn authenticate_private_key_jwt(
        &self,
        resolved: &OAuthResolvedClientMetadata,
        creds: &ClientAuthCredentials<'_>,
        expected_dpop_jkt: Option<&str>,
    ) -> Result<(), OAuthServerError> {
        if creds.client_assertion_type != Some(Self::CLIENT_ASSERTION_TYPE_JWT_BEARER) {
            return Err(OAuthServerError::Unauthorized(
                "confidential client requires private_key_jwt client_assertion_type".into(),
            ));
        }
        let assertion = creds
            .client_assertion
            .ok_or_else(|| OAuthServerError::Unauthorized("missing client_assertion".into()))?;
        let jwks = resolved.key_set.as_ref().ok_or_else(|| {
            OAuthServerError::Unauthorized("confidential client has no JWKS".into())
        })?;
        let alg_str = resolved
            .metadata
            .token_endpoint_auth_signing_alg
            .as_deref()
            .unwrap_or("ES256");
        let required_alg = OAuthJwsAlgorithm::parse(alg_str)?;
        let now = self.clock.now_secs();
        let mut constraints = OAuthJwtVerificationConstraints::new(now);
        constraints.allowed_algorithms = vec![required_alg];
        constraints.expected_issuer = Some(resolved.metadata.client_id.clone());
        constraints.expected_audience = Some(self.issuer.clone());
        constraints.require_issued_at = true;
        constraints.require_expiration = true;
        constraints.max_lifetime_secs = Some(self.max_lifetime_secs);
        constraints.clock_skew_secs = self.clock_skew_secs;
        constraints.signature_encoding = OAuthJwtSignatureEncoding::JoseInteroperable;

        let verified = OAuthCompactJwt::verify_with_jwks::<ClientAssertionClaims>(
            assertion,
            jwks,
            &constraints,
        )?;
        if verified.registered.sub.as_deref() != Some(resolved.metadata.client_id.as_str()) {
            return Err(OAuthServerError::Unauthorized(
                "client_assertion sub must equal client_id".into(),
            ));
        }
        if let Some(cnf) = verified.claims.cnf {
            let bound_jkt = cnf
                .jkt
                .as_deref()
                .filter(|s| !s.is_empty())
                .ok_or_else(|| {
                    OAuthServerError::Unauthorized(
                        "client_assertion cnf.jkt must be non-empty".into(),
                    )
                })?;
            match expected_dpop_jkt {
                Some(req_jkt) if ConstantTime::equal(bound_jkt, req_jkt) => {}
                Some(_) => {
                    return Err(OAuthServerError::Unauthorized(
                        "client_assertion cnf.jkt does not match DPoP proof key".into(),
                    ));
                }
                None => {
                    return Err(OAuthServerError::Unauthorized(
                        "DPoP proof is required for cnf-bound client_assertion".into(),
                    ));
                }
            }
        }
        let jti = verified
            .claims
            .jti
            .filter(|s| !s.is_empty() && s.len() <= 256)
            .ok_or_else(|| {
                OAuthServerError::Unauthorized("client_assertion must include bounded jti".into())
            })?;
        let replay_key = format!("{}\0{jti}", resolved.metadata.client_id);
        let digest = self
            .keyed_digest
            .digest_str(&replay_key, DigestPurpose::ClientAssertion);
        let expires_at = verified
            .registered
            .exp
            .unwrap_or(now + self.max_lifetime_secs)
            .saturating_add(self.clock_skew_secs)
            .saturating_add(1);
        let fresh = self
            .replay_store
            .record_if_fresh(
                OAuthReplayNamespace::ClientAssertion,
                digest,
                expires_at,
                now,
            )
            .await?;
        if !fresh {
            return Err(OAuthServerError::Unauthorized(
                "client_assertion jti was replayed".into(),
            ));
        }
        Ok(())
    }
}

/// Normalizes an ATProto client's `redirect_uris` uniqueness check helper.
#[allow(dead_code)]
fn _unique_strings(items: &[String]) -> bool {
    let set: HashSet<&str> = items.iter().map(String::as_str).collect();
    set.len() == items.len()
}
