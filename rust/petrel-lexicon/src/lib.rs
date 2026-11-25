//! Runtime AT Protocol Lexicon support for Petrel:
//!
//! - [`LexValue`] & [`LexBlobRef`] — strict JSON and canonical DAG-CBOR ATProto Data Model codecs
//! - [`LexStringFormat`] — all Lexicon v1 string format validators (+ PR #90 `at:space/` & `space-ref`)
//! - [`LexiconDoc`] & [`LexiconDefinition`] — Lexicon schema AST, JSON coding, and static schema validation
//! - [`LexiconCatalog`] & [`LexiconCatalog::bundled()`] — in-memory schema registry and runtime data validator
//! - [`DefaultLexiconResolver`] & [`LexiconRepoProofVerifier`] — remote `_lexicon` NSID resolution

pub mod bundled;
pub mod catalog;
pub mod doc;
pub mod format;
#[rustfmt::skip]
mod generated;
pub mod identity;
pub mod proof;
pub mod resolver;
pub mod schema;
pub mod validation;
pub mod value;

pub use catalog::{LexiconCatalog, LexiconCatalogError};
pub use doc::{
    LexArray, LexBlob, LexBoolean, LexBytes, LexCidLink, LexInteger, LexNull, LexObject,
    LexPermission, LexPermissionSet, LexRecord, LexRecordKeyType, LexRef, LexRefUnion, LexSpace,
    LexString, LexToken, LexUnknown, LexXrpcBody, LexXrpcError, LexXrpcParameters,
    LexXrpcProcedure, LexXrpcQuery, LexXrpcSubscription, LexXrpcSubscriptionMessage,
    LexiconCodingError, LexiconDefinition, LexiconDoc,
};
pub use format::LexStringFormat;
pub use identity::{
    IdentityLexiconDidResolver, IdentityLexiconDnsResolver, LexiconIdentityResolution,
};
pub use proof::DefaultLexiconRepoProofVerifier;
pub use resolver::{
    DefaultLexiconResolver, LEXICON_SCHEMA_COLLECTION, LexiconAuthority, LexiconDidResolver,
    LexiconDnsResolver, LexiconHttpRecordFetcher, LexiconRecordFetcher, LexiconRepoProofVerifier,
    LexiconResolutionCache, LexiconResolutionError, LexiconResolver, ResolvedLexiconIdentity,
    VerifiedLexiconRecord, lexicon_doc_from_record_value,
};
pub use schema::{LexiconReference, LexiconSchemaError, LexiconSchemaOptions};
pub use validation::{LexiconDataValidator, LexiconValidationError, LexiconValidationOptions};
pub use value::{LexBlobRef, LexValue, LexValueError, ParseOptions};
