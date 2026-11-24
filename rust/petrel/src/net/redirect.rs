use bytes::Bytes;
use http::{
    Method, Request, Response, StatusCode,
    header::{AUTHORIZATION, CONTENT_ENCODING, CONTENT_LENGTH, CONTENT_TYPE, HOST, LOCATION},
};
use url::Url;

use super::{
    DynHttpTransport, SendOptions, TransportError,
    policy::{
        Origin, retain_anonymous_headers, strip_sensitive_headers, validate_redirect,
        validate_url_with_development,
    },
};

const MAX_REDIRECTS: usize = 5;

/// Whether Petrel is permitted to follow a redirect after an exchange. The
/// underlying transport always performs just one exchange.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum RedirectPolicy {
    /// Return the server's response, including any redirect status.
    #[default]
    Never,
    /// Follow up to five visible redirects, enforcing destination policy at each hop.
    Follow,
}

/// The origin that returned a response after Petrel followed redirects.
#[derive(Debug, Clone)]
pub struct ResponseOrigin(pub Origin);

/// Send one request, optionally following redirects with Petrel's per-hop policy.
///
/// A Fetch-backed transport may be unable to see redirect details in a browser.
pub async fn send_with_redirects(
    transport: &dyn DynHttpTransport,
    mut request: Request<Bytes>,
    options: &SendOptions,
    redirects: RedirectPolicy,
) -> Result<Response<Bytes>, TransportError> {
    let mut url = Url::parse(&request.uri().to_string())
        .map_err(|error| TransportError::InvalidRequest(error.to_string()))?;
    let mut origin = validate_url_with_development(&url, options.allow_loopback)
        .map_err(|error| TransportError::PolicyViolation(error.to_string()))?;
    if options.anonymous {
        retain_anonymous_headers(request.headers_mut());
    }
    request.headers_mut().remove(HOST);

    for hop in 0..=MAX_REDIRECTS {
        let mut response = transport.send_dyn(request.clone(), options).await?;
        response
            .extensions_mut()
            .insert(ResponseOrigin(origin.clone()));
        if redirects == RedirectPolicy::Never || !is_redirect(response.status()) {
            return Ok(response);
        }

        let Some(location) = response.headers().get(LOCATION) else {
            return Ok(response);
        };
        if hop == MAX_REDIRECTS {
            return Err(TransportError::PolicyViolation(
                "redirect limit exceeded".to_owned(),
            ));
        }

        url = url
            .join(location.to_str().map_err(invalid_location)?)
            .map_err(invalid_location)?;
        // A redirect fragment identifies a position in the client; it is never sent over HTTP.
        url.set_fragment(None);
        let next_origin = validate_redirect(&origin, &url, options.allow_loopback)
            .map_err(|error| TransportError::PolicyViolation(error.to_string()))?;
        update_request(&mut request, response.status(), origin != next_origin)?;
        *request.uri_mut() = url.as_str().parse().map_err(invalid_location)?;
        origin = next_origin;
    }

    unreachable!("every redirect either advances or reaches the limit")
}

fn invalid_location(_: impl std::error::Error) -> TransportError {
    TransportError::PolicyViolation("invalid redirect location".to_owned())
}

fn is_redirect(status: StatusCode) -> bool {
    matches!(
        status,
        StatusCode::MOVED_PERMANENTLY
            | StatusCode::FOUND
            | StatusCode::SEE_OTHER
            | StatusCode::TEMPORARY_REDIRECT
            | StatusCode::PERMANENT_REDIRECT
    )
}

fn update_request(
    request: &mut Request<Bytes>,
    status: StatusCode,
    cross_origin: bool,
) -> Result<(), TransportError> {
    let switch_to_get = status == StatusCode::SEE_OTHER && request.method() != Method::HEAD
        || matches!(status, StatusCode::MOVED_PERMANENTLY | StatusCode::FOUND)
            && request.method() == Method::POST;
    if switch_to_get {
        *request.method_mut() = Method::GET;
        *request.body_mut() = Bytes::new();
        for name in [CONTENT_ENCODING, CONTENT_LENGTH, CONTENT_TYPE] {
            request.headers_mut().remove(name);
        }
    }

    let headers = request.headers_mut();
    if headers.remove("dpop").is_some() || headers.remove("x-dpop").is_some() {
        // The proof signed the original URI. An auth-aware caller must sign again if required.
        headers.remove("x-dpop");
        headers.remove(AUTHORIZATION);
    }
    if cross_origin {
        strip_sensitive_headers(headers);
        if !request.body().is_empty() {
            return Err(TransportError::PolicyViolation(
                "redirect would replay the request body at a different origin".to_owned(),
            ));
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cross_origin_redirect_removes_credentials_and_routing() {
        let mut request = Request::builder()
            .header("authorization", "Bearer stub")
            .header("dpop", "test-proof")
            .header("atproto-proxy", "did:web:api.bsky.app#bsky_appview")
            .header("atproto-accept-labelers", "did:plc:a;redact")
            .header("cookie", "session=test")
            .header("accept", "application/json")
            .body(Bytes::new())
            .unwrap();
        update_request(&mut request, StatusCode::FOUND, true).unwrap();
        assert_eq!(request.headers().len(), 1);
        assert_eq!(request.headers()["accept"], "application/json");
    }

    #[test]
    fn cross_origin_redirect_cannot_replay_a_nonempty_procedure_body() {
        let mut request = Request::builder()
            .method(Method::POST)
            .header(CONTENT_TYPE, "application/json")
            .body(Bytes::from_static(b"{}"))
            .unwrap();
        assert!(matches!(
            update_request(&mut request, StatusCode::PERMANENT_REDIRECT, true),
            Err(TransportError::PolicyViolation(_))
        ));
        update_request(&mut request, StatusCode::SEE_OTHER, true).unwrap();
        assert_eq!(request.method(), Method::GET);
        assert!(request.body().is_empty());
        assert!(!request.headers().contains_key(CONTENT_TYPE));
    }
}
