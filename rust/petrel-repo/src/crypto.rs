use std::fmt;
use std::sync::Arc;

use k256::ecdsa as k256_ecdsa;
use p256::ecdsa as p256_ecdsa;
use p256::elliptic_curve::sec1::ToEncodedPoint as _;
use petrel::identity::{
    DidDocument, DnsResolver, IdentityCache, IdentityResolver, SigningCurve, SigningKey,
};
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::Did;

use crate::error::CommitError;

/// Elliptic curve supported for AT Protocol repository commit signatures.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SigningAlgorithm {
    /// NIST P-256 (`secp256r1` / ES256), `did:key` multicodec `0x1200` (`[0x80, 0x24]`).
    P256,
    /// secp256k1 (`ES256K`), `did:key` multicodec `0xe7` (`[0xe7, 0x01]`).
    Secp256k1,
}

impl From<SigningCurve> for SigningAlgorithm {
    fn from(value: SigningCurve) -> Self {
        match value {
            SigningCurve::P256 => Self::P256,
            SigningCurve::Secp256k1 => Self::Secp256k1,
        }
    }
}

impl From<SigningAlgorithm> for SigningCurve {
    fn from(value: SigningAlgorithm) -> Self {
        match value {
            SigningAlgorithm::P256 => Self::P256,
            SigningAlgorithm::Secp256k1 => Self::Secp256k1,
        }
    }
}

/// 64-byte compact ECDSA signature (`r || s`) validated for low-S canonical form.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Signature([u8; 64]);

impl Signature {
    /// Parses a 64-byte signature and checks that its scalar `s` is canonical low-S
    /// for `algorithm`.
    pub fn from_strict_bytes(
        algorithm: SigningAlgorithm,
        bytes: &[u8],
    ) -> Result<Self, CommitError> {
        let raw: [u8; 64] = bytes.try_into().map_err(|_| {
            CommitError::InvalidSignatureEncoding(format!(
                "expected 64-byte compact signature, got {} bytes",
                bytes.len()
            ))
        })?;
        match algorithm {
            SigningAlgorithm::P256 => {
                let sig = p256_ecdsa::Signature::from_slice(&raw)
                    .map_err(|err| CommitError::InvalidSignatureEncoding(err.to_string()))?;
                if sig.normalize_s().is_some() {
                    return Err(CommitError::HighSSignature);
                }
            }
            SigningAlgorithm::Secp256k1 => {
                let sig = k256_ecdsa::Signature::from_slice(&raw)
                    .map_err(|err| CommitError::InvalidSignatureEncoding(err.to_string()))?;
                if sig.normalize_s().is_some() {
                    return Err(CommitError::HighSSignature);
                }
            }
        }
        Ok(Self(raw))
    }

    pub fn as_bytes(&self) -> &[u8; 64] {
        &self.0
    }
}

/// Async repository commit signer seam.
///
/// Mirrors `ATProtoRepositoryCommitSigner` / `PublicRepositoryCommitSigner`
/// and aligns with `petrel-crypto::ATProtoSigner` so `petrel-crypto` keypairs
/// adapt without touching repository code.
pub trait CommitSigner: MaybeSend + MaybeSync {
    fn algorithm(&self) -> SigningAlgorithm;

    /// Signs `unsigned_commit_bytes` (the raw DAG-CBOR unsigned commit bytes)
    /// and returns a 64-byte low-S normalized `r || s` signature.
    fn sign<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
    ) -> BoxFuture<'a, Result<Vec<u8>, CommitError>>;
}

/// Async repository commit verifier seam.
///
/// Mirrors `ATProtoRepositoryCommitVerifier` / `PublicRepositoryCommitVerifier`
/// and aligns with `petrel-crypto::ATProtoVerifier`.
pub trait CommitVerifier: MaybeSend + MaybeSync + fmt::Debug {
    /// Verifies `signature` (64-byte compact low-S `r || s`) against
    /// `unsigned_commit_bytes`.
    fn verify<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), CommitError>>;
}

