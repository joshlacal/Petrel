#![forbid(unsafe_code)]

//! AT Protocol OAuth scope tokens.
//!
//! Scope grammar is ported from Petrel's Swift `Sources/PetrelOAuthScopes`
//! at commit `28b2624ee`. This crate is independent of the Petrel runtime.

mod admission;
mod families;
mod grants;
mod identifiers;
mod include;
mod syntax;

pub use admission::{
    OAuthScopeAdmissionError, OAuthScopeAdmissionPolicy, OAuthScopeBudget, OAuthScopeTokenizer,
    OAuthUnknownScopePolicy,
};
pub use families::{
    AccountPermission, AtProtoScope, BlobPermission, IdentityPermission, IncludeScope,
    RepoPermission, RpcPermission, ScopeParameterValues, is_accept, is_mime,
};
pub use grants::ScopeDenied;
pub use identifiers::{
    is_atproto_did, is_atproto_did_ref_absolute, is_did, is_did_ref_absolute, is_nsid,
    is_record_key,
};
pub use include::{
    ExpansionRejection, ExpansionRejectionReason, IncludedPermission, LexiconPermission,
    LexiconPermissionSet, ScopeExpansion, is_parent_authority_of,
};
pub use syntax::{
    ScopeParameterBag, ScopeParseError, ScopeStringSyntax, SingleLookup, encode_form_component,
    encode_uri_component,
};

use std::{
    collections::{BTreeMap, BTreeSet},
    fmt,
    str::FromStr,
};

/// A token contained bytes outside the RFC 6749 scope-token alphabet.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ScopeTokenError;

impl fmt::Display for ScopeTokenError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("scope value contains an invalid RFC 6749 scope token")
    }
}

impl std::error::Error for ScopeTokenError {}

/// An OAuth scope set that retains each wire token verbatim.
#[derive(Clone, Debug, Default)]
pub struct ScopeSet {
    raw: BTreeSet<String>,
    grants: Vec<AtProtoScope>,
    rejected: BTreeMap<String, ScopeParseError>,
}

impl ScopeSet {
    /// Parse a scope value using ASCII SPACE as the only separator.
    ///
    /// Consecutive spaces are ignored and exact duplicate tokens collapse.
    /// Unknown scope families are accepted. Empty input yields an empty set.
    pub fn parse(value: &str) -> Result<Self, ScopeTokenError> {
        let tokens = split_scopes(value);
        let mut raw = BTreeSet::new();
        for token in tokens {
            if !is_scope_token(token) {
                return Err(ScopeTokenError);
            }
            raw.insert(token.to_owned());
        }
        Ok(Self::from_raw_scopes(raw))
    }

    /// Whether the set contains the exact base AT Protocol scope.
    pub fn includes_atproto(&self) -> bool {
        self.raw.contains("atproto")
    }

    /// The original tokens, ordered by their bytes.
    pub fn raw_scopes(&self) -> &BTreeSet<String> {
        &self.raw
    }

    /// Join the original tokens with ASCII SPACE in byte order.
    pub fn scope_string(&self) -> String {
        self.raw
            .iter()
            .map(String::as_str)
            .collect::<Vec<_>>()
            .join(" ")
    }
}

impl FromStr for ScopeSet {
    type Err = ScopeTokenError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        Self::parse(value)
    }
}

fn split_scopes(value: &str) -> impl Iterator<Item = &str> {
    value.split(' ').filter(|token| !token.is_empty())
}

fn is_scope_token(value: &str) -> bool {
    !value.is_empty()
        && value
            .bytes()
            .all(|byte| matches!(byte, 0x21 | 0x23..=0x5b | 0x5d..=0x7e))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg_attr(not(target_arch = "wasm32"), test)]
    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    fn space_is_the_only_separator() {
        assert_eq!(
            ScopeSet::parse("  atproto   future:ABC  ")
                .unwrap()
                .scope_string(),
            "atproto future:ABC"
        );
        for invalid in [
            "atproto\tfuture:ABC",
            "atproto\nfuture:ABC",
            "atproto \u{0301}",
            "atproto future:\"quoted",
            "atproto future:\\escaped",
            "atproto future:\u{212A}",
        ] {
            assert_eq!(ScopeSet::parse(invalid), Err(ScopeTokenError));
        }
    }

    #[cfg_attr(not(target_arch = "wasm32"), test)]
    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    fn detects_only_the_exact_base_scope() {
        for value in ["", "  ", "ATProto", "future:atproto", "atproto:extra"] {
            assert!(!ScopeSet::parse(value).unwrap().includes_atproto());
        }
        assert!(
            ScopeSet::parse("atproto atproto")
                .unwrap()
                .includes_atproto()
        );
    }

    #[cfg_attr(not(target_arch = "wasm32"), test)]
    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    fn keeps_catmos_tokens_and_unknown_scope_bytes() {
        let tokens = [
            "atproto",
            "blob:*/*",
            "blob:application/octet-stream",
            "repo:app.bsky.graph.block?action=create",
            "repo:blue.catbird.chat.declaration?action=create&action=update",
            "repo:blue.catbird.chat.device?action=create",
            "repo:blue.catbird.chat.deviceRevocation?action=create",
            "repo:blue.catbird.labyrinth.mailboxKeys",
            "rpc:*?aud=did:web:chat.catbird.blue%23atproto_mls",
            "space:blue.catbird.labyrinth.conversation?action=create&action=delete&action=read&action=update&authority=*&collection=blue.catbird.labyrinth.attachmentManifest&collection=blue.catbird.labyrinth.authorRedaction&collection=blue.catbird.labyrinth.batch&collection=blue.catbird.labyrinth.mek",
            "space:blue.catbird.labyrinth.mailbox?action=create&action=delete&action=read&action=update&collection=blue.catbird.labyrinth.attachmentManifest&collection=blue.catbird.labyrinth.circleOwnerState&collection=blue.catbird.labyrinth.device&collection=blue.catbird.labyrinth.epoch&collection=blue.catbird.labyrinth.epochMember&collection=blue.catbird.labyrinth.otcSession&collection=blue.catbird.labyrinth.ownerBatch&collection=blue.catbird.labyrinth.readState&collection=blue.catbird.labyrinth.virtualDevice&manage=create&manage=delete",
            "unrecognized:Example?foo=%3a+%FF",
        ];
        let wire = tokens.join(" ");
        let scopes: ScopeSet = wire.parse().unwrap();
        assert_eq!(scopes.scope_string(), wire);
        assert_eq!(scopes.raw_scopes().len(), tokens.len());
    }
}
