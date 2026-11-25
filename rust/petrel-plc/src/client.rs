use std::{collections::VecDeque, net::IpAddr, time::Duration};

use bytes::Bytes;
use http::{
    Method, Request, Response,
    header::{ACCEPT, CONTENT_TYPE},
};
use petrel::{
    net::{
        Origin, RedirectPolicy, ResponseOrigin, SendOptions, SharedTransport, TransportError,
        send_with_redirects,
    },
    rt::BoxFuture,
};
use petrel_crypto::{ATProtoSigner, PublicKey};
use serde_json::Value as Json;
use url::{Host, Url};

use crate::{
    audit_log::{
        PlcAuditEntry, PlcAuditLogVerifier, PlcDocumentData, PlcVerifiedAuditLog,
        plc_timestamp_milliseconds,
    },
    did_document::PlcDidDocument,
    error::PlcError,
    export::{PlcExportCursor, PlcExportEntry},
    limits::PlcOperationLimits,
    operation::{
        PlcOperation, PlcOperationCodec, PlcOperationDraft, PlcTombstone, UnsignedPlcOperation,
    },
    strict_json::PlcStrictJson,
};

/// How `PlcDirectoryClient` checks an HTTP 2xx submit acknowledgement body.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum PlcSubmitSuccessResponsePolicy {
    /// Strict behavior: production submits always confirm via audit log; laboratory accepts empty or StrictJSON `application/json`.
    #[default]
    Strict,
    /// Reference server (`did-method-plc`) `200`, `text/plain; charset=utf-8`, body `OK`.
    DidPlcServer001,
}

/// Configuration and bounds for [`PlcDirectoryClient`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlcClientConfiguration {
    origin: Url,
    is_laboratory: bool,
    submit_success_response_policy: PlcSubmitSuccessResponsePolicy,
    pub timeout: Duration,
    pub maximum_state_bytes: usize,
    pub maximum_audit_bytes: usize,
    pub maximum_submit_response_bytes: usize,
    pub maximum_export_bytes: usize,
    pub operation_limits: PlcOperationLimits,
}

impl PlcClientConfiguration {
    /// Default public PLC directory origin (`https://plc.directory`).
    ///
    /// # Panics
    ///
    /// Never panics; the static URL literal is valid.
    pub fn default_production_origin() -> Url {
        Url::parse("https://plc.directory").expect("fixed production PLC origin")
    }

    /// Production configuration targeting an HTTPS non-loopback directory origin.
    pub fn production(origin: Option<&Url>) -> Result<Self, PlcError> {
        let default = Self::default_production_origin();
        Self::production_with_options(
            origin.unwrap_or(&default),
            PlcOperationLimits::REFERENCE_DIRECTORY,
            false,
        )
    }

    /// Production configuration with explicit operation limits and non-default port flag.
    pub fn production_with_options(
        origin: &Url,
        operation_limits: PlcOperationLimits,
        allows_non_default_port: bool,
    ) -> Result<Self, PlcError> {
        let origin = Self::validate_origin(origin, false, None, allows_non_default_port)?;
        Ok(Self {
            origin,
            is_laboratory: false,
            submit_success_response_policy: PlcSubmitSuccessResponsePolicy::Strict,
            timeout: Duration::from_secs(5),
            maximum_state_bytes: 256 * 1024,
            maximum_audit_bytes: 4 * 1024 * 1024,
            maximum_submit_response_bytes: 64 * 1024,
            maximum_export_bytes: 16 * 1024 * 1024,
            operation_limits,
        })
    }

    /// Development configuration targeting HTTP on literal loopback or an explicitly allowlisted host (`port >= 1024`).
    pub fn laboratory(
        origin: &Url,
        submit_success_response_policy: PlcSubmitSuccessResponsePolicy,
        allowlisted_host: Option<&str>,
    ) -> Result<Self, PlcError> {
        let origin = Self::validate_origin(origin, true, allowlisted_host, false)?;
        Ok(Self {
            origin,
            is_laboratory: true,
            submit_success_response_policy,
            timeout: Duration::from_secs(5),
            maximum_state_bytes: 256 * 1024,
            maximum_audit_bytes: 4 * 1024 * 1024,
            maximum_submit_response_bytes: 64 * 1024,
            maximum_export_bytes: 16 * 1024 * 1024,
            operation_limits: PlcOperationLimits::SPECIFICATION,
        })
    }

