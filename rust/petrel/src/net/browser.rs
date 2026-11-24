//! Browser Fetch transport with credential-free browser state and manual redirects.

use std::time::Duration;

use bytes::{Bytes, BytesMut};
use http::{
    HeaderName, HeaderValue, Request, Response,
    header::{CONTENT_ENCODING, CONTENT_LENGTH, HOST},
};
use js_sys::{Array, Function, Promise, Reflect, Uint8Array};
use wasm_bindgen::{JsCast, JsValue};
use wasm_bindgen_futures::JsFuture;
use web_sys::{
    AbortController, Headers, ReadableStreamDefaultReader, RequestCredentials, RequestInit,
    RequestMode, RequestRedirect, ResponseType,
};

use super::{
    HttpTransport, SendOptions, TransportError,
    policy::{retain_anonymous_headers, validate_request_uri},
};

/// Fetch transport for browsers and Web Workers.
///
/// The browser resolves hostnames and decodes content, so Petrel cannot
/// enforce connection-IP, wire-byte, or decompression-ratio limits. It
/// bounds the decoded stream and denies opaque redirects because the
/// browser does not expose the destination for per-hop policy checks.
#[derive(Debug, Clone, Copy, Default)]
pub struct FetchTransport;

impl HttpTransport for FetchTransport {
    async fn send(
        &self,
        request: Request<Bytes>,
        options: &SendOptions,
    ) -> Result<Response<Bytes>, TransportError> {
        let (mut parts, body) = request.into_parts();
        let (url, origin) = validate_request_uri(&parts.uri, options.allow_loopback)
            .map_err(|error| TransportError::PolicyViolation(error.to_string()))?;
        if !matches!(origin.scheme(), "http" | "https") {
            return Err(TransportError::InvalidRequest(
                "Fetch transport requires HTTP or HTTPS".to_owned(),
            ));
        }
        if options.anonymous {
            retain_anonymous_headers(&mut parts.headers);
        }
        parts.headers.remove(HOST);

        let controller = AbortOnDrop(AbortController::new().map_err(js_failure)?);
        let headers = Headers::new().map_err(js_failure)?;
        for (name, value) in &parts.headers {
            let value = value.to_str().map_err(|_| {
                TransportError::InvalidRequest("Fetch requires text request headers".to_owned())
            })?;
            headers.append(name.as_str(), value).map_err(js_failure)?;
        }

        let init = RequestInit::new();
        init.set_method(parts.method.as_str());
        init.set_mode(RequestMode::Cors);
        init.set_referrer("");
        init.set_credentials(RequestCredentials::Omit);
        init.set_redirect(RequestRedirect::Manual);
        init.set_signal(Some(&controller.0.signal()));
        init.set_headers_headers(&headers);
        if !body.is_empty() {
            init.set_body(&Uint8Array::from(body.as_ref()));
        }
        let request =
            web_sys::Request::new_with_str_and_init(url.as_str(), &init).map_err(js_failure)?;

        let limit = options
            .max_response_bytes
            .unwrap_or(10 * 1024 * 1024)
            .min(128 * 1024 * 1024);
        let duration = options.timeout.unwrap_or(Duration::from_secs(30));
        crate::rt::timeout(duration, exchange(request, limit))
            .await
            .map_err(|_| TransportError::Timeout)?
    }
}

struct AbortOnDrop(AbortController);

impl Drop for AbortOnDrop {
    fn drop(&mut self) {
        self.0.abort();
    }
}

async fn exchange(
    request: web_sys::Request,
    limit: u64,
) -> Result<Response<Bytes>, TransportError> {
    let global = js_sys::global();
    let fetch: Function = Reflect::get(&global, &JsValue::from_str("fetch"))
        .and_then(JsCast::dyn_into)
        .map_err(js_failure)?;
    let promise: Promise = fetch
        .call1(&global, &request)
        .and_then(JsCast::dyn_into)
        .map_err(js_failure)?;
    let response: web_sys::Response = JsFuture::from(promise)
        .await
        .and_then(JsCast::dyn_into)
        .map_err(js_failure)?;
    if response.type_() == ResponseType::Opaqueredirect || response.redirected() {
        return Err(TransportError::PolicyViolation(
            "browser Fetch hides redirect destinations".to_owned(),
        ));
    }
    let mut result = Response::builder().status(response.status());

    // Only CORS-exposed response headers are visible to a browser client.
    let headers = response.headers();
    let iter = js_sys::try_iter(headers.as_ref())
        .map_err(js_failure)?
        .ok_or_else(|| {
            TransportError::Other("browser response headers are not iterable".to_owned())
        })?;
    for entry in iter {
        let entry: Array = entry.and_then(JsCast::dyn_into).map_err(js_failure)?;
        let name = entry.get(0).as_string().ok_or_else(invalid_response)?;
        let value = entry.get(1).as_string().ok_or_else(invalid_response)?;
        let name = HeaderName::from_bytes(name.as_bytes()).map_err(|_| invalid_response())?;
        let value = HeaderValue::from_str(&value).map_err(|_| invalid_response())?;
        result = result.header(name, value);
    }
    if let Some(headers) = result.headers_mut() {
        if headers.remove(CONTENT_ENCODING).is_some() {
            headers.remove(CONTENT_LENGTH);
        }
    }

    let mut bytes = BytesMut::new();
    if let Some(stream) = response.body() {
        let reader: ReadableStreamDefaultReader = stream
            .get_reader()
            .dyn_into()
            .map_err(|_| invalid_response())?;
        loop {
            let read = JsFuture::from(reader.read()).await.map_err(js_failure)?;
            let done = Reflect::get(&read, &JsValue::from_str("done")).map_err(js_failure)?;
            if done.as_bool() == Some(true) {
                break;
            }
            let chunk: Uint8Array = Reflect::get(&read, &JsValue::from_str("value"))
                .and_then(JsCast::dyn_into)
                .map_err(js_failure)?;
            let length = u64::from(chunk.length());
            if length > limit - bytes.len() as u64 {
                return Err(TransportError::ResponseTooLarge { limit });
            }
            let written = bytes.len();
            bytes.resize(written + chunk.length() as usize, 0);
            chunk.copy_to(&mut bytes[written..]);
        }
    }
    result.body(bytes.freeze()).map_err(|_| invalid_response())
}

#[allow(clippy::needless_pass_by_value)]
fn js_failure(_: JsValue) -> TransportError {
    TransportError::Other("browser Fetch failed".to_owned())
}

fn invalid_response() -> TransportError {
    TransportError::Other("invalid browser Fetch response".to_owned())
}
