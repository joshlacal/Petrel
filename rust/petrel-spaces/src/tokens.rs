//! Space delegation, credential, and client-attestation JWT minting & verification.

use petrel_core::{Did, SpaceRef};
use petrel_crypto::{
    ATProtoCrypto, ATProtoJWTVerificationKey, ATProtoSignatureVerificationOptions, Hex,
    JWTBase64URL, K256Keypair, P256Keypair, PublicKey, StrictJSON,
    rt::{BoxFuture, MaybeSend, MaybeSync},
};
use serde::{Deserialize, Serialize};

use crate::error::{Result, SpaceError, parse_space_ref};

/// JWT `typ` for space delegation tokens (`com.atproto.space.getDelegationToken`).
pub const DELEGATION_JWT_TYP: &str = "atproto-space-delegation+jwt";
/// JWT `typ` for space credentials issued by `authorizeSpaceSync`.
pub const CREDENTIAL_JWT_TYP: &str = "atproto-space-credential+jwt";
/// JWT `typ` for client attestation tokens.
pub const CLIENT_ATTESTATION_JWT_TYP: &str = "atproto-client-attestation+jwt";

/// Maximum lifetime of a delegation JWT in seconds (per ATProto Spaces spec).
pub const MAX_DELEGATION_LIFETIME_SECS: i64 = 60;
/// Maximum lifetime of a space credential JWT in seconds (15 minutes).
pub const MAX_CREDENTIAL_LIFETIME_SECS: i64 = 900;
/// Maximum lifetime of a client attestation JWT in seconds (5 minutes).
pub const MAX_CLIENT_ATTESTATION_LIFETIME_SECS: i64 = 300;
/// Default clock skew leeway in seconds.
pub const CLOCK_SKEW_SECS: i64 = 60;

/// Signing algorithm supported for Spaces JWTs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JwtAlgorithm {
    /// ECDSA P-256 with SHA-256 (`ES256`).
    ES256,
    /// ECDSA secp256k1 with SHA-256 (`ES256K`).
    ES256K,
}

impl JwtAlgorithm {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::ES256 => "ES256",
            Self::ES256K => "ES256K",
        }
    }

    pub fn parse(raw: &str) -> Result<Self> {
        match raw {
            "ES256" => Ok(Self::ES256),
            "ES256K" => Ok(Self::ES256K),
            other => Err(SpaceError::UnsupportedAlgorithm(other.to_owned())),
        }
    }
}

/// A local ECDSA signing keypair (P-256 or secp256k1) producing canonical low-S 64-byte signatures.
#[derive(Clone)]
pub enum SigningKeyPair {
    P256(P256Keypair),
    K256(K256Keypair),
}

impl core::fmt::Debug for SigningKeyPair {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            Self::P256(kp) => f
                .debug_tuple("SigningKeyPair::P256")
                .field(&kp.did_key())
                .finish(),
            Self::K256(kp) => f
                .debug_tuple("SigningKeyPair::K256")
                .field(&kp.did_key())
                .finish(),
        }
    }
}

impl SigningKeyPair {
    /// Generate a fresh P-256 signing keypair.
    pub fn generate_p256() -> Result<Self> {
        P256Keypair::generate()
            .map(Self::P256)
            .map_err(|e| SpaceError::KemError(e.to_string()))
    }

    /// Generate a fresh secp256k1 signing keypair.
    pub fn generate_k256() -> Result<Self> {
        K256Keypair::generate()
            .map(Self::K256)
            .map_err(|e| SpaceError::KemError(e.to_string()))
    }

    /// Construct a P-256 signing keypair from a 32-byte big-endian private scalar.
    pub fn from_p256_bytes(secret: &[u8]) -> Result<Self> {
        P256Keypair::from_raw(secret)
            .map(Self::P256)
            .map_err(|e| SpaceError::InvalidKeyMaterial(e.to_string()))
    }

    /// Construct a secp256k1 signing keypair from a 32-byte big-endian private scalar.
    pub fn from_k256_bytes(secret: &[u8]) -> Result<Self> {
        K256Keypair::from_raw(secret)
            .map(Self::K256)
            .map_err(|e| SpaceError::InvalidKeyMaterial(e.to_string()))
    }

