use std::collections::{BTreeMap, BTreeSet};

use crate::{
    ScopeParameterBag, ScopeParseError, ScopeStringSyntax, is_atproto_did_ref_absolute, is_nsid,
};

pub(crate) const REPO_ACTIONS: &[&str] = &["create", "update", "delete"];

#[derive(Clone, Copy, Debug)]
struct Parameter {
    key: &'static str,
    multiple: bool,
    required: bool,
    default: &'static [&'static str],
    validate: fn(&str) -> bool,
}

impl Parameter {
    const fn required(key: &'static str, multiple: bool, validate: fn(&str) -> bool) -> Self {
        Self {
            key,
            multiple,
            required: true,
            default: &[],
            validate,
        }
    }

    const fn optional(
        key: &'static str,
        multiple: bool,
        default: &'static [&'static str],
        validate: fn(&str) -> bool,
    ) -> Self {
        Self {
            key,
            multiple,
            required: false,
            default,
            validate,
        }
    }
}

/// Validated, ordered values in one scope, including the schema's defaults.
#[derive(Clone, Debug, Default, Eq, Hash, PartialEq)]
pub struct ScopeParameterValues {
    slots: BTreeMap<&'static str, Slot>,
}

#[derive(Clone, Debug, Eq, Hash, PartialEq)]
struct Slot {
    values: Vec<String>,
    stated: bool,
}

impl ScopeParameterValues {
    pub fn single(&self, key: &str) -> Option<&str> {
        self.multiple(key).first().map(String::as_str)
    }

    pub fn multiple(&self, key: &str) -> &[String] {
        self.slots
            .get(key)
            .map_or(&[], |slot| slot.values.as_slice())
    }

    pub fn was_stated(&self, key: &str) -> bool {
        self.slots.get(key).is_some_and(|slot| slot.stated)
    }

    fn set(&mut self, key: &'static str, values: Vec<String>, stated: bool) {
        self.slots.insert(key, Slot { values, stated });
    }

    fn contains(&self, key: &str, value: &str) -> bool {
        self.multiple(key).iter().any(|item| item == value)
    }
}

#[derive(Clone, Copy, Debug)]
struct Schema {
    prefix: &'static str,
    positional: &'static str,
    parameters: &'static [Parameter],
}

impl Schema {
    fn parse(self, input: &str) -> Result<ScopeParameterValues, ScopeParseError> {
        if !ScopeStringSyntax::is_scope_string(input, self.prefix) {
            return Err(ScopeParseError::PrefixMismatch {
                expected: self.prefix,
            });
        }
        let syntax = ScopeStringSyntax::parse(input)?;
        let named = syntax
            .parameters
            .ordered_keys()
            .into_iter()
            .map(|key| (key, syntax.parameters.values(key)));
        self.read(syntax.positional.as_deref(), named)
    }