/// Async resolver mapping a repository DID to its commit verifier.
///
/// Mirrors `RepositorySigningKeyResolver` in Swift.
pub trait RepositorySigningKeyResolver: MaybeSend + MaybeSync {
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a Did,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<Arc<dyn CommitVerifier>, CommitError>>;
}

/// A validated compressed public signing key (P-256 or secp256k1).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SigningPublicKey {
    algorithm: SigningAlgorithm,
    compressed_sec1: [u8; 33],
}

impl SigningPublicKey {
    /// Wraps compressed or uncompressed SEC1 bytes for `algorithm`.
    pub fn from_sec1_bytes(algorithm: SigningAlgorithm, bytes: &[u8]) -> Result<Self, CommitError> {
        let compressed_sec1: [u8; 33] = match algorithm {
            SigningAlgorithm::P256 => p256::PublicKey::from_sec1_bytes(bytes)
                .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?
                .to_encoded_point(true)
                .as_bytes()
                .try_into()
                .map_err(|_| CommitError::InvalidPublicKey("invalid P-256 SEC1 point".into()))?,
            SigningAlgorithm::Secp256k1 => k256::PublicKey::from_sec1_bytes(bytes)
                .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?
                .to_encoded_point(true)
                .as_bytes()
                .try_into()
                .map_err(|_| {
                    CommitError::InvalidPublicKey("invalid secp256k1 SEC1 point".into())
                })?,
        };
        Ok(Self {
            algorithm,
            compressed_sec1,
        })
    }

    /// Parses a `did:key:z...` multikey string.
    pub fn from_did_key(did_key: &str) -> Result<Self, CommitError> {
        let multibase = did_key.strip_prefix("did:key:").unwrap_or(did_key);
        let encoded = multibase.strip_prefix('z').ok_or_else(|| {
            CommitError::InvalidPublicKey("did:key must use base58btc ('z') multibase".into())
        })?;
        if encoded.is_empty() || encoded.len() > 255 {
            return Err(CommitError::InvalidPublicKey(
                "did:key multibase payload out of bounds".into(),
            ));
        }
        let raw = bs58::decode(encoded)
            .into_vec()
            .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?;
        if bs58::encode(&raw).into_string() != encoded {
            return Err(CommitError::InvalidPublicKey(
                "non-canonical base58btc encoding in did:key".into(),
            ));
        }
        match raw.as_slice() {
            [0x80, 0x24, sec1 @ ..] if sec1.len() == 33 => {
                Self::from_sec1_bytes(SigningAlgorithm::P256, sec1)
            }
            [0xe7, 0x01, sec1 @ ..] if sec1.len() == 33 => {
                Self::from_sec1_bytes(SigningAlgorithm::Secp256k1, sec1)
            }
            _ => Err(CommitError::InvalidPublicKey(
                "unsupported did:key multicodec or key length".into(),
            )),
        }
    }

    /// Extracts the `#atproto` signing key from a DID document JSON payload.
    pub fn from_did_document_json(json_bytes: &[u8], did: &Did) -> Result<Self, CommitError> {
        let doc: DidDocument = serde_json::from_slice(json_bytes).map_err(|err| {
            CommitError::InvalidPublicKey(format!("invalid DID document JSON: {err}"))
        })?;
        if &doc.id != did {
            return Err(CommitError::InvalidPublicKey(format!(
                "DID document id ({}) does not match expected DID ({did})",
                doc.id
            )));
        }
        let key = doc
            .signing_key()
            .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?;
        Ok(Self::from(&key))
    }

    pub fn algorithm(&self) -> SigningAlgorithm {
        self.algorithm
    }

    pub fn as_sec1(&self) -> &[u8; 33] {
        &self.compressed_sec1
    }

    pub fn did_key(&self) -> String {
        let prefix = match self.algorithm {
            SigningAlgorithm::P256 => [0x80, 0x24],
            SigningAlgorithm::Secp256k1 => [0xe7, 0x01],
        };
        let mut buf = [0_u8; 35];
        buf[..2].copy_from_slice(&prefix);
        buf[2..].copy_from_slice(&self.compressed_sec1);
        format!("did:key:z{}", bs58::encode(buf).into_string())
    }

