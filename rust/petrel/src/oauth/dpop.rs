//! RFC 9449 proofs and in-memory nonce binding.

use std::{collections::HashMap, sync::Mutex};

use http::{HeaderMap, Method, StatusCode, header::WWW_AUTHENTICATE};
use serde::{Deserialize, Serialize};
use url::Url;

use super::metadata::origin;
use crate::crypto::{
    CryptoError, DpopSigner, Jwk, base64url, finish_es256_jws, jws_signing_input, random_bytes,
    sha256,
};

#[derive(Clone, Debug, Eq, PartialEq, thiserror::Error)]
pub enum DpopError {
    #[error("invalid HTTP target for DPoP")]
    Target,
    #[error("invalid DPoP nonce")]
    Nonce,
    #[error("timestamp exceeds the range usable for a DPoP proof")]
    Timestamp,
    #[error(transparent)]
    Crypto(#[from] CryptoError),
}

/// Canonical origin and path for DPoP's htu claim.
pub fn dpop_target(url: &Url) -> Result<String, DpopError> {
    let origin = origin(url, true).ok_or(DpopError::Target)?;
    Ok(format!(
        "{origin}{}",
        if url.path().is_empty() {
            "/"
        } else {
            url.path()
        }
    ))
}

/// Signs one proof. Supply an access token only for a protected resource request.
pub async fn dpop_proof(
    signer: &dyn DpopSigner,
    method: &Method,
    target: &Url,
    now: u64,
    access_token: Option<&str>,
    nonce: Option<&str>,
) -> Result<String, DpopError> {
    #[derive(Serialize)]
    struct Header<'a> {
        typ: &'static str,
        alg: &'static str,
        jwk: &'a Jwk,
    }

    #[derive(Serialize)]
    struct Claims<'a> {
        jti: String,
        htm: &'a str,
        htu: String,
        iat: u64,
        exp: u64,
        #[serde(skip_serializing_if = "Option::is_none")]
        ath: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        nonce: Option<&'a str>,
    }

    if nonce.is_some_and(|value| !valid_nonce(value)) {
        return Err(DpopError::Nonce);
    }
    let input = jws_signing_input(
        &Header {
            typ: "dpop+jwt",
            alg: "ES256",
            jwk: &Jwk::try_from(&signer.public_jwk())?,
        },
        &Claims {
            jti: base64url(&random_bytes::<24>()?),
            htm: method.as_str(),
            htu: dpop_target(target)?,
            iat: now,
            exp: now.checked_add(120).ok_or(DpopError::Timestamp)?,
            ath: access_token.map(|token| base64url(&sha256(token.as_bytes()))),
            nonce,
        },
    )?;
    let raw_signature = signer.sign(input.as_bytes()).await?;
    Ok(finish_es256_jws(input, &raw_signature)?)
}

fn valid_nonce(nonce: &str) -> bool {
    !nonce.is_empty()
        && nonce.len() <= 8 * 1024
        && nonce
            .bytes()
            .all(|byte| matches!(byte, 0x21 | 0x23..=0x5B | 0x5D..=0x7E))
}

/// A map scoped to both the sender key and the server origin.
#[derive(Default)]
pub struct DpopNonces {
    by_key: Mutex<HashMap<String, HashMap<String, String>>>,
}

impl std::fmt::Debug for DpopNonces {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DpopNonces").finish_non_exhaustive()
    }
}

impl DpopNonces {
    pub fn get(&self, jkt: &str, url: &Url) -> Option<String> {
        let origin = origin(url, false)?;
        self.by_key
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .get(jkt)?
            .get(&origin)
            .cloned()
    }

    pub fn put(&self, jkt: &str, url: &Url, nonce: &str) -> Result<(), DpopError> {
        let origin = origin(url, false).ok_or(DpopError::Target)?;
        if !valid_nonce(nonce) {
            return Err(DpopError::Nonce);
        }
        self.by_key
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .entry(jkt.to_owned())
            .or_default()
            .insert(origin, nonce.to_owned());
        Ok(())
    }

    pub fn clear_key(&self, jkt: &str) {
        self.by_key
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .remove(jkt);
    }
}

pub(super) fn nonce_header(headers: &HeaderMap) -> Result<Option<&str>, DpopError> {
    let mut values = headers.get_all("dpop-nonce").iter();
    let Some(value) = values.next() else {
        return Ok(None);
    };
    let nonce = value.to_str().map_err(|_| DpopError::Nonce)?;
    if values.next().is_some() || !valid_nonce(nonce) {
        return Err(DpopError::Nonce);
    }
    Ok(Some(nonce))
}

/// Parse only the OAuth code used for protocol decisions. Never surface descriptions.
pub(super) fn oauth_error_code(body: &[u8]) -> Option<&str> {
    #[derive(Deserialize)]
    struct ErrorBody<'a> {
        error: &'a str,
    }
    serde_json::from_slice::<ErrorBody<'_>>(body)
        .ok()
        .map(|body| body.error)
}

