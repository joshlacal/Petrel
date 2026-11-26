use std::fmt;

use k256::ecdsa as k256_ecdsa;
use p256::ecdsa as p256_ecdsa;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use zeroize::Zeroizing;

use crate::error::OAuthServerError;
use crate::support::{ConstantTime, StrictJson, base64url_decode, base64url_encode, sha256};

/// Maximum compact JWT length accepted by the parser (bytes).
pub const MAX_COMPACT_JWT_BYTES: usize = 16_384;
/// Maximum decoded JWS header length accepted by the parser (bytes).
pub const MAX_JWT_HEADER_BYTES: usize = 4_096;
/// Maximum decoded JWS payload length accepted by the parser (bytes).
pub const MAX_JWT_PAYLOAD_BYTES: usize = 16_384;
/// Fixed length of a raw ECDSA `r || s` signature over P-256 or secp256k1.
pub const ECDSA_SIGNATURE_BYTES: usize = 64;
/// Fixed length of one uncompressed EC coordinate (`x` or `y`) on P-256 or secp256k1.
pub const EC_COORDINATE_BYTES: usize = 32;

/// JOSE signing algorithms supported by AT Protocol OAuth and service auth.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum OAuthJwsAlgorithm {
    /// ECDSA using P-256 and SHA-256 (`ES256`).
    #[serde(rename = "ES256")]
    Es256,
    /// ECDSA using secp256k1 and SHA-256 (`ES256K`).
    #[serde(rename = "ES256K")]
    Es256k,
}

impl OAuthJwsAlgorithm {
    /// JOSE wire identifier (`"ES256"` or `"ES256K"`).
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Es256 => "ES256",
            Self::Es256k => "ES256K",
        }
    }

    /// Parses a JOSE `alg` string.
    pub fn parse(value: &str) -> Result<Self, OAuthServerError> {
        match value {
            "ES256" => Ok(Self::Es256),
            "ES256K" => Ok(Self::Es256k),
            _ => Err(OAuthServerError::Unauthorized(format!(
                "unsupported JWS algorithm: {value}"
            ))),
        }
    }

    /// Elliptic curve paired with this algorithm.
    pub const fn curve(self) -> OAuthCurve {
        match self {
            Self::Es256 => OAuthCurve::P256,
            Self::Es256k => OAuthCurve::Secp256k1,
        }
    }
}

impl fmt::Display for OAuthJwsAlgorithm {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// Elliptic curves supported by `petrel-server`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum OAuthCurve {
    /// NIST P-256 (`P-256`).
    #[serde(rename = "P-256")]
    P256,
    /// secp256k1 (`secp256k1`).
    #[serde(rename = "secp256k1")]
    Secp256k1,
}

impl OAuthCurve {
    /// JOSE `crv` string.
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::P256 => "P-256",
            Self::Secp256k1 => "secp256k1",
        }
    }

    /// JWS `alg` paired with this curve.
    pub const fn algorithm(self) -> OAuthJwsAlgorithm {
        match self {
            Self::P256 => OAuthJwsAlgorithm::Es256,
            Self::Secp256k1 => OAuthJwsAlgorithm::Es256k,
        }
    }
}

impl fmt::Display for OAuthCurve {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// Low-S acceptance policy for ECDSA JWS verification.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum OAuthJwtSignatureEncoding {
    /// Rejects high-S malleable ECDSA signatures (AT Protocol-native rule).
    #[default]
    CanonicalLowS,
    /// Accepts both low-S and high-S signatures as permitted by RFC 7518 §3.4 (DPoP / client assertions).
    JoseInteroperable,
}

/// Public EC JSON Web Key validated upon construction or deserialization.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct OAuthJsonWebKey {
    /// Always `"EC"`.
    pub kty: String,
    /// Curve (`"P-256"` or `"secp256k1"`).
    pub crv: OAuthCurve,
    /// Optional public key use (`"sig"` if present).
    #[serde(rename = "use", skip_serializing_if = "Option::is_none")]
    pub use_: Option<String>,
    /// Optional key identifier.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub kid: Option<String>,
    /// Optional declared algorithm (`"ES256"` or `"ES256K"`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub alg: Option<OAuthJwsAlgorithm>,
    /// 32-byte base64url X coordinate.
    pub x: String,
    /// 32-byte base64url Y coordinate.
    pub y: String,
}

#[derive(Deserialize)]
struct RawJwk {
    kty: String,
    crv: String,
    #[serde(rename = "use")]
    use_: Option<String>,
    kid: Option<String>,
    alg: Option<String>,
    x: String,
    y: String,
    // Private / RSA / symmetric members MUST be rejected in public JWKs.
    d: Option<serde_json::Value>,
    p: Option<serde_json::Value>,
    q: Option<serde_json::Value>,
    dp: Option<serde_json::Value>,
    dq: Option<serde_json::Value>,
    qi: Option<serde_json::Value>,
    k: Option<serde_json::Value>,
    oth: Option<serde_json::Value>,
}

