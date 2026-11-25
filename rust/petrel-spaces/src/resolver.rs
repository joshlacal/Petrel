//! Space host DID resolution, `#atproto_kem` extraction, and `#atproto` signing key verification.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use http::{Method, Request, header::ACCEPT};
use petrel::identity::DidWebIdentifier;
use petrel::net::{
    RedirectPolicy, SendOptions, SharedTransport, policy::validate_url_with_development,
    send_with_redirects,
};
use petrel_core::Did;
use petrel_crypto::{
    ATProtoJWTVerificationKey, JWTBase64URL, P256DIDKey, PLCDIDKeyCodec, PublicKey,
    curve::ATProtoKeyCurve,
    rt::{BoxFuture, MaybeSend, MaybeSync},
};
use serde::{Deserialize, Serialize};
use url::Url;
use web_time::{Duration, Instant};

use crate::error::{Result, SpaceError};
use crate::tokens::{SigningKeyPair, SigningKeyResolver};

/// Default PLC directory base URL.
pub const DEFAULT_PLC_DIRECTORY_URL: &str = "https://plc.directory";
/// Default cache TTL for DID documents resolved over HTTP (5 minutes).
pub const DEFAULT_DID_CACHE_TTL_SECS: u64 = 300;

/// Resolved service endpoints and keys for a space's authority DID.
#[derive(Debug, Clone)]
pub struct SpaceAuthorityEndpoints {
    pub space_did: Did,
    pub service_url: Url,
    pub service_type: String,
    pub signing_key: Option<ATProtoJWTVerificationKey>,
    pub kem_key: Option<String>,
    pub kem_key_id: Option<String>,
}

/// JSON-compatible AT Protocol DID document retaining both `publicKeyMultibase`
/// and `publicKeyJwk` verification material for Space host resolution.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SpaceDidDocument {
    pub id: Did,
    #[serde(rename = "@context", default)]
    pub context: Vec<String>,
    #[serde(default)]
    pub also_known_as: Vec<String>,
    #[serde(rename = "service", default)]
    pub services: Vec<SpaceDidService>,
    #[serde(rename = "verificationMethod", default)]
    pub verification_methods: Vec<SpaceVerificationMethod>,
}

/// A service entry in a DID document.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SpaceDidService {
    pub id: String,
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(default)]
    pub service_endpoint: Option<String>,
}

/// A verification method entry in a DID document.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SpaceVerificationMethod {
    pub id: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub controller: Did,
    #[serde(default)]
    pub public_key_multibase: Option<String>,
    #[serde(default)]
    pub public_key_jwk: Option<serde_json::Value>,
}

impl SpaceDidDocument {
    /// Parse a DID document from JSON bytes.
    pub fn from_json_bytes(bytes: &[u8]) -> Result<Self> {
        serde_json::from_slice(bytes)
            .map_err(|e| SpaceError::DidResolutionFailed(format!("invalid DID document JSON: {e}")))
    }

    /// Look up a service entry matching a fragment (`#atproto_space`, `#atproto_pds`, etc.) and optional type.
    pub fn service(&self, fragment: &str, expected_type: Option<&str>) -> Option<&SpaceDidService> {
        self.services.iter().find(|svc| {
            self.matches_fragment(&svc.id, fragment)
                && expected_type.is_none_or(|ty| svc.kind == ty)
        })
    }

    /// Look up a verification method matching a fragment (`#atproto`, `#atproto_kem`, etc.).
    pub fn verification_method(&self, fragment: &str) -> Option<&SpaceVerificationMethod> {
        self.verification_methods
            .iter()
            .find(|vm| self.matches_fragment(&vm.id, fragment))
    }

    fn matches_fragment(&self, raw_id: &str, fragment: &str) -> bool {
        if raw_id == fragment {
            return true;
        }
        if let Some(rest) = raw_id.strip_prefix(self.id.as_str()) {
            return rest == fragment;
        }
        false
    }
}

