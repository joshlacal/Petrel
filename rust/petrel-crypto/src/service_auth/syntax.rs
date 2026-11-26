//! Identifier syntax checks used by service authentication.

use crate::did_key::PLCDIDKeyCodec;

pub(crate) const MAXIMUM_DID_BYTES: usize = 2048;
pub(crate) const MAXIMUM_NSID_BYTES: usize = 317;
pub(crate) const MAXIMUM_FRAGMENT_BYTES: usize = 512;

/// Generic DID syntax: `did:<lowercase-method>:<id>`, not ending in `:` or `%`.
pub(crate) fn is_generic_did(value: &str) -> bool {
    let bytes = value.as_bytes();
    if bytes.len() > MAXIMUM_DID_BYTES || bytes.len() < 7 || !bytes.starts_with(b"did:") {
        return false;
    }
    let mut index = 4;
    let method_start = index;
    while index < bytes.len() && bytes[index].is_ascii_lowercase() {
        index += 1;
    }
    if index == method_start || index >= bytes.len() || bytes[index] != b':' {
        return false;
    }
    index += 1;
    if index >= bytes.len() {
        return false;
    }
    for &byte in &bytes[index..] {
        if !(byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b':' | b'%' | b'-')) {
            return false;
        }
    }
    let last = bytes[bytes.len() - 1];
    last != b':' && last != b'%'
}

/// Service-auth DID syntax, enforcing method rules for `did:plc`, `did:web`, and `did:key`.
pub(crate) fn is_did(value: &str) -> bool {
    if !is_generic_did(value) {
        return false;
    }
    let mut parts = value.splitn(3, ':');
    let (Some(_scheme), Some(method), Some(identifier)) =
        (parts.next(), parts.next(), parts.next())
    else {
        return false;
    };
    match method {
        "plc" => {
            identifier.len() == 24
                && identifier
                    .bytes()
                    .all(|b| b.is_ascii_lowercase() || (b'2'..=b'7').contains(&b))
        }
        "web" => is_web_did_identifier(identifier),
        "key" => PLCDIDKeyCodec::decode(value).is_ok(),
        _ => true,
    }
}

fn is_web_did_identifier(identifier: &str) -> bool {
    if identifier.contains(':') {
        return false;
    }
    let pieces: Vec<&str> = identifier.split("%3A").collect();
    if !(1..=2).contains(&pieces.len()) || pieces[0].contains('%') {
        return false;
    }
    let host = pieces[0];
    if pieces.len() == 2 {
        let port = pieces[1];
        if host != "localhost"
            || port.is_empty()
            || !port.bytes().all(|b| b.is_ascii_digit())
            || (port.len() > 1 && port.starts_with('0'))
        {
            return false;
        }
        return port.parse::<u16>().is_ok_and(|n| n > 0);
    }
    host == "localhost" || is_hostname(host)
}

fn is_hostname(name: &str) -> bool {
    if name.len() > 253 {
        return false;
    }
    let labels: Vec<&str> = name.split('.').collect();
    if labels.len() < 2 {
        return false;
    }
    for &label in &labels {
        let bytes = label.as_bytes();
        if bytes.is_empty()
            || bytes.len() > 63
            || !bytes
                .iter()
                .all(|&b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
            || bytes.first() == Some(&b'-')
            || bytes.last() == Some(&b'-')
        {
            return false;
        }
    }
    !labels[labels.len() - 1]
        .as_bytes()
        .first()
        .is_some_and(u8::is_ascii_digit)
}

/// Splits `did` or `did#fragment`, validating both parts.
pub(crate) fn split_did_reference(value: &str) -> Option<(&str, Option<&str>)> {
    if let Some((did, fragment)) = value.split_once('#') {
        if is_did(did) && is_fragment(fragment) {
            Some((did, Some(fragment)))
        } else {
            None
        }
    } else if is_did(value) {
        Some((value, None))
    } else {
        None
    }
}

/// Validates a DID document fragment name without its `#`.
pub(crate) fn is_fragment(value: &str) -> bool {
    let bytes = value.as_bytes();
    !bytes.is_empty()
        && bytes.len() <= MAXIMUM_FRAGMENT_BYTES
        && bytes.iter().all(|&b| {
            b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'~' | b':' | b'%' | b'-')
        })
}

/// Validates a `kid` header value (`#` followed by a fragment name).
pub(crate) fn is_key_id(value: &str) -> bool {
    value.strip_prefix('#').is_some_and(is_fragment)
}

/// Validates AT Protocol NSID syntax.
pub(crate) fn is_nsid(value: &str) -> bool {
    if value.len() > MAXIMUM_NSID_BYTES || !value.is_ascii() {
        return false;
    }
    let segments: Vec<&[u8]> = value.split('.').map(str::as_bytes).collect();
    if segments.len() < 3 {
        return false;
    }
    for (index, &segment) in segments[..segments.len() - 1].iter().enumerate() {
        if segment.is_empty()
            || segment.len() > 63
            || !segment
                .iter()
                .all(|&b| b.is_ascii_alphanumeric() || b == b'-')
            || segment.first() == Some(&b'-')
            || segment.last() == Some(&b'-')
        {
            return false;
        }
        if index == 0 && segment.first().is_some_and(u8::is_ascii_digit) {
            return false;
        }
    }
    let name = segments[segments.len() - 1];
    !name.is_empty()
        && name.len() <= 63
        && name.iter().all(u8::is_ascii_alphanumeric)
        && !name[0].is_ascii_digit()
}

/// Validates a non-empty printable ASCII string without spaces up to `maximum_bytes`.
pub(crate) fn is_printable_ascii(value: &str, maximum_bytes: usize) -> bool {
    let bytes = value.as_bytes();
    !bytes.is_empty()
        && bytes.len() <= maximum_bytes
        && bytes.iter().all(|&b| (0x21..=0x7E).contains(&b))
}
