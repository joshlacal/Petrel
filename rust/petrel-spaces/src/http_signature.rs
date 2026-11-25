//! RFC 9421 HTTP Message Signatures for ATProto Space credential presentation.

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use http::HeaderMap;
use petrel_core::Did;
use petrel_crypto::{ATProtoSignatureVerificationOptions, PublicKey};
use url::Url;

use crate::error::{Result, SpaceError};
use crate::sf::{
    DuplicatePolicy, SfBareItem, SfItem, SfMember, escape_sf_string, parse_dictionary,
};
use crate::tokens::{
    CredentialClaims, SigningKeyPair, SigningKeyResolver, verify_credential_token,
};

/// RFC 9421 signature label for ATProto space credential presentations.
pub const SPACE_SIGNATURE_LABEL: &str = "atproto-space-credential";
/// RFC 9421 signature tag for ATProto space credential presentations.
pub const SPACE_SIGNATURE_TAG: &str = "atproto-space-credential";
/// Authorization scheme prefix for space credentials.
pub const SPACE_AUTH_SCHEME: &str = "Atproto-Space-Credential";
/// Audience HTTP header name (lowercase canonical).
pub const SPACE_AUDIENCE_HEADER: &str = "atproto-space-audience";

/// Default maximum HTTP signature age in seconds (5 minutes).
pub const MAX_HTTP_SIGNATURE_AGE_SECS: i64 = 300;
/// Default maximum clock skew leeway in seconds (60 seconds).
pub const MAX_HTTP_SIGNATURE_SKEW_SECS: i64 = 60;
/// Maximum allowed `nonce` length in bytes (512 bytes, matching reference conformance vectors).
pub const MAX_NONCE_BYTES: usize = 512;

/// Signed HTTP headers required to present a space credential under RFC 9421.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SpaceRequestHeaders {
    pub authorization: String,
    pub atproto_space_audience: String,
    pub signature_input: String,
    pub signature: String,
}

impl SpaceRequestHeaders {
    /// Insert these four headers into an `http::HeaderMap`.
    pub fn apply_to_header_map(&self, headers: &mut HeaderMap) -> Result<()> {
        let parse_val = |v: &str| {
            http::HeaderValue::from_str(v)
                .map_err(|e| SpaceError::MalformedHeader(format!("invalid header value: {e}")))
        };
        headers.insert(http::header::AUTHORIZATION, parse_val(&self.authorization)?);
        headers.insert(
            http::header::HeaderName::from_static(SPACE_AUDIENCE_HEADER),
            parse_val(&self.atproto_space_audience)?,
        );
        headers.insert(
            http::header::HeaderName::from_static("signature-input"),
            parse_val(&self.signature_input)?,
        );
        headers.insert(
            http::header::HeaderName::from_static("signature"),
            parse_val(&self.signature)?,
        );
        Ok(())
    }
}

/// Verified RFC 9421 HTTP signature metadata (without JWT claims).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedHttpSignature {
    pub credential_jwt: String,
    pub audience: String,
    pub created: Option<i64>,
    pub expires: Option<i64>,
    pub nonce: Option<String>,
    pub sig_params_line: String,
}

/// Verified space credential presentation (both RFC 9421 PoP signature and JWT claims).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedSpaceHeaders {
    pub credential_jwt: String,
    pub claims: CredentialClaims,
    pub audience: String,
    pub nonce: Option<String>,
    pub created: Option<i64>,
    pub expires: Option<i64>,
    pub sig_params_line: String,
}

/// Derive a `did:web:` DID from an HTTP(S) request URL.
pub fn did_web_from_url(url: &Url) -> Result<Did> {
    let host = url
        .host_str()
        .ok_or_else(|| SpaceError::InvalidUri(format!("URL missing host: {url}")))?
        .to_ascii_lowercase();
    let raw = match url.port() {
        Some(port) => format!("did:web:{host}%3A{port}"),
        None => format!("did:web:{host}"),
    };
    Did::parse(&raw).map_err(|e| SpaceError::InvalidDid(e.to_string()))
}

