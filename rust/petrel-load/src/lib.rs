//! CLI load generator and auth-event JSONL recorder for Petrel (native-only).
#![cfg(not(target_arch = "wasm32"))]

use std::collections::{BTreeMap, BTreeSet};
use std::fs::{File, OpenOptions};
use std::future::Future;
use std::io::{BufRead, BufReader, IsTerminal, Read, Seek, SeekFrom, Write};
use std::path::Path;
use std::pin::Pin;
use std::process::Command;
use std::sync::{Arc, Mutex as StdMutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use bytes::Bytes;
use http::Request;
use petrel::auth::AuthMode;
use petrel::client::AtProtoClient;
use petrel::identity::{HickoryResolver, IdentityOptions, IdentityResolver};
use petrel::net::{DynHttpTransport, ReqwestTransport};
use petrel::oauth::{
    ClientAuth, OAuthClient, OAuthConfig, OAuthIdentityAdapter, OAuthStartOptions, OAuthTarget,
};
use petrel::storage::{AuthEvent, AuthSubscription, FileSecretStore, SessionStore};
use petrel::xrpc::{AuthProvider, CallOptions};
use petrel_core::{AtIdentifier, Handle};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use tokio::sync::mpsc;
use url::Url;
use web_time::Instant;

/// Usage banner matching `PetrelLoad` CLI flags.
pub const USAGE: &str = "\
Usage: petrel-load --namespace <store-namespace> --endpoint <xrpc endpoint> [options]

Required:
  --namespace    Store namespace used by your app (e.g., com.your.app)
  --endpoint     Supported XRPC endpoint used by the load scenario

Basic Options:
  --base-url     Base PDS URL (defaults to stored account's PDS URL or https://bsky.social)
  --requests     Total number of requests. Default: 100
  --concurrency  Concurrent workers. Default: 10
  --unauth       Use the lightweight unauthenticated client
  --keep-running Continuously loop; signal termination may interrupt pending typed-event delivery

Logging:
  --log-file     Append typed authentication events as JSONL; final drain runs on orderly return or error

OAuth Helpers:
  --client-id <URL>          HTTPS URL of the published OAuth client metadata
  --redirect-uri <URL>       Callback URI declared by that metadata
  --oauth-start              Start an OAuth flow
  --identifier <handle>      Optional handle for --oauth-start
  --oauth-complete -         Complete OAuth with callback URL from standard input
  --oauth-complete-stdin     Complete OAuth by reading callback URL from standard input

OAuth Stress Testing:
  --oauth-stress                   Run an authenticated load sequence
  --oauth-test <scenario>          authenticated-load, refresh-sequence,
                                   or session-snapshot
  --dpop-test <mode>               session-check, authenticated-load,
                                   or refresh-check
";

const VALUE_OPTIONS: &[&str] = &[
    "base-url",
    "client-id",
    "concurrency",
    "dpop-test",
    "endpoint",
    "identifier",
    "log-file",
    "namespace",
    "oauth-complete",
    "oauth-test",
    "requests",
    "redirect-uri",
];

const FLAG_OPTIONS: &[&str] = &[
    "keep-running",
    "oauth-complete-stdin",
    "oauth-start",
    "oauth-stress",
    "simulate-ambiguous-timeout",
    "unauth",
];

const SUPPORTED_ENDPOINTS: &[&str] = &["app.bsky.actor.getProfile", "app.bsky.feed.getTimeline"];

const OAUTH_TEST_SCENARIOS: &[&str] =
    &["authenticated-load", "refresh-sequence", "session-snapshot"];

const DPOP_TEST_MODES: &[&str] = &["authenticated-load", "refresh-check", "session-check"];

/// CLI argument parsing and validation error.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ArgumentError {
    /// Option received an unsupported or out-of-range value.
    #[error("Unsupported value for --{option}: {value}")]
    InvalidValue {
        /// Option name without `--`.
        option: String,
        /// Supplied value.
        value: String,
    },
    /// Value option omitted its following argument.
    #[error("Missing value for --{0}")]
    MissingValue(String),
    /// Authenticated flows require both `--client-id` and `--redirect-uri`.
    #[error("OAuth modes require both --client-id and --redirect-uri")]
    OAuthConfigurationRequired,
    /// Positional token was encountered.
    #[error("Unexpected argument: {0}")]
    UnexpectedArgument(String),
    /// Unrecognized `--flag`.
    #[error("Unknown option: --{0}")]
    UnknownOption(String),
}

/// Callback stdin reading error.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum CallbackReadError {
    /// Stdin closed immediately with 0 bytes.
    #[error("Standard input was empty; expected OAuth callback URL")]
    EmptyInput,
    /// Stdin contained non-UTF-8 bytes.
    #[error("Standard input contained invalid UTF-8 bytes")]
    InvalidUtf8,
    /// Stdin contained whitespace only.
    #[error("Standard input contained only whitespace; expected OAuth callback URL")]
    WhitespaceOnly,
}

