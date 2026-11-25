//! Explicit, process-local qualification transport and CONNECT tunnel for local fixtures.
//!
//! Nothing activates implicitly from environment variables or defaults. Callers must
//! construct a [`HostPolicy`] and load a validated manifest explicitly.

use std::{
    collections::{BTreeMap, BTreeSet},
    io::{Read, Write},
    net::{Ipv4Addr, SocketAddr, TcpListener, TcpStream},
    sync::{
        Arc, Mutex, OnceLock,
        atomic::{AtomicBool, Ordering},
    },
    thread,
    time::Duration,
};

use base64::{Engine, engine::general_purpose::STANDARD as BASE64_STANDARD};
use sha2::{Digest, Sha256};
use url::Url;

const MAX_MANIFEST_BYTES: usize = 16_384;
const MAX_CERT_BYTES: usize = 16_384;
const MAX_CONNECT_HEADER_BYTES: usize = 8_192;
const MAX_TUNNELS: usize = 32;

/// Errors returned while validating fixture policies, manifests, URLs, or tunnels.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum DebugFixtureError {
    /// Invalid host policy, manifest shape, duplicate JSON keys, or invalid certificate bytes.
    #[error("invalid debug fixture configuration: {0}")]
    InvalidConfiguration(&'static str),
    /// Process-global fixture transport was already installed.
    #[error("debug fixture transport is already installed")]
    AlreadyInstalled,
    /// Listener or local relay is unavailable.
    #[error("debug fixture transport unavailable: {0}")]
    Unavailable(&'static str),
    /// Target URL or HTTP `CONNECT` request rejected by fixture policy.
    #[error("debug fixture target rejected: {0}")]
    Rejected(&'static str),
    /// Socket / IO error inside tunnel relay.
    #[error("debug fixture connection error: {0}")]
    Connection(String),
}

/// Caller-supplied domain and host policy controlling which hosts a fixture manifest may serve.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HostPolicy {
    fixture_domain: String,
    additional_hosts: BTreeSet<String>,
    service_labels: BTreeSet<String>,
}

impl HostPolicy {
    /// Creates a validated [`HostPolicy`].
    pub fn new(
        fixture_domain: &str,
        additional_hosts: impl IntoIterator<Item = String>,
        service_labels: impl IntoIterator<Item = String>,
    ) -> Result<Self, DebugFixtureError> {
        if !is_lowercase_dns_name(fixture_domain) {
            return Err(DebugFixtureError::InvalidConfiguration(
                "invalid fixture domain",
            ));
        }
        let additional: BTreeSet<String> = additional_hosts.into_iter().collect();
        for host in &additional {
            if !is_lowercase_dns_name(host) {
                return Err(DebugFixtureError::InvalidConfiguration(
                    "invalid additional host",
                ));
            }
            if host == fixture_domain
                || host
                    .strip_suffix(fixture_domain)
                    .is_some_and(|prefix| prefix.ends_with('.'))
            {
                return Err(DebugFixtureError::InvalidConfiguration(
                    "additional host must not lie inside fixture domain",
                ));
            }
        }
        let labels: BTreeSet<String> = service_labels.into_iter().collect();
        if labels.len() > 8 {
            return Err(DebugFixtureError::InvalidConfiguration(
                "too many service labels",
            ));
        }
        for label in &labels {
            if label.is_empty()
                || label.len() > 20
                || matches!(label.as_str(), "gateway" | "alice" | "bob")
                || !label
                    .bytes()
                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit())
            {
                return Err(DebugFixtureError::InvalidConfiguration(
                    "invalid service label",
                ));
            }
        }
        Ok(Self {
            fixture_domain: fixture_domain.to_owned(),
            additional_hosts: additional,
            service_labels: labels,
        })
    }

    /// Returns the configured base fixture domain.
    #[must_use]
    pub fn fixture_domain(&self) -> &str {
        &self.fixture_domain
    }

    /// Returns additional hosts permitted outside `fixture_domain`.
    #[must_use]
    pub const fn additional_hosts(&self) -> &BTreeSet<String> {
        &self.additional_hosts
    }

    /// Returns local numbered service labels derived from the gateway run suffix.
    #[must_use]
    pub const fn service_labels(&self) -> &BTreeSet<String> {
        &self.service_labels
    }

    /// Returns `true` if `host` is a valid lowercase subdomain of `fixture_domain`.
    #[must_use]
    pub fn is_fixture_host(&self, host: &str) -> bool {
        host.len() < 254
            && host
                .strip_suffix(&self.fixture_domain)
                .is_some_and(|prefix| prefix.ends_with('.'))
            && is_lowercase_dns_name(host)
    }
}

