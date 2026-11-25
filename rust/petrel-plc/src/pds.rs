use std::collections::BTreeMap;

use http::Method;
use petrel::{
    rt::{BoxFuture, MaybeSend, MaybeSync},
    xrpc::{CallOptions, XrpcBody, XrpcClient},
};
use petrel_api::generated::com::atproto::identity::{
    get_recommended_did_credentials::{self, GetRecommendedDidCredentials},
    request_plc_operation_signature::RequestPlcOperationSignature,
    sign_plc_operation::{self, SignPlcOperation},
    submit_plc_operation::{self, SubmitPlcOperation},
};
use petrel_core::{Value, XrpcRequest as _, from_json, to_json};
use thiserror::Error;

use crate::{
    audit_log::PlcVerifiedAuditLog,
    error::PlcError,
    operation::{PlcOperation, PlcOperationCodec, PlcService},
};

/// The four `com.atproto.identity` procedures offered by an ATProto PDS for PLC updates.
pub trait PlcPdsIdentityApi: MaybeSend + MaybeSync {
    fn get_recommended_did_credentials(
        &self,
    ) -> BoxFuture<
        '_,
        Result<(u16, Option<get_recommended_did_credentials::Output>), PlcPdsFlowError>,
    >;

    fn request_plc_operation_signature(&self) -> BoxFuture<'_, Result<u16, PlcPdsFlowError>>;

    fn sign_plc_operation(
        &self,
        input: sign_plc_operation::Input,
    ) -> BoxFuture<'_, Result<(u16, Option<sign_plc_operation::Output>), PlcPdsFlowError>>;

    fn submit_plc_operation(
        &self,
        input: submit_plc_operation::Input,
    ) -> BoxFuture<'_, Result<u16, PlcPdsFlowError>>;
}

impl PlcPdsIdentityApi for XrpcClient {
    fn get_recommended_did_credentials(
        &self,
    ) -> BoxFuture<
        '_,
        Result<(u16, Option<get_recommended_did_credentials::Output>), PlcPdsFlowError>,
    > {
        Box::pin(async move {
            let resp = self
                .exchange(
                    Method::GET,
                    GetRecommendedDidCredentials::NSID,
                    Vec::<(&str, &str)>::new(),
                    None,
                    &CallOptions::default(),
                )
                .await
                .map_err(|err| PlcPdsFlowError::Transport {
                    procedure: GetRecommendedDidCredentials::NSID.to_owned(),
                    detail: err.to_string(),
                })?;
            let status = resp.status().as_u16();
            if !(200..=299).contains(&status) {
                return Ok((status, None));
            }
            let out: get_recommended_did_credentials::Output = serde_json::from_slice(resp.body())
                .map_err(|err| PlcPdsFlowError::MalformedResponse {
                    procedure: GetRecommendedDidCredentials::NSID.to_owned(),
                    detail: err.to_string(),
                })?;
            Ok((status, Some(out)))
        })
    }

