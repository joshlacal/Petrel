//! Keypairs, signers, low-S boundary, and audit regression tests
//! ported from `ATProtoKeypairTests.swift`, `LowSBoundaryTests.swift`,
//! `AuditRegressionTests.swift`, and `CryptographyDocumentationTests.swift`.

#![cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]

use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

use k256::ecdsa::signature::{Signer as _, Verifier as _};
use petrel_crypto::{
    ATProtoCrypto, ATProtoExportableKeypair, ATProtoExternalSigner, ATProtoJWTVerificationKey,
    ATProtoKeyCurve, ATProtoKeypair, ATProtoSignature, ATProtoSignatureVerificationOptions,
    ATProtoSigner, ATProtoVerifier, Base58BTC, Hex, K256Keypair, P256Keypair, P256WireSignature,
    PetrelCryptoError, ServiceJWT, ServiceJWTMintOptions, ServiceJWTSigningKey,
    ServiceJWTVerifyOptions,
};
use sha2::{Digest, Sha256};

const MESSAGE: &[u8] = b"AT Protocol signs SHA-256 of these bytes";

const P256_ORDER_HEX: &str = "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551";
const P256_HALF_ORDER_HEX: &str =
    "7fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192a8";
const K256_ORDER_HEX: &str = "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141";
const K256_HALF_ORDER_HEX: &str =
    "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0";

/// Minimal 256-bit unsigned integer on four 64-bit limbs, independent of `scalar.rs`.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
struct TestUInt256([u64; 4]);

impl TestUInt256 {
    const ONE: Self = Self([0, 0, 0, 1]);

    fn from_hex(hex: &str) -> Self {
        assert_eq!(hex.len(), 64);
        let mut limbs = [0_u64; 4];
        for (i, limb) in limbs.iter_mut().enumerate() {
            *limb = u64::from_str_radix(&hex[i * 16..(i + 1) * 16], 16).unwrap();
        }
        Self(limbs)
    }

    fn from_bytes(bytes: &[u8]) -> Self {
        assert_eq!(bytes.len(), 32);
        let mut limbs = [0_u64; 4];
        for (i, limb) in limbs.iter_mut().enumerate() {
            *limb = u64::from_be_bytes(bytes[i * 8..(i + 1) * 8].try_into().unwrap());
        }
        Self(limbs)
    }

    fn to_hex(self) -> String {
        format!(
            "{:016x}{:016x}{:016x}{:016x}",
            self.0[0], self.0[1], self.0[2], self.0[3]
        )
    }

    fn to_bytes(self) -> [u8; 32] {
        let mut out = [0_u8; 32];
        for (i, limb) in self.0.iter().enumerate() {
            out[i * 8..(i + 1) * 8].copy_from_slice(&limb.to_be_bytes());
        }
        out
    }

    fn shifted_right_by_one(self) -> Self {
        let mut result = self.0;
        for i in (0..4).rev() {
            let carry_in = if i > 0 { (self.0[i - 1] & 1) << 63 } else { 0 };
            result[i] = (self.0[i] >> 1) | carry_in;
        }
        Self(result)
    }

    fn adding(self, other: Self) -> Self {
        let mut result = [0_u64; 4];
        let mut carry = false;
        for i in (0..4).rev() {
            let (partial, o1) = self.0[i].overflowing_add(other.0[i]);
            let (sum, o2) = partial.overflowing_add(u64::from(carry));
            result[i] = sum;
            carry = o1 || o2;
        }
        assert!(!carry);
        Self(result)
    }

    fn subtracting(self, other: Self) -> Self {
        let mut result = [0_u64; 4];
        let mut borrow = false;
        for i in (0..4).rev() {
            let (partial, b1) = self.0[i].overflowing_sub(other.0[i]);
            let (diff, b2) = partial.overflowing_sub(u64::from(borrow));
            result[i] = diff;
            borrow = b1 || b2;
        }
        assert!(!borrow);
        Self(result)
    }
}

fn order_for(curve: ATProtoKeyCurve) -> TestUInt256 {
    match curve {
        ATProtoKeyCurve::P256 => TestUInt256::from_hex(P256_ORDER_HEX),
        ATProtoKeyCurve::Secp256k1 => TestUInt256::from_hex(K256_ORDER_HEX),
    }
}