    /// Verifies `signature` strictly (64-byte compact low-S) against
    /// `unsigned_commit_bytes` using SHA-256.
    pub fn verify_sync(
        &self,
        unsigned_commit_bytes: &[u8],
        signature: &[u8],
    ) -> Result<(), CommitError> {
        use p256_ecdsa::signature::Verifier as _;

        let parsed = Signature::from_strict_bytes(self.algorithm, signature)?;
        match self.algorithm {
            SigningAlgorithm::P256 => {
                let vk = p256_ecdsa::VerifyingKey::from_sec1_bytes(&self.compressed_sec1)
                    .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?;
                let sig = p256_ecdsa::Signature::from_slice(parsed.as_bytes())
                    .map_err(|err| CommitError::InvalidSignatureEncoding(err.to_string()))?;
                vk.verify(unsigned_commit_bytes, &sig)
                    .map_err(|_| CommitError::InvalidSignature)
            }
            SigningAlgorithm::Secp256k1 => {
                let vk = k256_ecdsa::VerifyingKey::from_sec1_bytes(&self.compressed_sec1)
                    .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?;
                let sig = k256_ecdsa::Signature::from_slice(parsed.as_bytes())
                    .map_err(|err| CommitError::InvalidSignatureEncoding(err.to_string()))?;
                vk.verify(unsigned_commit_bytes, &sig)
                    .map_err(|_| CommitError::InvalidSignature)
            }
        }
    }
}

impl From<&SigningKey> for SigningPublicKey {
    fn from(value: &SigningKey) -> Self {
        Self {
            algorithm: SigningAlgorithm::from(value.curve()),
            compressed_sec1: *value.as_sec1(),
        }
    }
}

impl From<SigningKey> for SigningPublicKey {
    fn from(value: SigningKey) -> Self {
        Self::from(&value)
    }
}

impl CommitVerifier for SigningPublicKey {
    fn verify<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), CommitError>> {
        Box::pin(async move { self.verify_sync(unsigned_commit_bytes, signature) })
    }
}

/// Software NIST P-256 (`ES256`) signing keypair implementing [`CommitSigner`]
/// and [`CommitVerifier`].
#[derive(Clone)]
pub struct P256Keypair {
    signing_key: p256_ecdsa::SigningKey,
    public_key: SigningPublicKey,
}

impl P256Keypair {
    /// Generates a fresh random P-256 keypair.
    pub fn generate() -> Result<Self, CommitError> {
        let mut seed = [0_u8; 32];
        loop {
            getrandom::getrandom(&mut seed)
                .map_err(|err| CommitError::SigningFailed(err.to_string()))?;
            if let Ok(key) = Self::from_bytes(&seed) {
                return Ok(key);
            }
        }
    }

    /// Loads a P-256 private scalar from 32 big-endian bytes.
    pub fn from_bytes(bytes: &[u8; 32]) -> Result<Self, CommitError> {
        let signing_key = p256_ecdsa::SigningKey::from_slice(bytes)
            .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?;
        let sec1 = signing_key
            .verifying_key()
            .to_encoded_point(true)
            .as_bytes()
            .to_vec();
        let public_key = SigningPublicKey::from_sec1_bytes(SigningAlgorithm::P256, &sec1)?;
        Ok(Self {
            signing_key,
            public_key,
        })
    }

    pub fn to_bytes(&self) -> [u8; 32] {
        self.signing_key.to_bytes().into()
    }

    pub fn public_key(&self) -> &SigningPublicKey {
        &self.public_key
    }

    pub fn did_key(&self) -> String {
        self.public_key.did_key()
    }

