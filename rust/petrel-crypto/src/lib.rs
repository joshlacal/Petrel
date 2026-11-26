//! `petrel-crypto`: pure-Rust AT Protocol cryptography, key codecs,
//! Spaces LtHash/MAC, StrictJSON, and Service Auth JWTs.
//!
//! Works on native targets and `wasm32-unknown-unknown` (with the `wasm`
//! feature) with zero HTTP or Tokio dependencies.

pub mod base58;
pub mod codecs;
pub mod curve;
pub mod did_key;
pub mod error;
pub mod jwt_key;
pub mod keys;
pub mod rt;
mod scalar;
pub mod service_auth;
pub mod service_jwt;
pub mod signature;
pub mod space_mac;
pub mod space_set_hash;

pub use blake3;

pub use base58::Base58BTC;
pub use codecs::{Hex, JWTBase64URL, StrictJSON};
pub use curve::ATProtoKeyCurve;
pub use did_key::{LegacyVerificationKeyCurve, P256DIDKey, PLCDIDKeyCodec, PLCDIDVerificationKey};
pub use error::PetrelCryptoError;
pub use jwt_key::ATProtoJWTVerificationKey;
pub use keys::{
    ATProtoCrypto, ATProtoExportableKeypair, ATProtoExternalSigner, ATProtoKeypair,
    ATProtoPublicKey, ATProtoSigner, ATProtoVerifier, ExternalSignRequest, K256Keypair,
    P256Keypair, PrivateKey, PublicKey,
};
pub use service_auth::{
    ATProtoServiceReference, CachingServiceAuthKeyResolver, ClockFn, ClosureServiceAuthKeyResolver,
    InMemoryServiceAuthReplayStore, ReplayStoreError, ServiceAuthAudience, ServiceAuthError,
    ServiceAuthKeyResolver, ServiceAuthMethodPolicy, ServiceAuthPolicy, ServiceAuthReplayStore,
    ServiceAuthRequiredClaims, ServiceAuthVerifier, ServiceAuthVerifierConfig,
    ServiceAuthVerifierConfiguration, ServiceRef, ServiceRefError, StaticServiceAuthKeyResolver,
    VerifiedServiceAuth,
};
pub use service_jwt::{
    ProxyServiceJWT, ServiceJWT, ServiceJWTClaims, ServiceJWTInspection, ServiceJWTMintOptions,
    ServiceJWTSigningKey, ServiceJWTVerifyOptions, SpaceServiceJWT,
};
pub use signature::{ATProtoSignature, ATProtoSignatureVerificationOptions, P256WireSignature};
pub use space_mac::{SpaceMAC, SpaceMACEncapsulation, SpaceMACError};
pub use space_set_hash::SpaceSetHash;