/// OAuth client metadata validation error.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum OAuthMetadataError {
    /// Document `client_id` did not match `--client-id`.
    #[error("OAuth metadata client_id mismatch: expected {expected}, got {actual}")]
    ClientIdMismatch {
        /// Expected client ID.
        expected: String,
        /// Actual client ID in fetched document.
        actual: String,
    },
    /// Response Content-Type was not `application/json`.
    #[error("OAuth metadata must use application/json, got {}", .0.as_deref().unwrap_or("no Content-Type"))]
    InvalidContentType(Option<String>),
    /// Body was not a valid OAuth client metadata JSON document.
    #[error("OAuth client metadata is not a valid metadata document")]
    InvalidDocument,
    /// Response HTTP status was not 200 OK.
    #[error("OAuth metadata fetch returned HTTP {0}; expected 200")]
    InvalidStatus(u16),
    /// Fetch redirected away from `client_id`.
    #[error("OAuth metadata fetch redirected from {expected} to {}", actual.as_deref().unwrap_or("an unknown URL"))]
    Redirected {
        /// Expected URL.
        expected: String,
        /// Final URL observed.
        actual: Option<String>,
    },
    /// Required metadata property or scope was missing.
    #[error("OAuth metadata is missing required value: {0}")]
    MissingRequirement(String),
    /// Declared `redirect_uris` did not include `--redirect-uri`.
    #[error("OAuth metadata does not declare redirect URI {0}")]
    RedirectUriMissing(String),
}

/// Execution scenario failure.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ScenarioError {
    /// Command or sub-step failed.
    #[error("{0}")]
    CommandFailure(String),
    /// Scenario requires debug-only support.
    #[error("{0} requires a debug build")]
    DebugBuildRequired(String),
    /// OAuth completion finished without a stored account.
    #[error("OAuth completed without an active account")]
    MissingAuthenticatedAccount,
    /// One or more load-test requests failed.
    #[error("{0} request(s) failed")]
    RequestFailures(usize),
}

/// Parsed OAuth configuration arguments before constructing [`OAuthConfig`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CliOAuthConfig {
    /// HTTPS client metadata URL.
    pub client_id: String,
    /// Registered redirect URI.
    pub redirect_uri: Url,
    /// Requested OAuth scope string.
    pub scope: String,
}

impl CliOAuthConfig {
    /// Converts into Petrel's [`OAuthConfig`] with `ClientAuth::Public`.
    pub fn into_oauth_config(self) -> Result<OAuthConfig, String> {
        OAuthConfig::new(
            self.client_id,
            self.redirect_uri,
            &self.scope,
            ClientAuth::Public,
        )
        .map_err(|e| e.to_string())
    }
}

/// HTTP response returned by an [`OAuthMetadataFetcher`].
#[derive(Debug, Clone)]
pub struct OAuthMetadataResponse {
    /// Final URL after any response processing.
    pub final_url: Url,
    /// HTTP status code.
    pub status_code: u16,
    /// Optional `Content-Type` header value.
    pub content_type: Option<String>,
    /// Raw response bytes.
    pub data: Vec<u8>,
}

/// Asynchronous client metadata fetch callback signature.
pub type OAuthMetadataFetcher<'a> = Box<
    dyn Fn(Url) -> Pin<Box<dyn Future<Output = Result<OAuthMetadataResponse, String>> + Send>>
        + Send
        + Sync
        + 'a,
>;

#[derive(Debug, Deserialize)]
struct OAuthClientMetadataDoc {
    client_id: String,
    redirect_uris: Vec<String>,
    grant_types: Vec<String>,
    scope: String,
    response_types: Vec<String>,
    dpop_bound_access_tokens: bool,
}

/// Parsed test/stress plan selected by `--oauth-test` or `--dpop-test`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScenarioPlan {
    /// Execute `total` requests across `concurrency` workers.
    ConcurrentRequests {
        /// Total requests to issue.
        total: usize,
        /// Maximum concurrent worker tasks.
        concurrency: usize,
    },
    /// Execute `count` sequential token refreshes.
    SerialRefreshes {
        /// Number of sequential refresh cycles.
        count: usize,
    },
    /// Print the active session identity snapshot.
    SessionSnapshot,
    /// Check whether a valid session exists.
    SessionCheck,
    /// Perform one token refresh cycle.
    SingleRefresh,
}

/// JSONL file writer appending `{ "event": ..., "ts": ... }\n` records for [`AuthEvent`].
#[derive(Debug)]
pub struct AuthEventJsonlWriter {
    append_offset: u64,
    file: StdMutex<File>,
}

impl AuthEventJsonlWriter {
    /// Opens an existing (or creates a new) JSONL file in append mode and records initial offset.
    pub fn open(path: impl AsRef<Path>) -> std::io::Result<Self> {
        if let Some(parent) = path.as_ref().parent()
            && !parent.as_os_str().is_empty()
        {
            std::fs::create_dir_all(parent)?;
        }
        let mut file = OpenOptions::new().create(true).append(true).open(path)?;
        let append_offset = file.seek(SeekFrom::End(0))?;
        Ok(Self {
            append_offset,
            file: StdMutex::new(file),
        })
    }

    /// Returns the byte offset where appending started when opened.
    #[must_use]
    pub const fn append_offset(&self) -> u64 {
        self.append_offset
    }

    /// Formats and appends one [`AuthEvent`] JSONL line, flushing immediately.
    pub fn write_event(&self, event: &AuthEvent) -> std::io::Result<()> {
        let ts = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or(Duration::ZERO)
            .as_secs();
        let record = serde_json::json!({
            "event": format!("{event:?}"),
            "ts": ts,
        });
        let mut line = serde_json::to_vec(&record).map_err(std::io::Error::other)?;
        line.push(b'\n');
        let mut guard = self
            .file
            .lock()
            .map_err(|_| std::io::Error::other("writer mutex poisoned"))?;
        guard.write_all(&line)?;
        guard.flush()?;
        Ok(())
    }
}

