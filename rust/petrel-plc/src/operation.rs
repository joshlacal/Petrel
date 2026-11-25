use std::collections::{BTreeMap, BTreeSet};

use petrel_core::{Cid, Value, dagcbor};
use petrel_crypto::{
    ATProtoKeyCurve, ATProtoKeypair, ATProtoSignature, ATProtoSignatureVerificationOptions,
    ATProtoSigner, JWTBase64URL, PublicKey,
};
use serde::{Deserialize, Serialize};
use serde_json::Value as Json;
use sha2::{Digest, Sha256};

use crate::{
    at_profile::PlcAtProfile, audit_log::PlcDocumentData, error::PlcError,
    limits::PlcOperationLimits, strict_json::PlcStrictJson,
};

/// One entry of a PLC operation's `services` map.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlcService {
    #[serde(rename = "type")]
    pub kind: String,
    pub endpoint: String,
}

/// An unsigned `plc_operation` that satisfies write-time rules (`PlcOperationLimits::SPECIFICATION`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UnsignedPlcRegularOperation {
    pub rotation_keys: Vec<String>,
    pub verification_methods: BTreeMap<String, String>,
    pub also_known_as: Vec<String>,
    pub services: BTreeMap<String, PlcService>,
    pub prev: Option<String>,
}

impl UnsignedPlcRegularOperation {
    /// Validates all write-time rules and checks the 7,500-byte DAG-CBOR bound.
    pub fn new(
        rotation_keys: Vec<String>,
        verification_methods: BTreeMap<String, String>,
        also_known_as: Vec<String>,
        services: BTreeMap<String, PlcService>,
        prev: Option<String>,
    ) -> Result<Self, PlcError> {
        PlcOperationCodec::validate(
            &rotation_keys,
            &verification_methods,
            &also_known_as,
            &services,
            prev.as_deref(),
            &PlcOperationLimits::SPECIFICATION,
        )?;
        let op = Self {
            rotation_keys,
            verification_methods,
            also_known_as,
            services,
            prev,
        };
        let bytes = PlcOperationCodec::encode_regular_dag_cbor(&op, None);
        if bytes.len() > PlcOperationLimits::SPECIFICATION.maximum_dag_cbor_bytes {
            return Err(PlcError::malformed(
                "PLC operation exceeds 7,500 DAG-CBOR bytes",
            ));
        }
        Ok(op)
    }
}

/// An unsigned `plc_tombstone` deactivating an identity.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UnsignedPlcTombstoneOperation {
    pub prev: String,
}

impl UnsignedPlcTombstoneOperation {
    /// Validates `prev` as a canonical SHA-256 DAG-CBOR CIDv1.
    pub fn new(prev: String) -> Result<Self, PlcError> {
        PlcOperationCodec::validate_previous_cid(&prev)?;
        Ok(Self { prev })
    }
}

/// An unsigned operation ready to sign.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum UnsignedPlcOperation {
    Regular(UnsignedPlcRegularOperation),
    Tombstone(UnsignedPlcTombstoneOperation),
}

impl UnsignedPlcOperation {
    /// Canonical DAG-CBOR bytes covered by a signature (no `sig` field).
    pub fn signing_dag_cbor(&self) -> Vec<u8> {
        PlcOperationCodec::encode_signing_bytes(self)
    }

    /// Predecessor CID, or `None` for a genesis operation.
    pub fn prev(&self) -> Option<&str> {
        match self {
            Self::Regular(op) => op.prev.as_deref(),
            Self::Tombstone(op) => Some(&op.prev),
        }
    }
}

/// Signed `plc_operation`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SignedPlcRegularOperation {
    pub rotation_keys: Vec<String>,
    pub verification_methods: BTreeMap<String, String>,
    pub also_known_as: Vec<String>,
    pub services: BTreeMap<String, PlcService>,
    pub prev: Option<String>,
    pub signature: String,
}

/// Signed `plc_tombstone`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlcTombstone {
    pub prev: String,
    pub signature: String,
}

/// Legacy `create` operation (pre-March 2023 genesis format).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreateOp {
    pub signing_key: String,
    pub recovery_key: String,
    pub handle: String,
    pub service: String,
    pub signature: String,
}

impl CreateOp {
    /// Rotation keys in descending authority (`[recovery_key, signing_key]`).
    pub fn rotation_keys(&self) -> Vec<String> {
        vec![self.recovery_key.clone(), self.signing_key.clone()]
    }

    /// Normalized `verificationMethods` map (`atproto` -> `signing_key`).
    pub fn verification_methods(&self) -> BTreeMap<String, String> {
        let mut map = BTreeMap::new();
        map.insert(
            PlcAtProfile::SIGNING_KEY_ID.to_owned(),
            self.signing_key.clone(),
        );
        map
    }

    /// Normalized `alsoKnownAs` list (`at://<handle>`).
    pub fn also_known_as(&self) -> Vec<String> {
        let uri = if self.handle.starts_with("at://") {
            self.handle.clone()
        } else {
            format!("at://{}", self.handle)
        };
        vec![uri]
    }

