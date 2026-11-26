use petrel_crypto::StrictJSON;

use crate::error::PlcError;

/// Structural JSON validation applied before deserializing PLC payloads:
/// rejects duplicate keys, trailing data, invalid escapes, and nesting > 64 levels.
#[derive(Debug, Clone, Copy)]
pub struct PlcStrictJson;

impl PlcStrictJson {
    /// Maximum allowed JSON object/array nesting depth.
    pub const MAXIMUM_NESTING_DEPTH: usize = 64;

    /// Validates `data` strictly before parsing.
    pub fn validate(data: &[u8]) -> Result<(), PlcError> {
        StrictJSON::validate(data).map_err(|err| PlcError::Malformed(err.to_string()))
    }
}