/// Trait for resolving full AT Protocol DID documents for space hosts, authors, and authorities.
pub trait SpaceDidResolver: MaybeSend + MaybeSync {
    /// Resolve the DID document for `did`.
    fn resolve_did_document<'a>(
        &'a self,
        did: &'a Did,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<SpaceDidDocument>>;
}

/// Compute the authoritative DID document fetch URL for `did:plc:` or `did:web:`.
pub fn did_document_url(
    did: &Did,
    plc_directory_base: &Url,
    allow_http_localhost: bool,
) -> Result<Url> {
    let raw = did.as_str();
    if raw.starts_with("did:plc:") {
        let mut url = plc_directory_base.clone();
        url.set_path(&format!(
            "{}/{}",
            plc_directory_base.path().trim_end_matches('/'),
            raw
        ));
        validate_url_with_development(&url, allow_http_localhost)
            .map_err(|e| SpaceError::DidResolutionFailed(e.to_string()))?;
        return Ok(url);
    }
    if raw.starts_with("did:web:") {
        let parsed = DidWebIdentifier::parse(raw, allow_http_localhost)
            .map_err(|e| SpaceError::DidResolutionFailed(e.to_string()))?;
        let url = parsed
            .document_url()
            .map_err(|e| SpaceError::DidResolutionFailed(e.to_string()))?;
        validate_url_with_development(&url, allow_http_localhost)
            .map_err(|e| SpaceError::DidResolutionFailed(e.to_string()))?;
        return Ok(url);
    }
    Err(SpaceError::DidResolutionFailed(format!(
        "unsupported DID method for {raw}"
    )))
}

/// Extract the space host endpoint URL (`#atproto_space` preferred, `#atproto_pds` fallback).
pub fn extract_service_endpoint(
    doc: &SpaceDidDocument,
    allow_http_localhost: bool,
) -> Result<(Url, String)> {
    let svc = doc
        .service("#atproto_space", Some("AtprotoSpaceHost"))
        .or_else(|| doc.service("#atproto_pds", Some("AtprotoPersonalDataServer")))
        .ok_or_else(|| {
            SpaceError::Configuration(format!(
                "DID document for {} has neither #atproto_space nor #atproto_pds service",
                doc.id
            ))
        })?;
    let endpoint_str = svc.service_endpoint.as_deref().ok_or_else(|| {
        SpaceError::Configuration(format!(
            "service {} in {} missing serviceEndpoint",
            svc.id, doc.id
        ))
    })?;
    let url = Url::parse(endpoint_str).map_err(|e| {
        SpaceError::InvalidUri(format!("invalid serviceEndpoint '{endpoint_str}': {e}"))
    })?;
    validate_url_with_development(&url, allow_http_localhost).map_err(|e| {
        SpaceError::InvalidUri(format!("unsafe serviceEndpoint '{endpoint_str}': {e}"))
    })?;
    Ok((url, svc.kind.clone()))
}

/// Extract a P-256 `did:key:` KEM key (`#atproto_kem`) from a DID document.
pub fn extract_kem_key(doc: &SpaceDidDocument) -> Result<(String, String)> {
    let vm = doc.verification_method("#atproto_kem").ok_or_else(|| {
        SpaceError::SigningKeyNotFound(format!(
            "{} missing #atproto_kem verificationMethod",
            doc.id
        ))
    })?;
    let did_key = verification_method_to_p256_kem_did_key(vm)?;
    Ok((vm.id.clone(), did_key))
}

/// Extract an ATProto JWT verification key (`#atproto` by default) from a DID document.
pub fn extract_signing_key(doc: &SpaceDidDocument, kid: &str) -> Result<ATProtoJWTVerificationKey> {
    let vm = doc.verification_method(kid).ok_or_else(|| {
        SpaceError::SigningKeyNotFound(format!("{} missing {kid} verificationMethod", doc.id))
    })?;
    verification_method_to_jwt_key(vm)
}