    /// Normalized `services` map (`atproto_pds`), prepending `https://` if no scheme is present.
    pub fn services(&self) -> BTreeMap<String, PlcService> {
        let endpoint = if self.service.contains("://") {
            self.service.clone()
        } else {
            format!("https://{}", self.service)
        };
        let mut map = BTreeMap::new();
        map.insert(
            PlcAtProfile::PDS_SERVICE_ID.to_owned(),
            PlcService {
                kind: PlcAtProfile::PDS_SERVICE_TYPE.to_owned(),
                endpoint,
            },
        );
        map
    }

    /// Normalizes a legacy `create` into modern `PlcDocumentData`.
    pub fn normalize(&self, did: &str) -> PlcDocumentData {
        PlcDocumentData {
            did: did.to_owned(),
            rotation_keys: self.rotation_keys(),
            verification_methods: self.verification_methods(),
            also_known_as: self.also_known_as(),
            services: self.services(),
        }
    }
}

/// A signed PLC operation of any of the three supported formats.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PlcOperation {
    Regular(SignedPlcRegularOperation),
    Tombstone(PlcTombstone),
    LegacyCreate(CreateOp),
}

impl PlcOperation {
    pub fn as_regular(&self) -> Option<&SignedPlcRegularOperation> {
        match self {
            Self::Regular(op) => Some(op),
            _ => None,
        }
    }

    pub fn as_legacy_create(&self) -> Option<&CreateOp> {
        match self {
            Self::LegacyCreate(op) => Some(op),
            _ => None,
        }
    }

    pub fn is_tombstone(&self) -> bool {
        matches!(self, Self::Tombstone(_))
    }

    pub fn is_legacy(&self) -> bool {
        matches!(self, Self::LegacyCreate(_))
    }

    pub fn prev(&self) -> Option<&str> {
        match self {
            Self::Regular(op) => op.prev.as_deref(),
            Self::Tombstone(op) => Some(&op.prev),
            Self::LegacyCreate(_) => None,
        }
    }

    pub fn signature(&self) -> &str {
        match self {
            Self::Regular(op) => &op.signature,
            Self::Tombstone(op) => &op.signature,
            Self::LegacyCreate(op) => &op.signature,
        }
    }

    /// Effective rotation keys allowed to sign the next operation, or `None` if tombstoned.
    pub fn rotation_keys(&self) -> Option<Vec<String>> {
        match self {
            Self::Regular(op) => Some(op.rotation_keys.clone()),
            Self::Tombstone(_) => None,
            Self::LegacyCreate(op) => Some(op.rotation_keys()),
        }
    }

    /// Current state established by this operation, or `None` if tombstoned.
    pub fn document_data(&self, did: &str) -> Option<PlcDocumentData> {
        match self {
            Self::Regular(op) => Some(PlcDocumentData {
                did: did.to_owned(),
                rotation_keys: op.rotation_keys.clone(),
                verification_methods: op.verification_methods.clone(),
                also_known_as: op.also_known_as.clone(),
                services: op.services.clone(),
            }),
            Self::Tombstone(_) => None,
            Self::LegacyCreate(op) => Some(op.normalize(did)),
        }
    }

    /// Canonical DAG-CBOR bytes without `sig`.
    pub fn signing_dag_cbor(&self) -> Vec<u8> {
        PlcOperationCodec::encode_dag_cbor(self, false)
    }

    /// Canonical DAG-CBOR bytes including `sig`.
    pub fn canonical_dag_cbor(&self) -> Vec<u8> {
        PlcOperationCodec::encode_dag_cbor(self, true)
    }

    /// Canonical sorted-key JSON bytes (`POST /:did`).
    pub fn canonical_json(&self) -> Result<Vec<u8>, PlcError> {
        PlcOperationCodec::encode_signed_json(self)
    }

    /// CIDv1 (`dag-cbor`, SHA-256) of `canonical_dag_cbor`.
    pub fn cid(&self) -> Cid {
        Cid::for_dag_cbor(&self.canonical_dag_cbor())
    }

    /// Canonical base32 CIDv1 string (`b...`).
    pub fn cid_string(&self) -> Result<String, PlcError> {
        Ok(self.cid().to_string())
    }
}

/// Editable identity state passed to `PlcOperationCodec::update`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlcOperationDraft {
    pub rotation_keys: Vec<String>,
    pub verification_methods: BTreeMap<String, String>,
    pub also_known_as: Vec<String>,
    pub services: BTreeMap<String, PlcService>,
}

impl PlcOperationDraft {
    /// Starts from an existing identity state, dropping duplicate later rotation keys and aliases.
    pub fn from_data(data: &PlcDocumentData) -> Self {
        Self {
            rotation_keys: first_occurrences(&data.rotation_keys),
            verification_methods: data.verification_methods.clone(),
            also_known_as: first_occurrences(&data.also_known_as),
            services: data.services.clone(),
        }
    }

    /// Replaces the first `at://` alias (or inserts at index 0 if none exists).
    pub fn set_handle(&mut self, handle: &str) -> Result<(), PlcError> {
        let uri = PlcAtProfile::handle_uri(handle)?;
        if let Some(slot) = self
            .also_known_as
            .iter_mut()
            .find(|a| a.starts_with("at://"))
        {
            *slot = uri;
        } else {
            self.also_known_as.insert(0, uri);
        }
        Ok(())
    }

