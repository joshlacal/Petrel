use std::{fmt, time::Duration};

use http::HeaderValue;
use petrel_core::{Did, Nsid, ServiceRef};
use serde::{Deserialize, Deserializer, de::IgnoredAny};
use zeroize::Zeroizing;

use crate::crypto::split_compact_jws;

#[derive(Clone, Debug, Eq, PartialEq, thiserror::Error)]
pub enum ServiceAuthRequestError {
    #[error("invalid service-auth request")]
    InvalidRequest,
    #[error("the PDS returned an invalid service-auth token")]
    InvalidToken,
    #[error("the PDS returned a service-auth token with unexpected claims")]
    UnexpectedClaims,
    #[error("the PDS returned HTTP {0} for getServiceAuth")]
    RequestFailed(u16),
    #[error("the PDS rejected the service-auth request: {0}")]
    Declared(petrel_api::generated::com::atproto::server::get_service_auth::Error),
    #[error("service-auth session is unavailable")]
    Session(#[from] crate::oauth::OAuthError),
    #[error("service-auth request could not be completed")]
    Unavailable,
}

/// Unverified contents of a service-auth token.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ServiceAuthClaims {
    pub issuer: ServiceRef,
    pub audience: ServiceRef,
    pub issued_at: Option<i64>,
    pub expires_at: i64,
    pub method: Option<Nsid>,
}

pub struct ServiceAuthToken {
    compact: Zeroizing<String>,
    claims: ServiceAuthClaims,
}

impl ServiceAuthToken {
    /// Parses the claims of a token issued by the PDS.
    ///
    /// This is inspection only. The receiving service verifies the signature.
    pub fn inspect(compact: String) -> Result<Self, ServiceAuthRequestError> {
        #[derive(Deserialize)]
        struct Header {
            alg: String,
            typ: Option<String>,
            #[serde(default, deserialize_with = "present")]
            crit: bool,
            #[serde(default, deserialize_with = "present")]
            b64: bool,
        }

        #[derive(Deserialize)]
        struct Claims {
            iss: String,
            aud: String,
            iat: Option<i64>,
            exp: i64,
            lxm: Option<Nsid>,
            jti: Option<String>,
            req: Option<String>,
        }

        let compact = Zeroizing::new(compact);
        if compact.len() > 32 * 1024 || compact.split('.').any(|segment| segment.len() > 16 * 1024)
        {
            return Err(ServiceAuthRequestError::InvalidToken);
        }
        let jws = split_compact_jws(&compact).map_err(|_| ServiceAuthRequestError::InvalidToken)?;
        if jws.signature.len() != 64 || jws.header.len() > 4 * 1024 {
            return Err(ServiceAuthRequestError::InvalidToken);
        }
        let header: Header = serde_json::from_slice(&jws.header)
            .map_err(|_| ServiceAuthRequestError::InvalidToken)?;
        if !matches!(header.alg.as_str(), "ES256" | "ES256K")
            || header.crit
            || header.b64
            || header.typ.as_ref().is_some_and(|typ| {
                ["at+jwt", "refresh+jwt", "dpop+jwt"]
                    .iter()
                    .any(|item| item.eq_ignore_ascii_case(typ))
            })
        {
            return Err(ServiceAuthRequestError::InvalidToken);
        }
        let claims: Claims = serde_json::from_slice(&jws.claims)
            .map_err(|_| ServiceAuthRequestError::InvalidToken)?;
        if claims
            .jti
            .as_deref()
            .is_some_and(|jti| !jti.is_empty() && !visible_ascii(jti, 256))
            || claims
                .req
                .as_deref()
                .is_some_and(|req| !visible_ascii(req, 4096))
        {
            return Err(ServiceAuthRequestError::InvalidToken);
        }
        let claims = ServiceAuthClaims {
            issuer: inspect_reference(&claims.iss)?,
            audience: inspect_reference(&claims.aud)?,
            issued_at: claims.iat,
            expires_at: claims.exp,
            method: claims.lxm,
        };
        Ok(Self { compact, claims })
    }

    pub fn as_str(&self) -> &str {
        &self.compact
    }

    pub fn claims(&self) -> &ServiceAuthClaims {
        &self.claims
    }

    pub fn authorization_header_value(&self) -> Result<HeaderValue, ServiceAuthRequestError> {
        let value = Zeroizing::new(format!("Bearer {}", self.compact.as_str()));
        let mut header =
            HeaderValue::from_str(&value).map_err(|_| ServiceAuthRequestError::InvalidToken)?;
        header.set_sensitive(true);
        Ok(header)
    }

    pub(crate) fn validate_claims(
        &self,
        session_did: &Did,
        audience: &ServiceRef,
        method: Option<&Nsid>,
        now: i64,
    ) -> Result<(), ServiceAuthRequestError> {
        let issued = &self.claims;
        if issued.issuer.did() != session_did
            || issued.audience.did() != audience.did()
            || (issued.audience.service_id().is_some()
                && issued.audience.service_id() != audience.service_id())
            || issued.method.as_ref() != method
            || issued.expires_at <= now
        {
            return Err(ServiceAuthRequestError::UnexpectedClaims);
        }
        Ok(())
    }
}