impl<'de> Deserialize<'de> for OAuthJsonWebKey {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let raw = RawJwk::deserialize(deserializer)?;
        if raw.d.is_some()
            || raw.p.is_some()
            || raw.q.is_some()
            || raw.dp.is_some()
            || raw.dq.is_some()
            || raw.qi.is_some()
            || raw.k.is_some()
            || raw.oth.is_some()
        {
            return Err(serde::de::Error::custom(
                "public JWK must not contain private key material",
            ));
        }
        if raw.kty != "EC" {
            return Err(serde::de::Error::custom("unsupported JWK key type"));
        }
        let crv = match raw.crv.as_str() {
            "P-256" => OAuthCurve::P256,
            "secp256k1" => OAuthCurve::Secp256k1,
            _ => return Err(serde::de::Error::custom("unsupported EC curve")),
        };
        if let Some(ref use_) = raw.use_
            && use_ != "sig"
        {
            return Err(serde::de::Error::custom("JWK use must be sig"));
        }
        let alg = match raw.alg {
            Some(ref alg_str) => {
                let parsed = OAuthJwsAlgorithm::parse(alg_str)
                    .map_err(|err| serde::de::Error::custom(err.to_string()))?;
                if parsed.curve() != crv {
                    return Err(serde::de::Error::custom("JWK alg does not match curve"));
                }
                Some(parsed)
            }
            None => None,
        };
        Self::from_coordinates_b64(crv, raw.x, raw.y, raw.kid, raw.use_, alg)
            .map_err(|err| serde::de::Error::custom(err.to_string()))
    }
}

impl OAuthJsonWebKey {
    /// Constructs and validates an EC public JWK from raw 32-byte `x` and `y` coordinates.
    pub fn from_coordinates(
        curve: OAuthCurve,
        x: &[u8],
        y: &[u8],
        kid: Option<String>,
        use_: Option<String>,
        alg: Option<OAuthJwsAlgorithm>,
    ) -> Result<Self, OAuthServerError> {
        if x.len() != EC_COORDINATE_BYTES || y.len() != EC_COORDINATE_BYTES {
            return Err(OAuthServerError::Malformed(
                "EC JWK coordinates must be 32 bytes".into(),
            ));
        }
        let x_b64 = base64url_encode(x);
        let y_b64 = base64url_encode(y);
        Self::from_coordinates_b64(curve, x_b64, y_b64, kid, use_, alg)
    }

    fn from_coordinates_b64(
        curve: OAuthCurve,
        x: String,
        y: String,
        kid: Option<String>,
        use_: Option<String>,
        alg: Option<OAuthJwsAlgorithm>,
    ) -> Result<Self, OAuthServerError> {
        if let Some(ref u) = use_
            && u != "sig"
        {
            return Err(OAuthServerError::Malformed("JWK use must be sig".into()));
        }
        if let Some(a) = alg
            && a.curve() != curve
        {
            return Err(OAuthServerError::Malformed(
                "JWK alg does not match crv".into(),
            ));
        }
        let x_bytes = base64url_decode(&x, EC_COORDINATE_BYTES)?;
        let y_bytes = base64url_decode(&y, EC_COORDINATE_BYTES)?;
        if x_bytes.len() != EC_COORDINATE_BYTES || y_bytes.len() != EC_COORDINATE_BYTES {
            return Err(OAuthServerError::Malformed(
                "EC JWK coordinates must be exactly 32 bytes".into(),
            ));
        }
        // Canonical unpadded fixed-length base64url prevents duplicate representations.
        let x_canonical = base64url_encode(&x_bytes);
        let y_canonical = base64url_encode(&y_bytes);
        if x != x_canonical || y != y_canonical {
            return Err(OAuthServerError::Malformed(
                "EC JWK coordinate encoding is non-canonical".into(),
            ));
        }
        let mut sec1 = Vec::with_capacity(1 + 2 * EC_COORDINATE_BYTES);
        sec1.push(0x04);
        sec1.extend_from_slice(&x_bytes);
        sec1.extend_from_slice(&y_bytes);
        validate_uncompressed_point(curve, &sec1)?;

        Ok(Self {
            kty: "EC".to_owned(),
            crv: curve,
            use_,
            kid,
            alg,
            x,
            y,
        })
    }

    /// Constructs an EC public JWK from SEC1 compressed (33-byte) or uncompressed (65-byte) bytes.
    pub fn from_sec1(
        curve: OAuthCurve,
        sec1: &[u8],
        kid: Option<String>,
        alg: Option<OAuthJwsAlgorithm>,
    ) -> Result<Self, OAuthServerError> {
        let uncompressed = decompress_sec1(curve, sec1)?;
        Self::from_coordinates(
            curve,
            &uncompressed[1..33],
            &uncompressed[33..65],
            kid,
            Some("sig".to_owned()),
            alg,
        )
    }

    /// Parses a `did:key:z...` multikey string (`P-256` or `secp256k1`) into a JWK.
    pub fn from_did_key(did_key: &str) -> Result<Self, OAuthServerError> {
        let encoded = did_key.strip_prefix("did:key:z").ok_or_else(|| {
            OAuthServerError::InvalidIdentifier("did:key must start with did:key:z".into())
        })?;
        let raw = bs58::decode(encoded)
            .into_vec()
            .map_err(|_| OAuthServerError::InvalidIdentifier("invalid did:key base58".into()))?;
        if raw.len() != 35 {
            return Err(OAuthServerError::InvalidIdentifier(
                "unsupported did:key payload length".into(),
            ));
        }
        let curve = match (raw[0], raw[1]) {
            (0x80, 0x24) => OAuthCurve::P256,
            (0xe7, 0x01) => OAuthCurve::Secp256k1,
            _ => {
                return Err(OAuthServerError::InvalidIdentifier(
                    "unsupported did:key multicodec curve".into(),
                ));
            }
        };
        Self::from_sec1(curve, &raw[2..], None, None)
    }

    /// Uncompressed 65-byte SEC1 representation (`0x04 || x || y`).
    pub fn to_sec1_uncompressed(&self) -> Result<[u8; 65], OAuthServerError> {
        let x = base64url_decode(&self.x, EC_COORDINATE_BYTES)?;
        let y = base64url_decode(&self.y, EC_COORDINATE_BYTES)?;
        if x.len() != EC_COORDINATE_BYTES || y.len() != EC_COORDINATE_BYTES {
            return Err(OAuthServerError::Malformed(
                "invalid JWK coordinate length".into(),
            ));
        }
        let mut out = [0_u8; 65];
        out[0] = 0x04;
        out[1..33].copy_from_slice(&x);
        out[33..65].copy_from_slice(&y);
        Ok(out)
    }