    /// Adjusts timeout within `(0, 30s]`.
    pub fn with_timeout(mut self, timeout: Duration) -> Result<Self, PlcError> {
        if timeout.is_zero() || timeout > Duration::from_secs(30) {
            return Err(PlcError::malformed("PLC client timeout out of range"));
        }
        self.timeout = timeout;
        Ok(self)
    }

    /// Adjusts byte limits (must be strictly positive and at most 32 MiB).
    pub fn with_byte_bounds(
        mut self,
        state: usize,
        audit: usize,
        submit: usize,
        export: usize,
    ) -> Result<Self, PlcError> {
        const CEILING: usize = 32 * 1024 * 1024;
        for bound in [state, audit, submit, export] {
            if bound == 0 || bound > CEILING {
                return Err(PlcError::malformed("PLC response byte bound out of range"));
            }
        }
        self.maximum_state_bytes = state;
        self.maximum_audit_bytes = audit;
        self.maximum_submit_response_bytes = submit;
        self.maximum_export_bytes = export;
        Ok(self)
    }

    /// Sets write-time validation limits.
    #[must_use]
    pub fn with_operation_limits(mut self, limits: PlcOperationLimits) -> Self {
        self.operation_limits = limits;
        self
    }

    pub fn origin(&self) -> &Url {
        &self.origin
    }

    pub fn is_laboratory(&self) -> bool {
        self.is_laboratory
    }

    pub fn submit_success_response_policy(&self) -> PlcSubmitSuccessResponsePolicy {
        self.submit_success_response_policy
    }

    fn validate_origin(
        origin: &Url,
        laboratory: bool,
        allowlisted_host: Option<&str>,
        allows_non_default_port: bool,
    ) -> Result<Url, PlcError> {
        let scheme = origin.scheme().to_ascii_lowercase();
        let Some(host_str) = origin.host_str() else {
            return Err(PlcError::malformed(
                "PLC directory must be configured as an origin",
            ));
        };
        if host_str.is_empty()
            || !origin.username().is_empty()
            || origin.password().is_some()
            || origin.query().is_some()
            || origin.fragment().is_some()
            || !(origin.path().is_empty() || origin.path() == "/")
        {
            return Err(PlcError::malformed(
                "PLC directory must be configured as an origin",
            ));
        }

        if laboratory {
            let norm_host = host_str.trim_end_matches('.').to_ascii_lowercase();
            let norm_allow = allowlisted_host.map(|h| h.trim_end_matches('.').to_ascii_lowercase());
            let allow_matches = norm_allow
                .as_deref()
                .is_some_and(|a| !a.is_empty() && a == norm_host);
            let port_ok = origin.port().is_some_and(|p| p >= 1024);
            let host_ok = is_loopback_literal(origin) || allow_matches;
            let explicit_reject = norm_allow.is_some() && !allow_matches;
            if scheme != "http" || !host_ok || !port_ok || explicit_reject {
                return Err(PlcError::malformed(
                    "PLC laboratory origin must be an HTTP literal-loopback origin or an explicitly allowlisted lab host",
                ));
            }
        } else {
            if scheme != "https" || is_loopback_literal(origin) {
                return Err(PlcError::malformed("PLC production origin must use HTTPS"));
            }
            if let Some(port) = origin.port()
                && port != 443
                && (!allows_non_default_port || port == 0)
            {
                return Err(PlcError::malformed(
                    "PLC production origin must use HTTPS on port 443",
                ));
            }
        }

        let mut canonical = Url::parse(&format!("{scheme}://{host_str}"))
            .map_err(|_| PlcError::malformed("PLC directory origin is malformed"))?;
        if let Some(port) = origin.port() {
            canonical
                .set_port(Some(port))
                .map_err(|()| PlcError::malformed("PLC directory origin port is invalid"))?;
        }
        canonical.set_path("");
        Ok(canonical)
    }
}

fn is_loopback_literal(url: &Url) -> bool {
    match url.host() {
        Some(Host::Domain(domain)) => domain.eq_ignore_ascii_case("localhost"),
        Some(Host::Ipv4(ip)) => ip.is_loopback(),
        Some(Host::Ipv6(ip)) => IpAddr::V6(ip).is_loopback(),
        None => false,
    }
}

