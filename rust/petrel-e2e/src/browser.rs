use std::{collections::BTreeMap, time::Duration};

use reqwest::{Client, Response, StatusCode, header};
use url::{Host, Url};

use crate::{DEMO_HANDLE, DEMO_PASSWORD, TestResult, loopback_http_client};

/// Sign in and approve consent using the demo authorization interface. Returns
/// the callback URL from the server without making the callback request.
pub async fn headless_approve(origin: &Url, authorize_url: &Url) -> TestResult<Url> {
    if origin.scheme() != "http"
        || !matches!(origin.host(), Some(Host::Ipv4(address)) if address.is_loopback())
        || origin.origin() != authorize_url.origin()
        || authorize_url.path() != "/oauth/authorize"
    {
        return Err("expected an authorization URL on the local Swift server".into());
    }

    let browser = loopback_http_client(Duration::from_secs(5))?;
    let mut cookies = Cookies::default();
    let response = browser.get(authorize_url.clone()).send().await?;
    require_status(&response, StatusCode::OK, "authorization page")?;
    if response.headers().get(header::X_FRAME_OPTIONS)
        != Some(&header::HeaderValue::from_static("DENY"))
    {
        return Err("authorization page must refuse framing".into());
    }
    cookies.update(&response)?;

    let sign_in = response.text().await?;
    let response = post(
        &browser,
        &cookies,
        origin,
        "/oauth/authorize/sign-in",
        &[
            ("csrf", csrf_token(&sign_in)?),
            ("identifier", DEMO_HANDLE),
            ("password", DEMO_PASSWORD),
        ],
    )
    .await?;
    require_status(&response, StatusCode::OK, "demo account sign-in")?;
    cookies.update(&response)?;

    let consent = response.text().await?;
    if !consent.contains(r#"name="decision""#) {
        return Err("sign-in did not render the consent form".into());
    }
    let response = post(
        &browser,
        &cookies,
        origin,
        "/oauth/authorize/consent",
        &[("csrf", csrf_token(&consent)?), ("decision", "approve")],
    )
    .await?;
    require_status(&response, StatusCode::SEE_OTHER, "approved consent")?;
    let location = response
        .headers()
        .get(header::LOCATION)
        .ok_or("consent redirect has no Location")?;
    Ok(Url::parse(location.to_str()?)?)
}

async fn post(
    browser: &Client,
    cookies: &Cookies,
    origin: &Url,
    path: &str,
    fields: &[(&str, &str)],
) -> TestResult<Response> {
    let mut request = browser
        .post(origin.join(path)?)
        .header(header::ORIGIN, origin.origin().ascii_serialization())
        .form(fields);
    if !cookies.0.is_empty() {
        request = request.header(header::COOKIE, cookies.header_value());
    }
    Ok(request.send().await?)
}

#[derive(Default)]
struct Cookies(BTreeMap<String, String>);

// A single-origin jar for the example server's authorization UI. The driver
// never follows redirects, and the server sets cookies within this flow only.
impl Cookies {
    fn update(&mut self, response: &Response) -> TestResult<()> {
        for cookie in response.headers().get_all(header::SET_COOKIE) {
            let mut parts = cookie.to_str()?.split(';');
            let (name, value) = parts
                .next()
                .and_then(|pair| pair.split_once('='))
                .ok_or("malformed Set-Cookie")?;
            if value.is_empty() || parts.any(|attr| attr.trim().eq_ignore_ascii_case("Max-Age=0")) {
                self.0.remove(name);
            } else {
                self.0.insert(name.to_owned(), value.to_owned());
            }
        }
        Ok(())
    }

    fn header_value(&self) -> String {
        self.0
            .iter()
            .map(|(name, value)| format!("{name}={value}"))
            .collect::<Vec<_>>()
            .join("; ")
    }
}

fn csrf_token(html: &str) -> TestResult<&str> {
    html.split_once(r#"name="csrf" value=""#)
        .and_then(|(_, tail)| tail.split_once('"'))
        .map(|(value, _)| value)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| "authorization page has no CSRF token".into())
}

fn require_status(response: &Response, expected: StatusCode, step: &str) -> TestResult<()> {
    if response.status() == expected {
        return Ok(());
    }
    Err(format!(
        "{step}: expected {expected}, received {}",
        response.status()
    )
    .into())
}