/// Extract `SpaceAuthorityEndpoints` (service URL + optional signing key + optional KEM key)
/// from an already-fetched DID document.
pub fn extract_authority_endpoints(
    doc: &SpaceDidDocument,
    allow_http_localhost: bool,
) -> Result<SpaceAuthorityEndpoints> {
    let (service_url, service_type) = extract_service_endpoint(doc, allow_http_localhost)?;
    let signing_key = extract_signing_key(doc, "#atproto").ok();
    let (kem_key_id, kem_key) = match extract_kem_key(doc) {
        Ok((id, key)) => (Some(id), Some(key)),
        Err(_) => (None, None),
    };
    Ok(SpaceAuthorityEndpoints {
        space_did: doc.id.clone(),
        service_url,
        service_type,
        signing_key,
        kem_key,
        kem_key_id,
    })
}

fn verification_method_to_p256_kem_did_key(vm: &SpaceVerificationMethod) -> Result<String> {
    match vm.kind.as_str() {
        "Multikey" | "P256KeyAgreement" | "EcdsaSecp256r1VerificationKey2019" => {
            if let Some(mb) = vm.public_key_multibase.as_deref().filter(|s| !s.is_empty()) {
                let decoded = if mb.starts_with("did:key:") {
                    PLCDIDKeyCodec::decode(mb)
                } else if vm.kind == "EcdsaSecp256r1VerificationKey2019" {
                    PLCDIDKeyCodec::decode_legacy_multibase(
                        mb,
                        petrel_crypto::LegacyVerificationKeyCurve::P256,
                    )
                } else {
                    PLCDIDKeyCodec::decode_multikey(mb)
                }
                .map_err(|e| {
                    SpaceError::InvalidKemKey(format!("invalid multibase KEM key: {e}"))
                })?;
                let bytes = match decoded {
                    petrel_crypto::PLCDIDVerificationKey::P256(b) => b,
                    petrel_crypto::PLCDIDVerificationKey::Secp256k1(_) => {
                        return Err(SpaceError::InvalidKemKey(
                            "#atproto_kem must be P-256, found secp256k1".into(),
                        ));
                    }
                };
                return P256DIDKey::from_compressed_bytes(&bytes)
                    .map(P256DIDKey::into_string)
                    .map_err(|e| SpaceError::InvalidKemKey(e.to_string()));
            }
            if let Some(jwk) = &vm.public_key_jwk {
                let key = jwk_to_public_key(jwk)?;
                if key.curve() != ATProtoKeyCurve::P256 {
                    return Err(SpaceError::InvalidKemKey(
                        "#atproto_kem JWK curve must be P-256".into(),
                    ));
                }
                return Ok(key.did_key());
            }
            Err(SpaceError::InvalidKemKey(
                "#atproto_kem missing publicKeyMultibase and publicKeyJwk".into(),
            ))
        }
        "JsonWebKey2020" => {
            let jwk = vm.public_key_jwk.as_ref().ok_or_else(|| {
                SpaceError::InvalidKemKey("JsonWebKey2020 missing publicKeyJwk".into())
            })?;
            let key = jwk_to_public_key(jwk)?;
            if key.curve() != ATProtoKeyCurve::P256 {
                return Err(SpaceError::InvalidKemKey(
                    "#atproto_kem JWK curve must be P-256".into(),
                ));
            }
            Ok(key.did_key())
        }
        other => Err(SpaceError::InvalidKemKey(format!(
            "unsupported #atproto_kem verificationMethod type '{other}'"
        ))),
    }
}