    /// Return the JWT `alg` name (`"ES256"` or `"ES256K"`).
    pub fn algorithm(&self) -> JwtAlgorithm {
        match self {
            Self::P256(_) => JwtAlgorithm::ES256,
            Self::K256(_) => JwtAlgorithm::ES256K,
        }
    }

    /// Return the corresponding public key.
    pub fn public_key(&self) -> PublicKey {
        match self {
            Self::P256(kp) => kp.public_key().clone(),
            Self::K256(kp) => kp.public_key().clone(),
        }
    }

    /// Return the `did:key:` representation of the public key.
    pub fn did_key(&self) -> Result<String> {
        Ok(match self {
            Self::P256(kp) => kp.did_key(),
            Self::K256(kp) => kp.did_key(),
        })
    }

    /// Export raw 32-byte private key scalar.
    pub fn raw_secret_bytes(&self) -> Result<zeroize::Zeroizing<[u8; 32]>> {
        Ok(match self {
            Self::P256(kp) => kp.export_raw_representation(),
            Self::K256(kp) => kp.export_raw_representation(),
        })
    }

    /// Sign `message` with ECDSA-SHA256, returning 64-byte compact low-S `r || s`.
    pub fn sign(&self, message: &[u8]) -> Result<Vec<u8>> {
        match self {
            Self::P256(kp) => kp
                .sign_sync(message)
                .map(|sig| sig.to_vec())
                .map_err(|e| SpaceError::InvalidKeyMaterial(e.to_string())),
            Self::K256(kp) => kp
                .sign_sync(message)
                .map(|sig| sig.to_vec())
                .map_err(|e| SpaceError::InvalidKeyMaterial(e.to_string())),
        }
    }
}

/// Resolver used during JWT verification to obtain a DID's signing verification key.
pub trait SigningKeyResolver: MaybeSend + MaybeSync {
    /// Resolve the signing verification key for `did` and optional `kid` (default `#atproto`).
    ///
    /// When `force_refresh` is `true`, implementations should bypass any cached DID document.
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a Did,
        kid: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<ATProtoJWTVerificationKey>>;
}

/// Decoded JWT header for ATProto Space tokens.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct JwtHeader {
    pub alg: String,
    pub typ: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub kid: Option<String>,
}

/// `cnf` proof-of-possession key claim (`{"kid": "did:key:..."}`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CnfClaim {
    pub kid: String,
}

/// Claims for a space delegation JWT (`atproto-space-delegation+jwt`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DelegationClaims {
    pub iss: String,
    pub aud: String,
    pub sub: String,
    pub iat: i64,
    pub exp: i64,
    pub jti: String,
}

impl DelegationClaims {
    /// Parse `iss` as a validated `Did`.
    pub fn issuer_did(&self) -> Result<Did> {
        Did::parse(&self.iss).map_err(|e| SpaceError::InvalidDid(e.to_string()))
    }

    /// Parse the DID portion of `aud` (stripping any `#fragment` such as `#atproto_pds`).
    pub fn audience_did(&self) -> Result<Did> {
        parse_did_or_did_url(&self.aud)
    }

    /// Parse `sub` strictly as a Nov 24 alpha `SpaceRef` (`at:space/...`).
    pub fn space_ref(&self) -> Result<SpaceRef> {
        parse_space_ref(&self.sub)
    }
}

/// Claims for a space credential JWT (`atproto-space-credential+jwt`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CredentialClaims {
    pub iss: String,
    pub sub: String,
    pub iat: i64,
    pub exp: i64,
    pub jti: String,
    pub cnf: CnfClaim,
}

impl CredentialClaims {
    /// Parse `iss` as a validated `Did`.
    pub fn issuer_did(&self) -> Result<Did> {
        Did::parse(&self.iss).map_err(|e| SpaceError::InvalidDid(e.to_string()))
    }

    /// Parse `sub` strictly as a Nov 24 alpha `SpaceRef` (`at:space/...`).
    pub fn space_ref(&self) -> Result<SpaceRef> {
        parse_space_ref(&self.sub)
    }
}

/// Claims for a client attestation JWT (`atproto-client-attestation+jwt`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClientAttestationClaims {
    pub iss: String,
    pub aud: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sub: Option<String>,
    pub iat: i64,
    pub exp: i64,
    pub jti: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cnf: Option<CnfClaim>,
}

