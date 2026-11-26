//! URL, connection-address, and credential header policy shared by transports.

mod ip;

use std::fmt;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};

use http::{HeaderMap, HeaderName, HeaderValue, Uri};
use thiserror::Error;
use url::{Host, Url};

/// An HTTP or WebSocket origin identified by scheme, normalized host and effective port.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Origin {
    scheme: String,
    host: String,
    port: u16,
}

impl Origin {
    pub fn from_url(url: &Url) -> Result<Self, PolicyError> {
        let scheme = url.scheme();
        if !matches!(scheme, "http" | "https" | "ws" | "wss") {
            return Err(PolicyError::Scheme);
        }

        Ok(Self {
            scheme: scheme.to_owned(),
            host: url.host_str().ok_or(PolicyError::MissingHost)?.to_owned(),
            port: url.port_or_known_default().ok_or(PolicyError::Scheme)?,
        })
    }

    pub fn scheme(&self) -> &str {
        &self.scheme
    }

    pub fn host(&self) -> &str {
        &self.host
    }

    pub fn port(&self) -> u16 {
        self.port
    }
}

impl fmt::Display for Origin {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let default_port = if matches!(self.scheme(), "https" | "wss") {
            443
        } else {
            80
        };
        write!(f, "{}://{}", self.scheme, self.host)?;
        if self.port != default_port {
            write!(f, ":{}", self.port)?;
        }
        Ok(())
    }
}

/// A target rejected before sending a request.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
pub enum PolicyError {
    #[error("URL scheme is unsupported")]
    Scheme,
    #[error("URL has no host")]
    MissingHost,
    #[error("request URLs cannot contain credentials or fragments")]
    InvalidAuthority,
    #[error("cleartext connections require a loopback target")]
    Cleartext,
    #[error("loopback connections require development mode")]
    LoopbackDisabled,
    #[error("target has no IP addresses")]
    NoAddresses,
    #[error("target resolved to a disallowed IP address")]
    DisallowedAddress,
    #[error("a remote request cannot redirect to a loopback target")]
    RedirectToLoopback,
}

pub(crate) fn is_loopback_host(host: &str) -> bool {
    matches!(host, "localhost" | "127.0.0.1" | "[::1]" | "::1")
}

/// Validate a URL's scheme, authority and literal IP, if any. A native transport
/// validates DNS answers separately, on the path that supplies them to its connector.
pub fn validate_url(url: &Url) -> Result<Origin, PolicyError> {
    validate_url_with_development(url, false)
}

/// Allow direct loopback requests when development mode is enabled.
pub fn validate_url_with_development(
    url: &Url,
    allow_loopback: bool,
) -> Result<Origin, PolicyError> {
    validate_url_with_options(url, allow_loopback, None)
}

fn validate_url_with_options(
    url: &Url,
    allow_loopback: bool,
    allowed_cleartext_origin: Option<&Origin>,
) -> Result<Origin, PolicyError> {
    let origin = Origin::from_url(url)?;
    if !url.username().is_empty() || url.password().is_some() || url.fragment().is_some() {
        return Err(PolicyError::InvalidAuthority);
    }
    let local = is_loopback_host(origin.host());
    if local && !allow_loopback {
        return Err(PolicyError::LoopbackDisabled);
    }
    let matches_allowed_cleartext = allowed_cleartext_origin
        .is_some_and(|allowed| allowed == &origin && allowed.scheme() == "http");
    if !local && matches!(origin.scheme(), "http" | "ws") && !matches_allowed_cleartext {
        return Err(PolicyError::Cleartext);
    }

    match url.host().ok_or(PolicyError::MissingHost)? {
        Host::Ipv4(address) => validate_resolved_addresses(origin.host(), &[address.into()])?,
        Host::Ipv6(address) => validate_resolved_addresses(origin.host(), &[address.into()])?,
        Host::Domain(_) => {}
    }
    Ok(origin)
}