fn verification_method_to_jwt_key(
    vm: &SpaceVerificationMethod,
) -> Result<ATProtoJWTVerificationKey> {
    if let Some(mb) = vm.public_key_multibase.as_deref().filter(|s| !s.is_empty()) {
        if vm.kind == "Multikey" {
            let decoded = PLCDIDKeyCodec::decode_multikey(mb)
                .map_err(|e| SpaceError::InvalidKeyMaterial(e.to_string()))?;
            return Ok(ATProtoJWTVerificationKey::from_plc_key(&decoded));
        }
        let legacy_curve = match vm.kind.as_str() {
            "EcdsaSecp256r1VerificationKey2019" => {
                Some(petrel_crypto::LegacyVerificationKeyCurve::P256)
            }
            "EcdsaSecp256k1VerificationKey2019" => {
                Some(petrel_crypto::LegacyVerificationKeyCurve::Secp256k1)
            }
            _ => None,
        };
        if let Some(curve) = legacy_curve {
            let decoded = PLCDIDKeyCodec::decode_legacy_multibase(mb, curve)
                .map_err(|e| SpaceError::InvalidKeyMaterial(e.to_string()))?;
            return Ok(ATProtoJWTVerificationKey::from_plc_key(&decoded));
        }
        let decoded = PLCDIDKeyCodec::decode(mb)
            .map_err(|e| SpaceError::InvalidKeyMaterial(e.to_string()))?;
        return Ok(ATProtoJWTVerificationKey::from_plc_key(&decoded));
    }
    if let Some(jwk) = &vm.public_key_jwk {
        let key = jwk_to_public_key(jwk)?;
        return Ok(ATProtoJWTVerificationKey::from_public_key(&key));
    }
    Err(SpaceError::InvalidKeyMaterial(format!(
        "verificationMethod {} missing publicKeyMultibase/publicKeyJwk",
        vm.id
    )))
}

#[derive(Deserialize)]
struct EcJwk {
    kty: String,
    crv: String,
    x: String,
    y: String,
}

fn jwk_to_public_key(jwk: &serde_json::Value) -> Result<PublicKey> {
    let parsed: EcJwk = serde_json::from_value(jwk.clone())
        .map_err(|e| SpaceError::InvalidKeyMaterial(format!("invalid EC JWK: {e}")))?;
    if parsed.kty != "EC" {
        return Err(SpaceError::InvalidKeyMaterial(format!(
            "unsupported JWK kty '{}'",
            parsed.kty
        )));
    }
    let curve = match parsed.crv.as_str() {
        "P-256" => ATProtoKeyCurve::P256,
        "secp256k1" => ATProtoKeyCurve::Secp256k1,
        other => {
            return Err(SpaceError::InvalidKeyMaterial(format!(
                "unsupported JWK crv '{other}'"
            )));
        }
    };
    let x = JWTBase64URL::decode(&parsed.x, 64)
        .map_err(|e| SpaceError::InvalidKeyMaterial(format!("invalid JWK x: {e}")))?;
    let y = JWTBase64URL::decode(&parsed.y, 64)
        .map_err(|e| SpaceError::InvalidKeyMaterial(format!("invalid JWK y: {e}")))?;
    if x.len() != 32 || y.len() != 32 {
        return Err(SpaceError::InvalidKeyMaterial(
            "EC JWK x and y coordinates must be 32 bytes each".into(),
        ));
    }
    let mut uncompressed = [0u8; 65];
    uncompressed[0] = 0x04;
    uncompressed[1..33].copy_from_slice(&x);
    uncompressed[33..65].copy_from_slice(&y);
    PublicKey::from_sec1(curve, &uncompressed)
        .map_err(|e| SpaceError::InvalidKeyMaterial(format!("invalid EC JWK point: {e}")))
}

/// Static in-memory DID document and signing-key resolver for tests and pinned fixtures.
#[derive(Debug, Default, Clone)]
pub struct StaticDidResolver {
    docs: HashMap<Did, SpaceDidDocument>,
    signing_keys: HashMap<(Did, String), ATProtoJWTVerificationKey>,
}

impl StaticDidResolver {
    /// Create an empty static resolver.
    pub fn new() -> Self {
        Self::default()
    }

    /// Insert a full DID document.
    pub fn insert_document(&mut self, doc: SpaceDidDocument) {
        self.docs.insert(doc.id.clone(), doc);
    }

