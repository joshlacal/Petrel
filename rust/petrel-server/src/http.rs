use std::collections::HashMap;

use crate::error::OAuthServerError;

/// An ordered, case-insensitive list of HTTP header fields.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct OAuthHttpHeaders {
    fields: Vec<OAuthHttpField>,
}

/// One HTTP header field.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthHttpField {
    /// Header name in original case.
    pub name: String,
    /// Header value.
    pub value: String,
}

impl OAuthHttpHeaders {
    /// Creates a header list from `(name, value)` pairs.
    pub fn new<I, N, V>(fields: I) -> Self
    where
        I: IntoIterator<Item = (N, V)>,
        N: Into<String>,
        V: Into<String>,
    {
        Self {
            fields: fields
                .into_iter()
                .map(|(n, v)| OAuthHttpField {
                    name: n.into(),
                    value: v.into(),
                })
                .collect(),
        }
    }

    /// Returns all fields in order.
    pub fn fields(&self) -> &[OAuthHttpField] {
        &self.fields
    }

    /// Every value of `name` in order, matched ASCII case-insensitively.
    pub fn values(&self, name: &str) -> Vec<&str> {
        self.fields
            .iter()
            .filter(|f| f.name.eq_ignore_ascii_case(name))
            .map(|f| f.value.as_str())
            .collect()
    }

    /// The value of `name` when it appears exactly once.
    pub fn single(&self, name: &str) -> Option<&str> {
        let mut iter = self
            .fields
            .iter()
            .filter(|f| f.name.eq_ignore_ascii_case(name))
            .map(|f| f.value.as_str());
        let first = iter.next()?;
        if iter.next().is_some() {
            None
        } else {
            Some(first)
        }
    }

    /// The first value of `name`.
    pub fn get(&self, name: &str) -> Option<&str> {
        self.fields
            .iter()
            .find(|f| f.name.eq_ignore_ascii_case(name))
            .map(|f| f.value.as_str())
    }

    /// Appends a header without removing existing ones with the same name.
    pub fn add(&mut self, name: impl Into<String>, value: impl Into<String>) {
        self.fields.push(OAuthHttpField {
            name: name.into(),
            value: value.into(),
        });
    }

    /// Replaces all headers matching `name` with a single value.
    pub fn set(&mut self, name: impl Into<String>, value: impl Into<String>) {
        let name = name.into();
        self.fields.retain(|f| !f.name.eq_ignore_ascii_case(&name));
        self.fields.push(OAuthHttpField {
            name,
            value: value.into(),
        });
    }
}

/// Framework-agnostic HTTP request passed into [`crate::oauth::OAuthAuthorizationServer`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthHttpRequest {
    /// Uppercased HTTP method (e.g. `POST`).
    pub method: String,
    /// Request path starting with `/`, without query.
    pub path: String,
    /// Raw query string without leading `?`.
    pub query: Option<String>,
    /// Request headers.
    pub headers: OAuthHttpHeaders,
    /// Request body bytes.
    pub body: Vec<u8>,
    /// Client's network address when known by the host adapter (rate limiting only).
    pub remote_address: Option<String>,
}

impl OAuthHttpRequest {
    /// Creates an HTTP request, uppercasing `method`.
    pub fn new(method: impl AsRef<str>, path: impl Into<String>) -> Self {
        Self {
            method: method.as_ref().to_ascii_uppercase(),
            path: path.into(),
            query: None,
            headers: OAuthHttpHeaders::default(),
            body: Vec::new(),
            remote_address: None,
        }
    }

    /// Sets the query string (without leading `?`).
    #[must_use]
    pub fn with_query(mut self, query: impl Into<String>) -> Self {
        self.query = Some(query.into());
        self
    }

    /// Sets the request headers.
    #[must_use]
    pub fn with_headers(mut self, headers: OAuthHttpHeaders) -> Self {
        self.headers = headers;
        self
    }

    /// Sets the request body.
    #[must_use]
    pub fn with_body(mut self, body: impl Into<Vec<u8>>) -> Self {
        self.body = body.into();
        self
    }

    /// Sets the client remote address.
    #[must_use]
    pub fn with_remote_address(mut self, addr: impl Into<String>) -> Self {
        self.remote_address = Some(addr.into());
        self
    }
}

/// Framework-agnostic HTTP response returned by [`crate::oauth::OAuthAuthorizationServer`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthHttpResponse {
    /// HTTP status code.
    pub status: u16,
    /// Response headers.
    pub headers: OAuthHttpHeaders,
    /// Response body bytes.
    pub body: Vec<u8>,
}

impl OAuthHttpResponse {
    /// Creates a response with optional empty body.
    pub fn new(status: u16, headers: OAuthHttpHeaders, body: Vec<u8>) -> Self {
        Self {
            status,
            headers,
            body,
        }
    }

