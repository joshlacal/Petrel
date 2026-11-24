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
    dpop::{dpop_proof, oauth_error_code},
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
                return Err(AuthError::NoSession);
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
            let nonce = self.client.protocol.nonces.get(&record.dpop_jkt, &uri);
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
            Ok((
                request,
                AuthCtx {
                    did: Some(self.did.clone()),
                    jkt: Some(record.dpop_jkt),
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
            let refreshable = response.status() == StatusCode::UNAUTHORIZED
                || (response.status() == StatusCode::BAD_REQUEST && code == Some("ExpiredToken"));
            if !refreshable || ctx.did.as_ref() != Some(&self.did) {
                return Ok(UnauthorizedAction::GiveUp);
            }
            if matches!(
                code,
                Some(
                    "AccountTakedown"
                        | "AccountSuspended"
                        | "AccountDeactivated"
                        | "AccountDeleted"
                        | "Suspended"
                        | "Deactivated"
                        | "Deleted"
                )
            ) {
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
                    .protocol
                    .nonces
                    .put(&record.dpop_jkt, &url, nonce);
            }
        })
    }
}

fn auth_error(error: OAuthError) -> AuthError {
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
