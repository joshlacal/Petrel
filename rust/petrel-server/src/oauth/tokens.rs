use serde::{Deserialize, Serialize};

use crate::error::OAuthServerError;
use crate::jose::{OAuthCompactJwt, OAuthSigningKey};
use crate::store::{OAuthGrantBinding, OAuthIssuedTokenDigests};
use crate::support::{DigestPurpose, OAuthKeyedDigest, OAuthRandomSource};

/// RFC 9449 `cnf` confirmation claim binding an access token to a DPoP JWK thumbprint.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OAuthDpopCnf {
    pub jkt: String,
}

/// JWT claims emitted when `access_token_format == Jwt` (`typ = "at+jwt"`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OAuthAccessTokenClaims {
    pub iss: String,
    pub sub: String,
    pub aud: String,
    pub iat: i64,
    pub exp: i64,
    pub jti: String,
    pub client_id: String,
    pub scope: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cnf: Option<OAuthDpopCnf>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub session_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub device_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub account_id: Option<String>,
}

/// Input parameters for minting an access + refresh token pair.
#[derive(Debug, Clone)]
pub struct MintTokenPairInput<'a> {
    pub session_id: &'a str,
    pub client_id: &'a str,
    pub scope: &'a str,
    pub dpop_jkt: &'a str,
    pub binding: &'a OAuthGrantBinding,
    pub now_secs: i64,
    pub access_ttl_secs: i64,
    pub generation: u64,
}

/// Raw issued token strings paired with their storage digests.
#[derive(Debug, Clone)]
pub struct MintedTokenPair {
    pub access_token: String,
    pub refresh_token: String,
    pub digests: OAuthIssuedTokenDigests,
}

/// Mints opaque or `at+jwt` access tokens plus random refresh tokens and HMAC digests.
pub struct OAuthTokenMinter<'a> {
    pub issuer: &'a str,
    pub audience: &'a str,
    pub use_jwt_access_token: bool,
    pub signing_key: &'a OAuthSigningKey,
    pub keyed_digest: &'a OAuthKeyedDigest,
    pub random: &'a dyn OAuthRandomSource,
}

impl std::fmt::Debug for OAuthTokenMinter<'_> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OAuthTokenMinter")
            .field("issuer", &self.issuer)
            .field("audience", &self.audience)
            .field("use_jwt_access_token", &self.use_jwt_access_token)
            .finish_non_exhaustive()
    }
}

impl OAuthTokenMinter<'_> {
    /// Mints an access token and refresh token for `input`.
    pub fn mint(
        &self,
        input: &MintTokenPairInput<'_>,
    ) -> Result<MintedTokenPair, OAuthServerError> {
        let refresh_token = format!("rt_{}", self.random.opaque_value());
        let access_token = if self.use_jwt_access_token {
            let (device_id, account_id) = match input.binding {
                OAuthGrantBinding::Subject { .. } => (None, None),
                OAuthGrantBinding::DeviceAccount {
                    device_id,
                    account_id,
                    ..
                } => (Some(device_id.clone()), Some(account_id.clone())),
            };
            let claims = OAuthAccessTokenClaims {
                iss: self.issuer.to_owned(),
                sub: input.binding.did().to_owned(),
                aud: self.audience.to_owned(),
                iat: input.now_secs,
                exp: input.now_secs.saturating_add(input.access_ttl_secs),
                jti: self.random.uuid_v4().to_string(),
                client_id: input.client_id.to_owned(),
                scope: input.scope.to_owned(),
                cnf: Some(OAuthDpopCnf {
                    jkt: input.dpop_jkt.to_owned(),
                }),
                session_id: Some(input.session_id.to_owned()),
                device_id,
                account_id,
            };
            OAuthCompactJwt::sign(&claims, self.signing_key, Some("at+jwt"), false)?
        } else {
            format!("at_{}", self.random.opaque_value())
        };

        let access_token_digest = self
            .keyed_digest
            .digest_str(&access_token, DigestPurpose::AccessToken);
        let refresh_token_digest = self
            .keyed_digest
            .digest_str(&refresh_token, DigestPurpose::RefreshToken);

        Ok(MintedTokenPair {
            access_token,
            refresh_token,
            digests: OAuthIssuedTokenDigests {
                access_token_digest,
                refresh_token_digest,
                refresh_token_generation: input.generation,
            },
        })
    }
}