    /// Returns the body interpreted as UTF-8 lossily (for tests/diagnostics).
    pub fn text(&self) -> String {
        String::from_utf8_lossy(&self.body).into_owned()
    }
}

/// Route metadata exposed by [`crate::oauth::OAuthAuthorizationServer::routes`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct OAuthRoute {
    /// HTTP method (`GET`, `POST`, `OPTIONS`).
    pub method: &'static str,
    /// Exact route path.
    pub path: &'static str,
}

/// Errors from strict `application/x-www-form-urlencoded` parsing.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OAuthFormError {
    Malformed,
    TooLarge,
}

impl From<OAuthFormError> for OAuthServerError {
    fn from(err: OAuthFormError) -> Self {
        match err {
            OAuthFormError::Malformed => Self::Malformed("form body is malformed".into()),
            OAuthFormError::TooLarge => Self::Malformed("form body is too large".into()),
        }
    }
}

/// Strict `application/x-www-form-urlencoded` parser rejecting repeated keys,
/// invalid percent-escapes, NUL bytes, and invalid UTF-8.
#[derive(Debug, Clone, Copy)]
pub struct OAuthForm;

impl OAuthForm {
    /// Checks for a single `Content-Type: application/x-www-form-urlencoded` header.
    pub fn is_form_content_type(headers: &OAuthHttpHeaders) -> bool {
        let Some(value) = headers.single("Content-Type") else {
            return false;
        };
        let media_type = value
            .split(';')
            .next()
            .unwrap_or("")
            .trim()
            .to_ascii_lowercase();
        media_type == "application/x-www-form-urlencoded"
    }

    /// Parses a form-encoded body under `max_bytes`.
    pub fn parse(data: &[u8], max_bytes: usize) -> Result<HashMap<String, String>, OAuthFormError> {
        if data.len() > max_bytes {
            return Err(OAuthFormError::TooLarge);
        }
        Self::parse_bytes(data)
    }

    /// Parses a raw query string (up to 8192 bytes).
    pub fn parse_query(
        query: Option<&str>,
        max_bytes: usize,
    ) -> Result<HashMap<String, String>, OAuthFormError> {
        let Some(query) = query.filter(|q| !q.is_empty()) else {
            return Ok(HashMap::new());
        };
        if query.len() > max_bytes {
            return Err(OAuthFormError::TooLarge);
        }
        Self::parse_bytes(query.as_bytes())
    }

    fn parse_bytes(bytes: &[u8]) -> Result<HashMap<String, String>, OAuthFormError> {
        let mut fields = HashMap::new();
        if bytes.is_empty() {
            return Ok(fields);
        }
        for pair in bytes.split(|&b| b == b'&') {
            if pair.is_empty() {
                return Err(OAuthFormError::Malformed);
            }
            let mut split = pair.splitn(2, |&b| b == b'=');
            let raw_name = split.next().ok_or(OAuthFormError::Malformed)?;
            let raw_value = split.next().unwrap_or(b"");
            let name = Self::decode_component(raw_name)?;
            let value = Self::decode_component(raw_value)?;
            if name.is_empty() || fields.insert(name, value).is_some() {
                return Err(OAuthFormError::Malformed);
            }
        }
        Ok(fields)
    }

    fn decode_component(encoded: &[u8]) -> Result<String, OAuthFormError> {
        let mut output = Vec::with_capacity(encoded.len());
        let mut i = 0;
        while i < encoded.len() {
            match encoded[i] {
                b'+' => {
                    output.push(b' ');
                    i += 1;
                }
                b'%' => {
                    if i + 2 >= encoded.len() {
                        return Err(OAuthFormError::Malformed);
                    }
                    let hi = hex_digit(encoded[i + 1]).ok_or(OAuthFormError::Malformed)?;
                    let lo = hex_digit(encoded[i + 2]).ok_or(OAuthFormError::Malformed)?;
                    output.push((hi << 4) | lo);
                    i += 3;
                }
                byte => {
                    output.push(byte);
                    i += 1;
                }
            }
        }
        let text = String::from_utf8(output).map_err(|_| OAuthFormError::Malformed)?;
        if text.as_bytes().contains(&0) {
            return Err(OAuthFormError::Malformed);
        }
        Ok(text)
    }

    /// Encodes one query/form component, leaving only RFC 3986 unreserved bytes unescaped.
    pub fn encode_component(value: &str) -> String {
        let mut output = String::with_capacity(value.len());
        for &byte in value.as_bytes() {
            if byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'.' | b'_' | b'~') {
                output.push(char::from(byte));
            } else {
                use std::fmt::Write as _;
                let _ = write!(output, "%{byte:02X}");
            }
        }
        output
    }
}

fn hex_digit(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        _ => None,
    }
}
