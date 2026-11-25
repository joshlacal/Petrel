use std::collections::BTreeMap;

use petrel_core::cid::BlessedKind;
use petrel_core::{Cid, Did, Value, dagcbor};

use crate::block_store::BlockSource;
use crate::crypto::{CommitSigner, CommitVerifier, RepositorySigningKeyResolver, SigningAlgorithm};
use crate::error::CommitError;
use crate::limits::RepositoryLimits;
use crate::types::{RepositoryReadPolicy, RepositoryTid};

/// Descriptor identifying a signed commit before/during signing (`PublicRepositoryCommitDescriptor`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommitDescriptor {
    pub did: Did,
    pub rev: RepositoryTid,
    pub data_cid: Cid,
    pub prev_cid: Option<Cid>,
}

/// Structurally validated (signature not yet cryptographically verified) v3 commit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StructurallyValidatedSignedCommit {
    pub cid: Cid,
    pub did: Did,
    pub version: i64,
    pub rev: RepositoryTid,
    pub data_cid: Cid,
    pub prev_cid: Option<Cid>,
    pub signature: Vec<u8>,
    pub unsigned_commit_bytes: Vec<u8>,
    pub signed_commit_bytes: Vec<u8>,
}

/// Newly built and signed v3 commit ready for persistence (`PreparedPublicRepositorySignedCommit`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PreparedSignedCommit {
    pub cid: Cid,
    pub did: Did,
    pub version: i64,
    pub rev: RepositoryTid,
    pub data_cid: Cid,
    pub prev_cid: Option<Cid>,
    pub signature: Vec<u8>,
    pub unsigned_commit_bytes: Vec<u8>,
    pub signed_commit_bytes: Vec<u8>,
    pub algorithm: SigningAlgorithm,
}

/// Cryptographically verified v3 commit (`VerifiedPublicRepositorySignedCommit`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedSignedCommit {
    pub cid: Cid,
    pub did: Did,
    pub version: i64,
    pub rev: RepositoryTid,
    pub data_cid: Cid,
    pub prev_cid: Option<Cid>,
    pub signature: Vec<u8>,
    pub unsigned_commit_bytes: Vec<u8>,
    pub signed_commit_bytes: Vec<u8>,
}

impl VerifiedSignedCommit {
    pub fn from_prepared(prepared: &PreparedSignedCommit) -> Self {
        Self {
            cid: prepared.cid.clone(),
            did: prepared.did.clone(),
            version: prepared.version,
            rev: prepared.rev.clone(),
            data_cid: prepared.data_cid.clone(),
            prev_cid: prepared.prev_cid.clone(),
            signature: prepared.signature.clone(),
            unsigned_commit_bytes: prepared.unsigned_commit_bytes.clone(),
            signed_commit_bytes: prepared.signed_commit_bytes.clone(),
        }
    }
}

/// Legacy AT Protocol v2 commit (`LegacyRepositoryCommitV2`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LegacyCommitV2 {
    pub cid: Cid,
    pub did: Did,
    pub version: i64,
    pub rev: Option<String>,
    pub data_cid: Cid,
    pub prev_cid: Option<Cid>,
    pub signature: Vec<u8>,
    pub unsigned_commit_bytes: Vec<u8>,
    pub signed_commit_bytes: Vec<u8>,
}

/// Canonical AT Protocol v3 & legacy v2 commit encoder/decoder/verifier
/// (`PublicRepositoryCommitCodec`).
#[derive(Debug, Clone, Copy, Default)]
pub struct CommitCodec;

impl CommitCodec {
    /// Returns the declared integer `"version"` of a DAG-CBOR commit block.
    pub fn commit_version(bytes: &[u8]) -> Result<i64, CommitError> {
        let value = dagcbor::decode_with(bytes, dagcbor::Limits::REPOSITORY_BLOCK)
            .map_err(|err| CommitError::InvalidCbor(err.to_string()))?;
        let Value::Object(map) = value else {
            return Err(CommitError::InvalidCbor("commit must be a CBOR map".into()));
        };
        match map.get("version") {
            Some(Value::Integer(v)) => Ok(*v),
            _ => Err(CommitError::InvalidField {
                field: "version",
                reason: "missing integer version".into(),
            }),
        }
    }

