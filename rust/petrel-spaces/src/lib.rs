//! AT Protocol Permissioned Spaces for Petrel (`at:space/` URIs, Nov 24 alpha).
//!
//! Unifies Space authentication, delegation & credential tokens, RFC 9421 proof-of-possession
//! HTTP signatures, HPKE P-256 `SpaceMACHeader`, BLAKE3 `SpaceSetHash`, `SpaceSTAR` archives,
//! DID host resolution, `SpaceCredentialManager`, `SpaceHost`, and `SpaceSyncEngine` on top of
//! `petrel-core`, `petrel-crypto`, `petrel-api`, and `petrel` for both native and `wasm32`.

pub mod credential_manager;
pub mod error;
pub mod host;
pub mod http_signature;
pub mod kem;
pub mod mac_header;
pub mod resolver;
pub mod set_hash;
pub mod sf;
pub mod signature_replay;
pub mod star;
pub mod sync_engine;
pub mod tokens;

pub use credential_manager::{
    CREDENTIAL_REFRESH_MARGIN_SECS, CREDENTIAL_REVOKED_ERROR_NAME, CredentialCache,
    CredentialExchanger, DEFAULT_MAX_BLOB_BYTES, DelegationMinter, HttpCredentialExchanger,
    InMemoryCredentialCache, PdsDelegationMinter, SpaceCredential, SpaceCredentialManager,
    classify_authorize_space_sync_error,
};
pub use error::{Result, SpaceBlobLocator, SpaceError, constant_time_eq, parse_space_ref};
pub use host::{
    HostedSpace, InMemorySpaceHostBackend, NotifyRegistration, SpaceHost, SpaceHostBackend,
    WriterState,
};
pub use http_signature::{
    MAX_HTTP_SIGNATURE_AGE_SECS, MAX_HTTP_SIGNATURE_SKEW_SECS, MAX_NONCE_BYTES,
    SPACE_AUDIENCE_HEADER, SPACE_AUTH_SCHEME, SPACE_SIGNATURE_LABEL, SPACE_SIGNATURE_TAG,
    SpaceRequestHeaders, VerifiedHttpSignature, VerifiedSpaceHeaders, derive_audience,
    did_web_from_url, sign_credential_request, sign_credential_request_minimal,
    sign_credential_request_with_params, verify_credential_headers, verify_credential_request,
    verify_credential_request_with_window, verify_http_signature_against_key,
};
pub use kem::{
    decapsulate_p256, decode_p256_did_key, encapsulate_p256, encapsulate_p256_with_ephemeral,
    encode_p256_did_key, generate_p256_keypair,
};
pub use mac_header::{
    AcceptSignatureRequest, MacProfile, SpaceMacHeaders, VerifiedCommitMac, VerifiedRecordMac,
    format_accept_signature, parse_accept_signature, sign_commit_mac, sign_record_mac,
    verify_commit_mac, verify_record_mac,
};
pub use resolver::{
    DEFAULT_DID_CACHE_MAX_ENTRIES, DEFAULT_DID_CACHE_TTL_SECS, DEFAULT_DID_NEGATIVE_CACHE_TTL_SECS,
    DEFAULT_FORCE_REFRESH_COOLDOWN_SECS, DEFAULT_PLC_DIRECTORY_URL, SpaceAuthorityEndpoints,
    SpaceDidDocument, SpaceDidResolver, SpaceDidService, SpaceHostResolver,
    SpaceVerificationMethod, StaticDidResolver, did_document_url, extract_authority_endpoints,
    extract_kem_key, extract_service_endpoint, extract_signing_key,
};
pub use set_hash::{
    LTHASH_BYTES, LtHash, SpaceSetHash, compute_dagcbor_cid, compute_inventory_element_hash,
    compute_record_element_hash, compute_set_hash,
};
pub use signature_replay::{
    DEFAULT_REPLAY_CLOCK_SKEW_SECS, InMemorySignatureReplayCache, SignatureReplayStore,
    check_presentation_replay, check_presentation_replay_for_signer, replay_key,
    replay_key_for_signer, replay_window_end,
};
pub use star::{
    DEFAULT_MAX_ARCHIVE_BYTES, SAFE_INT_MAX, SAFE_INT_MIN, STAR_MAGIC, STAR_VERSION,
    StarRecordEntry, StarRepo, StarRepoMetadata, read_star_metadata, read_star_repo,
    read_star_repo_authenticated, verify_json_value_for_dag_cbor, verify_record_cid,
    write_star_repo,
};
pub use sync_engine::{
    ActiveWriterSet, SpaceSyncEngine, SyncedWriterOps, VerifiedLatestCommit, VerifiedSpaceRecord,
};
pub use tokens::{
    CLIENT_ATTESTATION_JWT_TYP, CLOCK_SKEW_SECS, CREDENTIAL_JWT_TYP, CnfClaim, CredentialClaims,
    DELEGATION_JWT_TYP, DelegationClaims, JwtAlgorithm, JwtHeader,
    MAX_CLIENT_ATTESTATION_LIFETIME_SECS, MAX_CREDENTIAL_LIFETIME_SECS,
    MAX_DELEGATION_LIFETIME_SECS, SigningKeyPair, SigningKeyResolver, generate_jti,
    inspect_credential_token_unverified, inspect_delegation_token_unverified,
    mint_client_attestation_token, mint_credential_token, mint_delegation_token,
    mint_delegation_token_with_cnf, verify_client_attestation_token, verify_credential_token,
    verify_delegation_token,
};

pub use petrel_core::{AtUri, Cid, Did, Nsid, RecordKey, SpaceRef, Tid, Value};
pub use petrel_crypto::rt::{BoxFuture, MaybeSend, MaybeSync};