    /// Compressed 33-byte SEC1 representation.
    pub fn to_sec1_compressed(&self) -> Result<[u8; 33], OAuthServerError> {
        let uncompressed = self.to_sec1_uncompressed()?;
        match self.crv {
            OAuthCurve::P256 => {
                use p256::elliptic_curve::sec1::ToEncodedPoint as _;
                let pk = p256::PublicKey::from_sec1_bytes(&uncompressed)
                    .map_err(|_| OAuthServerError::Malformed("invalid P-256 key".into()))?;
                let pt = pk.to_encoded_point(true);
                let bytes: [u8; 33] = pt
                    .as_bytes()
                    .try_into()
                    .map_err(|_| OAuthServerError::Malformed("invalid compressed point".into()))?;
                Ok(bytes)
            }
            OAuthCurve::Secp256k1 => {
                use k256::elliptic_curve::sec1::ToEncodedPoint as _;
                let pk = k256::PublicKey::from_sec1_bytes(&uncompressed)
                    .map_err(|_| OAuthServerError::Malformed("invalid secp256k1 key".into()))?;
                let pt = pk.to_encoded_point(true);
                let bytes: [u8; 33] = pt
                    .as_bytes()
                    .try_into()
                    .map_err(|_| OAuthServerError::Malformed("invalid compressed point".into()))?;
                Ok(bytes)
            }
        }
    }

    /// Encodes this key as an AT Protocol `did:key:z...` identifier.
    pub fn did_key(&self) -> Result<String, OAuthServerError> {
        let compressed = self.to_sec1_compressed()?;
        let prefix: [u8; 2] = match self.crv {
            OAuthCurve::P256 => [0x80, 0x24],
            OAuthCurve::Secp256k1 => [0xe7, 0x01],
        };
        let mut buf = [0_u8; 35];
        buf[..2].copy_from_slice(&prefix);
        buf[2..].copy_from_slice(&compressed);
        Ok(format!("did:key:z{}", bs58::encode(buf).into_string()))
    }

    /// Returns a copy with `kid` and `use` stripped (used for DPoP `jwk` headers).
    #[must_use]
    pub fn without_key_id(&self) -> Self {
        Self {
            kty: self.kty.clone(),
            crv: self.crv,
            use_: None,
            kid: None,
            alg: None,
            x: self.x.clone(),
            y: self.y.clone(),
        }
    }

    /// RFC 7638 SHA-256 JWK thumbprint encoded as unpadded base64url.
    ///
    /// Canonical member order for `kty == "EC"`: `crv`, `kty`, `x`, `y`.
    pub fn thumbprint(&self) -> String {
        // Coordinates and curve identifiers are base64url / fixed ASCII tokens needing no JSON escaping.
        let canonical = format!(
            "{{\"crv\":\"{}\",\"kty\":\"EC\",\"x\":\"{}\",\"y\":\"{}\"}}",
            self.crv.as_str(),
            self.x,
            self.y
        );
        base64url_encode(&sha256(canonical.as_bytes()))
    }

    /// Verifies a raw 64-byte `r || s` ECDSA signature over `signing_input` (hashed with SHA-256).
    pub fn verify_signature(
        &self,
        signature: &[u8],
        signing_input: &[u8],
        encoding: OAuthJwtSignatureEncoding,
    ) -> bool {
        if signature.len() != ECDSA_SIGNATURE_BYTES {
            return false;
        }
        let Ok(sec1) = self.to_sec1_uncompressed() else {
            return false;
        };
        match self.crv {
            OAuthCurve::P256 => verify_p256(&sec1, signature, signing_input, encoding),
            OAuthCurve::Secp256k1 => verify_k256(&sec1, signature, signing_input, encoding),
        }
    }
}

fn validate_uncompressed_point(curve: OAuthCurve, sec1: &[u8]) -> Result<(), OAuthServerError> {
    match curve {
        OAuthCurve::P256 => {
            p256::PublicKey::from_sec1_bytes(sec1)
                .map_err(|_| OAuthServerError::Malformed("invalid P-256 public key".into()))?;
        }
        OAuthCurve::Secp256k1 => {
            k256::PublicKey::from_sec1_bytes(sec1)
                .map_err(|_| OAuthServerError::Malformed("invalid secp256k1 public key".into()))?;
        }
    }
    Ok(())
}

fn decompress_sec1(curve: OAuthCurve, sec1: &[u8]) -> Result<[u8; 65], OAuthServerError> {
    match curve {
        OAuthCurve::P256 => {
            use p256::elliptic_curve::sec1::ToEncodedPoint as _;
            let pk = p256::PublicKey::from_sec1_bytes(sec1)
                .map_err(|_| OAuthServerError::Malformed("invalid P-256 public key".into()))?;
            let pt = pk.to_encoded_point(false);
            pt.as_bytes()
                .try_into()
                .map_err(|_| OAuthServerError::Malformed("invalid P-256 point".into()))
        }
        OAuthCurve::Secp256k1 => {
            use k256::elliptic_curve::sec1::ToEncodedPoint as _;
            let pk = k256::PublicKey::from_sec1_bytes(sec1)
                .map_err(|_| OAuthServerError::Malformed("invalid secp256k1 public key".into()))?;
            let pt = pk.to_encoded_point(false);
            pt.as_bytes()
                .try_into()
                .map_err(|_| OAuthServerError::Malformed("invalid secp256k1 point".into()))
        }
    }
}