fn high_s_twin(signature: &[u8; 64], curve: ATProtoKeyCurve) -> [u8; 64] {
    let order = order_for(curve);
    let s = TestUInt256::from_bytes(&signature[32..]);
    let mut out = [0_u8; 64];
    out[..32].copy_from_slice(&signature[..32]);
    out[32..].copy_from_slice(&order.subtracting(s).to_bytes());
    out
}

fn der_encoding(signature: &[u8; 64]) -> Vec<u8> {
    fn encode_integer(bytes: &[u8]) -> Vec<u8> {
        let mut mag: Vec<u8> = bytes.iter().copied().skip_while(|&b| b == 0).collect();
        if mag.is_empty() {
            mag.push(0);
        }
        if mag[0] & 0x80 != 0 {
            mag.insert(0, 0);
        }
        let mut out = vec![0x02, u8::try_from(mag.len()).unwrap()];
        out.extend_from_slice(&mag);
        out
    }
    let mut body = encode_integer(&signature[..32]);
    body.extend_from_slice(&encode_integer(&signature[32..]));
    let mut out = vec![0x30, u8::try_from(body.len()).unwrap()];
    out.extend_from_slice(&body);
    out
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn generate_sign_verify_both_curves() {
    for curve in ATProtoKeyCurve::ALL {
        let keypair = ATProtoCrypto::generate_keypair(curve).unwrap();
        let signer: &dyn ATProtoSigner = &keypair;

        assert_eq!(signer.curve(), curve);
        assert_eq!(
            signer.jwt_algorithm(),
            match curve {
                ATProtoKeyCurve::P256 => "ES256",
                ATProtoKeyCurve::Secp256k1 => "ES256K",
            }
        );
        assert_eq!(keypair.public_key().curve(), curve);
        assert!(keypair.did_key().starts_with(match curve {
            ATProtoKeyCurve::P256 => "did:key:zDn",
            ATProtoKeyCurve::Secp256k1 => "did:key:zQ3",
        }));
        assert_eq!(keypair.did_key(), format!("did:key:{}", keypair.multikey()));

        let sig = signer.sign(MESSAGE).await.unwrap();
        assert!(ATProtoSignature::is_canonical(&sig, curve));

        let verifier: &dyn ATProtoVerifier = keypair.public_key();
        assert!(verifier.is_valid_signature(
            &sig,
            MESSAGE,
            ATProtoSignatureVerificationOptions::STRICT
        ));
        let mut extended = MESSAGE.to_vec();
        extended.push(0);
        assert!(!verifier.is_valid_signature(
            &sig,
            &extended,
            ATProtoSignatureVerificationOptions::STRICT
        ));

        assert!(ATProtoCrypto::verify_signature(&keypair.did_key(), MESSAGE, &sig).unwrap());

        for other in ATProtoKeyCurve::ALL {
            let stranger = ATProtoCrypto::generate_keypair(other).unwrap();
            assert!(!stranger.public_key().is_valid_signature(
                &sig,
                MESSAGE,
                ATProtoSignatureVerificationOptions::ALLOW_MALLEABLE
            ));
        }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn default_curve_is_k256_and_generated_keys_are_distinct() {
    assert_eq!(
        ATProtoCrypto::generate_default_keypair().unwrap().curve(),
        ATProtoKeyCurve::Secp256k1
    );
    let p256_set: std::collections::HashSet<String> = (0..16)
        .map(|_| P256Keypair::generate().unwrap().did_key())
        .collect();
    let k256_set: std::collections::HashSet<String> = (0..16)
        .map(|_| K256Keypair::generate().unwrap().did_key())
        .collect();
    assert_eq!(p256_set.len(), 16);
    assert_eq!(k256_set.len(), 16);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn p256_and_k256_interoperate_with_underlying_crates() {
    let p256_kp = P256Keypair::generate().unwrap();
    let p256_sig = p256_kp.sign_sync(MESSAGE).unwrap();
    let p256_sk =
        p256::ecdsa::SigningKey::from_bytes((&*p256_kp.export_raw_representation()).into())
            .unwrap();
    let lib_sig = p256::ecdsa::Signature::from_bytes((&p256_sig).into()).unwrap();
    p256_sk.verifying_key().verify(MESSAGE, &lib_sig).unwrap();

    let raw_from_lib: p256::ecdsa::Signature = p256_sk.sign(MESSAGE);
    let canonical =
        ATProtoSignature::canonicalize(&raw_from_lib.to_bytes(), ATProtoKeyCurve::P256).unwrap();
    assert!(p256_kp.public_key().verify_strict(&canonical, MESSAGE));

    let k256_kp = K256Keypair::generate().unwrap();
    let k256_sig = k256_kp.sign_sync(MESSAGE).unwrap();
    let k256_sk =
        k256::ecdsa::SigningKey::from_bytes((&*k256_kp.export_raw_representation()).into())
            .unwrap();
    let k256_lib_sig = k256::ecdsa::Signature::from_bytes((&k256_sig).into()).unwrap();
    k256_sk
        .verifying_key()
        .verify(MESSAGE, &k256_lib_sig)
        .unwrap();

    let from_k256: k256::ecdsa::Signature = k256_sk.sign(MESSAGE);
    assert_eq!(<[u8; 64]>::from(from_k256.to_bytes()), k256_sig);
    assert_eq!(k256_kp.sign_sync(MESSAGE).unwrap(), k256_sig);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn import_export_round_trip_and_invalid_scalars() {
    for curve in ATProtoKeyCurve::ALL {
        let original = ATProtoCrypto::generate_keypair(curve).unwrap();
        let raw = original.export_raw_representation();
        let hex = original.export_hex().unwrap();
        let multibase = original.export_multibase().unwrap();

        assert_eq!(hex.len(), 64);
        assert_eq!(*hex, hex.to_lowercase());
        assert!(multibase.starts_with('z'));

        let from_raw = ATProtoCrypto::import_keypair_raw(curve, &*raw).unwrap();
        let from_hex = ATProtoCrypto::import_keypair_hex(curve, &hex).unwrap();
        let from_upper = ATProtoCrypto::import_keypair_hex(curve, &hex.to_uppercase()).unwrap();
        let from_mb = ATProtoCrypto::import_keypair_multibase(&multibase).unwrap();
        let bare_mb = format!("z{}", Base58BTC::encode(&*raw));

        let mut restored: Vec<Box<dyn ATProtoExportableKeypair>> = vec![
            Box::new(from_raw),
            Box::new(from_hex),
            Box::new(from_upper),
            Box::new(from_mb),
        ];
        match curve {
            ATProtoKeyCurve::P256 => {
                restored.push(Box::new(P256Keypair::from_multibase(&multibase).unwrap()));
                restored.push(Box::new(P256Keypair::from_multibase(&bare_mb).unwrap()));
            }
            ATProtoKeyCurve::Secp256k1 => {
                restored.push(Box::new(K256Keypair::from_multibase(&multibase).unwrap()));
                restored.push(Box::new(K256Keypair::from_multibase(&bare_mb).unwrap()));
            }
        }
        for item in restored {
            assert_eq!(item.curve(), curve);
            assert_eq!(item.did_key(), original.did_key());
            assert_eq!(*item.export_raw_representation().unwrap(), *raw);
            let sig = item.sign(MESSAGE).await.unwrap();
            assert!(original.public_key().verify_strict(&sig, MESSAGE));
        }

        let decoded = Base58BTC::decode(&multibase[1..]).unwrap();
        assert_eq!(decoded.len(), 34);
        assert_eq!(&decoded[..2], &curve.private_key_multicodec_prefix());
        assert_eq!(&decoded[2..], &*raw);

        // Invalid scalars
        let order = order_for(curve);
        for bad in [
            vec![],
            vec![0_u8; 32],
            order.to_bytes().to_vec(),
            vec![0xff_u8; 32],
            vec![1_u8; 31],
            vec![1_u8; 33],
        ] {
            assert!(ATProtoCrypto::import_keypair_raw(curve, &bad).is_err());
        }
        for bad_hex in [
            String::new(),
            "zz".into(),
            "0".repeat(64),
            "1".repeat(63),
            "g".repeat(64),
        ] {
            assert!(ATProtoCrypto::import_keypair_hex(curve, &bad_hex).is_err());
        }
        let largest = ATProtoCrypto::import_keypair_raw(
            curve,
            &order.subtracting(TestUInt256::ONE).to_bytes(),
        )
        .unwrap();
        assert_eq!(
            *largest.export_raw_representation(),
            order.subtracting(TestUInt256::ONE).to_bytes()
        );
        let smallest =
            ATProtoCrypto::import_keypair_raw(curve, &TestUInt256::ONE.to_bytes()).unwrap();
        let expected_gen_x = match curve {
            ATProtoKeyCurve::P256 => {
                "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296"
            }
            ATProtoKeyCurve::Secp256k1 => {
                "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
            }
        };
        assert_eq!(
            Hex::encode(&smallest.public_key().compressed_representation()[1..]),
            expected_gen_x
        );
    }

    // Cross-curve private multikey mismatch & bare multibase refusal
    let p256_mb = P256Keypair::generate().unwrap().export_multibase().unwrap();
    let k256_mb = K256Keypair::generate().unwrap().export_multibase().unwrap();
    assert!(K256Keypair::from_multibase(&p256_mb).is_err());
    assert!(P256Keypair::from_multibase(&k256_mb).is_err());

    let bare = format!(
        "z{}",
        Base58BTC::encode(&*P256Keypair::generate().unwrap().export_raw_representation())
    );
    assert!(ATProtoCrypto::import_keypair_multibase(&bare).is_err());
    let ed25519 = format!(
        "z{}",
        Base58BTC::encode(&[&[0x80_u8, 0x26][..], &[7_u8; 32][..]].concat())
    );
    assert!(ATProtoCrypto::import_keypair_multibase(&ed25519).is_err());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn debug_and_display_never_leak_private_scalar() {
    let p256 = P256Keypair::generate().unwrap();
    let k256 = K256Keypair::generate().unwrap();
    for (text, secret) in [
        (format!("{p256:?}"), p256.export_raw_representation()),
        (format!("{p256}"), p256.export_raw_representation()),
        (format!("{k256:?}"), k256.export_raw_representation()),
        (format!("{k256}"), k256.export_raw_representation()),
    ] {
        assert!(!text.to_lowercase().contains(&Hex::encode(&*secret)));
        assert!(!text.contains(&Base58BTC::encode(&*secret)));
        assert!(text.contains("did:key:z"));
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn strict_by_default_and_lax_modes_opt_in() {
    for curve in ATProtoKeyCurve::ALL {
        let kp = ATProtoCrypto::generate_keypair(curve).unwrap();
        let sig = kp.sign(MESSAGE).await.unwrap();
        let high_s = high_s_twin(&sig, curve);
        let der = der_encoding(&sig);
        let high_s_der = der_encoding(&high_s);

        assert!(ATProtoCrypto::verify_signature(&kp.did_key(), MESSAGE, &sig).unwrap());
        assert!(!ATProtoCrypto::verify_signature(&kp.did_key(), MESSAGE, &high_s).unwrap());
        assert!(!ATProtoCrypto::verify_signature(&kp.did_key(), MESSAGE, &der).unwrap());
        assert!(!ATProtoCrypto::verify_signature(&kp.did_key(), MESSAGE, &high_s_der).unwrap());

        for (candidate, expected_jwt, expected_malleable) in [
            (&sig[..], true, true),
            (&high_s[..], true, true),
            (&der[..], false, true),
            (&high_s_der[..], false, true),
        ] {
            assert_eq!(
                kp.public_key().is_valid_signature(
                    candidate,
                    MESSAGE,
                    ATProtoSignatureVerificationOptions::JWT
                ),
                expected_jwt
            );
            assert_eq!(
                kp.public_key().is_valid_signature(
                    candidate,
                    MESSAGE,
                    ATProtoSignatureVerificationOptions::ALLOW_MALLEABLE
                ),
                expected_malleable
            );
        }

        let der_low_s_only = ATProtoSignatureVerificationOptions::new(false, true);
        assert!(
            kp.public_key()
                .is_valid_signature(&der, MESSAGE, der_low_s_only)
        );
        assert!(
            !kp.public_key()
                .is_valid_signature(&high_s_der, MESSAGE, der_low_s_only)
        );
        assert!(
            !kp.public_key()
                .is_valid_signature(&high_s, MESSAGE, der_low_s_only)
        );

        // Strict JWT key verification error parity
        let jwt_key = ATProtoJWTVerificationKey::from_public_key(kp.public_key());
        assert!(jwt_key.verify(&sig, MESSAGE, kp.jwt_algorithm()).unwrap());
        assert_eq!(
            jwt_key.verify(&high_s, MESSAGE, kp.jwt_algorithm()),
            Err(PetrelCryptoError::Unauthorized(
                "JWT signature is not a canonical low-S compact signature".into()
            ))
        );
        assert!(
            jwt_key
                .verify_with_options(
                    &high_s,
                    MESSAGE,
                    kp.jwt_algorithm(),
                    ATProtoSignatureVerificationOptions::JWT
                )
                .unwrap()
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn external_signer_normalizes_and_fails_closed() {
    for curve in ATProtoKeyCurve::ALL {
        let backing = Arc::new(ATProtoCrypto::generate_keypair(curve).unwrap());
        let expected = backing.sign(MESSAGE).await.unwrap();

        for mode in 0..4 {
            let b = Arc::clone(&backing);
            let signer = ATProtoExternalSigner::new(backing.public_key().clone(), move |req| {
                let b = Arc::clone(&b);
                Box::pin(async move {
                    assert_eq!(req.curve, curve);
                    let expected_digest: [u8; 32] = Sha256::digest(&req.message).into();
                    assert_eq!(req.sha256_digest, expected_digest);
                    let canonical = b.sign_sync(&req.message)?;
                    Ok(match mode {
                        0 => canonical.to_vec(),
                        1 => high_s_twin(&canonical, curve).to_vec(),
                        2 => der_encoding(&canonical),
                        _ => der_encoding(&high_s_twin(&canonical, curve)),
                    })
                })
            });
            let sig = signer.sign(MESSAGE).await.unwrap();
            assert!(ATProtoSignature::is_canonical(&sig, curve));
            assert!(backing.public_key().verify_strict(&sig, MESSAGE));
            if curve == ATProtoKeyCurve::Secp256k1 {
                assert_eq!(sig, expected);
            }
        }

        // Wrong key fails closed
        let actual = Arc::new(ATProtoCrypto::generate_keypair(curve).unwrap());
        let wrong_key = ATProtoExternalSigner::new(backing.public_key().clone(), move |req| {
            let a = Arc::clone(&actual);
            Box::pin(async move { Ok(a.sign_sync(&req.message)?.to_vec()) })
        });
        assert!(wrong_key.sign(MESSAGE).await.is_err());

        // Double hashing fails closed
        let b2 = Arc::clone(&backing);
        let double_hash = ATProtoExternalSigner::new(backing.public_key().clone(), move |req| {
            let b = Arc::clone(&b2);
            Box::pin(async move { Ok(b.sign_sync(&req.sha256_digest)?.to_vec()) })
        });
        assert!(double_hash.sign(MESSAGE).await.is_err());

        // Garbage fails closed
        let garbage = ATProtoExternalSigner::new(backing.public_key().clone(), |_| {
            Box::pin(async { Ok(vec![0xab; 70]) })
        });
        assert!(garbage.sign(MESSAGE).await.is_err());
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn low_s_boundary_exact_and_signers_always_emit_low_s() {
    for (curve, order_hex, half_hex) in [
        (ATProtoKeyCurve::P256, P256_ORDER_HEX, P256_HALF_ORDER_HEX),
        (
            ATProtoKeyCurve::Secp256k1,
            K256_ORDER_HEX,
            K256_HALF_ORDER_HEX,
        ),
    ] {
        let order = TestUInt256::from_hex(order_hex);
        let half = order.shifted_right_by_one();
        assert_eq!(half.adding(half).adding(TestUInt256::ONE), order);
        assert_eq!(half.to_hex(), half_hex);

        let r = TestUInt256::ONE.to_bytes();
        let half_plus_one = half.adding(TestUInt256::ONE).to_bytes();

        let mut at_boundary = [0_u8; 64];
        at_boundary[..32].copy_from_slice(&r);
        at_boundary[32..].copy_from_slice(&half.to_bytes());
        assert!(ATProtoSignature::is_low_s(&at_boundary, curve));
        assert!(ATProtoSignature::is_canonical(&at_boundary, curve));
        assert_eq!(
            ATProtoSignature::canonicalize(&at_boundary, curve).unwrap(),
            at_boundary
        );

        let mut just_over = [0_u8; 64];
        just_over[..32].copy_from_slice(&r);
        just_over[32..].copy_from_slice(&half_plus_one);
        assert!(!ATProtoSignature::is_low_s(&just_over, curve));
        assert!(!ATProtoSignature::is_canonical(&just_over, curve));
        assert_eq!(
            ATProtoSignature::canonicalize(&just_over, curve).unwrap(),
            at_boundary
        );

        if curve == ATProtoKeyCurve::P256 {
            assert!(P256WireSignature::is_canonical_low_s(&at_boundary));
            assert!(!P256WireSignature::is_canonical_low_s(&just_over));
            assert_eq!(
                P256WireSignature::canonicalize(&just_over).unwrap(),
                at_boundary
            );
            assert!(P256WireSignature::decode_malleability_tolerant(&just_over).is_ok());

            // Audit regression: inside the historical off-by-one byte gap (`d6` vs `e5`)
            let mut inside_gap = half.to_bytes();
            inside_gap[31] -= 1;
            let mut gap_sig = [0_u8; 64];
            gap_sig[..32].copy_from_slice(&r);
            gap_sig[32..].copy_from_slice(&inside_gap);
            assert!(P256WireSignature::is_canonical_low_s(&gap_sig));
            assert_eq!(P256WireSignature::canonicalize(&gap_sig).unwrap(), gap_sig);
        } else {
            assert!(ATProtoJWTVerificationKey::is_canonical_secp256k1_signature(
                &at_boundary
            ));
            assert!(!ATProtoJWTVerificationKey::is_canonical_secp256k1_signature(&just_over));
        }

        let kp = ATProtoCrypto::generate_keypair(curve).unwrap();
        for i in 0..64 {
            let msg = format!("low-S message {i}");
            let sig = kp.sign_sync(msg.as_bytes()).unwrap();
            assert!(ATProtoSignature::is_canonical(&sig, curve));
            let twin = high_s_twin(&sig, curve);
            assert!(!ATProtoSignature::is_low_s(&twin, curve));
            assert!(kp.public_key().verify_strict(&sig, msg.as_bytes()));
            assert!(!kp.public_key().verify_strict(&twin, msg.as_bytes()));
            assert!(kp.public_key().is_valid_signature(
                &twin,
                msg.as_bytes(),
                ATProtoSignatureVerificationOptions::JWT
            ));
            assert_eq!(ATProtoSignature::canonicalize(&twin, curve).unwrap(), sig);
        }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn audit_regression_high_s_service_jwt_verifies() {
    let kp = P256Keypair::generate().unwrap();
    let now = web_time::UNIX_EPOCH + std::time::Duration::from_secs(1_700_000_000);
    let opts = ServiceJWTMintOptions {
        issuer: "did:plc:abcdefghijklmnopqrstuvwx",
        audience: "did:web:api.bsky.app",
        lexicon_method: Some("app.bsky.actor.getProfile"),
        key_id: None,
        nonce: Some("audit-high-s"),
        request_body_digest: None,
        now,
        lifetime: std::time::Duration::from_secs(60),
    };
    let token = ServiceJWT::mint_sync(&opts, ServiceJWTSigningKey::P256(&kp)).unwrap();
    let parts: Vec<&str> = token.split('.').collect();
    let sig_bytes: [u8; 64] = petrel_crypto::JWTBase64URL::decode(parts[2], 64)
        .unwrap()
        .try_into()
        .unwrap();
    let high_s = high_s_twin(&sig_bytes, ATProtoKeyCurve::P256);
    let high_s_token = format!(
        "{}.{}.{}",
        parts[0],
        parts[1],
        petrel_crypto::JWTBase64URL::encode(&high_s)
    );
    let claims = ServiceJWT::verify_with_options(
        &high_s_token,
        &ATProtoJWTVerificationKey::from_public_key(kp.public_key()),
        &ServiceJWTVerifyOptions {
            now,
            ..Default::default()
        },
    )
    .unwrap();
    assert_eq!(claims.jti.as_deref(), Some("audit-high-s"));

    // Sha256 & random_bytes checks
    assert_eq!(
        ATProtoCrypto::sha256_hex(b"abc"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
    assert_eq!(ATProtoCrypto::random_bytes(0).unwrap(), [] as [u8; 0]);
    assert_ne!(
        ATProtoCrypto::random_bytes(32).unwrap(),
        ATProtoCrypto::random_bytes(32).unwrap()
    );
    let counter = AtomicUsize::new(0);
    counter.fetch_add(1, Ordering::Relaxed);
}
