use std::collections::HashMap;

use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};

use crate::clients::OAuthResolvedClientMetadata;
use crate::error::OAuthServerError;
use crate::http::OAuthHttpResponse;
use crate::lexicon::OAuthScopeDescription;
use crate::store::OAuthGrantBinding;

/// Decision submitted by the consent form POST handler.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OAuthConsentAction {
    Approve,
    Deny,
}

/// Request handed to [`OAuthAccountAuthenticating`] when the user approves authorization.
#[derive(Debug, Clone)]
pub struct OAuthAccountAuthenticateRequest {
    pub client_id: String,
    pub scope: String,
    pub login_hint: Option<String>,
    pub form_fields: HashMap<String, String>,
}

/// Authenticated user account returned by [`OAuthAccountAuthenticating`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthAuthenticatedAccount {
    pub binding: OAuthGrantBinding,
    pub handle: Option<String>,
}

/// Pluggable user-authentication backend invoked on `POST /oauth/authorize`.
pub trait OAuthAccountAuthenticating: MaybeSend + MaybeSync {
    fn authenticate(
        &self,
        request: OAuthAccountAuthenticateRequest,
    ) -> BoxFuture<'_, Result<Option<OAuthAuthenticatedAccount>, OAuthServerError>>;
}

/// View-model handed to [`OAuthInterfaceRendering`] when displaying the login & consent UI.
#[derive(Debug, Clone)]
pub struct OAuthAuthorizationPageRequest {
    pub flow_id: String,
    pub csrf_token: String,
    pub action_url: String,
    pub client: OAuthResolvedClientMetadata,
    pub redirect_uri: String,
    pub requested_scope: String,
    pub scope_descriptions: Vec<OAuthScopeDescription>,
    pub login_hint: Option<String>,
    pub error_message: Option<String>,
}

/// Pluggable HTML/UI renderer for `/oauth/authorize` consent pages.
pub trait OAuthInterfaceRendering: MaybeSend + MaybeSync {
    fn render_authorization_page(
        &self,
        request: OAuthAuthorizationPageRequest,
    ) -> BoxFuture<'_, Result<OAuthHttpResponse, OAuthServerError>>;
}

/// Default HTML consent page renderer escaping all untrusted fields.
#[derive(Debug, Default, Clone, Copy)]
pub struct DefaultOAuthHtmlRenderer;

impl DefaultOAuthHtmlRenderer {
    fn escape_html(raw: &str) -> String {
        let mut out = String::with_capacity(raw.len());
        for ch in raw.chars() {
            match ch {
                '&' => out.push_str("&amp;"),
                '<' => out.push_str("&lt;"),
                '>' => out.push_str("&gt;"),
                '"' => out.push_str("&quot;"),
                '\'' => out.push_str("&#39;"),
                c => out.push(c),
            }
        }
        out
    }
}

impl OAuthInterfaceRendering for DefaultOAuthHtmlRenderer {
    fn render_authorization_page(
        &self,
        request: OAuthAuthorizationPageRequest,
    ) -> BoxFuture<'_, Result<OAuthHttpResponse, OAuthServerError>> {
        Box::pin(async move {
            let client_name = Self::escape_html(
                request
                    .client
                    .metadata
                    .client_name
                    .as_deref()
                    .unwrap_or(&request.client.metadata.client_id),
            );
            let client_id = Self::escape_html(&request.client.metadata.client_id);
            let action = Self::escape_html(&request.action_url);
            let flow_id = Self::escape_html(&request.flow_id);
            let csrf = Self::escape_html(&request.csrf_token);
            let login_hint = Self::escape_html(request.login_hint.as_deref().unwrap_or(""));
            let error_html = request
                .error_message
                .as_deref()
                .map(|msg| format!("<p role=\"alert\">{}</p>", Self::escape_html(msg)))
                .unwrap_or_default();

            let mut scopes_html = String::new();
            for desc in &request.scope_descriptions {
                use std::fmt::Write as _;
                let title = Self::escape_html(desc.title.as_deref().unwrap_or(&desc.scope));
                let detail = desc
                    .detail
                    .as_deref()
                    .map(|d| format!(" — {}", Self::escape_html(d)))
                    .unwrap_or_default();
                let _ = write!(scopes_html, "<li><strong>{title}</strong>{detail}</li>");
            }

            let html = format!(
                "<!doctype html><html><head><meta charset=\"utf-8\"><title>Authorize {client_name}</title></head>\
<body><h1>Authorize {client_name}</h1><p>Client: <code>{client_id}</code></p>{error_html}\
<ul>{scopes_html}</ul>\
<form method=\"POST\" action=\"{action}\">\
<input type=\"hidden\" name=\"flow_id\" value=\"{flow_id}\">\
<input type=\"hidden\" name=\"csrf_token\" value=\"{csrf}\">\
<label>Handle or DID: <input type=\"text\" name=\"identifier\" value=\"{login_hint}\"></label>\
<label>Password: <input type=\"password\" name=\"password\"></label>\
<button type=\"submit\" name=\"decision\" value=\"approve\">Authorize</button>\
<button type=\"submit\" name=\"decision\" value=\"deny\">Deny</button>\
</form></body></html>"
            );

            let mut form_action = "'self'".to_owned();
            if let Some(redirect_source) = form_action_source(&request.redirect_uri) {
                form_action.push(' ');
                form_action.push_str(&redirect_source);
            }

            let mut headers = crate::http::OAuthHttpHeaders::default();
            headers.set("Content-Type", "text/html; charset=utf-8");
            headers.set("Cache-Control", "no-store");
            headers.set("X-Frame-Options", "DENY");
            headers.set(
                "Content-Security-Policy",
                format!(
                    "default-src 'none'; style-src 'unsafe-inline'; form-action {form_action}; frame-ancestors 'none'; base-uri 'none'"
                ),
            );
            Ok(OAuthHttpResponse::new(200, headers, html.into_bytes()))
        })
    }
}

fn form_action_source(redirect_uri: &str) -> Option<String> {
    let url = url::Url::parse(redirect_uri).ok()?;
    let scheme = url.scheme().to_ascii_lowercase();
    if !scheme
        .bytes()
        .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || matches!(b, b'+' | b'-' | b'.'))
    {
        return None;
    }
    if matches!(scheme.as_str(), "https" | "http")
        && let Some(host) = url.host_str()
    {
        let host_text = if host.contains(':') && !host.starts_with('[') {
            format!("[{host}]")
        } else {
            host.to_owned()
        };
        return match url.port() {
            Some(port) => Some(format!("{scheme}://{host_text}:{port}")),
            None => Some(format!("{scheme}://{host_text}")),
        };
    }
    Some(format!("{scheme}:"))
}
