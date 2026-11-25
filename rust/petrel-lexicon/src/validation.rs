//! Runtime validation of AT Protocol [`LexValue`] data against schemas in a [`LexiconCatalog`].

use std::collections::BTreeMap;

use petrel_core::{ToValue, Value};
use thiserror::Error;
use unicode_segmentation::UnicodeSegmentation as _;

use crate::catalog::{LexiconCatalog, LexiconCatalogError};
use crate::doc::{
    LexArray, LexBlob, LexBoolean, LexBytes, LexInteger, LexObject, LexRecord, LexRefUnion,
    LexString, LexXrpcParameters, LexiconDefinition,
};
use crate::schema::LexiconReference;
use crate::value::{LexBlobRef, LexValue, ParseOptions, join_pointer};

/// Options controlling runtime data validation against a [`LexiconCatalog`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LexiconValidationOptions {
    /// Validate string values against schema `format` constraints (default `true`).
    pub validate_string_formats: bool,
    /// Require `raw` (`0x55`) codec CIDs on blobs (default `false` for historical vector compatibility).
    pub require_raw_blob_cids: bool,
    /// Maximum recursive schema-validation depth (default `128`).
    pub maximum_depth: usize,
}

impl LexiconValidationOptions {
    /// Standard validation options.
    pub const fn standard() -> Self {
        Self {
            validate_string_formats: true,
            require_raw_blob_cids: false,
            maximum_depth: 128,
        }
    }

    /// Strict options also requiring `raw` codec CIDs on blobs.
    pub const fn strict() -> Self {
        Self {
            validate_string_formats: true,
            require_raw_blob_cids: true,
            maximum_depth: 128,
        }
    }
}

impl Default for LexiconValidationOptions {
    fn default() -> Self {
        Self::standard()
    }
}

/// Errors produced when validating runtime data against a Lexicon schema.
#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum LexiconValidationError {
    /// Catalog lookup failed while starting validation.
    #[error(transparent)]
    Catalog(#[from] LexiconCatalogError),

    /// JSON/CBOR encoding failure when converting a generated Rust value.
    #[error("failed to encode value for validation: {message}")]
    EncodeFailed {
        /// Encoding failure message.
        message: String,
    },

    /// Wire value kind does not match the schema definition type.
    #[error("type mismatch at {path}: expected {expected}, got {actual}")]
    TypeMismatch {
        /// JSON-pointer path.
        path: String,
        /// Expected Lexicon type.
        expected: String,
        /// Actual data-model value kind.
        actual: String,
    },

    /// Required object or parameter property was omitted.
    #[error("missing required field {field:?} at {path}")]
    MissingRequiredField {
        /// JSON-pointer path to containing object.
        path: String,
        /// Required property name.
        field: String,
    },

    /// `null` value supplied for a property not listed in `nullable`.
    #[error("null not allowed for non-nullable field {field:?} at {path}")]
    NullNotAllowed {
        /// JSON-pointer path to containing object.
        path: String,
        /// Field name.
        field: String,
    },

    /// Numeric/length/grapheme/enum/const constraint failed.
    #[error("constraint violation at {path}: {message}")]
    ConstraintViolation {
        /// JSON-pointer path.
        path: String,
        /// Description of the violated constraint.
        message: String,
    },

    /// String value failed its `format` syntax check.
    #[error("string at {path} does not match format {format:?}: {value:?}")]
    StringFormatMismatch {
        /// JSON-pointer path.
        path: String,
        /// Expected format name.
        format: String,
        /// Offending string value.
        value: String,
    },

    /// Union `$type` is missing, invalid, or excluded by a closed union.
    #[error("union mismatch at {path}: {message}")]
    UnionMismatch {
        /// JSON-pointer path.
        path: String,
        /// Reason the union check failed.
        message: String,
    },

    /// Referenced definition could not be found in the catalog.
    #[error("unresolved reference {reference:?} at {path}")]
    UnresolvedReference {
        /// JSON-pointer path.
        path: String,
        /// Reference target string.
        reference: String,
    },

    /// Record `$type` did not match the target collection NSID.
    #[error("record $type mismatch at {path}: expected {expected:?}, got {actual:?}")]
    RecordTypeMismatch {
        /// JSON-pointer path.
        path: String,
        /// Expected collection NSID.
        expected: String,
        /// Actual `$type` present in the record.
        actual: String,
    },

    /// Record key did not satisfy the record schema's `key` rule.
    #[error("invalid record key {key:?} for collection {collection} (expected {expected})")]
    RecordKeyInvalid {
        /// Collection NSID.
        collection: String,
        /// Candidate record key.
        key: String,
        /// Expected key rule.
        expected: String,
    },

    /// Blob payload failed structural, MIME `accept`, or `maxSize` validation.
    #[error("blob validation failed at {path}: {message}")]
    BlobValidation {
        /// JSON-pointer path.
        path: String,
        /// Description of the failure.
        message: String,
    },

    /// Validation depth exceeded `LexiconValidationOptions::maximum_depth`.
    #[error("maximum validation depth {limit} exceeded at {path}")]
    DepthExceeded {
        /// JSON-pointer path.
        path: String,
        /// Configured limit.
        limit: usize,
    },
}

