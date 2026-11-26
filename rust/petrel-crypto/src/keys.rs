//! AT Protocol keys, keypairs, signers, verifiers, and curve-agnostic entry points.

use std::fmt;
use std::str::FromStr;

use k256::ecdsa::signature::{Signer as _, Verifier as _};
use p256::elliptic_curve::sec1::ToEncodedPoint as _;
use sha2::{Digest, Sha256};
use zeroize::Zeroizing;

use crate::base58::Base58BTC;
use crate::codecs::Hex;
use crate::curve::ATProtoKeyCurve;
use crate::error::PetrelCryptoError;
use crate::rt::{BoxFuture, MaybeSend, MaybeSync};
use crate::scalar::{self, SCALAR_BYTE_COUNT};
use crate::signature::{ATProtoSignature, ATProtoSignatureVerificationOptions};

const DID_KEY_PREFIX: &str = "did:key:";

/// Type alias matching Swift's `ATProtoPublicKey`.
pub type ATProtoPublicKey = PublicKey;

/// A validated AT Protocol public key on either supported curve (`P256` or `Secp256k1`).
///
/// Stores the 33-byte compressed SEC1 point, proven on-curve at construction.
#[derive(Clone, PartialEq, Eq, Hash)]
pub struct PublicKey {
    curve: ATProtoKeyCurve,
    compressed: [u8; 33],
}

impl PublicKey {
    /// Creates a key from a SEC1 point: 33 bytes compressed or 65 bytes uncompressed (`0x04 || X || Y`).
    pub fn from_sec1(curve: ATProtoKeyCurve, bytes: &[u8]) -> Result<Self, PetrelCryptoError> {
        let compressed: [u8; 33] = match curve {
            ATProtoKeyCurve::P256 => {
                if !matches!(
                    (bytes.len(), bytes.first().copied()),
                    (33, Some(0x02 | 0x03)) | (65, Some(0x04))
                ) {
                    return Err(PetrelCryptoError::Malformed(
                        "P-256 public key must be a 33- or 65-byte SEC1 point".into(),
                    ));
                }
                let key = p256::PublicKey::from_sec1_bytes(bytes).map_err(|_| {
                    PetrelCryptoError::Malformed(
                        "P-256 public key is not a point on the curve".into(),
                    )
                })?;
                key.to_encoded_point(true)
                    .as_bytes()
                    .try_into()
                    .map_err(|_| {
                        PetrelCryptoError::Malformed(
                            "P-256 public key could not be serialized".into(),
                        )
                    })?
            }
            ATProtoKeyCurve::Secp256k1 => {
                if !matches!(
                    (bytes.len(), bytes.first().copied()),
                    (33, Some(0x02 | 0x03)) | (65, Some(0x04))
                ) {
                    return Err(PetrelCryptoError::Malformed(
                        "K-256 public key must be a 33- or 65-byte SEC1 point".into(),
                    ));
                }
                let key = k256::PublicKey::from_sec1_bytes(bytes).map_err(|_| {
                    PetrelCryptoError::Malformed(
                        "K-256 public key is not a point on the curve".into(),
                    )
                })?;
                key.to_encoded_point(true)
                    .as_bytes()
                    .try_into()
                    .map_err(|_| {
                        PetrelCryptoError::Malformed(
                            "K-256 public key could not be serialized".into(),
                        )
                    })?
            }
        };
        Ok(Self { curve, compressed })
    }

    /// Parses a `did:key` identifier (`did:key:z...`) for P-256 or K-256.
    pub fn from_did_key(did_key: &str) -> Result<Self, PetrelCryptoError> {
        let multikey = did_key
            .strip_prefix(DID_KEY_PREFIX)
            .ok_or_else(|| PetrelCryptoError::InvalidIdentifier("did:key".into()))?;
        Self::from_multikey(multikey)
    }

    /// Parses a canonical multikey (`z` + base58btc(multicodec varint + 33-byte compressed point)).
    pub fn from_multikey(multikey: &str) -> Result<Self, PetrelCryptoError> {
        let decoded = decode_base58_multibase(multikey, "multikey")?;
        if decoded.len() != 35 {
            return Err(PetrelCryptoError::InvalidIdentifier(
                "multikey is not a compressed P-256 or K-256 public key".into(),
            ));
        }
        let curve = ATProtoKeyCurve::ALL
            .into_iter()
            .find(|c| decoded[..2] == c.public_key_multicodec_prefix())
            .ok_or_else(|| {
                PetrelCryptoError::InvalidIdentifier(
                    "multikey is not a compressed P-256 or K-256 public key".into(),
                )
            })?;
        let point = &decoded[2..];
        let key = Self::from_sec1(curve, point).map_err(|_| {
            PetrelCryptoError::InvalidIdentifier("multikey is not a point on its curve".into())
        })?;
        if key.compressed != point {
            return Err(PetrelCryptoError::InvalidIdentifier(
                "multikey is not canonical".into(),
            ));
        }
        Ok(key)
    }

