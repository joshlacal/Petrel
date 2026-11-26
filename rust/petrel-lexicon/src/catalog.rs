//! In-memory registry of validated AT Protocol Lexicon documents (`LexiconCatalog`).

use std::collections::BTreeMap;

use petrel_core::{Collection, ToValue, Value};
use thiserror::Error;

use crate::doc::{LexXrpcParameters, LexiconCodingError, LexiconDefinition, LexiconDoc};
use crate::schema::{LexiconReference, LexiconSchemaError, LexiconSchemaOptions};
use crate::validation::{LexiconDataValidator, LexiconValidationError, LexiconValidationOptions};

/// Errors produced when loading or querying a [`LexiconCatalog`].
#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum LexiconCatalogError {
    /// Failed to decode a Lexicon JSON document.
    #[error("failed to decode lexicon JSON: {message}")]
    CodingError {
        /// Human-readable JSON decode failure.
        message: String,
    },

    /// Static schema validation failed when adding a document.
    #[error(transparent)]
    SchemaError(#[from] LexiconSchemaError),

    /// A document with the same NSID is already registered.
    #[error("duplicate lexicon ID {id:?} in catalog")]
    DuplicateId {
        /// Duplicate NSID.
        id: String,
    },

    /// Requested NSID or definition was not found in the catalog.
    #[error("unknown lexicon definition {nsid}#{def_name}")]
    UnknownDefinition {
        /// NSID requested.
        nsid: String,
        /// Definition name requested.
        def_name: String,
    },

    /// Found definition has an unexpected kind (e.g. `query` instead of `record`).
    #[error("lexicon {nsid}#{def_name} is a {actual}, expected {expected}")]
    UnexpectedDefinitionKind {
        /// NSID.
        nsid: String,
        /// Definition name.
        def_name: String,
        /// Expected kind.
        expected: String,
        /// Actual kind.
        actual: String,
    },

    /// Filesystem I/O error while reading a directory of lexicon `.json` files.
    #[cfg(not(target_arch = "wasm32"))]
    #[error("filesystem error reading {path}: {message}")]
    Io {
        /// Path where I/O failed.
        path: String,
        /// Error message.
        message: String,
    },
}

impl From<LexiconCodingError> for LexiconCatalogError {
    fn from(err: LexiconCodingError) -> Self {
        Self::CodingError {
            message: err.to_string(),
        }
    }
}

/// Collection of parsed and validated [`LexiconDoc`] schemas indexed by NSID.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct LexiconCatalog {
    documents: BTreeMap<String, LexiconDoc>,
}

impl LexiconCatalog {
    /// Construct an empty [`LexiconCatalog`].
    pub const fn new() -> Self {
        Self {
            documents: BTreeMap::new(),
        }
    }

    /// Number of registered Lexicon documents.
    pub fn len(&self) -> usize {
        self.documents.len()
    }

    /// Returns `true` when no Lexicon documents are registered.
    pub fn is_empty(&self) -> bool {
        self.documents.is_empty()
    }

    /// Iterate over all `(nsid, doc)` pairs ordered deterministically by NSID.
    pub fn iter(&self) -> impl Iterator<Item = (&str, &LexiconDoc)> {
        self.documents.iter().map(|(k, v)| (k.as_str(), v))
    }

    /// Validate and insert a [`LexiconDoc`].
    pub fn add(
        &mut self,
        doc: LexiconDoc,
        options: LexiconSchemaOptions,
    ) -> Result<(), LexiconCatalogError> {
        doc.validate(options)?;
        if self.documents.contains_key(&doc.id) {
            return Err(LexiconCatalogError::DuplicateId { id: doc.id });
        }
        self.documents.insert(doc.id.clone(), doc);
        Ok(())
    }

    /// Decode, validate, and insert a Lexicon JSON document.
    pub fn add_json(
        &mut self,
        bytes: &[u8],
        options: LexiconSchemaOptions,
    ) -> Result<(), LexiconCatalogError> {
        let doc = LexiconDoc::from_json_bytes(bytes)?;
        self.add(doc, options)
    }

    /// Recursively load all `.json` Lexicon files under `dir`.
    #[cfg(not(target_arch = "wasm32"))]
    pub fn add_directory(
        &mut self,
        dir: impl AsRef<std::path::Path>,
        options: LexiconSchemaOptions,
    ) -> Result<usize, LexiconCatalogError> {
        let mut paths = Vec::new();
        collect_json_files(dir.as_ref(), &mut paths)?;
        paths.sort();
        let mut added = 0usize;
        for path in paths {
            let bytes = std::fs::read(&path).map_err(|err| LexiconCatalogError::Io {
                path: path.display().to_string(),
                message: err.to_string(),
            })?;
            self.add_json(&bytes, options)?;
            added += 1;
        }
        Ok(added)
    }

    /// Look up a registered [`LexiconDoc`] by NSID.
    pub fn document(&self, nsid: &str) -> Option<&LexiconDoc> {
        self.documents.get(nsid)
    }