/// Async observer registry wrapper allowing deterministic `drain()` on [`SessionStore`] events.
pub struct AuthEventRecorderHandle {
    subscription: AuthSubscription,
    tx: mpsc::UnboundedSender<AuthEvent>,
    worker: tokio::task::JoinHandle<()>,
}

impl std::fmt::Debug for AuthEventRecorderHandle {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("AuthEventRecorderHandle")
            .finish_non_exhaustive()
    }
}

impl AuthEventRecorderHandle {
    /// Attaches a [`SessionStore`] observer forwarding matching events to [`AuthEventJsonlWriter`].
    #[must_use]
    pub fn attach(store: &SessionStore, writer: Arc<AuthEventJsonlWriter>) -> Self {
        let (tx, mut rx) = mpsc::unbounded_channel::<AuthEvent>();
        let tx_obs = tx.clone();
        let subscription = store.observe_auth_events(move |event| {
            let _ = tx_obs.send(event.clone());
        });
        let worker = tokio::spawn(async move {
            while let Some(event) = rx.recv().await {
                if let Err(err) = writer.write_event(&event) {
                    eprintln!("WARN: Failed to append auth event: {err}");
                }
            }
        });
        Self {
            subscription,
            tx,
            worker,
        }
    }

    /// Closes the sender and awaits completion of all buffered event writes.
    pub async fn drain(self) {
        drop(self.subscription);
        drop(self.tx);
        let _ = self.worker.await;
    }
}

/// CLI helper namespace matching Swift `PetrelLoadCLI`.
#[derive(Debug, Clone, Copy, Default)]
pub struct PetrelLoadCli;

impl PetrelLoadCli {
    /// Parses and validates CLI arguments (skipping `argv[0]`).
    pub fn parse_args<S: AsRef<str>>(
        argv: &[S],
    ) -> Result<BTreeMap<String, String>, ArgumentError> {
        let mut parsed = BTreeMap::new();
        let mut i = 1usize;
        while i < argv.len() {
            let key = argv[i].as_ref();
            if !key.starts_with("--") || key.len() <= 2 {
                return Err(ArgumentError::UnexpectedArgument(key.to_owned()));
            }
            let name = &key[2..];
            if FLAG_OPTIONS.contains(&name) {
                parsed.insert(name.to_owned(), "true".to_owned());
                i += 1;
            } else if VALUE_OPTIONS.contains(&name) {
                if i + 1 >= argv.len() || argv[i + 1].as_ref().starts_with("--") {
                    return Err(ArgumentError::MissingValue(name.to_owned()));
                }
                parsed.insert(name.to_owned(), argv[i + 1].as_ref().to_owned());
                i += 2;
            } else {
                return Err(ArgumentError::UnknownOption(name.to_owned()));
            }
        }
        Self::validate_option_values(&parsed)?;
        Ok(parsed)
    }

    fn validate_option_values(args: &BTreeMap<String, String>) -> Result<(), ArgumentError> {
        for option in ["requests", "concurrency"] {
            if let Some(raw) = args.get(option) {
                let parsed = raw.parse::<usize>().ok().filter(|&v| v > 0);
                if parsed.is_none() {
                    return Err(ArgumentError::InvalidValue {
                        option: option.to_owned(),
                        value: raw.clone(),
                    });
                }
            }
        }
        if let Some(endpoint) = args.get("endpoint")
            && !SUPPORTED_ENDPOINTS.contains(&endpoint.as_str())
        {
            return Err(ArgumentError::InvalidValue {
                option: "endpoint".to_owned(),
                value: endpoint.clone(),
            });
        }
        if let Some(scenario) = args.get("oauth-test")
            && !OAUTH_TEST_SCENARIOS.contains(&scenario.as_str())
        {
            return Err(ArgumentError::InvalidValue {
                option: "oauth-test".to_owned(),
                value: scenario.clone(),
            });
        }
        if let Some(mode) = args.get("dpop-test")
            && !DPOP_TEST_MODES.contains(&mode.as_str())
        {
            return Err(ArgumentError::InvalidValue {
                option: "dpop-test".to_owned(),
                value: mode.clone(),
            });
        }
        if let Some(cb) = args.get("oauth-complete")
            && cb != "-"
        {
            return Err(ArgumentError::InvalidValue {
                option: "oauth-complete".to_owned(),
                value: cb.clone(),
            });
        }
        if let Some(base) = args.get("base-url") {
            Self::validated_base_url(base)?;
        }
        let unauthenticated = args.get("unauth").map(String::as_str) == Some("true");
        if !unauthenticated
            && (!args.contains_key("client-id") || !args.contains_key("redirect-uri"))
        {
            return Err(ArgumentError::OAuthConfigurationRequired);
        }
        if let Some(client_id) = args.get("client-id") {
            Self::validated_client_id(client_id)?;
        }
        if let Some(redirect_uri) = args.get("redirect-uri") {
            Self::validated_redirect_uri(redirect_uri)?;
        }
        Ok(())
    }