    /// Parses the legacy multibase encoding (`z` + base58btc(SEC1 point), no multicodec prefix).
    pub fn from_legacy_multibase(
        multibase: &str,
        curve: ATProtoKeyCurve,
    ) -> Result<Self, PetrelCryptoError> {
        let decoded = decode_base58_multibase(multibase, "legacy verification method multibase")?;
        Self::from_sec1(curve, &decoded).map_err(|_| {
            PetrelCryptoError::InvalidIdentifier(format!(
                "legacy {} verification method",
                curve.as_str()
            ))
        })
    }

    /// Reads a key from a DID document verification method (`type` and `publicKeyMultibase`).
    pub fn from_verification_method(
        method_type: &str,
        public_key_multibase: &str,
    ) -> Result<Self, PetrelCryptoError> {
        match method_type {
            "Multikey" => Self::from_multikey(public_key_multibase),
            t if t == ATProtoKeyCurve::P256.legacy_verification_method_type() => {
                Self::from_legacy_multibase(public_key_multibase, ATProtoKeyCurve::P256)
            }
            t if t == ATProtoKeyCurve::Secp256k1.legacy_verification_method_type() => {
                Self::from_legacy_multibase(public_key_multibase, ATProtoKeyCurve::Secp256k1)
            }
            other => Err(PetrelCryptoError::UnsupportedAlgorithm(format!(
                "verification method type {other}"
            ))),
        }
    }

    /// The curve this key belongs to.
    pub const fn curve(&self) -> ATProtoKeyCurve {
        self.curve
    }

    /// The JOSE `alg` value (`"ES256"` or `"ES256K"`).
    pub const fn jwt_algorithm(&self) -> &'static str {
        self.curve.jwt_algorithm()
    }

    /// The 33-byte compressed SEC1 point (`0x02`/`0x03 || X`).
    pub const fn compressed_representation(&self) -> &[u8; 33] {
        &self.compressed
    }

    /// The 65-byte uncompressed SEC1 point (`0x04 || X || Y`).
    ///
    /// # Panics
    ///
    /// Never panics for a constructed [`PublicKey`], whose compressed point was
    /// validated on the curve at construction.
    pub fn uncompressed_representation(&self) -> [u8; 65] {
        match self.curve {
            ATProtoKeyCurve::P256 => {
                // `compressed` was validated as a P-256 point at construction.
                let key = p256::PublicKey::from_sec1_bytes(&self.compressed)
                    .expect("validated P-256 compressed point");
                key.to_encoded_point(false)
                    .as_bytes()
                    .try_into()
                    .expect("uncompressed P-256 point is 65 bytes")
            }
            ATProtoKeyCurve::Secp256k1 => {
                let key = k256::PublicKey::from_sec1_bytes(&self.compressed)
                    .expect("validated K-256 compressed point");
                key.to_encoded_point(false)
                    .as_bytes()
                    .try_into()
                    .expect("uncompressed K-256 point is 65 bytes")
            }
        }
    }

    /// Multicodec prefix followed by the 33-byte compressed point (35 bytes).
    pub fn multikey_bytes(&self) -> [u8; 35] {
        let mut bytes = [0_u8; 35];
        bytes[..2].copy_from_slice(&self.curve.public_key_multicodec_prefix());
        bytes[2..].copy_from_slice(&self.compressed);
        bytes
    }

    /// The canonical multikey string (`z...`).
    pub fn multikey(&self) -> String {
        format!("z{}", Base58BTC::encode(&self.multikey_bytes()))
    }

    /// The `did:key` identifier (`did:key:z...`).
    pub fn did_key(&self) -> String {
        format!("{DID_KEY_PREFIX}{}", self.multikey())
    }

    /// The deprecated legacy multibase encoding (`z` + base58btc of the uncompressed point).
    pub fn legacy_multibase(&self) -> String {
        format!(
            "z{}",
            Base58BTC::encode(&self.uncompressed_representation())
        )
    }

    /// Verifies `signature` over `SHA-256(message)` under `ATProtoSignatureVerificationOptions::STRICT`.
    pub fn verify_strict(&self, signature: &[u8], message: &[u8]) -> bool {
        self.is_valid_signature(
            signature,
            message,
            ATProtoSignatureVerificationOptions::STRICT,
        )
    }

    /// Verifies an ECDSA signature over `SHA-256(message)` under the given `options`.
    pub fn is_valid_signature(
        &self,
        signature: &[u8],
        message: &[u8],
        options: ATProtoSignatureVerificationOptions,
    ) -> bool {
        for compact in ATProtoSignature::compact_candidates(signature, self.curve, options) {
            if !scalar::is_structurally_valid(&compact, self.curve) {
                continue;
            }
            let is_low = scalar::is_low(&compact[SCALAR_BYTE_COUNT..], self.curve);
            if !(is_low || options.allow_high_s) {
                continue;
            }
            if self.verifies_structurally_valid_compact(&compact, message) {
                return true;
            }
        }
        false
    }

    fn verifies_structurally_valid_compact(&self, compact: &[u8; 64], message: &[u8]) -> bool {
        match self.curve {
            ATProtoKeyCurve::P256 => {
                let Ok(vk) = p256::ecdsa::VerifyingKey::from_sec1_bytes(&self.compressed) else {
                    return false;
                };
                let Ok(sig) = p256::ecdsa::Signature::from_bytes(compact.into()) else {
                    return false;
                };
                vk.verify(message, &sig).is_ok()
            }
            ATProtoKeyCurve::Secp256k1 => {
                let Ok(vk) = k256::ecdsa::VerifyingKey::from_sec1_bytes(&self.compressed) else {
                    return false;
                };
                // Normalize high-S to low-S after the caller's policy check above.
                let low_s = scalar::low_s_form(compact, ATProtoKeyCurve::Secp256k1);
                let Ok(sig) = k256::ecdsa::Signature::from_bytes((&low_s).into()) else {
                    return false;
                };
                vk.verify(message, &sig).is_ok()
            }
        }
    }
}

