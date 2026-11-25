use std::collections::HashMap;
use std::sync::Arc;
use std::sync::atomic::{AtomicI64, Ordering};

use petrel_oauth_scopes::{
    OAuthScopeAdmissionPolicy, OAuthScopeBudget, OAuthScopeTokenizer, ScopeSet,
};
use serde::Serialize;

use crate::clients::{ClientAuthCredentials, OAuthClientAssertionValidator, OAuthClientResolving};
use crate::dpop::{
    DpopValidationContext, OAuthDpopError, OAuthDpopNonceService, OAuthDpopProofValidator,
    OAuthDpopReplayChecker,
};
use crate::error::OAuthServerError;
use crate::http::{OAuthForm, OAuthHttpHeaders, OAuthHttpRequest, OAuthHttpResponse, OAuthRoute};
use crate::jose::{OAuthJsonWebKeySet, OAuthSigningKey};
use crate::lexicon::{
    OAuthLexiconScopeResolution, OAuthScopeDescription, OAuthScopeResolutionStage,
};
use crate::oauth::config::OAuthAuthorizationServerConfiguration;
use crate::oauth::interface::{
    DefaultOAuthHtmlRenderer, OAuthAccountAuthenticateRequest, OAuthAccountAuthenticating,
    OAuthAuthorizationPageRequest, OAuthConsentAction, OAuthInterfaceRendering,
};
use crate::oauth::metadata::{OAuthAuthorizationServerMetadata, OAuthProtectedResourceMetadata};
use crate::oauth::tokens::{MintTokenPairInput, OAuthTokenMinter};
use crate::oauth::verifier::{OAuthResourceServerVerifier, OAuthResourceVerificationMode};
use crate::store::{
    ConsumeAuthorizationCodeParams, OAuthAccessTokenMinting, OAuthAuthorizationCode,
    OAuthBrowserFlowRecord, OAuthCodeConsumeResult, OAuthMintedAccessToken,
    OAuthPushedAuthorizationRequest, OAuthRefreshRotationResult, OAuthResponseMode,
    OAuthServerStores, OAuthSession, ReplayStoreDpopChecker, RotateRefreshTokenParams,
};
use crate::support::{
    ConstantTime, DigestPurpose, OAuthClock, OAuthKeyedDigest, OAuthPkce, OAuthRandomSource,
    SystemOAuthClock, SystemOAuthRandomSource,
};

const CSRF_COOKIE_NAME_INSECURE: &str = "__petrel_oauth_csrf";
const CSRF_COOKIE_NAME_SECURE: &str = "__Host-petrel_oauth_csrf";

struct ArcClock(Arc<dyn OAuthClock>);
impl OAuthClock for ArcClock {
    fn now_secs(&self) -> i64 {
        self.0.now_secs()
    }
    fn now_unix_f64(&self) -> f64 {
        self.0.now_unix_f64()
    }
}

struct RotationJwtMinter<'a> {
    minter: OAuthTokenMinter<'a>,
    dpop_jkt: &'a str,
    now_secs: i64,
    access_ttl_secs: i64,
}

impl OAuthAccessTokenMinting for RotationJwtMinter<'_> {
    fn mint_access_token_for_rotation(
        &self,
        session: &OAuthSession,
    ) -> Result<OAuthMintedAccessToken, OAuthServerError> {
        let session_end = session
            .hard_expires_at_secs
            .map_or(session.expires_at_secs, |hard| {
                session.expires_at_secs.min(hard)
            });
        let effective_ttl_secs = self
            .access_ttl_secs
            .min(session_end.saturating_sub(self.now_secs).max(0));
        let pair = self.minter.mint(&MintTokenPairInput {
            session_id: &session.session_id,
            client_id: &session.client_id,
            scope: &session.scope,
            dpop_jkt: self.dpop_jkt,
            binding: &session.binding,
            now_secs: self.now_secs,
            access_ttl_secs: effective_ttl_secs,
            generation: session.refresh_token_generation,
        })?;
        Ok(OAuthMintedAccessToken {
            token: pair.access_token,
            digest: pair.digests.access_token_digest,
        })
    }
}

/// Complete AT Protocol OAuth 2.1 Authorization Server HTTP request handler.
pub struct OAuthAuthorizationServer {
    config: OAuthAuthorizationServerConfiguration,
    signing_key: OAuthSigningKey,
    keyed_digest: OAuthKeyedDigest,
    nonce_service: OAuthDpopNonceService,
    dpop_validator: OAuthDpopProofValidator,
    replay_checker: Arc<dyn OAuthDpopReplayChecker>,
    stores: OAuthServerStores,
    accounts: Arc<dyn OAuthAccountAuthenticating>,
    clients: Arc<dyn OAuthClientResolving>,
    assertion_validator: OAuthClientAssertionValidator,
    scope_resolver: Option<Arc<dyn OAuthLexiconScopeResolution>>,
    renderer: Arc<dyn OAuthInterfaceRendering>,
    clock: Arc<dyn OAuthClock>,
    random: Arc<dyn OAuthRandomSource>,
    last_purge_secs: AtomicI64,
}

impl std::fmt::Debug for OAuthAuthorizationServer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OAuthAuthorizationServer")
            .field("issuer", &self.config.issuer)
            .field("access_token_format", &self.config.access_token_format)
            .finish_non_exhaustive()
    }
}

#[derive(Serialize)]
struct OAuthErrorBody<'a> {
    error: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    error_description: Option<&'a str>,
}

#[derive(Serialize)]
struct ParResponseBody<'a> {
    request_uri: &'a str,
    expires_in: i64,
}

#[derive(Serialize)]
struct TokenResponseBody {
    access_token: String,
    token_type: &'static str,
    expires_in: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    refresh_token: Option<String>,
    scope: String,
    sub: String,
}

