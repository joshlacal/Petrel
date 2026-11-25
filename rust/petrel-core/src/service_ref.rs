//! Lexical references to services identified by a DID.

use std::{fmt, str::FromStr};

use crate::{AtprotoMethod, Did, Handle};

const MAX_SERVICE_ID_BYTES: usize = 512;
const BASE58_BTC: &[u8] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

/// A malformed service reference or one that cannot be used for proxy routing.
#[derive(Clone, Copy, Debug, Eq, PartialEq, thiserror::Error)]
#[non_exhaustive]
pub enum ServiceRefError {
    /// The DID does not match the service-auth identifier grammar.
    #[error("invalid service DID")]
    InvalidDid,
    /// The fragment is empty, oversized or contains an unsupported character.
    #[error("invalid service identifier")]
    InvalidServiceId,
    /// Proxy routing requires the target's service fragment.
    #[error("atproto-proxy requires a service identifier")]
    MissingServiceId,
}

/// A DID and optional DID document service identifier.
///
/// Both are preserved verbatim for use as a service-auth audience. A bare
/// DID is a legacy audience form. Proxy routing requires the service identifier.
#[derive(Clone, Debug, Eq, Hash, PartialEq)]
pub struct ServiceRef {
    did: Did,
    service_id: Option<String>,
}

impl ServiceRef {
    /// Header name used to route a request through a Personal Data Server.
    pub const PROXY_HEADER: &'static str = "atproto-proxy";
    /// Bluesky AppView service identifier.
    pub const BSKY_APPVIEW: &'static str = "bsky_appview";
    /// Bluesky chat service identifier.
    pub const BSKY_CHAT: &'static str = "bsky_chat";
    /// Feed generator service identifier.
    pub const BSKY_FEED_GENERATOR: &'static str = "bsky_fg";
    /// Notification service identifier.
    pub const BSKY_NOTIFICATION: &'static str = "bsky_notif";
    /// Labeler service identifier.
    pub const ATPROTO_LABELER: &'static str = "atproto_labeler";
    /// Personal Data Server service identifier.
    pub const ATPROTO_PDS: &'static str = "atproto_pds";

    /// Builds a reference, accepting one optional leading `#` on the service identifier.
    pub fn new(did: Did, service_id: Option<&str>) -> Result<Self, ServiceRefError> {
        Self::from_parts(did, service_id.map(|id| id.strip_prefix('#').unwrap_or(id)))
    }

    /// Parses a bare DID or a DID followed by `#` and a service identifier.
    pub fn parse(value: &str) -> Result<Self, ServiceRefError> {
        let (did, service_id) = value
            .split_once('#')
            .map_or((value, None), |(did, id)| (did, Some(id)));
        let did = Did::parse(did).map_err(|_| ServiceRefError::InvalidDid)?;
        Self::from_parts(did, service_id)
    }

    fn from_parts(did: Did, service_id: Option<&str>) -> Result<Self, ServiceRefError> {
        if !valid_service_did(&did) {
            return Err(ServiceRefError::InvalidDid);
        }
        if service_id.is_some_and(|id| !valid_service_id(id)) {
            return Err(ServiceRefError::InvalidServiceId);
        }
        Ok(Self {
            did,
            service_id: service_id.map(str::to_owned),
        })
    }

    /// The service's DID.
    pub fn did(&self) -> &Did {
        &self.did
    }

    /// The service identifier, without its separator.
    pub fn service_id(&self) -> Option<&str> {
        self.service_id.as_deref()
    }

    /// Formats the value of the `atproto-proxy` request header.
    pub fn proxy_header_value(&self) -> Result<String, ServiceRefError> {
        if self.service_id.is_none() {
            return Err(ServiceRefError::MissingServiceId);
        }
        Ok(self.to_string())
    }
}

impl FromStr for ServiceRef {
    type Err = ServiceRefError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        Self::parse(value)
    }
}

impl fmt::Display for ServiceRef {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.did)?;
        if let Some(service_id) = &self.service_id {
            write!(f, "#{service_id}")?;
        }
        Ok(())
    }
}

fn valid_service_id(id: &str) -> bool {
    (1..=MAX_SERVICE_ID_BYTES).contains(&id.len())
        && id.bytes().all(|byte| {
            byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'~' | b':' | b'%' | b'-')
        })
}

fn valid_service_did(did: &Did) -> bool {
    match did.method() {
        "plc" => did.atproto_method() == Some(AtprotoMethod::Plc),
        "web" => valid_web_identifier(did.method_specific_identifier()),
        "key" => valid_key_identifier(did.method_specific_identifier()),
        _ => true,
    }
}

fn valid_web_identifier(identifier: &str) -> bool {
    if let Some((host, port)) = identifier.split_once("%3A") {
        return host == "localhost"
            && !port.starts_with('0')
            && port.bytes().all(|byte| byte.is_ascii_digit())
            && port.parse::<u16>().is_ok();
    }
    identifier == "localhost"
        || (!identifier.bytes().any(|byte| byte.is_ascii_uppercase())
            && Handle::parse(identifier).is_ok())
}

// Check the canonical multikey framing. A cryptographic consumer also
// needs to check that the compressed point belongs to its claimed curve.
fn valid_key_identifier(identifier: &str) -> bool {
    let Some(encoded) = identifier.strip_prefix('z') else {
        return false;
    };
    // Both allowed multicodecs occupy two bytes, followed by a 33-byte SEC1 point.
    // The decoded prefix has no leading zero; a leading base58 '1' is noncanonical here.
    if encoded.len() != 48 || encoded.starts_with('1') {
        return false;
    }
    let mut decoded = [0_u8; 35];
    for character in encoded.bytes() {
        let Some(mut carry) = BASE58_BTC
            .iter()
            .position(|&byte| byte == character)
            .and_then(|digit| u16::try_from(digit).ok())
        else {
            return false;
        };
        for byte in decoded.iter_mut().rev() {
            let value = 58 * u16::from(*byte) + carry;
            *byte = value.to_le_bytes()[0];
            carry = value >> 8;
        }
        if carry != 0 {
            return false;
        }
    }
    matches!(decoded, [0x80, 0x24, 2 | 3, ..] | [0xe7, 0x01, 2 | 3, ..])
}