impl fmt::Debug for PublicKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "PublicKey({})", self.did_key())
    }
}

impl fmt::Display for PublicKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.did_key())
    }
}

impl FromStr for PublicKey {
    type Err = PetrelCryptoError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::from_did_key(s)
    }
}

pub(crate) fn decode_base58_multibase(
    value: &str,
    context: &str,
) -> Result<Vec<u8>, PetrelCryptoError> {
    let encoded = value
        .strip_prefix('z')
        .filter(|_| value.len() <= 256)
        .ok_or_else(|| {
            PetrelCryptoError::InvalidIdentifier(format!(
                "{context} must be base58btc with a z prefix"
            ))
        })?;
    let decoded = Base58BTC::decode(encoded).map_err(|_| {
        PetrelCryptoError::InvalidIdentifier(format!("{context} is not canonical base58btc"))
    })?;
    if Base58BTC::encode(&decoded) != encoded {
        return Err(PetrelCryptoError::InvalidIdentifier(format!(
            "{context} is not canonical base58btc"
        )));
    }
    Ok(decoded)
}

/// Anything that can produce AT Protocol signatures (in-memory keys, hardware signers, remote signers).
///
/// `sign` receives the unhashed message bytes, hashes with SHA-256, and returns a
/// 64-byte compact low-S `r || s` signature.
pub trait ATProtoSigner: MaybeSend + MaybeSync {
    /// The curve signatures are produced on.
    fn curve(&self) -> ATProtoKeyCurve;

    /// The JOSE `alg` value for this signer (`"ES256"` or `"ES256K"`).
    fn jwt_algorithm(&self) -> &'static str {
        self.curve().jwt_algorithm()
    }

    /// Signs `message` (unhashed), returning a 64-byte compact low-S signature.
    fn sign<'a>(&'a self, message: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], PetrelCryptoError>>;
}

/// An [`ATProtoSigner`] that also knows its public key.
pub trait ATProtoKeypair: ATProtoSigner {
    /// The public half of the key.
    fn public_key(&self) -> &PublicKey;

    /// The public key as a `did:key` identifier.
    fn did_key(&self) -> String {
        self.public_key().did_key()
    }

    /// The public key as a multikey string.
    fn multikey(&self) -> String {
        self.public_key().multikey()
    }
}

/// A keypair whose 32-byte private scalar can leave the process.
pub trait ATProtoExportableKeypair: ATProtoKeypair {
    /// Exports the 32-byte big-endian private scalar.
    fn export_raw_representation(&self) -> Result<Zeroizing<[u8; 32]>, PetrelCryptoError>;

    /// Exports the private scalar as 64 lowercase hex characters.
    fn export_hex(&self) -> Result<Zeroizing<String>, PetrelCryptoError> {
        let raw = self.export_raw_representation()?;
        Ok(Zeroizing::new(Hex::encode(&*raw)))
    }