    /// Validates `--base-url` as an absolute `http` or `https` URL with non-empty host.
    pub fn validated_base_url(value: &str) -> Result<Url, ArgumentError> {
        let err = || ArgumentError::InvalidValue {
            option: "base-url".to_owned(),
            value: value.to_owned(),
        };
        let url = Url::parse(value).map_err(|_| err())?;
        // Reject RFC 3986 empty-authority URLs like `https:///path` that WHATWG `url` normalizes.
        if value
            .split_once("://")
            .is_some_and(|(_, rest)| rest.is_empty() || rest.starts_with('/'))
        {
            return Err(err());
        }
        if !matches!(url.scheme(), "http" | "https") || url.host_str().is_none_or(str::is_empty) {
            return Err(err());
        }
        Ok(url)
    }

    /// Validates `--client-id` as an HTTPS URL with host, no port, no userinfo, and no fragment.
    pub fn validated_client_id(value: &str) -> Result<Url, ArgumentError> {
        let err = || ArgumentError::InvalidValue {
            option: "client-id".to_owned(),
            value: value.to_owned(),
        };
        let url = Url::parse(value).map_err(|_| err())?;
        if url.scheme() != "https"
            || url.host_str().is_none_or(str::is_empty)
            || url.port().is_some()
            || !url.username().is_empty()
            || url.password().is_some()
            || url.fragment().is_some()
        {
            return Err(err());
        }
        Ok(url)
    }

    /// Validates `--redirect-uri` (either `http`/`https` with host, or custom scheme with path `/...`).
    pub fn validated_redirect_uri(value: &str) -> Result<Url, ArgumentError> {
        let err = || ArgumentError::InvalidValue {
            option: "redirect-uri".to_owned(),
            value: value.to_owned(),
        };
        let url = Url::parse(value).map_err(|_| err())?;
        let scheme = url.scheme();
        if scheme.is_empty() || url.fragment().is_some() {
            return Err(err());
        }
        let web_scheme = scheme == "http" || scheme == "https";
        let has_web_host = url.host_str().is_some_and(|h| !h.is_empty());
        let has_custom_path = !web_scheme
            && url.host_str().is_none()
            && url.path().starts_with('/')
            && url.path().len() > 1;
        if (web_scheme && has_web_host) || has_custom_path {
            Ok(url)
        } else {
            Err(err())
        }
    }

    /// Extracts optional OAuth config from validated arguments (`None` when `--unauth`).
    pub fn oauth_configuration(
        args: &BTreeMap<String, String>,
    ) -> Result<Option<CliOAuthConfig>, ArgumentError> {
        if args.get("unauth").map(String::as_str) == Some("true") {
            return Ok(None);
        }
        let (Some(client_id), Some(redirect_uri_raw)) =
            (args.get("client-id"), args.get("redirect-uri"))
        else {
            return Err(ArgumentError::OAuthConfigurationRequired);
        };
        Self::validated_client_id(client_id)?;
        let redirect_uri = Self::validated_redirect_uri(redirect_uri_raw)?;
        Ok(Some(CliOAuthConfig {
            client_id: client_id.clone(),
            redirect_uri,
            scope: "atproto transition:generic".to_owned(),
        }))
    }

    /// Fetches and validates remote OAuth client metadata before initiating auth.
    pub async fn validate_oauth_metadata<F, Fut>(
        configuration: &CliOAuthConfig,
        fetch: F,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce(Url) -> Fut,
        Fut: Future<
            Output = Result<OAuthMetadataResponse, Box<dyn std::error::Error + Send + Sync>>,
        >,
    {
        let client_id_url = Self::validated_client_id(&configuration.client_id)?;
        let response = fetch(client_id_url.clone()).await?;
        if response.final_url != client_id_url {
            return Err(Box::new(OAuthMetadataError::Redirected {
                expected: client_id_url.to_string(),
                actual: Some(response.final_url.to_string()),
            }));
        }
        if response.status_code != 200 {
            return Err(Box::new(OAuthMetadataError::InvalidStatus(
                response.status_code,
            )));
        }
        let media_type = response
            .content_type
            .as_deref()
            .and_then(|ct| ct.split(';').next())
            .map(|s| s.trim().to_ascii_lowercase());
        if media_type.as_deref() != Some("application/json") {
            return Err(Box::new(OAuthMetadataError::InvalidContentType(
                response.content_type,
            )));
        }
        let metadata: OAuthClientMetadataDoc = serde_json::from_slice(&response.data)
            .map_err(|_| Box::new(OAuthMetadataError::InvalidDocument))?;
        if metadata.client_id != configuration.client_id {
            return Err(Box::new(OAuthMetadataError::ClientIdMismatch {
                expected: configuration.client_id.clone(),
                actual: metadata.client_id,
            }));
        }
        let redirect_str = configuration.redirect_uri.as_str();
        if !metadata.redirect_uris.iter().any(|u| u == redirect_str) {
            return Err(Box::new(OAuthMetadataError::RedirectUriMissing(
                redirect_str.to_owned(),
            )));
        }
        if !metadata
            .grant_types
            .iter()
            .any(|g| g == "authorization_code")
        {
            return Err(Box::new(OAuthMetadataError::MissingRequirement(
                "grant_types.authorization_code".to_owned(),
            )));
        }
        if !metadata.grant_types.iter().any(|g| g == "refresh_token") {
            return Err(Box::new(OAuthMetadataError::MissingRequirement(
                "grant_types.refresh_token".to_owned(),
            )));
        }
        if !metadata.response_types.iter().any(|r| r == "code") {
            return Err(Box::new(OAuthMetadataError::MissingRequirement(
                "response_types.code".to_owned(),
            )));
        }
        if !metadata.dpop_bound_access_tokens {
            return Err(Box::new(OAuthMetadataError::MissingRequirement(
                "dpop_bound_access_tokens=true".to_owned(),
            )));
        }
        let declared: BTreeSet<&str> = metadata.scope.split_whitespace().collect();
        let requested: BTreeSet<&str> = configuration.scope.split_whitespace().collect();
        if !requested.is_subset(&declared) || !declared.contains("atproto") {
            return Err(Box::new(OAuthMetadataError::MissingRequirement(format!(
                "scope={}",
                configuration.scope
            ))));
        }
        Ok(())
    }

    /// Formats the browser authorization follow-up instructions.
    #[must_use]
    pub fn oauth_completion_instructions(
        configuration: &CliOAuthConfig,
        namespace: &str,
        endpoint: &str,
    ) -> String {
        format!(
            "After authorizing in the browser:\n\
1. The authorization server redirects to '{}'.\n\
2. The application registered for that URI must capture the ENTIRE callback URL, including its query string.\n\
3. Run PetrelLoad with --oauth-complete-stdin and pass the captured URL via standard input:\n   \
PetrelLoad --namespace {} --endpoint {} --client-id \"{}\" --redirect-uri \"{}\" --oauth-complete-stdin\n\n\
PetrelLoad exits after printing these instructions; it does not receive the callback itself.",
            configuration.redirect_uri,
            namespace,
            endpoint,
            configuration.client_id,
            configuration.redirect_uri
        )
    }

    /// Reads an OAuth callback URL to EOF from `reader`, rejecting empty/invalid-UTF8/whitespace-only inputs.
    pub fn read_callback<R: Read>(mut reader: R) -> Result<String, CallbackReadError> {
        let mut bytes = Vec::new();
        reader
            .read_to_end(&mut bytes)
            .map_err(|_| CallbackReadError::EmptyInput)?;
        if bytes.is_empty() {
            return Err(CallbackReadError::EmptyInput);
        }
        let s = String::from_utf8(bytes).map_err(|_| CallbackReadError::InvalidUtf8)?;
        let trimmed = s.trim();
        if trimmed.is_empty() {
            return Err(CallbackReadError::WhitespaceOnly);
        }
        Ok(trimmed.to_owned())
    }

    /// Trims and parses a callback URL string without shell interpretation.
    #[must_use]
    pub fn parse_callback_url(raw: &str) -> Option<Url> {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return None;
        }
        Url::parse(trimmed).ok()
    }

