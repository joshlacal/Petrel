use std::sync::Arc;

use bytes::Bytes;
use http::{HeaderValue, Request, Response, StatusCode, header};
use petrel_core::Did;
use url::Url;

use crate::{
    rt::BoxFuture,
    xrpc::{AuthCtx, AuthError, AuthProvider, UnauthorizedAction},
};

use super::{
    OAuthClient, OAuthError,
    client::valid_access_token,
    dpop::{dpop_proof, is_refreshable_token_rejection, oauth_error_code},
    metadata::{origin, require_canonical_origin},
    protocol::{OAuthProtocolError, unix_now},
};

/// Binds an XRPC client to one OAuth account.
#[derive(Clone, Debug)]
pub struct SessionAuth {
    client: Arc<OAuthClient>,
    did: Did,
}

impl OAuthClient {
    pub fn session_auth(self: &Arc<Self>, did: Did) -> SessionAuth {
        SessionAuth {
            client: Arc::clone(self),
            did,
        }
    }
}

impl AuthProvider for SessionAuth {
    fn prepare(
        &self,
        mut request: Request<Bytes>,
    ) -> BoxFuture<'_, Result<(Request<Bytes>, AuthCtx), AuthError>> {
        Box::pin(async move {
            let uri = Url::parse(&request.uri().to_string())
                .map_err(|_| AuthError::Other("invalid request URI".into()))?;
            let Some(record) = self
                .client
                .session_record(&self.did)
                .await
                .map_err(auth_error)?
            else {
                return Err(auth_error(self.client.missing_session(&self.did)));
            };
            if origin(&uri, false).as_deref() != Some(&record.account.pds)
                || !self.client.protocol.permits(&uri)
            {
                request.headers_mut().remove(header::AUTHORIZATION);
                request.headers_mut().remove("dpop");
                return Ok((request, AuthCtx::default()));
            }

            let token = record.session.access_token();
            let now = unix_now().map_err(|error| auth_error(error.into()))?;
            if now >= record.session.expires_at() || !valid_access_token(token) {
                return Err(AuthError::SessionExpired(
                    "access token expired or malformed".into(),
                ));
            }
            let key = self
                .client
                .bound_key(&record.dpop_key_id, &record.dpop_jkt)
                .await
                .map_err(auth_error)?;
            let nonce = self.client.resource_nonces.get(&record.dpop_jkt, &uri);
            let proof = dpop_proof(
                &*key,
                request.method(),
                &uri,
                now,
                Some(token),
                nonce.as_deref(),
            )
            .await
            .map_err(|error| auth_error(OAuthProtocolError::Dpop(error).into()))?;
            let mut authorization = HeaderValue::from_str(&format!("DPoP {token}"))
                .map_err(|_| AuthError::Other("invalid access token header".into()))?;
            let mut dpop = HeaderValue::from_str(&proof)
                .map_err(|_| AuthError::Other("invalid DPoP header".into()))?;
            authorization.set_sensitive(true);
            dpop.set_sensitive(true);
            request
                .headers_mut()
                .insert(header::AUTHORIZATION, authorization);
            request.headers_mut().insert("dpop", dpop);
            let session_generation = record.generation();
            Ok((
                request,
                AuthCtx {
                    did: Some(self.did.clone()),
                    jkt: Some(record.dpop_jkt),
                    session_generation: Some(session_generation),
                },
            ))
        })
    }

    fn refresh_if_needed(&self) -> BoxFuture<'_, Result<(), AuthError>> {
        Box::pin(async move {
            self.client
                .refresh(&self.did, false)
                .await
                .map(|_| ())
                .map_err(auth_error)
        })
    }

    fn handle_unauthorized<'a>(
        &'a self,
        response: &'a Response<Bytes>,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, Result<UnauthorizedAction, AuthError>> {
        Box::pin(async move {
            let code = oauth_error_code(response.body());
            if !is_refreshable_token_rejection(response, code)
                || ctx.did.as_ref() != Some(&self.did)
            {
                return Ok(UnauthorizedAction::GiveUp);
            }
            let Some(record) = self
                .client
                .session_record(&self.did)
                .await
                .map_err(auth_error)?
            else {
                return Ok(UnauthorizedAction::GiveUp);
            };
            if ctx.jkt.as_deref() != Some(&record.dpop_jkt) {
                return Ok(UnauthorizedAction::GiveUp);
            }

            if ctx
                .session_generation
                .is_some_and(|sent| sent != record.generation())
            {
                // This 401 refers to the previous access token on the same key.
                self.client
                    .refresh_after(&record, false)
                    .await
                    .map_err(auth_error)?;
                return Ok(UnauthorizedAction::Retry);
            }

            self.client
                .refresh_after(&record, true)
                .await
                .map_err(auth_error)?;
            Ok(UnauthorizedAction::Retry)
        })
    }

    fn update_dpop_nonce<'a>(
        &'a self,
        origin: &'a str,
        nonce: &'a str,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, ()> {
        Box::pin(async move {
            if ctx.did.as_ref() == Some(&self.did)
                && let Ok(Some(record)) = self.client.session_record(&self.did).await
                && ctx.jkt.as_deref() == Some(&record.dpop_jkt)
                && origin == record.account.pds
                && let Ok(url) = require_canonical_origin(origin)
            {
                let _ = self
                    .client
                    .resource_nonces
                    .put(&record.dpop_jkt, &url, nonce);
            }
        })
    }
}