    /// Exports the private scalar as a self-describing private multikey (`z` + base58btc(prefix || scalar)).
    fn export_multibase(&self) -> Result<Zeroizing<String>, PetrelCryptoError> {
        let raw = self.export_raw_representation()?;
        let mut buf = Zeroizing::new([0_u8; 34]);
        buf[..2].copy_from_slice(&self.curve().private_key_multicodec_prefix());
        buf[2..].copy_from_slice(&*raw);
        Ok(Zeroizing::new(format!("z{}", Base58BTC::encode(&*buf))))
    }
}

/// Anything that can verify an AT Protocol signature.
pub trait ATProtoVerifier: MaybeSend + MaybeSync {
    /// The curve signatures are expected on.
    fn curve(&self) -> ATProtoKeyCurve;

    /// Verifies `signature` over `SHA-256(message)` under `options`.
    fn is_valid_signature(
        &self,
        signature: &[u8],
        message: &[u8],
        options: ATProtoSignatureVerificationOptions,
    ) -> bool;
}

impl ATProtoVerifier for PublicKey {
    fn curve(&self) -> ATProtoKeyCurve {
        self.curve
    }

    fn is_valid_signature(
        &self,
        signature: &[u8],
        message: &[u8],
        options: ATProtoSignatureVerificationOptions,
    ) -> bool {
        Self::is_valid_signature(self, signature, message, options)
    }
}

/// Curve-tagged in-memory ECDSA private key with zeroized scalar storage.
#[derive(Clone)]
pub struct PrivateKey {
    public_key: PublicKey,
    raw: Zeroizing<[u8; 32]>,
}

impl PrivateKey {
    /// Generates a new random keypair on `curve` using OS/Web entropy.
    pub fn generate(curve: ATProtoKeyCurve) -> Result<Self, PetrelCryptoError> {
        loop {
            let candidate = Zeroizing::new(random_array::<32>()?);
            if let Ok(key) = Self::from_raw(curve, &*candidate) {
                return Ok(key);
            }
        }
    }

    /// Generates a new random K-256 keypair (the AT Protocol default).
    pub fn generate_k256() -> Result<Self, PetrelCryptoError> {
        Self::generate(ATProtoKeyCurve::Secp256k1)
    }

    /// Imports a private key from its 32-byte big-endian scalar (`0 < d < n`).
    pub fn from_raw(curve: ATProtoKeyCurve, raw: &[u8]) -> Result<Self, PetrelCryptoError> {
        let bytes: [u8; 32] = raw.try_into().map_err(|_| {
            PetrelCryptoError::Malformed(format!(
                "{} private key must be a 32-byte scalar in 1 ..< n",
                curve_label(curve)
            ))
        })?;
        let public_key = match curve {
            ATProtoKeyCurve::P256 => {
                let signing =
                    p256::ecdsa::SigningKey::from_bytes((&bytes).into()).map_err(|_| {
                        PetrelCryptoError::Malformed(
                            "P-256 private key must be a 32-byte scalar in 1 ..< n".into(),
                        )
                    })?;
                let compressed = signing.verifying_key().to_encoded_point(true);
                PublicKey::from_sec1(ATProtoKeyCurve::P256, compressed.as_bytes())?
            }
            ATProtoKeyCurve::Secp256k1 => {
                let signing =
                    k256::ecdsa::SigningKey::from_bytes((&bytes).into()).map_err(|_| {
                        PetrelCryptoError::Malformed(
                            "K-256 private key is not a valid scalar".into(),
                        )
                    })?;
                let compressed = signing.verifying_key().to_encoded_point(true);
                PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, compressed.as_bytes())?
            }
        };
        Ok(Self {
            public_key,
            raw: Zeroizing::new(bytes),
        })
    }

    /// Imports a private key from 64 hex characters.
    pub fn from_hex(curve: ATProtoKeyCurve, hex: &str) -> Result<Self, PetrelCryptoError> {
        let raw = decode_private_hex(hex)?;
        Self::from_raw(curve, &raw)
    }

    /// Imports a private key from a self-describing private multikey (`z...`).
    pub fn from_multibase(private_multibase: &str) -> Result<Self, PetrelCryptoError> {
        let (curve, scalar) = decode_private_multibase(private_multibase)?;
        let curve = curve.ok_or_else(|| {
            PetrelCryptoError::Malformed(
                "private key multibase has no multicodec prefix naming its curve".into(),
            )
        })?;
        Self::from_raw(curve, &scalar)
    }

    /// The curve this key belongs to.
    pub const fn curve(&self) -> ATProtoKeyCurve {
        self.public_key.curve()
    }

    /// The public half of the key.
    pub const fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    /// Signs `SHA-256(message)` synchronously, always returning 64-byte compact low-S `r || s`.
    pub fn sign_sync(&self, message: &[u8]) -> Result<[u8; 64], PetrelCryptoError> {
        match self.curve() {
            ATProtoKeyCurve::P256 => {
                let signing =
                    p256::ecdsa::SigningKey::from_bytes((&*self.raw).into()).map_err(|_| {
                        PetrelCryptoError::Malformed("P-256 private key is invalid".into())
                    })?;
                let sig: p256::ecdsa::Signature = signing
                    .try_sign(message)
                    .map_err(|_| PetrelCryptoError::Malformed("P-256 signing failed".into()))?;
                let raw: [u8; 64] = sig.normalize_s().unwrap_or(sig).to_bytes().into();
                Ok(scalar::low_s_form(&raw, ATProtoKeyCurve::P256))
            }
            ATProtoKeyCurve::Secp256k1 => {
                let signing =
                    k256::ecdsa::SigningKey::from_bytes((&*self.raw).into()).map_err(|_| {
                        PetrelCryptoError::Malformed(
                            "K-256 private key is not a valid scalar".into(),
                        )
                    })?;
                let sig: k256::ecdsa::Signature = signing
                    .try_sign(message)
                    .map_err(|_| PetrelCryptoError::Malformed("K-256 signing failed".into()))?;
                let raw: [u8; 64] = sig.normalize_s().unwrap_or(sig).to_bytes().into();
                if !scalar::is_structurally_valid(&raw, ATProtoKeyCurve::Secp256k1) {
                    return Err(PetrelCryptoError::Malformed(
                        "K-256 signer produced an invalid signature".into(),
                    ));
                }
                Ok(scalar::low_s_form(&raw, ATProtoKeyCurve::Secp256k1))
            }
        }
    }

    /// Exports the 32-byte big-endian private scalar.
    pub fn export_raw_representation(&self) -> Zeroizing<[u8; 32]> {
        self.raw.clone()
    }
}