/// Generate a random 128-bit hex `jti` token identifier.
pub fn generate_jti() -> Result<String> {
    let bytes: [u8; 16] = ATProtoCrypto::random_array()
        .map_err(|e| SpaceError::KemError(format!("RNG failure generating jti: {e}")))?;
    Ok(Hex::encode(&bytes))
}

/// Mint and sign a space delegation JWT (`typ = "atproto-space-delegation+jwt"`).
#[allow(clippy::too_many_arguments)]
pub fn mint_delegation_token(
    signing_key: &SigningKeyPair,
    iss: &Did,
    aud: &Did,
    sub: &SpaceRef,
    iat: i64,
    exp: i64,
    jti: Option<&str>,
    kid: Option<&str>,
) -> Result<String> {
    validate_lifetime(iat, exp, MAX_DELEGATION_LIFETIME_SECS)?;
    let jti_owned = match jti {
        Some(s) => s.to_owned(),
        None => generate_jti()?,
    };
    let header = JwtHeader {
        alg: signing_key.algorithm().as_str().to_owned(),
        typ: DELEGATION_JWT_TYP.to_owned(),
        kid: Some(kid.unwrap_or("#atproto").to_owned()),
    };
    let claims = DelegationClaims {
        iss: iss.as_str().to_owned(),
        aud: aud.as_str().to_owned(),
        sub: sub.as_str().to_owned(),
        iat,
        exp,
        jti: jti_owned,
    };
    encode_jwt(&header, &claims, signing_key)
}

/// Mint and sign a space credential JWT (`typ = "atproto-space-credential+jwt"`).
#[allow(clippy::too_many_arguments)]
pub fn mint_credential_token(
    signing_key: &SigningKeyPair,
    iss: &Did,
    sub: &SpaceRef,
    cnf_kid: &str,
    iat: i64,
    exp: i64,
    jti: Option<&str>,
    kid: Option<&str>,
) -> Result<String> {
    validate_lifetime(iat, exp, MAX_CREDENTIAL_LIFETIME_SECS)?;
    let jti_owned = match jti {
        Some(s) => s.to_owned(),
        None => generate_jti()?,
    };
    if jti_owned.is_empty() {
        return Err(SpaceError::MalformedPayload("empty jti claim".into()));
    }
    validate_did_key(cnf_kid)?;
    let header = JwtHeader {
        alg: signing_key.algorithm().as_str().to_owned(),
        typ: CREDENTIAL_JWT_TYP.to_owned(),
        kid: Some(kid.unwrap_or("#atproto").to_owned()),
    };
    let claims = CredentialClaims {
        iss: iss.as_str().to_owned(),
        sub: sub.as_str().to_owned(),
        iat,
        exp,
        jti: jti_owned,
        cnf: CnfClaim {
            kid: cnf_kid.to_owned(),
        },
    };
    encode_jwt(&header, &claims, signing_key)
}

/// Mint and sign a client attestation JWT (`typ = "atproto-client-attestation+jwt"`).
#[allow(clippy::too_many_arguments)]
pub fn mint_client_attestation_token(
    signing_key: &SigningKeyPair,
    iss: &Did,
    aud: &Did,
    sub: Option<&str>,
    cnf_kid: Option<&str>,
    iat: i64,
    exp: i64,
    jti: Option<&str>,
    kid: Option<&str>,
) -> Result<String> {
    validate_lifetime(iat, exp, MAX_CLIENT_ATTESTATION_LIFETIME_SECS)?;
    if let Some(sub_str) = sub {
        let _ = parse_space_ref(sub_str)?;
    }
    if let Some(cnf) = cnf_kid {
        validate_did_key(cnf)?;
    }
    let jti_owned = match jti {
        Some(s) => s.to_owned(),
        None => generate_jti()?,
    };
    let header = JwtHeader {
        alg: signing_key.algorithm().as_str().to_owned(),
        typ: CLIENT_ATTESTATION_JWT_TYP.to_owned(),
        kid: Some(kid.unwrap_or("#atproto").to_owned()),
    };
    let claims = ClientAttestationClaims {
        iss: iss.as_str().to_owned(),
        aud: aud.as_str().to_owned(),
        sub: sub.map(str::to_owned),
        iat,
        exp,
        jti: jti_owned,
        cnf: cnf_kid.map(|k| CnfClaim { kid: k.to_owned() }),
    };
    encode_jwt(&header, &claims, signing_key)
}

