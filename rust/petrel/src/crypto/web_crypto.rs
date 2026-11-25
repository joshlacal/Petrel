use std::fmt;

use js_sys::{Array, ArrayBuffer, Object, Promise, Reflect, Uint8Array};
use wasm_bindgen::{JsCast, JsValue};
use wasm_bindgen_futures::JsFuture;
use web_sys::{Crypto, CryptoKey, SubtleCrypto};

use super::{CryptoError, DpopSigner, EcPublicJwk, Jwk, normalize_es256};
use crate::rt::BoxFuture;

const KEY_BINDING: &[u8] = b"Petrel WebCrypto DPoP key binding v1";

/// Signs ES256 proofs using an opaque, non-extractable P-256 WebCrypto key.
///
/// The embedding app can persist the [`CryptoKey`] handle and the public JWK
/// using a platform store that supports structured cloning. On reload, use
/// [`Self::from_key`] to check the binding before using either value.
pub struct WebCryptoDpopSigner {
    subtle: SubtleCrypto,
    key: CryptoKey,
    jwk: EcPublicJwk,
}

impl WebCryptoDpopSigner {
    /// Generates a non-extractable private key and exports the public JWK.
    pub async fn generate() -> Result<Self, CryptoError> {
        let subtle = subtle_crypto()?;
        let algorithm = p256_parameters()?;
        let pair = settle(
            subtle.generate_key_with_object(
                &algorithm,
                false,
                usages(&["sign", "verify"]).as_ref(),
            ),
            key_unavailable(),
        )
        .await?;
        let key = key_property(&pair, "privateKey")?;
        validate_signing_key(&key)?;
        let public_key = key_property(&pair, "publicKey")?;
        let jwk = export_public_jwk(&subtle, &public_key).await?;
        Ok(Self { subtle, key, jwk })
    }

    /// Restores a private signing key after verifying it matches the public JWK.
    pub async fn from_key(key: CryptoKey, jwk: EcPublicJwk) -> Result<Self, CryptoError> {
        validate_signing_key(&key)?;
        let subtle = subtle_crypto()?;
        let public_key = import_public_key(&subtle, &jwk).await?;
        let signer = Self { subtle, key, jwk };

        let signature = signer
            .sign(KEY_BINDING)
            .await
            .map_err(|_| CryptoError::InvalidKey)?;
        if !verify(&signer.subtle, &public_key, KEY_BINDING, &signature).await? {
            return Err(CryptoError::InvalidKey);
        }
        Ok(signer)
    }

    /// The opaque private key handle for embedders that use structured cloning.
    pub fn crypto_key(&self) -> &CryptoKey {
        &self.key
    }
}

impl fmt::Debug for WebCryptoDpopSigner {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("WebCryptoDpopSigner")
            .finish_non_exhaustive()
    }
}

impl DpopSigner for WebCryptoDpopSigner {
    fn public_jwk(&self) -> EcPublicJwk {
        self.jwk.clone()
    }

    fn sign<'a>(&'a self, input: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], CryptoError>> {
        Box::pin(async move {
            let algorithm = es256_parameters()?;
            let signature = settle(
                self.subtle
                    .sign_with_object_and_u8_array(&algorithm, &self.key, input),
                CryptoError::SigningFailed,
            )
            .await?
            .dyn_into::<ArrayBuffer>()
            .map_err(|_| CryptoError::InvalidSignature)?;
            let bytes = Uint8Array::new(signature.as_ref());
            let mut raw = [0; 64];
            if bytes.length() != 64 {
                return Err(CryptoError::InvalidSignature);
            }
            bytes.copy_to(&mut raw);
            normalize_es256(&raw)
        })
    }
}

fn subtle_crypto() -> Result<SubtleCrypto, CryptoError> {
    // globalThis also covers workers and Node, where there is no Window.
    let crypto = Reflect::get(&js_sys::global(), &JsValue::from_str("crypto"))
        .map_err(|_| key_unavailable())?
        .dyn_into::<Crypto>()
        .map_err(|_| key_unavailable())?;
    Ok(crypto.subtle())
}

fn key_unavailable() -> CryptoError {
    CryptoError::KeyUnavailable("WebCrypto key unavailable".into())
}