impl ATProtoSigner for PrivateKey {
    fn curve(&self) -> ATProtoKeyCurve {
        self.curve()
    }

    fn sign<'a>(&'a self, message: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], PetrelCryptoError>> {
        Box::pin(async move { self.sign_sync(message) })
    }
}

impl ATProtoKeypair for PrivateKey {
    fn public_key(&self) -> &PublicKey {
        &self.public_key
    }
}

impl ATProtoExportableKeypair for PrivateKey {
    fn export_raw_representation(&self) -> Result<Zeroizing<[u8; 32]>, PetrelCryptoError> {
        Ok(self.raw.clone())
    }
}

impl fmt::Debug for PrivateKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "PrivateKey({})", self.public_key.did_key())
    }
}

impl fmt::Display for PrivateKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "PrivateKey({})", self.public_key.did_key())
    }
}

/// An in-memory NIST P-256 (`ES256`) signing keypair.
#[derive(Clone)]
pub struct P256Keypair(PrivateKey);

impl P256Keypair {
    /// Generates a new random P-256 keypair.
    pub fn generate() -> Result<Self, PetrelCryptoError> {
        Ok(Self(PrivateKey::generate(ATProtoKeyCurve::P256)?))
    }

    /// Imports a P-256 keypair from a 32-byte big-endian scalar.
    pub fn from_raw(raw: &[u8]) -> Result<Self, PetrelCryptoError> {
        Ok(Self(PrivateKey::from_raw(ATProtoKeyCurve::P256, raw)?))
    }

    /// Imports a P-256 keypair from 64 hex characters.
    pub fn from_hex(hex: &str) -> Result<Self, PetrelCryptoError> {
        Ok(Self(PrivateKey::from_hex(ATProtoKeyCurve::P256, hex)?))
    }

    /// Imports a P-256 keypair from base58btc multibase (`p256-priv` prefix or bare 32-byte scalar).
    pub fn from_multibase(multibase: &str) -> Result<Self, PetrelCryptoError> {
        let scalar = decode_private_multibase_expecting(multibase, ATProtoKeyCurve::P256)?;
        Self::from_raw(&scalar)
    }

    /// The public half of the keypair.
    pub const fn public_key(&self) -> &PublicKey {
        self.0.public_key()
    }

    /// The public `did:key`.
    pub fn did_key(&self) -> String {
        self.0.public_key().did_key()
    }

    /// Signs `SHA-256(message)` synchronously, returning 64-byte compact low-S `r || s`.
    pub fn sign_sync(&self, message: &[u8]) -> Result<[u8; 64], PetrelCryptoError> {
        self.0.sign_sync(message)
    }

