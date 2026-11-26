//! Static validation of [`LexiconDoc`] schemas and reference parsing.

use std::collections::HashSet;
use std::fmt;

use petrel_core::{Nsid, RecordKey};
use thiserror::Error;

use crate::doc::{
    LexArray, LexBlob, LexBytes, LexInteger, LexObject, LexPermissionSet, LexRecord,
    LexRecordKeyType, LexRef, LexRefUnion, LexString, LexXrpcParameters, LexXrpcProcedure,
    LexXrpcQuery, LexXrpcSubscription, LexiconDefinition, LexiconDoc,
};

/// Parsed schema reference (`#def`, `nsid`, or `nsid#def`).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct LexiconReference {
    /// Target NSID (`None` when relative `#def` in the same document).
    pub nsid: Option<String>,
    /// Target definition name (`"main"` when omitted).
    pub def_name: String,
}

impl LexiconReference {
    /// Parse a Lexicon `ref` string.
    pub fn parse(raw: &str) -> Result<Self, LexiconSchemaError> {
        if raw.is_empty() {
            return Err(LexiconSchemaError::InvalidReference {
                reference: raw.to_owned(),
                path: String::new(),
            });
        }
        if let Some(fragment) = raw.strip_prefix('#') {
            if !is_valid_def_name(fragment) {
                return Err(LexiconSchemaError::InvalidReference {
                    reference: raw.to_owned(),
                    path: String::new(),
                });
            }
            return Ok(Self {
                nsid: None,
                def_name: fragment.to_owned(),
            });
        }
        if let Some((nsid, fragment)) = raw.split_once('#') {
            if Nsid::parse(nsid).is_err() || !is_valid_def_name(fragment) {
                return Err(LexiconSchemaError::InvalidReference {
                    reference: raw.to_owned(),
                    path: String::new(),
                });
            }
            return Ok(Self {
                nsid: Some(nsid.to_owned()),
                def_name: fragment.to_owned(),
            });
        }
        if Nsid::parse(raw).is_err() {
            return Err(LexiconSchemaError::InvalidReference {
                reference: raw.to_owned(),
                path: String::new(),
            });
        }
        Ok(Self {
            nsid: Some(raw.to_owned()),
            def_name: "main".to_owned(),
        })
    }

    /// Resolve a possibly relative reference against `current_nsid`, returning `(nsid, def_name)`.
    pub fn resolve<'a>(&'a self, current_nsid: &'a str) -> (&'a str, &'a str) {
        (
            self.nsid.as_deref().unwrap_or(current_nsid),
            self.def_name.as_str(),
        )
    }

    /// Canonical `nsid#def` string (omitting `#main` if `main`).
    pub fn canonical_with_base(&self, current_nsid: &str) -> String {
        let (nsid, def) = self.resolve(current_nsid);
        if def == "main" {
            nsid.to_owned()
        } else {
            format!("{nsid}#{def}")
        }
    }
}

impl fmt::Display for LexiconReference {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.nsid {
            None => write!(f, "#{}", self.def_name),
            Some(nsid) if self.def_name == "main" => f.write_str(nsid),
            Some(nsid) => write!(f, "{nsid}#{}", self.def_name),
        }
    }
}

/// Options controlling static Lexicon schema validation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LexiconSchemaOptions {
    /// Allow non-standard string `format` values (such as `"space-ref"`).
    pub allow_unknown_string_formats: bool,
    /// Allow experimental / non-v1 definition types (such as `"space"`).
    pub allow_experimental_definitions: bool,
}

impl LexiconSchemaOptions {
    /// Strict Lexicon v1 schema validation.
    pub const fn strict() -> Self {
        Self {
            allow_unknown_string_formats: false,
            allow_experimental_definitions: false,
        }
    }

    /// Lenient validation permitting permissioned-spaces drafts (`"space"`, `"space-ref"`).
    pub const fn lenient() -> Self {
        Self {
            allow_unknown_string_formats: true,
            allow_experimental_definitions: true,
        }
    }
}

impl Default for LexiconSchemaOptions {
    fn default() -> Self {
        Self::strict()
    }
}

