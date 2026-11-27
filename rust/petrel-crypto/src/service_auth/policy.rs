//! Service authentication audience, method, and claim policies.

use std::collections::BTreeSet;
use std::ops::{BitOr, BitOrAssign};

use petrel_core::ServiceRef;
use web_time::SystemTime;

use crate::keys::PublicKey;
use crate::service_auth::error::ServiceAuthError;
use crate::service_jwt::ServiceJWTClaims;

/// Which `aud` claims a receiving service accepts.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ServiceAuthAudience {
    accepted_values: Option<BTreeSet<String>>,
}

impl ServiceAuthAudience {
    /// Accepts exactly one `aud` string.
    pub fn exactly(value: impl Into<String>) -> Self {
        let mut set = BTreeSet::new();
        set.insert(value.into());
        Self {
            accepted_values: Some(set),
        }
    }

    /// Accepts any of the given `aud` strings.
    pub fn any_of(values: impl IntoIterator<Item = String>) -> Self {
        Self {
            accepted_values: Some(values.into_iter().collect()),
        }
    }

    /// Accepts this service's DID with its `#id` service fragment, and optionally the bare DID.
    pub fn service(did: &str, id: &str, accept_bare_did: bool) -> Self {
        let fragment = id.strip_prefix('#').unwrap_or(id);
        let mut values = BTreeSet::new();
        values.insert(format!("{did}#{fragment}"));
        if accept_bare_did {
            values.insert(did.to_owned());
        }
        Self {
            accepted_values: Some(values),
        }
    }

    /// Accepts tokens addressed to `service`, and optionally to its bare DID.
    pub fn from_service_ref(service: &ServiceRef, accept_bare_did: bool) -> Self {
        match service.service_id() {
            Some(id) => Self::service(service.did().as_str(), id, accept_bare_did),
            None => Self::exactly(service.did().as_str()),
        }
    }

    /// Disables the audience check (appropriate only for inspection tools, never services).
    pub const fn unchecked() -> Self {
        Self {
            accepted_values: None,
        }
    }

    /// The exact accepted `aud` values, or `None` when [`Self::unchecked`].
    pub const fn accepted_values(&self) -> Option<&BTreeSet<String>> {
        self.accepted_values.as_ref()
    }

    /// Returns `true` iff `audience` passes this policy.
    pub fn accepts(&self, audience: &str) -> bool {
        match &self.accepted_values {
            None => true,
            Some(values) => values.contains(audience),
        }
    }
}

/// How a receiving service checks the `lxm` ("lexicon method") claim.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum ServiceAuthMethodPolicy {
    /// `lxm` must be present and equal to this NSID.
    Exactly(String),
    /// `lxm` must equal this NSID when present; a token without `lxm` is accepted.
    ExactlyIfPresent(String),
    /// `lxm` must be present; the caller compares it itself.
    ///
    /// Not bound to any route. Prefer [`Self::MatchRoute`] for XRPC servers.
    Required,
    /// `lxm` is not checked.
    Optional,
    /// `lxm` must be present and equal to the NSID of the XRPC route being served.
    ///
    /// A server adapter (for example `petrel-server`'s Axum integration) resolves this to
    /// [`Self::Exactly`] from the request's `/xrpc/{nsid}` path. Evaluated directly with
    /// [`Self::check`], where no route is known, it always fails closed.
    MatchRoute,
}

impl ServiceAuthMethodPolicy {
    /// Evaluates the policy against a token's `lxm` claim.
    pub fn check(&self, lexicon_method: Option<&str>) -> Result<(), ServiceAuthError> {
        match self {
            Self::Exactly(expected) => {
                if lexicon_method == Some(expected.as_str()) {
                    Ok(())
                } else {
                    Err(ServiceAuthError::LexiconMethodMismatch {
                        expected: Some(expected.clone()),
                        actual: lexicon_method.map(str::to_owned),
                    })
                }
            }
            Self::ExactlyIfPresent(expected) => match lexicon_method {
                None => Ok(()),
                Some(actual) if actual == expected => Ok(()),
                Some(actual) => Err(ServiceAuthError::LexiconMethodMismatch {
                    expected: Some(expected.clone()),
                    actual: Some(actual.to_owned()),
                }),
            },
            Self::Required => {
                if lexicon_method.is_some() {
                    Ok(())
                } else {
                    Err(ServiceAuthError::LexiconMethodMismatch {
                        expected: None,
                        actual: None,
                    })
                }
            }
            Self::Optional => Ok(()),
            Self::MatchRoute => Err(ServiceAuthError::LexiconMethodMismatch {
                expected: None,
                actual: lexicon_method.map(str::to_owned),
            }),
        }
    }
}

/// Claims and header fields the specification marks required that the reference
/// verifier does not insist on by default.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub struct ServiceAuthRequiredClaims(u8);

impl ServiceAuthRequiredClaims {
    /// Only what the reference verifier requires: `iss`, `aud`, `exp`.
    pub const REFERENCE: Self = Self(0);
    /// The `typ` header must be present.
    pub const TYPE: Self = Self(1 << 0);
    /// The `iat` claim must be present.
    pub const ISSUED_AT: Self = Self(1 << 1);
    /// The `jti` claim must be present (implied when a replay store is configured).
    pub const NONCE: Self = Self(1 << 2);
    /// Everything the specification marks required: `typ`, `iat`, `jti`.
    pub const SPECIFICATION: Self = Self(Self::TYPE.0 | Self::ISSUED_AT.0 | Self::NONCE.0);

    /// Creates a policy from raw option bits.
    pub const fn from_bits(bits: u8) -> Self {
        Self(bits)
    }

    /// Returns the raw option bits.
    pub const fn bits(self) -> u8 {
        self.0
    }

    /// Returns `true` if all bits in `other` are set in `self`.
    pub const fn contains(self, other: Self) -> bool {
        (self.0 & other.0) == other.0
    }

    /// Returns the union of `self` and `other`.
    #[must_use]
    pub const fn union(self, other: Self) -> Self {
        Self(self.0 | other.0)
    }
}

impl BitOr for ServiceAuthRequiredClaims {
    type Output = Self;

    fn bitor(self, rhs: Self) -> Self::Output {
        self.union(rhs)
    }
}

impl BitOrAssign for ServiceAuthRequiredClaims {
    fn bitor_assign(&mut self, rhs: Self) {
        self.0 |= rhs.0;
    }
}

/// Namespace grouping service-auth policy types.
#[derive(Debug, Clone, Copy)]
pub struct ServiceAuthPolicy;

/// Outcome of a successful service-auth verification: who is calling and what
/// the token was bound to.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedServiceAuth {
    /// The issuer's DID, without any fragment.
    pub issuer: String,
    /// Legacy `#fragment` carried on `iss`, without `#`, if present.
    pub issuer_fragment: Option<String>,
    /// Verification method fragment (with `#`) whose key verified the signature.
    pub key_id: String,
    /// The `aud` claim, verbatim.
    pub audience: String,
    /// The `lxm` claim, if bound.
    pub lexicon_method: Option<String>,
    /// The `jti` claim, if present and non-empty.
    pub nonce: Option<String>,
    /// The `exp` claim.
    pub expires_at: SystemTime,
    /// The `iat` claim, if present.
    pub issued_at: Option<SystemTime>,
    /// The header `alg`: `"ES256"` or `"ES256K"`.
    pub algorithm: String,
    /// The public key that verified the signature.
    pub signing_key: PublicKey,
    /// All decoded claims.
    pub claims: ServiceJWTClaims,
}