/// Inspect the unverified claims and header of a space credential JWT.
pub fn inspect_credential_token_unverified(token: &str) -> Result<(JwtHeader, CredentialClaims)> {
    let (header, claims, _, _) = parse_jwt_parts::<CredentialClaims>(token)?;
    if header.typ != CREDENTIAL_JWT_TYP {
        return Err(SpaceError::UnsupportedTokenType(header.typ));
    }
    let _ = JwtAlgorithm::parse(&header.alg)?;
    let _ = parse_space_ref(&claims.sub)?;
    let _ = Did::parse(&claims.iss).map_err(|e| SpaceError::InvalidDid(e.to_string()))?;
    validate_did_key(&claims.cnf.kid)?;
    if claims.jti.is_empty() {
        return Err(SpaceError::MalformedPayload("empty jti claim".into()));
    }
    Ok((header, claims))
}

/// Inspect the unverified claims and header of a delegation JWT.
pub fn inspect_delegation_token_unverified(token: &str) -> Result<(JwtHeader, DelegationClaims)> {
    let (header, claims, _, _) = parse_jwt_parts::<DelegationClaims>(token)?;
    if header.typ != DELEGATION_JWT_TYP {
        return Err(SpaceError::UnsupportedTokenType(header.typ));
    }
    let _ = JwtAlgorithm::parse(&header.alg)?;
    let _ = parse_space_ref(&claims.sub)?;
    let _ = Did::parse(&claims.iss).map_err(|e| SpaceError::InvalidDid(e.to_string()))?;
    let _ = Did::parse(&claims.aud).map_err(|e| SpaceError::InvalidDid(e.to_string()))?;
    if claims.jti.is_empty() {
        return Err(SpaceError::MalformedPayload("empty jti claim".into()));
    }
    Ok((header, claims))
}

/// Verify a delegation JWT (`atproto-space-delegation+jwt`), enforcing Nov 24 `at:space/` subject,
/// audience, time bounds, lifetime limit (`<= 60s`), and ECDSA signature with a single DID-cache
/// refresh retry on key rotation.
pub async fn verify_delegation_token<R: SigningKeyResolver + ?Sized>(
    token: &str,
    expected_audience: &str,
    now_secs: i64,
    resolver: &R,
) -> Result<DelegationClaims> {
    let (header, claims, signing_input, sig) = parse_jwt_parts::<DelegationClaims>(token)?;
    if header.typ != DELEGATION_JWT_TYP {
        return Err(SpaceError::UnsupportedTokenType(header.typ));
    }
    let _ = JwtAlgorithm::parse(&header.alg)?;
    let iss = claims.issuer_did()?;
    let aud_did = claims.audience_did()?;
    if !audience_matches(&claims.aud, &aud_did, expected_audience) {
        return Err(SpaceError::InvalidAudience {
            expected: expected_audience.to_owned(),
            actual: claims.aud,
        });
    }
    let _ = claims.space_ref().map_err(|e| match e {
        SpaceError::LegacySpaceUriRejected(_) => e,
        other => SpaceError::InvalidSubject(other.to_string()),
    })?;
    if claims.jti.is_empty() {
        return Err(SpaceError::MalformedPayload("empty jti claim".into()));
    }
    validate_time_bounds(
        claims.iat,
        claims.exp,
        now_secs,
        MAX_DELEGATION_LIFETIME_SECS,
    )?;

    let kid = header.kid.as_deref().unwrap_or("#atproto");
    verify_with_single_refresh(resolver, &iss, kid, &header.alg, &signing_input, &sig).await?;
    Ok(claims)
}