    /// Sets the `atproto_pds` service endpoint.
    pub fn set_pds(&mut self, endpoint: &str) -> Result<(), PlcError> {
        let valid_endpoint = PlcAtProfile::pds_endpoint(endpoint)?;
        self.services.insert(
            PlcAtProfile::PDS_SERVICE_ID.to_owned(),
            PlcService {
                kind: PlcAtProfile::PDS_SERVICE_TYPE.to_owned(),
                endpoint: valid_endpoint,
            },
        );
        Ok(())
    }

    /// Sets the `atproto` verification method key (`did:key`).
    pub fn set_atproto_key(&mut self, signing_key: &str) -> Result<(), PlcError> {
        let valid = PlcAtProfile::signing_did_key(signing_key)?;
        self.verification_methods
            .insert(PlcAtProfile::SIGNING_KEY_ID.to_owned(), valid);
        Ok(())
    }
}

/// Encoding, signing, hashing, and verification of PLC operations.
#[derive(Debug, Clone, Copy)]
pub struct PlcOperationCodec;

impl PlcOperationCodec {
    /// Specification write-time maximum DAG-CBOR size.
    pub const MAXIMUM_DAG_CBOR_BYTES: usize =
        PlcOperationLimits::SPECIFICATION.maximum_dag_cbor_bytes;
    /// Maximum JSON payload decoded by `decode_signed_json`.
    pub const MAXIMUM_OPERATION_JSON_BYTES: usize = 64 * 1024;

    /// Signs `operation` with any `ATProtoSigner`, rejecting non-canonical signatures.
    pub async fn sign(
        operation: &UnsignedPlcOperation,
        signer: &dyn ATProtoSigner,
    ) -> Result<PlcOperation, PlcError> {
        let signing_bytes = Self::encode_signing_bytes(operation);
        let sig = signer
            .sign(&signing_bytes)
            .await
            .map_err(|err| PlcError::malformed(err.to_string()))?;
        if !ATProtoSignature::is_canonical(&sig, signer.curve()) {
            return Err(PlcError::malformed(
                "PLC signer returned a signature that is not 64-byte low-S",
            ));
        }
        Self::attach(&sig, operation)
    }

    /// Signs `operation` with an `ATProtoKeypair` and verifies the signature against its public key.
    pub async fn sign_with_keypair(
        operation: &UnsignedPlcOperation,
        keypair: &dyn ATProtoKeypair,
    ) -> Result<PlcOperation, PlcError> {
        let signing_bytes = Self::encode_signing_bytes(operation);
        let sig = keypair
            .sign(&signing_bytes)
            .await
            .map_err(|err| PlcError::malformed(err.to_string()))?;
        if !ATProtoSignature::is_canonical(&sig, keypair.curve()) {
            return Err(PlcError::malformed(
                "PLC signer returned a signature that is not 64-byte low-S",
            ));
        }
        if !keypair.public_key().verify_strict(&sig, &signing_bytes) {
            return Err(PlcError::unauthorized(
                "PLC signer returned a signature that does not verify against its public key",
            ));
        }
        Self::attach(&sig, operation)
    }

    /// Attaches a raw 64-byte compact low-S signature produced over `operation.signing_dag_cbor()`.
    pub fn attach(
        signature: &[u8],
        operation: &UnsignedPlcOperation,
    ) -> Result<PlcOperation, PlcError> {
        if !is_canonical_on_any_curve(signature) {
            return Err(PlcError::malformed(
                "PLC operation signature is not canonical",
            ));
        }
        let encoded = JWTBase64URL::encode(signature);
        let signed = match operation {
            UnsignedPlcOperation::Regular(op) => PlcOperation::Regular(SignedPlcRegularOperation {
                rotation_keys: op.rotation_keys.clone(),
                verification_methods: op.verification_methods.clone(),
                also_known_as: op.also_known_as.clone(),
                services: op.services.clone(),
                prev: op.prev.clone(),
                signature: encoded,
            }),
            UnsignedPlcOperation::Tombstone(op) => PlcOperation::Tombstone(PlcTombstone {
                prev: op.prev.clone(),
                signature: encoded,
            }),
        };
        Self::validate_for_submission(&signed, &PlcOperationLimits::SPECIFICATION)?;
        Ok(signed)
    }

    /// Builds and verifies a regular `prev: None` operation from stored parts.
    pub fn reconstruct_genesis(
        signing_did_key: &str,
        rotation_did_key: &str,
        canonical_handle: &str,
        pds_origin: &str,
        signature: &str,
    ) -> Result<PlcOperation, PlcError> {
        let mut verification_methods = BTreeMap::new();
        verification_methods.insert(
            PlcAtProfile::SIGNING_KEY_ID.to_owned(),
            signing_did_key.to_owned(),
        );
        let mut services = BTreeMap::new();
        services.insert(
            PlcAtProfile::PDS_SERVICE_ID.to_owned(),
            PlcService {
                kind: PlcAtProfile::PDS_SERVICE_TYPE.to_owned(),
                endpoint: pds_origin.to_owned(),
            },
        );
        let unsigned = UnsignedPlcRegularOperation::new(
            vec![rotation_did_key.to_owned()],
            verification_methods,
            vec![format!("at://{canonical_handle}")],
            services,
            None,
        )?;
        let sig_bytes = Self::decode_canonical_signature(signature)?;
        Self::attach(&sig_bytes, &UnsignedPlcOperation::Regular(unsigned))
    }

