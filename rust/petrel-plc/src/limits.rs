/// Write-time limits enforced when building, signing, or submitting PLC operations.
///
/// Operations read from a directory are not held to these limits so historical
/// operations remain readable.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PlcOperationLimits {
    /// Largest signed operation, in DAG-CBOR bytes.
    pub maximum_dag_cbor_bytes: usize,
    /// Most rotation keys (at least 1 always required; keys must be distinct).
    pub maximum_rotation_keys: usize,
    /// Most `verificationMethods` entries.
    pub maximum_verification_methods: usize,
    /// Most `alsoKnownAs` entries.
    pub maximum_also_known_as: usize,
    /// Longest `alsoKnownAs` entry in UTF-8 bytes.
    pub maximum_also_known_as_length: usize,
    /// Whether `alsoKnownAs` may repeat a value.
    pub allows_duplicate_also_known_as: bool,
    /// Most `services` entries.
    pub maximum_services: usize,
    /// Longest verification method id or service id in UTF-8 bytes.
    pub maximum_identifier_length: usize,
    /// Longest service `type` in UTF-8 bytes.
    pub maximum_service_type_length: usize,
    /// Longest service `endpoint` in UTF-8 bytes.
    pub maximum_service_endpoint_length: usize,
    /// Longest `did:key` string in UTF-8 bytes.
    pub maximum_did_key_length: usize,
}

impl PlcOperationLimits {
    /// The `did:plc` specification (v0.3.0) write limits.
    pub const SPECIFICATION: Self = Self {
        maximum_dag_cbor_bytes: 7_500,
        maximum_rotation_keys: 5,
        maximum_verification_methods: 10,
        maximum_also_known_as: 32,
        maximum_also_known_as_length: 2_048,
        allows_duplicate_also_known_as: true,
        maximum_services: 32,
        maximum_identifier_length: 128,
        maximum_service_type_length: 2_048,
        maximum_service_endpoint_length: 2_048,
        maximum_did_key_length: 256,
    };

    /// Tighter limits enforced by the reference `did-method-plc` server.
    pub const REFERENCE_DIRECTORY: Self = Self {
        maximum_dag_cbor_bytes: 4_000,
        maximum_rotation_keys: 5,
        maximum_verification_methods: 10,
        maximum_also_known_as: 10,
        maximum_also_known_as_length: 258,
        allows_duplicate_also_known_as: false,
        maximum_services: 10,
        maximum_identifier_length: 32,
        maximum_service_type_length: 256,
        maximum_service_endpoint_length: 512,
        maximum_did_key_length: 256,
    };
}

impl Default for PlcOperationLimits {
    fn default() -> Self {
        Self::SPECIFICATION
    }
}