    /// Look up a definition `<nsid>#<def_name>`.
    pub fn definition(&self, nsid: &str, def_name: &str) -> Option<&LexiconDefinition> {
        self.documents.get(nsid)?.defs.get(def_name)
    }

    /// Resolve a [`LexiconReference`] relative to `current_nsid`.
    pub fn resolve_reference<'a>(
        &'a self,
        reference: &'a LexiconReference,
        current_nsid: &'a str,
    ) -> Option<(&'a str, &'a str, &'a LexiconDefinition)> {
        let (nsid, def_name) = reference.resolve(current_nsid);
        let def = self.definition(nsid, def_name)?;
        Some((nsid, def_name, def))
    }

    /// Look up `<nsid>#<def_name>`, returning [`LexiconCatalogError::UnknownDefinition`] if missing.
    pub fn require_definition(
        &self,
        nsid: &str,
        def_name: &str,
    ) -> Result<&LexiconDefinition, LexiconCatalogError> {
        self.definition(nsid, def_name)
            .ok_or_else(|| LexiconCatalogError::UnknownDefinition {
                nsid: nsid.to_owned(),
                def_name: def_name.to_owned(),
            })
    }

    /// Look up the optional `parameters` block on an XRPC endpoint (`query`/`procedure`/`subscription`).
    pub fn require_xrpc_parameters(
        &self,
        nsid: &str,
    ) -> Result<Option<&LexXrpcParameters>, LexiconCatalogError> {
        let def = self.require_definition(nsid, "main")?;
        match def {
            LexiconDefinition::Query(q) => Ok(q.parameters.as_ref()),
            LexiconDefinition::Procedure(p) => Ok(p.parameters.as_ref()),
            LexiconDefinition::Subscription(s) => Ok(s.parameters.as_ref()),
            other => Err(LexiconCatalogError::UnexpectedDefinitionKind {
                nsid: nsid.to_owned(),
                def_name: "main".to_owned(),
                expected: "query, procedure, or subscription".to_owned(),
                actual: other.type_name().to_owned(),
            }),
        }
    }

    /// Validate a typed generated record against the schema of `T::NSID`.
    pub fn validate_record<T: Collection + ToValue>(
        &self,
        record: &T,
        record_key: Option<&str>,
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(self, options).validate_typed_record(record, record_key)
    }

    /// Validate a [`petrel_core::Value`] record against `collection#main`.
    pub fn validate_record_value(
        &self,
        collection: &str,
        value: &Value,
        record_key: Option<&str>,
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(self, options).validate_record(collection, value, record_key)
    }

    /// Validate any [`petrel_core::Value`] against `<nsid>#<def_name>`.
    pub fn validate_value(
        &self,
        nsid: &str,
        def_name: &str,
        value: &Value,
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(self, options).validate_definition(nsid, def_name, value)
    }

    /// Validate XRPC query parameters passed as string pairs.
    pub fn validate_xrpc_query_params(
        &self,
        nsid: &str,
        params: &[(&str, &str)],
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(self, options).validate_query_params(nsid, params)
    }

    /// Validate XRPC query parameters passed as a [`petrel_core::Value::Object`].
    pub fn validate_xrpc_params_value(
        &self,
        nsid: &str,
        params: &Value,
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(self, options).validate_params_value(nsid, params)
    }

    /// Validate an XRPC procedure input payload.
    pub fn validate_xrpc_input(
        &self,
        nsid: &str,
        value: &Value,
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(self, options).validate_xrpc_input(nsid, value)
    }

    /// Validate an XRPC query or procedure output payload.
    pub fn validate_xrpc_output(
        &self,
        nsid: &str,
        value: &Value,
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(self, options).validate_xrpc_output(nsid, value)
    }

    /// Validate an XRPC subscription message payload.
    pub fn validate_xrpc_message(
        &self,
        nsid: &str,
        value: &Value,
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(self, options).validate_xrpc_message(nsid, value)
    }

    /// Validate an XRPC subscription message payload with an out-of-band frame type selector `t`.
    pub fn validate_xrpc_message_with_type(
        &self,
        nsid: &str,
        message_type: Option<&str>,
        value: &Value,
        options: LexiconValidationOptions,
    ) -> Result<(), LexiconValidationError> {
        LexiconDataValidator::new(self, options).validate_xrpc_message_with_type(
            nsid,
            message_type,
            value,
        )
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn collect_json_files(
    dir: &std::path::Path,
    out: &mut Vec<std::path::PathBuf>,
) -> Result<(), LexiconCatalogError> {
    let entries = std::fs::read_dir(dir).map_err(|err| LexiconCatalogError::Io {
        path: dir.display().to_string(),
        message: err.to_string(),
    })?;
    for entry in entries {
        let entry = entry.map_err(|err| LexiconCatalogError::Io {
            path: dir.display().to_string(),
            message: err.to_string(),
        })?;
        let path = entry.path();
        if path.is_dir() {
            collect_json_files(&path, out)?;
        } else if path.extension().and_then(|e| e.to_str()) == Some("json") {
            out.push(path);
        }
    }
    Ok(())
}