    /// Derives `did:plc:<24-char-base32(sha256(signed_cbor))>` for a genesis operation.
    pub fn genesis_did(operation: &PlcOperation) -> Result<String, PlcError> {
        if operation.prev().is_some() || operation.is_tombstone() {
            return Err(PlcError::malformed(
                "PLC genesis must be a regular or legacy create operation with null prev",
            ));
        }
        let digest = Sha256::digest(operation.canonical_dag_cbor());
        let b32 = base32_lower_encode(&digest);
        Ok(format!("did:plc:{}", &b32[..24]))
    }

    /// Verifies that `operation` hashes to `expected_did` and carries a valid own-rotation signature.
    pub fn verify_genesis(operation: &PlcOperation, expected_did: &str) -> Result<(), PlcError> {
        Self::validate_canonical_did(expected_did)?;
        let actual = Self::genesis_did(operation)?;
        let Some(keys) = operation.rotation_keys() else {
            return Err(PlcError::unauthorized(
                "PLC genesis DID does not match operation",
            ));
        };
        if actual != expected_did {
            return Err(PlcError::unauthorized(
                "PLC genesis DID does not match operation",
            ));
        }
        let _ = Self::verify(operation, &keys)?;
        Ok(())
    }

    /// Verifies an operation signature against `authorized_rotation_keys`, returning the signer index.
    pub fn verify(
        operation: &PlcOperation,
        authorized_rotation_keys: &[String],
    ) -> Result<usize, PlcError> {
        let (idx, _) = Self::verify_returning_key(operation, authorized_rotation_keys)?;
        Ok(idx)
    }

    pub(crate) fn verify_returning_key(
        operation: &PlcOperation,
        authorized_rotation_keys: &[String],
    ) -> Result<(usize, PublicKey), PlcError> {
        let signature = Self::decode_canonical_signature(operation.signature())?;
        let signing_bytes = operation.signing_dag_cbor();
        for (index, key_text) in authorized_rotation_keys.iter().enumerate() {
            let Ok(key) = PublicKey::from_did_key(key_text) else {
                continue;
            };
            if key.is_valid_signature(
                &signature,
                &signing_bytes,
                ATProtoSignatureVerificationOptions::STRICT,
            ) {
                return Ok((index, key));
            }
        }
        Err(PlcError::unauthorized("PLC operation signature is invalid"))
    }

    // MARK: Update drafts

    /// Prepares the unsigned regular operation following `last`, passing a mutable `PlcOperationDraft` to `mutate`.
    pub fn update<F>(
        last: &PlcOperation,
        mutate: F,
    ) -> Result<UnsignedPlcRegularOperation, PlcError>
    where
        F: FnOnce(&mut PlcOperationDraft) -> Result<(), PlcError>,
    {
        let Some(data) = last.document_data("did:plc:placeholderplaceholder") else {
            return Err(PlcError::malformed(
                "cannot update after a PLC tombstone operation",
            ));
        };
        let mut draft = PlcOperationDraft::from_data(&data);
        mutate(&mut draft)?;
        let prev = last.cid_string()?;
        UnsignedPlcRegularOperation::new(
            draft.rotation_keys,
            draft.verification_methods,
            draft.also_known_as,
            draft.services,
            Some(prev),
        )
    }

    pub fn update_handle(
        last: &PlcOperation,
        handle: &str,
    ) -> Result<UnsignedPlcRegularOperation, PlcError> {
        Self::update(last, |draft| draft.set_handle(handle))
    }

    pub fn update_pds(
        last: &PlcOperation,
        endpoint: &str,
    ) -> Result<UnsignedPlcRegularOperation, PlcError> {
        Self::update(last, |draft| draft.set_pds(endpoint))
    }

    pub fn update_atproto_key(
        last: &PlcOperation,
        signing_key: &str,
    ) -> Result<UnsignedPlcRegularOperation, PlcError> {
        Self::update(last, |draft| draft.set_atproto_key(signing_key))
    }

    pub fn update_rotation_keys(
        last: &PlcOperation,
        rotation_keys: Vec<String>,
    ) -> Result<UnsignedPlcRegularOperation, PlcError> {
        Self::update(last, |draft| {
            draft.rotation_keys = rotation_keys;
            Ok(())
        })
    }

    // MARK: JSON decoding (lenient content, strict structure & canonical sig)

    /// Decodes a signed operation from strict JSON bytes.
    pub fn decode_signed_json(data: &[u8]) -> Result<PlcOperation, PlcError> {
        if data.is_empty() || data.len() > Self::MAXIMUM_OPERATION_JSON_BYTES {
            return Err(PlcError::malformed("PLC operation JSON exceeds its bound"));
        }
        PlcStrictJson::validate(data)?;
        let value: Json = serde_json::from_slice(data)
            .map_err(|_| PlcError::malformed("PLC operation JSON is malformed"))?;
        Self::decode_signed_json_value(&value)
    }

