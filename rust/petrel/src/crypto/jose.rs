//! ES256 wire encoding for the Petrel OAuth client.
use std::fmt;

use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use p256::ecdsa::{Signature, SigningKey, VerifyingKey, signature::Signer};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use zeroize::Zeroizing;

use super::{CryptoError, DpopSigner, EcPublicJwk};
use crate::rt::BoxFuture;

/// Maximum decoded length of either JSON segment of a compact JWS.
pub const MAX_JWS_JSON_BYTES: usize = 16 * 1024;

pub fn base64url(input: &[u8]) -> String {
    URL_SAFE_NO_PAD.encode(input)
}

/// Decodes strict, unpadded base64url with an allocation bound.
pub fn decode_base64url(input: &str, max_bytes: usize) -> Result<Vec<u8>, CryptoError> {
    let max_encoded = (max_bytes / 3)
        .saturating_mul(4)
        .saturating_add(match max_bytes % 3 {
            0 => 0,
            1 => 2,
            _ => 3,
        });
    if input.len() > max_encoded {
        return Err(CryptoError::TooLarge);
    }
    URL_SAFE_NO_PAD
        .decode(input)
        .map_err(|_| CryptoError::InvalidEncoding)
}

pub fn sha256(input: &[u8]) -> [u8; 32] {
    Sha256::digest(input).into()
}

pub fn random_bytes<const N: usize>() -> Result<[u8; N], CryptoError> {
    let mut bytes = [0; N];
    getrandom::getrandom(&mut bytes).map_err(|_| CryptoError::Entropy)?;
    Ok(bytes)
}

pub fn pkce_challenge(verifier: &str) -> String {
    base64url(&sha256(verifier.as_bytes()))
}

/// Creates a fresh RFC 7636 verifier. Never log this value.
pub fn pkce_verifier() -> Result<String, CryptoError> {
    let entropy = Zeroizing::new(random_bytes::<32>()?);
    Ok(base64url(entropy.as_slice()))
}

/// A public P-256 JWK. Member order is the RFC 7638 canonical order.
#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub(crate) struct Jwk {
    crv: &'static str,
    kty: &'static str,
    x: String,
    y: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct JwkFields {
    crv: String,
    kty: String,
    x: String,
    y: String,
}

impl<'de> Deserialize<'de> for Jwk {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        JwkFields::deserialize(deserializer)?
            .try_into()
            .map_err(serde::de::Error::custom)
    }
}

impl TryFrom<JwkFields> for Jwk {
    type Error = CryptoError;

    fn try_from(fields: JwkFields) -> Result<Self, Self::Error> {
        if fields.crv != "P-256" || fields.kty != "EC" {
            return Err(CryptoError::InvalidKey);
        }
        Self::from_coordinates(fields.x, fields.y)
    }
}

impl Jwk {
    /// Constructs a JWK from two 32-byte coordinates encoded as unpadded base64url.
    pub(crate) fn from_coordinates(x: String, y: String) -> Result<Self, CryptoError> {
        let key = Self {
            crv: "P-256",
            kty: "EC",
            x,
            y,
        };
        key.verifying_key()?;
        Ok(key)
    }

    /// RFC 7638 SHA-256 thumbprint with no optional header fields.
    fn thumbprint(&self) -> String {
        // Coordinates have been validated as base64url and never need JSON escaping.
        let canonical = format!(
            r#"{{"crv":"P-256","kty":"EC","x":"{}","y":"{}"}}"#,
            self.x, self.y,
        );
        base64url(&sha256(canonical.as_bytes()))
    }

    fn verifying_key(&self) -> Result<VerifyingKey, CryptoError> {
        let x = decode_base64url(&self.x, 32)?;
        let y = decode_base64url(&self.y, 32)?;
        if x.len() != 32 || y.len() != 32 {
            return Err(CryptoError::InvalidKey);
        }
        let mut sec1 = [4; 65];
        sec1[1..33].copy_from_slice(&x);
        sec1[33..].copy_from_slice(&y);
        VerifyingKey::from_sec1_bytes(&sec1).map_err(|_| CryptoError::InvalidKey)
    }
}

