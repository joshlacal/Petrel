use std::{
    collections::{BTreeMap, BTreeSet},
    fmt,
    hash::{Hash, Hasher},
};

use crate::{
    AccountPermission, AtProtoScope, BlobPermission, IdentityPermission, RepoPermission,
    RpcPermission, ScopeParseError, ScopeSet,
    families::{accept_covers, is_repo_action},
    split_scopes,
};

/// The permission that would satisfy a denied scope check.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ScopeDenied {
    pub needed: String,
}

impl fmt::Display for ScopeDenied {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("the grant does not allow the request")
    }
}

impl std::error::Error for ScopeDenied {}

impl PartialEq for ScopeSet {
    fn eq(&self, other: &Self) -> bool {
        self.raw == other.raw
    }
}

impl Eq for ScopeSet {}

impl Hash for ScopeSet {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.raw.hash(state);
    }
}

impl ScopeSet {
    /// Split and retain the tokens of a received grant, including malformed
    /// or unrecognized tokens. Only successfully parsed permissions grant
    /// access. Use [`Self::parse`] to reject invalid wire tokens.
    pub fn from_scope_string(wire: &str) -> Self {
        Self::from_raw_scopes(split_scopes(wire).map(str::to_owned).collect())
    }

    /// Construct a grant from a set of scope strings, unchanged.
    pub fn from_raw_scopes(raw: BTreeSet<String>) -> Self {
        let mut grants = Vec::new();
        let mut rejected = BTreeMap::new();
        for token in &raw {
            match AtProtoScope::parse(token) {
                Ok(scope) => grants.push(scope),
                Err(error) => {
                    rejected.insert(token.clone(), error);
                }
            }
        }
        Self {
            raw,
            grants,
            rejected,
        }
    }

    /// Build a grant from validated scopes, retaining their parsed parameters.
    pub fn from_scopes(
        scopes: impl IntoIterator<Item = AtProtoScope>,
    ) -> Result<Self, ScopeParseError> {
        let mut typed = BTreeMap::new();
        let mut rejected = BTreeMap::new();
        for scope in scopes {
            let wire = scope.wire_scope_string()?;
            if matches!(scope, AtProtoScope::Unrecognized(_)) {
                rejected.insert(wire, ScopeParseError::UnknownPrefix);
            } else {
                typed.entry(wire).or_insert(scope);
            }
        }
        Ok(Self {
            raw: typed.keys().chain(rejected.keys()).cloned().collect(),
            grants: typed.into_values().collect(),
            rejected,
        })
    }

    /// Parse a scope value containing only recognized, valid scopes.
    pub fn parse_strict(wire: &str) -> Result<Self, ScopeParseError> {
        let scopes = Self::from_scope_string(wire);
        if let Some(error) = split_scopes(wire).find_map(|token| scopes.rejected.get(token)) {
            return Err(error.clone());
        }
        Ok(scopes)
    }

    /// Successfully parsed permissions in raw token order.
    pub fn scopes(&self) -> &[AtProtoScope] {
        &self.grants
    }

    /// Rejected tokens, including unfamiliar families, and why they were rejected.
    pub fn rejected(&self) -> &BTreeMap<String, ScopeParseError> {
        &self.rejected
    }

    /// A sorted, deduplicated representation preserving parsed grant meaning.
    /// Unrecognized and malformed tokens are carried byte for byte.
    pub fn normalized_scope_string(&self) -> String {
        self.grants
            .iter()
            .filter_map(|scope| scope.wire_scope_string().ok())
            .chain(self.rejected.keys().cloned())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>()
            .join(" ")
    }

    pub fn allows_repo(&self, collection: &str, action: &str) -> bool {
        if !is_repo_action(action) {
            return false;
        }
        self.raw.contains("transition:generic") || self.scopes().iter().any(|scope| {
            matches!(scope, AtProtoScope::Repo(permission) if permission.matches(collection, action))
        })
    }

    pub fn allows_rpc(&self, lxm: &str, aud: &str) -> bool {
        self.transition_allows_rpc(lxm) || self.scopes().iter().any(|scope| {
            matches!(scope, AtProtoScope::Rpc(permission) if permission.matches(lxm, aud))
        })
    }

    fn transition_allows_rpc(&self, lxm: &str) -> bool {
        if lxm.starts_with("chat.bsky.") {
            self.raw.contains("transition:chat.bsky")
        } else {
            self.raw.contains("transition:generic")
        }
    }

    pub fn allows_blob(&self, mime: &str) -> bool {
        self.raw.contains("transition:generic")
            || self.scopes().iter().any(
                |scope| matches!(scope, AtProtoScope::Blob(permission) if permission.matches(mime)),
            )
    }