/// Validates AT Protocol runtime values against schemas registered in a [`LexiconCatalog`].
#[derive(Debug)]
pub struct LexiconDataValidator<'a> {
    catalog: &'a LexiconCatalog,
    options: LexiconValidationOptions,
}

impl<'a> LexiconDataValidator<'a> {
    /// Construct a validator backed by `catalog`.
    pub const fn new(catalog: &'a LexiconCatalog, options: LexiconValidationOptions) -> Self {
        Self { catalog, options }
    }

    /// Validate a record object against `collection#main`.
    pub fn validate_record(
        &self,
        collection: &str,
        value: &Value,
        record_key: Option<&str>,
    ) -> Result<(), LexiconValidationError> {
        let def = self.catalog.require_definition(collection, "main")?;
        let LexiconDefinition::Record(rec) = def else {
            return Err(LexiconValidationError::Catalog(
                LexiconCatalogError::UnexpectedDefinitionKind {
                    nsid: collection.to_owned(),
                    def_name: "main".to_owned(),
                    expected: "record".to_owned(),
                    actual: def.type_name().to_owned(),
                },
            ));
        };

        if let Some(key) = record_key {
            if let Some(key_rule) = &rec.key {
                if !key_rule.is_valid_key(key) {
                    return Err(LexiconValidationError::RecordKeyInvalid {
                        collection: collection.to_owned(),
                        key: key.to_owned(),
                        expected: key_rule.as_str(),
                    });
                }
            } else if petrel_core::RecordKey::parse(key).is_err() {
                return Err(LexiconValidationError::RecordKeyInvalid {
                    collection: collection.to_owned(),
                    key: key.to_owned(),
                    expected: "any".to_owned(),
                });
            }
        }

        self.validate_record_object(value, rec, collection, "", 0)
    }

    fn validate_record_object(
        &self,
        value: &Value,
        rec: &LexRecord,
        collection: &str,
        path: &str,
        depth: usize,
    ) -> Result<(), LexiconValidationError> {
        let map = require_plain_object(value, path)?;

        match map.get("$type") {
            Some(type_val) => {
                let Some(type_str) = type_val.as_str() else {
                    return Err(LexiconValidationError::TypeMismatch {
                        path: join_pointer(path, "$type"),
                        expected: "string".to_owned(),
                        actual: type_val.kind().to_owned(),
                    });
                };
                if type_str != collection {
                    return Err(LexiconValidationError::RecordTypeMismatch {
                        path: join_pointer(path, "$type"),
                        expected: collection.to_owned(),
                        actual: type_str.to_owned(),
                    });
                }
            }
            None => {
                return Err(LexiconValidationError::MissingRequiredField {
                    path: path.to_owned(),
                    field: "$type".to_owned(),
                });
            }
        }

        self.validate_object(value, &rec.record, collection, path, depth)
    }

    /// Validate a typed record implementing [`petrel_core::Collection`] and [`petrel_core::ToValue`].
    pub fn validate_typed_record<T: petrel_core::Collection + ToValue>(
        &self,
        record: &T,
        record_key: Option<&str>,
    ) -> Result<(), LexiconValidationError> {
        let mut value = record
            .to_value()
            .map_err(|err| LexiconValidationError::EncodeFailed {
                message: err.to_string(),
            })?;
        if let Value::Object(map) = &mut value
            && !map.contains_key("$type")
        {
            map.insert("$type".to_owned(), Value::String(T::NSID.to_owned()));
        }
        self.validate_record(T::NSID, &value, record_key)
    }

    /// Validate an arbitrary value against `<nsid>#<def_name>`.
    pub fn validate_definition(
        &self,
        nsid: &str,
        def_name: &str,
        value: &Value,
    ) -> Result<(), LexiconValidationError> {
        let def = self.catalog.require_definition(nsid, def_name)?;
        if matches!(def, LexiconDefinition::Record(_)) && def_name == "main" {
            return self.validate_record(nsid, value, None);
        }
        self.validate_node(value, def, nsid, def_name, "", 0)
    }

    /// Validate XRPC query/procedure parameters encoded as key-value query pairs.
    pub fn validate_query_params(
        &self,
        nsid: &str,
        params: &[(&str, &str)],
    ) -> Result<(), LexiconValidationError> {
        let schema = self.catalog.require_xrpc_parameters(nsid)?;
        let Some(schema) = schema else {
            return Ok(());
        };
        let mut grouped: BTreeMap<&str, Vec<&str>> = BTreeMap::new();
        for &(k, v) in params {
            grouped.entry(k).or_default().push(v);
        }
        self.validate_param_groups(nsid, schema, &grouped)
    }