/// Account identity declared inside a fixture manifest.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FixtureAccount {
    /// `"alice"` or `"bob"`.
    pub label: String,
    /// `did:web:...` bound to the account fixture host.
    pub did: String,
    /// Lowercase UUIDv4/canonical UUID string.
    pub device_id: String,
}

static INSTALLATION_STARTED: AtomicBool = AtomicBool::new(false);
static INSTALLED: OnceLock<Arc<DebugFixtureTransport>> = OnceLock::new();

/// Process-local qualification fixture validator and loopback `CONNECT` relay.
#[derive(Debug)]
pub struct DebugFixtureTransport {
    identity: String,
    origin: Url,
    accounts: Vec<FixtureAccount>,
    ports: BTreeMap<String, u16>,
    certificate_der: Vec<u8>,
    proxy_port: u16,
    shutdown: Arc<AtomicBool>,
}

impl Drop for DebugFixtureTransport {
    fn drop(&mut self) {
        self.shutdown.store(true, Ordering::Relaxed);
    }
}

impl DebugFixtureTransport {
    /// Installs a single immutable process-wide fixture transport. Subsequent attempts fail.
    pub fn install(
        manifest: &[u8],
        certificate_der: &[u8],
        host_policy: &HostPolicy,
    ) -> Result<Arc<Self>, DebugFixtureError> {
        if INSTALLATION_STARTED.swap(true, Ordering::SeqCst) {
            return Err(DebugFixtureError::AlreadyInstalled);
        }
        let transport = Arc::new(Self::from_manifest(manifest, certificate_der, host_policy)?);
        let _ = INSTALLED.set(Arc::clone(&transport));
        Ok(transport)
    }

    /// Returns the currently installed process-global fixture transport, if any.
    #[must_use]
    pub fn current() -> Option<Arc<Self>> {
        INSTALLED.get().cloned()
    }

    /// Parses and validates a manifest + DER certificate without modifying global state.
    pub fn from_manifest(
        manifest: &[u8],
        certificate_der: &[u8],
        host_policy: &HostPolicy,
    ) -> Result<Self, DebugFixtureError> {
        if manifest.len() > MAX_MANIFEST_BYTES
            || certificate_der.is_empty()
            || certificate_der.len() > MAX_CERT_BYTES
        {
            return Err(DebugFixtureError::InvalidConfiguration(
                "manifest or certificate exceeds bounds",
            ));
        }

        let root = FixtureJsonValue::parse(manifest)?;
        let FixtureJsonValue::Object(object) = root else {
            return Err(DebugFixtureError::InvalidConfiguration(
                "manifest root must be an object",
            ));
        };

        let (origin, host) = validate_manifest_header(&object, host_policy)?;
        let (accounts, allowed_hosts) = validate_manifest_accounts(&object, &host, host_policy)?;
        let ports = validate_manifest_hosts(&object, &allowed_hosts)?;

        let mut hasher = Sha256::new();
        hasher.update(manifest);
        hasher.update(certificate_der);
        let identity = hasher
            .finalize()
            .iter()
            .fold(String::with_capacity(64), |mut acc, byte| {
                use std::fmt::Write as _;
                let _ = write!(acc, "{byte:02x}");
                acc
            });

        let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0))
            .map_err(|error| DebugFixtureError::Connection(error.to_string()))?;
        let proxy_port = listener
            .local_addr()
            .map_err(|error| DebugFixtureError::Connection(error.to_string()))?
            .port();
        let shutdown = Arc::new(AtomicBool::new(false));
        spawn_tunnel_accept_loop(listener, ports.clone(), Arc::clone(&shutdown));

        Ok(Self {
            identity,
            origin,
            accounts,
            ports,
            certificate_der: certificate_der.to_vec(),
            proxy_port,
            shutdown,
        })
    }

    /// SHA-256 hex digest binding manifest + certificate DER.
    #[must_use]
    pub fn identity(&self) -> &str {
        &self.identity
    }

    /// Validated fixture gateway origin URL.
    #[must_use]
    pub const fn origin(&self) -> &Url {
        &self.origin
    }

    /// Validated fixture accounts.
    #[must_use]
    pub fn accounts(&self) -> &[FixtureAccount] {
        &self.accounts
    }

    /// Configured host -> loopback port mapping.
    #[must_use]
    pub const fn ports(&self) -> &BTreeMap<String, u16> {
        &self.ports
    }

    /// Localhost port listening for HTTP `CONNECT` tunnel requests.
    #[must_use]
    pub const fn proxy_port(&self) -> u16 {
        self.proxy_port
    }

    /// DER bytes of the configured fixture CA/leaf certificate.
    #[must_use]
    pub fn certificate_der(&self) -> &[u8] {
        &self.certificate_der
    }

    /// Returns `true` if `url` is an HTTPS URL for an authorized fixture host without
    /// userinfo, custom port, fragment, or backslashes.
    #[must_use]
    pub fn permits(&self, url: &Url) -> bool {
        if url.scheme() != "https"
            || !url.username().is_empty()
            || url.password().is_some()
            || url.port().is_some()
            || url.fragment().is_some()
            || url.as_str().contains('\\')
        {
            return false;
        }
        let Some(host) = url.host_str() else {
            return false;
        };
        host == host.to_ascii_lowercase() && self.ports.contains_key(host)
    }

    /// Returns approved loopback addresses for `url` after verifying [`Self::permits`].
    pub fn approved_addresses(&self, url: &Url) -> Result<Vec<SocketAddr>, DebugFixtureError> {
        if !self.permits(url) {
            return Err(DebugFixtureError::Rejected("URL outside fixture policy"));
        }
        let host = url
            .host_str()
            .ok_or(DebugFixtureError::Rejected("URL missing host"))?;
        let port = self
            .ports
            .get(host)
            .copied()
            .ok_or(DebugFixtureError::Rejected("unknown fixture host"))?;
        Ok(vec![SocketAddr::from((Ipv4Addr::LOCALHOST, port))])
    }
}

