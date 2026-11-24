use std::{collections::BTreeSet, fmt};

use crate::{AtProtoScope, ScopeParseError, ScopeSet, is_scope_token, split_scopes};

/// Bounds for an incoming scope request or a grant after expansion.
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct OAuthScopeBudget {
    pub bytes_per_scope: usize,
    pub scope_count: usize,
    pub bytes_per_set: usize,
}

impl OAuthScopeBudget {
    pub const RAW_INPUT: Self = Self {
        bytes_per_scope: 1024,
        scope_count: 64,
        bytes_per_set: 8192,
    };

    pub const EXPANDED_GRANT: Self = Self {
        bytes_per_scope: 1024,
        scope_count: 256,
        bytes_per_set: 32768,
    };
}

/// A request or grant failed scope admission.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum OAuthScopeAdmissionError {
    EmptyScopeRequest,
    DuplicateScope,
    NotAScopeToken,
    TooManyScopes { count: usize, limit: usize },
    RawScopeTooLong { bytes: usize, limit: usize },
    RawRequestTooLong { bytes: usize, limit: usize },
    ForbiddenScope,
    UnparseableScope(ScopeParseError),
    NotRegistered,
    MissingBaseScope,
    ExpandedScopeTooLong { bytes: usize, limit: usize },
    ExpandedGrantTooManyScopes { count: usize, limit: usize },
    ExpandedGrantTooLong { bytes: usize, limit: usize },
}

impl OAuthScopeAdmissionError {
    /// The OAuth error identifier corresponding to this failure.
    pub fn oauth_error_code(&self) -> &'static str {
        match self {
            Self::ForbiddenScope
            | Self::UnparseableScope(_)
            | Self::NotRegistered
            | Self::MissingBaseScope => "invalid_scope",
            _ => "invalid_request",
        }
    }
}

impl fmt::Display for OAuthScopeAdmissionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyScopeRequest => f.write_str("scope request is empty"),
            Self::DuplicateScope => f.write_str("scope request contains a duplicate"),
            Self::NotAScopeToken => f.write_str("scope request has a non-RFC 6749 token"),
            Self::TooManyScopes { count, limit } => {
                write!(f, "scope request has {count} tokens, limit {limit}")
            }
            Self::RawScopeTooLong { bytes, limit } => {
                write!(f, "raw scope has {bytes} bytes, limit {limit}")
            }
            Self::RawRequestTooLong { bytes, limit } => {
                write!(f, "scope request has {bytes} bytes, limit {limit}")
            }
            Self::ForbiddenScope => {
                f.write_str("OpenID Connect scopes are incompatible with AT Protocol")
            }
            Self::UnparseableScope(error) => write!(f, "scope did not parse: {error}"),
            Self::NotRegistered => f.write_str("requested scope is not declared"),
            Self::MissingBaseScope => f.write_str("missing atproto scope"),
            Self::ExpandedScopeTooLong { bytes, limit } => {
                write!(f, "expanded scope has {bytes} bytes, limit {limit}")
            }
            Self::ExpandedGrantTooManyScopes { count, limit } => {
                write!(f, "expanded grant has {count} tokens, limit {limit}")
            }
            Self::ExpandedGrantTooLong { bytes, limit } => {
                write!(f, "expanded grant has {bytes} bytes, limit {limit}")
            }
        }
    }
}

impl std::error::Error for OAuthScopeAdmissionError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::UnparseableScope(error) => Some(error),
            _ => None,
        }
    }
}

use OAuthScopeAdmissionError as Error;

/// Admission tokenizer for authorization requests.
#[derive(Clone, Copy, Debug)]
pub struct OAuthScopeTokenizer;