/// Resolve the presentation audience DID for an outbound request: prefers `explicit_server_did`
/// when known, otherwise derives `did:web:<host>` from `request_url`.
pub fn derive_audience(request_url: &Url, explicit_server_did: Option<&Did>) -> Result<Did> {
    if let Some(did) = explicit_server_did {
        return Ok(did.clone());
    }
    did_web_from_url(request_url)
}

/// Sign a space credential presentation with RFC 9421 (`created` and optional `nonce`).
pub fn sign_credential_request(
    credential_jwt: &str,
    proof_key: &SigningKeyPair,
    audience_did: &str,
    created: i64,
    nonce: Option<&str>,
) -> Result<SpaceRequestHeaders> {
    sign_credential_request_with_params(
        credential_jwt,
        proof_key,
        audience_did,
        Some(created),
        None,
        nonce,
    )
}

/// Sign a minimal space credential presentation (`tag="atproto-space-credential"` only).
pub fn sign_credential_request_minimal(
    credential_jwt: &str,
    proof_key: &SigningKeyPair,
    audience_did: &str,
) -> Result<SpaceRequestHeaders> {
    sign_credential_request_with_params(credential_jwt, proof_key, audience_did, None, None, None)
}

/// Sign a space credential presentation with explicit optional `created`, `expires`, and `nonce`.
pub fn sign_credential_request_with_params(
    credential_jwt: &str,
    proof_key: &SigningKeyPair,
    audience_did: &str,
    created: Option<i64>,
    expires: Option<i64>,
    nonce: Option<&str>,
) -> Result<SpaceRequestHeaders> {
    if let Some(c) = created
        && c < 0
    {
        return Err(SpaceError::InvalidTimestamp(
            "created timestamp cannot be negative".into(),
        ));
    }
    if let Some(e) = expires
        && e < 0
    {
        return Err(SpaceError::InvalidTimestamp(
            "expires timestamp cannot be negative".into(),
        ));
    }
    if let Some(n) = nonce
        && (n.is_empty() || n.len() > MAX_NONCE_BYTES)
    {
        return Err(SpaceError::InvalidSignatureHeader(format!(
            "nonce must be 1..={MAX_NONCE_BYTES} bytes"
        )));
    }
    let _ = Did::parse(audience_did).map_err(|e| SpaceError::InvalidDid(e.to_string()))?;

    let authorization = format!("{SPACE_AUTH_SCHEME} {credential_jwt}");
    let sig_params = format_signature_params(created, expires, nonce);
    let signature_input = format!("{SPACE_SIGNATURE_LABEL}={sig_params}");
    let base = build_signature_base(&authorization, audience_did, &sig_params);
    let raw_sig = proof_key.sign(base.as_bytes())?;
    let signature = format!(
        "{SPACE_SIGNATURE_LABEL}=:{}:",
        BASE64_STANDARD.encode(&raw_sig)
    );

    Ok(SpaceRequestHeaders {
        authorization,
        atproto_space_audience: audience_did.to_owned(),
        signature_input,
        signature,
    })
}

/// Verify an incoming RFC 9421 space credential presentation from HTTP headers
/// using default freshness bounds (300s age, 60s skew, 512-byte nonce).
pub async fn verify_credential_request<R: SigningKeyResolver + ?Sized>(
    headers: &HeaderMap,
    expected_audience: &str,
    now_secs: i64,
    resolver: &R,
) -> Result<VerifiedSpaceHeaders> {
    verify_credential_request_with_window(
        headers,
        expected_audience,
        now_secs,
        MAX_HTTP_SIGNATURE_AGE_SECS,
        MAX_HTTP_SIGNATURE_SKEW_SECS,
        MAX_NONCE_BYTES,
        resolver,
    )
    .await
}

