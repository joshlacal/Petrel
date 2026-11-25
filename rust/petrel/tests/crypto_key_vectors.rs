//! The official `atproto-interop-tests/crypto` key vectors, read through the
//! DID-document key parser (`DidDocument::signing_key`) and `did:key`
//! encoder (`SigningKey::did_key`). Petrel Rust does not verify signatures,
//! so the signature fixtures are used for their keys only.

use p256::elliptic_curve::sec1::ToEncodedPoint;
use petrel::identity::{DidDocument, SigningCurve};

fn vectors(file: &str) -> Vec<serde_json::Value> {
    let path = format!(
        "{}/../../Tests/PetrelTests/Vectors/crypto/{file}",
        env!("CARGO_MANIFEST_DIR")
    );
    serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap()
}

/// A DID document whose `#atproto` key is `multibase` in the given suite.
fn document(kind: &str, multibase: &str) -> DidDocument {
    serde_json::from_value(serde_json::json!({
        "id": "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
        "verificationMethod": [{
            "id": "did:plc:ewvi7nxzyoun6zhxrhs64oiz#atproto",
            "type": kind,
            "controller": "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
            "publicKeyMultibase": multibase,
        }],
    }))
    .unwrap()
}

/// The compressed SEC1 public key of a private key, by curve.
fn public_key(curve: SigningCurve, private: &[u8]) -> Vec<u8> {
    match curve {
        SigningCurve::P256 => p256::SecretKey::from_slice(private)
            .unwrap()
            .public_key()
            .to_encoded_point(true)
            .as_bytes()
            .to_vec(),
        SigningCurve::Secp256k1 => k256::SecretKey::from_slice(private)
            .unwrap()
            .public_key()
            .to_encoded_point(true)
            .as_bytes()
            .to_vec(),
    }
}

fn check_w3c(file: &str, curve: SigningCurve, count: usize) {
    let vectors = vectors(file);
    assert_eq!(vectors.len(), count, "{file}");
    for vector in vectors {
        let did_key = vector["publicDidKey"].as_str().unwrap();
        let multibase = did_key.strip_prefix("did:key:").unwrap();
        let key = document("Multikey", multibase).signing_key().unwrap();
        assert_eq!(key.curve(), curve, "{did_key}");
        assert_eq!(key.did_key(), did_key);

        // The P-256 file spells the private key in base58, the secp256k1 one in hex.
        let private = if let Some(base58) = vector["privateKeyBytesBase58"].as_str() {
            bs58::decode(base58).into_vec().unwrap()
        } else {
            let hex = vector["privateKeyBytesHex"].as_str().unwrap();
            (0..hex.len())
                .step_by(2)
                .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
                .collect()
        };
        let compressed = public_key(curve, &private);
        assert_eq!(key.as_sec1().as_slice(), compressed.as_slice(), "{did_key}");
    }
}

#[test]
fn w3c_p256_did_keys_decode_to_the_private_keys_public_key() {
    check_w3c("w3c_didkey_P256.json", SigningCurve::P256, 1);
}

#[test]
fn w3c_secp256k1_did_keys_decode_to_the_private_keys_public_key() {
    check_w3c("w3c_didkey_K256.json", SigningCurve::Secp256k1, 5);
}

#[test]
fn signature_fixture_keys_agree_in_their_did_key_and_legacy_suite_forms() {
    let fixtures = vectors("signature-fixtures.json");
    assert_eq!(fixtures.len(), 6);
    for fixture in fixtures {
        let did_key = fixture["publicKeyDid"].as_str().unwrap();
        let suite = fixture["didDocSuite"].as_str().unwrap();
        let curve = match fixture["algorithm"].as_str().unwrap() {
            "ES256" => SigningCurve::P256,
            "ES256K" => SigningCurve::Secp256k1,
            other => panic!("unexpected algorithm {other}"),
        };

        let legacy = document(suite, fixture["publicKeyMultibase"].as_str().unwrap())
            .signing_key()
            .unwrap_or_else(|error| panic!("{suite} key of {did_key}: {error}"));
        assert_eq!(legacy.curve(), curve);
        assert_eq!(legacy.did_key(), did_key, "{suite}");

        let multikey = document("Multikey", did_key.strip_prefix("did:key:").unwrap())
            .signing_key()
            .unwrap();
        assert_eq!(multikey, legacy);
    }
}

#[test]
fn a_key_of_the_wrong_curve_for_its_suite_is_refused() {
    // The secp256k1 fixture's legacy key, declared as a P-256 suite.
    let fixtures = vectors("signature-fixtures.json");
    let k256 = fixtures
        .iter()
        .find(|fixture| fixture["algorithm"] == "ES256K")
        .unwrap();
    let as_p256 = document(
        "EcdsaSecp256r1VerificationKey2019",
        k256["publicKeyMultibase"].as_str().unwrap(),
    );
    // Either refused, or (if the bytes happen to parse) not the k256 key.
    if let Ok(key) = as_p256.signing_key() {
        assert_ne!(key.did_key(), k256["publicKeyDid"].as_str().unwrap());
    }
}