fn verify_p256(
    sec1: &[u8],
    signature: &[u8],
    signing_input: &[u8],
    encoding: OAuthJwtSignatureEncoding,
) -> bool {
    use p256_ecdsa::signature::Verifier as _;
    let Ok(vk) = p256_ecdsa::VerifyingKey::from_sec1_bytes(sec1) else {
        return false;
    };
    let Ok(sig) = p256_ecdsa::Signature::from_slice(signature) else {
        return false;
    };
    let normalized = sig.normalize_s();
    match encoding {
        OAuthJwtSignatureEncoding::CanonicalLowS => {
            if normalized.is_some() {
                return false;
            }
            vk.verify(signing_input, &sig).is_ok()
        }
        OAuthJwtSignatureEncoding::JoseInteroperable => {
            let check_sig = normalized.unwrap_or(sig);
            vk.verify(signing_input, &check_sig).is_ok()
        }
    }
}

fn verify_k256(
    sec1: &[u8],
    signature: &[u8],
    signing_input: &[u8],
    encoding: OAuthJwtSignatureEncoding,
) -> bool {
    use k256_ecdsa::signature::Verifier as _;
    let Ok(vk) = k256_ecdsa::VerifyingKey::from_sec1_bytes(sec1) else {
        return false;
    };
    let Ok(sig) = k256_ecdsa::Signature::from_slice(signature) else {
        return false;
    };
    let normalized = sig.normalize_s();
    match encoding {
        OAuthJwtSignatureEncoding::CanonicalLowS => {
            if normalized.is_some() {
                return false;
            }
            vk.verify(signing_input, &sig).is_ok()
        }
        OAuthJwtSignatureEncoding::JoseInteroperable => {
            let check_sig = normalized.unwrap_or(sig);
            vk.verify(signing_input, &check_sig).is_ok()
        }
    }
}

/// JSON Web Key Set (`{"keys": [...]}`) containing validated public signing keys.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct OAuthJsonWebKeySet {
    /// Public verification keys.
    pub keys: Vec<OAuthJsonWebKey>,
}

impl OAuthJsonWebKeySet {
    /// Constructs a JWKS from validated keys.
    pub fn new(keys: Vec<OAuthJsonWebKey>) -> Self {
        Self { keys }
    }

    /// Strictly decodes a fetched JWKS, rejecting duplicate JSON member names and malformed supported EC keys
    /// while skipping unsupported key types, non-signature keys, or entries carrying private material.
    pub fn decode_validated(data: &[u8]) -> Result<Self, OAuthServerError> {
        #[derive(Deserialize)]
        struct ProbeDoc {
            keys: Vec<serde_json::Value>,
        }
        StrictJson::validate(data)?;
        let doc: ProbeDoc = serde_json::from_slice(data)
            .map_err(|_| OAuthServerError::Malformed("JWKS document is invalid".into()))?;
        let mut accepted = Vec::new();
        for entry in doc.keys {
            let obj = entry.as_object().ok_or_else(|| {
                OAuthServerError::Malformed("JWKS key entry is not an object".into())
            })?;
            let has_private = ["d", "p", "q", "dp", "dq", "qi", "k", "oth"]
                .iter()
                .any(|k| obj.contains_key(*k));
            if has_private {
                continue;
            }
            let Some(kty) = obj.get("kty").and_then(serde_json::Value::as_str) else {
                return Err(OAuthServerError::Malformed("JWKS key missing kty".into()));
            };
            let crv = obj.get("crv").and_then(serde_json::Value::as_str);
            let use_ = obj.get("use").and_then(serde_json::Value::as_str);
            let is_supported_ec = kty == "EC"
                && matches!(crv, Some("P-256" | "secp256k1"))
                && matches!(use_, None | Some("sig"));
            if !is_supported_ec {
                continue;
            }
            let key: OAuthJsonWebKey = serde_json::from_value(entry)
                .map_err(|_| OAuthServerError::Malformed("JWKS EC key entry is invalid".into()))?;
            accepted.push(key);
        }
        Ok(Self { keys: accepted })
    }

    /// Selects a key matching `kid`, or the sole key when `kid` is `None`.
    pub fn select(&self, kid: Option<&str>) -> Result<&OAuthJsonWebKey, OAuthServerError> {
        if let Some(kid) = kid {
            self.keys
                .iter()
                .find(|k| k.kid.as_deref() == Some(kid))
                .ok_or_else(|| {
                    OAuthServerError::Unauthorized("JWT kid is not present in JWKS".into())
                })
        } else if self.keys.len() == 1 {
            Ok(&self.keys[0])
        } else {
            Err(OAuthServerError::Unauthorized(
                "JWT key selection is ambiguous".into(),
            ))
        }
    }
}

/// Private ECDSA signing key (`ES256` or `ES256K`) for minting tokens, assertions, and DPoP proofs.
#[derive(Clone)]
pub struct OAuthSigningKey {
    /// JWS signing algorithm.
    pub algorithm: OAuthJwsAlgorithm,
    /// Optional key identifier included in signed headers / JWKS.
    pub key_id: Option<String>,
    raw_secret: Zeroizing<[u8; 32]>,
}

impl fmt::Debug for OAuthSigningKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OAuthSigningKey")
            .field("algorithm", &self.algorithm)
            .field("key_id", &self.key_id)
            .field("raw_secret", &"<redacted>")
            .finish()
    }
}

impl OAuthSigningKey {
    /// Generates a fresh random signing key on `algorithm`.
    pub fn generate(
        algorithm: OAuthJwsAlgorithm,
        key_id: Option<String>,
    ) -> Result<Self, OAuthServerError> {
        loop {
            let mut raw = Zeroizing::new([0_u8; 32]);
            getrandom::getrandom(&mut raw[..])
                .map_err(|err| OAuthServerError::Unavailable(format!("CSPRNG error: {err}")))?;
            if let Ok(mut key) = Self::from_raw(algorithm, None, &raw[..]) {
                key.key_id = key_id;
                return Ok(key);
            }
        }
    }