    /// Exports the 32-byte big-endian private scalar.
    pub fn export_raw_representation(&self) -> Zeroizing<[u8; 32]> {
        self.0.export_raw_representation()
    }

    /// Returns the underlying curve-tagged [`PrivateKey`].
    pub const fn as_private_key(&self) -> &PrivateKey {
        &self.0
    }
}

impl ATProtoSigner for P256Keypair {
    fn curve(&self) -> ATProtoKeyCurve {
        ATProtoKeyCurve::P256
    }

    fn sign<'a>(&'a self, message: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], PetrelCryptoError>> {
        Box::pin(async move { self.sign_sync(message) })
    }
}

impl ATProtoKeypair for P256Keypair {
    fn public_key(&self) -> &PublicKey {
        self.0.public_key()
    }
}

impl ATProtoExportableKeypair for P256Keypair {
    fn export_raw_representation(&self) -> Result<Zeroizing<[u8; 32]>, PetrelCryptoError> {
        Ok(self.0.export_raw_representation())
    }
}

impl fmt::Debug for P256Keypair {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "P256Keypair({})", self.did_key())
    }
}

impl fmt::Display for P256Keypair {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "P256Keypair({})", self.did_key())
    }
}

/// An in-memory `secp256k1` (`ES256K`) signing keypair.
#[derive(Clone)]
pub struct K256Keypair(PrivateKey);

impl K256Keypair {
    /// Generates a new random K-256 keypair.
    pub fn generate() -> Result<Self, PetrelCryptoError> {
        Ok(Self(PrivateKey::generate(ATProtoKeyCurve::Secp256k1)?))
    }

    /// Imports a K-256 keypair from a 32-byte big-endian scalar.
    pub fn from_raw(raw: &[u8]) -> Result<Self, PetrelCryptoError> {
        Ok(Self(PrivateKey::from_raw(ATProtoKeyCurve::Secp256k1, raw)?))
    }

    /// Imports a K-256 keypair from 64 hex characters.
    pub fn from_hex(hex: &str) -> Result<Self, PetrelCryptoError> {
        Ok(Self(PrivateKey::from_hex(ATProtoKeyCurve::Secp256k1, hex)?))
    }

    /// Imports a K-256 keypair from base58btc multibase (`secp256k1-priv` prefix or bare 32-byte scalar).
    pub fn from_multibase(multibase: &str) -> Result<Self, PetrelCryptoError> {
        let scalar = decode_private_multibase_expecting(multibase, ATProtoKeyCurve::Secp256k1)?;
        Self::from_raw(&scalar)
    }

    /// The public half of the keypair.
    pub const fn public_key(&self) -> &PublicKey {
        self.0.public_key()
    }

    /// The public `did:key`.
    pub fn did_key(&self) -> String {
        self.0.public_key().did_key()
    }

    /// Signs `SHA-256(message)` synchronously, returning 64-byte compact low-S `r || s`.
    pub fn sign_sync(&self, message: &[u8]) -> Result<[u8; 64], PetrelCryptoError> {
        self.0.sign_sync(message)
    }

    /// Exports the 32-byte big-endian private scalar.
    pub fn export_raw_representation(&self) -> Zeroizing<[u8; 32]> {
        self.0.export_raw_representation()
    }

    /// Returns the underlying curve-tagged [`PrivateKey`].
    pub const fn as_private_key(&self) -> &PrivateKey {
        &self.0
    }
}

impl ATProtoSigner for K256Keypair {
    fn curve(&self) -> ATProtoKeyCurve {
        ATProtoKeyCurve::Secp256k1
    }

    fn sign<'a>(&'a self, message: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], PetrelCryptoError>> {
        Box::pin(async move { self.sign_sync(message) })
    }
}

impl ATProtoKeypair for K256Keypair {
    fn public_key(&self) -> &PublicKey {
        self.0.public_key()
    }
}

impl ATProtoExportableKeypair for K256Keypair {
    fn export_raw_representation(&self) -> Result<Zeroizing<[u8; 32]>, PetrelCryptoError> {
        Ok(self.0.export_raw_representation())
    }
}

impl fmt::Debug for K256Keypair {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "K256Keypair({})", self.did_key())
    }
}

impl fmt::Display for K256Keypair {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "K256Keypair({})", self.did_key())
    }
}

/// Request passed to an external signing closure by [`ATProtoExternalSigner`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExternalSignRequest {
    /// The bytes being signed, unhashed.
    pub message: Vec<u8>,
    /// `SHA-256(message)`, 32 bytes.
    pub sha256_digest: [u8; 32],
    /// The curve the signature must be on.
    pub curve: ATProtoKeyCurve,
}