fn validate_signing_key(key: &CryptoKey) -> Result<(), CryptoError> {
    if !key.is_instance_of::<CryptoKey>() || key.type_() != "private" || key.extractable() {
        return Err(CryptoError::InvalidKey);
    }
    let usages = key.usages();
    if usages.length() != 1 || !usages.get(0).eq(&JsValue::from_str("sign")) {
        return Err(CryptoError::InvalidKey);
    }
    let algorithm = key.algorithm().map_err(|_| CryptoError::InvalidKey)?;
    if string_property(algorithm.as_ref(), "name")? != "ECDSA"
        || string_property(algorithm.as_ref(), "namedCurve")? != "P-256"
    {
        return Err(CryptoError::InvalidKey);
    }
    Ok(())
}

async fn export_public_jwk(
    subtle: &SubtleCrypto,
    public_key: &CryptoKey,
) -> Result<EcPublicJwk, CryptoError> {
    if public_key.type_() != "public" {
        return Err(CryptoError::InvalidKey);
    }
    let jwk = settle(
        subtle.export_key("jwk", public_key),
        CryptoError::InvalidKey,
    )
    .await?;
    if !property(&jwk, "d")?.is_undefined()
        || string_property(&jwk, "kty")? != "EC"
        || string_property(&jwk, "crv")? != "P-256"
    {
        return Err(CryptoError::InvalidKey);
    }
    let key = EcPublicJwk {
        x: string_property(&jwk, "x")?,
        y: string_property(&jwk, "y")?,
    };
    Jwk::try_from(&key).map_err(|_| CryptoError::InvalidKey)?;
    Ok(key)
}

async fn import_public_key(
    subtle: &SubtleCrypto,
    jwk: &EcPublicJwk,
) -> Result<CryptoKey, CryptoError> {
    Jwk::try_from(jwk).map_err(|_| CryptoError::InvalidKey)?;
    let object = parameters(&[
        ("kty", "EC"),
        ("crv", "P-256"),
        ("x", &jwk.x),
        ("y", &jwk.y),
    ])?;
    let algorithm = p256_parameters()?;
    settle(
        subtle.import_key_with_object(
            "jwk",
            &object,
            &algorithm,
            false,
            usages(&["verify"]).as_ref(),
        ),
        CryptoError::InvalidKey,
    )
    .await?
    .dyn_into::<CryptoKey>()
    .map_err(|_| CryptoError::InvalidKey)
}

async fn verify(
    subtle: &SubtleCrypto,
    public_key: &CryptoKey,
    input: &[u8],
    signature: &[u8; 64],
) -> Result<bool, CryptoError> {
    let algorithm = es256_parameters()?;
    settle(
        subtle
            .verify_with_object_and_u8_array_and_u8_array(&algorithm, public_key, signature, input),
        CryptoError::InvalidKey,
    )
    .await?
    .as_bool()
    .ok_or(CryptoError::InvalidKey)
}

fn p256_parameters() -> Result<Object, CryptoError> {
    parameters(&[("name", "ECDSA"), ("namedCurve", "P-256")])
}

fn es256_parameters() -> Result<Object, CryptoError> {
    parameters(&[("name", "ECDSA"), ("hash", "SHA-256")])
}

fn parameters(fields: &[(&str, &str)]) -> Result<Object, CryptoError> {
    let object = Object::new();
    for &(name, value) in fields {
        if !Reflect::set(
            object.as_ref(),
            &JsValue::from_str(name),
            &JsValue::from_str(value),
        )
        .map_err(|_| CryptoError::InvalidKey)?
        {
            return Err(CryptoError::InvalidKey);
        }
    }
    Ok(object)
}

fn usages(values: &[&str]) -> Array {
    values.iter().copied().map(JsValue::from_str).collect()
}

fn property(value: &JsValue, name: &str) -> Result<JsValue, CryptoError> {
    Reflect::get(value, &JsValue::from_str(name)).map_err(|_| CryptoError::InvalidKey)
}

fn string_property(value: &JsValue, name: &str) -> Result<String, CryptoError> {
    property(value, name)?
        .as_string()
        .ok_or(CryptoError::InvalidKey)
}

fn key_property(value: &JsValue, name: &str) -> Result<CryptoKey, CryptoError> {
    property(value, name)?
        .dyn_into::<CryptoKey>()
        .map_err(|_| CryptoError::InvalidKey)
}

async fn settle(
    promise: Result<Promise, JsValue>,
    error: CryptoError,
) -> Result<JsValue, CryptoError> {
    JsFuture::from(promise.map_err(|_| error.clone())?)
        .await
        .map_err(|_| error)
}

#[cfg(test)]
mod tests {
    use http::Method;
    use serde_json::{Value, json};
    use url::Url;

    use super::*;
    use crate::crypto::split_compact_jws;
    use crate::oauth::dpop_proof;