/// Verified directory operations used by services and tests.
pub trait PlcClient: petrel::rt::MaybeSend + petrel::rt::MaybeSync {
    fn submit<'a>(
        &'a self,
        did: &'a str,
        operation: &'a PlcOperation,
    ) -> BoxFuture<'a, Result<(), PlcError>>;

    fn fetch_state<'a>(&'a self, did: &'a str) -> BoxFuture<'a, Result<PlcDocumentData, PlcError>>;

    fn fetch_audit<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Vec<PlcAuditEntry>, PlcError>>;

    fn fetch_audit_if_present<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<PlcAuditEntry>>, PlcError>> {
        Box::pin(async move {
            match self.fetch_audit(did).await {
                Ok(entries) => Ok(Some(entries)),
                Err(PlcError::NotFound { .. }) => Ok(None),
                Err(err) => Err(err),
            }
        })
    }
}

/// Client for `did:plc` directories built atop `petrel::net::SharedTransport`.
#[derive(Clone)]
pub struct PlcDirectoryClient {
    configuration: PlcClientConfiguration,
    transport: SharedTransport,
}

impl std::fmt::Debug for PlcDirectoryClient {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PlcDirectoryClient")
            .field("configuration", &self.configuration)
            .finish_non_exhaustive()
    }
}

impl PlcDirectoryClient {
    /// Creates a client with explicit configuration and HTTP transport.
    pub fn new(configuration: PlcClientConfiguration, transport: SharedTransport) -> Self {
        Self {
            configuration,
            transport,
        }
    }

    pub fn configuration(&self) -> &PlcClientConfiguration {
        &self.configuration
    }

    /// `GET /:did` — rendered DID document (unverified presentation).
    pub async fn get_document(&self, did: &str) -> Result<PlcDidDocument, PlcError> {
        let body = self
            .get_json_with_types(
                did,
                &[],
                self.configuration.maximum_state_bytes,
                "application/did+ld+json, application/json",
                &["application/did+ld+json", "application/json"],
            )
            .await?;
        let doc: PlcDidDocument = serde_json::from_slice(&body)
            .map_err(|_| PlcError::malformed("PLC DID document is malformed"))?;
        if doc.id != did {
            return Err(PlcError::unauthorized(
                "PLC DID document id does not match DID",
            ));
        }
        Ok(doc)
    }

    /// `GET /:did/data` — identity state (unverified presentation).
    pub async fn get_document_data(&self, did: &str) -> Result<PlcDocumentData, PlcError> {
        let body = self
            .get_json(did, &["data"], self.configuration.maximum_state_bytes)
            .await?;
        let data: PlcDocumentData = serde_json::from_slice(&body)
            .map_err(|_| PlcError::malformed("PLC document data is malformed"))?;
        if data.did != did {
            return Err(PlcError::malformed("PLC document data DID does not match"));
        }
        Ok(data)
    }

    /// `GET /:did/log` — linear operation log.
    pub async fn get_operation_log(&self, did: &str) -> Result<Vec<PlcOperation>, PlcError> {
        let body = self
            .get_json(did, &["log"], self.configuration.maximum_audit_bytes)
            .await?;
        let raw_ops: Vec<Json> = serde_json::from_slice(&body)
            .map_err(|_| PlcError::malformed("PLC operation log is malformed"))?;
        if raw_ops.is_empty() || raw_ops.len() > PlcAuditLogVerifier::MAXIMUM_ENTRIES {
            return Err(PlcError::malformed("PLC operation log is malformed"));
        }
        raw_ops
            .iter()
            .map(PlcOperationCodec::decode_signed_json_value)
            .collect()
    }

    /// `GET /:did/log/audit` — unverified audit log.
    pub async fn get_audit_log(&self, did: &str) -> Result<Vec<PlcAuditEntry>, PlcError> {
        let body = self
            .get_json(
                did,
                &["log", "audit"],
                self.configuration.maximum_audit_bytes,
            )
            .await?;
        PlcAuditLogVerifier::decode(&body, did)
    }

    /// `GET /:did/log/last` — current active operation.
    pub async fn get_last_operation(&self, did: &str) -> Result<PlcOperation, PlcError> {
        let body = self
            .get_json(
                did,
                &["log", "last"],
                self.configuration.maximum_state_bytes,
            )
            .await?;
        PlcOperationCodec::decode_signed_json(&body)
    }