/// Errors produced when validating a [`LexiconDoc`] schema.
#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum LexiconSchemaError {
    /// `lexicon` version field is not `1`.
    #[error("unsupported lexicon version {version} (expected 1)")]
    UnsupportedVersion {
        /// Version number present in the document.
        version: i64,
    },

    /// `id` is not a valid NSID.
    #[error("invalid lexicon NSID {id:?}")]
    InvalidId {
        /// The malformed ID string.
        id: String,
    },

    /// A definition key in `defs` is invalid.
    #[error("invalid definition name {name:?}")]
    InvalidDefName {
        /// Malformed definition name.
        name: String,
    },

    /// Non-primary definition or nested primary definition violation.
    #[error("invalid definition placement at {path}: {message}")]
    InvalidPlacement {
        /// Schema path (`#<def>/...`).
        path: String,
        /// Explanation.
        message: String,
    },

    /// Unknown string `format` rejected under strict validation.
    #[error("unknown string format {format:?} at {path}")]
    UnknownStringFormat {
        /// Schema path.
        path: String,
        /// Unknown format name.
        format: String,
    },

    /// Experimental or unknown `"type"` rejected under strict validation.
    #[error("unsupported definition type {kind:?} at {path}")]
    UnsupportedDefinitionType {
        /// Schema path.
        path: String,
        /// Raw `"type"` name.
        kind: String,
    },

    /// Invalid schema constraint (e.g. `minLength > maxLength`, negative length, bad `required`/`nullable`).
    #[error("invalid schema constraint at {path}: {message}")]
    InvalidConstraint {
        /// Schema path.
        path: String,
        /// Description of the violated rule.
        message: String,
    },

    /// Malformed `ref` target string.
    #[error("invalid lexicon reference {reference:?} at {path}")]
    InvalidReference {
        /// Reference string.
        reference: String,
        /// Schema path.
        path: String,
    },

    /// Conflicting or invalid `record.key` specifier.
    #[error("invalid record key specifier {key:?} at {path}")]
    InvalidRecordKey {
        /// Key string.
        key: String,
        /// Schema path.
        path: String,
    },
}

impl LexiconDoc {
    /// Validate this schema document according to `options`.
    pub fn validate(&self, options: LexiconSchemaOptions) -> Result<(), LexiconSchemaError> {
        if self.lexicon != 1 {
            return Err(LexiconSchemaError::UnsupportedVersion {
                version: self.lexicon,
            });
        }
        if Nsid::parse(&self.id).is_err() {
            return Err(LexiconSchemaError::InvalidId {
                id: self.id.clone(),
            });
        }
        if let Some(rev) = self.revision
            && rev < 0
        {
            return Err(LexiconSchemaError::InvalidConstraint {
                path: "/revision".to_owned(),
                message: "revision must be non-negative".to_owned(),
            });
        }

        for (def_name, def) in &self.defs {
            if !is_valid_def_name(def_name) {
                return Err(LexiconSchemaError::InvalidDefName {
                    name: def_name.clone(),
                });
            }
            let path = format!("#{def_name}");
            if def_name != "main" && def.is_primary_definition() {
                return Err(LexiconSchemaError::InvalidPlacement {
                    path,
                    message: format!(
                        "primary definition type {:?} is only allowed under #main",
                        def.type_name()
                    ),
                });
            }
            if matches!(
                def,
                LexiconDefinition::Unknown(_)
                    | LexiconDefinition::Ref(_)
                    | LexiconDefinition::Union(_)
                    | LexiconDefinition::Null(_)
                    | LexiconDefinition::Params(_)
            ) {
                return Err(LexiconSchemaError::InvalidPlacement {
                    path,
                    message: format!(
                        "definition type {:?} cannot appear at top level of defs",
                        def.type_name()
                    ),
                });
            }
            validate_definition(def, &path, true, options)?;
        }

        Ok(())
    }
}

fn is_valid_def_name(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= 64
        && name.bytes().enumerate().all(|(i, b)| {
            if i == 0 {
                b.is_ascii_alphabetic()
            } else {
                b.is_ascii_alphanumeric() || b == b'_'
            }
        })
}

