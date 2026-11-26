//! Cross-language Spaces cryptography tests (`SpaceSetHash` and `SpaceMAC`).

use petrel_crypto::{Hex, P256DIDKey, P256Keypair, SpaceMAC, SpaceMACError, SpaceSetHash};
use serde::Deserialize;

const SPACES_VECTORS_JSON: &str =
    include_str!("../../../Tests/PetrelTests/Vectors/atproto_spaces_v1.json");

#[derive(Deserialize)]
struct SpacesVectors {
    version: u32,
    lthash: LtHashVectors,
    kem_p256: KemP256Vectors,
    commit_mac: CommitMacVectors,
    record_mac: RecordMacVectors,
}

#[derive(Deserialize)]
struct LtHashVectors {
    record_a: LtHashRecord,
    record_b: LtHashRecord,
    empty_commitment_hex: String,
    only_a_commitment_hex: String,
    only_b_commitment_hex: String,
    combined_ab_commitment_hex: String,
    after_remove_a_commitment_hex: String,
}

#[derive(Deserialize)]
struct LtHashRecord {
    path: String,
    cid: String,
}

#[derive(Deserialize)]
struct KemP256Vectors {
    author_secret_hex: String,
    author_kem_did_key: String,
    ephemeral_secret_hex: String,
    key_share_did_key: String,
    shared_secret_hex: String,
}

#[derive(Deserialize)]
struct CommitMacVectors {
    shared_secret_hex: String,
    mac_hex: String,
}