    /// Validate XRPC query/procedure parameters represented as a [`petrel_core::Value::Object`].
    pub fn validate_params_value(
        &self,
        nsid: &str,
        value: &Value,
    ) -> Result<(), LexiconValidationError> {
        let Some(schema) = self.catalog.require_xrpc_parameters(nsid)? else {
            return Ok(());
        };
        let map = require_plain_object(value, "")?;
        self.validate_params_object(nsid, schema, map)
    }

    /// Validate an XRPC procedure input body against `<nsid>#main.input.schema`.
    pub fn validate_xrpc_input(
        &self,
        nsid: &str,
        value: &Value,
    ) -> Result<(), LexiconValidationError> {
        let def = self.catalog.require_definition(nsid, "main")?;
        let LexiconDefinition::Procedure(proc_def) = def else {
            return Err(LexiconValidationError::Catalog(
                LexiconCatalogError::UnexpectedDefinitionKind {
                    nsid: nsid.to_owned(),
                    def_name: "main".to_owned(),
                    expected: "procedure".to_owned(),
                    actual: def.type_name().to_owned(),
                },
            ));
        };
        if let Some(input) = &proc_def.input
            && let Some(schema) = &input.schema
        {
            return self.validate_node(value, schema, nsid, "main", "", 0);
        }
        Ok(())
    }

    /// Validate an XRPC query or procedure output body against `<nsid>#main.output.schema`.
    pub fn validate_xrpc_output(
        &self,
        nsid: &str,
        value: &Value,
    ) -> Result<(), LexiconValidationError> {
        let def = self.catalog.require_definition(nsid, "main")?;
        let schema = match def {
            LexiconDefinition::Query(q) => q.output.as_ref().and_then(|o| o.schema.as_deref()),
            LexiconDefinition::Procedure(p) => p.output.as_ref().and_then(|o| o.schema.as_deref()),
            other => {
                return Err(LexiconValidationError::Catalog(
                    LexiconCatalogError::UnexpectedDefinitionKind {
                        nsid: nsid.to_owned(),
                        def_name: "main".to_owned(),
                        expected: "query or procedure".to_owned(),
                        actual: other.type_name().to_owned(),
                    },
                ));
            }
        };
        if let Some(schema) = schema {
            return self.validate_node(value, schema, nsid, "main", "", 0);
        }
        Ok(())
    }

    /// Validate an XRPC subscription event payload against `<nsid>#main.message.schema`.
    ///
    /// Accepts payloads containing `"$type"` or frame selector `"t"`, or use
    /// [`Self::validate_xrpc_message_with_type`] when the ATProto frame header `t`
    /// is supplied separately (as with generated event structs).
    pub fn validate_xrpc_message(
        &self,
        nsid: &str,
        value: &Value,
    ) -> Result<(), LexiconValidationError> {
        self.validate_xrpc_message_with_type(nsid, None, value)
    }

    /// Validate an XRPC subscription event payload against `<nsid>#main.message.schema`
    /// using an optional out-of-band frame header type selector `t` (for example `"#info"` or
    /// `"com.atproto.sync.subscribeRepos#info"`) without mutating `value`.
    pub fn validate_xrpc_message_with_type(
        &self,
        nsid: &str,
        message_type: Option<&str>,
        value: &Value,
    ) -> Result<(), LexiconValidationError> {
        let def = self.catalog.require_definition(nsid, "main")?;
        let LexiconDefinition::Subscription(sub) = def else {
            return Err(LexiconValidationError::Catalog(
                LexiconCatalogError::UnexpectedDefinitionKind {
                    nsid: nsid.to_owned(),
                    def_name: "main".to_owned(),
                    expected: "subscription".to_owned(),
                    actual: def.type_name().to_owned(),
                },
            ));
        };
        if let Some(msg) = &sub.message
            && let Some(schema) = &msg.schema
        {
            if let LexiconDefinition::Union(u) = schema.as_ref() {
                return self.validate_subscription_union(value, u, nsid, message_type);
            }
            return self.validate_node(value, schema, nsid, "main", "", 0);
        }
        Ok(())
    }