    /// Synchronously signs `unsigned_commit_bytes` returning 64-byte low-S `r || s`.
    pub fn sign_sync(&self, unsigned_commit_bytes: &[u8]) -> Result<Vec<u8>, CommitError> {
        use p256_ecdsa::signature::Signer as _;
        let sig: p256_ecdsa::Signature = self
            .signing_key
            .try_sign(unsigned_commit_bytes)
            .map_err(|err| CommitError::SigningFailed(err.to_string()))?;
        let normalized = sig.normalize_s().unwrap_or(sig);
        Ok(normalized.to_bytes().to_vec())
    }
}

impl fmt::Debug for P256Keypair {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("P256Keypair")
            .field("public_key", &self.public_key)
            .finish_non_exhaustive()
    }
}

impl CommitSigner for P256Keypair {
    fn algorithm(&self) -> SigningAlgorithm {
        SigningAlgorithm::P256
    }

    fn sign<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
    ) -> BoxFuture<'a, Result<Vec<u8>, CommitError>> {
        Box::pin(async move { self.sign_sync(unsigned_commit_bytes) })
    }
}

impl CommitVerifier for P256Keypair {
    fn verify<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), CommitError>> {
        self.public_key.verify(unsigned_commit_bytes, signature)
    }
}

/// Software secp256k1 (`ES256K`) signing keypair implementing [`CommitSigner`]
/// and [`CommitVerifier`].
#[derive(Clone)]
pub struct K256Keypair {
    signing_key: k256_ecdsa::SigningKey,
    public_key: SigningPublicKey,
}

impl K256Keypair {
    /// Generates a fresh random secp256k1 keypair.
    pub fn generate() -> Result<Self, CommitError> {
        let mut seed = [0_u8; 32];
        loop {
            getrandom::getrandom(&mut seed)
                .map_err(|err| CommitError::SigningFailed(err.to_string()))?;
            if let Ok(key) = Self::from_bytes(&seed) {
                return Ok(key);
            }
        }
    }

    /// Loads a secp256k1 private scalar from 32 big-endian bytes.
    pub fn from_bytes(bytes: &[u8; 32]) -> Result<Self, CommitError> {
        let signing_key = k256_ecdsa::SigningKey::from_slice(bytes)
            .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?;
        let sec1 = signing_key
            .verifying_key()
            .to_encoded_point(true)
            .as_bytes()
            .to_vec();
        let public_key = SigningPublicKey::from_sec1_bytes(SigningAlgorithm::Secp256k1, &sec1)?;
        Ok(Self {
            signing_key,
            public_key,
        })
    }

    pub fn to_bytes(&self) -> [u8; 32] {
        self.signing_key.to_bytes().into()
    }

    pub fn public_key(&self) -> &SigningPublicKey {
        &self.public_key
    }

    pub fn did_key(&self) -> String {
        self.public_key.did_key()
    }

    /// Synchronously signs `unsigned_commit_bytes` returning 64-byte low-S `r || s`.
    pub fn sign_sync(&self, unsigned_commit_bytes: &[u8]) -> Result<Vec<u8>, CommitError> {
        use k256_ecdsa::signature::Signer as _;
        let sig: k256_ecdsa::Signature = self
            .signing_key
            .try_sign(unsigned_commit_bytes)
            .map_err(|err| CommitError::SigningFailed(err.to_string()))?;
        let normalized = sig.normalize_s().unwrap_or(sig);
        Ok(normalized.to_bytes().to_vec())
    }
}

impl fmt::Debug for K256Keypair {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("K256Keypair")
            .field("public_key", &self.public_key)
            .finish_non_exhaustive()
    }
}

impl CommitSigner for K256Keypair {
    fn algorithm(&self) -> SigningAlgorithm {
        SigningAlgorithm::Secp256k1
    }

    fn sign<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
    ) -> BoxFuture<'a, Result<Vec<u8>, CommitError>> {
        Box::pin(async move { self.sign_sync(unsigned_commit_bytes) })
    }
}

impl CommitVerifier for K256Keypair {
    fn verify<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), CommitError>> {
        self.public_key.verify(unsigned_commit_bytes, signature)
    }
}

/// Static key resolver returning a fixed verifier (`FixedRepositorySigningKey`).
#[derive(Debug, Clone)]
pub struct FixedSigningKey {
    verifier: Arc<dyn CommitVerifier>,
}