    fn request_plc_operation_signature(&self) -> BoxFuture<'_, Result<u16, PlcPdsFlowError>> {
        Box::pin(async move {
            let resp = self
                .exchange(
                    Method::POST,
                    RequestPlcOperationSignature::NSID,
                    Vec::<(&str, &str)>::new(),
                    None,
                    &CallOptions::default(),
                )
                .await
                .map_err(|err| PlcPdsFlowError::Transport {
                    procedure: RequestPlcOperationSignature::NSID.to_owned(),
                    detail: err.to_string(),
                })?;
            Ok(resp.status().as_u16())
        })
    }

    fn sign_plc_operation(
        &self,
        input: sign_plc_operation::Input,
    ) -> BoxFuture<'_, Result<(u16, Option<sign_plc_operation::Output>), PlcPdsFlowError>> {
        Box::pin(async move {
            let bytes =
                serde_json::to_vec(&input).map_err(|err| PlcPdsFlowError::MalformedResponse {
                    procedure: SignPlcOperation::NSID.to_owned(),
                    detail: err.to_string(),
                })?;
            let body = XrpcBody::json(bytes);
            let resp = self
                .exchange(
                    Method::POST,
                    SignPlcOperation::NSID,
                    Vec::<(&str, &str)>::new(),
                    Some(body),
                    &CallOptions::default(),
                )
                .await
                .map_err(|err| PlcPdsFlowError::Transport {
                    procedure: SignPlcOperation::NSID.to_owned(),
                    detail: err.to_string(),
                })?;
            let status = resp.status().as_u16();
            if !(200..=299).contains(&status) {
                return Ok((status, None));
            }
            let out: sign_plc_operation::Output =
                serde_json::from_slice(resp.body()).map_err(|err| {
                    PlcPdsFlowError::MalformedResponse {
                        procedure: SignPlcOperation::NSID.to_owned(),
                        detail: err.to_string(),
                    }
                })?;
            Ok((status, Some(out)))
        })
    }

    fn submit_plc_operation(
        &self,
        input: submit_plc_operation::Input,
    ) -> BoxFuture<'_, Result<u16, PlcPdsFlowError>> {
        Box::pin(async move {
            let bytes =
                serde_json::to_vec(&input).map_err(|err| PlcPdsFlowError::MalformedResponse {
                    procedure: SubmitPlcOperation::NSID.to_owned(),
                    detail: err.to_string(),
                })?;
            let body = XrpcBody::json(bytes);
            let resp = self
                .exchange(
                    Method::POST,
                    SubmitPlcOperation::NSID,
                    Vec::<(&str, &str)>::new(),
                    Some(body),
                    &CallOptions::default(),
                )
                .await
                .map_err(|err| PlcPdsFlowError::Transport {
                    procedure: SubmitPlcOperation::NSID.to_owned(),
                    detail: err.to_string(),
                })?;
            Ok(resp.status().as_u16())
        })
    }
}

/// Errors produced by the PDS-mediated PLC flow.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum PlcPdsFlowError {
    #[error("{procedure} failed with HTTP {status}")]
    RequestFailed { procedure: String, status: u16 },
    #[error("{procedure} returned a malformed response: {detail}")]
    MalformedResponse { procedure: String, detail: String },
    #[error("{procedure} transport error: {detail}")]
    Transport { procedure: String, detail: String },
}

/// Partial set of PLC operation fields to change (`None` fields remain untouched).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct PlcPdsOperationFields {
    pub rotation_keys: Option<Vec<String>>,
    pub also_known_as: Option<Vec<String>>,
    pub verification_methods: Option<BTreeMap<String, String>>,
    pub services: Option<BTreeMap<String, PlcService>>,
}

/// PDS-mediated PLC rotation/migration flow (`requestPlcOperationSignature` -> `signPlcOperation` -> verify -> `submitPlcOperation`).
#[derive(Debug, Clone)]
pub struct PlcPdsOperationFlow<A> {
    api: A,
}

impl<A: PlcPdsIdentityApi> PlcPdsOperationFlow<A> {
    pub fn new(api: A) -> Self {
        Self { api }
    }

    pub async fn recommended_credentials(&self) -> Result<PlcPdsOperationFields, PlcPdsFlowError> {
        let procedure = GetRecommendedDidCredentials::NSID;
        let (status, output) = self.api.get_recommended_did_credentials().await?;
        if !(200..=299).contains(&status) {
            return Err(PlcPdsFlowError::RequestFailed {
                procedure: procedure.to_owned(),
                status,
            });
        }
        let Some(output) = output else {
            return Err(PlcPdsFlowError::MalformedResponse {
                procedure: procedure.to_owned(),
                detail: "no body".to_owned(),
            });
        };
        let verification_methods = output
            .verification_methods
            .as_ref()
            .map(PlcPdsBridge::verification_methods)
            .transpose()
            .map_err(|err| PlcPdsFlowError::MalformedResponse {
                procedure: procedure.to_owned(),
                detail: err.to_string(),
            })?;
        let services = output
            .services
            .as_ref()
            .map(PlcPdsBridge::services)
            .transpose()
            .map_err(|err| PlcPdsFlowError::MalformedResponse {
                procedure: procedure.to_owned(),
                detail: err.to_string(),
            })?;
        Ok(PlcPdsOperationFields {
            rotation_keys: output.rotation_keys,
            also_known_as: output.also_known_as,
            verification_methods,
            services,
        })
    }

