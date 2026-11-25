use p256::ecdsa::SigningKey as P256SigningKey;
use petrel_server::jose::{
    OAuthCompactJwt, OAuthCurve, OAuthJsonWebKey, OAuthJsonWebKeySet, OAuthJwsAlgorithm,
    OAuthJwtSignatureEncoding, OAuthJwtVerificationConstraints, OAuthSigningKey,
};
use petrel_server::support::base64url_encode;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
struct SampleClaims {
    iss: String,
    sub: String,
    exp: i64,
    iat: i64,
    jti: String,
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn sign_and_verify_es256_and_es256k_roundtrip() {
    for alg in [OAuthJwsAlgorithm::Es256, OAuthJwsAlgorithm::Es256k] {
        let key = OAuthSigningKey::generate(alg, Some("k-1".to_owned())).unwrap();
        let pub_jwk = key.public_jwk(true).unwrap();
        let claims = SampleClaims {
            iss: "did:plc:alice".to_owned(),
            sub: "did:plc:alice".to_owned(),
            exp: 1_700_000_300,
            iat: 1_700_000_000,
            jti: "nonce-1".to_owned(),
        };
        let jwt = OAuthCompactJwt::sign(&claims, &key, Some("JWT"), false).unwrap();
        let mut constraints = OAuthJwtVerificationConstraints::new(1_700_000_010);
        constraints.expected_issuer = Some("did:plc:alice".to_owned());
        constraints.expected_type = Some("JWT".to_owned());
        let verified =
            OAuthCompactJwt::verify_with_jwk::<SampleClaims>(&jwt, &pub_jwk, &constraints)
                .expect("verify JWT");
        assert_eq!(verified.claims, claims);
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn did_key_roundtrip_p256_and_k256() {
    for alg in [OAuthJwsAlgorithm::Es256, OAuthJwsAlgorithm::Es256k] {
        let key = OAuthSigningKey::generate(alg, None).unwrap();
        let jwk = key.public_jwk(false).unwrap();
        let did_key = jwk.did_key().unwrap();
        let parsed = OAuthJsonWebKey::from_did_key(&did_key).unwrap();
        assert_eq!(parsed.thumbprint(), jwk.thumbprint());
        assert_eq!(parsed.crv, jwk.crv);
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn high_s_signature_rejected_by_canonical_low_s_accepted_by_jose_interoperable() {
    use p256::ecdsa::signature::Signer as _;
    use p256::elliptic_curve::ops::Reduce as _;
    use p256::{Scalar, U256};

    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("k1".into())).unwrap();
    let jwk = key.public_jwk(true).unwrap();
    let raw = key.raw_secret();
    let p256_sk = P256SigningKey::from_slice(&raw[..]).unwrap();

    let header = r#"{"alg":"ES256","kid":"k1"}"#;
    let payload = r#"{"iss":"a","sub":"a","exp":2000000000,"iat":1700000000,"jti":"1"}"#;
    let input = format!(
        "{}.{}",
        base64url_encode(header.as_bytes()),
        base64url_encode(payload.as_bytes())
    );
    let sig: p256::ecdsa::Signature = p256_sk.sign(input.as_bytes());
    let low_sig = sig.normalize_s().unwrap_or(sig);
    let bytes = low_sig.to_bytes();
    let r = &bytes[..32];
    let s_scalar = Scalar::reduce(U256::from_be_slice(&bytes[32..]));
    let high_s = (-s_scalar).to_bytes();

    let mut malleable_sig = Vec::with_capacity(64);
    malleable_sig.extend_from_slice(r);
    malleable_sig.extend_from_slice(&high_s);
    let malleable_jwt = format!("{input}.{}", base64url_encode(&malleable_sig));

    let mut strict_c = OAuthJwtVerificationConstraints::new(1_700_000_010);
    strict_c.signature_encoding = OAuthJwtSignatureEncoding::CanonicalLowS;
    assert!(
        OAuthCompactJwt::verify_with_jwk::<SampleClaims>(&malleable_jwt, &jwk, &strict_c).is_err()
    );

    let mut jose_c = OAuthJwtVerificationConstraints::new(1_700_000_010);
    jose_c.signature_encoding = OAuthJwtSignatureEncoding::JoseInteroperable;
    assert!(
        OAuthCompactJwt::verify_with_jwk::<SampleClaims>(&malleable_jwt, &jwk, &jose_c).is_ok()
    );
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn strict_json_and_jwks_reject_duplicate_keys_and_private_material() {
    let dup_payload = r#"{"alg":"ES256","alg":"ES256"}"#;
    let compact = format!(
        "{}.e30.{}",
        base64url_encode(dup_payload.as_bytes()),
        base64url_encode(&[0; 64])
    );
    assert!(OAuthCompactJwt::parse_unverified_header(&compact).is_err());

    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("good".into())).unwrap();
    let pub_jwk = key.public_jwk(true).unwrap();

    // JWKS with private key material in one entry is skipped, while a good EC entry is accepted;
    // a malformed EC entry fails strictly.
    let private_entry = serde_json::json!({
        "kty": "EC", "crv": "P-256", "kid": "priv", "x": pub_jwk.x, "y": pub_jwk.y, "d": pub_jwk.x
    });
    let doc = serde_json::json!({ "keys": [pub_jwk, private_entry] }).to_string();
    let decoded = OAuthJsonWebKeySet::decode_validated(doc.as_bytes()).unwrap();
    assert_eq!(decoded.keys.len(), 1);
    assert_eq!(decoded.keys[0].kid.as_deref(), Some("good"));

    // Invalid EC coordinate length fails decoding.
    let bad_ec = r#"{"keys":[{"kty":"EC","crv":"P-256","x":"AAAA","y":"BBBB"}]}"#;
    assert!(OAuthJsonWebKeySet::decode_validated(bad_ec.as_bytes()).is_err());

    // Direct JWK deserialization rejects private material.
    let priv_jwk = serde_json::json!({
        "kty": "EC", "crv": "P-256", "x": decoded.keys[0].x, "y": decoded.keys[0].y, "d": decoded.keys[0].x
    })
    .to_string();
    assert!(serde_json::from_str::<OAuthJsonWebKey>(&priv_jwk).is_err());
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn rejects_crit_b64_and_invalid_curve_points() {
    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("k".into())).unwrap();
    let jwk = key.public_jwk(true).unwrap();

    let crit_header = r#"{"alg":"ES256","crit":["exp"]}"#;
    let payload = r#"{"iss":"a","sub":"a","exp":2000000000,"iat":1700000000,"jti":"1"}"#;
    let input = format!(
        "{}.{}",
        base64url_encode(crit_header.as_bytes()),
        base64url_encode(payload.as_bytes())
    );
    let sig = key.sign(input.as_bytes()).unwrap();
    let jwt = format!("{input}.{}", base64url_encode(&sig));
    let c = OAuthJwtVerificationConstraints::new(1_700_000_010);
    assert!(OAuthCompactJwt::verify_with_jwk::<SampleClaims>(&jwt, &jwk, &c).is_err());

    // Point at infinity / off-curve rejected
    assert!(
        OAuthJsonWebKey::from_coordinates(OAuthCurve::P256, &[0; 32], &[0; 32], None, None, None)
            .is_err()
    );
}
