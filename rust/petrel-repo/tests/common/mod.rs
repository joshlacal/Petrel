#![allow(dead_code, unreachable_pub)]

use std::sync::Arc;

use petrel_core::{Cid, Did, Value, dagcbor};
use petrel_repo::block_store::{BlockStore, InMemoryBlockStore};
use petrel_repo::crypto::{P256Keypair, SigningAlgorithm};
use petrel_repo::mst::{MstKeySyntax, MstOptions, MstProof, RepositoryMst, build_mst_from_entries};
use petrel_repo::types::RepositoryReadPolicy;

pub fn mst_common_prefix_json() -> &'static str {
    include_str!("../../../../Tests/PetrelRepoTests/Vectors/mst/common_prefix.json")
}

pub fn mst_key_heights_json() -> &'static str {
    include_str!("../../../../Tests/PetrelRepoTests/Vectors/mst/key_heights.json")
}

pub fn mst_example_keys_txt() -> &'static str {
    include_str!("../../../../Tests/PetrelRepoTests/Vectors/mst/example_keys.txt")
}

pub fn data_model_fixtures_json() -> &'static str {
    include_str!("../../../../Tests/PetrelRepoTests/Vectors/data-model/data-model-fixtures.json")
}

pub fn data_model_valid_json() -> &'static str {
    include_str!("../../../../Tests/PetrelRepoTests/Vectors/data-model/data-model-valid.json")
}

pub fn data_model_invalid_json() -> &'static str {
    include_str!("../../../../Tests/PetrelRepoTests/Vectors/data-model/data-model-invalid.json")
}

pub fn commit_proof_fixtures_json() -> &'static str {
    include_str!("../../../../Tests/PetrelRepoTests/Vectors/firehose/commit-proof-fixtures.json")
}

pub fn real_repo_car() -> &'static [u8] {
    include_bytes!("../../../../Tests/PetrelRepoTests/Vectors/real-repo/repo.car")
}

pub fn real_repo_diddoc() -> &'static [u8] {
    include_bytes!("../../../../Tests/PetrelRepoTests/Vectors/real-repo/diddoc.json")
}

pub fn real_repo_expected_json() -> &'static str {
    include_str!("../../../../Tests/PetrelRepoTests/Vectors/real-repo/expected.json")
}

pub fn real_repo_proof_present_car() -> &'static [u8] {
    include_bytes!("../../../../Tests/PetrelRepoTests/Vectors/real-repo/record-proof-present.car")
}

pub fn real_repo_proof_absent_car() -> &'static [u8] {
    include_bytes!("../../../../Tests/PetrelRepoTests/Vectors/real-repo/record-proof-absent.car")
}

pub fn encode_raw_car(roots: &[Cid], frames: &[(Vec<u8>, Vec<u8>)]) -> Vec<u8> {
    let mut header_map = std::collections::BTreeMap::new();
    header_map.insert(
        "roots".to_owned(),
        Value::Array(roots.iter().cloned().map(Value::Link).collect()),
    );
    header_map.insert("version".to_owned(), Value::Integer(1));
    let header_cbor = dagcbor::encode(&Value::Object(header_map));
    let mut out = Vec::new();
    petrel_repo::car::varint::push_varint(header_cbor.len() as u64, &mut out).unwrap();
    out.extend_from_slice(&header_cbor);
    for (raw_cid, payload) in frames {
        petrel_repo::car::varint::push_varint((raw_cid.len() + payload.len()) as u64, &mut out)
            .unwrap();
        out.extend_from_slice(raw_cid);
        out.extend_from_slice(payload);
    }
    out
}

pub fn test_did() -> Did {
    Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap()
}

pub fn deterministic_p256_signer() -> P256Keypair {
    let mut seed = [0_u8; 32];
    seed[31] = 7;
    P256Keypair::from_bytes(&seed).unwrap()
}

pub fn build_raw_mst(
    entries: Vec<(String, Cid)>,
    syntax: MstKeySyntax,
) -> (RepositoryMst, Arc<InMemoryBlockStore>) {
    let options = MstOptions {
        key_syntax: syntax,
        policy: RepositoryReadPolicy::data_model(),
        require_canonical_prefix: true,
        ..MstOptions::default()
    };
    let (tree, blocks) = build_mst_from_entries(entries, options).unwrap();
    let store = Arc::new(
        InMemoryBlockStore::from_blocks(blocks.into_iter().map(|b| (b.cid, b.bytes))).unwrap(),
    );
    let reopened =
        RepositoryMst::open_with_options(tree.root_cid().clone(), store.clone(), options);
    (reopened, store)
}

pub async fn check_inclusion_and_exclusion(
    root: &Cid,
    key: &str,
    expected: Option<&Cid>,
    store: &dyn BlockStore,
    syntax: MstKeySyntax,
) {
    let options = MstOptions {
        key_syntax: syntax,
        policy: RepositoryReadPolicy::data_model(),
        ..MstOptions::default()
    };
    let proof_blocks = MstProof::build_proof_blocks(root, key, store, &options)
        .await
        .unwrap();
    let proof_store = InMemoryBlockStore::from_blocks(proof_blocks).unwrap();
    match expected {
        Some(cid) => MstProof::verify_inclusion(root, key, cid, &proof_store, &options)
            .await
            .unwrap(),
        None => MstProof::verify_exclusion(root, key, &proof_store, &options)
            .await
            .unwrap(),
    }
}

pub fn algo_name(a: SigningAlgorithm) -> &'static str {
    match a {
        SigningAlgorithm::P256 => "p256",
        SigningAlgorithm::Secp256k1 => "secp256k1",
    }
}