    #[wasm_bindgen_test::wasm_bindgen_test]
    async fn generates_nonextractable_key_and_verifiable_low_s_proof() {
        let signer = WebCryptoDpopSigner::generate().await.unwrap();
        let subtle = subtle_crypto().unwrap();
        assert!(!signer.crypto_key().extractable());
        assert!(
            settle(
                subtle.export_key("jwk", signer.crypto_key()),
                CryptoError::InvalidKey
            )
            .await
            .is_err()
        );
        // Test the signer boundary as well as the JWS output, which normalizes again.
        for attempt in 0..16 {
            let signature = signer.sign(&[attempt]).await.unwrap();
            assert_eq!(signature, normalize_es256(&signature).unwrap());
        }

        let proof = dpop_proof(
            &signer,
            &Method::POST,
            &Url::parse("https://pds.example.test/xrpc/example.method").unwrap(),
            1_900_000_000,
            None,
            None,
        )
        .await
        .unwrap();
        let parsed = split_compact_jws(&proof).unwrap();
        let jwk = signer.public_jwk();
        let header: Value = serde_json::from_slice(&parsed.header).unwrap();
        assert_eq!(
            header["jwk"],
            json!({"kty": "EC", "crv": "P-256", "x": jwk.x, "y": jwk.y}),
        );
        let signature: [u8; 64] = parsed.signature.try_into().unwrap();
        assert_eq!(signature, normalize_es256(&signature).unwrap());
        let public_key = import_public_key(&subtle, &jwk).await.unwrap();
        assert!(
            verify(&subtle, &public_key, parsed.input.as_bytes(), &signature)
                .await
                .unwrap()
        );
        assert!(
            !verify(&subtle, &public_key, b"wrong proof", &signature)
                .await
                .unwrap()
        );
    }

    #[wasm_bindgen_test::wasm_bindgen_test]
    async fn restores_matching_handle_and_rejects_mismatched_jwk() {
        let original = WebCryptoDpopSigner::generate().await.unwrap();
        let other = WebCryptoDpopSigner::generate().await.unwrap();
        let handle = original.crypto_key().clone();
        let pub_jwk = original.public_jwk();
        let restored = WebCryptoDpopSigner::from_key(handle.clone(), pub_jwk.clone())
            .await
            .unwrap();
        assert_eq!(restored.public_jwk().thumbprint(), pub_jwk.thumbprint());
        assert_eq!(
            WebCryptoDpopSigner::from_key(handle.clone(), other.public_jwk())
                .await
                .unwrap_err(),
            CryptoError::InvalidKey,
        );
        assert_eq!(
            WebCryptoDpopSigner::from_key(
                handle,
                EcPublicJwk {
                    x: String::new(),
                    y: pub_jwk.y
                },
            )
            .await
            .unwrap_err(),
            CryptoError::InvalidKey,
        );
    }

    #[wasm_bindgen_test::wasm_bindgen_test]
    async fn rejects_public_extractable_and_non_signing_handles() {
        let bound = WebCryptoDpopSigner::generate().await.unwrap();
        let subtle = subtle_crypto().unwrap();
        let usage = usages(&["sign", "verify"]);
        let p256 = parameters(&[("name", "ECDSA"), ("namedCurve", "P-256")]).unwrap();
        let exportable = settle(
            subtle.generate_key_with_object(&p256, true, usage.as_ref()),
            CryptoError::InvalidKey,
        )
        .await
        .unwrap();
        let public = key_property(&exportable, "publicKey").unwrap();
        let extractable_private = key_property(&exportable, "privateKey").unwrap();
        assert!(extractable_private.extractable());
        let p384 = parameters(&[("name", "ECDSA"), ("namedCurve", "P-384")]).unwrap();
        let other_curve = settle(
            subtle.generate_key_with_object(&p384, false, usage.as_ref()),
            CryptoError::InvalidKey,
        )
        .await
        .unwrap();
        let wrong_curve = key_property(&other_curve, "privateKey").unwrap();
        let ecdh = parameters(&[("name", "ECDH"), ("namedCurve", "P-256")]).unwrap();
        let ecdh_pair = settle(
            subtle.generate_key_with_object(&ecdh, false, usages(&["deriveBits"]).as_ref()),
            CryptoError::InvalidKey,
        )
        .await
        .unwrap();
        let wrong_usage = key_property(&ecdh_pair, "privateKey").unwrap();

        for key in [public, extractable_private, wrong_curve, wrong_usage] {
            assert_eq!(
                WebCryptoDpopSigner::from_key(key, bound.public_jwk())
                    .await
                    .unwrap_err(),
                CryptoError::InvalidKey,
            );
        }
    }
}