    /// Decodes a signed operation from an already-parsed JSON `Value` (caller must have validated strict JSON).
    pub fn decode_signed_json_value(value: &Json) -> Result<PlcOperation, PlcError> {
        let Some(obj) = value.as_object() else {
            return Err(PlcError::malformed("PLC operation JSON is malformed"));
        };
        let Some(kind) = obj.get("type").and_then(Json::as_str) else {
            return Err(PlcError::malformed("PLC operation JSON is malformed"));
        };

        let op = match kind {
            "plc_operation" => Self::decode_regular_obj(obj)?,
            "plc_tombstone" => Self::decode_tombstone_obj(obj)?,
            "create" => Self::decode_legacy_obj(obj)?,
            _ => return Err(PlcError::malformed("PLC operation type is unsupported")),
        };

        let sig_bytes = Self::decode_canonical_signature(op.signature())?;
        if !is_canonical_on_any_curve(&sig_bytes) {
            return Err(PlcError::malformed(
                "PLC operation signature is not canonical",
            ));
        }
        Ok(op)
    }

    fn decode_regular_obj(obj: &serde_json::Map<String, Json>) -> Result<PlcOperation, PlcError> {
        let expected = [
            "type",
            "rotationKeys",
            "verificationMethods",
            "alsoKnownAs",
            "services",
            "prev",
            "sig",
        ];
        if obj.len() != expected.len() || !expected.iter().all(|k| obj.contains_key(*k)) {
            return Err(PlcError::malformed(
                "PLC regular operation JSON is malformed",
            ));
        }
        let rotation_keys = string_vec(obj.get("rotationKeys"))
            .ok_or_else(|| PlcError::malformed("PLC regular operation JSON is malformed"))?;
        let verification_methods = string_map(obj.get("verificationMethods"))
            .ok_or_else(|| PlcError::malformed("PLC regular operation JSON is malformed"))?;
        let also_known_as = string_vec(obj.get("alsoKnownAs"))
            .ok_or_else(|| PlcError::malformed("PLC regular operation JSON is malformed"))?;
        let raw_services = obj
            .get("services")
            .and_then(Json::as_object)
            .ok_or_else(|| PlcError::malformed("PLC regular operation JSON is malformed"))?;
        let services = Self::decode_services_map(raw_services)?;
        let prev = match obj.get("prev") {
            Some(Json::Null) => None,
            Some(Json::String(s)) => Some(s.clone()),
            _ => return Err(PlcError::malformed("PLC operation prev is malformed")),
        };
        let signature = obj
            .get("sig")
            .and_then(Json::as_str)
            .ok_or_else(|| PlcError::malformed("PLC regular operation JSON is malformed"))?
            .to_owned();

        Ok(PlcOperation::Regular(SignedPlcRegularOperation {
            rotation_keys,
            verification_methods,
            also_known_as,
            services,
            prev,
            signature,
        }))
    }

    fn decode_tombstone_obj(obj: &serde_json::Map<String, Json>) -> Result<PlcOperation, PlcError> {
        if obj.len() != 3
            || !obj.contains_key("type")
            || !obj.contains_key("prev")
            || !obj.contains_key("sig")
        {
            return Err(PlcError::malformed("PLC tombstone JSON is malformed"));
        }
        let prev = obj
            .get("prev")
            .and_then(Json::as_str)
            .ok_or_else(|| PlcError::malformed("PLC tombstone JSON is malformed"))?
            .to_owned();
        let signature = obj
            .get("sig")
            .and_then(Json::as_str)
            .ok_or_else(|| PlcError::malformed("PLC tombstone JSON is malformed"))?
            .to_owned();
        Ok(PlcOperation::Tombstone(PlcTombstone { prev, signature }))
    }

    fn decode_legacy_obj(obj: &serde_json::Map<String, Json>) -> Result<PlcOperation, PlcError> {
        let expected = [
            "type",
            "signingKey",
            "recoveryKey",
            "handle",
            "service",
            "prev",
            "sig",
        ];
        if obj.len() != expected.len() || !expected.iter().all(|k| obj.contains_key(*k)) {
            return Err(PlcError::malformed(
                "PLC legacy create operation JSON is malformed",
            ));
        }
        if !matches!(obj.get("prev"), Some(Json::Null)) {
            return Err(PlcError::malformed(
                "PLC legacy create operation JSON is malformed",
            ));
        }
        let signing_key = obj
            .get("signingKey")
            .and_then(Json::as_str)
            .ok_or_else(|| PlcError::malformed("PLC legacy create operation JSON is malformed"))?
            .to_owned();
        let recovery_key = obj
            .get("recoveryKey")
            .and_then(Json::as_str)
            .ok_or_else(|| PlcError::malformed("PLC legacy create operation JSON is malformed"))?
            .to_owned();
        let handle = obj
            .get("handle")
            .and_then(Json::as_str)
            .ok_or_else(|| PlcError::malformed("PLC legacy create operation JSON is malformed"))?
            .to_owned();
        let service = obj
            .get("service")
            .and_then(Json::as_str)
            .ok_or_else(|| PlcError::malformed("PLC legacy create operation JSON is malformed"))?
            .to_owned();
        let signature = obj
            .get("sig")
            .and_then(Json::as_str)
            .ok_or_else(|| PlcError::malformed("PLC legacy create operation JSON is malformed"))?
            .to_owned();

        Ok(PlcOperation::LegacyCreate(CreateOp {
            signing_key,
            recovery_key,
            handle,
            service,
            signature,
        }))
    }