/// Verify a space credential JWT (`atproto-space-credential+jwt`), enforcing Nov 24 `at:space/`
/// subject, `cnf.kid`, time bounds, lifetime limit (`<= 900s`), and issuer ECDSA signature.
pub async fn verify_credential_token<R: SigningKeyResolver + ?Sized>(
    token: &str,
    now_secs: i64,
    resolver: &R,
) -> Result<CredentialClaims> {
    let (header, claims, signing_input, sig) = parse_jwt_parts::<CredentialClaims>(token)?;
    if header.typ != CREDENTIAL_JWT_TYP {
        return Err(SpaceError::UnsupportedTokenType(header.typ));
    }
    let _ = JwtAlgorithm::parse(&header.alg)?;
    let iss = claims.issuer_did()?;
    let _ = claims.space_ref().map_err(|e| match e {
        SpaceError::LegacySpaceUriRejected(_) => e,
        other => SpaceError::InvalidSubject(other.to_string()),
    })?;
    if claims.jti.is_empty() {
        return Err(SpaceError::MalformedPayload("empty jti claim".into()));
    }
    validate_did_key(&claims.cnf.kid)?;
    validate_time_bounds(
        claims.iat,
        claims.exp,
        now_secs,
        MAX_CREDENTIAL_LIFETIME_SECS,
    )?;

    let kid = header.kid.as_deref().unwrap_or("#atproto");
    verify_with_single_refresh(resolver, &iss, kid, &header.alg, &signing_input, &sig).await?;
    Ok(claims)
}

/// Verify a client attestation JWT (`atproto-client-attestation+jwt`).
pub async fn verify_client_attestation_token<R: SigningKeyResolver + ?Sized>(
    token: &str,
    expected_audience: &str,
    now_secs: i64,
    resolver: &R,
) -> Result<ClientAttestationClaims> {
    let (header, claims, signing_input, sig) = parse_jwt_parts::<ClientAttestationClaims>(token)?;
    if header.typ != CLIENT_ATTESTATION_JWT_TYP {
        return Err(SpaceError::UnsupportedTokenType(header.typ));
    }
    let _ = JwtAlgorithm::parse(&header.alg)?;
    let iss = Did::parse(&claims.iss).map_err(|e| SpaceError::InvalidDid(e.to_string()))?;
    let aud_did = parse_did_or_did_url(&claims.aud)?;
    if !audience_matches(&claims.aud, &aud_did, expected_audience) {
        return Err(SpaceError::InvalidAudience {
            expected: expected_audience.to_owned(),
            actual: claims.aud,
        });
    }
    if let Some(sub_str) = claims.sub.as_deref() {
        let _ = parse_space_ref(sub_str).map_err(|e| match e {
            SpaceError::LegacySpaceUriRejected(_) => e,
            other => SpaceError::InvalidSubject(other.to_string()),
        })?;
    }
    if let Some(cnf) = &claims.cnf {
        validate_did_key(&cnf.kid)?;
    }
    if claims.jti.is_empty() {
        return Err(SpaceError::MalformedPayload("empty jti claim".into()));
    }
    validate_time_bounds(
        claims.iat,
        claims.exp,
        now_secs,
        MAX_CLIENT_ATTESTATION_LIFETIME_SECS,
    )?;

    let kid = header.kid.as_deref().unwrap_or("#atproto");
    verify_with_single_refresh(resolver, &iss, kid, &header.alg, &signing_input, &sig).await?;
    Ok(claims)
}

async fn verify_with_single_refresh<R: SigningKeyResolver + ?Sized>(
    resolver: &R,
    iss: &Did,
    kid: &str,
    alg: &str,
    signing_input: &[u8],
    sig: &[u8],
) -> Result<()> {
    let key = resolver.resolve_signing_key(iss, kid, false).await?;
    if matches!(
        verify_jwt_signature(&key, sig, signing_input, alg),
        Ok(true)
    ) {
        return Ok(());
    }
    let refreshed = resolver.resolve_signing_key(iss, kid, true).await?;
    if verify_jwt_signature(&refreshed, sig, signing_input, alg)? {
        Ok(())
    } else {
        Err(SpaceError::InvalidSignature)
    }
}

fn verify_jwt_signature(
    key: &ATProtoJWTVerificationKey,
    sig: &[u8],
    signing_input: &[u8],
    alg: &str,
) -> Result<bool> {
    key.verify_with_options(
        sig,
        signing_input,
        alg,
        ATProtoSignatureVerificationOptions::JWT,
    )
    .map_err(|_| SpaceError::InvalidSignature)
}