/// Verify an incoming RFC 9421 space credential presentation with explicit freshness window bounds.
pub async fn verify_credential_request_with_window<R: SigningKeyResolver + ?Sized>(
    headers: &HeaderMap,
    expected_audience: &str,
    now_secs: i64,
    max_age_secs: i64,
    max_clock_skew_secs: i64,
    max_nonce_bytes: usize,
    resolver: &R,
) -> Result<VerifiedSpaceHeaders> {
    let auth_raw = single_header_str(headers, "authorization")?;
    let audience_raw = single_header_str(headers, SPACE_AUDIENCE_HEADER)?;
    let sig_input_raw = joined_header_str(headers, "signature-input")?;
    let sig_raw = joined_header_str(headers, "signature")?;

    verify_credential_headers(
        auth_raw,
        audience_raw,
        &sig_input_raw,
        &sig_raw,
        expected_audience,
        now_secs,
        max_age_secs,
        max_clock_skew_secs,
        max_nonce_bytes,
        resolver,
    )
    .await
}

/// Verify RFC 9421 space credential presentation headers given raw header strings.
#[allow(clippy::too_many_arguments)]
pub async fn verify_credential_headers<R: SigningKeyResolver + ?Sized>(
    authorization_header: &str,
    audience_header: &str,
    signature_input_header: &str,
    signature_header: &str,
    expected_audience: &str,
    now_secs: i64,
    max_age_secs: i64,
    max_clock_skew_secs: i64,
    max_nonce_bytes: usize,
    resolver: &R,
) -> Result<VerifiedSpaceHeaders> {
    let credential_jwt = extract_space_credential_jwt(authorization_header)?;
    let claims = verify_credential_token(credential_jwt, now_secs, resolver).await?;
    let sig = verify_http_signature_against_key(
        authorization_header,
        audience_header,
        signature_input_header,
        signature_header,
        expected_audience,
        &claims.cnf.kid,
        now_secs,
        max_age_secs,
        max_clock_skew_secs,
        max_nonce_bytes,
    )?;

    Ok(VerifiedSpaceHeaders {
        credential_jwt: sig.credential_jwt,
        claims,
        audience: sig.audience,
        nonce: sig.nonce,
        created: sig.created,
        expires: sig.expires,
        sig_params_line: sig.sig_params_line,
    })
}

/// Verify ONLY the RFC 9421 HTTP signature layer against a caller-supplied `cnf_did_key`,
/// supporting multi-line headers, `created` / `expires` / `nonce` bounds, RFC 8941 overwrite-last
/// parameter/dictionary rules, and both canonical low-S and high-S signatures.
#[allow(clippy::too_many_arguments)]
pub fn verify_http_signature_against_key(
    authorization_header: &str,
    audience_header: &str,
    signature_input_header: &str,
    signature_header: &str,
    expected_audience: &str,
    cnf_did_key: &str,
    now_secs: i64,
    max_age_secs: i64,
    max_clock_skew_secs: i64,
    max_nonce_bytes: usize,
) -> Result<VerifiedHttpSignature> {
    let credential_jwt = extract_space_credential_jwt(authorization_header)?;
    if audience_header.trim() != expected_audience {
        return Err(SpaceError::InvalidAudience {
            expected: expected_audience.to_owned(),
            actual: audience_header.to_owned(),
        });
    }

    let sig_input_dict = parse_dictionary(signature_input_header, DuplicatePolicy::OverwriteLast)?;
    let member = sig_input_dict.get(SPACE_SIGNATURE_LABEL).ok_or_else(|| {
        SpaceError::InvalidSignatureHeader(format!(
            "missing '{SPACE_SIGNATURE_LABEL}' in Signature-Input"
        ))
    })?;
    let (items, params) = match member {
        SfMember::InnerList(items, params) => (items, params),
        SfMember::Item(_) => {
            return Err(SpaceError::InvalidSignatureHeader(
                "Signature-Input member must be an inner list".into(),
            ));
        }
    };

    validate_covered_components(items)?;
    let (created, expires, nonce) = validate_signature_params(
        params,
        now_secs,
        max_age_secs,
        max_clock_skew_secs,
        max_nonce_bytes,
    )?;

    let sig_dict = parse_dictionary(signature_header, DuplicatePolicy::OverwriteLast)?;
    let sig_item = sig_dict
        .get(SPACE_SIGNATURE_LABEL)
        .and_then(SfMember::as_item)
        .ok_or_else(|| {
            SpaceError::InvalidSignatureHeader(format!(
                "missing '{SPACE_SIGNATURE_LABEL}' in Signature"
            ))
        })?;
    if !sig_item.params.is_empty() {
        return Err(SpaceError::InvalidSignatureHeader(
            "Signature byte sequence must not carry parameters".into(),
        ));
    }
    let sig_bytes = sig_item.bare.as_bytes().ok_or_else(|| {
        SpaceError::InvalidSignatureHeader("Signature value must be a byte sequence".into())
    })?;

    let sig_params_line = member.format();
    let base = build_signature_base(
        authorization_header.trim(),
        audience_header.trim(),
        &sig_params_line,
    );

    let cnf_key = PublicKey::from_did_key(cnf_did_key)
        .map_err(|e| SpaceError::InvalidKeyMaterial(format!("invalid cnf.kid: {e}")))?;

    if !cnf_key.is_valid_signature(
        sig_bytes,
        base.as_bytes(),
        ATProtoSignatureVerificationOptions::JWT,
    ) {
        return Err(SpaceError::InvalidSignature);
    }

    Ok(VerifiedHttpSignature {
        credential_jwt: credential_jwt.to_owned(),
        audience: audience_header.trim().to_owned(),
        created,
        expires,
        nonce,
        sig_params_line,
    })
}