fn validate_definition(
    def: &LexiconDefinition,
    path: &str,
    top_level: bool,
    options: LexiconSchemaOptions,
) -> Result<(), LexiconSchemaError> {
    if !top_level && def.is_primary_definition() {
        return Err(LexiconSchemaError::InvalidPlacement {
            path: path.to_owned(),
            message: format!(
                "primary definition type {:?} cannot be nested",
                def.type_name()
            ),
        });
    }

    match def {
        LexiconDefinition::Record(rec) => validate_record(rec, path, options),
        LexiconDefinition::Query(query) => validate_query(query, path, options),
        LexiconDefinition::Procedure(proc_def) => validate_procedure(proc_def, path, options),
        LexiconDefinition::Subscription(sub) => validate_subscription(sub, path, options),
        LexiconDefinition::PermissionSet(ps) => validate_permission_set(ps, path),
        LexiconDefinition::Space(space) => {
            if !options.allow_experimental_definitions {
                return Err(LexiconSchemaError::UnsupportedDefinitionType {
                    path: path.to_owned(),
                    kind: "space".to_owned(),
                });
            }
            if let Some(key) = &space.key {
                validate_record_key(key, path)?;
            }
            if let Some(collections) = &space.collections {
                for coll in collections {
                    if Nsid::parse(coll).is_err() {
                        return Err(LexiconSchemaError::InvalidConstraint {
                            path: format!("{path}/collections"),
                            message: format!("invalid collection NSID {coll:?}"),
                        });
                    }
                }
            }
            Ok(())
        }
        LexiconDefinition::Unsupported { kind } => {
            if !options.allow_experimental_definitions {
                return Err(LexiconSchemaError::UnsupportedDefinitionType {
                    path: path.to_owned(),
                    kind: kind.clone(),
                });
            }
            Ok(())
        }
        LexiconDefinition::Object(obj) => validate_object(obj, path, options),
        LexiconDefinition::Array(arr) => validate_array(arr, path, options),
        LexiconDefinition::String(s) => validate_string(s, path, options),
        LexiconDefinition::Integer(int) => validate_integer(int, path),
        LexiconDefinition::Bytes(bytes) => validate_bytes(bytes, path),
        LexiconDefinition::Blob(blob) => validate_blob(blob, path),
        LexiconDefinition::Ref(r) => validate_ref(r, path),
        LexiconDefinition::Union(u) => validate_union(u, path),
        LexiconDefinition::Params(p) => validate_params(p, path, options),
        LexiconDefinition::Boolean(_)
        | LexiconDefinition::CidLink(_)
        | LexiconDefinition::Token(_)
        | LexiconDefinition::Unknown(_)
        | LexiconDefinition::Null(_) => Ok(()),
    }
}

fn validate_record_key(key: &LexRecordKeyType, path: &str) -> Result<(), LexiconSchemaError> {
    match key {
        LexRecordKeyType::Tid | LexRecordKeyType::Nsid | LexRecordKeyType::Any => Ok(()),
        LexRecordKeyType::Literal(lit) => {
            if RecordKey::parse(lit).is_ok() {
                Ok(())
            } else {
                Err(LexiconSchemaError::InvalidRecordKey {
                    key: key.as_str(),
                    path: path.to_owned(),
                })
            }
        }
        LexRecordKeyType::Custom(other) => Err(LexiconSchemaError::InvalidRecordKey {
            key: other.clone(),
            path: path.to_owned(),
        }),
    }
}

fn validate_record(
    rec: &LexRecord,
    path: &str,
    options: LexiconSchemaOptions,
) -> Result<(), LexiconSchemaError> {
    if let Some(key) = &rec.key {
        validate_record_key(key, path)?;
    }
    if rec.record.kind.as_deref() != Some("object") {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: format!("{path}/record"),
            message: format!(
                "record schema body must have type \"object\", got {:?}",
                rec.record.kind
            ),
        });
    }
    validate_object(&rec.record, &format!("{path}/record"), options)
}