    pub async fn request_signature_token(&self) -> Result<(), PlcPdsFlowError> {
        let status = self.api.request_plc_operation_signature().await?;
        if !(200..=299).contains(&status) {
            return Err(PlcPdsFlowError::RequestFailed {
                procedure: RequestPlcOperationSignature::NSID.to_owned(),
                status,
            });
        }
        Ok(())
    }

    pub async fn sign_operation(
        &self,
        token: &str,
        changes: &PlcPdsOperationFields,
    ) -> Result<PlcOperation, PlcPdsFlowError> {
        let procedure = SignPlcOperation::NSID;
        let input = sign_plc_operation::Input {
            token: Some(token.to_owned()),
            rotation_keys: changes.rotation_keys.clone(),
            also_known_as: changes.also_known_as.clone(),
            verification_methods: changes
                .verification_methods
                .as_ref()
                .map(PlcPdsBridge::value_for_verification_methods),
            services: changes
                .services
                .as_ref()
                .map(PlcPdsBridge::value_for_services),
        };
        let (status, output) = self.api.sign_plc_operation(input).await?;
        if !(200..=299).contains(&status) {
            return Err(PlcPdsFlowError::RequestFailed {
                procedure: procedure.to_owned(),
                status,
            });
        }
        let Some(output) = output else {
            return Err(PlcPdsFlowError::MalformedResponse {
                procedure: procedure.to_owned(),
                detail: "no body".to_owned(),
            });
        };
        PlcPdsBridge::operation_from_value(&output.operation).map_err(|err| {
            PlcPdsFlowError::MalformedResponse {
                procedure: procedure.to_owned(),
                detail: err.to_string(),
            }
        })
    }

    pub async fn submit(&self, operation: &PlcOperation) -> Result<(), PlcPdsFlowError> {
        let procedure = SubmitPlcOperation::NSID;
        let value = PlcPdsBridge::value_for_operation(operation).map_err(|err| {
            PlcPdsFlowError::MalformedResponse {
                procedure: procedure.to_owned(),
                detail: err.to_string(),
            }
        })?;
        let status = self
            .api
            .submit_plc_operation(submit_plc_operation::Input { operation: value })
            .await?;
        if !(200..=299).contains(&status) {
            return Err(PlcPdsFlowError::RequestFailed {
                procedure: procedure.to_owned(),
                status,
            });
        }
        Ok(())
    }
}

impl PlcVerifiedAuditLog {
    /// Verifies that a PDS-signed operation extends the verified log, is a regular
    /// update (never a tombstone), and applies `changes` to the current state with all
    /// untouched fields preserved verbatim.
    pub fn verify_next_operation_applying(
        &self,
        operation: &PlcOperation,
        changes: &PlcPdsOperationFields,
    ) -> Result<usize, PlcError> {
        let signer = self.verify_next_operation(operation)?;
        let (PlcOperation::Regular(_), Some(current), Some(proposed)) = (
            operation,
            self.document_data(),
            operation.document_data(&self.did),
        ) else {
            return Err(PlcError::unauthorized(
                "PLC operation is not an update of the identity",
            ));
        };

        let expected_rotation_keys = changes
            .rotation_keys
            .as_deref()
            .unwrap_or(&current.rotation_keys);
        let expected_also_known_as = changes
            .also_known_as
            .as_deref()
            .unwrap_or(&current.also_known_as);
        let expected_verification_methods = changes
            .verification_methods
            .as_ref()
            .unwrap_or(&current.verification_methods);
        let expected_services = changes.services.as_ref().unwrap_or(&current.services);

        let mut mismatched = Vec::new();
        if proposed.rotation_keys.as_slice() != expected_rotation_keys {
            mismatched.push("rotationKeys");
        }
        if proposed.also_known_as.as_slice() != expected_also_known_as {
            mismatched.push("alsoKnownAs");
        }
        if &proposed.verification_methods != expected_verification_methods {
            mismatched.push("verificationMethods");
        }
        if &proposed.services != expected_services {
            mismatched.push("services");
        }
        if !mismatched.is_empty() {
            return Err(PlcError::unauthorized(format!(
                "PLC operation does not apply the requested changes: {} differ",
                mismatched.join(", ")
            )));
        }
        Ok(signer)
    }
}