    /// `GET /export` — fetches a single page of directory-wide operations.
    pub async fn export(
        &self,
        after: Option<&PlcExportCursor>,
        count: usize,
    ) -> Result<Vec<PlcExportEntry>, PlcError> {
        if !(1..=1_000).contains(&count) {
            return Err(PlcError::malformed("PLC export count must be 1...1000"));
        }
        let mut query = vec![("count".to_owned(), count.to_string())];
        if let Some(cursor) = after {
            if let PlcExportCursor::Timestamp(ts) = cursor
                && plc_timestamp_milliseconds(ts).is_none()
            {
                return Err(PlcError::malformed(
                    "PLC export timestamp cursor must be YYYY-MM-DDTHH:mm:ss.sssZ",
                ));
            }
            query.push(("after".to_owned(), cursor.to_string()));
        }

        let url = self.endpoint(&["export"], &query)?;
        let request = Request::builder()
            .method(Method::GET)
            .uri(url.as_str())
            .header(ACCEPT, "application/jsonlines, application/json")
            .body(Bytes::new())
            .map_err(|e| PlcError::unavailable(e.to_string()))?;

        let response = self
            .send_checked(request, &url, self.configuration.maximum_export_bytes)
            .await?;
        Self::validate_response(
            &response,
            &url,
            self.configuration.maximum_export_bytes,
            None,
            &[
                "application/jsonlines",
                "application/jsonl",
                "application/x-ndjson",
                "application/x-jsonlines",
                "application/json",
                "text/plain",
            ],
            true,
        )?;
        PlcExportEntry::decode_json_lines(response.body())
    }

    /// Returns a lazy page-by-page export stream starting at `after`.
    pub fn export_sequence(&self, after: PlcExportCursor, page_size: usize) -> PlcExportSequence {
        PlcExportSequence::new(self.clone(), after, page_size)
    }

    /// Fetches and offline-verifies the identity's audit log.
    pub async fn fetch_verified_audit_log(
        &self,
        did: &str,
    ) -> Result<PlcVerifiedAuditLog, PlcError> {
        let entries = self.get_audit_log(did).await?;
        PlcAuditLogVerifier::verify(&entries, did)
    }

    /// Verified audit entries with recomputed `nullified` flags.
    pub async fn fetch_audit(&self, did: &str) -> Result<Vec<PlcAuditEntry>, PlcError> {
        Ok(self.fetch_verified_audit_log(did).await?.entries)
    }

    /// Like `fetch_audit`, returning `Ok(None)` when the DID is not registered.
    pub async fn fetch_audit_if_present(
        &self,
        did: &str,
    ) -> Result<Option<Vec<PlcAuditEntry>>, PlcError> {
        match self.fetch_audit(did).await {
            Ok(entries) => Ok(Some(entries)),
            Err(PlcError::NotFound { .. }) => Ok(None),
            Err(err) => Err(err),
        }
    }

    /// Fetches `GET /:did/data` and proves it matches the verified audit log head.
    pub async fn fetch_state(&self, did: &str) -> Result<PlcDocumentData, PlcError> {
        let state = self.get_document_data(did).await?;
        let log = self.fetch_verified_audit_log(did).await?;
        let Some(proven) = log.document_data() else {
            return Err(PlcError::Tombstoned {
                did: did.to_owned(),
            });
        };
        if state != proven {
            return Err(PlcError::unauthorized(
                "PLC document data does not match its audit log",
            ));
        }
        Ok(state)
    }

    /// `POST /:did` — submits a signed operation and confirms registration on production origins.
    pub async fn submit(&self, did: &str, operation: &PlcOperation) -> Result<(), PlcError> {
        PlcOperationCodec::validate_canonical_did(did)?;
        PlcOperationCodec::validate_for_submission(
            operation,
            &self.configuration.operation_limits,
        )?;
        if operation.prev().is_none() {
            PlcOperationCodec::verify_genesis(operation, did)?;
        }
        let body = operation.canonical_json()?;
        if &PlcOperationCodec::decode_signed_json(&body)? != operation {
            return Err(PlcError::malformed("PLC operation is not canonical"));
        }

        let url = self.endpoint(&[did], &[])?;
        let request = Request::builder()
            .method(Method::POST)
            .uri(url.as_str())
            .header(ACCEPT, "application/json")
            .header(CONTENT_TYPE, "application/json")
            .body(Bytes::from(body))
            .map_err(|e| PlcError::unavailable(e.to_string()))?;

        let response = self
            .send_checked(
                request,
                &url,
                self.configuration.maximum_submit_response_bytes,
            )
            .await?;
        match self.validate_submit_response(&response, &url)? {
            SubmitAcceptance::Verified => Ok(()),
            SubmitAcceptance::RequiresDirectoryConfirmation => {
                let submitted_cid = operation.cid_string()?;
                let log = self.fetch_verified_audit_log(did).await.map_err(|err| {
                    PlcError::SubmittedButUnconfirmed {
                        cid: submitted_cid.clone(),
                        reason: err.to_string(),
                    }
                })?;
                if log.head.cid != submitted_cid {
                    return Err(PlcError::unauthorized(
                        "PLC directory did not record the submitted operation",
                    ));
                }
                Ok(())
            }
        }
    }