    /// Encodes canonical unsigned v3 commit DAG-CBOR bytes (map with `did`, `rev`,
    /// `data`, `prev`, `version`).
    pub fn encode_unsigned(descriptor: &CommitDescriptor) -> Result<Vec<u8>, CommitError> {
        let map = build_unsigned_v3_map(descriptor);
        Ok(dagcbor::encode(&Value::Object(map)))
    }

    /// Computes exact signed commit byte length without calling the signer
    /// (`"sig"` key + 64-byte CBOR byte-string header).
    pub fn preflight_signed_commit_byte_count(
        descriptor: &CommitDescriptor,
        limits: &RepositoryLimits,
    ) -> Result<usize, CommitError> {
        let unsigned = Self::encode_unsigned(descriptor)?;
        // Canonical CBOR adds key `"sig"` (1 + 3 = 4 bytes) + bytes(64) (2 + 64 = 66 bytes) = 70 bytes,
        // wait: encoding a dummy 64-byte zero signature computes exact canonical length!
        let mut signed_map = build_unsigned_v3_map(descriptor);
        signed_map.insert("sig".to_owned(), Value::Bytes(vec![0_u8; 64]));
        let exact_len = dagcbor::encode(&Value::Object(signed_map)).len();
        debug_assert!(exact_len > unsigned.len());
        if exact_len > limits.max_single_block_bytes {
            return Err(CommitError::CommitTooLarge {
                len: exact_len,
                limit: limits.max_single_block_bytes,
            });
        }
        Ok(exact_len)
    }

    /// Signs and canonicalizes a v3 repository commit.
    pub async fn prepare(
        descriptor: &CommitDescriptor,
        signer: &dyn CommitSigner,
        limits: &RepositoryLimits,
    ) -> Result<PreparedSignedCommit, CommitError> {
        let _ = Self::preflight_signed_commit_byte_count(descriptor, limits)?;
        let unsigned_commit_bytes = Self::encode_unsigned(descriptor)?;
        let signature = signer.sign(&unsigned_commit_bytes).await?;
        if signature.len() != 64 {
            return Err(CommitError::InvalidSignatureEncoding(format!(
                "signer returned {} bytes (expected 64)",
                signature.len()
            )));
        }

        let mut signed_map = build_unsigned_v3_map(descriptor);
        signed_map.insert("sig".to_owned(), Value::Bytes(signature.clone()));
        let signed_commit_bytes = dagcbor::encode(&Value::Object(signed_map));
        if signed_commit_bytes.len() > limits.max_single_block_bytes {
            return Err(CommitError::CommitTooLarge {
                len: signed_commit_bytes.len(),
                limit: limits.max_single_block_bytes,
            });
        }
        let cid = Cid::for_dag_cbor(&signed_commit_bytes);

        Ok(PreparedSignedCommit {
            cid,
            did: descriptor.did.clone(),
            version: 3,
            rev: descriptor.rev.clone(),
            data_cid: descriptor.data_cid.clone(),
            prev_cid: descriptor.prev_cid.clone(),
            signature,
            unsigned_commit_bytes,
            signed_commit_bytes,
            algorithm: signer.algorithm(),
        })
    }