/// Conversions between `petrel-plc` types and `petrel_core::Value` used by generated lexicons.
#[derive(Debug, Clone, Copy)]
pub struct PlcPdsBridge;

impl PlcPdsBridge {
    /// Converts a signed operation into a `petrel_core::Value` for `submitPlcOperation`.
    pub fn value_for_operation(operation: &PlcOperation) -> Result<Value, PlcError> {
        let json = operation.canonical_json()?;
        let val = from_json(&json)
            .map_err(|_| PlcError::malformed("PLC operation value is not a valid JSON object"))?;
        Self::validate_plc_value(&val)?;
        Ok(val)
    }

    /// Decodes a `petrel_core::Value` from `signPlcOperation` into a signed `PlcOperation`.
    pub fn operation_from_value(value: &Value) -> Result<PlcOperation, PlcError> {
        Self::validate_plc_value(value)?;
        let json = to_json(value)
            .map_err(|_| PlcError::malformed("PLC operation value is not a JSON object"))?;
        PlcOperationCodec::decode_signed_json(&json)
    }

    /// Encodes a `verificationMethods` map as a `petrel_core::Value`.
    pub fn value_for_verification_methods(methods: &BTreeMap<String, String>) -> Value {
        Value::Object(
            methods
                .iter()
                .map(|(k, v)| (k.clone(), Value::String(v.clone())))
                .collect(),
        )
    }

    /// Encodes a `services` map as a `petrel_core::Value`.
    pub fn value_for_services(services: &BTreeMap<String, PlcService>) -> Value {
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
        )
    }

    /// Decodes a `verificationMethods` map from a `petrel_core::Value`.
    pub fn verification_methods(value: &Value) -> Result<BTreeMap<String, String>, PlcError> {
        let Some(map) = value.as_object() else {
            return Err(PlcError::malformed(
                "PLC verificationMethods value is malformed",
            ));
        };
        let mut out = BTreeMap::new();
        for (k, v) in map {
            let Some(s) = v.as_str() else {
                return Err(PlcError::malformed(
                    "PLC verificationMethods value is malformed",
                ));
            };
            out.insert(k.clone(), s.to_owned());
        }
        Ok(out)
    }

    /// Decodes a `services` map from a `petrel_core::Value`.
    pub fn services(value: &Value) -> Result<BTreeMap<String, PlcService>, PlcError> {
        let Some(map) = value.as_object() else {
            return Err(PlcError::malformed("PLC services value is malformed"));
        };
        let mut out = BTreeMap::new();
        for (k, v) in map {
            let Some(entry) = v.as_object() else {
                return Err(PlcError::malformed("PLC services value is malformed"));
            };
            if entry.len() != 2 {
                return Err(PlcError::malformed("PLC services value is malformed"));
            }
            let Some(kind) = entry.get("type").and_then(Value::as_str) else {
                return Err(PlcError::malformed("PLC services value is malformed"));
            };
            let Some(endpoint) = entry.get("endpoint").and_then(Value::as_str) else {
                return Err(PlcError::malformed("PLC services value is malformed"));
            };
            out.insert(
                k.clone(),
                PlcService {
                    kind: kind.to_owned(),
                    endpoint: endpoint.to_owned(),
                },
            );
        }
        Ok(out)
    }

    fn validate_plc_value(value: &Value) -> Result<(), PlcError> {
        match value {
            Value::Null | Value::String(_) => Ok(()),
            Value::Array(items) => items.iter().try_for_each(Self::validate_plc_value),
            Value::Object(map) => map.values().try_for_each(Self::validate_plc_value),
            _ => Err(PlcError::malformed(
                "PLC operation holds an unsupported lexicon value",
            )),
        }
    }
}