    fn read<'a>(
        self,
        positional: Option<&str>,
        parameters: impl IntoIterator<Item = (&'a str, Vec<&'a str>)>,
    ) -> Result<ScopeParameterValues, ScopeParseError> {
        let mut named = BTreeMap::new();
        for (key, values) in parameters {
            if !self.parameters.iter().any(|parameter| parameter.key == key) {
                return Err(ScopeParseError::UnknownParameter {
                    prefix: self.prefix,
                    key: key.to_owned(),
                });
            }
            named.insert(key, values);
        }

        let mut result = ScopeParameterValues::default();
        for &parameter in self.parameters {
            let key = parameter.key;
            let positional = positional.filter(|_| key == self.positional);
            if let Some(values) = named.remove(key) {
                if !parameter.multiple && values.len() != 1 {
                    return Err(ScopeParseError::RepeatedSingleValue { key });
                }
                if positional.is_some() {
                    return Err(ScopeParseError::PositionalConflict { key });
                }
                if values.is_empty() {
                    return Err(ScopeParseError::EmptyMultiValue { key });
                }
                if !values.iter().all(|value| (parameter.validate)(value)) {
                    return Err(ScopeParseError::InvalidParameter { key });
                }
                result.set(key, own_values(&values), true);
            } else if let Some(value) = positional {
                if !(parameter.validate)(value) {
                    return Err(ScopeParseError::InvalidPositional { key });
                }
                result.set(key, vec![value.to_owned()], true);
            } else if parameter.required {
                return Err(ScopeParseError::MissingRequiredParameter { key });
            } else if !parameter.default.is_empty() {
                result.set(key, own_values(parameter.default), false);
            }
        }
        if self.prefix == "rpc" && result.single("aud") == Some("*") && result.contains("lxm", "*")
        {
            return Err(ScopeParseError::ForbiddenCombination {
                prefix: self.prefix,
            });
        }
        Ok(result)
    }

    fn build(self, params: &[(&str, &[&str])]) -> Result<ScopeParameterValues, ScopeParseError> {
        self.read(
            None,
            params
                .iter()
                .filter(|(_, values)| !values.is_empty())
                .map(|&(key, values)| (key, values.to_vec())),
        )
    }

    fn format(self, values: &ScopeParameterValues, wire: bool) -> Result<String, ScopeParseError> {
        let mut syntax = ScopeStringSyntax {
            prefix: self.prefix.to_owned(),
            positional: None,
            parameters: ScopeParameterBag::default(),
        };
        for parameter in self.parameters {
            let raw = values.multiple(parameter.key);
            let normalized = self.normalize(parameter.key, raw);
            if !parameter.required
                && normalized
                    .iter()
                    .map(String::as_str)
                    .collect::<BTreeSet<_>>()
                    == parameter.default.iter().copied().collect()
            {
                continue;
            }
            if parameter.key == self.positional && normalized.len() == 1 {
                syntax.positional = normalized.into_iter().next();
            } else {
                let mut seen = BTreeSet::new();
                for value in normalized {
                    if seen.insert(value.clone()) {
                        syntax.parameters.append(parameter.key.to_owned(), value);
                    }
                }
            }
        }
        if wire {
            syntax.wire_string()
        } else {
            syntax.canonical_string()
        }
    }

    fn normalize(self, key: &str, raw: &[String]) -> Vec<String> {
        match key {
            "collection" | "lxm" => {
                if raw.iter().any(|value| value == "*") {
                    vec!["*".to_owned()]
                } else {
                    raw.iter()
                        .cloned()
                        .collect::<BTreeSet<_>>()
                        .into_iter()
                        .collect()
                }
            }
            "action" if self.prefix == "repo" => REPO_ACTIONS
                .iter()
                .filter(|action| raw.iter().any(|value| value == **action))
                .map(|action| (*action).to_owned())
                .collect(),
            "accept" => normalize_accept(raw),
            _ => raw.to_vec(),
        }
    }

    fn needed(self, params: &[(&'static str, &str)]) -> Result<String, ScopeParseError> {
        let mut values = ScopeParameterValues::default();
        for &(key, value) in params {
            values.set(key, vec![value.to_owned()], true);
        }
        self.format(&values, true)
    }

    fn meaning(self, values: &ScopeParameterValues) -> BTreeMap<&'static str, BTreeSet<String>> {
        self.parameters
            .iter()
            .map(|parameter| {
                let key = parameter.key;
                let raw = values.multiple(key);
                let normalized = if self.prefix == "account"
                    && key == "action"
                    && values.contains(key, "manage")
                {
                    vec!["manage".to_owned()]
                } else {
                    self.normalize(key, raw)
                };
                (key, normalized.into_iter().collect())
            })
            .collect()
    }
}

fn own_values(values: &[&str]) -> Vec<String> {
    values.iter().map(|value| (*value).to_owned()).collect()
}

fn nsid_or_any(value: &str) -> bool {
    value == "*" || is_nsid(value)
}

fn audience_or_any(value: &str) -> bool {
    value == "*" || is_atproto_did_ref_absolute(value)
}

pub(crate) fn is_repo_action(value: &str) -> bool {
    REPO_ACTIONS.contains(&value)
}

pub(crate) fn is_account_action(value: &str) -> bool {
    matches!(value, "read" | "manage")
}

pub(crate) fn is_account_attr(value: &str) -> bool {
    matches!(value, "email" | "repo" | "status")
}

pub(crate) fn is_identity_attr(value: &str) -> bool {
    matches!(value, "handle" | "*")
}