impl OAuthAuthorizationServer {
    /// Static route table exposed by this server.
    pub const ROUTES: &'static [OAuthRoute] = &[
        OAuthRoute {
            method: "GET",
            path: "/.well-known/oauth-authorization-server",
        },
        OAuthRoute {
            method: "GET",
            path: "/.well-known/oauth-protected-resource",
        },
        OAuthRoute {
            method: "GET",
            path: "/oauth/jwks",
        },
        OAuthRoute {
            method: "POST",
            path: "/oauth/par",
        },
        OAuthRoute {
            method: "GET",
            path: "/oauth/authorize",
        },
        OAuthRoute {
            method: "POST",
            path: "/oauth/authorize",
        },
        OAuthRoute {
            method: "POST",
            path: "/oauth/token",
        },
        OAuthRoute {
            method: "POST",
            path: "/oauth/revoke",
        },
    ];

    /// Constructs a validated OAuth 2.1 authorization server instance.
    pub fn new(
        config: OAuthAuthorizationServerConfiguration,
        stores: OAuthServerStores,
        accounts: Arc<dyn OAuthAccountAuthenticating>,
        clients: Arc<dyn OAuthClientResolving>,
    ) -> Result<Self, OAuthServerError> {
        Self::with_dependencies(
            config,
            stores,
            accounts,
            clients,
            None,
            Arc::new(DefaultOAuthHtmlRenderer),
            Arc::new(SystemOAuthClock),
            Arc::new(SystemOAuthRandomSource),
        )
    }

    /// Constructs an authorization server with optional lexicon scope resolver, custom HTML renderer, clock, and RNG.
    #[allow(clippy::too_many_arguments)]
    pub fn with_dependencies(
        config: OAuthAuthorizationServerConfiguration,
        stores: OAuthServerStores,
        accounts: Arc<dyn OAuthAccountAuthenticating>,
        clients: Arc<dyn OAuthClientResolving>,
        scope_resolver: Option<Arc<dyn OAuthLexiconScopeResolution>>,
        renderer: Arc<dyn OAuthInterfaceRendering>,
        clock: Arc<dyn OAuthClock>,
        random: Arc<dyn OAuthRandomSource>,
    ) -> Result<Self, OAuthServerError> {
        let signing_key = config.validate()?;
        let keyed_digest = OAuthKeyedDigest::new(config.server_secret.as_slice())?;
        let nonce_service = OAuthDpopNonceService::new(
            config.server_secret.as_slice(),
            config.dpop_nonce_rotation_interval_secs,
            config.dpop_nonce_accepted_previous_buckets,
        )?;
        let dpop_validator =
            OAuthDpopProofValidator::new(nonce_service.clone(), keyed_digest.clone())
                .with_clock(ArcClock(clock.clone()));
        #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
        let replay_checker = Arc::new(ReplayStoreDpopChecker::new(
            stores.replay.clone(),
            clock.clone(),
        ));
        let assertion_validator = OAuthClientAssertionValidator::new(
            config.issuer.clone(),
            keyed_digest.clone(),
            stores.replay.clone(),
            clock.clone(),
        );
        Ok(Self {
            config,
            signing_key,
            keyed_digest,
            nonce_service,
            dpop_validator,
            replay_checker,
            stores,
            accounts,
            clients,
            assertion_validator,
            scope_resolver,
            renderer,
            clock,
            random,
            last_purge_secs: AtomicI64::new(i64::MIN),
        })
    }

    /// Server configuration reference.
    pub const fn config(&self) -> &OAuthAuthorizationServerConfiguration {
        &self.config
    }

    /// Public JWKS containing the active JWT signing key and any retiring keys.
    pub fn jwks(&self) -> Result<OAuthJsonWebKeySet, OAuthServerError> {
        let mut keys = vec![self.signing_key.public_jwk(true)?];
        keys.extend(self.config.retiring_access_token_keys.iter().cloned());
        Ok(OAuthJsonWebKeySet::new(keys))
    }

    /// Authorization Server Metadata document (`/.well-known/oauth-authorization-server`).
    pub fn authorization_server_metadata(&self) -> OAuthAuthorizationServerMetadata {
        OAuthAuthorizationServerMetadata::from_config(&self.config)
    }

    fn issuer_base_path(&self) -> String {
        url::Url::parse(&self.config.issuer)
            .map(|u| u.path().trim_end_matches('/').to_owned())
            .unwrap_or_default()
    }

    fn csrf_cookie_name(&self) -> &'static str {
        if self.config.issuer.starts_with("https://") {
            CSRF_COOKIE_NAME_SECURE
        } else {
            CSRF_COOKIE_NAME_INSECURE
        }
    }

    fn authorize_cookie_path(&self) -> String {
        if self.config.issuer.starts_with("https://") {
            // `__Host-` cookies require `Path=/` per RFC 6265bis and cover both root and path-prefixed issuers.
            "/".to_owned()
        } else {
            let base = self.issuer_base_path();
            format!("{base}/oauth/authorize")
        }
    }

    fn normalize_request_path<'a>(&self, path: &'a str) -> &'a str {
        let base = self.issuer_base_path();
        if base.is_empty() {
            return path;
        }
        if path.strip_prefix("/.well-known/oauth-authorization-server") == Some(base.as_str()) {
            return "/.well-known/oauth-authorization-server";
        }
        if path.strip_prefix("/.well-known/oauth-protected-resource") == Some(base.as_str()) {
            return "/.well-known/oauth-protected-resource";
        }
        if let Some(rest) = path.strip_prefix(base.as_str()) {
            if rest.is_empty() {
                return "/";
            }
            if rest.starts_with('/') {
                return rest;
            }
        }
        path
    }

    /// Protected Resource Metadata document (`/.well-known/oauth-protected-resource`).
    pub fn protected_resource_metadata(&self) -> OAuthProtectedResourceMetadata {
        OAuthProtectedResourceMetadata::for_resource(
            self.config.issuer.clone(),
            vec![self.config.issuer.clone()],
            self.config.scopes_supported.clone(),
        )
    }

    /// Builds a paired [`OAuthResourceServerVerifier`] sharing this server's token store, nonces, and replay store.
    pub fn resource_verifier(&self) -> OAuthResourceServerVerifier {
        let mut verifier = OAuthResourceServerVerifier::new(
            OAuthResourceVerificationMode::Shared {
                token_store: self.stores.tokens.clone(),
                keyed_digest: self.keyed_digest.clone(),
            },
            self.nonce_service.clone(),
            self.keyed_digest.clone(),
            self.stores.replay.clone(),
            self.clock.clone(),
        );
        if let Some(ref resolver) = self.scope_resolver {
            verifier = verifier.with_scope_resolver(resolver.clone());
        }
        verifier
    }

    /// Runs an explicit expired-state purge and advances the opportunistic purge watermark.
    pub async fn purge_expired(&self) -> Result<usize, OAuthServerError> {
        let Some(ref purger) = self.stores.purging else {
            return Ok(0);
        };
        let now = self.clock.now_secs();
        self.last_purge_secs.store(now, Ordering::Release);
        purger.purge_expired(now).await
    }

    async fn maybe_purge_expired(&self) {
        let Some(ref purger) = self.stores.purging else {
            return;
        };
        let Some(interval) = self.config.purge_interval_secs else {
            return;
        };
        let now = self.clock.now_secs();
        let should_purge = if interval <= 0 {
            self.last_purge_secs.store(now, Ordering::Release);
            true
        } else {
            loop {
                let last = self.last_purge_secs.load(Ordering::Acquire);
                let due = last == i64::MIN || now < last || now.saturating_sub(last) >= interval;
                if !due {
                    break false;
                }
                if self
                    .last_purge_secs
                    .compare_exchange_weak(last, now, Ordering::AcqRel, Ordering::Acquire)
                    .is_ok()
                {
                    break true;
                }
            }
        };
        if should_purge {
            let _ = purger.purge_expired(now).await;
        }
    }

    /// Dispatches one framework-agnostic HTTP request to the matching OAuth 2.1 endpoint.
    pub async fn handle(&self, request: OAuthHttpRequest) -> OAuthHttpResponse {
        let normalized_path = self.normalize_request_path(&request.path).to_owned();
        let path = normalized_path.as_str();
        let method = request.method.as_str();
        match (method, path) {
            (
                "OPTIONS",
                "/.well-known/oauth-authorization-server"
                | "/.well-known/oauth-protected-resource"
                | "/oauth/jwks"
                | "/oauth/par"
                | "/oauth/token"
                | "/oauth/revoke",
            ) => Self::cors_preflight(),
            ("GET", "/.well-known/oauth-authorization-server") => {
                self.json_ok(200, &self.authorization_server_metadata(), false)
            }
            ("GET", "/.well-known/oauth-protected-resource") => {
                self.json_ok(200, &self.protected_resource_metadata(), false)
            }
            ("GET", "/oauth/jwks") => match self.jwks() {
                Ok(jwks) => self.json_ok(200, &jwks, false),
                Err(_) => self.json_error(500, "server_error", Some("internal server error"), None),
            },
            ("POST", "/oauth/par") => {
                self.maybe_purge_expired().await;
                self.handle_par(&request).await
            }
            ("GET", "/oauth/authorize") => {
                self.maybe_purge_expired().await;
                self.handle_authorize_get(&request).await
            }
            ("POST", "/oauth/authorize") => {
                self.maybe_purge_expired().await;
                self.handle_authorize_post(&request).await
            }
            ("POST", "/oauth/token") => {
                self.maybe_purge_expired().await;
                self.handle_token(&request).await
            }
            ("POST", "/oauth/revoke") => {
                self.maybe_purge_expired().await;
                self.handle_revoke(&request).await
            }
            ("GET" | "POST", _) => self.json_error(404, "not_found", Some("unknown route"), None),
            (
                _,
                "/oauth/par" | "/oauth/token" | "/oauth/revoke" | "/oauth/authorize"
                | "/oauth/jwks",
            ) => self.json_error(405, "invalid_request", Some("method not allowed"), None),
            _ => self.json_error(404, "not_found", Some("unknown route"), None),
        }
    }

    async fn handle_par(&self, req: &OAuthHttpRequest) -> OAuthHttpResponse {
        let form = match self.parse_validated_form(req) {
            Ok(f) => f,
            Err(resp) => return resp,
        };
        let creds = match ClientAuthCredentials::from_form(&form) {
            Ok(c) => c,
            Err(err) => {
                return self.json_error(400, "invalid_request", Some(&err_msg(&err)), None);
            }
        };
        // Validate DPoP proof & nonce before remote client metadata resolution to block unauthenticated fetch amplification.
        let target_url = format!("{}/oauth/par", self.config.issuer);
        let dpop = match self
            .validate_dpop_for_endpoint(
                &req.headers,
                &target_url,
                self.config.require_dpop_nonce_on_par,
            )
            .await
        {
            Ok(p) => p,
            Err(resp) => return resp,
        };
        let resolved_client = match self.clients.resolve(creds.client_id).await {
            Ok(c) => c,
            Err(err) => return self.map_client_or_server_error(err, None),
        };
        if let Err(err) = self
            .assertion_validator
            .authenticate_with_dpop(&resolved_client, &creds, Some(&dpop.jkt))
            .await
        {
            return self.json_error(401, "invalid_client", Some(&err_msg(&err)), None);
        }

        let response_mode =
            match self.validate_par_parameters(&form, &resolved_client.metadata, &dpop.jkt) {
                Ok(mode) => mode,
                Err(resp) => return resp,
            };
        let raw_scope = form
            .get("scope")
            .map(String::as_str)
            .filter(|s| !s.trim().is_empty())
            .unwrap_or("");
        let admitted_scope = match self.admit_scope(raw_scope, &resolved_client.metadata).await {
            Ok(s) => s,
            Err((code, desc)) => return self.json_error(400, code, Some(&desc), None),
        };

        let now = self.clock.now_secs();
        let request_uri = format!(
            "urn:ietf:params:oauth:request_uri:req_{}",
            self.random.opaque_value()
        );
        let record = OAuthPushedAuthorizationRequest {
            request_uri_digest: self
                .keyed_digest
                .digest_str(&request_uri, DigestPurpose::RequestUri),
            client_id: resolved_client.metadata.client_id,
            redirect_uri: form["redirect_uri"].clone(),
            scope: admitted_scope,
            code_challenge: form["code_challenge"].clone(),
            state: form.get("state").cloned(),
            response_mode,
            dpop_jkt: Some(dpop.jkt),
            login_hint: form.get("login_hint").cloned(),
            created_at_secs: now,
            expires_at_secs: now + self.config.pushed_request_ttl_secs,
        };
        if self
            .stores
            .requests
            .store_pushed_request(record)
            .await
            .is_err()
        {
            return self.json_error(
                503,
                "temporarily_unavailable",
                Some("authorization service temporarily unavailable"),
                None,
            );
        }

        let body = ParResponseBody {
            request_uri: &request_uri,
            expires_in: self.config.pushed_request_ttl_secs,
        };
        self.json_ok(201, &body, true)
    }

    fn parse_validated_form(
        &self,
        req: &OAuthHttpRequest,
    ) -> Result<HashMap<String, String>, OAuthHttpResponse> {
        if !OAuthForm::is_form_content_type(&req.headers) {
            return Err(self.json_error(
                400,
                "invalid_request",
                Some("Content-Type must be application/x-www-form-urlencoded"),
                None,
            ));
        }
        OAuthForm::parse(&req.body, self.config.max_form_body_bytes).map_err(|err| {
            let oauth_err = OAuthServerError::from(err);
            self.json_error(400, "invalid_request", Some(&err_msg(&oauth_err)), None)
        })
    }

    async fn validate_dpop_for_endpoint(
        &self,
        headers: &OAuthHttpHeaders,
        target_url: &str,
        require_nonce: bool,
    ) -> Result<crate::dpop::OAuthValidatedDpopProof, OAuthHttpResponse> {
        let ctx = DpopValidationContext {
            method: "POST",
            url: target_url,
            expected_access_token: None,
            expected_jkt: None,
            require_nonce,
        };
        self.dpop_validator
            .validate_headers(headers, ctx, self.replay_checker.as_ref())
            .await
            .map_err(|err| match err {
                OAuthDpopError::UseDpopNonce { next_nonce } => self.json_error(
                    400,
                    "use_dpop_nonce",
                    Some("Authorization server requires DPoP nonce"),
                    Some(next_nonce),
                ),
                OAuthDpopError::InvalidDpopProof(msg) => {
                    self.json_error(400, "invalid_dpop_proof", Some(&msg), None)
                }
            })
    }

    fn validate_par_parameters(
        &self,
        form: &HashMap<String, String>,
        metadata: &crate::clients::OAuthClientMetadata,
        dpop_jkt: &str,
    ) -> Result<OAuthResponseMode, OAuthHttpResponse> {
        if form.get("response_type").map(String::as_str) != Some("code") {
            return Err(self.json_error(
                400,
                "unsupported_response_type",
                Some("response_type must be code"),
                None,
            ));
        }
        let Some(redirect_uri) = form.get("redirect_uri") else {
            return Err(self.json_error(
                400,
                "invalid_request",
                Some("redirect_uri is required"),
                None,
            ));
        };
        if !metadata.redirect_uris.contains(redirect_uri) {
            return Err(self.json_error(
                400,
                "invalid_request",
                Some("redirect_uri does not match client metadata"),
                None,
            ));
        }
        if form.get("code_challenge_method").map(String::as_str) != Some("S256") {
            return Err(self.json_error(
                400,
                "invalid_request",
                Some("code_challenge_method must be S256"),
                None,
            ));
        }
        let Some(code_challenge) = form.get("code_challenge") else {
            return Err(self.json_error(
                400,
                "invalid_request",
                Some("code_challenge is required"),
                None,
            ));
        };
        if !OAuthPkce::is_valid_s256_challenge(code_challenge) {
            return Err(self.json_error(
                400,
                "invalid_request",
                Some("code_challenge is invalid"),
                None,
            ));
        }
        if let Some(dpop_jkt_param) = form.get("dpop_jkt")
            && !ConstantTime::equal(dpop_jkt_param, dpop_jkt)
        {
            return Err(self.json_error(
                400,
                "invalid_dpop_proof",
                Some("DPoP proof key does not match dpop_jkt parameter"),
                None,
            ));
        }
        match form.get("response_mode") {
            Some(mode) => OAuthResponseMode::parse(mode).map_err(|_| {
                self.json_error(
                    400,
                    "invalid_request",
                    Some("unsupported response_mode"),
                    None,
                )
            }),
            None => Ok(OAuthResponseMode::Query),
        }
    }

    async fn handle_authorize_get(&self, req: &OAuthHttpRequest) -> OAuthHttpResponse {
        let params = match OAuthForm::parse_query(req.query.as_deref(), 8192) {
            Ok(p) => p,
            Err(err) => {
                let oauth_err = OAuthServerError::from(err);
                return Self::html_error(400, &err_msg(&oauth_err));
            }
        };
        let Some(client_id) = params.get("client_id").filter(|s| !s.is_empty()) else {
            return Self::html_error(400, "missing client_id");
        };
        let Some(request_uri) = params.get("request_uri").filter(|s| !s.is_empty()) else {
            return Self::html_error(400, "request_uri is required (PAR)");
        };
        let now = self.clock.now_secs();
        let digest = self
            .keyed_digest
            .digest_str(request_uri, DigestPurpose::RequestUri);
        let par = match self
            .stores
            .requests
            .consume_pushed_request(&digest, now)
            .await
        {
            Ok(Some(rec)) => rec,
            Ok(None) => return Self::html_error(400, "invalid or expired request_uri"),
            Err(_) => {
                return Self::html_error(503, "authorization service temporarily unavailable");
            }
        };
        if !ConstantTime::equal(&par.client_id, client_id) {
            return Self::html_error(400, "client_id does not match request_uri");
        }
        let resolved_client = match self.clients.resolve(&par.client_id).await {
            Ok(c) => c,
            Err(err) => return Self::html_error(400, &err_msg(&err)),
        };

        let flow_id = format!("flow_{}", self.random.opaque_value());
        let csrf_token = self.random.opaque_value();
        let flow = OAuthBrowserFlowRecord {
            flow_id_digest: self
                .keyed_digest
                .digest_str(&flow_id, DigestPurpose::BrowserFlow),
            csrf_token_digest: self
                .keyed_digest
                .digest_str(&csrf_token, DigestPurpose::BrowserFlow),
            client_id: par.client_id.clone(),
            redirect_uri: par.redirect_uri.clone(),
            scope: par.scope.clone(),
            code_challenge: par.code_challenge,
            state: par.state,
            response_mode: par.response_mode,
            dpop_jkt: par.dpop_jkt,
            login_hint: par.login_hint.clone(),
            expires_at_secs: now + self.config.browser_flow_ttl_secs,
        };
        if self
            .stores
            .browser_flows
            .store_browser_flow(flow)
            .await
            .is_err()
        {
            return Self::html_error(503, "authorization service temporarily unavailable");
        }

        let langs = parse_accept_language(req.headers.get("Accept-Language"));
        let lang_refs: Vec<&str> = langs.iter().map(String::as_str).collect();
        let scope_descriptions = self
            .describe_scopes(&par.scope, &resolved_client.metadata, &lang_refs)
            .await;

        let issuer_base = self.config.issuer.trim_end_matches('/');
        let page_req = OAuthAuthorizationPageRequest {
            flow_id,
            csrf_token: csrf_token.clone(),
            action_url: format!("{issuer_base}/oauth/authorize"),
            client: resolved_client,
            redirect_uri: par.redirect_uri,
            requested_scope: par.scope,
            scope_descriptions,
            login_hint: par.login_hint,
        };
        let Ok(mut resp) = self.renderer.render_authorization_page(page_req).await else {
            return Self::html_error(500, "internal server error");
        };
        let secure_flag = if self.config.issuer.starts_with("https://") {
            "; Secure"
        } else {
            ""
        };
        let cookie_name = self.csrf_cookie_name();
        let cookie_path = self.authorize_cookie_path();
        resp.headers.add(
            "Set-Cookie",
            format!("{cookie_name}={csrf_token}; HttpOnly; SameSite=Lax; Path={cookie_path}{secure_flag}"),
        );
        resp
    }

    async fn handle_authorize_post(&self, req: &OAuthHttpRequest) -> OAuthHttpResponse {
        let now = self.clock.now_secs();
        let (form, flow) = match self.consume_authorize_consent_submission(req, now).await {
            Ok(pair) => pair,
            Err(resp) => return resp,
        };

        let action = match form.get("decision").map(String::as_str) {
            Some("deny") => OAuthConsentAction::Deny,
            _ => OAuthConsentAction::Approve,
        };
        if action == OAuthConsentAction::Deny {
            return self.authorization_error_redirect(
                &flow.redirect_uri,
                flow.response_mode,
                flow.state.as_deref(),
                "access_denied",
                Some("user denied the authorization request"),
            );
        }

        let auth_req = OAuthAccountAuthenticateRequest {
            client_id: flow.client_id.clone(),
            scope: flow.scope.clone(),
            login_hint: flow.login_hint.clone(),
            form_fields: form,
        };
        let authenticated = match self.accounts.authenticate(auth_req).await {
            Ok(Some(acct)) => acct,
            Ok(None) => {
                return Self::html_error(401, "invalid account credentials");
            }
            Err(_) => {
                return Self::html_error(500, "internal server error");
            }
        };

        let code = format!("code_{}", self.random.opaque_value());
        let code_digest = self
            .keyed_digest
            .digest_str(&code, DigestPurpose::AuthorizationCode);
        let session_id = self.random.uuid_v4().to_string();
        let record = OAuthAuthorizationCode {
            code_digest,
            client_id: flow.client_id,
            redirect_uri: flow.redirect_uri.clone(),
            scope: flow.scope,
            code_challenge: flow.code_challenge,
            dpop_jkt: flow.dpop_jkt,
            binding: authenticated.binding,
            session_id,
            created_at_secs: now,
            expires_at_secs: now + self.config.authorization_code_ttl_secs,
        };
        if self
            .stores
            .codes
            .store_authorization_code(record)
            .await
            .is_err()
        {
            return Self::html_error(503, "authorization service temporarily unavailable");
        }

        self.authorization_success_redirect(
            &flow.redirect_uri,
            flow.response_mode,
            &code,
            flow.state.as_deref(),
        )
    }

    async fn handle_token(&self, req: &OAuthHttpRequest) -> OAuthHttpResponse {
        if !OAuthForm::is_form_content_type(&req.headers) {
            return self.json_error(
                400,
                "invalid_request",
                Some("Content-Type must be application/x-www-form-urlencoded"),
                None,
            );
        }
        let form = match OAuthForm::parse(&req.body, self.config.max_form_body_bytes) {
            Ok(f) => f,
            Err(err) => {
                let oauth_err = OAuthServerError::from(err);
                return self.json_error(400, "invalid_request", Some(&err_msg(&oauth_err)), None);
            }
        };

        let creds = match ClientAuthCredentials::from_form(&form) {
            Ok(c) => c,
            Err(err) => {
                return self.json_error(400, "invalid_request", Some(&err_msg(&err)), None);
            }
        };
        let Some(grant_type) = form.get("grant_type").map(String::as_str) else {
            return self.json_error(400, "invalid_request", Some("grant_type is required"), None);
        };
        if !matches!(grant_type, "authorization_code" | "refresh_token") {
            return self.json_error(
                400,
                "unsupported_grant_type",
                Some("unsupported grant_type"),
                None,
            );
        }
        // DPoP first, matching Swift `OAuthAuthorizationServer+Token.swift` and preventing fetch/assertion burn on nonce challenges.
        let target_url = format!("{}/oauth/token", self.config.issuer);
        let ctx = DpopValidationContext {
            method: "POST",
            url: &target_url,
            expected_access_token: None,
            expected_jkt: None,
            require_nonce: self.config.require_dpop_nonce_on_token,
        };
        let dpop = match self
            .dpop_validator
            .validate_headers(&req.headers, ctx, self.replay_checker.as_ref())
            .await
        {
            Ok(p) => p,
            Err(OAuthDpopError::UseDpopNonce { next_nonce }) => {
                return self.json_error(
                    400,
                    "use_dpop_nonce",
                    Some("Authorization server requires DPoP nonce"),
                    Some(next_nonce),
                );
            }
            Err(OAuthDpopError::InvalidDpopProof(msg)) => {
                return self.json_error(400, "invalid_dpop_proof", Some(&msg), None);
            }
        };
        let resolved_client = match self.clients.resolve(creds.client_id).await {
            Ok(c) => c,
            Err(err) => return self.map_client_or_server_error(err, None),
        };
        if let Err(err) = self
            .assertion_validator
            .authenticate_with_dpop(&resolved_client, &creds, Some(&dpop.jkt))
            .await
        {
            return self.json_error(401, "invalid_client", Some(&err_msg(&err)), None);
        }

        self.dispatch_token_grant(&form, &resolved_client, &dpop.jkt)
            .await
    }

    async fn dispatch_token_grant(
        &self,
        form: &HashMap<String, String>,
        resolved_client: &crate::clients::OAuthResolvedClientMetadata,
        dpop_jkt: &str,
    ) -> OAuthHttpResponse {
        let Some(grant_type) = form.get("grant_type").map(String::as_str) else {
            return self.json_error(400, "invalid_request", Some("grant_type is required"), None);
        };
        let grants = &resolved_client.metadata.grant_types;
        let is_confidential = resolved_client.metadata.is_confidential();
        match grant_type {
            "authorization_code" => {
                if !grants.iter().any(|g| g == "authorization_code") {
                    return self.json_error(
                        400,
                        "unauthorized_client",
                        Some("the client did not declare the authorization_code grant"),
                        None,
                    );
                }
                let allow_refresh = grants.iter().any(|g| g == "refresh_token");
                self.handle_authorization_code_grant(
                    form,
                    &resolved_client.metadata.client_id,
                    dpop_jkt,
                    allow_refresh,
                    is_confidential,
                )
                .await
            }
            "refresh_token" => {
                if !grants.iter().any(|g| g == "refresh_token") {
                    return self.json_error(
                        400,
                        "unauthorized_client",
                        Some("the client did not declare the refresh_token grant"),
                        None,
                    );
                }
                self.handle_refresh_token_grant(
                    form,
                    &resolved_client.metadata.client_id,
                    dpop_jkt,
                    is_confidential,
                )
                .await
            }
            _ => self.json_error(
                400,
                "unsupported_grant_type",
                Some("unsupported grant_type"),
                None,
            ),
        }
    }

    async fn consume_authorize_consent_submission(
        &self,
        req: &OAuthHttpRequest,
        now: i64,
    ) -> Result<(HashMap<String, String>, OAuthBrowserFlowRecord), OAuthHttpResponse> {
        if !OAuthForm::is_form_content_type(&req.headers) {
            return Err(Self::html_error(
                400,
                "Content-Type must be application/x-www-form-urlencoded",
            ));
        }
        let form = OAuthForm::parse(&req.body, self.config.max_form_body_bytes).map_err(|err| {
            let oauth_err = OAuthServerError::from(err);
            Self::html_error(400, &err_msg(&oauth_err))
        })?;
        let Some(flow_id) = form.get("flow_id") else {
            return Err(Self::html_error(400, "missing flow_id"));
        };
        let Some(form_csrf) = form.get("csrf_token") else {
            return Err(Self::html_error(403, "missing csrf_token"));
        };
        let cookie_name = self.csrf_cookie_name();
        let Some(cookie_csrf) = extract_cookie(&req.headers, cookie_name) else {
            return Err(Self::html_error(403, "missing CSRF cookie"));
        };
        if !ConstantTime::equal(cookie_csrf, form_csrf) {
            return Err(Self::html_error(403, "CSRF token mismatch"));
        }
        let flow_digest = self
            .keyed_digest
            .digest_str(flow_id, DigestPurpose::BrowserFlow);
        let flow = match self
            .stores
            .browser_flows
            .consume_browser_flow(&flow_digest, now)
            .await
        {
            Ok(Some(rec)) => rec,
            Ok(None) => {
                return Err(Self::html_error(
                    400,
                    "invalid or expired authorization flow",
                ));
            }
            Err(_) => {
                return Err(Self::html_error(
                    503,
                    "authorization service temporarily unavailable",
                ));
            }
        };
        let presented_csrf_digest = self
            .keyed_digest
            .digest_str(form_csrf, DigestPurpose::BrowserFlow);
        if !ConstantTime::equal_bytes(&flow.csrf_token_digest, &presented_csrf_digest) {
            return Err(Self::html_error(403, "CSRF digest mismatch"));
        }
        Ok((form, flow))
    }

    async fn handle_authorization_code_grant(
        &self,
        form: &HashMap<String, String>,
        client_id: &str,
        dpop_jkt: &str,
        allow_refresh: bool,
        is_confidential: bool,
    ) -> OAuthHttpResponse {
        let Some(code) = form.get("code").filter(|s| !s.is_empty()) else {
            return self.json_error(400, "invalid_request", Some("code is required"), None);
        };
        let Some(redirect_uri) = form.get("redirect_uri").filter(|s| !s.is_empty()) else {
            return self.json_error(
                400,
                "invalid_request",
                Some("redirect_uri is required"),
                None,
            );
        };
        let Some(code_verifier) = form.get("code_verifier").filter(|s| !s.is_empty()) else {
            return self.json_error(
                400,
                "invalid_request",
                Some("code_verifier is required"),
                None,
            );
        };
        if !OAuthPkce::is_valid_verifier(code_verifier) {
            return self.json_error(
                400,
                "invalid_grant",
                Some("invalid code_verifier syntax"),
                None,
            );
        }

        let now = self.clock.now_secs();
        let code_digest = self
            .keyed_digest
            .digest_str(code, DigestPurpose::AuthorizationCode);
        let record = match self
            .stores
            .codes
            .consume_authorization_code(ConsumeAuthorizationCodeParams {
                code_digest: &code_digest,
                client_id,
                redirect_uri,
                dpop_jkt,
                code_verifier,
                now_secs: now,
            })
            .await
        {
            Ok(OAuthCodeConsumeResult::Consumed(rec)) => *rec,
            Ok(OAuthCodeConsumeResult::Replayed) => {
                return self.json_error(
                    400,
                    "invalid_grant",
                    Some("authorization code was already used; the session has been revoked"),
                    None,
                );
            }
            Ok(OAuthCodeConsumeResult::BindingMismatch | OAuthCodeConsumeResult::NotFound) => {
                return self.json_error(
                    400,
                    "invalid_grant",
                    Some("invalid or expired authorization code"),
                    None,
                );
            }
            Err(_) => {
                return self.json_error(
                    503,
                    "temporarily_unavailable",
                    Some("authorization service temporarily unavailable"),
                    None,
                );
            }
        };

        self.issue_session_for_code_grant(
            record,
            client_id,
            dpop_jkt,
            now,
            allow_refresh,
            is_confidential,
        )
        .await
    }

    async fn issue_session_for_code_grant(
        &self,
        record: OAuthAuthorizationCode,
        client_id: &str,
        dpop_jkt: &str,
        now: i64,
        allow_refresh: bool,
        is_confidential: bool,
    ) -> OAuthHttpResponse {
        let (hard_expires_at_secs, expires_at_secs) = if !allow_refresh {
            let end = now + self.config.access_token_ttl_secs;
            (Some(end), end)
        } else if is_confidential {
            let hard = self
                .config
                .confidential_client_session_lifetime_secs
                .map(|ttl| now + ttl);
            let sliding = now + self.config.refresh_token_ttl_secs;
            (hard, hard.map_or(sliding, |h| sliding.min(h)))
        } else {
            let hard = now + self.config.public_client_session_lifetime_secs;
            let sliding = now + self.config.public_client_refresh_ttl_secs;
            (Some(hard), sliding.min(hard))
        };
        let effective_access_ttl_secs = self
            .config
            .access_token_ttl_secs
            .min(expires_at_secs.saturating_sub(now).max(0));

        let token_minter = self.token_minter();
        let Ok(issued) = token_minter.mint(&MintTokenPairInput {
            session_id: &record.session_id,
            client_id,
            scope: &record.scope,
            dpop_jkt,
            binding: &record.binding,
            now_secs: now,
            access_ttl_secs: effective_access_ttl_secs,
            generation: 0,
        }) else {
            return self.json_error(500, "server_error", Some("internal server error"), None);
        };

        let session = OAuthSession {
            session_id: record.session_id,
            client_id: client_id.to_owned(),
            scope: record.scope.clone(),
            dpop_jkt: Some(dpop_jkt.to_owned()),
            binding: record.binding.clone(),
            access_token_digest: issued.digests.access_token_digest,
            refresh_token_digest: allow_refresh.then_some(issued.digests.refresh_token_digest),
            previous_refresh_token_digest: None,
            refresh_token_generation: 0,
            access_token_expires_at_secs: now + effective_access_ttl_secs,
            created_at_secs: now,
            expires_at_secs,
            hard_expires_at_secs,
            revoked_at_secs: None,
        };
        match self.stores.tokens.store_session(session).await {
            Ok(()) => {}
            Err(OAuthServerError::Unauthorized(_)) => {
                return self.json_error(
                    400,
                    "invalid_grant",
                    Some("authorization code was already used; the session has been revoked"),
                    None,
                );
            }
            Err(_) => {
                return self.json_error(
                    503,
                    "temporarily_unavailable",
                    Some("authorization service temporarily unavailable"),
                    None,
                );
            }
        }

        let body = TokenResponseBody {
            access_token: issued.access_token,
            token_type: "DPoP",
            expires_in: effective_access_ttl_secs,
            refresh_token: allow_refresh.then_some(issued.refresh_token),
            scope: record.scope,
            sub: record.binding.did().to_owned(),
        };
        self.json_ok(200, &body, true)
    }

    async fn handle_refresh_token_grant(
        &self,
        form: &HashMap<String, String>,
        client_id: &str,
        dpop_jkt: &str,
        is_confidential: bool,
    ) -> OAuthHttpResponse {
        let Some(refresh_token) = form.get("refresh_token").filter(|s| !s.is_empty()) else {
            return self.json_error(
                400,
                "invalid_request",
                Some("refresh_token is required"),
                None,
            );
        };
        let now = self.clock.now_secs();
        let presented_digest = self
            .keyed_digest
            .digest_str(refresh_token, DigestPurpose::RefreshToken);

        let use_jwt = matches!(
            self.config.access_token_format,
            crate::oauth::config::OAuthAccessTokenFormat::Jwt
        );
        let jwt_minter = RotationJwtMinter {
            minter: self.token_minter(),
            dpop_jkt,
            now_secs: now,
            access_ttl_secs: self.config.access_token_ttl_secs,
        };
        let next_refresh_token = format!("rt_{}", self.random.opaque_value());
        let next_access_token = format!("at_{}", self.random.opaque_value());
        let next_access_digest = jwt_minter
            .minter
            .keyed_digest
            .digest_str(&next_access_token, DigestPurpose::AccessToken);
        let next_refresh_digest = jwt_minter
            .minter
            .keyed_digest
            .digest_str(&next_refresh_token, DigestPurpose::RefreshToken);

        let refresh_ttl = if is_confidential {
            self.config.refresh_token_ttl_secs
        } else {
            self.config.public_client_refresh_ttl_secs
        };
        let Ok(result) = self
            .stores
            .tokens
            .rotate_refresh_token(RotateRefreshTokenParams {
                presented_refresh_digest: &presented_digest,
                client_id,
                dpop_jkt,
                next_access_digest,
                next_refresh_digest,
                next_access_expires_at_secs: now + self.config.access_token_ttl_secs,
                next_session_expires_at_secs: now + refresh_ttl,
                now_secs: now,
                access_token_minter: use_jwt.then_some(&jwt_minter as &dyn OAuthAccessTokenMinting),
            })
            .await
        else {
            return self.json_error(
                503,
                "temporarily_unavailable",
                Some("authorization service temporarily unavailable"),
                None,
            );
        };

        self.finalize_refresh_rotation(result, next_access_token, next_refresh_token, now)
    }

    fn finalize_refresh_rotation(
        &self,
        result: OAuthRefreshRotationResult,
        next_access_token: String,
        next_refresh_token: String,
        now: i64,
    ) -> OAuthHttpResponse {
        match result {
            OAuthRefreshRotationResult::Rotated {
                session,
                issued_access_token,
            } => {
                let final_access_token = issued_access_token.unwrap_or(next_access_token);
                let session_end = session
                    .hard_expires_at_secs
                    .map_or(session.expires_at_secs, |hard| {
                        session.expires_at_secs.min(hard)
                    });
                let effective_access_end = session.access_token_expires_at_secs.min(session_end);
                let expires_in = self
                    .config
                    .access_token_ttl_secs
                    .min(effective_access_end.saturating_sub(now).max(0));
                let body = TokenResponseBody {
                    access_token: final_access_token,
                    token_type: "DPoP",
                    expires_in,
                    refresh_token: Some(next_refresh_token),
                    scope: session.scope,
                    sub: session.binding.did().to_owned(),
                };
                self.json_ok(200, &body, true)
            }
            OAuthRefreshRotationResult::ReplayDetected => self.json_error(
                400,
                "invalid_grant",
                Some("refresh token reuse detected; session revoked"),
                None,
            ),
            OAuthRefreshRotationResult::NotFound
            | OAuthRefreshRotationResult::ClientMismatch
            | OAuthRefreshRotationResult::Revoked
            | OAuthRefreshRotationResult::Expired => self.json_error(
                400,
                "invalid_grant",
                Some("invalid, expired, or revoked refresh token"),
                None,
            ),
        }
    }

    async fn handle_revoke(&self, req: &OAuthHttpRequest) -> OAuthHttpResponse {
        if !OAuthForm::is_form_content_type(&req.headers) {
            return self.json_error(
                400,
                "invalid_request",
                Some("Content-Type must be application/x-www-form-urlencoded"),
                None,
            );
        }
        let form = match OAuthForm::parse(&req.body, self.config.max_form_body_bytes) {
            Ok(f) => f,
            Err(err) => {
                let oauth_err = OAuthServerError::from(err);
                return self.json_error(400, "invalid_request", Some(&err_msg(&oauth_err)), None);
            }
        };
        let rev_dpop_jkt = if req.headers.values("DPoP").is_empty() {
            None
        } else {
            let issuer_base = self.config.issuer.trim_end_matches('/');
            let target_url = format!("{issuer_base}/oauth/revoke");
            match self
                .validate_dpop_for_endpoint(&req.headers, &target_url, false)
                .await
            {
                Ok(p) => Some(p.jkt),
                Err(resp) => return resp,
            }
        };
        let caller_client_id = match self
            .authenticate_revoke_caller(&form, rev_dpop_jkt.as_deref())
            .await
        {
            Ok(id) => id,
            Err(resp) => return resp,
        };
        let Some(token) = form.get("token").filter(|s| !s.is_empty()) else {
            return self.json_error(400, "invalid_request", Some("token is required"), None);
        };
        let now = self.clock.now_secs();
        let lookup_order = match form.get("token_type_hint").map(String::as_str) {
            Some("refresh_token") => [DigestPurpose::RefreshToken, DigestPurpose::AccessToken],
            _ => [DigestPurpose::AccessToken, DigestPurpose::RefreshToken],
        };
        let mut matched_session = None;
        for purpose in lookup_order {
            let digest = self.keyed_digest.digest_str(token, purpose);
            match self.stores.tokens.lookup_by_token_digest(&digest).await {
                Ok(Some(session)) => {
                    matched_session = Some(session);
                    break;
                }
                Ok(None) => {}
                Err(_) => {
                    return self.json_error(
                        503,
                        "temporarily_unavailable",
                        Some("authorization service temporarily unavailable"),
                        None,
                    );
                }
            }
        }
        if let Some(session) = matched_session {
            match self
                .authorize_token_revocation(&session, caller_client_id, rev_dpop_jkt.as_deref())
                .await
            {
                Ok(true) => {
                    if self
                        .stores
                        .tokens
                        .revoke_session(&session.session_id, now)
                        .await
                        .is_err()
                    {
                        return self.json_error(
                            503,
                            "temporarily_unavailable",
                            Some("authorization service temporarily unavailable"),
                            None,
                        );
                    }
                }
                Ok(false) => {}
                Err(resp) => return resp,
            }
        }
        let mut headers = Self::cors_headers();
        headers.set("Cache-Control", "no-store");
        OAuthHttpResponse::new(200, headers, Vec::new())
    }

    async fn authenticate_revoke_caller<'a>(
        &self,
        form: &'a std::collections::HashMap<String, String>,
        rev_dpop_jkt: Option<&str>,
    ) -> Result<Option<&'a str>, OAuthHttpResponse> {
        let Some(client_id) = form.get("client_id").filter(|s| !s.is_empty()) else {
            return Ok(None);
        };
        let resolved_client = self
            .clients
            .resolve(client_id)
            .await
            .map_err(|err| self.map_client_or_server_error(err, None))?;
        if resolved_client.metadata.is_confidential() {
            let creds = ClientAuthCredentials {
                client_id: client_id.as_str(),
                client_assertion_type: form.get("client_assertion_type").map(String::as_str),
                client_assertion: form.get("client_assertion").map(String::as_str),
            };
            self.assertion_validator
                .authenticate_with_dpop(&resolved_client, &creds, rev_dpop_jkt)
                .await
                .map_err(|err| {
                    self.json_error(401, "invalid_client", Some(&err_msg(&err)), None)
                })?;
        }
        Ok(Some(client_id.as_str()))
    }

    async fn authorize_token_revocation(
        &self,
        session: &crate::store::OAuthSession,
        caller_client_id: Option<&str>,
        rev_dpop_jkt: Option<&str>,
    ) -> Result<bool, OAuthHttpResponse> {
        if let Some(cid) = caller_client_id
            && !crate::support::ConstantTime::equal(cid, &session.client_id)
        {
            // Preserve RFC 7009 / ATProto non-oracle 200 without mutating the other client's session.
            return Ok(false);
        }
        let owner_client = self
            .clients
            .resolve(&session.client_id)
            .await
            .map_err(|err| self.map_client_or_server_error(err, None))?;
        if owner_client.metadata.is_confidential() {
            if caller_client_id.is_none() {
                return Err(self.json_error(
                    401,
                    "invalid_client",
                    Some("client authentication is required to revoke this token"),
                    None,
                ));
            }
            if let Some(ref bound_jkt) = session.dpop_jkt
                && rev_dpop_jkt
                    .is_none_or(|jkt| !crate::support::ConstantTime::equal(jkt, bound_jkt))
            {
                return Err(self.json_error(
                    401,
                    "invalid_client",
                    Some("DPoP proof does not match bound session key"),
                    None,
                ));
            }
        } else if let Some(ref bound_jkt) = session.dpop_jkt
            && let Some(proof_jkt) = rev_dpop_jkt
            && !crate::support::ConstantTime::equal(proof_jkt, bound_jkt)
        {
            return Err(self.json_error(
                401,
                "invalid_dpop_proof",
                Some("DPoP proof does not match bound session key"),
                None,
            ));
        }
        Ok(true)
    }

    async fn admit_scope(
        &self,
        raw_scope: &str,
        metadata: &crate::clients::OAuthClientMetadata,
    ) -> Result<String, (&'static str, String)> {
        if raw_scope.trim().is_empty() {
            return Err(("invalid_scope", "scope is required".into()));
        }
        let requested = OAuthScopeTokenizer::tokenize(raw_scope, OAuthScopeBudget::RAW_INPUT)
            .map_err(|err| (err.oauth_error_code(), err.to_string()))?;
        let declared = metadata
            .declared_scopes()
            .map_err(|err| ("invalid_scope", err.to_string()))?;
        if let Some(ref resolver) = self.scope_resolver {
            let empty_langs: &[&str] = &[];
            let expanded = resolver
                .resolve_scopes(
                    &requested,
                    &declared,
                    self.config.unknown_scope_policy,
                    OAuthScopeResolutionStage::Admission,
                    empty_langs,
                )
                .await
                .map_err(|err| (err.oauth_error_code(), err.to_string()))?;
            Ok(expanded.wire_scope())
        } else {
            let admitted = OAuthScopeAdmissionPolicy::admit(
                &requested,
                &declared,
                self.config.unknown_scope_policy,
            )
            .map_err(|err| (err.oauth_error_code(), err.to_string()))?;
            Ok(admitted.scope_string())
        }
    }

    async fn describe_scopes(
        &self,
        scope_str: &str,
        metadata: &crate::clients::OAuthClientMetadata,
        languages: &[&str],
    ) -> Vec<OAuthScopeDescription> {
        let requested = ScopeSet::from_scope_string(scope_str);
        if let Some(ref resolver) = self.scope_resolver
            && let Ok(declared) = metadata.declared_scopes()
            && let Ok(expanded) = resolver
                .resolve_scopes(
                    &requested,
                    &declared,
                    self.config.unknown_scope_policy,
                    OAuthScopeResolutionStage::Authorization,
                    languages,
                )
                .await
        {
            return expanded.descriptions;
        }
        requested
            .raw_scopes()
            .iter()
            .map(|s| OAuthScopeDescription {
                scope: s.clone(),
                title: None,
                detail: None,
                source_nsid: None,
            })
            .collect()
    }

    fn token_minter(&self) -> OAuthTokenMinter<'_> {
        let audience = self
            .config
            .access_token_audience
            .as_deref()
            .unwrap_or(&self.config.issuer);
        OAuthTokenMinter {
            issuer: &self.config.issuer,
            audience,
            use_jwt_access_token: matches!(
                self.config.access_token_format,
                crate::oauth::config::OAuthAccessTokenFormat::Jwt
            ),
            signing_key: &self.signing_key,
            keyed_digest: &self.keyed_digest,
            random: self.random.as_ref(),
        }
    }

    fn authorization_success_redirect(
        &self,
        redirect_uri: &str,
        mode: OAuthResponseMode,
        code: &str,
        state: Option<&str>,
    ) -> OAuthHttpResponse {
        let mut pairs = vec![("code", code), ("iss", self.config.issuer.as_str())];
        if let Some(st) = state {
            pairs.push(("state", st));
        }
        Self::build_redirect(redirect_uri, mode, &pairs)
    }

    fn authorization_error_redirect(
        &self,
        redirect_uri: &str,
        mode: OAuthResponseMode,
        state: Option<&str>,
        error: &str,
        description: Option<&str>,
    ) -> OAuthHttpResponse {
        let mut pairs = vec![("error", error), ("iss", self.config.issuer.as_str())];
        if let Some(desc) = description {
            pairs.push(("error_description", desc));
        }
        if let Some(st) = state {
            pairs.push(("state", st));
        }
        Self::build_redirect(redirect_uri, mode, &pairs)
    }

    fn build_redirect(
        redirect_uri: &str,
        mode: OAuthResponseMode,
        pairs: &[(&str, &str)],
    ) -> OAuthHttpResponse {
        let encoded = pairs
            .iter()
            .map(|(k, v)| {
                format!(
                    "{}={}",
                    OAuthForm::encode_component(k),
                    OAuthForm::encode_component(v)
                )
            })
            .collect::<Vec<_>>()
            .join("&");
        let location = match mode {
            OAuthResponseMode::Query => {
                let sep = if redirect_uri.contains('?') { '&' } else { '?' };
                format!("{redirect_uri}{sep}{encoded}")
            }
            OAuthResponseMode::Fragment => format!("{redirect_uri}#{encoded}"),
        };
        let mut headers = OAuthHttpHeaders::default();
        headers.set("Location", location);
        headers.set("Cache-Control", "no-store");
        OAuthHttpResponse::new(303, headers, Vec::new())
    }

    fn cors_headers() -> OAuthHttpHeaders {
        let mut headers = OAuthHttpHeaders::default();
        headers.set("Access-Control-Allow-Origin", "*");
        headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        headers.set(
            "Access-Control-Allow-Headers",
            "Authorization, Content-Type, DPoP",
        );
        headers.set("Access-Control-Expose-Headers", "DPoP-Nonce");
        headers
    }

    fn cors_preflight() -> OAuthHttpResponse {
        let headers = Self::cors_headers();
        OAuthHttpResponse::new(204, headers, Vec::new())
    }

    fn json_ok<T: Serialize>(
        &self,
        status: u16,
        body: &T,
        include_dpop_nonce: bool,
    ) -> OAuthHttpResponse {
        let mut headers = Self::cors_headers();
        headers.set("Content-Type", "application/json");
        headers.set("Cache-Control", "no-store");
        if include_dpop_nonce {
            headers.set(
                "DPoP-Nonce",
                self.nonce_service.current_nonce(self.clock.now_secs()),
            );
        }
        let bytes = serde_json::to_vec(body).unwrap_or_else(|_| b"{}".to_vec());
        OAuthHttpResponse::new(status, headers, bytes)
    }

    fn json_error(
        &self,
        status: u16,
        error: &str,
        description: Option<&str>,
        dpop_nonce: Option<String>,
    ) -> OAuthHttpResponse {
        let mut headers = Self::cors_headers();
        headers.set("Content-Type", "application/json");
        headers.set("Cache-Control", "no-store");
        headers.set(
            "DPoP-Nonce",
            dpop_nonce.unwrap_or_else(|| self.nonce_service.current_nonce(self.clock.now_secs())),
        );
        let payload = OAuthErrorBody {
            error,
            error_description: description,
        };
        let bytes = serde_json::to_vec(&payload).unwrap_or_else(|_| b"{}".to_vec());
        OAuthHttpResponse::new(status, headers, bytes)
    }

    fn html_error(status: u16, message: &str) -> OAuthHttpResponse {
        let mut headers = OAuthHttpHeaders::default();
        headers.set("Content-Type", "text/plain; charset=utf-8");
        headers.set("Cache-Control", "no-store");
        headers.set("X-Frame-Options", "DENY");
        OAuthHttpResponse::new(status, headers, message.as_bytes().to_vec())
    }

    fn map_client_or_server_error(
        &self,
        err: OAuthServerError,
        nonce: Option<String>,
    ) -> OAuthHttpResponse {
        match err {
            OAuthServerError::Unavailable(_) => self.json_error(
                503,
                "temporarily_unavailable",
                Some("authorization service temporarily unavailable"),
                nonce,
            ),
            OAuthServerError::Unauthorized(msg) => {
                self.json_error(400, "invalid_client", Some(&msg), nonce)
            }
            ref other => self.json_error(400, "invalid_request", Some(&err_msg(other)), nonce),
        }
    }
}

fn err_msg(err: &OAuthServerError) -> String {
    match err {
        OAuthServerError::Unavailable(_) => {
            "authorization service temporarily unavailable".to_owned()
        }
        OAuthServerError::InvalidIdentifier(msg)
        | OAuthServerError::Malformed(msg)
        | OAuthServerError::Unauthorized(msg) => msg.clone(),
        OAuthServerError::Expired => "credential or token expired".to_owned(),
    }
}

fn extract_cookie<'a>(headers: &'a OAuthHttpHeaders, name: &str) -> Option<&'a str> {
    for raw in headers.values("Cookie") {
        for part in raw.split(';') {
            let trimmed = part.trim();
            if let Some((k, v)) = trimmed.split_once('=')
                && k.trim() == name
            {
                return Some(v.trim());
            }
        }
    }
    None
}

fn parse_accept_language(header: Option<&str>) -> Vec<String> {
    let Some(header) = header else {
        return Vec::new();
    };
    header
        .split(',')
        .filter_map(|item| {
            let tag = item.split(';').next()?.trim();
            if tag.is_empty() {
                None
            } else {
                Some(tag.to_owned())
            }
        })
        .collect()
}