fn single_header_str<'a>(headers: &'a HeaderMap, name: &str) -> Result<&'a str> {
    let mut iter = headers.get_all(name).iter();
    let first = iter
        .next()
        .ok_or_else(|| SpaceError::MissingHeader(name.to_owned()))?;
    if iter.next().is_some() {
        return Err(SpaceError::MalformedHeader(format!(
            "multiple '{name}' headers present"
        )));
    }
    first
        .to_str()
        .map_err(|_| SpaceError::MalformedHeader(format!("non-ASCII '{name}' header")))
}

fn joined_header_str(headers: &HeaderMap, name: &str) -> Result<String> {
    let mut parts = Vec::new();
    for val in headers.get_all(name) {
        let s = val
            .to_str()
            .map_err(|_| SpaceError::MalformedHeader(format!("non-ASCII '{name}' header")))?;
        parts.push(s);
    }
    if parts.is_empty() {
        return Err(SpaceError::MissingHeader(name.to_owned()));
    }
    Ok(parts.join(", "))
}

fn extract_space_credential_jwt(header_value: &str) -> Result<&str> {
    let trimmed = header_value.trim();
    let rest = trimmed.strip_prefix(SPACE_AUTH_SCHEME).ok_or_else(|| {
        SpaceError::Unauthorized("expected Atproto-Space-Credential scheme".into())
    })?;
    if !rest.starts_with(' ') {
        return Err(SpaceError::Unauthorized(
            "malformed Atproto-Space-Credential Authorization header".into(),
        ));
    }
    let jwt = rest[1..].trim();
    if jwt.is_empty() || jwt.contains(char::is_whitespace) {
        return Err(SpaceError::InvalidTokenFormat);
    }
    Ok(jwt)
}

fn validate_covered_components(items: &[SfItem]) -> Result<()> {
    if items.len() != 2 {
        return Err(SpaceError::UnsupportedSignatureComponent(format!(
            "expected exactly 2 covered components, got {}",
            items.len()
        )));
    }
    for (idx, expected) in ["authorization", SPACE_AUDIENCE_HEADER].iter().enumerate() {
        let item = &items[idx];
        if !item.params.is_empty() {
            return Err(SpaceError::UnsupportedSignatureComponent(
                "covered components must not have parameters".into(),
            ));
        }
        match item.bare.as_string_strict() {
            Some(name) if name == *expected => {}
            Some(other) => {
                return Err(SpaceError::UnsupportedSignatureComponent(format!(
                    "unexpected covered component '{other}' (expected '{expected}')"
                )));
            }
            None => {
                return Err(SpaceError::InvalidSignatureHeader(
                    "covered component identifier must be an RFC 8941 string".into(),
                ));
            }
        }
    }
    Ok(())
}