/// Validates HTTP `CONNECT <host>:443 HTTP/1.1` tunnel request headers.
#[derive(Debug, Clone, Copy)]
pub struct FixtureTunnel;

impl FixtureTunnel {
    /// Parses and validates a raw `CONNECT ... \r\n\r\n` block, returning the lowercase hostname.
    pub fn authority(data: &[u8]) -> Result<String, DebugFixtureError> {
        if data.len() > MAX_CONNECT_HEADER_BYTES || !data.is_ascii() {
            return Err(DebugFixtureError::Rejected(
                "oversized or non-ASCII CONNECT",
            ));
        }
        let text = std::str::from_utf8(data)
            .map_err(|_| DebugFixtureError::Rejected("invalid UTF-8 CONNECT"))?;
        let Some(end_idx) = text.find("\r\n\r\n") else {
            return Err(DebugFixtureError::Rejected("unterminated CONNECT headers"));
        };
        if end_idx + 4 != text.len() {
            return Err(DebugFixtureError::Rejected(
                "trailing bytes after CONNECT headers",
            ));
        }

        let mut lines = text[..end_idx].split("\r\n");
        let first = lines
            .next()
            .ok_or(DebugFixtureError::Rejected("missing request line"))?;
        let words: Vec<&str> = first.split(' ').collect();
        if words.len() != 3 || words[0] != "CONNECT" || words[2] != "HTTP/1.1" {
            return Err(DebugFixtureError::Rejected("invalid CONNECT request line"));
        }
        let authority = words[1];
        let Some(host) = authority.strip_suffix(":443") else {
            return Err(DebugFixtureError::Rejected("CONNECT port must be :443"));
        };
        if host.is_empty()
            || host != host.to_ascii_lowercase()
            || !host
                .bytes()
                .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-' || b == b'.')
            || host.contains("..")
            || host.starts_with('.')
            || host.ends_with('.')
            || !host.bytes().any(|b| b.is_ascii_alphabetic())
        {
            return Err(DebugFixtureError::Rejected("invalid CONNECT hostname"));
        }

        let mut seen_names = BTreeSet::new();
        let mut saw_host = false;
        for line in lines {
            let Some((raw_name, raw_value)) = line.split_once(':') else {
                return Err(DebugFixtureError::Rejected("malformed header line"));
            };
            let name = raw_name.to_ascii_lowercase();
            let value = raw_value.trim_matches(|c: char| c == ' ' || c == '\t');
            if !matches!(
                name.as_str(),
                "host" | "user-agent" | "proxy-connection" | "connection"
            ) || !seen_names.insert(name.clone())
                || value.contains('\r')
                || value.contains('\n')
            {
                return Err(DebugFixtureError::Rejected("disallowed CONNECT header"));
            }
            if name == "host" {
                if value != authority && value != host {
                    return Err(DebugFixtureError::Rejected("Host header mismatch"));
                }
                saw_host = true;
            }
        }
        if !saw_host {
            return Err(DebugFixtureError::Rejected("missing Host header"));
        }
        Ok(host.to_owned())
    }
}