fn validate_query(
    query: &LexXrpcQuery,
    path: &str,
    options: LexiconSchemaOptions,
) -> Result<(), LexiconSchemaError> {
    if let Some(params) = &query.parameters {
        validate_params(params, &format!("{path}/parameters"), options)?;
    }
    if let Some(output) = &query.output {
        if output.encoding.is_empty() {
            return Err(LexiconSchemaError::InvalidConstraint {
                path: format!("{path}/output/encoding"),
                message: "output encoding must not be empty".to_owned(),
            });
        }
        if let Some(schema) = &output.schema {
            validate_definition(schema, &format!("{path}/output/schema"), false, options)?;
        }
    }
    Ok(())
}

fn validate_procedure(
    proc_def: &LexXrpcProcedure,
    path: &str,
    options: LexiconSchemaOptions,
) -> Result<(), LexiconSchemaError> {
    if let Some(params) = &proc_def.parameters {
        validate_params(params, &format!("{path}/parameters"), options)?;
    }
    if let Some(input) = &proc_def.input {
        if input.encoding.is_empty() {
            return Err(LexiconSchemaError::InvalidConstraint {
                path: format!("{path}/input/encoding"),
                message: "input encoding must not be empty".to_owned(),
            });
        }
        if let Some(schema) = &input.schema {
            validate_definition(schema, &format!("{path}/input/schema"), false, options)?;
        }
    }
    if let Some(output) = &proc_def.output {
        if output.encoding.is_empty() {
            return Err(LexiconSchemaError::InvalidConstraint {
                path: format!("{path}/output/encoding"),
                message: "output encoding must not be empty".to_owned(),
            });
        }
        if let Some(schema) = &output.schema {
            validate_definition(schema, &format!("{path}/output/schema"), false, options)?;
        }
    }
    Ok(())
}

fn validate_subscription(
    sub: &LexXrpcSubscription,
    path: &str,
    options: LexiconSchemaOptions,
) -> Result<(), LexiconSchemaError> {
    if let Some(params) = &sub.parameters {
        validate_params(params, &format!("{path}/parameters"), options)?;
    }
    if let Some(message) = &sub.message
        && let Some(schema) = &message.schema
    {
        validate_definition(schema, &format!("{path}/message/schema"), false, options)?;
    }
    Ok(())
}

fn validate_permission_set(ps: &LexPermissionSet, path: &str) -> Result<(), LexiconSchemaError> {
    if let Some(langs) = &ps.title_lang {
        for tag in langs.keys() {
            if petrel_core::Language::parse(tag).is_err() {
                return Err(LexiconSchemaError::InvalidConstraint {
                    path: format!("{path}/title:lang/{tag}"),
                    message: format!("invalid language tag {tag:?}"),
                });
            }
        }
    }
    if let Some(langs) = &ps.detail_lang {
        for tag in langs.keys() {
            if petrel_core::Language::parse(tag).is_err() {
                return Err(LexiconSchemaError::InvalidConstraint {
                    path: format!("{path}/detail:lang/{tag}"),
                    message: format!("invalid language tag {tag:?}"),
                });
            }
        }
    }
    for (idx, perm) in ps.permissions.iter().enumerate() {
        let ppath = format!("{path}/permissions/{idx}");
        if let Some(kind) = &perm.kind
            && kind != "permission"
        {
            return Err(LexiconSchemaError::InvalidConstraint {
                path: ppath,
                message: format!("expected permission type \"permission\", got {kind:?}"),
            });
        }
        if perm.resource.is_empty() {
            return Err(LexiconSchemaError::InvalidConstraint {
                path: ppath,
                message: "permission resource must not be empty".to_owned(),
            });
        }
    }
    Ok(())
}

