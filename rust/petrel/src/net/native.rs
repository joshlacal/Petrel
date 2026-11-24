//! Native transport using the same approved DNS answers for validation and connection.

use std::{error::Error, net::SocketAddr, sync::Arc, time::Duration};

use bytes::{Bytes, BytesMut};
use http::{
    Method, Request, Response, StatusCode,
    header::{ACCEPT_ENCODING, CONTENT_ENCODING, CONTENT_LENGTH, HOST},
};
use reqwest::dns::{Addrs, Name, Resolve, Resolving};
use url::Url;

use crate::identity::{DnsResolver, HickoryResolver};

use super::{
    HttpTransport, SendOptions, TransportError,
    body::{DecodeError, decode},
    policy::{
        PolicyError, retain_anonymous_headers, validate_resolved_addresses,
        validate_url_with_development,
    },
};

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);
const DEFAULT_LIMIT: usize = 10 * 1024 * 1024;
const MAX_LIMIT: usize = 128 * 1024 * 1024;
const MAX_EXPANSION_RATIO: usize = 20;

/// Native HTTP transport using rustls without proxies, cookies, or automatic redirects.
#[derive(Debug, Clone)]
pub struct ReqwestTransport {
    client: reqwest::Client,
}

impl ReqwestTransport {
    pub fn new() -> Result<Self, TransportError> {
        let resolver = HickoryResolver::system()
            .map_err(|error| TransportError::Connect(error.to_string()))?;
        Self::with_dns(resolver)
    }

    /// Use a DNS resolver whose exact answers will be checked by the connector policy.
    pub fn with_dns(dns: impl DnsResolver + 'static) -> Result<Self, TransportError> {
        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .retry(reqwest::retry::never())
            .no_proxy()
            .no_gzip()
            .no_deflate()
            .no_brotli()
            .no_zstd()
            .dns_resolver(Arc::new(FilteringDns(Arc::new(dns))))
            .build()
            .map_err(map_reqwest)?;
        Ok(Self { client })
    }
}

impl HttpTransport for ReqwestTransport {
    async fn send(
        &self,
        request: Request<Bytes>,
        options: &SendOptions,
    ) -> Result<Response<Bytes>, TransportError> {
        let (mut parts, body) = request.into_parts();
        let url = Url::parse(&parts.uri.to_string())
            .map_err(|error| TransportError::InvalidRequest(error.to_string()))?;
        let origin = validate_url_with_development(&url, options.allow_loopback)
            .map_err(|error| TransportError::PolicyViolation(error.to_string()))?;
        if !matches!(origin.scheme(), "http" | "https") {
            return Err(TransportError::InvalidRequest(
                "transport requires HTTP or HTTPS".to_owned(),
            ));
        }
        if options.anonymous {
            retain_anonymous_headers(&mut parts.headers);
        }
        parts.headers.remove(HOST);
        parts
            .headers
            .entry(ACCEPT_ENCODING)
            .or_insert(http::HeaderValue::from_static("gzip, deflate, br"));

        let head = parts.method == Method::HEAD;
        let mut request = self
            .client
            .request(parts.method, url)
            .headers(parts.headers)
            .timeout(options.timeout.unwrap_or(DEFAULT_TIMEOUT));
        if !body.is_empty() {
            request = request.body(body);
        }
        let response = request.send().await.map_err(map_reqwest)?;
        read_response(response, options, head).await
    }
}

async fn read_response(
    mut response: reqwest::Response,
    options: &SendOptions,
    head: bool,
) -> Result<Response<Bytes>, TransportError> {
    let mut result = Response::builder()
        .status(response.status())
        .version(response.version());
    if head
        || matches!(
            response.status(),
            StatusCode::NO_CONTENT | StatusCode::NOT_MODIFIED
        )
    {
        let mut result = result.body(Bytes::new()).map_err(invalid_response)?;
        *result.headers_mut() = std::mem::take(response.headers_mut());
        return Ok(result);
    }

    let limit = options.max_response_bytes.map_or(DEFAULT_LIMIT, |limit| {
        usize::try_from(limit).unwrap_or(usize::MAX).min(MAX_LIMIT)
    });
    let large_response = || TransportError::ResponseTooLarge {
        limit: limit as u64,
    };
    if response
        .content_length()
        .is_some_and(|length| length > limit as u64)
    {
        return Err(large_response());
    }

    let mut wire = BytesMut::new();
    while let Some(chunk) = response.chunk().await.map_err(map_reqwest)? {
        if chunk.len() > limit - wire.len() {
            return Err(large_response());
        }
        wire.extend_from_slice(&chunk);
    }

    let mut headers = std::mem::take(response.headers_mut());
    let body =
        decode(wire.freeze(), &headers, limit, MAX_EXPANSION_RATIO).map_err(
            |error| match error {
                DecodeError::TooLarge => large_response(),
                DecodeError::Unsupported | DecodeError::Invalid(_) => {
                    TransportError::Other(error.to_string())
                }
            },
        )?;
    if headers.remove(CONTENT_ENCODING).is_some() {
        headers.remove(CONTENT_LENGTH);
    }

    *result
        .headers_mut()
        .ok_or_else(|| TransportError::Other("invalid HTTP response headers".to_owned()))? =
        headers;
    result.body(body).map_err(invalid_response)
}

fn invalid_response(error: http::Error) -> TransportError {
    TransportError::Other(error.to_string())
}

struct FilteringDns<D>(Arc<D>);

impl<D: DnsResolver + 'static> Resolve for FilteringDns<D> {
    fn resolve(&self, name: Name) -> Resolving {
        let dns = Arc::clone(&self.0);
        Box::pin(async move {
            let answers = dns.lookup_ip(name.as_str()).await?;
            validate_resolved_addresses(name.as_str(), &answers)?;
            Ok(Box::new(answers.into_iter().map(|ip| SocketAddr::new(ip, 0))) as Addrs)
        })
    }
}

fn map_reqwest(error: reqwest::Error) -> TransportError {
    let mut source = error.source();
    let mut connection_lost = false;
    while let Some(cause) = source {
        if let Some(policy) = cause.downcast_ref::<PolicyError>() {
            return if *policy == PolicyError::NoAddresses {
                TransportError::Connect(policy.to_string())
            } else {
                TransportError::PolicyViolation(policy.to_string())
            };
        }
        if let Some(io) = cause.downcast_ref::<std::io::Error>() {
            connection_lost |= matches!(
                io.kind(),
                std::io::ErrorKind::ConnectionReset
                    | std::io::ErrorKind::ConnectionAborted
                    | std::io::ErrorKind::BrokenPipe
                    | std::io::ErrorKind::UnexpectedEof
            );
        }
        source = cause.source();
    }
    if error.is_timeout() {
        return TransportError::Timeout;
    }
    if error.is_connect() {
        return TransportError::Connect(error.without_url().to_string());
    }
    if connection_lost {
        return TransportError::ConnectionLost(error.without_url().to_string());
    }
    TransportError::Other(error.without_url().to_string())
}
