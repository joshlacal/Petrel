use std::fmt;

use petrel_core::{Did, Handle};
use petrel_oauth_scopes::ScopeSet;
use serde::{Deserialize, Serialize};
use zeroize::Zeroize;

use super::AuthorizationServerMetadata;

/// Identity and authorization binding attached to a durable session.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Account {
    pub did: Did,
    pub handle: Option<Handle>,
    /// Canonical PDS origin, with no trailing slash.
    pub pds: String,
    pub authorization_server: AuthorizationServerMetadata,
}

/// Tokens issued to one account. Debug output does not contain credentials.
#[derive(Clone, Deserialize, Serialize)]
pub struct Session {
    pub did: Did,
    access_token: String,
    refresh_token: Option<String>,
    pub created_at: u64,
    pub expires_in: u64,
    scope: String,
}

impl Session {
    pub(super) fn new(
        did: Did,
        access_token: String,
        refresh_token: Option<String>,
        created_at: u64,
        expires_in: u64,
        scope: &ScopeSet,
    ) -> Self {
        Self {
            did,
            access_token,
            refresh_token,
            created_at,
            expires_in,
            scope: scope.scope_string(),
        }
    }

    pub fn access_token(&self) -> &str {
        &self.access_token
    }

    pub fn refresh_token(&self) -> Option<&str> {
        self.refresh_token.as_deref()
    }

    pub fn scope(&self) -> &str {
        &self.scope
    }

    pub fn expires_at(&self) -> u64 {
        self.created_at.saturating_add(self.expires_in)
    }

    pub fn needs_refresh(&self, now: u64) -> bool {
        let expiry = self.expires_at();
        let margin = self
            .refresh_token
            .as_ref()
            .map_or(0, |_| (self.expires_in / 5).min(60));
        now >= expiry.saturating_sub(margin)
    }
}

impl fmt::Debug for Session {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Session")
            .field("did", &self.did)
            .field("created_at", &self.created_at)
            .field("expires_in", &self.expires_in)
            .finish_non_exhaustive()
    }
}

impl Drop for Session {
    fn drop(&mut self) {
        self.access_token.zeroize();
        self.refresh_token.zeroize();
    }
}

/// One committed record, including the DPoP key reference and thumbprint.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct SessionRecord {
    pub account: Account,
    pub session: Session,
    pub dpop_key_id: String,
    pub dpop_jkt: String,
}

/// State consumed exactly once by the callback handler.
#[derive(Deserialize, Serialize)]
pub(super) struct OAuthFlowState {
    pub code_verifier: String,
    pub nonce: String,
    pub expected_issuer: String,
    pub expected_pds: Option<String>,
    pub expected_did: Option<Did>,
    pub redirect_uri: String,
    pub dpop_key_id: String,
    pub dpop_jkt: String,
    pub metadata: AuthorizationServerMetadata,
}

impl Drop for OAuthFlowState {
    fn drop(&mut self) {
        self.code_verifier.zeroize();
        self.nonce.zeroize();
    }
}