    /// Structurally validates a v3 signed commit block against `expected_cid`
    /// and `policy` without performing signature verification.
    #[allow(clippy::too_many_lines)]
    pub fn structurally_validate(
        bytes: &[u8],
        expected_cid: Option<&Cid>,
        target_did: Option<&Did>,
        policy: &RepositoryReadPolicy,
    ) -> Result<StructurallyValidatedSignedCommit, CommitError> {
        let computed_cid = Cid::for_dag_cbor(bytes);
        if let Some(cid) = expected_cid {
            if cid.blessed_kind() != Some(BlessedKind::DagCbor) || !cid.matches_content(bytes) {
                return Err(CommitError::InvalidCbor(format!(
                    "commit CID hash mismatch: expected {cid}, got {computed_cid}"
                )));
            }
            if policy.requires_blessed_record_links_in_mst && !cid.is_blessed() {
                return Err(CommitError::UnblessedLink("commit"));
            }
        }

        let value = dagcbor::decode_with(bytes, dagcbor::Limits::REPOSITORY_BLOCK)
            .map_err(|err| CommitError::InvalidCbor(err.to_string()))?;
        let Value::Object(map) = value else {
            return Err(CommitError::InvalidCbor("commit must be a CBOR map".into()));
        };

        for key in map.keys() {
            if !matches!(
                key.as_str(),
                "did" | "version" | "data" | "rev" | "prev" | "sig"
            ) {
                return Err(CommitError::InvalidField {
                    field: "unknown",
                    reason: format!("unexpected commit field {key:?}"),
                });
            }
        }

        let version = match map.get("version") {
            Some(Value::Integer(3)) => 3,
            Some(Value::Integer(other)) => return Err(CommitError::UnsupportedVersion(*other)),
            _ => {
                return Err(CommitError::InvalidField {
                    field: "version",
                    reason: "missing integer version 3".into(),
                });
            }
        };

        let did = match map.get("did") {
            Some(Value::String(s)) => {
                let parsed = Did::parse(s).map_err(|err| CommitError::InvalidField {
                    field: "did",
                    reason: err.to_string(),
                })?;
                if let Some(exp) = target_did
                    && &parsed != exp
                {
                    return Err(CommitError::DidMismatch {
                        expected: exp.as_str().to_owned(),
                        actual: parsed.as_str().to_owned(),
                    });
                }
                parsed
            }
            _ => {
                return Err(CommitError::InvalidField {
                    field: "did",
                    reason: "missing DID string".into(),
                });
            }
        };

        let rev = match map.get("rev") {
            Some(Value::String(s)) => {
                RepositoryTid::parse(s).map_err(|err| CommitError::InvalidField {
                    field: "rev",
                    reason: err.to_string(),
                })?
            }
            _ => {
                return Err(CommitError::InvalidField {
                    field: "rev",
                    reason: "missing TID rev string".into(),
                });
            }
        };

        let data_cid = match map.get("data") {
            Some(Value::Link(cid)) => {
                if policy.requires_blessed_record_links_in_mst && !cid.is_blessed() {
                    return Err(CommitError::UnblessedLink("data"));
                }
                cid.clone()
            }
            _ => {
                return Err(CommitError::InvalidField {
                    field: "data",
                    reason: "missing MST root CID link".into(),
                });
            }
        };

        let prev_cid = match map.get("prev") {
            Some(Value::Null) => None,
            Some(Value::Link(cid)) => {
                if policy.requires_blessed_record_links_in_mst && !cid.is_blessed() {
                    return Err(CommitError::UnblessedLink("prev"));
                }
                Some(cid.clone())
            }
            None => {
                return Err(CommitError::InvalidField {
                    field: "prev",
                    reason: "v3 commit must explicitly include 'prev' (null or link)".into(),
                });
            }
            _ => {
                return Err(CommitError::InvalidField {
                    field: "prev",
                    reason: "'prev' must be null or CID link".into(),
                });
            }
        };

        let signature = match map.get("sig") {
            Some(Value::Bytes(sig)) => {
                if sig.len() != 64 {
                    return Err(CommitError::InvalidSignatureEncoding(format!(
                        "commit 'sig' must be 64 bytes (got {})",
                        sig.len()
                    )));
                }
                sig.clone()
            }
            _ => {
                return Err(CommitError::InvalidField {
                    field: "sig",
                    reason: "missing bytes signature".into(),
                });
            }
        };

        let mut unsigned_map = map.clone();
        unsigned_map.remove("sig");
        let unsigned_commit_bytes = dagcbor::encode(&Value::Object(unsigned_map));

        Ok(StructurallyValidatedSignedCommit {
            cid: expected_cid.cloned().unwrap_or(computed_cid),
            did,
            version,
            rev,
            data_cid,
            prev_cid,
            signature,
            unsigned_commit_bytes,
            signed_commit_bytes: bytes.to_vec(),
        })
    }

