use crate::syntax::{hex, percent_decode};

/// Validate the method-agnostic AT Protocol DID syntax.
pub fn is_did(value: &str) -> bool {
    let Some((method, msid)) = did_parts(value) else {
        return false;
    };
    !method.is_empty()
        && method.bytes().all(|byte| byte.is_ascii_lowercase())
        && msid.as_bytes().last().copied().is_some_and(is_name_byte)
        && msid
            .bytes()
            .all(|byte| is_name_byte(byte) || matches!(byte, b':' | b'%'))
}

fn did_parts(value: &str) -> Option<(&str, &str)> {
    if value.len() > 2048 {
        return None;
    }
    value.strip_prefix("did:")?.split_once(':')
}

fn is_name_byte(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-')
}

fn upper_hex(byte: u8) -> bool {
    byte.is_ascii_digit() || (b'A'..=b'F').contains(&byte)
}

fn with_percent_escapes(
    mut bytes: &[u8],
    hex_digit: impl Fn(u8) -> bool,
    accepts: impl Fn(u8) -> bool,
) -> bool {
    while let [first, rest @ ..] = bytes {
        if *first == b'%' {
            match rest {
                [high, low, remaining @ ..] if hex_digit(*high) && hex_digit(*low) => {
                    bytes = remaining;
                }
                _ => return false,
            }
        } else if accepts(*first) {
            bytes = rest;
        } else {
            return false;
        }
    }
    true
}

fn is_did_core_msid(msid: &str) -> bool {
    !msid.is_empty()
        && !msid.ends_with(':')
        && with_percent_escapes(msid.as_bytes(), upper_hex, |byte| {
            is_name_byte(byte) || byte == b':'
        })
}

/// Validate a Namespaced Identifier used for XRPC methods and collections.
pub fn is_nsid(value: &str) -> bool {
    if value.len() > 317 {
        return false;
    }
    let mut labels = value.split('.').peekable();
    if labels.clone().count() < 3 {
        return false;
    }
    let mut first = true;
    while let Some(label) = labels.next() {
        let Some(start) = label.as_bytes().first() else {
            return false;
        };
        let last = labels.peek().is_none();
        if label.len() > 63
            || !start.is_ascii_alphanumeric()
            || ((first || last) && !start.is_ascii_alphabetic())
            || label.ends_with('-')
            || !label
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || (!last && byte == b'-'))
        {
            return false;
        }
        first = false;
    }
    true
}

/// Validate an AT Protocol record key.
pub fn is_record_key(value: &str) -> bool {
    !matches!(value, "" | "." | "..")
        && value.len() <= 512
        && value
            .bytes()
            .all(|byte| is_name_byte(byte) || matches!(byte, b':' | b'~'))
}

/// Validate an absolute DID reference with a non-empty URI fragment.
pub fn is_did_ref_absolute(value: &str) -> bool {
    let Some((did, fragment)) = value.split_once('#') else {
        return false;
    };
    let Some((method, msid)) = did_parts(did) else {
        return false;
    };
    !method.is_empty()
        && method
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit())
        && is_did_core_msid(msid)
        && !fragment.is_empty()
        && with_percent_escapes(
            fragment.as_bytes(),
            |byte| hex(byte).is_some(),
            |byte| byte.is_ascii_alphanumeric() || b"-._~!$&'()*+,;=:@/?".contains(&byte),
        )
}

/// Validate the DID methods accepted in AT Protocol service references.
pub fn is_atproto_did(value: &str) -> bool {
    let Some((method, msid)) = did_parts(value) else {
        return false;
    };
    match method {
        "plc" => {
            msid.len() == 24
                && msid
                    .bytes()
                    .all(|byte| byte.is_ascii_lowercase() || matches!(byte, b'2'..=b'7'))
        }
        "web" => is_atproto_web_msid(msid),
        _ => false,
    }
}

fn is_atproto_web_msid(msid: &str) -> bool {
    if msid.contains(':') || !is_did_core_msid(msid) {
        return false;
    }
    let host = if let Some((host, port)) = msid.split_once("%3A") {
        if host != "localhost"
            || (!port.is_empty()
                && (!port.bytes().all(|b| b.is_ascii_digit()) || port.parse::<u16>().is_err()))
        {
            return false;
        }
        host
    } else {
        msid
    };

    // Swift's scope grammar rejects hosts requiring IDNA conversion. Use
    // the WHATWG host parser for ASCII DNS names and IPv4 forms.
    percent_decode(host, false, true).is_some_and(|bytes| bytes.is_ascii())
        && url::Host::parse(host).is_ok()
}

/// Validate the service DID and mandatory fragment used by `aud`.
pub fn is_atproto_did_ref_absolute(value: &str) -> bool {
    is_did_ref_absolute(value)
        && value
            .split_once('#')
            .is_some_and(|(did, _)| is_atproto_did(did))
}