const REPO: Schema = Schema {
    prefix: "repo",
    positional: "collection",
    parameters: &[
        Parameter::required("collection", true, nsid_or_any),
        Parameter::optional("action", true, REPO_ACTIONS, is_repo_action),
    ],
};

const RPC: Schema = Schema {
    prefix: "rpc",
    positional: "lxm",
    parameters: &[
        Parameter::required("lxm", true, nsid_or_any),
        Parameter::required("aud", false, audience_or_any),
    ],
};

const ACCOUNT: Schema = Schema {
    prefix: "account",
    positional: "attr",
    parameters: &[
        Parameter::required("attr", false, is_account_attr),
        Parameter::optional("action", true, &["read"], is_account_action),
    ],
};

const BLOB: Schema = Schema {
    prefix: "blob",
    positional: "accept",
    parameters: &[Parameter::required("accept", true, is_accept)],
};

const IDENTITY: Schema = Schema {
    prefix: "identity",
    positional: "attr",
    parameters: &[Parameter::required("attr", false, is_identity_attr)],
};

const INCLUDE: Schema = Schema {
    prefix: "include",
    positional: "nsid",
    parameters: &[
        Parameter::required("nsid", false, is_nsid),
        Parameter::optional("aud", false, &[], is_atproto_did_ref_absolute),
    ],
};

