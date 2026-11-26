//! Official ATProto crypto & syntax interop vectors (plus wasm32 compatibility).

use base64::{Engine as _, engine::general_purpose::STANDARD_NO_PAD};
use petrel_crypto::{
    ATProtoCrypto, ATProtoKeyCurve, ATProtoSignatureVerificationOptions, Base58BTC, K256Keypair,
    P256Keypair, PublicKey, ServiceJWT,
};
use serde::Deserialize;

const SIGNATURE_FIXTURES_JSON: &str =
    include_str!("../../../Tests/PetrelTests/Vectors/crypto/signature-fixtures.json");
const W3C_P256_JSON: &str =
    include_str!("../../../Tests/PetrelTests/Vectors/crypto/w3c_didkey_P256.json");
const W3C_K256_JSON: &str =
    include_str!("../../../Tests/PetrelTests/Vectors/crypto/w3c_didkey_K256.json");

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SignatureFixture {
    comment: String,
    message_base64: String,
    algorithm: String,
    did_doc_suite: String,
    public_key_did: String,
    public_key_multibase: String,
    signature_base64: String,
    valid_signature: bool,
    tags: Vec<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct W3CP256Vector {
    private_key_bytes_base58: String,
    public_did_key: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct W3CK256Vector {
    private_key_bytes_hex: String,
    public_did_key: String,
}

fn decode_b64_any(s: &str) -> Vec<u8> {
    if let Ok(bytes) = STANDARD_NO_PAD.decode(s) {
        bytes
    } else {
        base64::engine::general_purpose::STANDARD.decode(s).unwrap()
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn signature_fixtures_match_strict_and_lax_policies() {
    let fixtures: Vec<SignatureFixture> = serde_json::from_str(SIGNATURE_FIXTURES_JSON).unwrap();
    assert!(!fixtures.is_empty());

    for fixture in fixtures {
        let message = decode_b64_any(&fixture.message_base64);
        let signature = decode_b64_any(&fixture.signature_base64);

        let strict_ok = ATProtoCrypto::verify_signature_with_options(
            &fixture.public_key_did,
            &message,
            &signature,
            ATProtoSignatureVerificationOptions::STRICT,
            Some(&fixture.algorithm),
        )
        .unwrap();
        assert_eq!(strict_ok, fixture.valid_signature, "{}", fixture.comment);

        // Also check DID document verificationMethod decoding (legacy 2019 suite).
        let legacy_key = PublicKey::from_verification_method(
            &fixture.did_doc_suite,
            &fixture.public_key_multibase,
        )
        .unwrap();
        assert_eq!(legacy_key.did_key(), fixture.public_key_did);
        assert_eq!(
            legacy_key.is_valid_signature(
                &signature,
                &message,
                ATProtoSignatureVerificationOptions::STRICT
            ),
            fixture.valid_signature
        );

        if fixture.tags.iter().any(|t| t == "high-s") {
            assert!(
                legacy_key.is_valid_signature(
                    &signature,
                    &message,
                    ATProtoSignatureVerificationOptions::JWT
                ),
                "high-s fixture should pass JWT policy: {}",
                fixture.comment
            );
        }
        if fixture.tags.iter().any(|t| t == "der-encoded") {
            assert!(
                !legacy_key.is_valid_signature(
                    &signature,
                    &message,
                    ATProtoSignatureVerificationOptions::JWT
                ),
                "der fixture must fail JWT policy: {}",
                fixture.comment
            );
            assert!(
                legacy_key.is_valid_signature(
                    &signature,
                    &message,
                    ATProtoSignatureVerificationOptions::ALLOW_MALLEABLE
                ),
                "der fixture should pass ALLOW_MALLEABLE: {}",
                fixture.comment
            );
        }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn w3c_didkey_p256_vectors_round_trip() {
    let vectors: Vec<W3CP256Vector> = serde_json::from_str(W3C_P256_JSON).unwrap();
    assert!(!vectors.is_empty());
    for v in vectors {
        let raw = Base58BTC::decode(&v.private_key_bytes_base58).unwrap();
        let kp = P256Keypair::from_raw(&raw).unwrap();
        assert_eq!(kp.did_key(), v.public_did_key);
        assert_eq!(
            PublicKey::from_did_key(&v.public_did_key).unwrap().curve(),
            ATProtoKeyCurve::P256
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn w3c_didkey_k256_vectors_round_trip() {
    let vectors: Vec<W3CK256Vector> = serde_json::from_str(W3C_K256_JSON).unwrap();
    assert!(!vectors.is_empty());
    for v in vectors {
        let kp = K256Keypair::from_hex(&v.private_key_bytes_hex).unwrap();
        assert_eq!(kp.did_key(), v.public_did_key);
        assert_eq!(
            PublicKey::from_did_key(&v.public_did_key).unwrap().curve(),
            ATProtoKeyCurve::Secp256k1
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn service_auth_nsid_syntax_vectors() {
    let valid = include_str!(
        "../../../Tests/PetrelTests/Vectors/service-auth/syntax/nsid_syntax_valid.txt"
    );
    for line in valid.lines() {
        let line = line.trim_end_matches('\r');
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        assert!(ServiceJWT::is_nsid(line), "expected valid NSID: {line}");
    }

    let invalid = include_str!(
        "../../../Tests/PetrelTests/Vectors/service-auth/syntax/nsid_syntax_invalid.txt"
    );
    for line in invalid.lines() {
        let line = line.trim_end_matches('\r');
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        assert!(!ServiceJWT::is_nsid(line), "expected invalid NSID: {line}");
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn service_auth_did_syntax_vectors() {
    let valid =
        include_str!("../../../Tests/PetrelTests/Vectors/service-auth/syntax/did_syntax_valid.txt");
    for line in valid.lines() {
        let line = line.trim_end_matches('\r');
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        assert!(ServiceJWT::is_did(line), "expected valid DID: {line}");
    }

    let invalid = include_str!(
        "../../../Tests/PetrelTests/Vectors/service-auth/syntax/did_syntax_invalid.txt"
    );
    for line in invalid.lines() {
        let line = line.trim_end_matches('\r');
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        assert!(!ServiceJWT::is_did(line), "expected invalid DID: {line}");
    }
}