    pub(crate) fn decode_services_map(
        raw_services: &serde_json::Map<String, Json>,
    ) -> Result<BTreeMap<String, PlcService>, PlcError> {
        let mut out = BTreeMap::new();
        for (name, val) in raw_services {
            let Some(obj) = val.as_object() else {
                return Err(PlcError::malformed("PLC operation service is malformed"));
            };
            if obj.len() != 2 {
                return Err(PlcError::malformed("PLC operation service is malformed"));
            }
            let Some(kind) = obj.get("type").and_then(Json::as_str) else {
                return Err(PlcError::malformed("PLC operation service is malformed"));
            };
            let Some(endpoint) = obj.get("endpoint").and_then(Json::as_str) else {
                return Err(PlcError::malformed("PLC operation service is malformed"));
            };
            out.insert(
                name.clone(),
                PlcService {
                    kind: kind.to_owned(),
                    endpoint: endpoint.to_owned(),
                },
            );
        }
        Ok(out)
    }

    // MARK: Write validation

    /// Applies write rules and DAG-CBOR size limits before signing/submission.
    pub fn validate_for_submission(
        operation: &PlcOperation,
        limits: &PlcOperationLimits,
    ) -> Result<(), PlcError> {
        match operation {
            PlcOperation::Regular(op) => Self::validate(
                &op.rotation_keys,
                &op.verification_methods,
                &op.also_known_as,
                &op.services,
                op.prev.as_deref(),
                limits,
            )?,
            PlcOperation::Tombstone(op) => Self::validate_previous_cid(&op.prev)?,
            PlcOperation::LegacyCreate(_) => {
                return Err(PlcError::malformed(
                    "the legacy create operation format cannot be submitted; build a plc_operation",
                ));
            }
        }
        let sig_bytes = Self::decode_canonical_signature(operation.signature())?;
        if !is_canonical_on_any_curve(&sig_bytes) {
            return Err(PlcError::malformed(
                "PLC operation signature is not canonical",
            ));
        }
        let cbor = Self::encode_dag_cbor(operation, true);
        if cbor.len() > limits.maximum_dag_cbor_bytes {
            return Err(PlcError::malformed(format!(
                "PLC operation exceeds {} DAG-CBOR bytes",
                limits.maximum_dag_cbor_bytes
            )));
        }
        Ok(())
    }

    pub(crate) fn validate(
        rotation_keys: &[String],
        verification_methods: &BTreeMap<String, String>,
        also_known_as: &[String],
        services: &BTreeMap<String, PlcService>,
        prev: Option<&str>,
        limits: &PlcOperationLimits,
    ) -> Result<(), PlcError> {
        let unique_rot: BTreeSet<&str> = rotation_keys.iter().map(String::as_str).collect();
        if rotation_keys.is_empty()
            || rotation_keys.len() > limits.maximum_rotation_keys
            || unique_rot.len() != rotation_keys.len()
        {
            return Err(PlcError::malformed(format!(
                "PLC operation must contain 1...{} unique rotation keys",
                limits.maximum_rotation_keys
            )));
        }
        for key in rotation_keys {
            if key.len() > limits.maximum_did_key_length || PublicKey::from_did_key(key).is_err() {
                return Err(PlcError::invalid_identifier(
                    "PLC rotation key must be a P-256 or K-256 did:key",
                ));
            }
        }
        if verification_methods.len() > limits.maximum_verification_methods {
            return Err(PlcError::malformed(format!(
                "PLC operation may contain at most {} verification methods",
                limits.maximum_verification_methods
            )));
        }
        for (name, value) in verification_methods {
            validate_map_name(name, limits.maximum_identifier_length)?;
            if value.len() > limits.maximum_did_key_length || !Self::is_syntactic_did_key(value) {
                return Err(PlcError::invalid_identifier(
                    "PLC verification method must be a did:key with a base58btc multibase value",
                ));
            }
        }
        if also_known_as.len() > limits.maximum_also_known_as {
            return Err(PlcError::malformed(format!(
                "PLC operation may contain at most {} alsoKnownAs entries",
                limits.maximum_also_known_as
            )));
        }
        if !limits.allows_duplicate_also_known_as {
            let unique_aka: BTreeSet<&str> = also_known_as.iter().map(String::as_str).collect();
            if unique_aka.len() != also_known_as.len() {
                return Err(PlcError::malformed(
                    "PLC operation alsoKnownAs entries must be unique",
                ));
            }
        }
        for alias in also_known_as {
            validate_wire_string(alias, "alsoKnownAs", limits.maximum_also_known_as_length)?;
        }
        if services.len() > limits.maximum_services {
            return Err(PlcError::malformed(format!(
                "PLC operation may contain at most {} services",
                limits.maximum_services
            )));
        }
        for (name, service) in services {
            validate_map_name(name, limits.maximum_identifier_length)?;
            validate_wire_string(
                &service.kind,
                "service type",
                limits.maximum_service_type_length,
            )?;
            validate_wire_string(
                &service.endpoint,
                "service endpoint",
                limits.maximum_service_endpoint_length,
            )?;
        }
        if let Some(prev) = prev {
            Self::validate_previous_cid(prev)?;
        }
        Ok(())
    }

    pub fn validate_previous_cid(value: &str) -> Result<(), PlcError> {
        let Ok(cid) = Cid::parse(value) else {
            return Err(PlcError::invalid_identifier("PLC previous operation CID"));
        };
        if cid.to_string() != value
            || cid.codec() != Cid::CODEC_DAG_CBOR
            || cid.hash_code() != Cid::HASH_SHA2_256
            || cid.digest().len() != 32
        {
            return Err(PlcError::invalid_identifier("PLC previous operation CID"));
        }
        Ok(())
    }