macro_rules! family {
    ($(#[$doc:meta])* $name:ident, $schema:ident) => {
        $(#[$doc])*
        #[derive(Clone, Debug, Eq, Hash, PartialEq)]
        pub struct $name(ScopeParameterValues);

        impl $name {
            pub fn parse(value: &str) -> Result<Self, ScopeParseError> {
                $schema.parse(value).map(Self)
            }

            pub fn parameters(&self) -> &ScopeParameterValues {
                &self.0
            }

            pub fn canonical_scope_string(&self) -> Result<String, ScopeParseError> {
                $schema.format(&self.0, false)
            }

            pub fn wire_scope_string(&self) -> Result<String, ScopeParseError> {
                $schema.format(&self.0, true)
            }

            fn same_grant(&self, other: &Self) -> bool {
                $schema.meaning(&self.0) == $schema.meaning(&other.0)
            }
        }
    };
}

family!(
    /// Grants write actions on repository collections.
    RepoPermission,
    REPO
);
family!(
    /// Grants access to RPC methods, constrained by service audience.
    RpcPermission,
    RPC
);
family!(
    /// Grants access to account attributes.
    AccountPermission,
    ACCOUNT
);
family!(
    /// Grants blob uploads by media type.
    BlobPermission,
    BLOB
);
family!(
    /// Grants access to identity attributes.
    IdentityPermission,
    IDENTITY
);
family!(
    /// Refers to an external Lexicon permission set.
    IncludeScope,
    INCLUDE
);

impl RepoPermission {
    /// Build a validated permission from decoded parameter values.
    pub fn new(collections: &[&str], actions: &[&str]) -> Result<Self, ScopeParseError> {
        REPO.build(&[("collection", collections), ("action", actions)])
            .map(Self)
    }

    pub fn matches(&self, collection: &str, action: &str) -> bool {
        self.0.contains("action", action)
            && (self.0.contains("collection", "*") || self.0.contains("collection", collection))
    }

    pub fn scope_needed(collection: &str, action: &str) -> Result<String, ScopeParseError> {
        if !is_repo_action(action) {
            return Err(ScopeParseError::InvalidParameter { key: "action" });
        }
        REPO.needed(&[("collection", collection), ("action", action)])
    }

    pub(crate) fn from_lexicon(fields: BTreeMap<&str, Vec<&str>>) -> Result<Self, ScopeParseError> {
        REPO.read(None, fields).map(Self)
    }
}

impl RpcPermission {
    /// Build a validated permission from decoded parameter values.
    pub fn new(methods: &[&str], aud: &str) -> Result<Self, ScopeParseError> {
        RPC.build(&[("lxm", methods), ("aud", &[aud])]).map(Self)
    }

    pub fn matches(&self, lxm: &str, aud: &str) -> bool {
        (self.0.single("aud") == Some("*") || self.0.single("aud") == Some(aud))
            && (self.0.contains("lxm", "*") || self.0.contains("lxm", lxm))
    }

    pub fn scope_needed(lxm: &str, aud: &str) -> Result<String, ScopeParseError> {
        RPC.needed(&[("lxm", lxm), ("aud", aud)])
    }

    pub(crate) fn from_lexicon(fields: BTreeMap<&str, Vec<&str>>) -> Result<Self, ScopeParseError> {
        RPC.read(None, fields).map(Self)
    }
}

impl AccountPermission {
    /// Build a validated permission from decoded parameter values.
    pub fn new(attr: &str, action: &str) -> Result<Self, ScopeParseError> {
        ACCOUNT
            .build(&[("attr", &[attr]), ("action", &[action])])
            .map(Self)
    }

    pub fn matches(&self, attr: &str, action: &str) -> bool {
        is_account_action(action)
            && self.0.single("attr") == Some(attr)
            && (self.0.contains("action", action) || self.0.contains("action", "manage"))
    }

    pub fn scope_needed(attr: &str, action: &str) -> Result<String, ScopeParseError> {
        ACCOUNT.needed(&[("attr", attr), ("action", action)])
    }
}

impl BlobPermission {
    /// Build a validated permission from decoded parameter values.
    pub fn new(patterns: &[&str]) -> Result<Self, ScopeParseError> {
        BLOB.build(&[("accept", patterns)]).map(Self)
    }

    pub fn matches(&self, mime: &str) -> bool {
        if !is_mime(mime) {
            return false;
        }
        self.0
            .multiple("accept")
            .iter()
            .any(|grant| accept_covers(grant, mime))
    }

    pub fn scope_needed(mime: &str) -> Result<String, ScopeParseError> {
        BLOB.needed(&[("accept", mime)])
    }
}

impl IdentityPermission {
    /// Build a validated permission from decoded parameter values.
    pub fn new(attr: &str) -> Result<Self, ScopeParseError> {
        IDENTITY.build(&[("attr", &[attr])]).map(Self)
    }

    pub fn matches(&self, attr: &str) -> bool {
        is_identity_attr(attr)
            && (self.0.single("attr") == Some("*") || self.0.single("attr") == Some(attr))
    }

    pub fn scope_needed(attr: &str) -> Result<String, ScopeParseError> {
        IDENTITY.needed(&[("attr", attr)])
    }
}

impl IncludeScope {
    /// Build a validated permission-set reference from decoded values.
    pub fn new(nsid: &str, aud: Option<&str>) -> Result<Self, ScopeParseError> {
        INCLUDE
            .build(&[("nsid", &[nsid]), ("aud", aud.as_slice())])
            .map(Self)
    }
}

fn media_parts(value: &str) -> Option<(&str, &str)> {
    let (kind, sub) = value.split_once('/')?;
    (!kind.is_empty() && !sub.is_empty() && !sub.contains('/') && !value.contains(' '))
        .then_some((kind, sub))
}

/// Whether a media type is concrete and contains no wildcard.
pub fn is_mime(value: &str) -> bool {
    media_parts(value).is_some() && !value.contains('*')
}

/// Whether a media type is a valid exact or wildcard blob pattern.
pub fn is_accept(value: &str) -> bool {
    if value == "*/*" {
        return true;
    }
    media_parts(value)
        .is_some_and(|(kind, sub)| !kind.contains('*') && (sub == "*" || !sub.contains('*')))
}

pub(crate) fn accept_covers(grant: &str, need: &str) -> bool {
    if grant == "*/*" || grant.eq_ignore_ascii_case(need) {
        return true;
    }
    grant
        .strip_suffix("/*")
        .zip(media_parts(need))
        .is_some_and(|(kind, (need_kind, _))| kind.eq_ignore_ascii_case(need_kind))
}

fn normalize_accept(raw: &[String]) -> Vec<String> {
    if raw.iter().any(|value| value == "*/*") {
        return vec!["*/*".to_owned()];
    }
    let mut folded: Vec<_> = raw.iter().map(|value| value.to_ascii_lowercase()).collect();
    let wildcards: BTreeSet<_> = folded
        .iter()
        .filter_map(|value| value.strip_suffix("/*").map(str::to_owned))
        .collect();
    folded.retain(|value| match media_parts(value) {
        Some((kind, subtype)) if subtype != "*" => !wildcards.contains(kind),
        _ => true,
    });
    folded.sort();
    folded
}

/// A recognized AT Protocol scope or an uninterpreted wire token.
#[derive(Clone, Debug, Eq, Hash, PartialEq)]
pub enum AtProtoScope {
    Atproto,
    TransitionGeneric,
    TransitionEmail,
    TransitionChatBsky,
    Repo(RepoPermission),
    Rpc(RpcPermission),
    Blob(BlobPermission),
    Account(AccountPermission),
    Identity(IdentityPermission),
    Include(IncludeScope),
    Unrecognized(String),
}

impl AtProtoScope {
    /// Parse a scope understood by this version of Petrel.
    pub fn parse(value: &str) -> Result<Self, ScopeParseError> {
        match value {
            "atproto" => return Ok(Self::Atproto),
            "transition:generic" => return Ok(Self::TransitionGeneric),
            "transition:email" => return Ok(Self::TransitionEmail),
            "transition:chat.bsky" => return Ok(Self::TransitionChatBsky),
            _ => {}
        }
        let prefix = value.split([':', '?']).next().unwrap_or(value);
        match prefix {
            "repo" => RepoPermission::parse(value).map(Self::Repo),
            "rpc" => RpcPermission::parse(value).map(Self::Rpc),
            "blob" => BlobPermission::parse(value).map(Self::Blob),
            "account" => AccountPermission::parse(value).map(Self::Account),
            "identity" => IdentityPermission::parse(value).map(Self::Identity),
            "include" => IncludeScope::parse(value).map(Self::Include),
            _ => Err(ScopeParseError::UnknownPrefix),
        }
    }

    /// Parse a scope while preserving an unknown, syntactically valid token.
    pub fn parse_or_unrecognized(value: &str) -> Result<Self, ScopeParseError> {
        match Self::parse(value) {
            Err(ScopeParseError::UnknownPrefix) if crate::is_scope_token(value) => {
                Ok(Self::Unrecognized(value.to_owned()))
            }
            parsed => parsed,
        }
    }

    /// Return the reference implementation's canonical wire spelling.
    pub fn canonical_scope_string(&self) -> Result<String, ScopeParseError> {
        self.format(false)
    }

    /// Preserve grant meaning when the result is parsed on the wire.
    pub fn wire_scope_string(&self) -> Result<String, ScopeParseError> {
        let canonical = self.format(false)?;
        match Self::parse_or_unrecognized(&canonical) {
            Ok(reparsed) if self.same_grant(&reparsed) => Ok(canonical),
            _ => self.format(true),
        }
    }

    fn format(&self, wire: bool) -> Result<String, ScopeParseError> {
        match self {
            Self::Atproto => Ok("atproto".to_owned()),
            Self::TransitionGeneric => Ok("transition:generic".to_owned()),
            Self::TransitionEmail => Ok("transition:email".to_owned()),
            Self::TransitionChatBsky => Ok("transition:chat.bsky".to_owned()),
            Self::Repo(p) => REPO.format(&p.0, wire),
            Self::Rpc(p) => RPC.format(&p.0, wire),
            Self::Blob(p) => BLOB.format(&p.0, wire),
            Self::Account(p) => ACCOUNT.format(&p.0, wire),
            Self::Identity(p) => IDENTITY.format(&p.0, wire),
            Self::Include(p) => INCLUDE.format(&p.0, wire),
            Self::Unrecognized(raw) => {
                if !crate::is_scope_token(raw) {
                    return Err(ScopeParseError::NotAScopeToken);
                }
                if Self::parse(raw) != Err(ScopeParseError::UnknownPrefix) {
                    return Err(ScopeParseError::ForbiddenCombination { prefix: "opaque" });
                }
                Ok(raw.clone())
            }
        }
    }

    pub(crate) fn same_grant(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::Repo(a), Self::Repo(b)) => a.same_grant(b),
            (Self::Rpc(a), Self::Rpc(b)) => a.same_grant(b),
            (Self::Blob(a), Self::Blob(b)) => a.same_grant(b),
            (Self::Account(a), Self::Account(b)) => a.same_grant(b),
            (Self::Identity(a), Self::Identity(b)) => a.same_grant(b),
            (Self::Include(a), Self::Include(b)) => a.same_grant(b),
            _ => self == other,
        }
    }
}
