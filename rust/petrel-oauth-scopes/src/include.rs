use std::collections::BTreeMap;

use serde::{Deserialize, Deserializer, Serialize};
use serde_json::Value;

use crate::{IncludeScope, RepoPermission, RpcPermission, ScopeParseError};

/// A decoded Lexicon permission entry. Arbitrary fields are kept for
/// validation when a verified permission set is expanded.
#[derive(Clone, Debug, PartialEq, Deserialize, Serialize)]
pub struct LexiconPermission {
    #[serde(rename = "type")]
    pub kind: String,
    pub resource: String,
    #[serde(flatten)]
    pub fields: BTreeMap<String, Value>,
}

/// The `main` definition of a Lexicon permission set.
#[derive(Clone, Debug, PartialEq, Deserialize, Serialize)]
pub struct LexiconPermissionSet {
    #[serde(rename = "type")]
    pub kind: String,
    pub permissions: Vec<LexiconPermission>,
    pub title: Option<String>,
    pub detail: Option<String>,
    #[serde(rename = "title:lang", default, deserialize_with = "display_map")]
    pub title_lang: BTreeMap<String, String>,
    #[serde(rename = "detail:lang", default, deserialize_with = "display_map")]
    pub detail_lang: BTreeMap<String, String>,
}

fn display_map<'de, D: Deserializer<'de>>(
    deserializer: D,
) -> Result<BTreeMap<String, String>, D::Error> {
    let value = Value::deserialize(deserializer)?;
    // Display metadata is optional and does not affect the grant.
    Ok(serde_json::from_value(value).unwrap_or_default())
}

impl LexiconPermissionSet {
    pub fn localized_title(&self, languages: &[&str]) -> Option<&str> {
        localized(&self.title_lang, languages).or(self.title.as_deref())
    }

    pub fn localized_detail(&self, languages: &[&str]) -> Option<&str> {
        localized(&self.detail_lang, languages).or(self.detail.as_deref())
    }
}

fn localized<'a>(values: &'a BTreeMap<String, String>, languages: &[&str]) -> Option<&'a str> {
    let find = |tag| {
        values
            .iter()
            .find(|(key, _)| key.eq_ignore_ascii_case(tag))
            .map(|(_, value)| value.as_str())
    };
    languages.iter().find_map(|tag| {
        find(tag).or_else(|| tag.split_once('-').and_then(|(primary, _)| find(primary)))
    })
}

/// The only permissions a Lexicon permission set can contribute.
#[derive(Clone, Debug, Eq, Hash, PartialEq)]
pub enum IncludedPermission {
    Repo(RepoPermission),
    Rpc(RpcPermission),
}

impl IncludedPermission {
    pub fn canonical_scope_string(&self) -> Result<String, ScopeParseError> {
        match self {
            Self::Repo(permission) => permission.canonical_scope_string(),
            Self::Rpc(permission) => permission.canonical_scope_string(),
        }
    }

    pub fn scope_string(&self) -> Result<String, ScopeParseError> {
        match self {
            Self::Repo(permission) => permission.wire_scope_string(),
            Self::Rpc(permission) => permission.wire_scope_string(),
        }
    }

    fn targets(&self) -> &[String] {
        match self {
            Self::Repo(permission) => permission.parameters().multiple("collection"),
            Self::Rpc(permission) => permission.parameters().multiple("lxm"),
        }
    }
}

/// Whether `child` is in the namespace authority of a permission set.
pub fn is_parent_authority_of(nsid: &str, child: &str) -> bool {
    child != "*"
        && nsid.rsplit_once('.').is_some_and(|(parent, _)| {
            child
                .strip_prefix(parent)
                .and_then(|rest| rest.strip_prefix('.'))
                .is_some_and(|suffix| !suffix.is_empty())
        })
}

impl IncludeScope {
    pub fn is_parent_authority_of(&self, child: &str) -> bool {
        self.parameters()
            .single("nsid")
            .is_some_and(|nsid| is_parent_authority_of(nsid, child))
    }

    /// Expand an authenticated Lexicon permission set in document order.
    /// The caller must verify the set's provenance before expansion.
    pub fn expand(&self, set: &LexiconPermissionSet) -> Vec<IncludedPermission> {
        set.permissions
            .iter()
            .filter_map(|entry| self.expand_entry(entry))
            .filter(|permission| {
                permission
                    .targets()
                    .iter()
                    .all(|name| self.is_parent_authority_of(name))
            })
            .collect()
    }

    pub fn expand_to_scope_strings(
        &self,
        set: &LexiconPermissionSet,
    ) -> Result<Vec<String>, ScopeParseError> {
        self.expand(set)
            .iter()
            .map(IncludedPermission::scope_string)
            .collect()
    }

    fn expand_entry(&self, entry: &LexiconPermission) -> Option<IncludedPermission> {
        match entry.resource.as_str() {
            "repo" => {
                let parameters = entry
                    .fields
                    .iter()
                    .map(|(key, value)| Some((key.as_str(), strings(value)?)))
                    .collect::<Option<BTreeMap<_, _>>>()?;
                RepoPermission::from_lexicon(parameters)
                    .ok()
                    .map(IncludedPermission::Repo)
            }
            "rpc" => self.expand_rpc(entry).map(IncludedPermission::Rpc),
            _ => None,
        }
    }

    fn expand_rpc(&self, entry: &LexiconPermission) -> Option<RpcPermission> {
        let mut named = BTreeMap::new();
        match (entry.fields.get("aud"), entry.fields.get("inheritAud")) {
            (Some(aud), None) if aud.as_str() == Some("*") => {
                named.insert("aud", vec!["*"]);
            }
            (None, Some(Value::Bool(true))) => {
                named.insert("aud", vec![self.parameters().single("aud")?]);
            }
            _ => return None,
        }
        for (key, value) in &entry.fields {
            if !matches!(key.as_str(), "aud" | "inheritAud") {
                named.insert(key, strings(value)?);
            }
        }
        RpcPermission::from_lexicon(named).ok()
    }
}

fn strings(value: &Value) -> Option<Vec<&str>> {
    value.as_array()?.iter().map(Value::as_str).collect()
}