fn validate_params(
    params: &LexXrpcParameters,
    path: &str,
    options: LexiconSchemaOptions,
) -> Result<(), LexiconSchemaError> {
    if let Some(kind) = &params.kind
        && kind != "params"
    {
        return Err(LexiconSchemaError::UnsupportedDefinitionType {
            path: path.to_owned(),
            kind: kind.clone(),
        });
    }
    if let Some(req) = &params.required {
        for name in req {
            if !params.properties.contains_key(name) {
                return Err(LexiconSchemaError::InvalidConstraint {
                    path: format!("{path}/required/{name}"),
                    message: format!("required parameter {name:?} is not listed in properties"),
                });
            }
        }
    }
    for (prop_name, prop_def) in &params.properties {
        let ppath = format!("{path}/properties/{prop_name}");
        match prop_def {
            LexiconDefinition::String(_)
            | LexiconDefinition::Integer(_)
            | LexiconDefinition::Boolean(_)
            | LexiconDefinition::Unknown(_) => {
                validate_definition(prop_def, &ppath, false, options)?;
            }
            LexiconDefinition::Array(arr) => {
                match arr.items.as_ref() {
                    LexiconDefinition::String(_)
                    | LexiconDefinition::Integer(_)
                    | LexiconDefinition::Boolean(_)
                    | LexiconDefinition::Unknown(_) => {}
                    other => {
                        return Err(LexiconSchemaError::InvalidConstraint {
                            path: format!("{ppath}/items"),
                            message: format!(
                                "params array items must be scalar, got {:?}",
                                other.type_name()
                            ),
                        });
                    }
                }
                validate_array(arr, &ppath, options)?;
            }
            other => {
                return Err(LexiconSchemaError::InvalidConstraint {
                    path: ppath,
                    message: format!(
                        "params property must be scalar or scalar array, got {:?}",
                        other.type_name()
                    ),
                });
            }
        }
    }
    Ok(())
}

fn validate_object(
    obj: &LexObject,
    path: &str,
    options: LexiconSchemaOptions,
) -> Result<(), LexiconSchemaError> {
    if let Some(req) = &obj.required {
        let mut seen = HashSet::new();
        for name in req {
            if !seen.insert(name.as_str()) {
                return Err(LexiconSchemaError::InvalidConstraint {
                    path: format!("{path}/required/{name}"),
                    message: format!("duplicate required property {name:?}"),
                });
            }
            if !obj.properties.contains_key(name) {
                return Err(LexiconSchemaError::InvalidConstraint {
                    path: format!("{path}/required/{name}"),
                    message: format!("required property {name:?} is not defined in properties"),
                });
            }
        }
    }
    if let Some(nullable) = &obj.nullable {
        let mut seen = HashSet::new();
        for name in nullable {
            if !seen.insert(name.as_str()) {
                return Err(LexiconSchemaError::InvalidConstraint {
                    path: format!("{path}/nullable/{name}"),
                    message: format!("duplicate nullable property {name:?}"),
                });
            }
            if !obj.properties.contains_key(name) {
                return Err(LexiconSchemaError::InvalidConstraint {
                    path: format!("{path}/nullable/{name}"),
                    message: format!("nullable property {name:?} is not defined in properties"),
                });
            }
        }
    }
    for (prop_name, prop_def) in &obj.properties {
        validate_definition(
            prop_def,
            &format!("{path}/properties/{prop_name}"),
            false,
            options,
        )?;
    }
    Ok(())
}

fn validate_array(
    arr: &LexArray,
    path: &str,
    options: LexiconSchemaOptions,
) -> Result<(), LexiconSchemaError> {
    if let Some(min) = arr.min_length
        && min < 0
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: format!("{path}/minLength"),
            message: "array minLength must be non-negative".to_owned(),
        });
    }
    if let Some(max) = arr.max_length
        && max < 0
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: format!("{path}/maxLength"),
            message: "array maxLength must be non-negative".to_owned(),
        });
    }
    if let (Some(min), Some(max)) = (arr.min_length, arr.max_length)
        && min > max
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: path.to_owned(),
            message: format!("array minLength ({min}) exceeds maxLength ({max})"),
        });
    }
    validate_definition(&arr.items, &format!("{path}/items"), false, options)
}