pub trait ExternalSignOp:
    Fn(ExternalSignRequest) -> BoxFuture<'static, Result<Vec<u8>, PetrelCryptoError>>
    + MaybeSend
    + MaybeSync
{
}

impl<F> ExternalSignOp for F where
    F: Fn(ExternalSignRequest) -> BoxFuture<'static, Result<Vec<u8>, PetrelCryptoError>>
        + MaybeSend
        + MaybeSync
{
}

/// Adapts an external signing operation (KMS, HSM, hardware token) to [`ATProtoSigner`]
/// and [`ATProtoKeypair`], normalizing and verifying its output before returning.
pub struct ATProtoExternalSigner {
    public_key: PublicKey,
    operation: Box<dyn ExternalSignOp>,
}

impl ATProtoExternalSigner {
    /// Wraps an external signing callback and verifies every produced signature against `public_key`.
    pub fn new<F>(public_key: PublicKey, sign: F) -> Self
    where
        F: Fn(ExternalSignRequest) -> BoxFuture<'static, Result<Vec<u8>, PetrelCryptoError>>
            + MaybeSend
            + MaybeSync
            + 'static,
    {
        Self {
            public_key,
            operation: Box::new(sign),
        }
    }
}

impl fmt::Debug for ATProtoExternalSigner {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ATProtoExternalSigner")
            .field("public_key", &self.public_key)
            .finish_non_exhaustive()
    }
}

impl ATProtoSigner for ATProtoExternalSigner {
    fn curve(&self) -> ATProtoKeyCurve {
        self.public_key.curve()
    }

    fn sign<'a>(&'a self, message: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], PetrelCryptoError>> {
        Box::pin(async move {
            let request = ExternalSignRequest {
                message: message.to_vec(),
                sha256_digest: ATProtoCrypto::sha256(message),
                curve: self.public_key.curve(),
            };
            let produced = (self.operation)(request).await?;
            let canonical = ATProtoSignature::canonicalize(&produced, self.public_key.curve())?;
            if !self.public_key.verify_strict(&canonical, message) {
                return Err(PetrelCryptoError::Unauthorized(
                    "external signer returned a signature that does not verify against its public key"
                        .into(),
                ));
            }
            Ok(canonical)
        })
    }
}

impl ATProtoKeypair for ATProtoExternalSigner {
    fn public_key(&self) -> &PublicKey {
        &self.public_key
    }
}

/// Curve-agnostic entry points for AT Protocol cryptography.
#[derive(Debug, Clone, Copy)]
pub struct ATProtoCrypto;

impl ATProtoCrypto {
    /// Verifies `signature` over `SHA-256(data)` against `did_key` with strict low-S policy.
    pub fn verify_signature(
        did_key: &str,
        data: &[u8],
        signature: &[u8],
    ) -> Result<bool, PetrelCryptoError> {
        Self::verify_signature_with_options(
            did_key,
            data,
            signature,
            ATProtoSignatureVerificationOptions::STRICT,
            None,
        )
    }

    /// Verifies `signature` over `SHA-256(data)` against `did_key` with explicit `options`
    /// and an optional `expected_jwt_algorithm` (`"ES256"` / `"ES256K"`).
    pub fn verify_signature_with_options(
        did_key: &str,
        data: &[u8],
        signature: &[u8],
        options: ATProtoSignatureVerificationOptions,
        expected_jwt_algorithm: Option<&str>,
    ) -> Result<bool, PetrelCryptoError> {
        let key = PublicKey::from_did_key(did_key)?;
        if let Some(expected) = expected_jwt_algorithm
            && expected != key.jwt_algorithm()
        {
            return Err(PetrelCryptoError::UnsupportedAlgorithm(format!(
                "expected key algorithm {expected}, got {}",
                key.jwt_algorithm()
            )));
        }
        Ok(key.is_valid_signature(signature, data, options))
    }

    /// Generates a new in-memory keypair on `curve`.
    pub fn generate_keypair(curve: ATProtoKeyCurve) -> Result<PrivateKey, PetrelCryptoError> {
        PrivateKey::generate(curve)
    }

    /// Generates a new in-memory K-256 keypair (reference default).
    pub fn generate_default_keypair() -> Result<PrivateKey, PetrelCryptoError> {
        PrivateKey::generate_k256()
    }

    /// Imports a keypair from a 32-byte private scalar.
    pub fn import_keypair_raw(
        curve: ATProtoKeyCurve,
        raw: &[u8],
    ) -> Result<PrivateKey, PetrelCryptoError> {
        PrivateKey::from_raw(curve, raw)
    }