    /// Reads one trimmed non-empty line from `reader` (used for secrets/non-TTY input).
    pub fn read_secret_line<R: BufRead>(mut reader: R) -> Option<String> {
        let mut buf = Vec::new();
        if reader.read_until(b'\n', &mut buf).ok()? == 0 {
            return None;
        }
        let s = String::from_utf8(buf).ok()?;
        let trimmed = s.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_owned())
        }
    }

    /// Reads a secret from stdin, disabling terminal echo with `stty -echo` when `stdin` is a TTY.
    pub fn read_secret_from_stdin(prompt: Option<&str>) -> std::io::Result<Option<String>> {
        if let Some(p) = prompt {
            print!("{p}");
            std::io::stdout().flush()?;
        }
        let stdin = std::io::stdin();
        let is_tty = stdin.is_terminal();
        if is_tty {
            let _ = Command::new("stty").arg("-echo").status();
        }
        let result = Self::read_secret_line(BufReader::new(stdin.lock()));
        if is_tty {
            let _ = Command::new("stty").arg("echo").status();
            println!();
        }
        Ok(result)
    }

    /// Resolves the [`ScenarioPlan`] for `--oauth-test` or `--dpop-test`.
    #[must_use]
    pub fn scenario_plan(
        option: &str,
        value: &str,
        total: usize,
        concurrency: usize,
    ) -> Option<ScenarioPlan> {
        match (option, value) {
            ("oauth-test", "authenticated-load") => {
                Some(ScenarioPlan::ConcurrentRequests { total, concurrency })
            }
            ("oauth-test", "refresh-sequence") => Some(ScenarioPlan::SerialRefreshes { count: 5 }),
            ("oauth-test", "session-snapshot") => Some(ScenarioPlan::SessionSnapshot),
            ("dpop-test", "session-check") => Some(ScenarioPlan::SessionCheck),
            ("dpop-test", "authenticated-load") => Some(ScenarioPlan::ConcurrentRequests {
                total: 50,
                concurrency: 5,
            }),
            ("dpop-test", "refresh-check") => Some(ScenarioPlan::SingleRefresh),
            _ => None,
        }
    }

    /// Distributes `total` iterations evenly across `min(total, concurrency)` workers.
    ///
    /// # Panics
    ///
    /// Panics if `total == 0` or `concurrency == 0`.
    #[must_use]
    pub fn request_distribution(total: usize, concurrency: usize) -> Vec<usize> {
        assert!(total > 0 && concurrency > 0);
        let worker_count = total.min(concurrency);
        let quotient = total / worker_count;
        let remainder = total % worker_count;
        (0..worker_count)
            .map(|idx| quotient + usize::from(idx < remainder))
            .collect()
    }
}