    /// Loads a 32-byte big-endian scalar signing key.
    pub fn from_raw(
        algorithm: OAuthJwsAlgorithm,
        key_id: Option<String>,
        raw_bytes: &[u8],
    ) -> Result<Self, OAuthServerError> {
        let raw_arr: [u8; 32] = raw_bytes.try_into().map_err(|_| {
            OAuthServerError::Malformed("EC private key must be exactly 32 bytes".into())
        })?;
        match algorithm {
            OAuthJwsAlgorithm::Es256 => {
                p256_ecdsa::SigningKey::from_slice(&raw_arr).map_err(|_| {
                    OAuthServerError::Malformed("P-256 private key is invalid".into())
                })?;
            }
            OAuthJwsAlgorithm::Es256k => {
                k256_ecdsa::SigningKey::from_slice(&raw_arr).map_err(|_| {
                    OAuthServerError::Malformed("secp256k1 private key is invalid".into())
                })?;
            }
        }
        Ok(Self {
            algorithm,
            key_id,
            raw_secret: Zeroizing::new(raw_arr),
        })
    }

    /// Raw 32-byte private key scalar wrapped in [`Zeroizing`].
    pub fn raw_secret(&self) -> Zeroizing<[u8; 32]> {
        self.raw_secret.clone()
    }

    /// Corresponding public JSON Web Key.
    pub fn public_jwk(&self, include_key_id: bool) -> Result<OAuthJsonWebKey, OAuthServerError> {
        let sec1 = match self.algorithm {
            OAuthJwsAlgorithm::Es256 => {
                let sk = p256_ecdsa::SigningKey::from_slice(&self.raw_secret[..])
                    .map_err(|_| OAuthServerError::Malformed("P-256 key invalid".into()))?;
                sk.verifying_key()
                    .to_encoded_point(false)
                    .as_bytes()
                    .to_vec()
            }
            OAuthJwsAlgorithm::Es256k => {
                let sk = k256_ecdsa::SigningKey::from_slice(&self.raw_secret[..])
                    .map_err(|_| OAuthServerError::Malformed("secp256k1 key invalid".into()))?;
                sk.verifying_key()
                    .to_encoded_point(false)
                    .as_bytes()
                    .to_vec()
            }
        };
        OAuthJsonWebKey::from_coordinates(
            self.algorithm.curve(),
            &sec1[1..33],
            &sec1[33..65],
            if include_key_id {
                self.key_id.clone()
            } else {
                None
            },
            if include_key_id {
                Some("sig".to_owned())
            } else {
                None
            },
            if include_key_id {
                Some(self.algorithm)
            } else {
                None
            },
        )
    }

    /// Signs `signing_input` and returns a canonical low-S 64-byte `r || s` signature.
    pub fn sign(
        &self,
        signing_input: &[u8],
    ) -> Result<[u8; ECDSA_SIGNATURE_BYTES], OAuthServerError> {
        match self.algorithm {
            OAuthJwsAlgorithm::Es256 => {
                use p256_ecdsa::signature::Signer as _;
                let sk = p256_ecdsa::SigningKey::from_slice(&self.raw_secret[..])
                    .map_err(|_| OAuthServerError::Malformed("P-256 key invalid".into()))?;
                let sig: p256_ecdsa::Signature = sk.sign(signing_input);
                let low_s = sig.normalize_s().unwrap_or(sig);
                let mut out = [0_u8; 64];
                out.copy_from_slice(&low_s.to_bytes());
                Ok(out)
            }
            OAuthJwsAlgorithm::Es256k => {
                use k256_ecdsa::signature::Signer as _;
                let sk = k256_ecdsa::SigningKey::from_slice(&self.raw_secret[..])
                    .map_err(|_| OAuthServerError::Malformed("secp256k1 key invalid".into()))?;
                let sig: k256_ecdsa::Signature = sk.sign(signing_input);
                let low_s = sig.normalize_s().unwrap_or(sig);
                let mut out = [0_u8; 64];
                out.copy_from_slice(&low_s.to_bytes());
                Ok(out)
            }
        }
    }

    /// RFC 7638 thumbprint of this signing key's public key.
    pub fn thumbprint(&self) -> Result<String, OAuthServerError> {
        Ok(self.public_jwk(false)?.thumbprint())
    }
}

/// Decoded JOSE compact JWT header.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OAuthJwtHeader {
    /// Signature algorithm (`ES256` or `ES256K`).
    pub alg: String,
    /// Optional token media type (`dpop+jwt`, `at+jwt`, `JWT`, etc.).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub typ: Option<String>,
    /// Optional key identifier.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub kid: Option<String>,
    /// Optional embedded public JWK (used by DPoP proofs).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jwk: Option<OAuthJsonWebKey>,
    /// Rejected if present: unsupported critical headers.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub crit: Option<serde_json::Value>,
    /// Rejected if present: unsupported RFC 7797 detached/unencoded payload flag.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub b64: Option<serde_json::Value>,
}

/// `aud` claim accepting either a single JSON string or a JSON array of strings.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum OAuthJwtAudience {
    Single(String),
    Many(Vec<String>),
}

impl OAuthJwtAudience {
    /// Returns true if `expected` appears as the single string or an array member.
    pub fn contains(&self, expected: &str) -> bool {
        match self {
            Self::Single(s) => ConstantTime::equal(s, expected),
            Self::Many(list) => list.iter().any(|s| ConstantTime::equal(s, expected)),
        }
    }