/// Check a request's original authority before URL normalization.
pub(crate) fn validate_request_uri(
    uri: &Uri,
    options: &super::SendOptions,
) -> Result<(Url, Origin), PolicyError> {
    if uri
        .authority()
        .is_some_and(|authority| authority.as_str().contains('@'))
    {
        return Err(PolicyError::InvalidAuthority);
    }
    let url = Url::parse(&uri.to_string()).map_err(|_| PolicyError::InvalidAuthority)?;
    let origin = validate_url_with_options(
        &url,
        options.allow_loopback,
        options.allowed_cleartext_origin.as_ref(),
    )?;
    if is_loopback_host(origin.host())
        && !uri
            .host()
            .is_some_and(|host| is_loopback_host(&host.to_ascii_lowercase()))
    {
        return Err(PolicyError::DisallowedAddress);
    }
    Ok((url, origin))
}

/// Reject an entire DNS answer set when any address violates the target's policy.
pub fn validate_resolved_addresses(host: &str, addresses: &[IpAddr]) -> Result<(), PolicyError> {
    if addresses.is_empty() {
        return Err(PolicyError::NoAddresses);
    }

    let permitted = if is_loopback_host(host) {
        addresses.iter().copied().all(is_exact_loopback_address)
    } else {
        !addresses.iter().copied().any(ip::is_private_or_reserved)
    };
    if permitted {
        Ok(())
    } else {
        Err(PolicyError::DisallowedAddress)
    }
}

fn is_exact_loopback_address(address: IpAddr) -> bool {
    match address {
        IpAddr::V4(address) => address == Ipv4Addr::LOCALHOST,
        IpAddr::V6(address) => {
            address == Ipv6Addr::LOCALHOST || address.to_ipv4_mapped() == Some(Ipv4Addr::LOCALHOST)
        }
    }
}

pub(crate) fn validate_redirect(
    from: &Origin,
    url: &Url,
    allow_loopback: bool,
) -> Result<Origin, PolicyError> {
    let target = validate_url_with_development(url, allow_loopback)?;
    if !is_loopback_host(from.host()) && is_loopback_host(target.host()) {
        return Err(PolicyError::RedirectToLoopback);
    }
    Ok(target)
}

/// Header names that carry credentials or origin-scoped routing information.
const SENSITIVE_HEADERS: &[&str] = &[
    "authorization",
    "dpop",
    "x-dpop",
    "dpop-nonce",
    "cookie",
    "cookie2",
    "atproto-proxy",
    "atproto-accept-labelers",
    "x-api-key",
    "x-auth-token",
    "proxy-authorization",
];

pub(crate) fn strip_sensitive_headers(headers: &mut HeaderMap) {
    *headers = headers
        .iter()
        .filter(|(name, value)| {
            !value.is_sensitive() && !SENSITIVE_HEADERS.contains(&name.as_str())
        })
        .map(|(name, value)| (name.clone(), value.clone()))
        .collect();
}

pub(crate) fn retain_anonymous_headers(headers: &mut HeaderMap) {
    *headers = headers
        .iter()
        .filter(|(name, value)| {
            !value.is_sensitive()
                && matches!(
                    name.as_str(),
                    "user-agent" | "accept" | "content-type" | "content-length" | "accept-encoding"
                )
        })
        .map(|(name, value)| (name.clone(), value.clone()))
        .collect();
}

/// Copy headers for diagnostics, redacting credentials and token-like values.
pub fn redacted_headers(headers: &HeaderMap) -> HeaderMap {
    headers
        .iter()
        .map(|(name, value)| (name.clone(), redacted_header_value(name, value)))
        .collect()
}