impl EcPublicJwk {
    /// Validates the coordinates and computes the RFC 7638 SHA-256 thumbprint.
    pub fn thumbprint(&self) -> Result<String, CryptoError> {
        Ok(Jwk::try_from(self)?.thumbprint())
    }
}

impl TryFrom<&EcPublicJwk> for Jwk {
    type Error = CryptoError;

    fn try_from(key: &EcPublicJwk) -> Result<Self, CryptoError> {
        Self::from_coordinates(key.x.clone(), key.y.clone())
    }
}

/// P-256 DPoP signer for embedders that keep software keys.
pub struct SoftwareDpopSigner {
    key: SigningKey,
    jwk: EcPublicJwk,
}

impl SoftwareDpopSigner {
    pub fn generate() -> Result<Self, CryptoError> {
        // Uniform rejection sampling without an entropy failure becoming a panic.
        loop {
            let candidate = Zeroizing::new(random_bytes::<32>()?);
            if let Ok(key) = Self::from_bytes(&candidate) {
                return Ok(key);
            }
        }
    }

    pub fn from_bytes(bytes: &[u8; 32]) -> Result<Self, CryptoError> {
        let key = SigningKey::from_slice(bytes).map_err(|_| CryptoError::InvalidKey)?;
        let point = key.verifying_key().to_encoded_point(false);
        let (Some(x), Some(y)) = (point.x(), point.y()) else {
            return Err(CryptoError::InvalidKey);
        };

        Ok(Self {
            key,
            jwk: EcPublicJwk {
                x: base64url(x),
                y: base64url(y),
            },
        })
    }

    /// Exports the software key for storage in a SecretStore.
    pub fn to_bytes(&self) -> Zeroizing<[u8; 32]> {
        let bytes = Zeroizing::new(self.key.to_bytes());
        let mut output = Zeroizing::new([0; 32]);
        output.copy_from_slice(&bytes[..]);
        output
    }

    pub(super) fn sign_raw(&self, input: &[u8]) -> Result<[u8; 64], CryptoError> {
        let signature: Signature = self
            .key
            .try_sign(input)
            .map_err(|_| CryptoError::SigningFailed)?;
        Ok(signature
            .normalize_s()
            .unwrap_or(signature)
            .to_bytes()
            .into())
    }
}

impl fmt::Debug for SoftwareDpopSigner {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SoftwareDpopSigner")
            .field("jwk", &self.jwk)
            .finish_non_exhaustive()
    }
}

impl DpopSigner for SoftwareDpopSigner {
    fn public_jwk(&self) -> EcPublicJwk {
        self.jwk.clone()
    }

    fn sign<'a>(&'a self, input: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], CryptoError>> {
        Box::pin(async move { self.sign_raw(input) })
    }
}

/// Normalizes an external signer's ES256 signature before putting it on the wire.
pub fn normalize_es256(signature: &[u8; 64]) -> Result<[u8; 64], CryptoError> {
    let signature = Signature::from_slice(signature).map_err(|_| CryptoError::InvalidSignature)?;
    Ok(signature
        .normalize_s()
        .unwrap_or(signature)
        .to_bytes()
        .into())
}

pub(crate) fn jws_signing_input(
    header: &impl Serialize,
    claims: &impl Serialize,
) -> Result<String, CryptoError> {
    let header = serde_json::to_vec(header).map_err(|_| CryptoError::InvalidJws)?;
    let claims = serde_json::to_vec(claims).map_err(|_| CryptoError::InvalidJws)?;
    if header.len() > MAX_JWS_JSON_BYTES || claims.len() > MAX_JWS_JSON_BYTES {
        return Err(CryptoError::TooLarge);
    }
    Ok(format!("{}.{}", base64url(&header), base64url(&claims)))
}

pub(crate) fn finish_es256_jws(
    mut input: String,
    signature: &[u8; 64],
) -> Result<String, CryptoError> {
    input.push('.');
    input.push_str(&base64url(&normalize_es256(signature)?));
    Ok(input)
}

pub(crate) struct CompactJws {
    #[cfg(test)]
    pub input: String,
    pub header: Vec<u8>,
    pub claims: Vec<u8>,
    pub signature: Vec<u8>,
}