    pub fn allows_account(&self, attr: &str, action: &str) -> bool {
        (attr == "email" && action == "read" && self.raw.contains("transition:email"))
            || self.scopes().iter().any(|scope| {
                matches!(scope, AtProtoScope::Account(permission) if permission.matches(attr, action))
            })
    }

    pub fn allows_identity(&self, attr: &str) -> bool {
        self.scopes().iter().any(
            |scope| matches!(scope, AtProtoScope::Identity(permission) if permission.matches(attr)),
        )
    }

    pub fn require_repo(&self, collection: &str, action: &str) -> Result<(), ScopeDenied> {
        require(self.allows_repo(collection, action), "repo", || {
            RepoPermission::scope_needed(collection, action)
        })
    }

    pub fn require_rpc(&self, lxm: &str, aud: &str) -> Result<(), ScopeDenied> {
        require(self.allows_rpc(lxm, aud), "rpc", || {
            RpcPermission::scope_needed(lxm, aud)
        })
    }

    pub fn require_blob(&self, mime: &str) -> Result<(), ScopeDenied> {
        require(self.allows_blob(mime), "blob", || {
            BlobPermission::scope_needed(mime)
        })
    }

    pub fn require_account(&self, attr: &str, action: &str) -> Result<(), ScopeDenied> {
        require(self.allows_account(attr, action), "account", || {
            AccountPermission::scope_needed(attr, action)
        })
    }

    pub fn require_identity(&self, attr: &str) -> Result<(), ScopeDenied> {
        require(self.allows_identity(attr), "identity", || {
            IdentityPermission::scope_needed(attr)
        })
    }

    /// Whether the grant allows every operation described by a needed scope.
    /// An opaque scope is covered only by an identical token.
    pub fn covers_scope(&self, scope: &AtProtoScope) -> bool {
        match scope {
            AtProtoScope::Atproto => self.includes_atproto(),
            AtProtoScope::TransitionGeneric => self.raw.contains("transition:generic"),
            AtProtoScope::TransitionEmail => self.raw.contains("transition:email"),
            AtProtoScope::TransitionChatBsky => self.raw.contains("transition:chat.bsky"),
            AtProtoScope::Unrecognized(token) => self.raw.contains(token),
            AtProtoScope::Include(_) => self.scopes().iter().any(|grant| grant.same_grant(scope)),
            AtProtoScope::Repo(permission) => {
                let parameters = permission.parameters();
                parameters.multiple("action").iter().all(|action| {
                    parameters
                        .multiple("collection")
                        .iter()
                        .all(|collection| self.allows_repo(collection, action))
                })
            }
            AtProtoScope::Rpc(permission) => {
                let parameters = permission.parameters();
                let aud = parameters.single("aud").unwrap_or("");
                parameters
                    .multiple("lxm")
                    .iter()
                    .all(|lxm| self.covers_rpc(lxm, aud))
            }
            AtProtoScope::Blob(permission) => permission
                .parameters()
                .multiple("accept")
                .iter()
                .all(|need| {
                    self.raw.contains("transition:generic")
                        || self.scopes().iter().any(|scope| match scope {
                            AtProtoScope::Blob(grant) => grant
                                .parameters()
                                .multiple("accept")
                                .iter()
                                .any(|value| accept_covers(value, need)),
                            _ => false,
                        })
                }),
            AtProtoScope::Account(permission) => {
                let parameters = permission.parameters();
                let attr = parameters.single("attr").unwrap_or("");
                parameters
                    .multiple("action")
                    .iter()
                    .all(|action| self.allows_account(attr, action))
            }
            AtProtoScope::Identity(permission) => {
                self.allows_identity(permission.parameters().single("attr").unwrap_or(""))
            }
        }
    }

    fn covers_rpc(&self, lxm: &str, aud: &str) -> bool {
        // A single transition can cover a concrete method on every service,
        // but the method wildcard spans chat and non-chat methods.
        let transition = if lxm == "*" {
            self.raw.contains("transition:generic") && self.raw.contains("transition:chat.bsky")
        } else {
            self.transition_allows_rpc(lxm)
        };
        transition || self.scopes().iter().any(|scope| {
            matches!(scope, AtProtoScope::Rpc(permission) if permission.matches(lxm, aud))
        })
    }

    /// Whether every required permission and opaque scope token is covered.
    pub fn covers(&self, needed: &Self) -> bool {
        needed.scopes().iter().all(|scope| self.covers_scope(scope))
            && needed
                .rejected()
                .keys()
                .all(|token| self.raw.contains(token))
    }
}

fn require(
    allowed: bool,
    prefix: &str,
    needed: impl FnOnce() -> Result<String, ScopeParseError>,
) -> Result<(), ScopeDenied> {
    if allowed {
        return Ok(());
    }
    Err(ScopeDenied {
        needed: needed().unwrap_or_else(|_| format!("{prefix}:<unrenderable target>")),
    })
}