    // MARK: One-call convenience creation and updates

    /// Builds, signs, validates, and submits a new `did:plc` identity.
    pub async fn create_did(
        &self,
        handle: &str,
        signing_key: &str,
        rotation_keys: &[String],
        pds_endpoint: &str,
        signer: &dyn ATProtoSigner,
    ) -> Result<CreatedPlcIdentity, PlcError> {
        let unsigned = crate::at_profile::PlcAtProfile::genesis_operation(
            handle,
            signing_key,
            rotation_keys,
            pds_endpoint,
        )?;
        let operation =
            PlcOperationCodec::sign(&UnsignedPlcOperation::Regular(unsigned), signer).await?;
        let did = PlcOperationCodec::genesis_did(&operation)?;
        self.submit(&did, &operation).await?;
        Ok(CreatedPlcIdentity { did, operation })
    }

    /// Reads the verified audit log, updates the draft via `mutate`, signs, checks local authorization, and submits.
    pub async fn update<F>(
        &self,
        did: &str,
        signer: &dyn ATProtoSigner,
        mutate: F,
    ) -> Result<PlcOperation, PlcError>
    where
        F: FnOnce(&mut PlcOperationDraft) -> Result<(), PlcError>,
    {
        let log = self.fetch_verified_audit_log(did).await?;
        let Some(rotation_keys) = log.head.operation.rotation_keys() else {
            return Err(PlcError::Tombstoned {
                did: did.to_owned(),
            });
        };
        let next_unsigned = PlcOperationCodec::update(&log.head.operation, mutate)?;
        let operation =
            PlcOperationCodec::sign(&UnsignedPlcOperation::Regular(next_unsigned), signer).await?;
        let _ = PlcOperationCodec::verify(&operation, &rotation_keys)?;
        self.submit(did, &operation).await?;
        Ok(operation)
    }

    /// Replaces the account handle in the first `at://` alias.
    pub async fn update_handle(
        &self,
        did: &str,
        signer: &dyn ATProtoSigner,
        handle: &str,
    ) -> Result<PlcOperation, PlcError> {
        self.update(did, signer, |draft| draft.set_handle(handle))
            .await
    }

    /// Updates the `atproto_pds` service endpoint.
    pub async fn update_pds(
        &self,
        did: &str,
        signer: &dyn ATProtoSigner,
        endpoint: &str,
    ) -> Result<PlcOperation, PlcError> {
        self.update(did, signer, |draft| draft.set_pds(endpoint))
            .await
    }

    /// Updates the `#atproto` verification method key.
    pub async fn update_atproto_key(
        &self,
        did: &str,
        signer: &dyn ATProtoSigner,
        signing_key: &str,
    ) -> Result<PlcOperation, PlcError> {
        self.update(did, signer, |draft| draft.set_atproto_key(signing_key))
            .await
    }

    /// Replaces the ordered rotation keys list.
    pub async fn update_rotation_keys(
        &self,
        did: &str,
        signer: &dyn ATProtoSigner,
        rotation_keys: Vec<String>,
    ) -> Result<PlcOperation, PlcError> {
        self.update(did, signer, |draft| {
            draft.rotation_keys = rotation_keys;
            Ok(())
        })
        .await
    }

    /// Deactivates a `did:plc` identity with a signed `plc_tombstone`.
    pub async fn tombstone(
        &self,
        did: &str,
        signer: &dyn ATProtoSigner,
    ) -> Result<PlcTombstone, PlcError> {
        let log = self.fetch_verified_audit_log(did).await?;
        let Some(rotation_keys) = log.head.operation.rotation_keys() else {
            return Err(PlcError::Tombstoned {
                did: did.to_owned(),
            });
        };
        let unsigned = crate::operation::UnsignedPlcTombstoneOperation::new(log.head.cid)?;
        let operation =
            PlcOperationCodec::sign(&UnsignedPlcOperation::Tombstone(unsigned), signer).await?;
        let _ = PlcOperationCodec::verify(&operation, &rotation_keys)?;
        self.submit(did, &operation).await?;
        match operation {
            PlcOperation::Tombstone(tombstone) => Ok(tombstone),
            _ => unreachable!("tombstone signing always yields tombstone"),
        }
    }