impl OAuthScopeTokenizer {
    /// Split on ASCII SPACE and reject unknown wire syntax, duplicates,
    /// `openid`, and requests that exceed their raw budget.
    pub fn tokenize(raw: &str, budget: OAuthScopeBudget) -> Result<ScopeSet, Error> {
        if raw.len() > budget.bytes_per_set {
            return Err(Error::RawRequestTooLong {
                bytes: raw.len(),
                limit: budget.bytes_per_set,
            });
        }
        let tokens: Vec<_> = split_scopes(raw).collect();
        if tokens.is_empty() {
            return Err(Error::EmptyScopeRequest);
        }
        if tokens.len() > budget.scope_count {
            return Err(Error::TooManyScopes {
                count: tokens.len(),
                limit: budget.scope_count,
            });
        }
        let unique: BTreeSet<_> = tokens.iter().copied().collect();
        if unique.len() != tokens.len() {
            return Err(Error::DuplicateScope);
        }
        for token in tokens {
            if !is_scope_token(token) {
                return Err(Error::NotAScopeToken);
            }
            if token.len() > budget.bytes_per_scope {
                return Err(Error::RawScopeTooLong {
                    bytes: token.len(),
                    limit: budget.bytes_per_scope,
                });
            }
            if token == "openid" {
                return Err(Error::ForbiddenScope);
            }
        }
        Ok(ScopeSet::from_raw_scopes(
            unique.into_iter().map(str::to_owned).collect(),
        ))
    }
}

/// How an authorization server handles a requested scope it cannot interpret.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum OAuthUnknownScopePolicy {
    #[default]
    Reject,
    Ignore,
}

/// The protocol checks applied after an authorization request is tokenized.
#[derive(Clone, Copy, Debug)]
pub struct OAuthScopeAdmissionPolicy;

impl OAuthScopeAdmissionPolicy {
    /// Admit recognized scopes with an equivalent declaration and require
    /// the base scope. Retain each admitted token in its original spelling.
    pub fn admit(
        requested: &ScopeSet,
        declared: &ScopeSet,
        unknown: OAuthUnknownScopePolicy,
    ) -> Result<ScopeSet, Error> {
        if unknown == OAuthUnknownScopePolicy::Reject
            && let Some(error) = requested.rejected().values().next()
        {
            return Err(Error::UnparseableScope(error.clone()));
        }
        if !Self::recognized_are_declared(requested, declared) {
            return Err(Error::NotRegistered);
        }
        if !requested.includes_atproto() {
            return Err(Error::MissingBaseScope);
        }
        let raw = requested
            .raw_scopes()
            .iter()
            .filter(|scope| !requested.rejected().contains_key(*scope))
            .cloned()
            .collect();
        Ok(ScopeSet::from_raw_scopes(raw))
    }

    /// Compare the meanings of the typed grants. Opaque tokens are declared
    /// only by an exact token match.
    pub fn is_declared(requested: &ScopeSet, declared: &ScopeSet) -> bool {
        Self::recognized_are_declared(requested, declared)
            && requested
                .rejected()
                .keys()
                .all(|scope| declared.raw_scopes().contains(scope))
    }

    fn recognized_are_declared(requested: &ScopeSet, declared: &ScopeSet) -> bool {
        requested.scopes().iter().all(|scope: &AtProtoScope| {
            declared
                .scopes()
                .iter()
                .any(|declaration| declaration.same_grant(scope))
        })
    }

    /// Check the grant's token count, per-token length and total joined bytes.
    pub fn enforce_expanded_grant_budget(
        scopes: &ScopeSet,
        budget: OAuthScopeBudget,
    ) -> Result<(), Error> {
        let count = scopes.raw_scopes().len();
        if count > budget.scope_count {
            return Err(Error::ExpandedGrantTooManyScopes {
                count,
                limit: budget.scope_count,
            });
        }
        let mut total = count.saturating_sub(1);
        for scope in scopes.raw_scopes() {
            if scope.len() > budget.bytes_per_scope {
                return Err(Error::ExpandedScopeTooLong {
                    bytes: scope.len(),
                    limit: budget.bytes_per_scope,
                });
            }
            total = total.saturating_add(scope.len());
        }
        if total > budget.bytes_per_set {
            return Err(Error::ExpandedGrantTooLong {
                bytes: total,
                limit: budget.bytes_per_set,
            });
        }
        Ok(())
    }
}
