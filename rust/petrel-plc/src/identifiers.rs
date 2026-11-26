use crate::error::PlcError;

/// Syntax validation for AT Protocol account identifiers (`did:plc`, `did:web`, handles).
#[derive(Debug, Clone, Copy)]
pub struct AccountIdentifiers;

impl AccountIdentifiers {
    /// Reserved top-level domains that a handle or `did:web` host may not use.
    pub const DISALLOWED_TLDS: &'static [&'static str] = &[
        ".alt",
        ".arpa",
        ".example",
        ".internal",
        ".invalid",
        ".local",
        ".localhost",
        ".onion",
    ];

    /// Validates an account DID under AT Protocol's rules (`did:plc` and hostname-only `did:web`).
    pub fn validate_did(did: &str, allow_localhost: bool) -> Result<&str, PlcError> {
        let bytes = did.as_bytes();
        if bytes.len() > 2048 || !bytes.iter().all(|b| (0x21..=0x7e).contains(b)) {
            return Err(PlcError::invalid_identifier("account DID"));
        }
        if let Some(rest) = did.strip_prefix("did:plc:") {
            if rest.len() != 24 || !rest.bytes().all(|b| matches!(b, b'a'..=b'z' | b'2'..=b'7')) {
                return Err(PlcError::invalid_identifier("account DID"));
            }
            return Ok(did);
        }
        let Some(web_rest) = did.strip_prefix("did:web:") else {
            return Err(PlcError::invalid_identifier(
                "unsupported account DID method",
            ));
        };
        Self::validate_web_did_identifier(web_rest, allow_localhost)?;
        Ok(did)
    }

    /// Validates a handle (a DNS name of at least two labels) and returns it lowercased.
    pub fn canonical_handle(handle: &str) -> Result<String, PlcError> {
        let bytes = handle.as_bytes();
        if bytes.is_empty()
            || bytes.len() > 253
            || !bytes
                .iter()
                .all(|b| b.is_ascii_alphanumeric() || *b == b'-' || *b == b'.')
        {
            return Err(PlcError::invalid_identifier("account handle"));
        }

        let canonical = handle.to_ascii_lowercase();
        if !Self::is_valid_hostname(&canonical) {
            return Err(PlcError::invalid_identifier("account handle"));
        }
        Ok(canonical)
    }

    fn validate_web_did_identifier(
        identifier: &str,
        allow_localhost: bool,
    ) -> Result<(), PlcError> {
        if identifier.is_empty() || identifier.contains(':') {
            return Err(PlcError::invalid_identifier(
                "did:web must be a bare hostname",
            ));
        }

        let (host, has_port) = if let Some(idx) = find_case_insensitive(identifier, "%3a") {
            let port_text = &identifier[idx + 3..];
            if port_text.is_empty()
                || port_text.len() > 5
                || !port_text.bytes().all(|b| b.is_ascii_digit())
            {
                return Err(PlcError::invalid_identifier("did:web port"));
            }
            let port: u16 = port_text
                .parse()
                .map_err(|_| PlcError::invalid_identifier("did:web port"))?;
            if port == 0 {
                return Err(PlcError::invalid_identifier("did:web port"));
            }
            (&identifier[..idx], true)
        } else {
            (identifier, false)
        };

        if host.eq_ignore_ascii_case("localhost") {
            if !allow_localhost {
                return Err(PlcError::invalid_identifier(
                    "did:web:localhost is for development only",
                ));
            }
            return Ok(());
        }

        if has_port {
            return Err(PlcError::invalid_identifier("did:web port"));
        }

        let lowercased = host.to_ascii_lowercase();
        if host != lowercased || lowercased.len() > 253 || !Self::is_valid_hostname(&lowercased) {
            return Err(PlcError::invalid_identifier("did:web hostname"));
        }
        if Self::DISALLOWED_TLDS
            .iter()
            .any(|tld| lowercased.ends_with(tld))
        {
            return Err(PlcError::invalid_identifier(
                "did:web host uses a reserved top-level domain",
            ));
        }
        Ok(())
    }

    fn is_valid_hostname(lower: &str) -> bool {
        let labels: Vec<&str> = lower.split('.').collect();
        if labels.len() < 2 {
            return false;
        }
        let Some(last) = labels.last() else {
            return false;
        };
        if !last.as_bytes().first().is_some_and(u8::is_ascii_lowercase) {
            return false;
        }
        labels.iter().all(|label| {
            !label.is_empty()
                && label.len() <= 63
                && !label.starts_with('-')
                && !label.ends_with('-')
                && label
                    .bytes()
                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
        })
    }
}

fn find_case_insensitive(haystack: &str, needle_lower: &str) -> Option<usize> {
    let h = haystack.as_bytes();
    let n = needle_lower.as_bytes();
    if h.len() < n.len() {
        return None;
    }
    h.windows(n.len())
        .position(|window| window.eq_ignore_ascii_case(n))
}
