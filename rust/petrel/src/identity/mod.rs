//! Resolve DIDs and verify bidirectional handle claims without account credentials.
//!
//! Native DNS uses the operating system's resolver configuration. The browser
//! can use DNS-over-HTTPS, whose operator sees the handle being queried.

mod cache;
mod dns;
mod document;
mod resolver;
mod web;

pub use cache::{CacheEntry, CachePolicy, IdentityCache, InMemoryIdentityCache};
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub use dns::HickoryResolver;
pub use dns::{DnsError, DnsResolver, DohResolver};
pub use document::{
    DidDocument, Service, ServiceKind, SigningCurve, SigningKey, VerificationMethod,
};
pub use resolver::{
    HandleConflictPolicy, HandleLookup, HandleStrategy, HandleVerification, IdentityError,
    IdentityOptions, IdentityResolver, ResolvedIdentity,
};
pub use web::{DidWebError, DidWebIdentifier};

#[cfg(all(test, not(target_arch = "wasm32"), feature = "native"))]
mod tests;
