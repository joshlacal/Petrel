const TID_ALPHABET: &[u8; 32] = b"234567abcdefghijklmnopqrstuvwxyz";

pub(super) fn did(value: &str) -> Result<usize, &'static str> {
    if value.len() > 2048 {
        return Err("longer than 2048 bytes");
    }
    let rest = value
        .strip_prefix("did:")
        .ok_or("must start with lowercase did:")?;
    let (method, identifier) = rest
        .split_once(':')
        .ok_or("method must be followed by a colon")?;
    if method.is_empty() || !method.bytes().all(|byte| byte.is_ascii_lowercase()) {
        return Err("method must consist of lowercase ASCII letters");
    }
    if identifier.is_empty() {
        return Err("method-specific identifier is empty");
    }
    if !identifier.bytes().all(|byte| {
        byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b':' | b'%' | b'-')
    }) {
        return Err("method-specific identifier contains an invalid byte");
    }
    if identifier.ends_with([':', '%']) {
        return Err("must not end with a colon or percent sign");
    }
    Ok(4 + method.len())
}

fn labels(value: &str, limit: usize, minimum: usize) -> Result<&str, &'static str> {
    if value.len() > limit {
        return Err("longer than the maximum byte length");
    }
    let mut labels = value.split('.');
    if labels.clone().count() < minimum {
        return Err("too few dot-separated parts");
    }
    let mut last = "";
    for label in &mut labels {
        if label.is_empty() || label.len() > 63 {
            return Err("each dot-separated part must be 1–63 bytes");
        }
        if label.starts_with('-') || label.ends_with('-') {
            return Err("a dot-separated part starts or ends with a hyphen");
        }
        if !label
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-')
        {
            return Err("a dot-separated part contains an invalid byte");
        }
        last = label;
    }
    Ok(last)
}

pub(super) fn handle(value: &str) -> Result<(), &'static str> {
    let tld = labels(value, 253, 2)?;
    if !tld.as_bytes()[0].is_ascii_alphabetic() {
        return Err("top-level domain must start with an ASCII letter");
    }
    Ok(())
}

pub(super) fn nsid(value: &str) -> Result<usize, &'static str> {
    // The vector set permits an authority longer than 253 bytes.
    let name = labels(value, 317, 3)?;
    if !value.as_bytes()[0].is_ascii_alphabetic() {
        return Err("first part must start with an ASCII letter");
    }
    if !name.as_bytes()[0].is_ascii_alphabetic()
        || !name.bytes().all(|byte| byte.is_ascii_alphanumeric())
    {
        return Err(
            "the name must start with an ASCII letter and contain only ASCII letters and digits",
        );
    }
    Ok(value.len() - name.len())
}

pub(super) fn record_key(value: &str) -> Result<(), &'static str> {
    if !(1..=512).contains(&value.len()) {
        return Err("must be 1–512 bytes");
    }
    if matches!(value, "." | "..") {
        return Err("must not be . or ..");
    }
    if !value.bytes().all(|byte| {
        byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'-' | b'_' | b':' | b'~')
    }) {
        return Err("contains a byte outside ASCII letters, digits and . - _ : ~");
    }
    Ok(())
}

pub(super) fn tid(value: &str) -> Result<u64, &'static str> {
    if value.len() != 13 {
        return Err("must be exactly 13 bytes");
    }
    let mut result = 0;
    for (index, byte) in value.bytes().enumerate() {
        let digit = match byte {
            b'2'..=b'7' => byte - b'2',
            b'a'..=b'z' => byte - b'a' + 6,
            _ => return Err("contains a byte outside the TID alphabet"),
        };
        if index == 0 && digit >= 16 {
            return Err("first character must be one of 234567abcdefghij");
        }
        result = (result << 5) | u64::from(digit);
    }
    Ok(result)
}

pub(super) fn tid_string(mut value: u64) -> String {
    let mut bytes = [b'2'; 13];
    for byte in bytes.iter_mut().rev() {
        *byte = TID_ALPHABET[(value & 31) as usize];
        value >>= 5;
    }
    bytes.into_iter().map(char::from).collect()
}

pub(super) fn cid_string(value: &str) -> Result<(), &'static str> {
    if !(8..=256).contains(&value.len()) {
        return Err("must be 8–256 bytes");
    }
    if value.len() == 46 && value.starts_with("Qm") {
        return Err("CIDv0 is not supported");
    }
    if !value
        .bytes()
        .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'+' | b'='))
    {
        return Err("contains a byte outside ASCII letters, digits, plus and equals");
    }
    Ok(())
}

pub(super) fn uri(value: &str) -> Result<(), &'static str> {
    if value.len() > 8192 {
        return Err("longer than 8192 bytes");
    }
    let (scheme, rest) = value
        .split_once(':')
        .ok_or("must have a scheme and a colon")?;
    if !scheme
        .as_bytes()
        .first()
        .is_some_and(u8::is_ascii_alphabetic)
        || !scheme
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'+' | b'-' | b'.'))
    {
        return Err(
            "scheme must start with an ASCII letter and use only ASCII letters, digits and + - .",
        );
    }
    if rest.strip_prefix("//").unwrap_or(rest).is_empty() {
        return Err("has nothing after the scheme");
    }
    if rest
        .chars()
        .any(|ch| ch.is_whitespace() || ch.is_control() || ch == '\u{feff}')
    {
        return Err("contains whitespace or a control character");
    }
    Ok(())
}