    pub fn validate_canonical_did(did: &str) -> Result<(), PlcError> {
        let Some(rest) = did.strip_prefix("did:plc:") else {
            return Err(PlcError::invalid_identifier("canonical did:plc"));
        };
        if did.len() != 32 || !rest.bytes().all(|b| matches!(b, b'a'..=b'z' | b'2'..=b'7')) {
            return Err(PlcError::invalid_identifier("canonical did:plc"));
        }
        Ok(())
    }

    pub fn is_syntactic_did_key(value: &str) -> bool {
        let Some(body) = value.strip_prefix("did:key:z") else {
            return false;
        };
        !body.is_empty() && body.bytes().all(is_base58btc_byte)
    }

    // MARK: Encoding

    pub fn encode_signing_bytes(operation: &UnsignedPlcOperation) -> Vec<u8> {
        match operation {
            UnsignedPlcOperation::Regular(op) => Self::encode_regular_dag_cbor(op, None),
            UnsignedPlcOperation::Tombstone(op) => tombstone_cbor(&op.prev, None),
        }
    }

    pub fn encode_dag_cbor(operation: &PlcOperation, including_signature: bool) -> Vec<u8> {
        let sig = if including_signature {
            Some(operation.signature())
        } else {
            None
        };
        match operation {
            PlcOperation::Regular(op) => regular_cbor(
                &op.rotation_keys,
                &op.verification_methods,
                &op.also_known_as,
                &op.services,
                op.prev.as_deref(),
                sig,
            ),
            PlcOperation::Tombstone(op) => tombstone_cbor(&op.prev, sig),
            PlcOperation::LegacyCreate(op) => legacy_cbor(op, sig),
        }
    }

    fn encode_regular_dag_cbor(op: &UnsignedPlcRegularOperation, sig: Option<&str>) -> Vec<u8> {
        regular_cbor(
            &op.rotation_keys,
            &op.verification_methods,
            &op.also_known_as,
            &op.services,
            op.prev.as_deref(),
            sig,
        )
    }

    /// Encodes a signed operation to sorted-key JSON bytes (`POST /:did`).
    pub fn encode_signed_json(operation: &PlcOperation) -> Result<Vec<u8>, PlcError> {
        let value = operation_to_core_value(operation);
        serde_json::to_vec(&value).map_err(|err| PlcError::malformed(err.to_string()))
    }

    /// Strictly decodes an unpadded 64-byte base64url signature string.
    pub fn decode_canonical_signature(value: &str) -> Result<Vec<u8>, PlcError> {
        let bytes = JWTBase64URL::decode(value, 64)
            .map_err(|_| PlcError::malformed("PLC operation signature encoding is invalid"))?;
        if bytes.len() != 64 || JWTBase64URL::encode(&bytes) != value {
            return Err(PlcError::malformed(
                "PLC operation signature encoding is invalid",
            ));
        }
        Ok(bytes)
    }
}

fn operation_to_core_value(operation: &PlcOperation) -> Value {
    let mut map = BTreeMap::new();
    match operation {
        PlcOperation::Regular(op) => {
            regular_fields_into(
                &mut map,
                &op.rotation_keys,
                &op.verification_methods,
                &op.also_known_as,
                &op.services,
                op.prev.as_deref(),
                Some(&op.signature),
            );
        }
        PlcOperation::Tombstone(op) => {
            map.insert("type".to_owned(), Value::String("plc_tombstone".to_owned()));
            map.insert("prev".to_owned(), Value::String(op.prev.clone()));
            map.insert("sig".to_owned(), Value::String(op.signature.clone()));
        }
        PlcOperation::LegacyCreate(op) => {
            map.insert("type".to_owned(), Value::String("create".to_owned()));
            map.insert(
                "signingKey".to_owned(),
                Value::String(op.signing_key.clone()),
            );
            map.insert(
                "recoveryKey".to_owned(),
                Value::String(op.recovery_key.clone()),
            );
            map.insert("handle".to_owned(), Value::String(op.handle.clone()));
            map.insert("service".to_owned(), Value::String(op.service.clone()));
            map.insert("prev".to_owned(), Value::Null);
            map.insert("sig".to_owned(), Value::String(op.signature.clone()));
        }
    }
    Value::Object(map)
}

fn regular_cbor(
    rotation_keys: &[String],
    verification_methods: &BTreeMap<String, String>,
    also_known_as: &[String],
    services: &BTreeMap<String, PlcService>,
    prev: Option<&str>,
    signature: Option<&str>,
) -> Vec<u8> {
    let mut map = BTreeMap::new();
    regular_fields_into(
        &mut map,
        rotation_keys,
        verification_methods,
        also_known_as,
        services,
        prev,
        signature,
    );
    dagcbor::encode(&Value::Object(map))
}

fn tombstone_cbor(prev: &str, signature: Option<&str>) -> Vec<u8> {
    let mut map = BTreeMap::new();
    map.insert("type".to_owned(), Value::String("plc_tombstone".to_owned()));
    map.insert("prev".to_owned(), Value::String(prev.to_owned()));
    if let Some(sig) = signature {
        map.insert("sig".to_owned(), Value::String(sig.to_owned()));
    }
    dagcbor::encode(&Value::Object(map))
}