fn redacted_header_value(name: &HeaderName, value: &HeaderValue) -> HeaderValue {
    let looks_like_token = value.to_str().is_ok_and(|text| {
        let normalized = text.to_ascii_lowercase();
        normalized.contains("bearer") || normalized.contains("dpop")
    });
    if value.is_sensitive() || SENSITIVE_HEADERS.contains(&name.as_str()) || looks_like_token {
        HeaderValue::from_static("<REDACTED>")
    } else {
        value.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn origin_includes_the_scheme_and_effective_port() {
        let origin = |url| Origin::from_url(&Url::parse(url).unwrap()).unwrap();

        assert_eq!(
            origin("https://EXAMPLE.com/path"),
            origin("https://example.com:443/other"),
        );
        assert_ne!(
            origin("https://example.com"),
            origin("https://example.com:444")
        );
        assert_ne!(origin("https://example.com"), origin("wss://example.com"));
        assert_eq!(origin("http://[::1]:3000").to_string(), "http://[::1]:3000");
    }

    #[test]
    fn url_requires_a_valid_authority_and_remote_encryption() {
        for url in [
            "http://example.com",
            "https://127.0.0.2",
            "https://[::ffff:127.0.0.1]",
            "https://10.1.2.3",
            "https://user:password@example.com",
            "https://example.com/#secret",
            "file:///some-path",
        ] {
            assert!(validate_url(&Url::parse(url).unwrap()).is_err(), "{url}");
        }
        for url in ["https://example.com", "wss://example.com"] {
            assert!(validate_url(&Url::parse(url).unwrap()).is_ok(), "{url}");
        }
        for url in ["http://localhost", "http://127.0.0.1", "http://[::1]"] {
            let url = Url::parse(url).unwrap();
            assert_eq!(validate_url(&url), Err(PolicyError::LoopbackDisabled));
            assert!(validate_url_with_development(&url, true).is_ok(), "{url}");
        }
        assert!(Url::parse("https://[broken-ip]").is_err());
    }

    #[test]
    fn connection_policy_rejects_a_mixed_dns_answer() {
        let public = "1.1.1.1".parse().unwrap();
        let localhost = IpAddr::V4(Ipv4Addr::LOCALHOST);

        assert_eq!(
            validate_resolved_addresses("example.com", &[public]),
            Ok(())
        );
        assert_eq!(
            validate_resolved_addresses("example.com", &[public, localhost]),
            Err(PolicyError::DisallowedAddress),
        );
        assert_eq!(
            validate_resolved_addresses("localhost", &[localhost, public]),
            Err(PolicyError::DisallowedAddress),
        );
        assert_eq!(
            validate_resolved_addresses("localhost", &["::ffff:127.0.0.1".parse().unwrap()]),
            Ok(()),
        );
        assert_eq!(
            validate_resolved_addresses("localhost", &["64:ff9b::7f00:1".parse().unwrap()]),
            Err(PolicyError::DisallowedAddress),
        );
        assert_eq!(
            validate_resolved_addresses("example.com", &[]),
            Err(PolicyError::NoAddresses),
        );
    }

    #[test]
    fn remote_redirect_cannot_switch_to_loopback() {
        let origin = validate_url(&Url::parse("https://example.com").unwrap()).unwrap();
        let target = Url::parse("http://localhost:3344").unwrap();
        assert_eq!(
            validate_redirect(&origin, &target, true),
            Err(PolicyError::RedirectToLoopback)
        );
        let local =
            validate_url_with_development(&Url::parse("http://127.0.0.1").unwrap(), true).unwrap();
        assert!(validate_redirect(&local, &target, true).is_ok());
    }

    #[test]
    fn sensitive_and_token_like_headers_are_redacted() {
        let mut headers = HeaderMap::new();
        headers.insert(
            "Authorization",
            HeaderValue::from_static("example-credential"),
        );
        headers.insert("atproto-proxy", HeaderValue::from_static("did:plc:test"));
        headers.insert(
            "custom-secret",
            HeaderValue::from_static("Bearer example-credential"),
        );
        headers.insert("accept", HeaderValue::from_static("application/json"));

        let redacted = redacted_headers(&headers);
        for name in ["authorization", "atproto-proxy", "custom-secret"] {
            assert_eq!(redacted[name], "<REDACTED>");
        }
        assert_eq!(redacted["accept"], "application/json");
        assert_eq!(headers["authorization"], "example-credential");
    }

    #[test]
    fn allowed_cleartext_origin_is_strictly_scoped_to_exact_http_origin() {
        let allowed = Origin::from_url(&Url::parse("http://plc.lab:2582").unwrap()).unwrap();
        let mut opts = crate::net::SendOptions::new();
        opts.allowed_cleartext_origin = Some(allowed);

        assert!(
            validate_request_uri(&"http://plc.lab:2582/did:plc:abc".parse().unwrap(), &opts)
                .is_ok()
        );
        for rejected in [
            "http://plc.lab:2583/did:plc:abc",
            "http://other.lab:2582/did:plc:abc",
            "ws://plc.lab:2582/did:plc:abc",
            "http://127.0.0.1:2582/did:plc:abc",
        ] {
            assert!(
                validate_request_uri(&rejected.parse().unwrap(), &opts).is_err(),
                "{rejected}"
            );
        }
    }
}