fn spawn_tunnel_accept_loop(
    listener: TcpListener,
    ports: BTreeMap<String, u16>,
    shutdown: Arc<AtomicBool>,
) {
    let active = Arc::new(Mutex::new(0_usize));
    let _ = listener.set_nonblocking(true);
    let _ = thread::Builder::new()
        .name("petrel-fixture-tunnel".to_owned())
        .spawn(move || {
            while !shutdown.load(Ordering::Relaxed) {
                match listener.accept() {
                    Ok((stream, _)) => {
                        let can_accept = {
                            let mut guard = active
                                .lock()
                                .unwrap_or_else(std::sync::PoisonError::into_inner);
                            if *guard < MAX_TUNNELS {
                                *guard += 1;
                                true
                            } else {
                                false
                            }
                        };
                        if !can_accept {
                            drop(stream);
                            continue;
                        }
                        let ports = ports.clone();
                        let active = Arc::clone(&active);
                        let _ = thread::spawn(move || {
                            handle_tunnel_connection(stream, &ports);
                            if let Ok(mut guard) = active.lock() {
                                *guard = guard.saturating_sub(1);
                            }
                        });
                    }
                    Err(err) if err.kind() == std::io::ErrorKind::WouldBlock => {
                        thread::sleep(Duration::from_millis(10));
                    }
                    Err(_) => break,
                }
            }
        });
}