    // MARK: Internal HTTP plumbing

    async fn get_json(
        &self,
        did: &str,
        suffix: &[&str],
        maximum_bytes: usize,
    ) -> Result<Bytes, PlcError> {
        self.get_json_with_types(
            did,
            suffix,
            maximum_bytes,
            "application/json",
            &["application/json"],
        )
        .await
    }

    async fn get_json_with_types(
        &self,
        did: &str,
        suffix: &[&str],
        maximum_bytes: usize,
        accept: &str,
        content_types: &[&str],
    ) -> Result<Bytes, PlcError> {
        PlcOperationCodec::validate_canonical_did(did)?;
        let mut path = Vec::with_capacity(1 + suffix.len());
        path.push(did);
        path.extend_from_slice(suffix);
        let url = self.endpoint(&path, &[])?;
        let request = Request::builder()
            .method(Method::GET)
            .uri(url.as_str())
            .header(ACCEPT, accept)
            .body(Bytes::new())
            .map_err(|e| PlcError::unavailable(e.to_string()))?;

        let response = self.send_checked(request, &url, maximum_bytes).await?;
        Self::validate_response(
            &response,
            &url,
            maximum_bytes,
            Some(did),
            content_types,
            false,
        )?;
        PlcStrictJson::validate(response.body())?;
        Ok(response.into_body())
    }

    async fn send_checked(
        &self,
        request: Request<Bytes>,
        url: &Url,
        maximum_bytes: usize,
    ) -> Result<Response<Bytes>, PlcError> {
        let mut options = SendOptions::new();
        options.timeout = Some(self.configuration.timeout);
        options.max_response_bytes = Some(maximum_bytes as u64);
        options.allow_loopback = self.configuration.is_laboratory;
        options.allowed_cleartext_origin = if self.configuration.is_laboratory
            && self.configuration.origin.scheme() == "http"
            && !is_loopback_literal(&self.configuration.origin)
        {
            Origin::from_url(&self.configuration.origin).ok()
        } else {
            None
        };
        options.anonymous = true;
        let response = send_with_redirects(
            self.transport.as_ref(),
            request,
            &options,
            RedirectPolicy::Never,
        )
        .await
        .map_err(|err| match err {
            TransportError::ResponseTooLarge { .. } => {
                PlcError::unavailable("PLC directory response exceeded its bound")
            }
            TransportError::PolicyViolation(msg) => PlcError::unavailable(msg),
            other => PlcError::unavailable(other.to_string()),
        })?;

        if response.status().is_redirection() {
            return Err(PlcError::unauthorized(
                "PLC directory redirects are forbidden",
            ));
        }
        if let Some(origin) = response.extensions().get::<ResponseOrigin>()
            && Origin::from_url(url).is_ok_and(|expected| origin.0 != expected)
        {
            return Err(PlcError::unauthorized(
                "PLC directory redirects are forbidden",
            ));
        }
        if response.body().len() > maximum_bytes {
            return Err(PlcError::unavailable(
                "PLC directory response exceeded its bound",
            ));
        }
        Ok(response)
    }

    fn endpoint(&self, path: &[&str], query: &[(String, String)]) -> Result<Url, PlcError> {
        if path.iter().any(|seg| seg.is_empty() || seg.contains('/')) {
            return Err(PlcError::malformed("PLC request URL is invalid"));
        }
        let mut url = self.configuration.origin.clone();
        url.set_path(&format!("/{}", path.join("/")));
        if query.is_empty() {
            url.set_query(None);
        } else {
            let encoded: String = query
                .iter()
                .map(|(k, v)| {
                    format!(
                        "{}={}",
                        percent_encode_unreserved(k),
                        percent_encode_unreserved(v)
                    )
                })
                .collect::<Vec<_>>()
                .join("&");
            url.set_query(Some(&encoded));
        }
        Ok(url)
    }

    fn validate_response(
        response: &Response<Bytes>,
        _url: &Url,
        maximum_bytes: usize,
        did: Option<&str>,
        content_types: &[&str],
        permits_empty_body: bool,
    ) -> Result<(), PlcError> {
        if response.body().len() > maximum_bytes {
            return Err(PlcError::unavailable(
                "PLC directory response exceeded its bound",
            ));
        }
        let status = response.status().as_u16();
        if !(200..=299).contains(&status) {
            return Err(Self::failure_for_response(response, did));
        }
        if permits_empty_body && response.body().is_empty() {
            return Ok(());
        }
        let Some(mt) = Self::media_type(response) else {
            return Err(PlcError::malformed(
                "PLC directory response has an unexpected content type",
            ));
        };
        if !content_types.contains(&mt.as_str()) {
            return Err(PlcError::malformed(
                "PLC directory response has an unexpected content type",
            ));
        }
        Ok(())
    }