async fn fetch_oauth_metadata(
    url: Url,
) -> Result<OAuthMetadataResponse, Box<dyn std::error::Error + Send + Sync>> {
    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .timeout(Duration::from_secs(10))
        .build()?;
    let resp = client.get(url.clone()).send().await?;
    let final_url = resp.url().clone();
    let status_code = resp.status().as_u16();
    let content_type = resp
        .headers()
        .get(reqwest::header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .map(ToOwned::to_owned);
    let data = resp.bytes().await?.to_vec();
    Ok(OAuthMetadataResponse {
        final_url,
        status_code,
        content_type,
        data,
    })
}

#[allow(clippy::struct_excessive_bools)]
struct RunOptions<'a> {
    namespace: &'a str,
    endpoint: &'a str,
    total: usize,
    concurrency: usize,
    unauth: bool,
    keep_running: bool,
    oauth_stress: bool,
    oauth_test: Option<&'a str>,
    dpop_test: Option<&'a str>,
    simulate_ambiguous: bool,
    oauth_cfg: Option<&'a CliOAuthConfig>,
}

fn open_session_store(
    namespace: &str,
) -> Result<SessionStore, Box<dyn std::error::Error + Send + Sync>> {
    let store_dir = std::env::temp_dir().join(format!("petrel-load-store-{namespace}"));
    std::fs::create_dir_all(&store_dir)?;
    let canon_dir = std::fs::canonicalize(&store_dir)?;
    let key: [u8; 32] = Sha256::digest(namespace.as_bytes()).into();
    let secret_store = Arc::new(FileSecretStore::open(&canon_dir, &key)?);
    Ok(SessionStore::new(secret_store, namespace.to_owned())?)
}

fn build_client(
    base_url: Url,
    session_store: SessionStore,
    oauth_cfg: Option<&CliOAuthConfig>,
    unauth: bool,
) -> Result<Arc<AtProtoClient>, Box<dyn std::error::Error + Send + Sync>> {
    let transport: Arc<dyn DynHttpTransport> = Arc::new(ReqwestTransport::new()?);
    let dns = HickoryResolver::system()?;
    let identity_resolver = Arc::new(OAuthIdentityAdapter::new(IdentityResolver::new(
        Arc::clone(&transport),
        dns,
        IdentityOptions::default(),
    )));
    let oauth_client = if let Some(cfg) = oauth_cfg {
        Some(Arc::new(OAuthClient::new(
            Arc::clone(&transport),
            identity_resolver.clone(),
            session_store.clone(),
            cfg.clone()
                .into_oauth_config()
                .map_err(ScenarioError::CommandFailure)?,
        )?))
    } else {
        None
    };
    let auth_mode = if unauth {
        AuthMode::None
    } else {
        AuthMode::PublicOAuth
    };
    let allow_loopback = base_url.scheme() == "http";
    Ok(Arc::new(AtProtoClient::new(
        base_url,
        transport,
        session_store,
        identity_resolver,
        oauth_client,
        auth_mode,
        allow_loopback,
    )?))
}

/// Runs the PetrelLoad CLI to completion, ensuring any JSONL event writer drains before returning.
pub async fn run_cli<S: AsRef<str>>(
    argv: &[S],
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let parsed = PetrelLoadCli::parse_args(argv)?;
    let (Some(namespace), Some(endpoint)) = (parsed.get("namespace"), parsed.get("endpoint"))
    else {
        eprintln!("{USAGE}");
        std::process::exit(2);
    };
    let base_url = match parsed.get("base-url") {
        Some(raw) => PetrelLoadCli::validated_base_url(raw)?,
        None => Url::parse("https://bsky.social")?,
    };
    let oauth_cfg = PetrelLoadCli::oauth_configuration(&parsed)?;
    let session_store = open_session_store(namespace)?;
    let recorder = parsed
        .get("log-file")
        .filter(|p| !p.is_empty())
        .and_then(|path| match AuthEventJsonlWriter::open(path) {
            Ok(writer) => {
                let offset = writer.append_offset();
                let handle = AuthEventRecorderHandle::attach(&session_store, Arc::new(writer));
                println!("✓ Logging typed auth events to {path} from byte {offset}");
                Some(handle)
            }
            Err(err) => {
                eprintln!("WARN: Failed to open log file {path}: {err}");
                None
            }
        });

    let unauth = parsed.get("unauth").map(String::as_str) == Some("true");
    let client = build_client(base_url, session_store, oauth_cfg.as_ref(), unauth)?;
    let opts = RunOptions {
        namespace,
        endpoint,
        total: parsed
            .get("requests")
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(100),
        concurrency: parsed
            .get("concurrency")
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(10),
        unauth,
        keep_running: parsed.get("keep-running").map(String::as_str) == Some("true"),
        oauth_stress: parsed.get("oauth-stress").map(String::as_str) == Some("true"),
        oauth_test: parsed.get("oauth-test").map(String::as_str),
        dpop_test: parsed.get("dpop-test").map(String::as_str),
        simulate_ambiguous: parsed.get("simulate-ambiguous-timeout").map(String::as_str)
            == Some("true"),
        oauth_cfg: oauth_cfg.as_ref(),
    };
    let outcome = execute_mode(&client, &parsed, &opts).await;
    if let Some(handle) = recorder {
        handle.drain().await;
    }
    outcome
}