    /// Register a verification key for `(did, kid)` directly, and synthesize a minimal DID document
    /// if none was registered yet.
    pub fn insert_signing_key(&mut self, did: Did, kid: &str, key: &ATProtoJWTVerificationKey) {
        self.signing_keys
            .insert((did.clone(), kid.to_owned()), key.clone());
        let doc = self
            .docs
            .entry(did.clone())
            .or_insert_with(|| SpaceDidDocument {
                id: did.clone(),
                context: vec!["https://www.w3.org/ns/did/v1".into()],
                also_known_as: Vec::new(),
                services: Vec::new(),
                verification_methods: Vec::new(),
            });
        if let Ok(pk) = key.public_key() {
            let full_id = if kid.starts_with('#') {
                format!("{did}{kid}")
            } else {
                kid.to_owned()
            };
            let mb = pk
                .did_key()
                .strip_prefix("did:key:")
                .unwrap_or_default()
                .to_owned();
            doc.verification_methods.push(SpaceVerificationMethod {
                id: full_id,
                kind: "Multikey".into(),
                controller: did,
                public_key_multibase: Some(mb),
                public_key_jwk: None,
            });
        }
    }

    /// Register a local `SigningKeyPair` under `did` with `#atproto` (and optional service URL).
    pub fn insert_keypair(
        &mut self,
        did: &Did,
        keypair: &SigningKeyPair,
        service_url: Option<&str>,
    ) {
        let key = ATProtoJWTVerificationKey::from_public_key(&keypair.public_key());
        self.insert_signing_key(did.clone(), "#atproto", &key);
        if let Some(ep) = service_url
            && let Some(doc) = self.docs.get_mut(did)
        {
            doc.services.push(SpaceDidService {
                id: "#atproto_space".into(),
                kind: "AtprotoSpaceHost".into(),
                service_endpoint: Some(ep.to_owned()),
            });
        }
    }
}

impl SpaceDidResolver for StaticDidResolver {
    fn resolve_did_document<'a>(
        &'a self,
        did: &'a Did,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<SpaceDidDocument>> {
        Box::pin(async move {
            self.docs
                .get(did)
                .cloned()
                .ok_or_else(|| SpaceError::DidDocumentNotFound(did.to_string()))
        })
    }
}

impl SigningKeyResolver for StaticDidResolver {
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a Did,
        kid: &'a str,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<ATProtoJWTVerificationKey>> {
        Box::pin(async move {
            if let Some(k) = self.signing_keys.get(&(did.clone(), kid.to_owned())) {
                return Ok(k.clone());
            }
            let doc = self
                .docs
                .get(did)
                .ok_or_else(|| SpaceError::DidDocumentNotFound(did.to_string()))?;
            extract_signing_key(doc, kid)
        })
    }
}

#[derive(Debug, Clone)]
struct CachedDidDoc {
    doc: SpaceDidDocument,
    fetched_at: Instant,
}

/// HTTP-backed DID resolver + Space host endpoint resolver built on `petrel::net::SharedTransport`.
pub struct SpaceHostResolver {
    transport: SharedTransport,
    plc_directory_base: Url,
    allow_http_localhost: bool,
    cache_ttl: Duration,
    cache: Arc<Mutex<HashMap<Did, CachedDidDoc>>>,
}

impl core::fmt::Debug for SpaceHostResolver {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("SpaceHostResolver")
            .field("plc_directory_base", &self.plc_directory_base)
            .field("allow_http_localhost", &self.allow_http_localhost)
            .field("cache_ttl", &self.cache_ttl)
            .finish_non_exhaustive()
    }
}