    fn validate_param_groups(
        &self,
        nsid: &str,
        schema: &LexXrpcParameters,
        grouped: &BTreeMap<&str, Vec<&str>>,
    ) -> Result<(), LexiconValidationError> {
        if let Some(required) = &schema.required {
            for field in required {
                if !grouped.contains_key(field.as_str()) {
                    return Err(LexiconValidationError::MissingRequiredField {
                        path: String::new(),
                        field: field.clone(),
                    });
                }
            }
        }
        for (name, prop_def) in &schema.properties {
            let Some(values) = grouped.get(name.as_str()) else {
                continue;
            };
            let path = join_pointer("", name);
            match prop_def {
                LexiconDefinition::Array(arr) => {
                    let mut parsed = Vec::with_capacity(values.len());
                    for raw in values {
                        parsed.push(parse_scalar_query_value(raw, &arr.items, &path)?);
                    }
                    let val = Value::Array(parsed);
                    if matches!(&*arr.items, LexiconDefinition::Unknown(_)) {
                        self.validate_array_header(&val, arr, &path, 0)?;
                    } else {
                        self.validate_array(&val, arr, nsid, &path, 0)?;
                    }
                }
                scalar => {
                    if values.len() > 1 {
                        return Err(LexiconValidationError::TypeMismatch {
                            path,
                            expected: scalar.type_name().to_owned(),
                            actual: "array".to_owned(),
                        });
                    }
                    let parsed = parse_scalar_query_value(values[0], scalar, &path)?;
                    if !matches!(scalar, LexiconDefinition::Unknown(_)) {
                        self.validate_node(&parsed, scalar, nsid, "main", &path, 0)?;
                    }
                }
            }
        }
        Ok(())
    }

    fn validate_params_object(
        &self,
        nsid: &str,
        schema: &LexXrpcParameters,
        map: &BTreeMap<String, Value>,
    ) -> Result<(), LexiconValidationError> {
        if let Some(required) = &schema.required {
            for field in required {
                if !map.contains_key(field) {
                    return Err(LexiconValidationError::MissingRequiredField {
                        path: String::new(),
                        field: field.clone(),
                    });
                }
            }
        }
        for (name, prop_def) in &schema.properties {
            let Some(val) = map.get(name) else {
                continue;
            };
            let path = join_pointer("", name);
            match prop_def {
                LexiconDefinition::Unknown(_) => {}
                LexiconDefinition::Array(arr)
                    if matches!(&*arr.items, LexiconDefinition::Unknown(_)) =>
                {
                    self.validate_array_header(val, arr, &path, 0)?;
                }
                _ => self.validate_node(val, prop_def, nsid, "main", &path, 0)?,
            }
        }
        Ok(())
    }

    fn validate_node(
        &self,
        value: &Value,
        def: &LexiconDefinition,
        current_nsid: &str,
        current_def_name: &str,
        path: &str,
        depth: usize,
    ) -> Result<(), LexiconValidationError> {
        if depth > self.options.maximum_depth {
            return Err(LexiconValidationError::DepthExceeded {
                path: path.to_owned(),
                limit: self.options.maximum_depth,
            });
        }

        match def {
            LexiconDefinition::Object(obj) => {
                self.validate_object(value, obj, current_nsid, path, depth)
            }
            LexiconDefinition::Array(arr) => {
                self.validate_array(value, arr, current_nsid, path, depth)
            }
            LexiconDefinition::String(s) => self.validate_string(value, s, path),
            LexiconDefinition::Integer(int) => validate_integer(value, int, path),
            LexiconDefinition::Boolean(b) => validate_boolean(value, b, path),
            LexiconDefinition::Bytes(bytes) => validate_bytes(value, bytes, path),
            LexiconDefinition::Blob(blob) => self.validate_blob(value, blob, path),
            LexiconDefinition::CidLink(_) => validate_cid_link(value, path),
            LexiconDefinition::Null(_) => validate_null(value, path),
            LexiconDefinition::Unknown(_) => {
                require_plain_object(value, path)?;
                Ok(())
            }
            LexiconDefinition::Token(_) => {
                let expected = if current_def_name == "main" {
                    current_nsid.to_owned()
                } else {
                    format!("{current_nsid}#{current_def_name}")
                };
                match value {
                    Value::String(s) if s == &expected => Ok(()),
                    Value::String(s) => Err(LexiconValidationError::ConstraintViolation {
                        path: path.to_owned(),
                        message: format!("expected token {expected:?}, got {s:?}"),
                    }),
                    other => Err(LexiconValidationError::TypeMismatch {
                        path: path.to_owned(),
                        expected: "string".to_owned(),
                        actual: other.kind().to_owned(),
                    }),
                }
            }
            LexiconDefinition::Ref(r) => {
                self.validate_ref(value, &r.target, current_nsid, path, depth)
            }
            LexiconDefinition::Union(u) => self.validate_union(value, u, current_nsid, path, depth),
            LexiconDefinition::Record(rec) => {
                self.validate_record_object(value, rec, current_nsid, path, depth)
            }
            LexiconDefinition::Params(params) => {
                let Value::Object(map) = value else {
                    return Err(LexiconValidationError::TypeMismatch {
                        path: path.to_owned(),
                        expected: "object".to_owned(),
                        actual: value.kind().to_owned(),
                    });
                };
                self.validate_params_object(current_nsid, params, map)
            }
            LexiconDefinition::Query(_)
            | LexiconDefinition::Procedure(_)
            | LexiconDefinition::Subscription(_)
            | LexiconDefinition::PermissionSet(_)
            | LexiconDefinition::Space(_)
            | LexiconDefinition::Unsupported { .. } => {
                Err(LexiconValidationError::ConstraintViolation {
                    path: path.to_owned(),
                    message: format!(
                        "schema definition type {:?} does not validate value data directly",
                        def.type_name()
                    ),
                })
            }
        }
    }