pub(super) fn use_dpop_nonce<B: AsRef<[u8]>>(response: &http::Response<B>) -> bool {
    if !matches!(
        response.status(),
        StatusCode::BAD_REQUEST | StatusCode::UNAUTHORIZED
    ) {
        return false;
    }
    oauth_error_code(response.body().as_ref()) == Some("use_dpop_nonce")
        || response
            .headers()
            .get_all(WWW_AUTHENTICATE)
            .iter()
            .filter_map(|header| header.to_str().ok())
            .any(www_authenticate_nonce)
}

fn www_authenticate_nonce(input: &str) -> bool {
    let mut start = 0;
    let mut quoted = false;
    let mut escaped = false;
    // Split auth parameters on commas outside quoted values.
    for (index, byte) in input.bytes().enumerate() {
        if escaped {
            escaped = false;
        } else if quoted && byte == b'\\' {
            escaped = true;
        } else if byte == b'"' {
            quoted = !quoted;
        } else if !quoted && byte == b',' {
            if is_nonce_parameter(&input[start..index]) {
                return true;
            }
            start = index + 1;
        }
    }
    !quoted && is_nonce_parameter(&input[start..])
}

fn is_nonce_parameter(input: &str) -> bool {
    let input = input.trim();
    let parameter = input
        .split_once([' ', '\t'])
        .filter(|(scheme, _)| scheme.eq_ignore_ascii_case("DPoP"))
        .map_or(input, |(_, value)| value);
    parameter.split_once('=').is_some_and(|(key, value)| {
        key.trim().eq_ignore_ascii_case("error") && value.trim() == "\"use_dpop_nonce\""
    })
}

#[cfg(test)]
mod tests {
    use serde_json::Value;

    use super::*;
    use crate::crypto::{SoftwareDpopSigner, split_compact_jws};

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    async fn proofs_bind_target_method_hash_nonce_and_fresh_id() {
        let signer = SoftwareDpopSigner::generate().unwrap();
        let method = Method::POST;
        let target =
            Url::parse("https://EXAMPLE.test:443/oauth/token?secret=ignored#ignored").unwrap();
        let token = Some("fixture-token");
        let old = dpop_proof(&signer, &method, &target, 10, token, Some("nonce1"))
            .await
            .unwrap();
        let new = dpop_proof(&signer, &method, &target, 11, token, Some("nonce2"))
            .await
            .unwrap();
        let old = split_compact_jws(&old).unwrap();
        let new = split_compact_jws(&new).unwrap();
        let header: Value = serde_json::from_slice(&old.header).unwrap();
        let old: Value = serde_json::from_slice(&old.claims).unwrap();
        let new: Value = serde_json::from_slice(&new.claims).unwrap();
        assert_eq!(header["typ"], "dpop+jwt");
        assert_eq!(header["alg"], "ES256");
        assert_eq!(header["jwk"].as_object().unwrap().len(), 4);
        assert_ne!(old["jti"], new["jti"]);
        assert_eq!(old["htm"], "POST");
        assert_eq!(old["htu"], "https://example.test/oauth/token");
        assert_eq!(old["ath"], base64url(&sha256(b"fixture-token")));
        assert_eq!(old["iat"], 10);
        assert_eq!(old["exp"], 130);
        assert_eq!(new["nonce"], "nonce2");
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn nonce_bound_to_both_thumbprint_and_origin() {
        let nonces = DpopNonces::default();
        let first = Url::parse("https://issuer.example/path1").unwrap();
        let same_origin = Url::parse("https://issuer.example:443/path2").unwrap();
        let another_port = Url::parse("https://issuer.example:8000/path1").unwrap();
        nonces.put("key-a", &first, "nonce-a").unwrap();
        nonces.put("key-b", &first, "nonce-b").unwrap();
        assert_eq!(
            nonces.get("key-a", &same_origin).as_deref(),
            Some("nonce-a")
        );
        assert_eq!(nonces.get("key-a", &another_port), None);
        nonces.clear_key("key-a");
        assert_eq!(nonces.get("key-a", &first), None);
        assert_eq!(nonces.get("key-b", &first).as_deref(), Some("nonce-b"));
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn nonce_challenge_requires_status_and_exact_code() {
        let challenge = http::Response::builder()
            .status(401)
            .header(
                WWW_AUTHENTICATE,
                "DPoP error=\"use_dpop_nonce\", error_description=\"try again, now\"",
            )
            .header("DPoP-Nonce", "fresh")
            .body(b"".as_slice())
            .unwrap();
        assert!(use_dpop_nonce(&challenge));
        assert_eq!(nonce_header(challenge.headers()).unwrap(), Some("fresh"));
        assert!(!www_authenticate_nonce(
            "DPoP error_description=\"error=\\\"use_dpop_nonce\\\"\""
        ));
        assert!(!www_authenticate_nonce(
            "DPoP error=\"use_dpop_nonce_extra\""
        ));
        assert!(!use_dpop_nonce(&http::Response::new(
            br#"{"error":"use_dpop_nonce"}"#.as_slice()
        )));
    }
}