fn validate_signature_params(
    params: &[(String, SfBareItem)],
    now_secs: i64,
    max_age_secs: i64,
    max_clock_skew_secs: i64,
    max_nonce_bytes: usize,
) -> Result<(Option<i64>, Option<i64>, Option<String>)> {
    let mut created: Option<i64> = None;
    let mut expires: Option<i64> = None;
    let mut nonce: Option<String> = None;
    let mut tag_ok = false;

    for (k, v) in params {
        match k.as_str() {
            "created" => {
                let ts = v.as_int().ok_or_else(|| {
                    SpaceError::InvalidSignatureHeader(
                        "created parameter must be an integer".into(),
                    )
                })?;
                if ts < 0 {
                    return Err(SpaceError::InvalidSignatureHeader(
                        "created parameter must be non-negative".into(),
                    ));
                }
                created = Some(ts);
            }
            "expires" => {
                let ts = v.as_int().ok_or_else(|| {
                    SpaceError::InvalidSignatureHeader(
                        "expires parameter must be an integer".into(),
                    )
                })?;
                if ts < 0 {
                    return Err(SpaceError::InvalidSignatureHeader(
                        "expires parameter must be non-negative".into(),
                    ));
                }
                expires = Some(ts);
            }
            "nonce" => {
                let s = v.as_string_strict().ok_or_else(|| {
                    SpaceError::InvalidSignatureHeader("nonce parameter must be a string".into())
                })?;
                if s.is_empty() || s.len() > max_nonce_bytes {
                    return Err(SpaceError::InvalidSignatureHeader(format!(
                        "nonce must be 1..={max_nonce_bytes} bytes"
                    )));
                }
                nonce = Some(s.to_owned());
            }
            "tag" => {
                let s = v.as_string_strict().ok_or_else(|| {
                    SpaceError::InvalidSignatureHeader("tag parameter must be a string".into())
                })?;
                if s != SPACE_SIGNATURE_TAG {
                    return Err(SpaceError::InvalidSignatureHeader(format!(
                        "unexpected signature tag '{s}'"
                    )));
                }
                tag_ok = true;
            }
            other => {
                return Err(SpaceError::InvalidSignatureHeader(format!(
                    "disallowed or unknown signature parameter '{other}'"
                )));
            }
        }
    }

    if !tag_ok {
        return Err(SpaceError::InvalidSignatureHeader(
            "missing required tag=\"atproto-space-credential\" parameter".into(),
        ));
    }

    if let Some(c) = created
        && (c < now_secs.saturating_sub(max_age_secs)
            || c > now_secs.saturating_add(max_clock_skew_secs))
    {
        return Err(SpaceError::InvalidTimestamp(format!(
            "created={c} outside freshness window around now={now_secs}"
        )));
    }
    if let Some(e) = expires
        && e < now_secs.saturating_sub(max_clock_skew_secs)
    {
        return Err(SpaceError::InvalidTimestamp(format!(
            "expires={e} passed relative to now={now_secs}"
        )));
    }
    Ok((created, expires, nonce))
}

fn format_signature_params(
    created: Option<i64>,
    expires: Option<i64>,
    nonce: Option<&str>,
) -> String {
    use core::fmt::Write as _;
    let mut out = format!("(\"authorization\" \"{SPACE_AUDIENCE_HEADER}\")");
    if let Some(c) = created {
        let _ = write!(out, ";created={c}");
    }
    if let Some(e) = expires {
        let _ = write!(out, ";expires={e}");
    }
    if let Some(n) = nonce {
        let _ = write!(out, ";nonce=\"{}\"", escape_sf_string(n));
    }
    let _ = write!(out, ";tag=\"{SPACE_SIGNATURE_TAG}\"");
    out
}

fn build_signature_base(authorization: &str, audience: &str, sig_params: &str) -> String {
    format!(
        "\"authorization\": {authorization}\n\"{SPACE_AUDIENCE_HEADER}\": {audience}\n\"@signature-params\": {sig_params}"
    )
}
