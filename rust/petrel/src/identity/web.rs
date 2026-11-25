use std::fmt;

use thiserror::Error;
use url::Url;

/// The AT Protocol's host-only subset of `did:web`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DidWebIdentifier {
    did: String,
    host: String,
    port: Option<u16>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
pub enum DidWebError {
    #[error("not a valid did:web identifier")]
    InvalidDid,
    #[error("AT Protocol does not support did:web paths")]
    UnsupportedPath,
    #[error("did:web hostname is invalid")]
    InvalidHost,
    #[error("did:web hostname uses a reserved TLD")]
    ReservedTld,
    #[error("did:web development host is disabled")]
    DevelopmentHostDisabled,
    #[error("did:web ports are allowed only on localhost and must be 1–65535")]
    InvalidPort,
}

impl DidWebIdentifier {
    pub fn parse(did: &str, allow_development_hosts: bool) -> Result<Self, DidWebError> {
        let authority = did
            .strip_prefix("did:web:")
            .ok_or(DidWebError::InvalidDid)?;
        if did.len() > 2048
            || authority.is_empty()
            || authority.ends_with([':', '%'])
            || !authority.bytes().all(is_did_identifier_byte)
        {
            return Err(DidWebError::InvalidDid);
        }
        if authority.contains(':') {
            return Err(DidWebError::UnsupportedPath);
        }

        let separator = authority.bytes().enumerate().find_map(|(index, byte)| {
            (byte == b'%'
                && matches!(
                    authority.as_bytes().get(index..index + 3),
                    Some(b"%3A" | b"%3a")
                ))
            .then_some(index)
        });
        let (host, port) = separator.map_or((authority, None), |index| {
            (&authority[..index], Some(&authority[index + 3..]))
        });
        if host.contains('%') {
            return Err(DidWebError::InvalidHost);
        }

        if host == "localhost" {
            if !allow_development_hosts {
                return Err(DidWebError::DevelopmentHostDisabled);
            }
        } else {
            if port.is_some() {
                return Err(DidWebError::InvalidPort);
            }
            let tld = validated_tld(host).ok_or(DidWebError::InvalidHost)?;
            if matches!(
                tld,
                "alt"
                    | "arpa"
                    | "example"
                    | "internal"
                    | "invalid"
                    | "local"
                    | "localhost"
                    | "onion"
            ) {
                return Err(DidWebError::ReservedTld);
            }
            if tld == "test" && !allow_development_hosts {
                return Err(DidWebError::DevelopmentHostDisabled);
            }
        }

        let port = port.map(parse_port).transpose()?;
        Ok(Self {
            did: did.to_owned(),
            host: host.to_owned(),
            port,
        })
    }

    pub fn host(&self) -> &str {
        &self.host
    }

    pub fn port(&self) -> Option<u16> {
        self.port
    }

    pub fn is_development_host(&self) -> bool {
        self.host == "localhost"
            || self
                .host
                .rsplit_once('.')
                .is_some_and(|(_, tld)| tld == "test")
    }

    pub fn document_url(&self) -> Result<Url, url::ParseError> {
        let scheme = if self.host == "localhost" {
            "http"
        } else {
            "https"
        };
        let mut url = Url::parse(&format!("{scheme}://{}/.well-known/did.json", self.host))?;
        url.set_port(self.port)
            .map_err(|()| url::ParseError::InvalidPort)?;
        Ok(url)
    }
}

impl fmt::Display for DidWebIdentifier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.did.fmt(f)
    }
}

fn is_did_identifier_byte(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b':' | b'%' | b'-')
}

fn parse_port(port: &str) -> Result<u16, DidWebError> {
    if port.len() > 5 || !port.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err(DidWebError::InvalidPort);
    }
    match port.parse() {
        Ok(port @ 1..=u16::MAX) => Ok(port),
        _ => Err(DidWebError::InvalidPort),
    }
}

fn validated_tld(host: &str) -> Option<&str> {
    if host.len() > 253 {
        return None;
    }
    let (prefix, tld) = host.rsplit_once('.')?;
    if prefix.is_empty() || !tld.as_bytes().first().is_some_and(u8::is_ascii_lowercase) {
        return None;
    }
    host.split('.').all(is_hostname_label).then_some(tld)
}

fn is_hostname_label(label: &str) -> bool {
    (1..=63).contains(&label.len())
        && !label.starts_with('-')
        && !label.ends_with('-')
        && label
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_host_based_lowercase_public_identifiers_are_accepted_by_default() {
        let identifier = DidWebIdentifier::parse("did:web:pds.example.com", false).unwrap();
        assert_eq!(identifier.host(), "pds.example.com");
        assert_eq!(
            identifier.document_url().unwrap().as_str(),
            "https://pds.example.com/.well-known/did.json"
        );

        for (did, expected) in [
            ("did:web:pds.example.com:user", DidWebError::UnsupportedPath),
            ("did:web:pds.example.com%3A123", DidWebError::InvalidPort),
            ("did:web:A.example.com", DidWebError::InvalidHost),
            ("did:web:127.0.0.1", DidWebError::InvalidHost),
            ("did:web:some.local", DidWebError::ReservedTld),
            ("did:web:x.test", DidWebError::DevelopmentHostDisabled),
            (
                "did:web:localhost%3a2583",
                DidWebError::DevelopmentHostDisabled,
            ),
        ] {
            assert_eq!(DidWebIdentifier::parse(did, false), Err(expected), "{did}");
        }
    }

    #[test]
    fn only_development_mode_accepts_localhost_and_test_hosts() {
        let identifier = DidWebIdentifier::parse("did:web:localhost%3a2583", true).unwrap();
        assert_eq!(identifier.port(), Some(2583));
        assert!(identifier.is_development_host());
        assert_eq!(
            identifier.document_url().unwrap().as_str(),
            "http://localhost:2583/.well-known/did.json"
        );
        assert!(DidWebIdentifier::parse("did:web:x.test", true).is_ok());
        for did in [
            "did:web:localhost%3A0",
            "did:web:localhost%3A65536",
            "did:web:localhost%3A000001",
        ] {
            assert_eq!(
                DidWebIdentifier::parse(did, true),
                Err(DidWebError::InvalidPort)
            );
        }
    }
}