    /// Returns all audience values as slices.
    pub fn as_slices(&self) -> Vec<&str> {
        match self {
            Self::Single(s) => vec![s.as_str()],
            Self::Many(list) => list.iter().map(String::as_str).collect(),
        }
    }
}

/// Integer `NumericDate` representation accepting JSON integers or finite non-negative/bounded floats truncated toward zero.
fn deserialize_numeric_date<'de, D>(deserializer: D) -> Result<Option<i64>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    #[derive(Deserialize)]
    #[serde(untagged)]
    enum Num {
        Int(i64),
        Float(f64),
    }
    let val: Option<Num> = Option::deserialize(deserializer)?;
    match val {
        None => Ok(None),
        Some(Num::Int(i)) => Ok(Some(i)),
        #[allow(clippy::cast_precision_loss, clippy::cast_possible_truncation)]
        Some(Num::Float(f)) => {
            if !f.is_finite() || f < (i64::MIN as f64) || f >= (i64::MAX as f64) {
                return Err(serde::de::Error::custom("JWT NumericDate out of range"));
            }
            Ok(Some(f.trunc() as i64))
        }
    }
}

/// Standard RFC 7519 registered claims validated alongside custom claims.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct OAuthJwtRegisteredClaims {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub iss: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub sub: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub aud: Option<OAuthJwtAudience>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "deserialize_numeric_date"
    )]
    pub exp: Option<i64>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "deserialize_numeric_date"
    )]
    pub nbf: Option<i64>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "deserialize_numeric_date"
    )]
    pub iat: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub jti: Option<String>,
}

/// Verification constraints checked after cryptographic signature verification.
#[derive(Debug, Clone)]
pub struct OAuthJwtVerificationConstraints {
    pub allowed_algorithms: Vec<OAuthJwsAlgorithm>,
    pub expected_type: Option<String>,
    pub expected_issuer: Option<String>,
    pub expected_audience: Option<String>,
    pub require_issued_at: bool,
    pub require_expiration: bool,
    pub maximum_age_secs: Option<i64>,
    pub max_lifetime_secs: Option<i64>,
    pub clock_skew_secs: i64,
    pub now_secs: i64,
    pub signature_encoding: OAuthJwtSignatureEncoding,
}

impl OAuthJwtVerificationConstraints {
    /// Creates standard verification constraints with `clock_skew_secs = 5`.
    pub fn new(now_secs: i64) -> Self {
        Self {
            allowed_algorithms: vec![OAuthJwsAlgorithm::Es256, OAuthJwsAlgorithm::Es256k],
            expected_type: None,
            expected_issuer: None,
            expected_audience: None,
            require_issued_at: false,
            require_expiration: false,
            maximum_age_secs: None,
            max_lifetime_secs: None,
            clock_skew_secs: 5,
            now_secs,
            signature_encoding: OAuthJwtSignatureEncoding::CanonicalLowS,
        }
    }
}

/// A cryptographically verified compact JWT paired with its parsed header, claims, and optional embedded JWK.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthVerifiedJwt<C> {
    pub header: OAuthJwtHeader,
    pub claims: C,
    pub registered: OAuthJwtRegisteredClaims,
    pub embedded_jwk: Option<OAuthJsonWebKey>,
}

struct ParsedJwt<'a> {
    header: OAuthJwtHeader,
    payload: Vec<u8>,
    signing_input: &'a [u8],
    signature: [u8; ECDSA_SIGNATURE_BYTES],
}

/// Compact JWS signing and strict verification utilities.
#[derive(Debug, Clone, Copy)]
pub struct OAuthCompactJwt;

impl OAuthCompactJwt {
    /// Signs `claims` as a compact JWS (`header.payload.signature`).
    pub fn sign<C: Serialize>(
        claims: &C,
        key: &OAuthSigningKey,
        typ: Option<&str>,
        embeds_public_key: bool,
    ) -> Result<String, OAuthServerError> {
        let header = OAuthJwtHeader {
            alg: key.algorithm.as_str().to_owned(),
            typ: typ.map(str::to_owned),
            kid: if embeds_public_key {
                None
            } else {
                key.key_id.clone()
            },
            jwk: if embeds_public_key {
                Some(key.public_jwk(false)?)
            } else {
                None
            },
            crit: None,
            b64: None,
        };
        let header_json = serde_json::to_vec(&header)
            .map_err(|_| OAuthServerError::Malformed("JWT header cannot be encoded".into()))?;
        let payload_json = serde_json::to_vec(claims)
            .map_err(|_| OAuthServerError::Malformed("JWT claims cannot be encoded".into()))?;
        let signing_input = format!(
            "{}.{}",
            base64url_encode(&header_json),
            base64url_encode(&payload_json)
        );
        let signature = key.sign(signing_input.as_bytes())?;
        Ok(format!("{signing_input}.{}", base64url_encode(&signature)))
    }

    /// Parses only the header without checking the signature (for pre-selection by `iss`/`kid`).
    pub fn parse_unverified_header(compact: &str) -> Result<OAuthJwtHeader, OAuthServerError> {
        Ok(Self::parse(compact)?.header)
    }

    /// Parses header and decoded claims without verifying the signature (e.g., to inspect `iss` or `sub` for key resolution).
    pub fn parse_unverified<C: DeserializeOwned>(
        compact: &str,
    ) -> Result<(OAuthJwtHeader, C, OAuthJwtRegisteredClaims), OAuthServerError> {
        let parsed = Self::parse(compact)?;
        let registered: OAuthJwtRegisteredClaims = Self::strict_decode(&parsed.payload)?;
        let claims: C = Self::strict_decode(&parsed.payload)?;
        Ok((parsed.header, claims, registered))
    }