    fn validate_submit_response(
        &self,
        response: &Response<Bytes>,
        _url: &Url,
    ) -> Result<SubmitAcceptance, PlcError> {
        Self::validate_submit_response_for_config(&self.configuration, response)
    }

    fn validate_submit_response_for_config(
        configuration: &PlcClientConfiguration,
        response: &Response<Bytes>,
    ) -> Result<SubmitAcceptance, PlcError> {
        let status = response.status().as_u16();
        if !(200..=299).contains(&status) {
            return Err(Self::failure_for_response(response, None));
        }

        if !configuration.is_laboratory {
            if configuration.submit_success_response_policy
                == PlcSubmitSuccessResponsePolicy::DidPlcServer001
            {
                return Err(PlcError::malformed(
                    "PLC reference submit compatibility requires a laboratory origin",
                ));
            }
            return Ok(SubmitAcceptance::RequiresDirectoryConfirmation);
        }

        match configuration.submit_success_response_policy {
            PlcSubmitSuccessResponsePolicy::DidPlcServer001 => {
                if status != 200 {
                    return Err(PlcError::unavailable(
                        "PLC directory returned an incompatible submit status",
                    ));
                }
                let ct = response
                    .headers()
                    .get(CONTENT_TYPE)
                    .and_then(|v| v.to_str().ok());
                if ct != Some("text/plain; charset=utf-8") || response.body().as_ref() != b"OK" {
                    return Err(PlcError::malformed(
                        "PLC directory returned an incompatible submit response",
                    ));
                }
                Ok(SubmitAcceptance::Verified)
            }
            PlcSubmitSuccessResponsePolicy::Strict => {
                if response.body().is_empty() {
                    return Ok(SubmitAcceptance::Verified);
                }
                if Self::media_type(response).as_deref() != Some("application/json") {
                    return Err(PlcError::malformed("PLC directory response is not JSON"));
                }
                PlcStrictJson::validate(response.body())?;
                Ok(SubmitAcceptance::Verified)
            }
        }
    }

    fn media_type(response: &Response<Bytes>) -> Option<String> {
        response
            .headers()
            .get(CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .and_then(|raw| raw.split(';').next())
            .map(|part| part.trim().to_ascii_lowercase())
    }

    pub(crate) fn failure_for_response(response: &Response<Bytes>, did: Option<&str>) -> PlcError {
        let status = response.status().as_u16();
        let message = Self::directory_message(response.body());
        match status {
            404 => match did {
                None => PlcError::Rejected {
                    status: 404,
                    message: message.unwrap_or_default(),
                },
                Some(did)
                    if message
                        .as_deref()
                        .is_some_and(|m| m.contains("not available")) =>
                {
                    PlcError::Tombstoned {
                        did: did.to_owned(),
                    }
                }
                Some(did) => PlcError::NotFound {
                    did: did.to_owned(),
                },
            },
            410 => match did {
                None => PlcError::Rejected {
                    status: 410,
                    message: message.unwrap_or_default(),
                },
                Some(did) => PlcError::Tombstoned {
                    did: did.to_owned(),
                },
            },
            429 => {
                let retry_after = response
                    .headers()
                    .get("retry-after")
                    .and_then(|v| v.to_str().ok())
                    .and_then(|raw| raw.trim().parse::<u64>().ok());
                PlcError::RateLimited {
                    retry_after_seconds: retry_after,
                }
            }
            400..=499 => PlcError::Rejected {
                status,
                message: message.unwrap_or_default(),
            },
            _ => PlcError::Unavailable(format!("PLC directory returned HTTP {status}")),
        }
    }

    fn directory_message(body: &[u8]) -> Option<String> {
        if body.is_empty() || body.len() > 64 * 1024 || PlcStrictJson::validate(body).is_err() {
            return None;
        }
        let val: Json = serde_json::from_slice(body).ok()?;
        let msg = val.get("message")?.as_str()?;
        Some(msg.chars().take(1_024).collect())
    }
}

impl PlcClient for PlcDirectoryClient {
    fn submit<'a>(
        &'a self,
        did: &'a str,
        operation: &'a PlcOperation,
    ) -> BoxFuture<'a, Result<(), PlcError>> {
        Box::pin(self.submit(did, operation))
    }

    fn fetch_state<'a>(&'a self, did: &'a str) -> BoxFuture<'a, Result<PlcDocumentData, PlcError>> {
        Box::pin(self.fetch_state(did))
    }

    fn fetch_audit<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Vec<PlcAuditEntry>, PlcError>> {
        Box::pin(self.fetch_audit(did))
    }

    fn fetch_audit_if_present<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<PlcAuditEntry>>, PlcError>> {
        Box::pin(self.fetch_audit_if_present(did))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SubmitAcceptance {
    Verified,
    RequiresDirectoryConfirmation,
}

/// Newly created identity returned by [`PlcDirectoryClient::create_did`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreatedPlcIdentity {
    pub did: String,
    pub operation: PlcOperation,
}

