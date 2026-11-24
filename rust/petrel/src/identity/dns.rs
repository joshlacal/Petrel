use std::{future::Future, time::Duration};

#[cfg(not(target_arch = "wasm32"))]
use std::net::IpAddr;

use bytes::Bytes;
use http::{Request, header::ACCEPT};
use serde::Deserialize;
use thiserror::Error;
use url::Url;

use crate::{
    net::{SendOptions, SharedTransport, TransportError, policy::validate_url},
    rt::{MaybeSend, MaybeSync},
};

#[derive(Debug, Error)]
#[non_exhaustive]
pub enum DnsError {
    #[error("DNS lookup failed: {0}")]
    Lookup(String),
    #[error("DNS-over-HTTPS request failed: {0}")]
    Transport(#[from] TransportError),
    #[error("DNS-over-HTTPS response was invalid")]
    InvalidResponse,
}

/// Resolve DNS TXT records for handles and resolve connection addresses on native platforms.
pub trait DnsResolver: MaybeSend + MaybeSync {
    fn txt(&self, name: &str) -> impl Future<Output = Result<Vec<String>, DnsError>> + MaybeSend;

    /// Resolve the whole address set, leaving all policy decisions to the transport.
    #[cfg(not(target_arch = "wasm32"))]
    fn lookup_ip(
        &self,
        host: &str,
    ) -> impl Future<Output = Result<Vec<IpAddr>, DnsError>> + MaybeSend;
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
mod native {
    use hickory_resolver::{TokioResolver, proto::rr::RData};

    use super::*;

    /// Native DNS resolver using the operating system's resolver configuration.
    #[derive(Clone)]
    pub struct HickoryResolver(TokioResolver);

    impl std::fmt::Debug for HickoryResolver {
        fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            f.debug_struct("HickoryResolver").finish_non_exhaustive()
        }
    }

    impl HickoryResolver {
        pub fn system() -> Result<Self, DnsError> {
            let builder = TokioResolver::builder_tokio().map_err(lookup_error)?;
            builder.build().map(Self).map_err(lookup_error)
        }
    }

    impl DnsResolver for HickoryResolver {
        async fn txt(&self, name: &str) -> Result<Vec<String>, DnsError> {
            // A fully qualified name never falls back through a local search suffix.
            let name = format!("{}.", name.trim_end_matches('.'));
            match self.0.txt_lookup(name.as_str()).await {
                Ok(answer) => Ok(answer
                    .answers()
                    .iter()
                    .filter_map(|record| match record.data() {
                        RData::TXT(txt) => {
                            let joined: Vec<u8> = txt.iter().flatten().copied().collect();
                            String::from_utf8(joined).ok()
                        }
                        _ => None,
                    })
                    .collect()),
                Err(error) if error.is_nx_domain() || error.is_no_records_found() => Ok(Vec::new()),
                Err(error) => Err(lookup_error(error)),
            }
        }

        async fn lookup_ip(&self, host: &str) -> Result<Vec<IpAddr>, DnsError> {
            match self.0.lookup_ip(host).await {
                Ok(answers) => Ok(answers.iter().collect()),
                Err(error) if error.is_nx_domain() || error.is_no_records_found() => Ok(Vec::new()),
                Err(error) => Err(lookup_error(error)),
            }
        }
    }

    fn lookup_error(error: impl std::fmt::Display) -> DnsError {
        DnsError::Lookup(error.to_string())
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub use native::HickoryResolver;

/// DNS-over-HTTPS TXT resolver. The operator of the configured endpoint sees handle lookups.
#[derive(Clone)]
pub struct DohResolver {
    endpoint: Url,
    transport: SharedTransport,
}

impl std::fmt::Debug for DohResolver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DohResolver")
            .field("endpoint", &self.endpoint)
            .finish_non_exhaustive()
    }
}

impl DohResolver {
    pub fn new(endpoint: Url, transport: SharedTransport) -> Result<Self, DnsError> {
        validate_url(&endpoint).map_err(|error| DnsError::Lookup(error.to_string()))?;
        if endpoint.scheme() != "https" {
            return Err(DnsError::Lookup("DNS-over-HTTPS requires HTTPS".to_owned()));
        }
        Ok(Self {
            endpoint,
            transport,
        })
    }