    /// Verifies `compact` against a single explicit public key.
    pub fn verify_with_jwk<C: DeserializeOwned>(
        compact: &str,
        key: &OAuthJsonWebKey,
        constraints: &OAuthJwtVerificationConstraints,
    ) -> Result<OAuthVerifiedJwt<C>, OAuthServerError> {
        let parsed = Self::parse(compact)?;
        if parsed.header.jwk.is_some() {
            return Err(OAuthServerError::Unauthorized(
                "unexpected embedded JWK in non-DPoP JWT".into(),
            ));
        }
        let alg = Self::check_header(&parsed.header, constraints)?;
        if alg.curve() != key.crv {
            return Err(OAuthServerError::Unauthorized(
                "JWT algorithm does not match verification key curve".into(),
            ));
        }
        if let Some(expected_alg) = key.alg
            && expected_alg != alg
        {
            return Err(OAuthServerError::Unauthorized(
                "JWT algorithm does not match JWK alg".into(),
            ));
        }
        if let (Some(header_kid), Some(jwk_kid)) = (&parsed.header.kid, &key.kid)
            && header_kid != jwk_kid
        {
            return Err(OAuthServerError::Unauthorized(
                "JWT kid does not match key".into(),
            ));
        }
        if !key.verify_signature(
            &parsed.signature,
            parsed.signing_input,
            constraints.signature_encoding,
        ) {
            return Err(OAuthServerError::Unauthorized(
                "JWT signature verification failed".into(),
            ));
        }
        Self::decode_and_validate_claims(parsed.header, &parsed.payload, None, constraints)
    }

    /// Verifies `compact` against a JWKS (selecting by `header.kid`).
    pub fn verify_with_jwks<C: DeserializeOwned>(
        compact: &str,
        jwks: &OAuthJsonWebKeySet,
        constraints: &OAuthJwtVerificationConstraints,
    ) -> Result<OAuthVerifiedJwt<C>, OAuthServerError> {
        let parsed = Self::parse(compact)?;
        if parsed.header.jwk.is_some() {
            return Err(OAuthServerError::Unauthorized(
                "unexpected embedded JWK in JWKS-verified JWT".into(),
            ));
        }
        let alg = Self::check_header(&parsed.header, constraints)?;
        let key = jwks.select(parsed.header.kid.as_deref())?;
        if alg.curve() != key.crv {
            return Err(OAuthServerError::Unauthorized(
                "JWT algorithm does not match JWK curve".into(),
            ));
        }
        if let Some(expected_alg) = key.alg
            && expected_alg != alg
        {
            return Err(OAuthServerError::Unauthorized(
                "JWT algorithm does not match JWK alg".into(),
            ));
        }
        if !key.verify_signature(
            &parsed.signature,
            parsed.signing_input,
            constraints.signature_encoding,
        ) {
            return Err(OAuthServerError::Unauthorized(
                "JWT signature verification failed".into(),
            ));
        }
        Self::decode_and_validate_claims(parsed.header, &parsed.payload, None, constraints)
    }

    /// Verifies a DPoP proof (`typ = "dpop+jwt"`, embedded public `jwk`, no `kid`).
    pub fn verify_dpop_proof<C: DeserializeOwned>(
        compact: &str,
        constraints: &OAuthJwtVerificationConstraints,
    ) -> Result<OAuthVerifiedJwt<C>, OAuthServerError> {
        let parsed = Self::parse(compact)?;
        if parsed.header.kid.is_some() {
            return Err(OAuthServerError::Malformed(
                "DPoP proof must not carry kid".into(),
            ));
        }
        let jwk = parsed.header.jwk.clone().ok_or_else(|| {
            OAuthServerError::Malformed("DPoP proof must carry embedded jwk".into())
        })?;
        let alg = Self::check_header(&parsed.header, constraints)?;
        if alg.curve() != jwk.crv {
            return Err(OAuthServerError::Malformed(
                "DPoP alg does not match embedded jwk crv".into(),
            ));
        }
        if !jwk.verify_signature(
            &parsed.signature,
            parsed.signing_input,
            constraints.signature_encoding,
        ) {
            return Err(OAuthServerError::Unauthorized(
                "DPoP proof signature verification failed".into(),
            ));
        }
        Self::decode_and_validate_claims(parsed.header, &parsed.payload, Some(jwk), constraints)
    }