impl FixedSigningKey {
    pub fn new(verifier: Arc<dyn CommitVerifier>) -> Self {
        Self { verifier }
    }

    pub fn from_public_key(key: SigningPublicKey) -> Self {
        Self {
            verifier: Arc::new(key),
        }
    }

    pub fn from_crypto_public_key(key: petrel_crypto::PublicKey) -> Self {
        Self {
            verifier: Arc::new(key),
        }
    }
}

impl From<petrel_crypto::ATProtoKeyCurve> for SigningAlgorithm {
    fn from(value: petrel_crypto::ATProtoKeyCurve) -> Self {
        match value {
            petrel_crypto::ATProtoKeyCurve::P256 => Self::P256,
            petrel_crypto::ATProtoKeyCurve::Secp256k1 => Self::Secp256k1,
        }
    }
}

impl From<SigningAlgorithm> for petrel_crypto::ATProtoKeyCurve {
    fn from(value: SigningAlgorithm) -> Self {
        match value {
            SigningAlgorithm::P256 => Self::P256,
            SigningAlgorithm::Secp256k1 => Self::Secp256k1,
        }
    }
}

impl From<&petrel_crypto::PublicKey> for SigningPublicKey {
    fn from(value: &petrel_crypto::PublicKey) -> Self {
        Self {
            algorithm: SigningAlgorithm::from(value.curve()),
            compressed_sec1: *value.compressed_representation(),
        }
    }
}

impl From<petrel_crypto::PublicKey> for SigningPublicKey {
    fn from(value: petrel_crypto::PublicKey) -> Self {
        Self::from(&value)
    }
}

impl TryFrom<&SigningPublicKey> for petrel_crypto::PublicKey {
    type Error = CommitError;

    fn try_from(value: &SigningPublicKey) -> Result<Self, Self::Error> {
        Self::from_sec1(
            petrel_crypto::ATProtoKeyCurve::from(value.algorithm()),
            value.as_sec1(),
        )
        .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))
    }
}

impl TryFrom<SigningPublicKey> for petrel_crypto::PublicKey {
    type Error = CommitError;

    fn try_from(value: SigningPublicKey) -> Result<Self, Self::Error> {
        Self::try_from(&value)
    }
}

fn sign_with_petrel_crypto<'a, S: petrel_crypto::ATProtoSigner>(
    signer: &'a S,
    unsigned_commit_bytes: &'a [u8],
) -> BoxFuture<'a, Result<Vec<u8>, CommitError>> {
    Box::pin(async move {
        let sig = signer
            .sign(unsigned_commit_bytes)
            .await
            .map_err(|err| CommitError::SigningFailed(err.to_string()))?;
        Ok(sig.to_vec())
    })
}

fn verify_with_petrel_crypto_key(
    key: &petrel_crypto::PublicKey,
    unsigned_commit_bytes: &[u8],
    signature: &[u8],
) -> Result<(), CommitError> {
    let parsed = Signature::from_strict_bytes(SigningAlgorithm::from(key.curve()), signature)?;
    if key.verify_strict(parsed.as_bytes(), unsigned_commit_bytes) {
        Ok(())
    } else {
        Err(CommitError::InvalidSignature)
    }
}

macro_rules! impl_crypto_commit_signer {
    ($($ty:ty),+ $(,)?) => {
        $(
            impl CommitSigner for $ty {
                fn algorithm(&self) -> SigningAlgorithm {
                    SigningAlgorithm::from(<Self as petrel_crypto::ATProtoSigner>::curve(self))
                }

                fn sign<'a>(
                    &'a self,
                    unsigned_commit_bytes: &'a [u8],
                ) -> BoxFuture<'a, Result<Vec<u8>, CommitError>> {
                    sign_with_petrel_crypto(self, unsigned_commit_bytes)
                }
            }
        )+
    };
}

