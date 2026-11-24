//! OAuth protected-resource and authorization-server metadata validation.

use serde::{Deserialize, Serialize};
use url::Url;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ClientAuthenticationMethod {
    Public,
    PrivateKeyJwt,
}

impl ClientAuthenticationMethod {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Public => "none",
            Self::PrivateKeyJwt => "private_key_jwt",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MetadataDocument {
    ProtectedResource,
    AuthorizationServer,
}

impl MetadataDocument {
    pub fn name(self) -> &'static str {
        match self {
            Self::ProtectedResource => "oauth-protected-resource",
            Self::AuthorizationServer => "oauth-authorization-server",
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, thiserror::Error)]
pub enum MetadataError {
    #[error("expected a canonical HTTPS or loopback HTTP origin")]
    InvalidOrigin,
    #[error("metadata issuer differs from the discovery origin")]
    IssuerMismatch,
    #[error("metadata resource differs from the discovery origin")]
    ResourceMismatch,
    #[error("protected resource metadata names {0} authorization servers, expected one")]
    AuthorizationServerCount(usize),
    #[error("invalid or missing OAuth endpoint: {0}")]
    InvalidEndpoint(&'static str),
    #[error("metadata field {field} is missing required value {value}")]
    MissingValue {
        field: &'static str,
        value: &'static str,
    },
    #[error("metadata field {field} contains forbidden value {value}")]
    ForbiddenValue {
        field: &'static str,
        value: &'static str,
    },
    #[error("metadata does not declare required capability {0}")]
    RequirementNotMet(&'static str),
    #[error("authorization server does not claim the protected resource")]
    ResourceNotProtected,
    #[error("{document:?} metadata returned HTTP {status}, expected 200")]
    UnexpectedStatus {
        document: MetadataDocument,
        status: u16,
    },
    #[error("{0:?} metadata was not served as application/json")]
    ContentType(MetadataDocument),
    #[error("{0:?} metadata document is malformed")]
    MalformedDocument(MetadataDocument),
    #[error("{0:?} metadata request failed")]
    Transport(MetadataDocument),
}

pub(super) fn endpoint_url(input: &str) -> Option<Url> {
    // Reject URL spellings that the parser would repair, including empty userinfo.
    if input
        .bytes()
        .any(|b| b.is_ascii_control() || matches!(b, b' ' | b'\\'))
    {
        return None;
    }
    let (_, rest) = input.split_once("://")?;
    let authority = rest.split(['/', '?', '#']).next()?;
    if authority.is_empty() || authority.contains('@') {
        return None;
    }
    let url = Url::parse(input).ok()?;
    origin(&url, false)?;
    Some(url)
}

pub(super) fn origin(url: &Url, allow_fragment: bool) -> Option<String> {
    let host = url.host_str()?;
    if !url.username().is_empty()
        || url.password().is_some()
        || (!allow_fragment && url.fragment().is_some())
    {
        return None;
    }
    match url.scheme() {
        "https" => {}
        "http" if matches!(host, "localhost" | "127.0.0.1" | "[::1]") => {}
        _ => return None,
    }
    Some(url.origin().ascii_serialization())
}

pub(super) fn require_canonical_origin(input: &str) -> Result<Url, MetadataError> {
    let url = endpoint_url(input).ok_or(MetadataError::InvalidOrigin)?;
    if url.origin().ascii_serialization() != input {
        return Err(MetadataError::InvalidOrigin);
    }
    Ok(url)
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct ProtectedResourceMetadata {
    pub resource: String,
    pub authorization_servers: Vec<String>,
}

impl ProtectedResourceMetadata {
    pub fn validate(&self, resource_origin: &str) -> Result<&str, MetadataError> {
        require_canonical_origin(resource_origin)?;
        if self.resource != resource_origin {
            return Err(MetadataError::ResourceMismatch);
        }
        let [issuer] = self.authorization_servers.as_slice() else {
            return Err(MetadataError::AuthorizationServerCount(
                self.authorization_servers.len(),
            ));
        };
        require_canonical_origin(issuer)?;
        Ok(issuer)
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct AuthorizationServerMetadata {
    pub issuer: String,
    pub authorization_endpoint: Option<String>,
    pub token_endpoint: Option<String>,
    pub pushed_authorization_request_endpoint: Option<String>,
    pub revocation_endpoint: Option<String>,
    #[serde(default)]
    pub response_types_supported: Vec<String>,
    #[serde(default)]
    pub grant_types_supported: Vec<String>,
    #[serde(default)]
    pub code_challenge_methods_supported: Vec<String>,
    #[serde(default)]
    pub token_endpoint_auth_methods_supported: Vec<String>,
    #[serde(default)]
    pub token_endpoint_auth_signing_alg_values_supported: Vec<String>,
    #[serde(default)]
    pub scopes_supported: Vec<String>,
    #[serde(default)]
    pub dpop_signing_alg_values_supported: Vec<String>,
    pub authorization_response_iss_parameter_supported: Option<bool>,
    pub require_pushed_authorization_requests: Option<bool>,
    pub client_id_metadata_document_supported: Option<bool>,
    pub require_request_uri_registration: Option<bool>,
    pub protected_resources: Option<Vec<String>>,
}

/// OAuth endpoints validated against the expected issuer and active client authentication.
#[derive(Clone, Debug)]
pub struct ValidatedAuthorizationServer {
    pub(super) metadata: AuthorizationServerMetadata,
    pub(super) authorization_endpoint: Url,
    pub(super) token_endpoint: Url,
    pub(super) par_endpoint: Url,
    pub(super) revocation_endpoint: Option<Url>,
}

impl ValidatedAuthorizationServer {
    pub fn issuer(&self) -> &str {
        &self.metadata.issuer
    }

    pub fn metadata(&self) -> &AuthorizationServerMetadata {
        &self.metadata
    }

    pub fn authorization_endpoint(&self) -> &Url {
        &self.authorization_endpoint
    }

    pub fn validates_resource(&self, resource_origin: &str) -> Result<(), MetadataError> {
        require_canonical_origin(resource_origin)?;
        if let Some(protected) = &self.metadata.protected_resources
            && !protected.iter().any(|item| item == resource_origin)
        {
            return Err(MetadataError::ResourceNotProtected);
        }
        Ok(())
    }
}

impl AuthorizationServerMetadata {
    pub fn validate(
        self,
        expected_issuer: &str,
        client_auth: ClientAuthenticationMethod,
    ) -> Result<ValidatedAuthorizationServer, MetadataError> {
        let issuer_url = require_canonical_origin(&self.issuer)?;
        if self.issuer != expected_issuer {
            return Err(MetadataError::IssuerMismatch);
        }
        let endpoint = |value: Option<&str>, name| {
            value
                .and_then(endpoint_url)
                // A remote issuer cannot delegate an endpoint to the local machine.
                .filter(|url| !is_loopback(url) || is_loopback(&issuer_url))
                .ok_or(MetadataError::InvalidEndpoint(name))
        };
        let authorization_endpoint = endpoint(
            self.authorization_endpoint.as_deref(),
            "authorization_endpoint",
        )?;
        let token_endpoint = endpoint(self.token_endpoint.as_deref(), "token_endpoint")?;
        let par_endpoint = endpoint(
            self.pushed_authorization_request_endpoint.as_deref(),
            "pushed_authorization_request_endpoint",
        )?;
        let revocation_endpoint = self
            .revocation_endpoint
            .as_deref()
            .map(|url| endpoint(Some(url), "revocation_endpoint"))
            .transpose()?;

        self.validate_capabilities(client_auth)?;

        Ok(ValidatedAuthorizationServer {
            metadata: self,
            authorization_endpoint,
            token_endpoint,
            par_endpoint,
            revocation_endpoint,
        })
    }

    fn validate_capabilities(
        &self,
        client_auth: ClientAuthenticationMethod,
    ) -> Result<(), MetadataError> {
        let require = |items: &[String], field, value| {
            if items.iter().any(|item| item == value) {
                Ok(())
            } else {
                Err(MetadataError::MissingValue { field, value })
            }
        };
        require(
            &self.response_types_supported,
            "response_types_supported",
            "code",
        )?;
        require(
            &self.grant_types_supported,
            "grant_types_supported",
            "authorization_code",
        )?;
        require(
            &self.grant_types_supported,
            "grant_types_supported",
            "refresh_token",
        )?;
        require(
            &self.code_challenge_methods_supported,
            "code_challenge_methods_supported",
            "S256",
        )?;
        require(
            &self.token_endpoint_auth_methods_supported,
            "token_endpoint_auth_methods_supported",
            client_auth.as_str(),
        )?;
        let algorithms = &self.token_endpoint_auth_signing_alg_values_supported;
        let field = "token_endpoint_auth_signing_alg_values_supported";
        if algorithms.iter().any(|algorithm| algorithm == "none") {
            return Err(MetadataError::ForbiddenValue {
                field,
                value: "none",
            });
        }
        if client_auth == ClientAuthenticationMethod::PrivateKeyJwt {
            require(algorithms, field, "ES256")?;
        }
        require(&self.scopes_supported, "scopes_supported", "atproto")?;
        require(
            &self.dpop_signing_alg_values_supported,
            "dpop_signing_alg_values_supported",
            "ES256",
        )?;
        for (flag, field) in [
            (
                self.authorization_response_iss_parameter_supported == Some(true),
                "authorization_response_iss_parameter_supported",
            ),
            (
                self.require_pushed_authorization_requests == Some(true),
                "require_pushed_authorization_requests",
            ),
            (
                self.client_id_metadata_document_supported == Some(true),
                "client_id_metadata_document_supported",
            ),
            (
                self.require_request_uri_registration != Some(false),
                "require_request_uri_registration",
            ),
        ] {
            if !flag {
                return Err(MetadataError::RequirementNotMet(field));
            }
        }

        Ok(())
    }
}

pub(super) fn is_loopback(url: &Url) -> bool {
    matches!(url.host_str(), Some("localhost" | "127.0.0.1" | "[::1]"))
}

#[cfg(test)]
pub(super) fn example_metadata(issuer: &str) -> AuthorizationServerMetadata {
    serde_json::from_value(serde_json::json!({
        "issuer": issuer,
        "authorization_endpoint": format!("{issuer}/authorize"),
        "token_endpoint": format!("{issuer}/token"),
        "pushed_authorization_request_endpoint": format!("{issuer}/par"),
        "revocation_endpoint": format!("{issuer}/revoke"),
        "response_types_supported": ["code"],
        "grant_types_supported": ["authorization_code", "refresh_token"],
        "code_challenge_methods_supported": ["S256"],
        "token_endpoint_auth_methods_supported": ["none", "private_key_jwt"],
        "token_endpoint_auth_signing_alg_values_supported": ["ES256"],
        "scopes_supported": ["atproto"],
        "dpop_signing_alg_values_supported": ["ES256"],
        "authorization_response_iss_parameter_supported": true,
        "require_pushed_authorization_requests": true,
        "client_id_metadata_document_supported": true
    }))
    .unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;

    const ISSUER: &str = "https://issuer.example";

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn strict_origin() {
        for origin in [
            ISSUER,
            "https://issuer.example:8443",
            "http://localhost:9000",
            "http://127.0.0.1",
            "http://[::1]:8900",
        ] {
            assert!(require_canonical_origin(origin).is_ok(), "{origin}");
        }
        for origin in [
            "https://issuer.example/",
            "https://issuer.example:443",
            "HTTPS://issuer.example",
            "https://ISSUER.example",
            "https://user@issuer.example",
            "https://@issuer.example",
            "https://issuer.example?x",
            "https://issuer.example#f",
            "http://issuer.example",
            "http://127.1",
            "https:///issuer.example",
        ] {
            assert!(require_canonical_origin(origin).is_err(), "{origin}");
        }
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn protected_resource_binds_exactly_one_canonical_issuer() {
        let mut document = ProtectedResourceMetadata {
            resource: "https://pds.example".into(),
            authorization_servers: vec![ISSUER.into()],
        };
        assert_eq!(document.validate("https://pds.example"), Ok(ISSUER));
        assert_eq!(
            document.validate("https://different.example"),
            Err(MetadataError::ResourceMismatch)
        );
        document
            .authorization_servers
            .push("https://another.example".into());
        assert_eq!(
            document.validate("https://pds.example"),
            Err(MetadataError::AuthorizationServerCount(2))
        );
        document.authorization_servers.clear();
        assert_eq!(
            document.validate("https://pds.example"),
            Err(MetadataError::AuthorizationServerCount(0))
        );
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn authorization_metadata_checks_required_features() {
        let metadata = example_metadata(ISSUER);
        for mode in [
            ClientAuthenticationMethod::Public,
            ClientAuthenticationMethod::PrivateKeyJwt,
        ] {
            assert!(metadata.clone().validate(ISSUER, mode).is_ok());
        }

        let required = [
            "authorization_endpoint",
            "token_endpoint",
            "pushed_authorization_request_endpoint",
            "response_types_supported",
            "grant_types_supported",
            "code_challenge_methods_supported",
            "token_endpoint_auth_methods_supported",
            "token_endpoint_auth_signing_alg_values_supported",
            "scopes_supported",
            "dpop_signing_alg_values_supported",
            "authorization_response_iss_parameter_supported",
            "require_pushed_authorization_requests",
            "client_id_metadata_document_supported",
        ];
        for field in required {
            let mut value = serde_json::to_value(&metadata).unwrap();
            value.as_object_mut().unwrap().remove(field);
            let document: AuthorizationServerMetadata = serde_json::from_value(value).unwrap();
            assert!(
                document
                    .validate(ISSUER, ClientAuthenticationMethod::PrivateKeyJwt)
                    .is_err(),
                "{field}"
            );
        }
        let mut metadata = metadata;
        metadata.require_request_uri_registration = Some(false);
        assert!(matches!(
            metadata
                .clone()
                .validate(ISSUER, ClientAuthenticationMethod::Public),
            Err(MetadataError::RequirementNotMet(_))
        ));
        metadata.require_request_uri_registration = None;
        metadata
            .token_endpoint_auth_signing_alg_values_supported
            .push("none".into());
        assert!(matches!(
            metadata.validate(ISSUER, ClientAuthenticationMethod::Public),
            Err(MetadataError::ForbiddenValue { .. })
        ));
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn authorization_metadata_rejects_wrong_issuer_and_invalid_endpoints() {
        let metadata = example_metadata(ISSUER);
        assert!(matches!(
            metadata
                .clone()
                .validate("https://other.example", ClientAuthenticationMethod::Public),
            Err(MetadataError::IssuerMismatch)
        ));
        for endpoint in [
            "http://issuer.example/token",
            "http://localhost:3456/token",
            "https://me@issuer.example/token",
            "https://issuer.example/token#unexpected",
        ] {
            let mut document = metadata.clone();
            document.token_endpoint = Some(endpoint.into());
            assert!(matches!(
                document.validate(ISSUER, ClientAuthenticationMethod::Public),
                Err(MetadataError::InvalidEndpoint("token_endpoint"))
            ));
        }
    }
}