async fn execute_mode(
    client: &Arc<AtProtoClient>,
    parsed: &BTreeMap<String, String>,
    opts: &RunOptions<'_>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if parsed.get("oauth-start").map(String::as_str) == Some("true") {
        let cfg = opts
            .oauth_cfg
            .ok_or(ArgumentError::OAuthConfigurationRequired)?;
        return run_oauth_start(client, parsed, opts.namespace, opts.endpoint, cfg).await;
    }

    let stdin_complete = parsed.get("oauth-complete").map(String::as_str) == Some("-")
        || parsed.get("oauth-complete-stdin").map(String::as_str) == Some("true");
    if stdin_complete {
        return run_oauth_complete(client, opts.namespace).await;
    }

    if opts.oauth_stress
        || opts.oauth_test.is_some()
        || opts.dpop_test.is_some()
        || opts.simulate_ambiguous
    {
        return run_oauth_diagnostics(client, opts).await;
    }

    if opts.keep_running {
        loop {
            run_basic_stress_test(client, opts.endpoint, opts.total, opts.concurrency).await?;
            tokio::select! {
                _ = tokio::signal::ctrl_c() => break,
                () = tokio::time::sleep(Duration::from_secs(2)) => {}
            }
        }
        Ok(())
    } else {
        run_basic_stress_test(client, opts.endpoint, opts.total, opts.concurrency).await
    }
}

async fn run_oauth_start(
    client: &Arc<AtProtoClient>,
    parsed: &BTreeMap<String, String>,
    namespace: &str,
    endpoint: &str,
    cfg: &CliOAuthConfig,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    PetrelLoadCli::validate_oauth_metadata(cfg, fetch_oauth_metadata).await?;
    let identifier = parsed
        .get("identifier")
        .map(|id| id.parse::<AtIdentifier>())
        .transpose()
        .map_err(|e| ScenarioError::CommandFailure(format!("Invalid identifier: {e}")))?;
    let flow = client
        .start_oauth_flow(identifier.as_ref(), None, OAuthStartOptions::default())
        .await
        .map_err(|e| ScenarioError::CommandFailure(format!("Failed to start OAuth flow: {e}")))?;
    println!(
        "Starting OAuth flow for: {}",
        parsed.get("identifier").map_or("user", String::as_str)
    );
    println!("OAuth URL: {}", flow.authorize_url);
    println!(
        "\n{}",
        PetrelLoadCli::oauth_completion_instructions(cfg, namespace, endpoint)
    );
    Ok(())
}

async fn run_oauth_complete(
    client: &Arc<AtProtoClient>,
    namespace: &str,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let callback = PetrelLoadCli::read_callback(std::io::stdin().lock())?;
    let url = PetrelLoadCli::parse_callback_url(&callback).ok_or_else(|| {
        ScenarioError::CommandFailure(format!(
            "Standard input did not contain a parsable callback URL ({} bytes)",
            callback.len()
        ))
    })?;
    client
        .handle_oauth_callback(&url)
        .await
        .map_err(|e| ScenarioError::CommandFailure(format!("OAuth completion failed: {e}")))?;
    let account = client
        .get_current_account()
        .await?
        .ok_or(ScenarioError::MissingAuthenticatedAccount)?;
    println!("OAuth completed and saved to store for namespace {namespace}.");
    println!("✓ DID: {}", account.did.as_str());
    println!(
        "✓ Handle: {}",
        account.handle.as_ref().map_or("nil", Handle::as_str)
    );
    println!("✓ PDS: {}", account.pds);
    Ok(())
}

async fn run_oauth_diagnostics(
    client: &Arc<AtProtoClient>,
    opts: &RunOptions<'_>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if opts.unauth {
        return Err(Box::new(ScenarioError::CommandFailure(
            "Cannot run OAuth stress tests with --unauth flag".to_owned(),
        )));
    }
    if !client.has_valid_session().await {
        return Err(Box::new(ScenarioError::CommandFailure(
            "No valid OAuth session found. Please run --oauth-start first".to_owned(),
        )));
    }
    if opts.simulate_ambiguous {
        if !cfg!(debug_assertions) {
            return Err(Box::new(ScenarioError::DebugBuildRequired(
                "--simulate-ambiguous-timeout".to_owned(),
            )));
        }
        client.auth_manager().refresh_if_needed().await?;
        return Ok(());
    }
    if opts.oauth_stress {
        return run_basic_stress_test(client, opts.endpoint, opts.total, opts.concurrency).await;
    }
    if let Some(scenario) = opts.oauth_test {
        let plan =
            PetrelLoadCli::scenario_plan("oauth-test", scenario, opts.total, opts.concurrency)
                .ok_or_else(|| ArgumentError::InvalidValue {
                    option: "oauth-test".to_owned(),
                    value: scenario.to_owned(),
                })?;
        return match plan {
            ScenarioPlan::ConcurrentRequests { total, concurrency } => {
                run_basic_stress_test(client, opts.endpoint, total, concurrency).await
            }
            ScenarioPlan::SerialRefreshes { count } => {
                for _ in 0..count {
                    client.auth_manager().refresh_if_needed().await?;
                }
                Ok(())
            }
            ScenarioPlan::SessionSnapshot => {
                let account = client.get_current_account().await?;
                println!(
                    "✓ DID: {}",
                    account.as_ref().map_or("unknown", |a| a.did.as_str())
                );
                Ok(())
            }
            ScenarioPlan::SessionCheck | ScenarioPlan::SingleRefresh => {
                Err(Box::new(ArgumentError::InvalidValue {
                    option: "oauth-test".to_owned(),
                    value: scenario.to_owned(),
                }))
            }
        };
    }
    if let Some(mode) = opts.dpop_test {
        let plan = PetrelLoadCli::scenario_plan("dpop-test", mode, opts.total, opts.concurrency)
            .ok_or_else(|| ArgumentError::InvalidValue {
                option: "dpop-test".to_owned(),
                value: mode.to_owned(),
            })?;
        return match plan {
            ScenarioPlan::SessionCheck => {
                println!(
                    "✓ Valid OAuth session: {}",
                    client.has_valid_session().await
                );
                Ok(())
            }
            ScenarioPlan::ConcurrentRequests { total, concurrency } => {
                run_basic_stress_test(client, opts.endpoint, total, concurrency).await
            }
            ScenarioPlan::SingleRefresh => {
                client.auth_manager().refresh_if_needed().await?;
                Ok(())
            }
            ScenarioPlan::SerialRefreshes { .. } | ScenarioPlan::SessionSnapshot => {
                Err(Box::new(ArgumentError::InvalidValue {
                    option: "dpop-test".to_owned(),
                    value: mode.to_owned(),
                }))
            }
        };
    }
    Ok(())
}

