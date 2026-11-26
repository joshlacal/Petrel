use serde::{Deserialize, Serialize};

use crate::oauth::config::OAuthAuthorizationServerConfiguration;

/// OAuth 2.0 Authorization Server Metadata document (`/.well-known/oauth-authorization-server`, RFC 8414).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OAuthAuthorizationServerMetadata {
    pub issuer: String,
    pub authorization_endpoint: String,
    pub token_endpoint: String,
    pub pushed_authorization_request_endpoint: String,
    pub revocation_endpoint: String,
    pub jwks_uri: String,
    pub scopes_supported: Vec<String>,
    pub response_types_supported: Vec<String>,
    pub response_modes_supported: Vec<String>,
    pub grant_types_supported: Vec<String>,
    pub subject_types_supported: Vec<String>,
    pub code_challenge_methods_supported: Vec<String>,
    pub token_endpoint_auth_methods_supported: Vec<String>,
    pub token_endpoint_auth_signing_alg_values_supported: Vec<String>,
    pub dpop_signing_alg_values_supported: Vec<String>,
    pub require_pushed_authorization_requests: bool,
    pub authorization_response_iss_parameter_supported: bool,
    pub client_id_metadata_document_supported: bool,
}

impl OAuthAuthorizationServerMetadata {
    /// Builds the standard AT Protocol authorization server metadata for `config`.
    pub fn from_config(config: &OAuthAuthorizationServerConfiguration) -> Self {
        let base = config.issuer.trim_end_matches('/');
        Self {
            issuer: base.to_owned(),
            authorization_endpoint: format!("{base}/oauth/authorize"),
            token_endpoint: format!("{base}/oauth/token"),
            pushed_authorization_request_endpoint: format!("{base}/oauth/par"),
            revocation_endpoint: format!("{base}/oauth/revoke"),
            jwks_uri: format!("{base}/oauth/jwks"),
            scopes_supported: config.scopes_supported.clone(),
            response_types_supported: vec!["code".to_owned()],
            response_modes_supported: vec!["query".to_owned(), "fragment".to_owned()],
            grant_types_supported: vec![
                "authorization_code".to_owned(),
                "refresh_token".to_owned(),
            ],
            subject_types_supported: vec!["public".to_owned()],
            code_challenge_methods_supported: vec!["S256".to_owned()],
            token_endpoint_auth_methods_supported: vec![
                "none".to_owned(),
                "private_key_jwt".to_owned(),
            ],
            token_endpoint_auth_signing_alg_values_supported: vec![
                "ES256".to_owned(),
                "ES256K".to_owned(),
            ],
            dpop_signing_alg_values_supported: vec!["ES256".to_owned(), "ES256K".to_owned()],
            require_pushed_authorization_requests: true,
            authorization_response_iss_parameter_supported: true,
            client_id_metadata_document_supported: true,
        }
    }
}

/// OAuth 2.0 Protected Resource Metadata document (`/.well-known/oauth-protected-resource`, RFC 9728).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OAuthProtectedResourceMetadata {
    pub resource: String,
    pub authorization_servers: Vec<String>,
    pub scopes_supported: Vec<String>,
    pub bearer_methods_supported: Vec<String>,
    pub dpop_signing_alg_values_supported: Vec<String>,
    pub dpop_bound_access_tokens_required: bool,
}

impl OAuthProtectedResourceMetadata {
    /// Builds standard AT Protocol protected resource metadata.
    pub fn for_resource(
        resource: impl Into<String>,
        authorization_servers: Vec<String>,
        scopes_supported: Vec<String>,
    ) -> Self {
        Self {
            resource: resource.into(),
            authorization_servers,
            scopes_supported,
            bearer_methods_supported: Vec::new(),
            dpop_signing_alg_values_supported: vec!["ES256".to_owned(), "ES256K".to_owned()],
            dpop_bound_access_tokens_required: true,
        }
    }
}