pub(crate) fn split_compact_jws(compact: &str) -> Result<CompactJws, CryptoError> {
    // Bound the scan before splitting, including when the input has no dots.
    if compact.len() > 2 * (MAX_JWS_JSON_BYTES * 4).div_ceil(3) + 256 {
        return Err(CryptoError::TooLarge);
    }
    let (input, signature) = compact.rsplit_once('.').ok_or(CryptoError::InvalidJws)?;
    let (header, claims) = input.split_once('.').ok_or(CryptoError::InvalidJws)?;
    if header.is_empty() || claims.is_empty() || signature.is_empty() {
        return Err(CryptoError::InvalidJws);
    }
    Ok(CompactJws {
        #[cfg(test)]
        input: input.to_owned(),
        header: decode_base64url(header, MAX_JWS_JSON_BYTES)?,
        claims: decode_base64url(claims, MAX_JWS_JSON_BYTES)?,
        signature: decode_base64url(signature, 132)?,
    })
}

#[cfg(test)]
mod tests {
    use p256::ecdsa::signature::Verifier;
    use serde_json::json;

    use super::*;

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn swift_jwk_and_thumbprint() {
        let bytes = std::array::from_fn(|index| u8::try_from(index + 1).unwrap());
        let signer = SoftwareDpopSigner::from_bytes(&bytes).unwrap();
        let jwk = signer.public_jwk();
        // Fixed-key literals from OAuthCharacterizationTests.swift.
        assert_eq!(jwk.x, "UVw9brnjlrkE0_7Kf1T9zQzB6Ze_N13KUVrQpsO0A18");
        assert_eq!(jwk.y, "RTa-OlDzGPv5pUdZAqIhUCvvDVfgjFOyzApW8X2fk1Q");
        assert_eq!(
            jwk.thumbprint().unwrap(),
            "6UoWwDCkLjV0J-pQG8c0THxbVhBcpR0AZDift1Yl5DM"
        );
        assert_eq!(&*signer.to_bytes(), &bytes);
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn compact_es256_signatures_are_low_s() {
        let signer = SoftwareDpopSigner::generate().unwrap();
        let key = Jwk::try_from(&signer.public_jwk())
            .unwrap()
            .verifying_key()
            .unwrap();
        for counter in 0..32 {
            let input =
                jws_signing_input(&json!({"alg": "ES256"}), &json!({"i": counter})).unwrap();
            let raw = signer.sign_raw(input.as_bytes()).unwrap();
            let compact = finish_es256_jws(input, &raw).unwrap();
            let decoded = split_compact_jws(&compact).unwrap();
            let signature = Signature::from_slice(&decoded.signature).unwrap();
            assert!(signature.normalize_s().is_none());
            assert_eq!(decoded.header, br#"{"alg":"ES256"}"#);
            assert_eq!(decoded.claims, format!(r#"{{"i":{counter}}}"#).as_bytes());
            key.verify(decoded.input.as_bytes(), &signature).unwrap();
        }
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn rfc_7636_appendix_b_and_decode_bounds() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
        assert_eq!(
            pkce_challenge(verifier),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        );
        assert_eq!(pkce_verifier().unwrap().len(), 43);
        assert_eq!(decode_base64url("AA", 1).unwrap(), [0]);
        assert_eq!(decode_base64url("AA", 0), Err(CryptoError::TooLarge));
        assert_eq!(
            decode_base64url("AA==", 4),
            Err(CryptoError::InvalidEncoding)
        );
        assert_eq!(decode_base64url("AB", 4), Err(CryptoError::InvalidEncoding));
    }
}

#[cfg(test)]
impl Jwk {
    pub(crate) fn verify_test_signature(
        &self,
        input: &[u8],
        signature: &[u8],
    ) -> Result<(), CryptoError> {
        use p256::ecdsa::signature::Verifier;

        let signature =
            Signature::from_slice(signature).map_err(|_| CryptoError::InvalidSignature)?;
        if signature.normalize_s().is_some() {
            return Err(CryptoError::InvalidSignature);
        }
        self.verifying_key()?
            .verify(input, &signature)
            .map_err(|_| CryptoError::InvalidSignature)
    }
}