impl SpaceHostResolver {
    /// Construct a resolver using the default PLC directory (`https://plc.directory`).
    ///
    /// # Panics
    ///
    /// Never panics because `DEFAULT_PLC_DIRECTORY_URL` is a compile-time constant valid URL.
    pub fn new(transport: SharedTransport) -> Self {
        Self {
            transport,
            plc_directory_base: Url::parse(DEFAULT_PLC_DIRECTORY_URL).expect("valid PLC URL"),
            allow_http_localhost: false,
            cache_ttl: Duration::from_secs(DEFAULT_DID_CACHE_TTL_SECS),
            cache: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Override the PLC directory URL (useful for testing against a local directory mock).
    #[must_use]
    pub fn with_plc_directory_base(mut self, url: Url) -> Self {
        self.plc_directory_base = url;
        self
    }

    /// Enable or disable plain `http://localhost` / `http://127.0.0.1` DID & service URLs.
    #[must_use]
    pub fn with_allow_http_localhost(mut self, allow: bool) -> Self {
        self.allow_http_localhost = allow;
        self
    }

    /// Override the DID document cache TTL.
    #[must_use]
    pub fn with_cache_ttl(mut self, ttl: Duration) -> Self {
        self.cache_ttl = ttl;
        self
    }

    /// Evict any cached DID document for `did`.
    pub fn invalidate(&self, did: &Did) {
        if let Ok(mut guard) = self.cache.lock() {
            guard.remove(did);
        }
    }

    /// Compute the DID document URL for `did` under this resolver's configuration.
    pub fn did_document_url(&self, did: &Did) -> Result<Url> {
        did_document_url(did, &self.plc_directory_base, self.allow_http_localhost)
    }

    /// Resolve `did` and extract its Space host endpoints and keys.
    pub async fn resolve_authority_endpoints(
        &self,
        did: &Did,
        force_refresh: bool,
    ) -> Result<SpaceAuthorityEndpoints> {
        let doc = self.resolve_did_document(did, force_refresh).await?;
        extract_authority_endpoints(&doc, self.allow_http_localhost)
    }

    /// Resolve a writer/author DID's `#atproto_kem` P-256 `did:key:`.
    pub async fn resolve_kem_key(&self, did: &Did, force_refresh: bool) -> Result<String> {
        let doc = self.resolve_did_document(did, force_refresh).await?;
        extract_kem_key(&doc).map(|(_, key)| key)
    }
}

impl SpaceDidResolver for SpaceHostResolver {
    fn resolve_did_document<'a>(
        &'a self,
        did: &'a Did,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<SpaceDidDocument>> {
        Box::pin(async move {
            if !force_refresh
                && let Ok(guard) = self.cache.lock()
                && let Some(entry) = guard.get(did)
                && entry.fetched_at.elapsed() < self.cache_ttl
            {
                return Ok(entry.doc.clone());
            }

            let url = self.did_document_url(did)?;
            let mut req = Request::builder()
                .method(Method::GET)
                .uri(url.as_str())
                .header(ACCEPT, "application/json")
                .body(bytes::Bytes::new())
                .map_err(|e| SpaceError::DidResolutionFailed(e.to_string()))?;
            let _ = &mut req;

            let resp = send_with_redirects(
                self.transport.as_ref(),
                req,
                &SendOptions::new(),
                RedirectPolicy::Follow,
            )
            .await
            .map_err(|e| SpaceError::Transport(e.to_string()))?;

            let status = resp.status().as_u16();
            if status == 404 {
                return Err(SpaceError::DidDocumentNotFound(did.to_string()));
            }
            if !(200..300).contains(&status) {
                return Err(SpaceError::DidResolutionFailed(format!(
                    "HTTP {status} fetching DID document for {did}"
                )));
            }

            let doc = SpaceDidDocument::from_json_bytes(resp.body())?;
            if &doc.id != did {
                return Err(SpaceError::DidResolutionFailed(format!(
                    "DID document id mismatch: expected {did}, got {}",
                    doc.id
                )));
            }
            if let Ok(mut guard) = self.cache.lock() {
                guard.insert(
                    did.clone(),
                    CachedDidDoc {
                        doc: doc.clone(),
                        fetched_at: Instant::now(),
                    },
                );
            }
            Ok(doc)
        })
    }
}

impl SigningKeyResolver for SpaceHostResolver {
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a Did,
        kid: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<ATProtoJWTVerificationKey>> {
        Box::pin(async move {
            let doc = self.resolve_did_document(did, force_refresh).await?;
            extract_signing_key(&doc, kid)
        })
    }
}