fn handle_tunnel_connection(mut client: TcpStream, ports: &BTreeMap<String, u16>) {
    let _ = client.set_nonblocking(false);
    let _ = client.set_read_timeout(Some(Duration::from_secs(10)));
    let _ = client.set_write_timeout(Some(Duration::from_secs(10)));
    let mut buf = Vec::with_capacity(512);
    let mut byte = [0_u8; 1024];
    loop {
        match client.read(&mut byte) {
            Ok(0) | Err(_) => return,
            Ok(n) => {
                buf.extend_from_slice(&byte[..n]);
                if buf.len() > MAX_CONNECT_HEADER_BYTES {
                    return;
                }
                if buf.windows(4).any(|w| w == b"\r\n\r\n") {
                    break;
                }
            }
        }
    }
    let Ok(host) = FixtureTunnel::authority(&buf) else {
        return;
    };
    let Some(&port) = ports.get(&host) else {
        return;
    };
    let Ok(upstream) = TcpStream::connect((Ipv4Addr::LOCALHOST, port)) else {
        return;
    };
    if client
        .write_all(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        .is_err()
    {
        return;
    }
    let _ = client.set_read_timeout(Some(Duration::from_secs(120)));
    let _ = upstream.set_read_timeout(Some(Duration::from_secs(120)));
    let (Ok(mut c_read), Ok(mut u_write)) = (client.try_clone(), upstream.try_clone()) else {
        return;
    };
    let forward = thread::spawn(move || {
        let _ = std::io::copy(&mut c_read, &mut u_write);
    });
    let mut u_read = upstream;
    let mut c_write = client;
    let _ = std::io::copy(&mut u_read, &mut c_write);
    let _ = forward.join();
}

/// Validates a lowercase DNS hostname as used by [`HostPolicy`].
#[must_use]
pub fn is_lowercase_dns_name(host: &str) -> bool {
    !host.is_empty()
        && host.len() < 254
        && host == host.to_ascii_lowercase()
        && host
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-' || b == b'.')
        && !host.contains("..")
        && !host.starts_with('.')
        && !host.starts_with('-')
        && !host.ends_with('.')
}

fn is_canonical_lowercase_uuid(value: &str) -> bool {
    let bytes = value.as_bytes();
    if bytes.len() != 36 {
        return false;
    }
    for (idx, &b) in bytes.iter().enumerate() {
        if matches!(idx, 8 | 13 | 18 | 23) {
            if b != b'-' {
                return false;
            }
        } else if !matches!(b, b'0'..=b'9' | b'a'..=b'f') {
            return false;
        }
    }
    true
}

fn validate_manifest_header(
    object: &BTreeMap<String, FixtureJsonValue>,
    host_policy: &HostPolicy,
) -> Result<(Url, String), DebugFixtureError> {
    let expected_keys: BTreeSet<&str> = [
        "fixtureOnly",
        "origin",
        "corsOrigin",
        "caPem",
        "tlsCertificatePem",
        "tlsSpkiSha256",
        "hosts",
        "accounts",
    ]
    .into_iter()
    .collect();
    let actual_keys: BTreeSet<&str> = object.keys().map(String::as_str).collect();
    if actual_keys != expected_keys
        || object.get("fixtureOnly") != Some(&FixtureJsonValue::Bool(true))
    {
        return Err(DebugFixtureError::InvalidConfiguration(
            "manifest keys mismatch or fixtureOnly != true",
        ));
    }

    let origin_str = as_str(object.get("origin"))?;
    let origin = Url::parse(origin_str)
        .map_err(|_| DebugFixtureError::InvalidConfiguration("invalid origin URL"))?;
    let host = origin
        .host_str()
        .ok_or(DebugFixtureError::InvalidConfiguration(
            "origin missing host",
        ))?
        .to_owned();
    if origin_str != format!("https://{host}")
        || !host_policy.is_fixture_host(&host)
        || !host.starts_with("gateway-")
        || host_policy.additional_hosts.contains(&host)
    {
        return Err(DebugFixtureError::InvalidConfiguration(
            "invalid gateway origin",
        ));
    }

    let ca_path = as_str(object.get("caPem"))?;
    let leaf_path = as_str(object.get("tlsCertificatePem"))?;
    if !ca_path.starts_with('/') || !leaf_path.starts_with('/') {
        return Err(DebugFixtureError::InvalidConfiguration(
            "PEM paths must be absolute",
        ));
    }

    let spki = as_str(object.get("tlsSpkiSha256"))?;
    let spki_bytes = BASE64_STANDARD
        .decode(spki)
        .map_err(|_| DebugFixtureError::InvalidConfiguration("invalid tlsSpkiSha256"))?;
    if spki_bytes.len() != 32 || BASE64_STANDARD.encode(&spki_bytes) != spki {
        return Err(DebugFixtureError::InvalidConfiguration(
            "tlsSpkiSha256 must be canonical 32-byte base64",
        ));
    }

    let cors_str = as_str(object.get("corsOrigin"))?;
    let cors = Url::parse(cors_str)
        .map_err(|_| DebugFixtureError::InvalidConfiguration("invalid corsOrigin"))?;
    let expected_cors_prefix = match cors.port() {
        Some(port) => format!(
            "{}://{}:{}",
            cors.scheme(),
            cors.host_str().unwrap_or(""),
            port
        ),
        None => format!("{}://{}", cors.scheme(), cors.host_str().unwrap_or("")),
    };
    if !matches!(cors.scheme(), "http" | "https")
        || !matches!(cors.host_str(), Some("127.0.0.1" | "localhost" | "[::1]"))
        || !cors.username().is_empty()
        || cors.password().is_some()
        || cors.query().is_some()
        || cors.fragment().is_some()
        || cors_str != expected_cors_prefix
    {
        return Err(DebugFixtureError::InvalidConfiguration(
            "corsOrigin must be loopback origin without path",
        ));
    }

    Ok((origin, host))
}

fn validate_manifest_accounts(
    object: &BTreeMap<String, FixtureJsonValue>,
    gateway_host: &str,
    host_policy: &HostPolicy,
) -> Result<(Vec<FixtureAccount>, BTreeSet<String>), DebugFixtureError> {
    let Some(FixtureJsonValue::Array(raw_accounts)) = object.get("accounts") else {
        return Err(DebugFixtureError::InvalidConfiguration(
            "accounts must be an array",
        ));
    };
    if raw_accounts.len() != 2 {
        return Err(DebugFixtureError::InvalidConfiguration(
            "accounts must have exactly 2 entries",
        ));
    }

    let run_suffix = &gateway_host["gateway-".len()..];
    let mut allowed_hosts = host_policy.additional_hosts.clone();
    for label in &host_policy.service_labels {
        allowed_hosts.insert(format!("{label}-{run_suffix}"));
    }
    allowed_hosts.insert(gateway_host.to_owned());

    let mut accounts = Vec::with_capacity(2);
    let account_keys: BTreeSet<&str> = ["label", "did", "deviceId"].into_iter().collect();
    for item in raw_accounts {
        let FixtureJsonValue::Object(row) = item else {
            return Err(DebugFixtureError::InvalidConfiguration(
                "account entry must be an object",
            ));
        };
        let keys: BTreeSet<&str> = row.keys().map(String::as_str).collect();
        if keys != account_keys {
            return Err(DebugFixtureError::InvalidConfiguration(
                "account keys mismatch",
            ));
        }
        let label = as_str(row.get("label"))?;
        if !matches!(label, "alice" | "bob")
            || accounts.iter().any(|a: &FixtureAccount| a.label == label)
        {
            return Err(DebugFixtureError::InvalidConfiguration(
                "invalid or duplicate account label",
            ));
        }
        let did = as_str(row.get("did"))?;
        let Some(account_host) = did.strip_prefix("did:web:") else {
            return Err(DebugFixtureError::InvalidConfiguration(
                "account did must be did:web",
            ));
        };
        if !host_policy.is_fixture_host(account_host)
            || !account_host.starts_with(&format!("{label}-"))
            || allowed_hosts.contains(account_host)
        {
            return Err(DebugFixtureError::InvalidConfiguration(
                "account did host violates policy",
            ));
        }
        let device_id = as_str(row.get("deviceId"))?;
        if !is_canonical_lowercase_uuid(device_id) {
            return Err(DebugFixtureError::InvalidConfiguration(
                "invalid lowercase deviceId UUID",
            ));
        }
        allowed_hosts.insert(account_host.to_owned());
        accounts.push(FixtureAccount {
            label: label.to_owned(),
            did: did.to_owned(),
            device_id: device_id.to_owned(),
        });
    }

    Ok((accounts, allowed_hosts))
}

fn validate_manifest_hosts(
    object: &BTreeMap<String, FixtureJsonValue>,
    allowed_hosts: &BTreeSet<String>,
) -> Result<BTreeMap<String, u16>, DebugFixtureError> {
    let Some(FixtureJsonValue::Object(raw_hosts)) = object.get("hosts") else {
        return Err(DebugFixtureError::InvalidConfiguration(
            "hosts must be an object",
        ));
    };
    let actual_hosts: BTreeSet<String> = raw_hosts.keys().cloned().collect();
    if actual_hosts != *allowed_hosts {
        return Err(DebugFixtureError::InvalidConfiguration(
            "hosts keys do not match allowed policy hosts",
        ));
    }
    let mut ports = BTreeMap::new();
    let mut unique_ports = BTreeSet::new();
    for (name, val) in raw_hosts {
        let endpoint = as_str(Some(val))?;
        let Some(port_str) = endpoint.strip_prefix("127.0.0.1:") else {
            return Err(DebugFixtureError::InvalidConfiguration(
                "host endpoint must be 127.0.0.1:<port>",
            ));
        };
        let port: u16 = port_str
            .parse()
            .map_err(|_| DebugFixtureError::InvalidConfiguration("invalid port"))?;
        if port <= 1023 || endpoint != format!("127.0.0.1:{port}") {
            return Err(DebugFixtureError::InvalidConfiguration(
                "port must be > 1023 and canonical",
            ));
        }
        ports.insert(name.clone(), port);
        unique_ports.insert(port);
    }
    if unique_ports.len() != 1 {
        return Err(DebugFixtureError::InvalidConfiguration(
            "all fixture hosts must bind the same loopback port",
        ));
    }
    Ok(ports)
}

fn as_str(val: Option<&FixtureJsonValue>) -> Result<&str, DebugFixtureError> {
    match val {
        Some(FixtureJsonValue::String(s)) => Ok(s.as_str()),
        _ => Err(DebugFixtureError::InvalidConfiguration(
            "expected string value",
        )),
    }
}

/// Strict subset JSON parser rejecting duplicate object keys and unbounded structures.
#[derive(Debug, PartialEq)]
enum FixtureJsonValue {
    String(String),
    Bool(bool),
    Array(Vec<Self>),
    Object(BTreeMap<String, Self>),
}

impl FixtureJsonValue {
    fn parse(bytes: &[u8]) -> Result<Self, DebugFixtureError> {
        let mut parser = FixtureJsonParser { bytes, offset: 0 };
        let value = parser.value(0)?;
        parser.whitespace();
        if parser.offset != bytes.len() {
            return Err(DebugFixtureError::InvalidConfiguration(
                "trailing data in manifest JSON",
            ));
        }
        Ok(value)
    }
}

struct FixtureJsonParser<'a> {
    bytes: &'a [u8],
    offset: usize,
}