    fn validate_ref(
        &self,
        value: &Value,
        raw_ref: &str,
        current_nsid: &str,
        path: &str,
        depth: usize,
    ) -> Result<(), LexiconValidationError> {
        let parsed = LexiconReference::parse(raw_ref).map_err(|_| {
            LexiconValidationError::UnresolvedReference {
                path: path.to_owned(),
                reference: raw_ref.to_owned(),
            }
        })?;
        let (target_nsid, target_def) = parsed.resolve(current_nsid);
        let Some(target) = self.catalog.definition(target_nsid, target_def) else {
            return Err(LexiconValidationError::UnresolvedReference {
                path: path.to_owned(),
                reference: parsed.canonical_with_base(current_nsid),
            });
        };
        self.validate_node(value, target, target_nsid, target_def, path, depth + 1)
    }

    fn validate_union(
        &self,
        value: &Value,
        union_def: &LexRefUnion,
        current_nsid: &str,
        path: &str,
        depth: usize,
    ) -> Result<(), LexiconValidationError> {
        let map = require_plain_object(value, path)?;
        let Some(type_val) = map.get("$type") else {
            return Err(LexiconValidationError::UnionMismatch {
                path: path.to_owned(),
                message: "union value object is missing '$type'".to_owned(),
            });
        };
        let Some(type_str) = type_val.as_str() else {
            return Err(LexiconValidationError::UnionMismatch {
                path: join_pointer(path, "$type"),
                message: "union '$type' must be a string".to_owned(),
            });
        };
        self.validate_union_with_selector(
            value,
            union_def,
            current_nsid,
            path,
            depth,
            UnionSelector::DollarType(type_str),
        )
    }

    fn validate_subscription_union(
        &self,
        value: &Value,
        union_def: &LexRefUnion,
        current_nsid: &str,
        message_type: Option<&str>,
    ) -> Result<(), LexiconValidationError> {
        let map = require_plain_object(value, "")?;
        if let Some(t) = message_type {
            return self.validate_union_with_selector(
                value,
                union_def,
                current_nsid,
                "",
                0,
                UnionSelector::FrameHeader(t),
            );
        }
        if let Some(type_val) = map.get("$type") {
            let Some(type_str) = type_val.as_str() else {
                return Err(LexiconValidationError::UnionMismatch {
                    path: "/$type".to_owned(),
                    message: "union '$type' must be a string".to_owned(),
                });
            };
            return self.validate_union_with_selector(
                value,
                union_def,
                current_nsid,
                "",
                0,
                UnionSelector::DollarType(type_str),
            );
        }
        if let Some(t_val) = map.get("t") {
            let Some(t_str) = t_val.as_str() else {
                return Err(LexiconValidationError::UnionMismatch {
                    path: "/t".to_owned(),
                    message: "subscription frame 't' must be a string".to_owned(),
                });
            };
            return self.validate_union_with_selector(
                value,
                union_def,
                current_nsid,
                "",
                0,
                UnionSelector::FrameHeader(t_str),
            );
        }
        Err(LexiconValidationError::UnionMismatch {
            path: String::new(),
            message: "subscription message is missing frame type 't' or '$type'".to_owned(),
        })
    }

    fn validate_union_with_selector(
        &self,
        value: &Value,
        union_def: &LexRefUnion,
        current_nsid: &str,
        path: &str,
        depth: usize,
        selector: UnionSelector<'_>,
    ) -> Result<(), LexiconValidationError> {
        let (selector_field, type_str, allow_relative) = match selector {
            UnionSelector::DollarType(s) => ("$type", s, false),
            UnionSelector::FrameHeader(s) => ("t", s, true),
        };
        if !allow_relative && type_str.ends_with("#main") {
            return Err(LexiconValidationError::UnionMismatch {
                path: join_pointer(path, selector_field),
                message: format!("union '$type' must not use the '#main' suffix; got {type_str:?}"),
            });
        }
        let Ok(value_ref) = LexiconReference::parse(type_str) else {
            return Err(LexiconValidationError::UnionMismatch {
                path: join_pointer(path, selector_field),
                message: format!(
                    "union {selector_field:?} {type_str:?} is not a valid lexicon reference"
                ),
            });
        };
        if !allow_relative && value_ref.nsid.is_none() {
            return Err(LexiconValidationError::UnionMismatch {
                path: join_pointer(path, selector_field),
                message: format!(
                    "union '$type' {type_str:?} must be an absolute lexicon identifier, not a relative '#fragment'"
                ),
            });
        }
        let canonical_type = value_ref.canonical_with_base(current_nsid);

        for member_raw in &union_def.refs {
            let Ok(member_ref) = LexiconReference::parse(member_raw) else {
                continue;
            };
            if member_ref.canonical_with_base(current_nsid) == canonical_type {
                let (target_nsid, target_def) = member_ref.resolve(current_nsid);
                let Some(target) = self.catalog.definition(target_nsid, target_def) else {
                    return Err(LexiconValidationError::UnresolvedReference {
                        path: path.to_owned(),
                        reference: canonical_type,
                    });
                };
                return self.validate_node(value, target, target_nsid, target_def, path, depth + 1);
            }
        }

        if union_def.closed == Some(true) {
            return Err(LexiconValidationError::UnionMismatch {
                path: join_pointer(path, selector_field),
                message: format!("type {canonical_type:?} is not permitted in closed union"),
            });
        }

        Ok(())
    }