fn legacy_cbor(op: &CreateOp, signature: Option<&str>) -> Vec<u8> {
    let mut map = BTreeMap::new();
    map.insert("type".to_owned(), Value::String("create".to_owned()));
    map.insert(
        "signingKey".to_owned(),
        Value::String(op.signing_key.clone()),
    );
    map.insert(
        "recoveryKey".to_owned(),
        Value::String(op.recovery_key.clone()),
    );
    map.insert("handle".to_owned(), Value::String(op.handle.clone()));
    map.insert("service".to_owned(), Value::String(op.service.clone()));
    map.insert("prev".to_owned(), Value::Null);
    if let Some(sig) = signature {
        map.insert("sig".to_owned(), Value::String(sig.to_owned()));
    }
    dagcbor::encode(&Value::Object(map))
}

fn regular_fields_into(
    map: &mut BTreeMap<String, Value>,
    rotation_keys: &[String],
    verification_methods: &BTreeMap<String, String>,
    also_known_as: &[String],
    services: &BTreeMap<String, PlcService>,
    prev: Option<&str>,
    signature: Option<&str>,
) {
    map.insert("type".to_owned(), Value::String("plc_operation".to_owned()));
    map.insert(
        "rotationKeys".to_owned(),
        Value::Array(rotation_keys.iter().cloned().map(Value::String).collect()),
    );
    map.insert(
        "verificationMethods".to_owned(),
        Value::Object(
            verification_methods
                .iter()
                .map(|(k, v)| (k.clone(), Value::String(v.clone())))
                .collect(),
        ),
    );
    map.insert(
        "alsoKnownAs".to_owned(),
        Value::Array(also_known_as.iter().cloned().map(Value::String).collect()),
    );
    map.insert(
        "services".to_owned(),
        Value::Object(
            services
                .iter()
                .map(|(k, svc)| {
                    let mut entry = BTreeMap::new();
                    entry.insert("type".to_owned(), Value::String(svc.kind.clone()));
                    entry.insert("endpoint".to_owned(), Value::String(svc.endpoint.clone()));
                    (k.clone(), Value::Object(entry))
                })
                .collect(),
        ),
    );
    map.insert(
        "prev".to_owned(),
        match prev {
            Some(cid) => Value::String(cid.to_owned()),
            None => Value::Null,
        },
    );
    if let Some(sig) = signature {
        map.insert("sig".to_owned(), Value::String(sig.to_owned()));
    }
}

fn is_canonical_on_any_curve(sig: &[u8]) -> bool {
    ATProtoSignature::is_canonical(sig, ATProtoKeyCurve::P256)
        || ATProtoSignature::is_canonical(sig, ATProtoKeyCurve::Secp256k1)
}

fn is_base58btc_byte(b: u8) -> bool {
    matches!(b, b'1'..=b'9' | b'A'..=b'H' | b'J'..=b'N' | b'P'..=b'Z' | b'a'..=b'k' | b'm'..=b'z')
}

fn validate_map_name(value: &str, max_len: usize) -> Result<(), PlcError> {
    if value.is_empty()
        || value.len() > max_len
        || !value.bytes().all(|b| (0x21..=0x7e).contains(&b))
    {
        return Err(PlcError::malformed("PLC operation map key is invalid"));
    }
    Ok(())
}

fn validate_wire_string(value: &str, field: &str, max_len: usize) -> Result<(), PlcError> {
    if value.is_empty() || value.len() > max_len || value.chars().any(char::is_control) {
        return Err(PlcError::malformed(format!(
            "PLC operation {field} is invalid: each entry must be 1...{max_len} UTF-8 bytes with no control characters"
        )));
    }
    Ok(())
}

fn string_vec(val: Option<&Json>) -> Option<Vec<String>> {
    let arr = val?.as_array()?;
    arr.iter()
        .map(|item| item.as_str().map(str::to_owned))
        .collect()
}

fn string_map(val: Option<&Json>) -> Option<BTreeMap<String, String>> {
    let obj = val?.as_object()?;
    obj.iter()
        .map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_owned())))
        .collect()
}

fn first_occurrences(values: &[String]) -> Vec<String> {
    let mut seen = BTreeSet::new();
    let mut out = Vec::with_capacity(values.len());
    for value in values {
        if seen.insert(value.as_str()) {
            out.push(value.clone());
        }
    }
    out
}

fn base32_lower_encode(bytes: &[u8]) -> String {
    const ALPHABET: &[u8; 32] = b"abcdefghijklmnopqrstuvwxyz234567";
    let mut out = String::with_capacity((bytes.len() * 8).div_ceil(5));
    let mut buffer: u32 = 0;
    let mut bits: u32 = 0;
    for &b in bytes {
        buffer = (buffer << 8) | u32::from(b);
        bits += 8;
        while bits >= 5 {
            bits -= 5;
            let idx = ((buffer >> bits) & 0x1f) as usize;
            out.push(ALPHABET[idx] as char);
        }
    }
    if bits > 0 {
        let idx = ((buffer << (5 - bits)) & 0x1f) as usize;
        out.push(ALPHABET[idx] as char);
    }
    out
}
