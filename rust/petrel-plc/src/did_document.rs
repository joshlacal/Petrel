use petrel_crypto::{ATProtoKeyCurve, PublicKey};
use serde::{Deserialize, Serialize};

use crate::{at_profile::PlcAtProfile, audit_log::PlcDocumentData};

/// One `verificationMethod` entry in a rendered PLC DID document.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlcVerificationMethod {
    pub id: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub controller: String,
    pub public_key_multibase: String,
}

/// One `service` entry in a rendered PLC DID document.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlcDidService {
    pub id: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub service_endpoint: String,
}

/// W3C DID document rendered for a `did:plc` identity (`GET /:did`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlcDidDocument {
    #[serde(rename = "@context")]
    pub context: Vec<String>,
    pub id: String,
    pub also_known_as: Vec<String>,
    pub verification_method: Vec<PlcVerificationMethod>,
    pub service: Vec<PlcDidService>,
}

impl PlcDidDocument {
    /// Deterministically renders the DID document for verified identity state (`formatDidDoc`).
    pub fn from_data(data: &PlcDocumentData) -> Self {
        let mut context = vec![
            "https://www.w3.org/ns/did/v1".to_owned(),
            "https://w3id.org/security/multikey/v1".to_owned(),
        ];
        let mut verification_method = Vec::with_capacity(data.verification_methods.len());
        for (key_id, did_key) in &data.verification_methods {
            if let Ok(pub_key) = PublicKey::from_did_key(did_key) {
                let suite = match pub_key.curve() {
                    ATProtoKeyCurve::P256 => "https://w3id.org/security/suites/ecdsa-2019/v1",
                    ATProtoKeyCurve::Secp256k1 => {
                        "https://w3id.org/security/suites/secp256k1-2019/v1"
                    }
                };
                if !context.iter().any(|c| c == suite) {
                    context.push(suite.to_owned());
                }
            }
            let multibase = did_key
                .strip_prefix("did:key:")
                .unwrap_or(did_key)
                .to_owned();
            verification_method.push(PlcVerificationMethod {
                id: format!("{}#{key_id}", data.did),
                kind: "Multikey".to_owned(),
                controller: data.did.clone(),
                public_key_multibase: multibase,
            });
        }
        let service = data
            .services
            .iter()
            .map(|(service_id, svc)| PlcDidService {
                id: format!("#{service_id}"),
                kind: svc.kind.clone(),
                service_endpoint: svc.endpoint.clone(),
            })
            .collect();

        Self {
            context,
            id: data.did.clone(),
            also_known_as: data.also_known_as.clone(),
            verification_method,
            service,
        }
    }

    /// First `at://` handle without its prefix.
    pub fn handle(&self) -> Option<&str> {
        self.also_known_as
            .iter()
            .find_map(|alias| alias.strip_prefix("at://"))
    }

    /// Endpoint of the `#atproto_pds` service when its type is `AtprotoPersonalDataServer`.
    pub fn pds_endpoint(&self) -> Option<&str> {
        let full_id = format!("{}#{}", self.id, PlcAtProfile::PDS_SERVICE_ID);
        let short_id = format!("#{}", PlcAtProfile::PDS_SERVICE_ID);
        self.service
            .iter()
            .find(|svc| {
                (svc.id == short_id || svc.id == full_id)
                    && svc.kind == PlcAtProfile::PDS_SERVICE_TYPE
            })
            .map(|svc| svc.service_endpoint.as_str())
    }
}
