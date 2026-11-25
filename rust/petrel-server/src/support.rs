use std::collections::HashSet;
use std::fmt;

use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use hmac::{Hmac, Mac};
use petrel::rt::{MaybeSend, MaybeSync};
use serde::de::{self, DeserializeSeed, MapAccess, SeqAccess, Visitor};
use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq as _;
use web_time::{SystemTime, UNIX_EPOCH};
use zeroize::Zeroizing;

use crate::error::OAuthServerError;

type HmacSha256 = Hmac<Sha256>;

/// Constant-time comparison helpers.
#[derive(Debug, Clone, Copy)]
pub struct ConstantTime;

impl ConstantTime {
    /// Compares two byte slices in constant time.
    pub fn equal_bytes(lhs: &[u8], rhs: &[u8]) -> bool {
        lhs.len() == rhs.len() && bool::from(lhs.ct_eq(rhs))
    }

    /// Compares two strings in constant time.
    pub fn equal(lhs: &str, rhs: &str) -> bool {
        Self::equal_bytes(lhs.as_bytes(), rhs.as_bytes())
    }
}

/// Encodes bytes as unpadded base64url.
pub fn base64url_encode(input: &[u8]) -> String {
    URL_SAFE_NO_PAD.encode(input)
}

/// Decodes strict unpadded base64url up to `max_bytes`.
pub fn base64url_decode(value: &str, max_bytes: usize) -> Result<Vec<u8>, OAuthServerError> {
    let max_encoded = (max_bytes / 3)
        .saturating_mul(4)
        .saturating_add(match max_bytes % 3 {
            0 => 0,
            1 => 2,
            _ => 3,
        });
    if value.len() > max_encoded {
        return Err(OAuthServerError::Malformed(
            "base64url input exceeds limit".into(),
        ));
    }
    URL_SAFE_NO_PAD
        .decode(value)
        .map_err(|_| OAuthServerError::Malformed("invalid base64url encoding".into()))
}

/// Computes SHA-256 over `input`.
pub fn sha256(input: &[u8]) -> [u8; 32] {
    Sha256::digest(input).into()
}

/// Injectable time source (Unix epoch seconds as `f64` or `i64`).
pub trait OAuthClock: MaybeSend + MaybeSync {
    /// Current Unix timestamp in whole seconds (truncated toward negative infinity).
    #[allow(clippy::cast_possible_truncation)]
    fn now_secs(&self) -> i64 {
        self.now_unix_f64().floor() as i64
    }

    /// Current Unix timestamp in seconds, possibly fractional.
    fn now_unix_f64(&self) -> f64;
}

/// System wall clock backed by `web_time::SystemTime` (native & wasm32).
#[derive(Debug, Default, Clone, Copy)]
pub struct SystemOAuthClock;

impl OAuthClock for SystemOAuthClock {
    fn now_unix_f64(&self) -> f64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0.0, |d| d.as_secs_f64())
    }
}

/// Injectable CSPRNG for opaque values (codes, tokens, request URIs, CSRF tokens).
pub trait OAuthRandomSource: MaybeSend + MaybeSync {
    /// Fills a vector of `count` unpredictable bytes.
    fn bytes(&self, count: usize) -> Vec<u8>;

    /// 32 random bytes encoded as 43 characters of unpadded base64url.
    fn opaque_value(&self) -> String {
        base64url_encode(&self.bytes(32))
    }

    /// Generates a random UUIDv4.
    fn uuid_v4(&self) -> uuid::Uuid {
        let raw = self.bytes(16);
        let mut buf = [0_u8; 16];
        buf.copy_from_slice(&raw[..16]);
        uuid::Builder::from_random_bytes(buf).into_uuid()
    }
}

/// System CSPRNG backed by `getrandom`.
#[derive(Debug, Default, Clone, Copy)]
pub struct SystemOAuthRandomSource;

impl OAuthRandomSource for SystemOAuthRandomSource {
    fn bytes(&self, count: usize) -> Vec<u8> {
        let mut out = vec![0_u8; count];
        if count > 0 {
            getrandom::getrandom(&mut out).expect("OS CSPRNG unavailable");
        }
        out
    }
}

/// Domain separation tags for keyed HMAC digests stored instead of raw secrets.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum DigestPurpose {
    RequestUri,
    AuthorizationCode,
    AccessToken,
    RefreshToken,
    DPoPProof,
    ClientAssertion,
    CodeChallenge,
    State,
    Device,
    DPoPNonce,
    BrowserFlow,
}

impl DigestPurpose {
    const fn as_str(self) -> &'static str {
        match self {
            Self::RequestUri => "request-uri",
            Self::AuthorizationCode => "authorization-code",
            Self::AccessToken => "access-token",
            Self::RefreshToken => "refresh-token",
            Self::DPoPProof => "dpop-jti",
            Self::ClientAssertion => "client-assertion-jti",
            Self::CodeChallenge => "code-challenge",
            Self::State => "state",
            Self::Device => "device",
            Self::DPoPNonce => "dpop-nonce",
            Self::BrowserFlow => "browser-flow",
        }
    }
}

/// Derives keyed HMAC-SHA256 digests (`HMAC-SHA256(secret, "petrel.oauth.<purpose>\0" || value)`).
#[derive(Clone)]
pub struct OAuthKeyedDigest {
    secret: Zeroizing<Vec<u8>>,
}