    /// Imports a keypair from 64 hex characters.
    pub fn import_keypair_hex(
        curve: ATProtoKeyCurve,
        hex: &str,
    ) -> Result<PrivateKey, PetrelCryptoError> {
        PrivateKey::from_hex(curve, hex)
    }

    /// Imports a keypair from a private multikey (`z...`).
    pub fn import_keypair_multibase(
        private_multibase: &str,
    ) -> Result<PrivateKey, PetrelCryptoError> {
        PrivateKey::from_multibase(private_multibase)
    }

    /// SHA-256 of `data`, as 32 raw bytes.
    pub fn sha256(data: &[u8]) -> [u8; 32] {
        Sha256::digest(data).into()
    }

    /// SHA-256 of `data`, as 64 lowercase hex characters.
    pub fn sha256_hex(data: &[u8]) -> String {
        Hex::encode(&Self::sha256(data))
    }

    /// Returns `count` cryptographically secure random bytes.
    pub fn random_bytes(count: usize) -> Result<Vec<u8>, PetrelCryptoError> {
        let mut bytes = vec![0_u8; count];
        if count > 0 {
            getrandom::getrandom(&mut bytes).map_err(|_| PetrelCryptoError::Entropy)?;
        }
        Ok(bytes)
    }

    /// Returns a fixed-size array of cryptographically secure random bytes.
    pub fn random_array<const N: usize>() -> Result<[u8; N], PetrelCryptoError> {
        random_array::<N>()
    }
}

pub(crate) fn random_array<const N: usize>() -> Result<[u8; N], PetrelCryptoError> {
    let mut bytes = [0_u8; N];
    if N > 0 {
        getrandom::getrandom(&mut bytes).map_err(|_| PetrelCryptoError::Entropy)?;
    }
    Ok(bytes)
}

const fn curve_label(curve: ATProtoKeyCurve) -> &'static str {
    match curve {
        ATProtoKeyCurve::P256 => "P-256",
        ATProtoKeyCurve::Secp256k1 => "K-256",
    }
}

fn decode_private_hex(hex: &str) -> Result<Zeroizing<Vec<u8>>, PetrelCryptoError> {
    if hex.len() != 2 * SCALAR_BYTE_COUNT {
        return Err(PetrelCryptoError::Malformed(
            "private key hex must be 64 hex characters".into(),
        ));
    }
    let bytes = Hex::decode(hex).ok_or_else(|| {
        PetrelCryptoError::Malformed("private key hex must be 64 hex characters".into())
    })?;
    Ok(Zeroizing::new(bytes))
}

fn decode_private_multibase(
    multibase: &str,
) -> Result<(Option<ATProtoKeyCurve>, Zeroizing<Vec<u8>>), PetrelCryptoError> {
    let encoded = multibase
        .strip_prefix('z')
        .filter(|_| multibase.len() <= 128)
        .ok_or_else(|| {
            PetrelCryptoError::Malformed(
                "private key multibase must be base58btc with a z prefix".into(),
            )
        })?;
    let decoded = Zeroizing::new(Base58BTC::decode(encoded).map_err(|_| {
        PetrelCryptoError::Malformed("private key multibase is not canonical base58btc".into())
    })?);
    if Base58BTC::encode(&decoded) != encoded {
        return Err(PetrelCryptoError::Malformed(
            "private key multibase is not canonical base58btc".into(),
        ));
    }
    match decoded.len() {
        SCALAR_BYTE_COUNT => Ok((None, decoded)),
        34 => {
            let curve = ATProtoKeyCurve::ALL
                .into_iter()
                .find(|c| decoded[..2] == c.private_key_multicodec_prefix())
                .ok_or_else(|| {
                    PetrelCryptoError::UnsupportedAlgorithm(
                        "private multikey is not a P-256 or K-256 key".into(),
                    )
                })?;
            Ok((Some(curve), Zeroizing::new(decoded[2..].to_vec())))
        }
        _ => Err(PetrelCryptoError::Malformed(
            "private key multibase has the wrong length".into(),
        )),
    }
}

fn decode_private_multibase_expecting(
    multibase: &str,
    expected: ATProtoKeyCurve,
) -> Result<Zeroizing<Vec<u8>>, PetrelCryptoError> {
    let (curve, scalar) = decode_private_multibase(multibase)?;
    if let Some(actual) = curve
        && actual != expected
    {
        return Err(PetrelCryptoError::UnsupportedAlgorithm(format!(
            "private multikey is a {} key, expected {}",
            actual.as_str(),
            expected.as_str()
        )));
    }
    Ok(scalar)
}