pub(super) fn auth_error(error: OAuthError) -> AuthError {
    match error {
        OAuthError::Store(error) => AuthError::Store(error),
        OAuthError::Protocol(OAuthProtocolError::Transport(error)) => AuthError::Transport(error),
        OAuthError::MissingSession => AuthError::NoSession,
        OAuthError::InvalidGrant
        | OAuthError::ExpiredSession
        | OAuthError::UsedRefreshToken
        | OAuthError::KeyBinding => AuthError::SessionExpired(error.to_string()),
        _ => AuthError::RefreshFailed(error.to_string()),
    }
}

impl SessionAuth {
    /// Requests a service-auth token from this session's PDS.
    ///
    /// The PDS signs the token on behalf of the session DID. Petrel checks
    /// the returned claims, and the receiving service verifies the signature.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub async fn get_service_auth(
        &self,
        audience: &crate::service_auth::ServiceRef,
        method: Option<&petrel_core::Nsid>,
        lifetime: Option<std::time::Duration>,
    ) -> Result<crate::service_auth::ServiceAuthToken, crate::service_auth::ServiceAuthRequestError>
    {
        use petrel_api::generated::com::atproto::server::get_service_auth::{
            GetServiceAuth, Parameters,
        };

        use crate::{
            service_auth::{
                ServiceAuthRequestError as Error, ServiceAuthToken, has_valid_curve_key,
                requested_expiration,
            },
            xrpc::{CallOptions, Error as XrpcError, XrpcClient, XrpcErrorKind},
        };

        let aud = audience.to_string();
        if aud.len() > 2048 || !has_valid_curve_key(audience) {
            return Err(Error::InvalidRequest);
        }
        let now =
            i64::try_from(unix_now().map_err(OAuthError::from)?).map_err(|_| Error::Unavailable)?;
        let exp = requested_expiration(lifetime, now)?;
        let record = self
            .client
            .session_record(&self.did)
            .await?
            .ok_or_else(|| self.client.missing_session(&self.did))?;
        let pds = require_canonical_origin(&record.account.pds).map_err(OAuthError::from)?;
        if !self.client.protocol.permits(&pds) {
            return Err(Error::Unavailable);
        }

        let xrpc = XrpcClient::new(pds, Arc::clone(&self.client.protocol.transport))
            .map_err(|_| Error::Unavailable)?
            .with_auth_provider(Arc::new(self.clone()));
        let mut call_options = CallOptions::default();
        call_options.transport.allow_loopback = self.client.protocol.allow_loopback;
        let mut parameters = Parameters::new(aud);
        parameters.exp = exp;
        parameters.lxm = method.cloned();

        let (response, metadata) = xrpc
            .send_with_metadata::<GetServiceAuth>(parameters, (), &call_options)
            .await
            .map_err(|error| match error {
                XrpcError::Xrpc(error) => match error.kind {
                    XrpcErrorKind::Declared(typed) => Error::Declared(typed),
                    XrpcErrorKind::Undeclared(_) => {
                        Error::RequestFailed(error.metadata.status.as_u16())
                    }
                },
                XrpcError::Decode {
                    status: StatusCode::OK,
                    ..
                } => Error::InvalidToken,
                XrpcError::Decode { status, .. } => Error::RequestFailed(status.as_u16()),
                _ => Error::Unavailable,
            })?;
        if metadata.status != StatusCode::OK {
            return Err(Error::RequestFailed(metadata.status.as_u16()));
        }
        let token = ServiceAuthToken::inspect(response.token)?;
        let now =
            i64::try_from(unix_now().map_err(OAuthError::from)?).map_err(|_| Error::Unavailable)?;
        token.validate_claims_for_lifetime(&self.did, audience, method, now, lifetime)?;
        Ok(token)
    }
}