    fn validate_object(
        &self,
        value: &Value,
        obj: &LexObject,
        current_nsid: &str,
        path: &str,
        depth: usize,
    ) -> Result<(), LexiconValidationError> {
        if depth + 1 > self.options.maximum_depth {
            return Err(LexiconValidationError::DepthExceeded {
                path: path.to_owned(),
                limit: self.options.maximum_depth,
            });
        }
        let map = require_plain_object(value, path)?;

        if let Some(required) = &obj.required {
            for field in required {
                if !map.contains_key(field) {
                    return Err(LexiconValidationError::MissingRequiredField {
                        path: path.to_owned(),
                        field: field.clone(),
                    });
                }
            }
        }

        for (prop_name, prop_def) in &obj.properties {
            let Some(prop_val) = map.get(prop_name) else {
                continue;
            };
            if matches!(prop_val, Value::Null) {
                let is_nullable = obj
                    .nullable
                    .as_ref()
                    .is_some_and(|list| list.iter().any(|name| name == prop_name));
                if is_nullable || matches!(prop_def, LexiconDefinition::Null(_)) {
                    continue;
                }
                return Err(LexiconValidationError::NullNotAllowed {
                    path: path.to_owned(),
                    field: prop_name.clone(),
                });
            }
            let prop_path = join_pointer(path, prop_name);
            self.validate_node(
                prop_val,
                prop_def,
                current_nsid,
                "main",
                &prop_path,
                depth + 1,
            )?;
        }

        Ok(())
    }