    pub fn cloudflare(transport: SharedTransport) -> Self {
        Self {
            endpoint: Url::parse("https://cloudflare-dns.com/dns-query")
                .expect("fixed DNS endpoint"),
            transport,
        }
    }
}

impl DnsResolver for DohResolver {
    async fn txt(&self, name: &str) -> Result<Vec<String>, DnsError> {
        let mut url = self.endpoint.clone();
        url.query_pairs_mut()
            .append_pair("name", name)
            .append_pair("type", "TXT");
        let request = Request::get(url.as_str())
            .header(ACCEPT, "application/dns-json")
            .body(Bytes::new())
            .map_err(|_| DnsError::InvalidResponse)?;
        let options = SendOptions {
            timeout: Some(Duration::from_secs(5)),
            max_response_bytes: Some(16 * 1024),
            anonymous: true,
            ..SendOptions::default()
        };
        let response = self.transport.send_dyn(request, &options).await?;
        if !response.status().is_success() || response.body().len() > 16 * 1024 {
            return Err(DnsError::InvalidResponse);
        }
        parse_dns_json(response.body())
    }

    #[cfg(not(target_arch = "wasm32"))]
    async fn lookup_ip(&self, _host: &str) -> Result<Vec<IpAddr>, DnsError> {
        Err(DnsError::Lookup(
            "this resolver only provides TXT records".to_owned(),
        ))
    }
}

#[derive(Debug, Deserialize)]
struct DnsJson {
    #[serde(rename = "Status")]
    status: u8,
    #[serde(rename = "TC", default)]
    truncated: bool,
    #[serde(rename = "Answer", default)]
    answer: Vec<DnsJsonAnswer>,
}

#[derive(Debug, Deserialize)]
struct DnsJsonAnswer {
    #[serde(rename = "type")]
    kind: u16,
    data: String,
}

fn parse_dns_json(body: &[u8]) -> Result<Vec<String>, DnsError> {
    let response: DnsJson = serde_json::from_slice(body).map_err(|_| DnsError::InvalidResponse)?;
    match response.status {
        _ if response.truncated => Err(DnsError::InvalidResponse),
        0 => Ok(response
            .answer
            .iter()
            .filter(|answer| answer.kind == 16)
            .filter_map(|answer| parse_txt_data(&answer.data))
            .collect()),
        3 => Ok(Vec::new()),
        status => Err(DnsError::Lookup(format!("DNS response code {status}"))),
    }
}

fn parse_txt_data(data: &str) -> Option<String> {
    let data = data.trim();
    if !data.starts_with('"') {
        return (!data.contains(['"', '\\'])).then(|| data.to_owned());
    }

    let mut output = Vec::new();
    let mut remaining = data.as_bytes();
    while let Some(contents) = remaining.strip_prefix(b"\"") {
        let mut bytes = contents;
        loop {
            let (&byte, tail) = bytes.split_first()?;
            bytes = tail;
            match byte {
                b'"' => break,
                b'\\' => {
                    let (&escape, tail) = bytes.split_first()?;
                    if escape.is_ascii_digit() {
                        let digits = bytes.get(..3)?;
                        let number: u8 = std::str::from_utf8(digits).ok()?.parse().ok()?;
                        output.push(number);
                        bytes = &bytes[3..];
                    } else {
                        output.push(escape);
                        bytes = tail;
                    }
                }
                _ => output.push(byte),
            }
        }
        remaining = bytes.trim_ascii_start();
    }
    if !remaining.is_empty() {
        return None;
    }
    String::from_utf8(output).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_doh_txt_and_status() {
        let body = br#"{"Status":0,"Answer":[{"type":5,"data":"alias."},{"type":16,"data":"\"did=\" \"did:plc:x\""},{"type":16,"data":"\"did=did:plc:y\""}]}"#;
        assert_eq!(
            parse_dns_json(body).unwrap(),
            ["did=did:plc:x", "did=did:plc:y"]
        );
        assert!(parse_dns_json(br#"{"Status":3}"#).unwrap().is_empty());
        assert!(parse_dns_json(br#"{"Status":2}"#).is_err());
        assert!(parse_dns_json(br#"{"Status":0,"TC":true}"#).is_err());
    }

    #[test]
    fn joins_only_valid_txt_character_strings() {
        assert_eq!(
            parse_txt_data(r#""did=did:plc:\120""#).as_deref(),
            Some("did=did:plc:x")
        );
        assert_eq!(parse_txt_data(r#""did=did:plc:x" trailing"#), None);
        assert_eq!(parse_txt_data(r#""unclosed"#), None);
    }
}