impl fmt::Debug for OAuthKeyedDigest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OAuthKeyedDigest")
            .field("secret", &"<redacted>")
            .finish()
    }
}

impl OAuthKeyedDigest {
    /// Creates a keyed digest instance; requires `secret.len() >= 32`.
    pub fn new(secret: impl Into<Vec<u8>>) -> Result<Self, OAuthServerError> {
        let secret = secret.into();
        if secret.len() < 32 {
            return Err(OAuthServerError::Malformed(
                "OAuth server secret must be at least 32 bytes".into(),
            ));
        }
        Ok(Self {
            secret: Zeroizing::new(secret),
        })
    }

    /// Computes the keyed digest of `value` for `purpose`.
    pub fn digest_str(&self, value: &str, purpose: DigestPurpose) -> Vec<u8> {
        self.digest_bytes(value.as_bytes(), purpose)
    }

    /// Computes the keyed digest of raw bytes for `purpose`.
    ///
    /// # Panics
    ///
    /// Never panics in practice because HMAC-SHA256 accepts keys of any length.
    pub fn digest_bytes(&self, value: &[u8], purpose: DigestPurpose) -> Vec<u8> {
        let mut mac =
            HmacSha256::new_from_slice(&self.secret).expect("HMAC accepts keys of any length");
        mac.update(b"petrel.oauth.");
        mac.update(purpose.as_str().as_bytes());
        mac.update(b"\0");
        mac.update(value);
        mac.finalize().into_bytes().to_vec()
    }
}

/// PKCE (RFC 7636) with the only transform the AT Protocol profile permits (`S256`).
#[derive(Debug, Clone, Copy)]
pub struct OAuthPkce;

impl OAuthPkce {
    /// `BASE64URL(SHA256(verifier))`.
    pub fn s256_challenge(verifier: &str) -> String {
        base64url_encode(&sha256(verifier.as_bytes()))
    }

    /// True when `challenge` matches the `S256` transform of `verifier`.
    pub fn verify_s256(verifier: &str, challenge: &str) -> bool {
        ConstantTime::equal(&Self::s256_challenge(verifier), challenge)
    }

    /// RFC 7636 §4.1: 43..=128 characters from `[A-Za-z0-9._~-]`.
    pub fn is_valid_verifier(value: &str) -> bool {
        (43..=128).contains(&value.len())
            && value
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'.' | b'_' | b'~'))
    }

    /// An S256 challenge is exactly 43 characters of unpadded base64url (32 bytes).
    pub fn is_valid_s256_challenge(value: &str) -> bool {
        value.len() == 43 && base64url_decode(value, 32).is_ok_and(|decoded| decoded.len() == 32)
    }
}

/// Validates JSON bytes for well-formedness and zero duplicate object member names at all depths.
#[derive(Debug, Clone, Copy)]
pub struct StrictJson;

impl StrictJson {
    const MAX_DEPTH: usize = 64;

    /// Rejects malformed JSON, trailing tokens, and any duplicate object keys.
    pub fn validate(data: &[u8]) -> Result<(), OAuthServerError> {
        let mut de = serde_json::Deserializer::from_slice(data);
        StrictSeed { depth: 0 }
            .deserialize(&mut de)
            .map_err(|err| OAuthServerError::Malformed(format!("invalid JSON: {err}")))?;
        de.end()
            .map_err(|err| OAuthServerError::Malformed(format!("trailing JSON data: {err}")))?;
        Ok(())
    }
}

struct StrictSeed {
    depth: usize,
}

impl<'de> DeserializeSeed<'de> for StrictSeed {
    type Value = ();

    fn deserialize<D: serde::Deserializer<'de>>(self, deserializer: D) -> Result<(), D::Error> {
        if self.depth >= StrictJson::MAX_DEPTH {
            return Err(de::Error::custom("JSON nesting depth exceeded"));
        }
        deserializer.deserialize_any(StrictVisitor { depth: self.depth })
    }
}

struct StrictVisitor {
    depth: usize,
}

impl<'de> Visitor<'de> for StrictVisitor {
    type Value = ();

    fn expecting(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("any valid JSON value without duplicate object keys")
    }

    fn visit_bool<E: de::Error>(self, _: bool) -> Result<(), E> {
        Ok(())
    }
    fn visit_i64<E: de::Error>(self, _: i64) -> Result<(), E> {
        Ok(())
    }
    fn visit_u64<E: de::Error>(self, _: u64) -> Result<(), E> {
        Ok(())
    }
    fn visit_f64<E: de::Error>(self, _: f64) -> Result<(), E> {
        Ok(())
    }
    fn visit_str<E: de::Error>(self, _: &str) -> Result<(), E> {
        Ok(())
    }
    fn visit_unit<E: de::Error>(self) -> Result<(), E> {
        Ok(())
    }

    fn visit_seq<A: SeqAccess<'de>>(self, mut seq: A) -> Result<(), A::Error> {
        while seq
            .next_element_seed(StrictSeed {
                depth: self.depth + 1,
            })?
            .is_some()
        {}
        Ok(())
    }

    fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> Result<(), A::Error> {
        let mut keys = HashSet::new();
        while let Some(key) = map.next_key::<String>()? {
            if !keys.insert(key) {
                return Err(de::Error::custom("duplicate JSON object key"));
            }
            map.next_value_seed(StrictSeed {
                depth: self.depth + 1,
            })?;
        }
        Ok(())
    }
}