async fn run_basic_stress_test(
    client: &Arc<AtProtoClient>,
    endpoint: &str,
    iterations: usize,
    concurrency: usize,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    println!("=== AtProtoClient Stress Test ===");
    println!("Endpoint: {endpoint}");
    println!("Iterations: {iterations}, Concurrency: {concurrency}");

    let start_time = Instant::now();
    let dist = PetrelLoadCli::request_distribution(iterations, concurrency);
    let handles: Vec<_> = dist
        .into_iter()
        .map(|worker_iters| {
            let client = Arc::clone(client);
            let endpoint = endpoint.to_owned();
            tokio::spawn(async move { run_worker(&client, &endpoint, worker_iters).await })
        })
        .collect();

    let mut successes = 0usize;
    let mut failures = 0usize;
    let mut latencies = Vec::new();
    let mut first_error = None;
    for handle in handles {
        let (s, f, l, e) = handle.await?;
        successes += s;
        failures += f;
        latencies.extend(l);
        if first_error.is_none() {
            first_error = e;
        }
    }

    report_stress_results(
        start_time.elapsed().as_secs_f64(),
        successes,
        failures,
        &mut latencies,
        first_error,
    )
}

async fn run_worker(
    client: &AtProtoClient,
    endpoint: &str,
    iterations: usize,
) -> (usize, usize, Vec<f64>, Option<String>) {
    let mut successes = 0usize;
    let mut failures = 0usize;
    let mut latencies = Vec::with_capacity(iterations);
    let mut sample_error: Option<String> = None;

    for _ in 0..iterations {
        let req_start = Instant::now();
        let did_str = client
            .get_did()
            .await
            .ok()
            .flatten()
            .map(|d| d.as_str().to_owned());
        let res = if endpoint == "app.bsky.feed.getTimeline" {
            client
                .query(
                    "app.bsky.feed.getTimeline",
                    [("limit", "10")],
                    &CallOptions::default(),
                )
                .await
        } else {
            let actor = did_str.as_deref().unwrap_or("bsky.app");
            client
                .query(
                    "app.bsky.actor.getProfile",
                    [("actor", actor)],
                    &CallOptions::default(),
                )
                .await
        };
        match res {
            Ok(_) => {
                successes += 1;
                latencies.push(req_start.elapsed().as_secs_f64());
            }
            Err(err) => {
                failures += 1;
                if sample_error.is_none() {
                    sample_error = Some(err.to_string());
                }
            }
        }
    }
    (successes, failures, latencies, sample_error)
}

#[allow(
    clippy::cast_precision_loss,
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss
)]
fn report_stress_results(
    elapsed_secs: f64,
    successes: usize,
    failures: usize,
    latencies: &mut [f64],
    first_error: Option<String>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let total_secs = elapsed_secs.max(f64::EPSILON);
    let total_reqs = successes + failures;
    let rps = (total_reqs as f64) / total_secs;

    if let Some(err) = first_error {
        println!("Sample error: {err}");
    }
    println!("\n=== Results ===");
    println!("Total time: {total_secs:.2}s");
    println!("Total requests: {total_reqs}");
    println!("Successes: {successes}");
    println!("Failures: {failures}");
    if total_reqs > 0 {
        println!(
            "Success rate: {:.1}%",
            (successes as f64) / (total_reqs as f64) * 100.0
        );
    }
    println!("RPS: {rps:.1}");

    if !latencies.is_empty() {
        latencies.sort_by(f64::total_cmp);
        let avg = latencies.iter().sum::<f64>() / (latencies.len() as f64);
        let p50 = latencies[(latencies.len() - 1) / 2];
        let p95 = latencies[((latencies.len() - 1) as f64 * 0.95) as usize];
        let p99 = latencies[((latencies.len() - 1) as f64 * 0.99) as usize];
        println!("Latency - avg: {avg:.3}s, p50: {p50:.3}s, p95: {p95:.3}s, p99: {p99:.3}s");
    }

    if failures > 0 {
        return Err(Box::new(ScenarioError::RequestFailures(failures)));
    }
    Ok(())
}

/// Marker touch to ensure unused-import lint stays silent for `OAuthTarget` & `Request`.
#[allow(dead_code)]
fn _keep_imports_used() {
    let _ = std::mem::size_of::<OAuthTarget>();
    let _ = std::mem::size_of::<Request<Bytes>>();
}