impl FixtureJsonParser<'_> {
    fn whitespace(&mut self) {
        while self.offset < self.bytes.len()
            && matches!(self.bytes[self.offset], b'\t' | b'\n' | b'\r' | b' ')
        {
            self.offset += 1;
        }
    }

    fn take(&mut self, expected: u8) -> bool {
        if self.offset < self.bytes.len() && self.bytes[self.offset] == expected {
            self.offset += 1;
            true
        } else {
            false
        }
    }

    fn value(&mut self, depth: usize) -> Result<FixtureJsonValue, DebugFixtureError> {
        self.whitespace();
        if depth >= 12 || self.offset >= self.bytes.len() {
            return Err(DebugFixtureError::InvalidConfiguration(
                "manifest depth or EOF",
            ));
        }
        match self.bytes[self.offset] {
            b'"' => self.string().map(FixtureJsonValue::String),
            b'{' => {
                self.offset += 1;
                self.whitespace();
                let mut object = BTreeMap::new();
                if self.take(b'}') {
                    return Ok(FixtureJsonValue::Object(object));
                }
                loop {
                    self.whitespace();
                    let key = self.string()?;
                    self.whitespace();
                    if !self.take(b':') || object.contains_key(&key) {
                        return Err(DebugFixtureError::InvalidConfiguration(
                            "duplicate or malformed JSON object key",
                        ));
                    }
                    let val = self.value(depth + 1)?;
                    object.insert(key, val);
                    self.whitespace();
                    if self.take(b'}') {
                        return Ok(FixtureJsonValue::Object(object));
                    }
                    if !self.take(b',') || object.len() >= 32 {
                        return Err(DebugFixtureError::InvalidConfiguration(
                            "malformed or oversized JSON object",
                        ));
                    }
                }
            }
            b'[' => {
                self.offset += 1;
                self.whitespace();
                let mut array = Vec::new();
                if self.take(b']') {
                    return Ok(FixtureJsonValue::Array(array));
                }
                loop {
                    array.push(self.value(depth + 1)?);
                    self.whitespace();
                    if self.take(b']') {
                        return Ok(FixtureJsonValue::Array(array));
                    }
                    if !self.take(b',') || array.len() >= 32 {
                        return Err(DebugFixtureError::InvalidConfiguration(
                            "malformed or oversized JSON array",
                        ));
                    }
                }
            }
            _ => {
                if self.bytes[self.offset..].starts_with(b"true") {
                    self.offset += 4;
                    return Ok(FixtureJsonValue::Bool(true));
                }
                if self.bytes[self.offset..].starts_with(b"false") {
                    self.offset += 5;
                    return Ok(FixtureJsonValue::Bool(false));
                }
                Err(DebugFixtureError::InvalidConfiguration(
                    "unsupported JSON token in manifest",
                ))
            }
        }
    }

    fn string(&mut self) -> Result<String, DebugFixtureError> {
        let start = self.offset;
        if !self.take(b'"') {
            return Err(DebugFixtureError::InvalidConfiguration("expected string"));
        }
        let mut escaped = false;
        while self.offset < self.bytes.len() {
            let b = self.bytes[self.offset];
            self.offset += 1;
            if b == b'"' && !escaped {
                return serde_json::from_slice::<String>(&self.bytes[start..self.offset]).map_err(
                    |_| DebugFixtureError::InvalidConfiguration("invalid JSON string escape"),
                );
            }
            escaped = b == b'\\' && !escaped;
        }
        Err(DebugFixtureError::InvalidConfiguration(
            "unterminated JSON string",
        ))
    }
}