    fn parse(compact: &str) -> Result<ParsedJwt<'_>, OAuthServerError> {
        if compact.len() > MAX_COMPACT_JWT_BYTES {
            return Err(OAuthServerError::Malformed("JWT is too large".into()));
        }
        let mut parts = compact.split('.');
        let header_b64 = parts.next().ok_or_else(|| {
            OAuthServerError::Malformed("JWT must be compact serialization".into())
        })?;
        let payload_b64 = parts.next().ok_or_else(|| {
            OAuthServerError::Malformed("JWT must be compact serialization".into())
        })?;
        let sig_b64 = parts.next().ok_or_else(|| {
            OAuthServerError::Malformed("JWT must be compact serialization".into())
        })?;
        if parts.next().is_some() {
            return Err(OAuthServerError::Malformed(
                "JWT must have exactly three compact segments".into(),
            ));
        }
        let header_bytes = base64url_decode(header_b64, MAX_JWT_HEADER_BYTES)?;
        let payload = base64url_decode(payload_b64, MAX_JWT_PAYLOAD_BYTES)?;
        let sig_bytes = base64url_decode(sig_b64, ECDSA_SIGNATURE_BYTES)?;
        let signature: [u8; ECDSA_SIGNATURE_BYTES] = sig_bytes
            .try_into()
            .map_err(|_| OAuthServerError::Malformed("JWT signature length is invalid".into()))?;
        let header: OAuthJwtHeader = Self::strict_decode(&header_bytes)?;
        if header.crit.is_some() || header.b64.is_some() {
            return Err(OAuthServerError::Malformed(
                "JWT uses unsupported critical JOSE header semantics".into(),
            ));
        }
        let signing_input_len = header_b64.len() + 1 + payload_b64.len();
        Ok(ParsedJwt {
            header,
            payload,
            signing_input: &compact.as_bytes()[..signing_input_len],
            signature,
        })
    }

    fn check_header(
        header: &OAuthJwtHeader,
        constraints: &OAuthJwtVerificationConstraints,
    ) -> Result<OAuthJwsAlgorithm, OAuthServerError> {
        let alg = OAuthJwsAlgorithm::parse(&header.alg)?;
        if !constraints.allowed_algorithms.contains(&alg) {
            return Err(OAuthServerError::Unauthorized(format!(
                "JWT algorithm {alg} is not permitted"
            )));
        }
        if let Some(ref expected_type) = constraints.expected_type
            && header.typ.as_deref() != Some(expected_type.as_str())
        {
            return Err(OAuthServerError::Malformed(format!(
                "JWT typ must be {expected_type}"
            )));
        }
        Ok(alg)
    }

    fn decode_and_validate_claims<C: DeserializeOwned>(
        header: OAuthJwtHeader,
        payload: &[u8],
        embedded_jwk: Option<OAuthJsonWebKey>,
        constraints: &OAuthJwtVerificationConstraints,
    ) -> Result<OAuthVerifiedJwt<C>, OAuthServerError> {
        let registered: OAuthJwtRegisteredClaims = Self::strict_decode(payload)?;
        Self::validate_registered(&registered, constraints)?;
        let claims: C = Self::strict_decode(payload)?;
        Ok(OAuthVerifiedJwt {
            header,
            claims,
            registered,
            embedded_jwk,
        })
    }

    fn strict_decode<T: DeserializeOwned>(data: &[u8]) -> Result<T, OAuthServerError> {
        StrictJson::validate(data)?;
        serde_json::from_slice(data)
            .map_err(|err| OAuthServerError::Malformed(format!("invalid JSON: {err}")))
    }

    fn validate_registered(
        claims: &OAuthJwtRegisteredClaims,
        constraints: &OAuthJwtVerificationConstraints,
    ) -> Result<(), OAuthServerError> {
        if constraints.clock_skew_secs < 0 {
            return Err(OAuthServerError::Malformed(
                "JWT clock skew policy is invalid".into(),
            ));
        }
        if let Some(ref expected_iss) = constraints.expected_issuer
            && claims.iss.as_deref() != Some(expected_iss.as_str())
        {
            return Err(OAuthServerError::Unauthorized(
                "JWT issuer is invalid".into(),
            ));
        }
        if let Some(ref expected_aud) = constraints.expected_audience
            && !claims
                .aud
                .as_ref()
                .is_some_and(|aud| aud.contains(expected_aud))
        {
            return Err(OAuthServerError::Unauthorized(
                "JWT audience is invalid".into(),
            ));
        }
        let now = constraints.now_secs;
        let skew = constraints.clock_skew_secs;
        if constraints.require_issued_at && claims.iat.is_none() {
            return Err(OAuthServerError::Malformed("JWT iat is required".into()));
        }
        if constraints.require_expiration && claims.exp.is_none() {
            return Err(OAuthServerError::Malformed("JWT exp is required".into()));
        }
        if let Some(iat) = claims.iat {
            let latest_iat = now
                .checked_add(skew)
                .ok_or_else(|| OAuthServerError::Malformed("JWT time policy overflow".into()))?;
            if iat > latest_iat {
                return Err(OAuthServerError::Unauthorized(
                    "JWT iat is in the future".into(),
                ));
            }
            if let Some(max_age) = constraints.maximum_age_secs {
                if max_age <= 0 {
                    return Err(OAuthServerError::Malformed(
                        "JWT maximum age policy is invalid".into(),
                    ));
                }
                let cutoff = now
                    .checked_sub(max_age)
                    .and_then(|t| t.checked_sub(skew))
                    .ok_or_else(|| {
                        OAuthServerError::Malformed("JWT time policy underflow".into())
                    })?;
                if iat < cutoff {
                    return Err(OAuthServerError::Expired);
                }
            }
        }
        if let Some(nbf) = claims.nbf {
            let latest = now
                .checked_add(skew)
                .ok_or_else(|| OAuthServerError::Malformed("JWT time policy overflow".into()))?;
            if nbf > latest {
                return Err(OAuthServerError::Unauthorized(
                    "JWT is not yet valid".into(),
                ));
            }
        }
        if let Some(exp) = claims.exp {
            let earliest_exp = now
                .checked_sub(skew)
                .ok_or_else(|| OAuthServerError::Malformed("JWT time policy underflow".into()))?;
            if exp < earliest_exp {
                return Err(OAuthServerError::Expired);
            }
            if let Some(iat) = claims.iat {
                if exp < iat {
                    return Err(OAuthServerError::Malformed("JWT exp precedes iat".into()));
                }
                if let Some(max_lifetime) = constraints.max_lifetime_secs {
                    if max_lifetime <= 0 {
                        return Err(OAuthServerError::Malformed(
                            "JWT maximum lifetime policy is invalid".into(),
                        ));
                    }
                    let lifetime = exp.checked_sub(iat).ok_or_else(|| {
                        OAuthServerError::Unauthorized("JWT lifetime overflow".into())
                    })?;
                    if lifetime > max_lifetime {
                        return Err(OAuthServerError::Unauthorized(
                            "JWT lifetime is too long".into(),
                        ));
                    }
                }
            }
        }
        Ok(())
    }
}