/// Paginated async reader over `GET /export`.
#[derive(Debug, Clone)]
pub struct PlcExportSequence {
    client: PlcDirectoryClient,
    cursor: PlcExportCursor,
    page_size: usize,
    buffer: VecDeque<PlcExportEntry>,
    reached_end: bool,
}

impl PlcExportSequence {
    fn new(client: PlcDirectoryClient, start: PlcExportCursor, page_size: usize) -> Self {
        Self {
            client,
            cursor: start,
            page_size,
            buffer: VecDeque::new(),
            reached_end: false,
        }
    }

    /// The cursor that the next page request will use.
    pub fn cursor(&self) -> &PlcExportCursor {
        &self.cursor
    }

    /// Fetches the next exported entry, returning `Ok(None)` when the directory log is exhausted.
    pub async fn next_entry(&mut self) -> Result<Option<PlcExportEntry>, PlcError> {
        if let Some(entry) = self.buffer.pop_front() {
            return Ok(Some(entry));
        }
        if self.reached_end {
            return Ok(None);
        }
        let page = self
            .client
            .export(Some(&self.cursor), self.page_size)
            .await?;
        self.reached_end = page.len() < self.page_size;
        let Some(last) = page.last() else {
            return Ok(None);
        };
        let next_cursor = last.cursor();
        if !cursor_strictly_advances(&self.cursor, &next_cursor) {
            return Err(PlcError::malformed("PLC export cursor did not advance"));
        }
        self.cursor = next_cursor;
        self.buffer.extend(page);
        Ok(self.buffer.pop_front())
    }
}

fn cursor_strictly_advances(previous: &PlcExportCursor, next: &PlcExportCursor) -> bool {
    match (previous, next) {
        (PlcExportCursor::Sequence(prev_seq), PlcExportCursor::Sequence(next_seq)) => {
            next_seq > prev_seq
        }
        (PlcExportCursor::Timestamp(prev_ts), PlcExportCursor::Timestamp(next_ts)) => matches!(
            (
                plc_timestamp_milliseconds(prev_ts),
                plc_timestamp_milliseconds(next_ts)
            ),
            (Some(prev_millis), Some(next_millis)) if next_millis > prev_millis
        ),
        _ => false,
    }
}

fn percent_encode_unreserved(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for byte in input.as_bytes() {
        if byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'.' | b'_' | b'~') {
            out.push(*byte as char);
        } else {
            out.push('%');
            out.push(HEX_UPPER[usize::from(*byte >> 4)]);
            out.push(HEX_UPPER[usize::from(*byte & 0x0f)]);
        }
    }
    out
}

const HEX_UPPER: &[char; 16] = &[
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
];

#[allow(dead_code)]
fn _unused_public_key_marker(_: &PublicKey) {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn did_plc_server_001_requires_laboratory_origin() {
        let mut prod = PlcClientConfiguration::production(None).unwrap();
        assert!(!prod.is_laboratory());
        assert_eq!(
            prod.submit_success_response_policy(),
            PlcSubmitSuccessResponsePolicy::Strict
        );

        let ok_resp = Response::builder()
            .status(200)
            .header(CONTENT_TYPE, "text/plain; charset=utf-8")
            .body(Bytes::from_static(b"OK"))
            .unwrap();

        assert_eq!(
            PlcDirectoryClient::validate_submit_response_for_config(&prod, &ok_resp).unwrap(),
            SubmitAcceptance::RequiresDirectoryConfirmation
        );

        prod.submit_success_response_policy = PlcSubmitSuccessResponsePolicy::DidPlcServer001;
        assert!(matches!(
            PlcDirectoryClient::validate_submit_response_for_config(&prod, &ok_resp),
            Err(PlcError::Malformed(_))
        ));
    }
}