    fn validate_array_header<'b>(
        &self,
        value: &'b Value,
        arr: &LexArray,
        path: &str,
        depth: usize,
    ) -> Result<&'b [Value], LexiconValidationError> {
        if depth + 1 > self.options.maximum_depth {
            return Err(LexiconValidationError::DepthExceeded {
                path: path.to_owned(),
                limit: self.options.maximum_depth,
            });
        }
        let Value::Array(items) = value else {
            return Err(LexiconValidationError::TypeMismatch {
                path: path.to_owned(),
                expected: "array".to_owned(),
                actual: value.kind().to_owned(),
            });
        };
        let count = i64::try_from(items.len()).unwrap_or(i64::MAX);
        if let Some(min) = arr.min_length
            && count < min
        {
            return Err(LexiconValidationError::ConstraintViolation {
                path: path.to_owned(),
                message: format!("array length {count} is less than minLength {min}"),
            });
        }
        if let Some(max) = arr.max_length
            && count > max
        {
            return Err(LexiconValidationError::ConstraintViolation {
                path: path.to_owned(),
                message: format!("array length {count} exceeds maxLength {max}"),
            });
        }
        Ok(items)
    }

    fn validate_array(
        &self,
        value: &Value,
        arr: &LexArray,
        current_nsid: &str,
        path: &str,
        depth: usize,
    ) -> Result<(), LexiconValidationError> {
        let items = self.validate_array_header(value, arr, path, depth)?;

        for (idx, item) in items.iter().enumerate() {
            let item_path = join_pointer(path, &idx.to_string());
            self.validate_node(
                item,
                &arr.items,
                current_nsid,
                "main",
                &item_path,
                depth + 1,
            )?;
        }

        Ok(())
    }

    fn validate_string(
        &self,
        value: &Value,
        s: &LexString,
        path: &str,
    ) -> Result<(), LexiconValidationError> {
        let Value::String(text) = value else {
            return Err(LexiconValidationError::TypeMismatch {
                path: path.to_owned(),
                expected: "string".to_owned(),
                actual: value.kind().to_owned(),
            });
        };
        if let Some(expected) = &s.const_value
            && text != expected
        {
            return Err(LexiconValidationError::ConstraintViolation {
                path: path.to_owned(),
                message: format!("expected const string {expected:?}, got {text:?}"),
            });
        }
        if let Some(allowed) = &s.enum_values
            && !allowed.iter().any(|v| v == text)
        {
            return Err(LexiconValidationError::ConstraintViolation {
                path: path.to_owned(),
                message: format!("value {text:?} is not in enum {allowed:?}"),
            });
        }
        let byte_len = i64::try_from(text.len()).unwrap_or(i64::MAX);
        if let Some(min) = s.min_length
            && byte_len < min
        {
            return Err(LexiconValidationError::ConstraintViolation {
                path: path.to_owned(),
                message: format!("UTF-8 byte length {byte_len} is less than minLength {min}"),
            });
        }
        if let Some(max) = s.max_length
            && byte_len > max
        {
            return Err(LexiconValidationError::ConstraintViolation {
                path: path.to_owned(),
                message: format!("UTF-8 byte length {byte_len} exceeds maxLength {max}"),
            });
        }
        if s.min_graphemes.is_some() || s.max_graphemes.is_some() {
            let graphemes = i64::try_from(text.graphemes(true).count()).unwrap_or(i64::MAX);
            if let Some(min) = s.min_graphemes
                && graphemes < min
            {
                return Err(LexiconValidationError::ConstraintViolation {
                    path: path.to_owned(),
                    message: format!("grapheme count {graphemes} is less than minGraphemes {min}"),
                });
            }
            if let Some(max) = s.max_graphemes
                && graphemes > max
            {
                return Err(LexiconValidationError::ConstraintViolation {
                    path: path.to_owned(),
                    message: format!("grapheme count {graphemes} exceeds maxGraphemes {max}"),
                });
            }
        }
        if self.options.validate_string_formats
            && let Some(fmt) = &s.format
            && !fmt.is_valid(text)
        {
            return Err(LexiconValidationError::StringFormatMismatch {
                path: path.to_owned(),
                format: fmt.as_str().to_owned(),
                value: text.clone(),
            });
        }
        Ok(())
    }

    fn validate_blob(
        &self,
        value: &Value,
        blob_schema: &LexBlob,
        path: &str,
    ) -> Result<(), LexiconValidationError> {
        let Value::Object(map) = value else {
            return Err(LexiconValidationError::TypeMismatch {
                path: path.to_owned(),
                expected: "blob".to_owned(),
                actual: value.kind().to_owned(),
            });
        };
        let parse_opts = ParseOptions {
            maximum_depth: self.options.maximum_depth,
            require_raw_blob_cids: self.options.require_raw_blob_cids,
            require_blessed_cids: true,
        };
        let blob = LexBlobRef::from_object(map, &parse_opts, path).map_err(|err| {
            LexiconValidationError::BlobValidation {
                path: path.to_owned(),
                message: err.to_string(),
            }
        })?;
        if let Some(max_size) = blob_schema.max_size
            && blob.size > max_size
        {
            return Err(LexiconValidationError::BlobValidation {
                path: path.to_owned(),
                message: format!("blob size {} exceeds maxSize {max_size}", blob.size),
            });
        }
        if let Some(accept) = &blob_schema.accept
            && !accept.is_empty()
            && !accept
                .iter()
                .any(|pattern| mime_matches(&blob.mime_type, pattern))
        {
            return Err(LexiconValidationError::BlobValidation {
                path: path.to_owned(),
                message: format!(
                    "blob MIME type {:?} is not accepted by {accept:?}",
                    blob.mime_type
                ),
            });
        }
        Ok(())
    }
}

fn validate_integer(
    value: &Value,
    int: &LexInteger,
    path: &str,
) -> Result<(), LexiconValidationError> {
    let Value::Integer(n) = value else {
        return Err(LexiconValidationError::TypeMismatch {
            path: path.to_owned(),
            expected: "integer".to_owned(),
            actual: value.kind().to_owned(),
        });
    };
    if let Some(expected) = int.const_value
        && *n != expected
    {
        return Err(LexiconValidationError::ConstraintViolation {
            path: path.to_owned(),
            message: format!("expected const integer {expected}, got {n}"),
        });
    }
    if let Some(allowed) = &int.enum_values
        && !allowed.contains(n)
    {
        return Err(LexiconValidationError::ConstraintViolation {
            path: path.to_owned(),
            message: format!("integer {n} is not in enum {allowed:?}"),
        });
    }
    if let Some(min) = int.minimum
        && *n < min
    {
        return Err(LexiconValidationError::ConstraintViolation {
            path: path.to_owned(),
            message: format!("integer {n} is less than minimum {min}"),
        });
    }
    if let Some(max) = int.maximum
        && *n > max
    {
        return Err(LexiconValidationError::ConstraintViolation {
            path: path.to_owned(),
            message: format!("integer {n} exceeds maximum {max}"),
        });
    }
    Ok(())
}

fn validate_boolean(
    value: &Value,
    b: &LexBoolean,
    path: &str,
) -> Result<(), LexiconValidationError> {
    let Value::Bool(actual) = value else {
        return Err(LexiconValidationError::TypeMismatch {
            path: path.to_owned(),
            expected: "boolean".to_owned(),
            actual: value.kind().to_owned(),
        });
    };
    if let Some(expected) = b.const_value
        && *actual != expected
    {
        return Err(LexiconValidationError::ConstraintViolation {
            path: path.to_owned(),
            message: format!("expected const boolean {expected}, got {actual}"),
        });
    }
    Ok(())
}