fn validate_string(
    s: &LexString,
    path: &str,
    options: LexiconSchemaOptions,
) -> Result<(), LexiconSchemaError> {
    if let Some(fmt) = &s.format
        && !fmt.is_standard()
        && !options.allow_unknown_string_formats
    {
        return Err(LexiconSchemaError::UnknownStringFormat {
            path: path.to_owned(),
            format: fmt.as_str().to_owned(),
        });
    }
    for (label, val) in [
        ("minLength", s.min_length),
        ("maxLength", s.max_length),
        ("minGraphemes", s.min_graphemes),
        ("maxGraphemes", s.max_graphemes),
    ] {
        if let Some(n) = val
            && n < 0
        {
            return Err(LexiconSchemaError::InvalidConstraint {
                path: format!("{path}/{label}"),
                message: format!("{label} must be non-negative"),
            });
        }
    }
    if let (Some(min), Some(max)) = (s.min_length, s.max_length)
        && min > max
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: path.to_owned(),
            message: format!("string minLength ({min}) exceeds maxLength ({max})"),
        });
    }
    if let (Some(min), Some(max)) = (s.min_graphemes, s.max_graphemes)
        && min > max
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: path.to_owned(),
            message: format!("string minGraphemes ({min}) exceeds maxGraphemes ({max})"),
        });
    }
    if let Some(vals) = &s.enum_values
        && vals.is_empty()
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: format!("{path}/enum"),
            message: "string enum must not be empty".to_owned(),
        });
    }
    Ok(())
}

fn validate_integer(int: &LexInteger, path: &str) -> Result<(), LexiconSchemaError> {
    if let (Some(min), Some(max)) = (int.minimum, int.maximum)
        && min > max
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: path.to_owned(),
            message: format!("integer minimum ({min}) exceeds maximum ({max})"),
        });
    }
    if let Some(vals) = &int.enum_values
        && vals.is_empty()
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: format!("{path}/enum"),
            message: "integer enum must not be empty".to_owned(),
        });
    }
    Ok(())
}

fn validate_bytes(bytes: &LexBytes, path: &str) -> Result<(), LexiconSchemaError> {
    if let Some(min) = bytes.min_length
        && min < 0
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: format!("{path}/minLength"),
            message: "bytes minLength must be non-negative".to_owned(),
        });
    }
    if let Some(max) = bytes.max_length
        && max < 0
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: format!("{path}/maxLength"),
            message: "bytes maxLength must be non-negative".to_owned(),
        });
    }
    if let (Some(min), Some(max)) = (bytes.min_length, bytes.max_length)
        && min > max
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: path.to_owned(),
            message: format!("bytes minLength ({min}) exceeds maxLength ({max})"),
        });
    }
    Ok(())
}

fn validate_blob(blob: &LexBlob, path: &str) -> Result<(), LexiconSchemaError> {
    if let Some(max) = blob.max_size
        && max < 0
    {
        return Err(LexiconSchemaError::InvalidConstraint {
            path: format!("{path}/maxSize"),
            message: "blob maxSize must be non-negative".to_owned(),
        });
    }
    if let Some(accept) = &blob.accept {
        for pattern in accept {
            if pattern.is_empty() || (!pattern.contains('/') && pattern != "*") {
                return Err(LexiconSchemaError::InvalidConstraint {
                    path: format!("{path}/accept"),
                    message: format!("invalid blob MIME accept pattern {pattern:?}"),
                });
            }
        }
    }
    Ok(())
}

fn validate_ref(r: &LexRef, path: &str) -> Result<(), LexiconSchemaError> {
    LexiconReference::parse(&r.target).map_err(|err| match err {
        LexiconSchemaError::InvalidReference { reference, .. } => {
            LexiconSchemaError::InvalidReference {
                reference,
                path: path.to_owned(),
            }
        }
        other => other,
    })?;
    Ok(())
}

fn validate_union(u: &LexRefUnion, path: &str) -> Result<(), LexiconSchemaError> {
    let mut seen = HashSet::new();
    for raw in &u.refs {
        let parsed = LexiconReference::parse(raw).map_err(|err| match err {
            LexiconSchemaError::InvalidReference { reference, .. } => {
                LexiconSchemaError::InvalidReference {
                    reference,
                    path: path.to_owned(),
                }
            }
            other => other,
        })?;
        if !seen.insert(parsed.to_string()) {
            return Err(LexiconSchemaError::InvalidConstraint {
                path: format!("{path}/refs"),
                message: format!("duplicate union ref {raw:?}"),
            });
        }
    }
    Ok(())
}
