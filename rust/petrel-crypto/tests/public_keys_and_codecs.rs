//! Public key encodings, did:key/multikey codecs, Base58BTC, Hex, and StrictJSON tests
//! ported from `ATProtoPublicKeyTests.swift`, `PetrelCryptoTests.swift`, and `StrictJSON.swift`.

use std::collections::HashSet;

use petrel_crypto::{
    ATProtoCrypto, ATProtoExportableKeypair, ATProtoJWTVerificationKey, ATProtoKeyCurve,
    ATProtoPublicKey, Base58BTC, Hex, JWTBase64URL, K256Keypair, LegacyVerificationKeyCurve,
    P256DIDKey, P256Keypair, PLCDIDKeyCodec, PLCDIDVerificationKey, PetrelCryptoError, PublicKey,
    StrictJSON,
};

const SPEC_P256_MULTIKEY: &str = "zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo";
const SPEC_K256_MULTIKEY: &str = "zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc";
const SPEC_LEGACY_K256: &str =
    "zQYEBzXeuTM9UR3rfvNag6L3RNAs5pQZyYPsomTsgQhsxLdEgCrPTLgFna8yqCnxPpNT7DBk6Ym3dgPKNu86vt9GR";
const SPEC_PREFERRED_K256: &str = "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF";

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn specification_examples_parse_and_reencode_exactly() {
    let p256 = PublicKey::from_multikey(SPEC_P256_MULTIKEY).unwrap();
    assert_eq!(p256.curve(), ATProtoKeyCurve::P256);
    assert_eq!(p256.multikey(), SPEC_P256_MULTIKEY);
    assert_eq!(p256.did_key(), format!("did:key:{SPEC_P256_MULTIKEY}"));
    assert_eq!(&p256.multikey_bytes()[..2], &[0x80, 0x24]);

    let k256 = PublicKey::from_did_key(&format!("did:key:{SPEC_K256_MULTIKEY}")).unwrap();
    assert_eq!(k256.curve(), ATProtoKeyCurve::Secp256k1);
    assert_eq!(k256.multikey(), SPEC_K256_MULTIKEY);
    assert_eq!(&k256.multikey_bytes()[..2], &[0xe7, 0x01]);
    assert_eq!(k256.to_string(), format!("did:key:{SPEC_K256_MULTIKEY}"));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn legacy_and_preferred_k256_are_the_same_key() {
    let legacy =
        PublicKey::from_legacy_multibase(SPEC_LEGACY_K256, ATProtoKeyCurve::Secp256k1).unwrap();
    let preferred = PublicKey::from_multikey(SPEC_PREFERRED_K256).unwrap();
    assert_eq!(legacy, preferred);
    assert_eq!(legacy.multikey(), SPEC_PREFERRED_K256);
    assert_eq!(preferred.legacy_multibase(), SPEC_LEGACY_K256);

    let from_legacy =
        PublicKey::from_verification_method("EcdsaSecp256k1VerificationKey2019", SPEC_LEGACY_K256)
            .unwrap();
    let from_multikey =
        PublicKey::from_verification_method("Multikey", SPEC_PREFERRED_K256).unwrap();
    assert_eq!(from_legacy, from_multikey);

    let via_codec = PLCDIDKeyCodec::decode_legacy_multibase(
        SPEC_LEGACY_K256,
        LegacyVerificationKeyCurve::Secp256k1,
    )
    .unwrap();
    assert_eq!(via_codec.multikey(), SPEC_PREFERRED_K256);
    assert_eq!(
        PLCDIDKeyCodec::decode_multikey(SPEC_PREFERRED_K256).unwrap(),
        via_codec
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn corrupted_y_on_uncompressed_point_is_rejected() {
    for curve in ATProtoKeyCurve::ALL {
        let key = ATProtoCrypto::generate_keypair(curve)
            .unwrap()
            .public_key()
            .clone();
        let uncompressed = key.uncompressed_representation();
        let intact = PublicKey::from_legacy_multibase(
            &format!("z{}", Base58BTC::encode(&uncompressed)),
            curve,
        )
        .unwrap();
        assert_eq!(intact, key);

        let mut corrupted = uncompressed;
        corrupted[64] ^= 0x01;
        let multibase = format!("z{}", Base58BTC::encode(&corrupted));
        assert!(PublicKey::from_legacy_multibase(&multibase, curve).is_err());
        assert!(PublicKey::from_sec1(curve, &corrupted).is_err());
        assert!(
            PublicKey::from_verification_method(
                curve.legacy_verification_method_type(),
                &multibase
            )
            .is_err()
        );
        let legacy_curve = match curve {
            ATProtoKeyCurve::P256 => LegacyVerificationKeyCurve::P256,
            ATProtoKeyCurve::Secp256k1 => LegacyVerificationKeyCurve::Secp256k1,
        };
        assert!(PLCDIDKeyCodec::decode_legacy_multibase(&multibase, legacy_curve).is_err());
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn compressed_and_uncompressed_denote_one_identity() {
    for curve in ATProtoKeyCurve::ALL {
        let key = ATProtoCrypto::generate_keypair(curve)
            .unwrap()
            .public_key()
            .clone();
        let compressed = key.compressed_representation();
        let uncompressed = key.uncompressed_representation();
        assert_eq!(compressed[0], 0x02 + (uncompressed[64] & 1));
        assert_eq!(&uncompressed[1..33], &compressed[1..]);

        let from_c = PublicKey::from_sec1(curve, compressed).unwrap();
        let from_u = PublicKey::from_sec1(curve, &uncompressed).unwrap();
        assert_eq!(from_c, from_u);
        let mut set = HashSet::new();
        set.insert(from_c);
        assert!(set.contains(&from_u));
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn non_canonical_and_foreign_multikeys_are_rejected() {
    let p256 = P256Keypair::generate().unwrap().public_key().clone();
    let k256 = K256Keypair::generate().unwrap().public_key().clone();
    let mk = |bytes: &[u8]| format!("z{}", Base58BTC::encode(bytes));

    let rejected = vec![
        String::new(),
        "z".into(),
        format!("m{}", &p256.multikey()[1..]),
        p256.multikey()[1..].to_owned(),
        mk(&[&[0x80, 0x24][..], &p256.uncompressed_representation()[..]].concat()),
        mk(&[&[0xe7, 0x01][..], &k256.uncompressed_representation()[..]].concat()),
        mk(p256.compressed_representation()),
        mk(k256.compressed_representation()),
        mk(&[&[0x80, 0x24, 0x02][..], &[0xff; 32][..]].concat()),
        mk(&[&[0xe7, 0x01, 0x02][..], &[0xff; 32][..]].concat()),
        mk(&p256.multikey_bytes()[..34]),
        mk(&[&k256.multikey_bytes()[..], &[0x00][..]].concat()),
        mk(&[&[0xed, 0x01][..], &[7; 32][..]].concat()),
        mk(&[&[0x81, 0x24][..], &[7; 33][..]].concat()),
        P256Keypair::generate()
            .unwrap()
            .export_multibase()
            .unwrap()
            .to_string(),
        format!("z1{}", &p256.multikey()[1..]),
        format!("z0{}", &p256.multikey()[2..]),
        format!("{} ", p256.multikey()),
    ];
    for value in rejected {
        assert!(ATProtoPublicKey::from_multikey(&value).is_err(), "{value}");
        assert!(
            ATProtoPublicKey::from_did_key(&format!("did:key:{value}")).is_err(),
            "{value}"
        );
        assert!(PLCDIDKeyCodec::decode_multikey(&value).is_err(), "{value}");
        assert!(
            PLCDIDKeyCodec::decode(&format!("did:key:{value}")).is_err(),
            "{value}"
        );
    }

    assert_eq!(
        PublicKey::from_verification_method("Ed25519VerificationKey2020", &p256.multikey()),
        Err(PetrelCryptoError::UnsupportedAlgorithm(
            "verification method type Ed25519VerificationKey2020".into()
        ))
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn p256_and_k256_did_key_goldens_and_bridges() {
    // P-256 golden
    let priv7 = P256Keypair::from_raw(&[7_u8; 32]).unwrap();
    let encoded = P256DIDKey::from_public_key(priv7.public_key()).unwrap();
    assert_eq!(
        encoded.as_str(),
        "did:key:zDnaejgmAHMLkBPMBWnkBxyGxpXx8LgE4WJAYDhwZzyoRAddF"
    );
    let parsed_p256 = P256DIDKey::parse(encoded.as_str()).unwrap();
    assert_eq!(parsed_p256.public_key().unwrap(), *priv7.public_key());

    // K-256 d=1 generator golden
    let mut scalar1 = [0_u8; 32];
    scalar1[31] = 1;
    let k1 = K256Keypair::from_raw(&scalar1).unwrap();
    assert_eq!(
        Hex::encode(k1.public_key().compressed_representation()),
        "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
    );
    assert_eq!(
        k1.did_key(),
        "did:key:zQ3shVc2UkAfJCdc1TR8E66J85h48P43r93q8jGPkPpjF9Ef9"
    );

    // Uncompressed K-256 bridges to canonical did:key & identity
    let k_gen = K256Keypair::generate().unwrap();
    let uncompressed = k_gen.public_key().uncompressed_representation();
    let validated = PLCDIDVerificationKey::from_secp256k1_public_key(&uncompressed).unwrap();
    assert_eq!(validated.did_key(), k_gen.did_key());

    let hand_built = PLCDIDVerificationKey::Secp256k1(uncompressed.to_vec());
    assert_eq!(hand_built.did_key(), k_gen.did_key());
    assert_eq!(hand_built, validated);
    assert_eq!(hand_built.public_key().unwrap(), *k_gen.public_key());

    let jwt_c = ATProtoJWTVerificationKey::from_secp256k1_public_key(
        k_gen.public_key().compressed_representation(),
    )
    .unwrap();
    let jwt_u = ATProtoJWTVerificationKey::from_secp256k1_public_key(&uncompressed).unwrap();
    let jwt_h = ATProtoJWTVerificationKey::Secp256k1(uncompressed.to_vec());
    assert_eq!(jwt_c, jwt_u);
    assert_eq!(jwt_c, jwt_h);
    assert_eq!(
        jwt_c.deterministic_identity(),
        jwt_h.deterministic_identity()
    );
    assert_eq!(
        jwt_c.recovery_verifier_identity(),
        jwt_h.recovery_verifier_identity()
    );

    let sig = k_gen.sign_sync(b"one key, one identity").unwrap();
    for v in [&jwt_c, &jwt_u, &jwt_h] {
        assert!(v.verify(&sig, b"one key, one identity", "ES256K").unwrap());
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn base58btc_and_hex_and_base64url_and_strict_json() {
    // Base58BTC
    let sample = [0x00, 0x00, 0x01, 0x02, 0x03, 0xff, 0xfe];
    let enc = Base58BTC::encode(&sample);
    assert_eq!(Base58BTC::decode(&enc).unwrap(), sample);

    assert_eq!(Base58BTC::encode(&[]), "");
    assert_eq!(Base58BTC::encode(&[0]), "1");
    assert_eq!(Base58BTC::encode(&[0, 0]), "11");
    assert_eq!(Base58BTC::encode(&[0, 1]), "12");
    assert_eq!(Base58BTC::encode(&[57]), "z");
    assert_eq!(Base58BTC::encode(&[58]), "21");
    for len in 0..=40 {
        let zeros = vec![0_u8; len];
        let zenc = Base58BTC::encode(&zeros);
        assert_eq!(zenc, "1".repeat(len));
        if len > 0 {
            assert_eq!(Base58BTC::decode(&zenc).unwrap(), zeros);
        }
    }
    for bad in ["", "0", "O", "I", "l", "2 ", "+"] {
        assert!(Base58BTC::decode(bad).is_err(), "{bad}");
    }
    assert_eq!(Base58BTC::encode(b"Hello World!"), "2NEpo7TZRRrLZSi2U");
    assert_eq!(
        Base58BTC::decode("2NEpo7TZRRrLZSi2U").unwrap(),
        b"Hello World!"
    );
    assert_eq!(
        Base58BTC::encode(b"The quick brown fox jumps over the lazy dog."),
        "USm3fpXnKG5EUBx2ndxBDMPVciP5hGey2Jh4NDv6gmeo1LkMeiKrLJUUBk6Z"
    );
    assert_eq!(
        Base58BTC::encode(&[0x00, 0x00, 0x28, 0x7f, 0xb4, 0xcd]),
        "11233QC4"
    );

    // Hex
    let hex_data = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef];
    assert_eq!(Hex::encode(&hex_data), "0123456789abcdef");
    assert_eq!(Hex::decode("0123456789ABCDEF").unwrap(), hex_data);
    assert!(Hex::decode("abc").is_none());
    assert!(Hex::decode("zzzz").is_none());

    // JWTBase64URL canonical check
    assert_eq!(JWTBase64URL::decode("AA", 1).unwrap(), [0]);
    assert!(JWTBase64URL::decode("AA", 0).is_err());
    assert!(JWTBase64URL::decode("AA==", 4).is_err());
    // Non-canonical trailing bits ('B' instead of 'A' in "AB")
    assert!(JWTBase64URL::decode("AB", 4).is_err());

    // StrictJSON
    assert!(StrictJSON::validate(br#"{"a":1,"b":{"c":[true,false,null,"\uD83D\uDE00"]}}"#).is_ok());
    assert_eq!(
        StrictJSON::validate(br#"{"a":1,"a":2}"#),
        Err(PetrelCryptoError::Malformed("duplicate JSON member".into()))
    );
    assert_eq!(
        StrictJSON::validate(br#"{"outer":{"x":1,"x":2}}"#),
        Err(PetrelCryptoError::Malformed("duplicate JSON member".into()))
    );
    assert!(StrictJSON::validate(br#"{"a":1} trailing"#).is_err());
    assert!(StrictJSON::validate(br#"{"a":"\uD800"}"#).is_err());

    // Nesting depth 64 vs 65
    let ok_depth = format!("{}{}", "[".repeat(64), "]".repeat(64));
    let bad_depth = format!("{}{}", "[".repeat(65), "]".repeat(65));
    assert!(StrictJSON::validate(ok_depth.as_bytes()).is_ok());
    assert!(StrictJSON::validate(bad_depth.as_bytes()).is_err());

    // Integer member token enforcement
    assert!(
        StrictJSON::validate_top_level_integer_members(&["exp"], br#"{"exp":1700000000}"#).is_ok()
    );
    assert!(
        StrictJSON::validate_top_level_integer_members(&["exp"], br#"{"exp":1700000000.0}"#)
            .is_err()
    );
    assert!(StrictJSON::validate_top_level_integer_members(&["exp"], br#"{"exp":1e5}"#).is_err());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn invalid_hand_built_plc_keys_propagate_errors_without_panicking() {
    let sig = [0_u8; 64];
    for bad in [
        PLCDIDVerificationKey::P256([0_u8; 33]),
        PLCDIDVerificationKey::Secp256k1(vec![0_u8; 33]),
    ] {
        assert!(bad.public_key().is_err());
        assert!(ATProtoJWTVerificationKey::from_plc_key(&bad).is_err());
        assert!(ATProtoJWTVerificationKey::try_from(&bad).is_err());
        assert!(ATProtoJWTVerificationKey::try_from(bad.clone()).is_err());
        assert!(bad.verify(&sig, b"msg", "ES256").is_err());
        assert!(bad.verify(&sig, b"msg", "ES256K").is_err());

        let kp = P256Keypair::generate().unwrap();
        let mut opts = petrel_crypto::ServiceJWTMintOptions::new(
            "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
            "did:web:api.example.com#svc",
            Some("app.bsky.feed.getTimeline"),
        );
        opts.nonce = Some("plc-bad-key");
        let token = petrel_crypto::ServiceJWT::mint_sync(
            &opts,
            petrel_crypto::ServiceJWTSigningKey::P256(&kp),
        )
        .unwrap();

        assert!(
            petrel_crypto::ServiceJWT::verify_with_plc_key(
                &token,
                &bad,
                &petrel_crypto::ServiceJWTVerifyOptions::default(),
            )
            .is_err()
        );
        assert!(
            petrel_crypto::SpaceServiceJWT::verify_with_plc_key(
                &token, &bad, None, None, None, opts.now,
            )
            .is_err()
        );
    }
}