fn validate_bytes(
    value: &Value,
    bytes_schema: &LexBytes,
    path: &str,
) -> Result<(), LexiconValidationError> {
    let Value::Bytes(raw) = value else {
        return Err(LexiconValidationError::TypeMismatch {
            path: path.to_owned(),
            expected: "bytes".to_owned(),
            actual: value.kind().to_owned(),
        });
    };
    let len = i64::try_from(raw.len()).unwrap_or(i64::MAX);
    if let Some(min) = bytes_schema.min_length
        && len < min
    {
        return Err(LexiconValidationError::ConstraintViolation {
            path: path.to_owned(),
            message: format!("bytes length {len} is less than minLength {min}"),
        });
    }
    if let Some(max) = bytes_schema.max_length
        && len > max
    {
        return Err(LexiconValidationError::ConstraintViolation {
            path: path.to_owned(),
            message: format!("bytes length {len} exceeds maxLength {max}"),
        });
    }
    Ok(())
}

fn validate_cid_link(value: &Value, path: &str) -> Result<(), LexiconValidationError> {
    if matches!(value, Value::Link(_)) {
        Ok(())
    } else {
        Err(LexiconValidationError::TypeMismatch {
            path: path.to_owned(),
            expected: "cid-link".to_owned(),
            actual: value.kind().to_owned(),
        })
    }
}

fn validate_null(value: &Value, path: &str) -> Result<(), LexiconValidationError> {
    if matches!(value, Value::Null) {
        Ok(())
    } else {
        Err(LexiconValidationError::TypeMismatch {
            path: path.to_owned(),
            expected: "null".to_owned(),
            actual: value.kind().to_owned(),
        })
    }
}

fn mime_matches(actual: &str, pattern: &str) -> bool {
    let actual_base = actual
        .split(';')
        .next()
        .unwrap_or(actual)
        .trim()
        .to_ascii_lowercase();
    let pattern_norm = pattern.trim().to_ascii_lowercase();
    if pattern_norm == "*" || pattern_norm == "*/*" {
        return true;
    }
    if let Some(prefix) = pattern_norm.strip_suffix("/*") {
        return actual_base
            .split_once('/')
            .is_some_and(|(actual_type, _)| actual_type == prefix);
    }
    actual_base == pattern_norm
}

fn parse_scalar_query_value(
    raw: &str,
    schema: &LexiconDefinition,
    path: &str,
) -> Result<Value, LexiconValidationError> {
    match schema {
        LexiconDefinition::String(_) | LexiconDefinition::Unknown(_) => {
            Ok(Value::String(raw.to_owned()))
        }
        LexiconDefinition::Integer(_) => raw.parse::<i64>().map(Value::Integer).map_err(|_| {
            LexiconValidationError::TypeMismatch {
                path: path.to_owned(),
                expected: "integer".to_owned(),
                actual: "string".to_owned(),
            }
        }),
        LexiconDefinition::Boolean(_) => match raw {
            "true" => Ok(Value::Bool(true)),
            "false" => Ok(Value::Bool(false)),
            _ => Err(LexiconValidationError::TypeMismatch {
                path: path.to_owned(),
                expected: "boolean".to_owned(),
                actual: "string".to_owned(),
            }),
        },
        other => Err(LexiconValidationError::TypeMismatch {
            path: path.to_owned(),
            expected: other.type_name().to_owned(),
            actual: "string".to_owned(),
        }),
    }
}

impl LexValue {
    /// Validate this value against a schema definition in `catalog`.
    pub fn validate(
        &self,
        nsid: &str,
        def_name: &str,
        catalog: &LexiconCatalog,
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(catalog, options).validate_definition(nsid, def_name, &self.0)
    }
}

#[derive(Clone, Copy)]
enum UnionSelector<'a> {
    DollarType(&'a str),
    FrameHeader(&'a str),
}

fn require_plain_object<'a>(
    value: &'a Value,
    path: &str,
) -> Result<&'a BTreeMap<String, Value>, LexiconValidationError> {
    let Value::Object(map) = value else {
        return Err(LexiconValidationError::TypeMismatch {
            path: path.to_owned(),
            expected: "object".to_owned(),
            actual: value.kind().to_owned(),
        });
    };
    if is_blob_ref(map) {
        return Err(LexiconValidationError::TypeMismatch {
            path: path.to_owned(),
            expected: "object".to_owned(),
            actual: "blob".to_owned(),
        });
    }
    Ok(map)
}

fn is_blob_ref(map: &BTreeMap<String, Value>) -> bool {
    matches!(map.get("$type"), Some(Value::String(s)) if s == "blob")
        && LexBlobRef::from_object(
            map,
            &ParseOptions {
                maximum_depth: 128,
                require_raw_blob_cids: false,
                require_blessed_cids: false,
            },
            "",
        )
        .is_ok()
}