fn encode_jwt<C: Serialize>(
    header: &JwtHeader,
    claims: &C,
    signing_key: &SigningKeyPair,
) -> Result<String> {
    let header_json =
        serde_json::to_vec(header).map_err(|e| SpaceError::MalformedHeader(e.to_string()))?;
    let claims_json =
        serde_json::to_vec(claims).map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;

    let mut signing_input =
        String::with_capacity(header_json.len() * 2 + claims_json.len() * 2 + 128);
    signing_input.push_str(&JWTBase64URL::encode(&header_json));
    signing_input.push('.');
    signing_input.push_str(&JWTBase64URL::encode(&claims_json));

    let sig = signing_key.sign(signing_input.as_bytes())?;
    let mut jwt = signing_input;
    jwt.push('.');
    jwt.push_str(&JWTBase64URL::encode(&sig));
    Ok(jwt)
}

fn parse_jwt_parts<C: for<'de> Deserialize<'de>>(
    token: &str,
) -> Result<(JwtHeader, C, Vec<u8>, Vec<u8>)> {
    let mut parts = token.split('.');
    let header_b64 = parts.next().ok_or(SpaceError::InvalidTokenFormat)?;
    let claims_b64 = parts.next().ok_or(SpaceError::InvalidTokenFormat)?;
    let sig_b64 = parts.next().ok_or(SpaceError::InvalidTokenFormat)?;
    if parts.next().is_some()
        || header_b64.is_empty()
        || claims_b64.is_empty()
        || sig_b64.is_empty()
    {
        return Err(SpaceError::InvalidTokenFormat);
    }

    let header_bytes = JWTBase64URL::decode(header_b64, JWTBase64URL::DEFAULT_MAX_BYTES)
        .map_err(|e| SpaceError::MalformedHeader(e.to_string()))?;
    let claims_bytes = JWTBase64URL::decode(claims_b64, JWTBase64URL::DEFAULT_MAX_BYTES)
        .map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;
    let sig = JWTBase64URL::decode(sig_b64, 256).map_err(|_| SpaceError::InvalidSignature)?;

    let header: JwtHeader = StrictJSON::decode(&header_bytes)
        .map_err(|e| SpaceError::MalformedHeader(e.to_string()))?;
    let claims: C = StrictJSON::decode(&claims_bytes)
        .map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;

    let mut signing_input = Vec::with_capacity(header_b64.len() + 1 + claims_b64.len());
    signing_input.extend_from_slice(header_b64.as_bytes());
    signing_input.push(b'.');
    signing_input.extend_from_slice(claims_b64.as_bytes());

    Ok((header, claims, signing_input, sig))
}

fn validate_lifetime(iat: i64, exp: i64, max_lifetime_secs: i64) -> Result<()> {
    if exp <= iat {
        return Err(SpaceError::MalformedPayload(
            "token exp must be greater than iat".into(),
        ));
    }
    let lifetime = exp.saturating_sub(iat);
    if lifetime > max_lifetime_secs {
        return Err(SpaceError::TokenLifetimeTooLong {
            lifetime,
            max: max_lifetime_secs,
        });
    }
    Ok(())
}

fn validate_time_bounds(iat: i64, exp: i64, now_secs: i64, max_lifetime_secs: i64) -> Result<()> {
    validate_lifetime(iat, exp, max_lifetime_secs)?;
    if iat > now_secs.saturating_add(CLOCK_SKEW_SECS) {
        return Err(SpaceError::TokenNotYetValid { now: now_secs, iat });
    }
    if exp <= now_secs.saturating_sub(CLOCK_SKEW_SECS) {
        return Err(SpaceError::TokenExpired { now: now_secs, exp });
    }
    Ok(())
}

fn validate_did_key(did_key: &str) -> Result<PublicKey> {
    PublicKey::from_did_key(did_key)
        .map_err(|e| SpaceError::InvalidKeyMaterial(format!("invalid cnf.kid {did_key}: {e}")))
}

fn parse_did_or_did_url(raw: &str) -> Result<Did> {
    if let Some((did_part, frag)) = raw.split_once('#') {
        if frag.is_empty() || frag.contains('#') {
            return Err(SpaceError::InvalidDid(format!(
                "invalid DID fragment in '{raw}'"
            )));
        }
        Did::parse(did_part).map_err(|e| SpaceError::InvalidDid(e.to_string()))
    } else {
        Did::parse(raw).map_err(|e| SpaceError::InvalidDid(e.to_string()))
    }
}

fn audience_matches(claims_aud: &str, claims_did: &Did, expected: &str) -> bool {
    if claims_aud == expected {
        return true;
    }
    !expected.contains('#') && claims_did.as_str() == expected
}