    /// Structurally validates and cryptographically verifies a v3 commit block,
    /// refreshing the resolver cache once on signature mismatch to accommodate
    /// key rotation.
    pub async fn verify(
        bytes: &[u8],
        expected_cid: Option<&Cid>,
        target_did: Option<&Did>,
        key_resolver: &dyn RepositorySigningKeyResolver,
        policy: &RepositoryReadPolicy,
    ) -> Result<VerifiedSignedCommit, CommitError> {
        let validated = Self::structurally_validate(bytes, expected_cid, target_did, policy)?;
        verify_with_retry(
            &validated.did,
            &validated.unsigned_commit_bytes,
            &validated.signature,
            key_resolver,
        )
        .await?;

        Ok(VerifiedSignedCommit {
            cid: validated.cid,
            did: validated.did,
            version: validated.version,
            rev: validated.rev,
            data_cid: validated.data_cid,
            prev_cid: validated.prev_cid,
            signature: validated.signature,
            unsigned_commit_bytes: validated.unsigned_commit_bytes,
            signed_commit_bytes: validated.signed_commit_bytes,
        })
    }

    /// Loads commit bytes by CID from `source` and verifies it.
    pub async fn verify_from_store(
        commit_cid: &Cid,
        source: &dyn BlockSource,
        target_did: Option<&Did>,
        key_resolver: &dyn RepositorySigningKeyResolver,
        policy: &RepositoryReadPolicy,
    ) -> Result<VerifiedSignedCommit, CommitError> {
        let bytes = source
            .get_block(commit_cid)
            .await?
            .ok_or_else(|| CommitError::MissingBlock(commit_cid.clone()))?;
        Self::verify(&bytes, Some(commit_cid), target_did, key_resolver, policy).await
    }

    /// Decodes a legacy AT Protocol v2 commit without signature verification.
    #[allow(clippy::too_many_lines)]
    pub fn decode_legacy_v2(
        bytes: &[u8],
        expected_cid: Option<&Cid>,
        target_did: Option<&Did>,
    ) -> Result<LegacyCommitV2, CommitError> {
        let computed_cid = Cid::for_dag_cbor(bytes);
        if let Some(cid) = expected_cid
            && (cid.blessed_kind() != Some(BlessedKind::DagCbor) || !cid.matches_content(bytes))
        {
            return Err(CommitError::InvalidCbor(format!(
                "v2 commit CID hash mismatch: expected {cid}, got {computed_cid}"
            )));
        }

        let value = dagcbor::decode_with(bytes, dagcbor::Limits::REPOSITORY_BLOCK)
            .map_err(|err| CommitError::InvalidCbor(err.to_string()))?;
        let Value::Object(map) = value else {
            return Err(CommitError::InvalidCbor("commit must be a CBOR map".into()));
        };

        let version = match map.get("version") {
            Some(Value::Integer(2)) => 2,
            Some(Value::Integer(other)) => return Err(CommitError::UnsupportedVersion(*other)),
            _ => {
                return Err(CommitError::InvalidField {
                    field: "version",
                    reason: "missing integer version 2".into(),
                });
            }
        };

        let did = match map.get("did") {
            Some(Value::String(s)) => {
                let parsed = Did::parse(s).map_err(|err| CommitError::InvalidField {
                    field: "did",
                    reason: err.to_string(),
                })?;
                if let Some(exp) = target_did
                    && &parsed != exp
                {
                    return Err(CommitError::DidMismatch {
                        expected: exp.as_str().to_owned(),
                        actual: parsed.as_str().to_owned(),
                    });
                }
                parsed
            }
            _ => {
                return Err(CommitError::InvalidField {
                    field: "did",
                    reason: "missing DID string".into(),
                });
            }
        };

        let rev = match map.get("rev") {
            Some(Value::String(s)) => Some(s.clone()),
            None | Some(Value::Null) => None,
            _ => {
                return Err(CommitError::InvalidField {
                    field: "rev",
                    reason: "v2 rev must be string or null".into(),
                });
            }
        };

        let data_cid = match map.get("data") {
            Some(Value::Link(cid)) => cid.clone(),
            _ => {
                return Err(CommitError::InvalidField {
                    field: "data",
                    reason: "missing MST data link".into(),
                });
            }
        };

        let prev_cid = match map.get("prev") {
            Some(Value::Link(cid)) => Some(cid.clone()),
            Some(Value::Null) | None => None,
            _ => {
                return Err(CommitError::InvalidField {
                    field: "prev",
                    reason: "v2 prev must be link or null".into(),
                });
            }
        };

        let signature = match map.get("sig") {
            Some(Value::Bytes(sig)) if sig.len() == 64 => sig.clone(),
            Some(Value::Bytes(sig)) => {
                return Err(CommitError::InvalidSignatureEncoding(format!(
                    "commit 'sig' must be 64 bytes (got {})",
                    sig.len()
                )));
            }
            _ => {
                return Err(CommitError::InvalidField {
                    field: "sig",
                    reason: "missing signature bytes".into(),
                });
            }
        };

        let mut unsigned_map = map.clone();
        unsigned_map.remove("sig");
        let unsigned_commit_bytes = dagcbor::encode(&Value::Object(unsigned_map));

        Ok(LegacyCommitV2 {
            cid: expected_cid.cloned().unwrap_or(computed_cid),
            did,
            version,
            rev,
            data_cid,
            prev_cid,
            signature,
            unsigned_commit_bytes,
            signed_commit_bytes: bytes.to_vec(),
        })
    }