fn inspect_reference(input: &str) -> Result<ServiceRef, ServiceAuthRequestError> {
    let reference = ServiceRef::parse(input).map_err(|_| ServiceAuthRequestError::InvalidToken)?;
    if !has_valid_curve_key(&reference) {
        return Err(ServiceAuthRequestError::InvalidToken);
    }
    Ok(reference)
}

pub(crate) fn has_valid_curve_key(reference: &ServiceRef) -> bool {
    let Some(multibase) = reference.did().as_str().strip_prefix("did:key:z") else {
        return true;
    };
    let Ok(decoded) = bs58::decode(multibase).into_vec() else {
        return false;
    };
    match decoded.as_slice() {
        [0x80, 0x24, sec1 @ ..] => p256::PublicKey::from_sec1_bytes(sec1).is_ok(),
        [0xe7, 0x01, sec1 @ ..] => k256::PublicKey::from_sec1_bytes(sec1).is_ok(),
        _ => false,
    }
}

fn present<'de, D: Deserializer<'de>>(deserializer: D) -> Result<bool, D::Error> {
    IgnoredAny::deserialize(deserializer).map(|_| true)
}

fn visible_ascii(value: &str, limit: usize) -> bool {
    !value.is_empty() && value.len() <= limit && value.bytes().all(|byte| byte.is_ascii_graphic())
}

pub(crate) fn requested_expiration(
    lifetime: Option<Duration>,
    now: i64,
) -> Result<Option<i64>, ServiceAuthRequestError> {
    lifetime
        .map(|lifetime| {
            if !(Duration::from_secs(1)..=Duration::from_secs(86_400)).contains(&lifetime) {
                return Err(ServiceAuthRequestError::InvalidRequest);
            }
            let seconds = i64::try_from(lifetime.as_secs())
                .map_err(|_| ServiceAuthRequestError::InvalidRequest)?;
            now.checked_add(seconds)
                .ok_or(ServiceAuthRequestError::InvalidRequest)
        })
        .transpose()
}

impl fmt::Debug for ServiceAuthToken {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ServiceAuthToken")
            .field("claims", &self.claims)
            .finish_non_exhaustive()
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use crate::crypto::DpopSigner;
    use crate::crypto::{SoftwareDpopSigner, finish_es256_jws, jws_signing_input};

    use super::*;

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    async fn service_auth_checks_claims_and_redacts_token() {
        let key = SoftwareDpopSigner::generate().unwrap();
        let issuer = "did:plc:abcdefghijklmnopqrstuvwx";
        let audience = "did:web:service.example";
        let expected_audience = format!("{audience}#atproto_service").parse().unwrap();
        let issuer_did = issuer.parse().unwrap();
        let method: Nsid = "blue.example.service".parse().unwrap();
        let cases = [
            (issuer, audience, method.as_str(), 100, Ok(())),
            (
                issuer,
                "did:web:service.example#atproto_service",
                method.as_str(),
                100,
                Ok(()),
            ),
            (
                "did:plc:zyxwvutsrqponmlkjihgfedc",
                audience,
                method.as_str(),
                100,
                Err(ServiceAuthRequestError::UnexpectedClaims),
            ),
            (
                issuer,
                "did:web:other.example",
                method.as_str(),
                100,
                Err(ServiceAuthRequestError::UnexpectedClaims),
            ),
            (
                issuer,
                "did:web:service.example#wrong",
                method.as_str(),
                100,
                Err(ServiceAuthRequestError::UnexpectedClaims),
            ),
            (
                issuer,
                audience,
                "blue.example.wrong",
                100,
                Err(ServiceAuthRequestError::UnexpectedClaims),
            ),
            (
                issuer,
                audience,
                method.as_str(),
                10,
                Err(ServiceAuthRequestError::UnexpectedClaims),
            ),
        ];
        for (iss, aud, lxm, exp, expected) in cases {
            let input = jws_signing_input(
                &json!({"alg":"ES256","typ":"JWT"}),
                &json!({"iss":iss,"aud":aud,"lxm":lxm,"exp":exp}),
            )
            .unwrap();
            let sig = key.sign(input.as_bytes()).await.unwrap();
            let compact = finish_es256_jws(input, &sig).unwrap();
            let token = ServiceAuthToken::inspect(compact.clone()).unwrap();
            assert!(!format!("{token:?}").contains(&compact));
            assert!(token.authorization_header_value().unwrap().is_sensitive());
            assert_eq!(
                token.validate_claims(&issuer_did, &expected_audience, Some(&method), 10),
                expected
            );
        }
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn requested_expiration_checks_bounds() {
        assert_eq!(requested_expiration(None, 10), Ok(None));
        assert_eq!(
            requested_expiration(Some(Duration::from_secs(1)), 10),
            Ok(Some(11))
        );
        assert_eq!(
            requested_expiration(Some(Duration::from_secs(86_400)), 10),
            Ok(Some(86_410))
        );
        assert_eq!(
            requested_expiration(Some(Duration::from_millis(999)), 10),
            Err(ServiceAuthRequestError::InvalidRequest)
        );
        assert_eq!(
            requested_expiration(Some(Duration::from_secs(86_401)), 10),
            Err(ServiceAuthRequestError::InvalidRequest)
        );
    }
}