macro_rules! impl_crypto_keypair_commit_verifier {
    ($($ty:ty),+ $(,)?) => {
        $(
            impl CommitVerifier for $ty {
                fn verify<'a>(
                    &'a self,
                    unsigned_commit_bytes: &'a [u8],
                    signature: &'a [u8],
                ) -> BoxFuture<'a, Result<(), CommitError>> {
                    Box::pin(async move {
                        let key = <Self as petrel_crypto::ATProtoKeypair>::public_key(self);
                        verify_with_petrel_crypto_key(key, unsigned_commit_bytes, signature)
                    })
                }
            }
        )+
    };
}

impl_crypto_commit_signer!(
    petrel_crypto::PrivateKey,
    petrel_crypto::P256Keypair,
    petrel_crypto::K256Keypair,
    petrel_crypto::ATProtoExternalSigner,
);

impl_crypto_keypair_commit_verifier!(
    petrel_crypto::PrivateKey,
    petrel_crypto::P256Keypair,
    petrel_crypto::K256Keypair,
    petrel_crypto::ATProtoExternalSigner,
);

impl CommitVerifier for petrel_crypto::PublicKey {
    fn verify<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), CommitError>> {
        Box::pin(
            async move { verify_with_petrel_crypto_key(self, unsigned_commit_bytes, signature) },
        )
    }
}

impl CommitVerifier for petrel_crypto::ATProtoJWTVerificationKey {
    fn verify<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), CommitError>> {
        Box::pin(async move {
            let key = self
                .public_key()
                .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?;
            verify_with_petrel_crypto_key(&key, unsigned_commit_bytes, signature)
        })
    }
}

impl CommitVerifier for petrel_crypto::PLCDIDVerificationKey {
    fn verify<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
        signature: &'a [u8],
    ) -> BoxFuture<'a, Result<(), CommitError>> {
        Box::pin(async move {
            let jwt_key = petrel_crypto::ATProtoJWTVerificationKey::from_plc_key(self)
                .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?;
            let key = jwt_key
                .public_key()
                .map_err(|err| CommitError::InvalidPublicKey(err.to_string()))?;
            verify_with_petrel_crypto_key(&key, unsigned_commit_bytes, signature)
        })
    }
}

impl RepositorySigningKeyResolver for FixedSigningKey {
    fn resolve_signing_key<'a>(
        &'a self,
        _did: &'a Did,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<Arc<dyn CommitVerifier>, CommitError>> {
        Box::pin(async move { Ok(Arc::clone(&self.verifier)) })
    }
}

/// Adapts `petrel::identity::IdentityResolver` to [`RepositorySigningKeyResolver`].
///
/// Uses cached lookup when `force_refresh == false` and forces DID document
/// refresh when `force_refresh == true` (supporting `verify()`'s refresh-once
/// key-rotation retry).
#[derive(Debug, Clone)]
pub struct IdentityResolverKeyAdapter<D, C> {
    resolver: Arc<IdentityResolver<D, C>>,
}

impl<D, C> IdentityResolverKeyAdapter<D, C> {
    pub fn new(resolver: Arc<IdentityResolver<D, C>>) -> Self {
        Self { resolver }
    }
}

impl<D, C> RepositorySigningKeyResolver for IdentityResolverKeyAdapter<D, C>
where
    D: DnsResolver + 'static,
    C: IdentityCache + 'static,
{
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a Did,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<Arc<dyn CommitVerifier>, CommitError>> {
        Box::pin(async move {
            let document = if force_refresh {
                self.resolver.refresh_did_document(did).await
            } else {
                self.resolver.resolve_did_document(did).await
            }
            .map_err(|err| CommitError::KeyResolutionFailed {
                did: did.as_str().to_owned(),
                reason: err.to_string(),
            })?;
            let key = document
                .signing_key()
                .map_err(|err| CommitError::KeyResolutionFailed {
                    did: did.as_str().to_owned(),
                    reason: err.to_string(),
                })?;
            let public_key = SigningPublicKey::from(&key);
            Ok(Arc::new(public_key) as Arc<dyn CommitVerifier>)
        })
    }
}
