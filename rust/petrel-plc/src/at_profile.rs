use petrel_crypto::PublicKey;
use url::Url;

use crate::{
    error::PlcError,
    identifiers::AccountIdentifiers,
    operation::{PlcService, UnsignedPlcRegularOperation},
};

/// AT Protocol profile helpers for constructing PLC genesis operations and endpoints.
#[derive(Debug, Clone, Copy)]
pub struct PlcAtProfile;

impl PlcAtProfile {
    /// The `services` key of the account's PDS.
    pub const PDS_SERVICE_ID: &'static str = "atproto_pds";
    /// The service type of a PDS.
    pub const PDS_SERVICE_TYPE: &'static str = "AtprotoPersonalDataServer";
    /// The `verificationMethods` key of the repository signing key.
    pub const SIGNING_KEY_ID: &'static str = "atproto";

    /// Builds the genesis operation of a new AT Protocol identity (`formatAtprotoOp`).
    pub fn genesis_operation(
        handle: &str,
        signing_key: &str,
        rotation_keys: &[String],
        pds_endpoint: &str,
    ) -> Result<UnsignedPlcRegularOperation, PlcError> {
        let mut verification_methods = std::collections::BTreeMap::new();
        verification_methods.insert(
            Self::SIGNING_KEY_ID.to_owned(),
            Self::signing_did_key(signing_key)?,
        );
        let mut services = std::collections::BTreeMap::new();
        services.insert(
            Self::PDS_SERVICE_ID.to_owned(),
            PlcService {
                kind: Self::PDS_SERVICE_TYPE.to_owned(),
                endpoint: Self::pds_endpoint(pds_endpoint)?,
            },
        );
        UnsignedPlcRegularOperation::new(
            rotation_keys.to_vec(),
            verification_methods,
            vec![Self::handle_uri(handle)?],
            services,
            None,
        )
    }

    /// Builds an AT Protocol operation from validated `PublicKey`s and a strict origin URL.
    pub fn regular_operation(
        handle: &str,
        signing_public_key: &PublicKey,
        rotation_public_keys: &[PublicKey],
        pds_origin: &Url,
        prev: Option<String>,
    ) -> Result<UnsignedPlcRegularOperation, PlcError> {
        let canonical_handle = AccountIdentifiers::canonical_handle(handle)?;
        let origin = Self::canonical_pds_origin(pds_origin)?;
        let mut verification_methods = std::collections::BTreeMap::new();
        verification_methods.insert(
            Self::SIGNING_KEY_ID.to_owned(),
            signing_public_key.did_key(),
        );
        let mut services = std::collections::BTreeMap::new();
        services.insert(
            Self::PDS_SERVICE_ID.to_owned(),
            PlcService {
                kind: Self::PDS_SERVICE_TYPE.to_owned(),
                endpoint: origin,
            },
        );
        UnsignedPlcRegularOperation::new(
            rotation_public_keys
                .iter()
                .map(PublicKey::did_key)
                .collect(),
            verification_methods,
            vec![format!("at://{canonical_handle}")],
            services,
            prev,
        )
    }

    /// Validates a handle (with or without `at://`) and returns `at://<canonical>`.
    pub fn handle_uri(handle: &str) -> Result<String, PlcError> {
        let bare = handle.strip_prefix("at://").unwrap_or(handle);
        Ok(format!(
            "at://{}",
            AccountIdentifiers::canonical_handle(bare)?
        ))
    }

    /// Validates a PDS endpoint (`http` or `https`, bare host gets `https://`), stripping any trailing `/`.
    pub fn pds_endpoint(raw: &str) -> Result<String, PlcError> {
        let trimmed = raw.trim();
        let candidate = if trimmed.contains("://") {
            trimmed.to_owned()
        } else {
            format!("https://{trimmed}")
        };
        let url = Url::parse(&candidate).map_err(|_| {
            PlcError::invalid_profile("PLC PDS endpoint must be an http/https origin URL")
        })?;
        Self::canonical_endpoint_origin(&url, false)
    }

    /// Validates a P-256 or K-256 `did:key` for `verificationMethods.atproto`.
    pub fn signing_did_key(signing_key: &str) -> Result<String, PlcError> {
        PublicKey::from_did_key(signing_key)
            .map(|k| k.did_key())
            .map_err(|_| {
                PlcError::invalid_identifier("PLC signing key must be a P-256 or K-256 did:key")
            })
    }

    /// Strict origin validation for `regular_operation`: HTTPS (default port) or loopback literal HTTP.
    pub fn canonical_pds_origin(url: &Url) -> Result<String, PlcError> {
        Self::canonical_endpoint_origin(url, true)
    }

    fn canonical_endpoint_origin(
        url: &Url,
        strict_origin_policy: bool,
    ) -> Result<String, PlcError> {
        let scheme = url.scheme().to_ascii_lowercase();
        let Some(host) = url.host_str() else {
            return Err(PlcError::invalid_profile(
                "PLC PDS endpoint must be an http/https origin URL",
            ));
        };
        if host.is_empty()
            || !url.username().is_empty()
            || url.password().is_some()
            || url.query().is_some()
            || url.fragment().is_some()
            || !(url.path().is_empty() || url.path() == "/")
            || !matches!(scheme.as_str(), "http" | "https")
        {
            return Err(PlcError::invalid_profile(
                "PLC PDS endpoint must not include credentials, path, query, or fragment",
            ));
        }
        if strict_origin_policy {
            let is_loopback = matches!(host, "localhost" | "127.0.0.1" | "::1" | "[::1]");
            if scheme == "https" {
                if let Some(port) = url.port()
                    && port != 443
                {
                    return Err(PlcError::invalid_profile(
                        "PLC PDS HTTPS origin must use port 443",
                    ));
                }
            } else if !is_loopback {
                return Err(PlcError::invalid_profile(
                    "PLC PDS HTTP origin is only allowed on loopback hosts",
                ));
            }
        }
        let mut out = format!("{scheme}://{host}");
        if let Some(port) = url.port() {
            let default_port = if scheme == "https" { 443 } else { 80 };
            if port != default_port {
                out.push(':');
                out.push_str(&port.to_string());
            }
        }
        Ok(out)
    }
}
