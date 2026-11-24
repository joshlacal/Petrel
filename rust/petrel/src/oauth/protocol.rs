//! HTTP exchanges between the OAuth client, authorization server and CAB.

use std::time::Duration;

use bytes::Bytes;
use http::{HeaderValue, Method, Request, Response, StatusCode, header};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use url::Url;
use web_time::{SystemTime, UNIX_EPOCH};
use zeroize::Zeroizing;

use super::{
    ClientAuth,
    dpop::{DpopError, DpopNonces, dpop_proof, nonce_header, oauth_error_code, use_dpop_nonce},
    metadata::{
        AuthorizationServerMetadata, ClientAuthenticationMethod, MetadataDocument, MetadataError,
        ProtectedResourceMetadata, ValidatedAuthorizationServer, endpoint_url, is_loopback, origin,
        require_canonical_origin,
    },
};
use crate::{
    crypto::{
        CryptoError, DpopSigner, base64url, finish_es256_jws, jws_signing_input, random_bytes,
    },
    net::{SendOptions, SharedTransport, TransportError},
};

const ASSERTION_TYPE: &str = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer";
const MAX_RESPONSE_BYTES: u64 = 128 * 1024;

#[derive(Clone, Debug, Eq, PartialEq, thiserror::Error)]
pub enum AssertionBackendError {
    #[error("the client assertion backend URL is invalid")]
    InvalidUrl,
    #[error("client assertion backend returned HTTP {status} ({code:?})")]
    Rejected {
        status: u16,
        code: Option<AssertionBackendErrorCode>,
    },
    #[error("client assertion backend did not return a fresh DPoP nonce")]
    MissingNonce,
    #[error("client assertion backend returned another client ID")]
    ClientIdMismatch,
    #[error("client assertion backend did not return a valid response")]
    MalformedResponse,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AssertionBackendErrorCode {
    UseDpopNonce,
    InvalidDpopProof,
    InvalidRequest,
    AccessDenied,
    RateLimited,
}

#[derive(Clone, Debug, Eq, PartialEq, thiserror::Error)]
pub enum OAuthProtocolError {
    #[error(transparent)]
    Metadata(#[from] MetadataError),
    #[error(transparent)]
    Crypto(#[from] CryptoError),
    #[error(transparent)]
    Dpop(#[from] DpopError),
    #[error(transparent)]
    AssertionBackend(#[from] AssertionBackendError),
    #[error("OAuth transport failed")]
    Transport(TransportError),
    #[error("OAuth request configuration is invalid")]
    InvalidRequest,
    #[error("OAuth endpoint returned a redirect")]
    Redirect,
    #[error("system clock is outside the supported OAuth range")]
    Clock,
}

pub(super) fn unix_now() -> Result<u64, OAuthProtocolError> {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .map_err(|_| OAuthProtocolError::Clock)
}

impl ClientAuth {
    pub fn method(&self) -> ClientAuthenticationMethod {
        match self {
            Self::Public => ClientAuthenticationMethod::Public,
            Self::PrivateKeyJwt(_) | Self::Cab { .. } => ClientAuthenticationMethod::PrivateKeyJwt,
        }
    }
}

#[derive(Clone, Copy)]
pub(super) enum AsEndpoint {
    Par,
    Token,
    Revoke,
}

pub(super) struct OAuthProtocol {
    pub(super) transport: SharedTransport,
    pub(super) client_id: String,
    pub(super) authentication: ClientAuth,
    pub(super) allow_loopback: bool,
    pub(super) nonces: DpopNonces,
}

impl OAuthProtocol {
    pub(super) fn permits(&self, url: &Url) -> bool {
        !is_loopback(url) || self.allow_loopback
    }

    fn options(&self, seconds: u64, anonymous: bool) -> SendOptions {
        let mut options = SendOptions::new();
        options.timeout = Some(Duration::from_secs(seconds));
        options.max_response_bytes = Some(MAX_RESPONSE_BYTES);
        options.allow_loopback = self.allow_loopback;
        options.anonymous = anonymous;
        options
    }

    /// PDS-first lookup. Both documents must name the authority they came from.
    pub(super) async fn discover_pds(
        &self,
        pds: &Url,
    ) -> Result<ValidatedAuthorizationServer, MetadataError> {
        let origin = origin(pds, false)
            .filter(|_| self.permits(pds))
            .ok_or(MetadataError::InvalidOrigin)?;
        let prm: ProtectedResourceMetadata = self
            .fetch(MetadataDocument::ProtectedResource, &origin)
            .await?;
        let issuer = prm.validate(&origin)?;
        if is_loopback(&require_canonical_origin(issuer)?) && !is_loopback(pds) {
            return Err(MetadataError::InvalidOrigin);
        }
        let as_metadata = self.discover_issuer(issuer).await?;
        as_metadata.validates_resource(&origin)?;
        Ok(as_metadata)
    }

    /// A server-first sign-in may target an issuer directly, as with an entryway.
    pub(super) async fn discover_server(
        &self,
        server: &Url,
    ) -> Result<ValidatedAuthorizationServer, MetadataError> {
        let resource_error = match self.discover_pds(server).await {
            Ok(metadata) => return Ok(metadata),
            Err(error @ MetadataError::Transport(_)) => return Err(error),
            Err(error) => error,
        };
        let issuer = origin(server, false)
            .filter(|_| self.permits(server))
            .ok_or(MetadataError::InvalidOrigin)?;
        match self.discover_issuer(&issuer).await {
            Ok(metadata) => Ok(metadata),
            Err(error)
                if matches!(error, MetadataError::Transport(_))
                    || matches!(
                        resource_error,
                        MetadataError::UnexpectedStatus {
                            document: MetadataDocument::ProtectedResource,
                            status: 404,
                        }
                    ) =>
            {
                Err(error)
            }
            Err(_) => Err(resource_error),
        }
    }

    async fn discover_issuer(
        &self,
        issuer: &str,
    ) -> Result<ValidatedAuthorizationServer, MetadataError> {
        let metadata: AuthorizationServerMetadata = self
            .fetch(MetadataDocument::AuthorizationServer, issuer)
            .await?;
        metadata.validate(issuer, self.authentication.method())
    }

    async fn fetch<T: DeserializeOwned>(
        &self,
        document: MetadataDocument,
        origin: &str,
    ) -> Result<T, MetadataError> {
        let origin_url = require_canonical_origin(origin)?;
        if !self.permits(&origin_url) {
            return Err(MetadataError::InvalidOrigin);
        }
        let url = format!("{origin}/.well-known/{}", document.name());
        let options = self.options(30, true);
        let response = {
            let mut attempt = 0;
            loop {
                let request = Request::get(&url)
                    .header(header::ACCEPT, "application/json")
                    .body(Bytes::new())
                    .map_err(|_| MetadataError::InvalidOrigin)?;
                match self.transport.send_dyn(request, &options).await {
                    Ok(response) => break response,
                    Err(
                        TransportError::Timeout
                        | TransportError::Connect(_)
                        | TransportError::ConnectionLost(_),
                    ) if attempt < 2 => {
                        retry_delay(100 << attempt).await;
                        attempt += 1;
                    }
                    Err(_) => return Err(MetadataError::Transport(document)),
                }
            }
        };
        if response.status() != StatusCode::OK {
            return Err(MetadataError::UnexpectedStatus {
                document,
                status: response.status().as_u16(),
            });
        }
        if !json_content_type(&response) {
            return Err(MetadataError::ContentType(document));
        }
        serde_json::from_slice(response.body())
            .map_err(|_| MetadataError::MalformedDocument(document))
    }

    /// Sends a signed form to a validated endpoint. This is the only AS sender.
    pub(super) async fn send_as(
        &self,
        metadata: &ValidatedAuthorizationServer,
        endpoint: AsEndpoint,
        parameters: &[(&str, &str)],
        key: &dyn DpopSigner,
    ) -> Result<Response<Bytes>, OAuthProtocolError> {
        let (url, timeout) = match endpoint {
            AsEndpoint::Par => (&metadata.par_endpoint, 30),
            AsEndpoint::Token => (&metadata.token_endpoint, 30),
            AsEndpoint::Revoke => (
                metadata
                    .revocation_endpoint
                    .as_ref()
                    .ok_or(OAuthProtocolError::InvalidRequest)?,
                10,
            ),
        };
        if !self.permits(url)
            || parameters.iter().any(|(key, _)| {
                matches!(
                    *key,
                    "client_id" | "client_assertion_type" | "client_assertion"
                )
            })
        {
            return Err(OAuthProtocolError::InvalidRequest);
        }
        let options = self.options(timeout, false);
        let jkt = key.public_jwk().thumbprint()?;
        let mut nonce = self.nonces.get(&jkt, url);
        for attempt in 0..2 {
            // The backend and private signer are called again for the retry.
            let assertion = self.client_assertion(metadata.issuer(), key).await?;
            let body = as_form(
                parameters,
                &self.client_id,
                assertion.as_deref().map(String::as_str),
            );
            let proof =
                dpop_proof(key, &Method::POST, url, unix_now()?, None, nonce.as_deref()).await?;
            let request = form_request(url, body, &proof)?;
            let response = self
                .transport
                .send_dyn(request, &options)
                .await
                .map_err(OAuthProtocolError::Transport)?;
            if response.status().is_redirection() {
                return Err(OAuthProtocolError::Redirect);
            }
            let updated_nonce = nonce_header(response.headers()).ok().flatten();
            if let Some(value) = updated_nonce {
                self.nonces.put(&jkt, url, value)?;
                if attempt == 0 && use_dpop_nonce(&response) {
                    nonce = Some(value.to_owned());
                    continue;
                }
            }
            return Ok(response);
        }
        unreachable!("the second attempt always returns its response")
    }

    async fn client_assertion(
        &self,
        issuer: &str,
        key: &dyn DpopSigner,
    ) -> Result<Option<Zeroizing<String>>, OAuthProtocolError> {
        match &self.authentication {
            ClientAuth::Public => Ok(None),
            ClientAuth::PrivateKeyJwt(signer) => {
                #[derive(Serialize)]
                struct Header<'a> {
                    alg: &'static str,
                    typ: &'static str,
                    kid: &'a str,
                }
                #[derive(Serialize)]
                struct Claims<'a> {
                    iss: &'a str,
                    sub: &'a str,
                    aud: &'a str,
                    jti: String,
                    iat: u64,
                    exp: u64,
                }
                let now = unix_now()?;
                let input = jws_signing_input(
                    &Header {
                        alg: "ES256",
                        typ: "JWT",
                        kid: signer.key_id(),
                    },
                    &Claims {
                        iss: &self.client_id,
                        sub: &self.client_id,
                        aud: issuer,
                        jti: base64url(&random_bytes::<24>()?),
                        iat: now,
                        exp: now.checked_add(60).ok_or(OAuthProtocolError::Clock)?,
                    },
                )?;
                let bytes = signer.sign(input.as_bytes()).await?;
                Ok(Some(Zeroizing::new(finish_es256_jws(input, &bytes)?)))
            }
            ClientAuth::Cab {
                backend_url,
                client_id,
            } => {
                if client_id != &self.client_id {
                    return Err(AssertionBackendError::ClientIdMismatch.into());
                }
                Ok(Some(Zeroizing::new(
                    self.cab_assertion(backend_url, issuer, key).await?,
                )))
            }
        }
    }

    async fn cab_assertion(
        &self,
        backend: &Url,
        issuer: &str,
        key: &dyn DpopSigner,
    ) -> Result<String, OAuthProtocolError> {
        #[derive(Deserialize)]
        struct CabSuccess {
            client_id: String,
            client_assertion: String,
        }

        let mut url = endpoint_url(backend.as_str())
            .filter(|url| self.permits(url) && url.query().is_none())
            .ok_or(AssertionBackendError::InvalidUrl)?;
        url.path_segments_mut()
            .map_err(|()| AssertionBackendError::InvalidUrl)?
            .pop_if_empty()
            .extend(["oauth", "client-assertion"]);
        let options = self.options(30, false);

        // CAB nonces are specific to this challenge, not reusable AS/PDS nonces.
        let mut nonce = None;
        for attempt in 0..2 {
            let proof = dpop_proof(
                key,
                &Method::POST,
                &url,
                unix_now()?,
                None,
                nonce.as_deref(),
            )
            .await?;
            let body = encode_form(&[("aud", issuer)]);
            let request = form_request(&url, body, &proof)?;
            let response = self
                .transport
                .send_dyn(request, &options)
                .await
                .map_err(OAuthProtocolError::Transport)?;
            if response.status().is_redirection() {
                return Err(OAuthProtocolError::Redirect);
            }
            if response.status() == StatusCode::OK {
                let success: CabSuccess = serde_json::from_slice(response.body())
                    .map_err(|_| AssertionBackendError::MalformedResponse)?;
                if success.client_id != self.client_id {
                    return Err(AssertionBackendError::ClientIdMismatch.into());
                }
                if success.client_assertion.is_empty() {
                    return Err(AssertionBackendError::MalformedResponse.into());
                }
                return Ok(success.client_assertion);
            }
            let code = match oauth_error_code(response.body()) {
                Some("use_dpop_nonce") => Some(AssertionBackendErrorCode::UseDpopNonce),
                Some("invalid_dpop_proof") => Some(AssertionBackendErrorCode::InvalidDpopProof),
                Some("invalid_request") => Some(AssertionBackendErrorCode::InvalidRequest),
                Some("access_denied") => Some(AssertionBackendErrorCode::AccessDenied),
                Some("rate_limited") => Some(AssertionBackendErrorCode::RateLimited),
                _ => None,
            };
            if attempt == 0
                && response.status() == StatusCode::BAD_REQUEST
                && code == Some(AssertionBackendErrorCode::UseDpopNonce)
            {
                nonce = Some(
                    nonce_header(response.headers())?
                        .ok_or(AssertionBackendError::MissingNonce)?
                        .to_owned(),
                );
                continue;
            }
            return Err(AssertionBackendError::Rejected {
                status: response.status().as_u16(),
                code,
            }
            .into());
        }
        unreachable!("the second attempt always returns its response")
    }
}

fn json_content_type(response: &Response<Bytes>) -> bool {
    response
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.split(';').next())
        .is_some_and(|value| value.trim().eq_ignore_ascii_case("application/json"))
}

fn as_form(parameters: &[(&str, &str)], client_id: &str, assertion: Option<&str>) -> String {
    let mut encoder = url::form_urlencoded::Serializer::new(String::new());
    encoder.extend_pairs(parameters.iter().copied());
    encoder.append_pair("client_id", client_id);
    if let Some(assertion) = assertion {
        encoder.append_pair("client_assertion_type", ASSERTION_TYPE);
        encoder.append_pair("client_assertion", assertion);
    }
    encoder.finish()
}

fn encode_form(parameters: &[(&str, &str)]) -> String {
    url::form_urlencoded::Serializer::new(String::new())
        .extend_pairs(parameters.iter().copied())
        .finish()
}

fn form_request(
    url: &Url,
    body: String,
    proof: &str,
) -> Result<Request<Bytes>, OAuthProtocolError> {
    let mut dpop = HeaderValue::from_str(proof).map_err(|_| OAuthProtocolError::InvalidRequest)?;
    dpop.set_sensitive(true);
    Request::post(url.as_str())
        .header(header::CONTENT_TYPE, "application/x-www-form-urlencoded")
        .header(header::ACCEPT, "application/json")
        .header("dpop", dpop)
        .body(Bytes::from(body))
        .map_err(|_| OAuthProtocolError::InvalidRequest)
}

pub(super) async fn retry_delay(millis: u32) {
    #[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
    tokio::time::sleep(Duration::from_millis(u64::from(millis))).await;
    #[cfg(all(target_arch = "wasm32", feature = "wasm"))]
    gloo_timers::future::TimeoutFuture::new(millis).await;
    #[cfg(not(any(
        all(not(target_arch = "wasm32"), feature = "native"),
        all(target_arch = "wasm32", feature = "wasm")
    )))]
    let _ = millis;
}

#[cfg(test)]
mod discovery_tests;