    /// Decodes and verifies a legacy v2 commit against `key_resolver` (or fixed `verifier`).
    pub async fn verify_legacy_v2(
        bytes: &[u8],
        expected_cid: Option<&Cid>,
        target_did: Option<&Did>,
        key_resolver: &dyn RepositorySigningKeyResolver,
    ) -> Result<LegacyCommitV2, CommitError> {
        let decoded = Self::decode_legacy_v2(bytes, expected_cid, target_did)?;
        verify_with_retry(
            &decoded.did,
            &decoded.unsigned_commit_bytes,
            &decoded.signature,
            key_resolver,
        )
        .await?;
        Ok(decoded)
    }

    /// Verifies a commit using a known verifier without DID resolution.
    pub async fn verify_with_verifier(
        bytes: &[u8],
        expected_cid: Option<&Cid>,
        target_did: Option<&Did>,
        verifier: &dyn CommitVerifier,
        policy: &RepositoryReadPolicy,
    ) -> Result<VerifiedSignedCommit, CommitError> {
        let validated = Self::structurally_validate(bytes, expected_cid, target_did, policy)?;
        verifier
            .verify(&validated.unsigned_commit_bytes, &validated.signature)
            .await?;
        Ok(VerifiedSignedCommit {
            cid: validated.cid,
            did: validated.did,
            version: validated.version,
            rev: validated.rev,
            data_cid: validated.data_cid,
            prev_cid: validated.prev_cid,
            signature: validated.signature,
            unsigned_commit_bytes: validated.unsigned_commit_bytes,
            signed_commit_bytes: validated.signed_commit_bytes,
        })
    }
}

fn build_unsigned_v3_map(descriptor: &CommitDescriptor) -> BTreeMap<String, Value> {
    let mut map = BTreeMap::new();
    map.insert(
        "did".to_owned(),
        Value::String(descriptor.did.as_str().to_owned()),
    );
    map.insert(
        "rev".to_owned(),
        Value::String(descriptor.rev.as_str().to_owned()),
    );
    map.insert("data".to_owned(), Value::Link(descriptor.data_cid.clone()));
    map.insert(
        "prev".to_owned(),
        match &descriptor.prev_cid {
            Some(cid) => Value::Link(cid.clone()),
            None => Value::Null,
        },
    );
    map.insert("version".to_owned(), Value::Integer(3));
    map
}

async fn verify_with_retry(
    did: &Did,
    unsigned_commit_bytes: &[u8],
    signature: &[u8],
    key_resolver: &dyn RepositorySigningKeyResolver,
) -> Result<(), CommitError> {
    let verifier = key_resolver.resolve_signing_key(did, false).await?;
    match verifier.verify(unsigned_commit_bytes, signature).await {
        Ok(()) => Ok(()),
        Err(CommitError::InvalidSignature) => {
            let refreshed = key_resolver.resolve_signing_key(did, true).await?;
            refreshed.verify(unsigned_commit_bytes, signature).await
        }
        Err(other) => Err(other),
    }
}