#[derive(Deserialize)]
struct RecordMacVectors {
    shared_secret_hex: String,
    mac_hex: String,
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn lthash_matches_atproto_spaces_v1_vectors() {
    let vectors: SpacesVectors = serde_json::from_str(SPACES_VECTORS_JSON).unwrap();
    assert_eq!(vectors.version, 1);

    let empty = SpaceSetHash::new();
    assert_eq!(
        Hex::encode(&empty.digest()),
        vectors.lthash.empty_commitment_hex
    );

    let mut forward = SpaceSetHash::new();
    forward.add(&vectors.lthash.record_a.path, &vectors.lthash.record_a.cid);
    assert_eq!(
        Hex::encode(&forward.digest()),
        vectors.lthash.only_a_commitment_hex
    );

    forward.add(&vectors.lthash.record_b.path, &vectors.lthash.record_b.cid);
    assert_eq!(
        Hex::encode(&forward.digest()),
        vectors.lthash.combined_ab_commitment_hex
    );

    let mut reverse = SpaceSetHash::new();
    reverse.add(&vectors.lthash.record_b.path, &vectors.lthash.record_b.cid);
    reverse.add(&vectors.lthash.record_a.path, &vectors.lthash.record_a.cid);
    assert_eq!(
        Hex::encode(&reverse.digest()),
        vectors.lthash.combined_ab_commitment_hex
    );

    forward.remove(&vectors.lthash.record_a.path, &vectors.lthash.record_a.cid);
    assert_eq!(
        Hex::encode(&forward.digest()),
        vectors.lthash.after_remove_a_commitment_hex
    );
    assert_eq!(
        Hex::encode(&forward.digest()),
        vectors.lthash.only_b_commitment_hex
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn space_mac_matches_rfc9180_export_only_vector() {
    let sender: [u8; 32] =
        Hex::decode("2f18b059576a0ec5a17121c0fe7ec8f00ea86f7b046fa3889ac8f21f89dbd484")
            .unwrap()
            .try_into()
            .unwrap();
    let author: [u8; 32] =
        Hex::decode("62c3868357a464f8461d03aa0182c7cebcde841036aea7230ddc7339f1088346")
            .unwrap()
            .try_into()
            .unwrap();
    let expected_secret: [u8; 32] =
        Hex::decode("2060e0558d1b34c10086bc137f849bb79ba59fcdc30544418e35c9cd301f0d0d")
            .unwrap()
            .try_into()
            .unwrap();

    let sender_keypair = P256Keypair::from_raw(&sender).unwrap();
    let author_keypair = P256Keypair::from_raw(&author).unwrap();
    let key_share = sender_keypair.did_key();

    let encap = SpaceMAC::encapsulate_with_ephemeral(&author_keypair.did_key(), &sender).unwrap();
    assert_eq!(encap.key_share, key_share);
    assert_eq!(&*encap.shared_secret, &expected_secret);

    let decap = SpaceMAC::decapsulate(&author, &key_share).unwrap();
    assert_eq!(&*decap, &expected_secret);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn space_mac_matches_atproto_spaces_v1_vectors() {
    let vectors: SpacesVectors = serde_json::from_str(SPACES_VECTORS_JSON).unwrap();
    let author_secret: [u8; 32] = Hex::decode(&vectors.kem_p256.author_secret_hex)
        .unwrap()
        .try_into()
        .unwrap();
    let eph_secret: [u8; 32] = Hex::decode(&vectors.kem_p256.ephemeral_secret_hex)
        .unwrap()
        .try_into()
        .unwrap();

    let encap =
        SpaceMAC::encapsulate_with_ephemeral(&vectors.kem_p256.author_kem_did_key, &eph_secret)
            .unwrap();
    assert_eq!(encap.key_share, vectors.kem_p256.key_share_did_key);
    assert_eq!(
        Hex::encode(&*encap.shared_secret),
        vectors.kem_p256.shared_secret_hex
    );

    let decap = SpaceMAC::decapsulate(&author_secret, &vectors.kem_p256.key_share_did_key).unwrap();
    assert_eq!(Hex::encode(&*decap), vectors.kem_p256.shared_secret_hex);

    // Also verify MAC authentication helpers.
    assert_eq!(
        vectors.commit_mac.shared_secret_hex,
        vectors.kem_p256.shared_secret_hex
    );
    assert_eq!(
        vectors.record_mac.shared_secret_hex,
        vectors.kem_p256.shared_secret_hex
    );
    assert_eq!(Hex::decode(&vectors.commit_mac.mac_hex).unwrap().len(), 32);
    assert_eq!(Hex::decode(&vectors.record_mac.mac_hex).unwrap().len(), 32);

    let message = b"atproto-space-mac-test";
    let tag = SpaceMAC::authentication_code(message, &*decap).unwrap();
    SpaceMAC::verify(&tag, message, &*decap).unwrap();
    let mut bad_tag = tag;
    bad_tag[0] ^= 0x01;
    assert_eq!(
        SpaceMAC::verify(&bad_tag, message, &*decap),
        Err(SpaceMACError::Mismatch)
    );
    assert_eq!(
        SpaceMAC::authentication_code(message, &[0_u8; 16]),
        Err(SpaceMACError::InvalidKey)
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn space_mac_fresh_keys_and_recipient_binding() {
    let recipient = P256Keypair::generate().unwrap();
    let stranger = P256Keypair::generate().unwrap();
    let key = P256DIDKey::from_public_key(recipient.public_key())
        .unwrap()
        .into_string();

    let first = SpaceMAC::encapsulate(&key).unwrap();
    let second = SpaceMAC::encapsulate(&key).unwrap();
    assert_ne!(first.key_share, second.key_share);
    assert_ne!(&*first.shared_secret, &*second.shared_secret);

    let recipient_raw = recipient.export_raw_representation();
    let stranger_raw = stranger.export_raw_representation();
    assert_eq!(
        SpaceMAC::decapsulate(&recipient_raw, &first.key_share).unwrap(),
        first.shared_secret
    );
    assert_ne!(
        SpaceMAC::decapsulate(&stranger_raw, &first.key_share).unwrap(),
        first.shared_secret
    );
    assert_eq!(
        SpaceMAC::encapsulate("did:key:zInvalid"),
        Err(SpaceMACError::InvalidKey)
    );
}
