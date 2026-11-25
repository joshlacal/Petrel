use std::{
    collections::VecDeque,
    future::{Future, ready},
    sync::{Arc, Mutex},
};

use petrel_core::{AtIdentifier, Did};
use serde_json::json;

use super::*;
use crate::{
    net::HttpTransport,
    oauth::{
        OAuthClient, OAuthConfig, OAuthError, OAuthIdentity, OAuthIdentityError,
        OAuthIdentityResolver, OAuthTarget, metadata::example_metadata,
    },
    rt::{BoxFuture, MaybeSend},
    storage::{MemorySecretStore, SessionStore},
};

use MetadataDocument::{AuthorizationServer, ProtectedResource};

const PDS: &str = "https://pds.example";
const ISSUER: &str = "https://issuer.example";
const CLIENT: &str = "https://client.example/metadata.json";
const CAB: &str = "https://cab.example";

struct Exchange {
    uri: String,
    reply: Result<Response<Bytes>, TransportError>,
}

impl Exchange {
    fn new(
        origin: &str,
        document: MetadataDocument,
        reply: Result<Response<Bytes>, TransportError>,
    ) -> Self {
        Self {
            uri: format!("{origin}/.well-known/{}", document.name()),
            reply,
        }
    }
}

struct DiscoveryTransport {
    exchanges: Mutex<VecDeque<Exchange>>,
}

impl DiscoveryTransport {
    fn assert_finished(&self) {
        let exchanges = self.exchanges.lock().unwrap();
        assert!(exchanges.is_empty(), "{} exchanges unused", exchanges.len());
    }
}

impl HttpTransport for DiscoveryTransport {
    fn send(
        &self,
        request: Request<Bytes>,
        options: &SendOptions,
    ) -> impl Future<Output = Result<Response<Bytes>, TransportError>> + MaybeSend {
        let exchange = self.exchanges.lock().unwrap().pop_front();
        let exchange =
            exchange.unwrap_or_else(|| panic!("unexpected metadata request: {}", request.uri()));
        assert_eq!(request.uri().to_string(), exchange.uri);
        assert_eq!(request.method(), Method::GET);
        assert_eq!(request.headers()[header::ACCEPT], "application/json");
        assert!(request.headers().get(header::AUTHORIZATION).is_none());
        assert!(request.headers().get(header::COOKIE).is_none());
        assert!(request.headers().get("dpop").is_none());
        assert!(request.body().is_empty());
        assert!(options.anonymous);
        assert!(!options.allow_loopback);
        assert_eq!(options.timeout, Some(Duration::from_secs(30)));
        assert_eq!(options.max_response_bytes, Some(128 * 1024));
        ready(exchange.reply)
    }
}

fn fixture_transport(exchanges: impl IntoIterator<Item = Exchange>) -> Arc<DiscoveryTransport> {
    Arc::new(DiscoveryTransport {
        exchanges: Mutex::new(exchanges.into_iter().collect()),
    })
}

fn public_protocol(transport: SharedTransport) -> OAuthProtocol {
    OAuthProtocol {
        transport,
        client_id: CLIENT.to_owned(),
        authentication: ClientAuth::Public,
        allow_loopback: false,
        nonces: DpopNonces::default(),
    }
}

fn response(status: StatusCode, content_type: Option<&str>, body: Bytes) -> Response<Bytes> {
    let mut response = Response::builder().status(status);
    if let Some(content_type) = content_type {
        response = response.header(header::CONTENT_TYPE, content_type);
    }
    response.body(body).unwrap()
}

fn json_response(data: &impl Serialize) -> Response<Bytes> {
    response(
        StatusCode::OK,
        Some("application/json"),
        serde_json::to_vec(data).unwrap().into(),
    )
}

fn resource_document() -> Response<Bytes> {
    json_response(&json!({ "resource": PDS, "authorization_servers": [ISSUER] }))
}

async fn assert_pds_failure(
    document: MetadataDocument,
    failing_response: Response<Bytes>,
    expected_error: MetadataError,
) {
    let exchanges = match document {
        ProtectedResource => vec![Exchange::new(PDS, ProtectedResource, Ok(failing_response))],
        AuthorizationServer => vec![
            Exchange::new(PDS, ProtectedResource, Ok(resource_document())),
            Exchange::new(ISSUER, AuthorizationServer, Ok(failing_response)),
        ],
    };
    let transport = fixture_transport(exchanges);
    let protocol = public_protocol(transport.clone());
    let error = protocol
        .discover_pds(&Url::parse(PDS).unwrap())
        .await
        .unwrap_err();
    assert_eq!(error, expected_error);
    transport.assert_finished();
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn discovers_from_minimal_pds_metadata_and_accepts_json_parameters() {
    let mut metadata = example_metadata(ISSUER);
    metadata.protected_resources = Some(vec![PDS.to_owned()]);
    let mut issuer_response = json_response(&metadata);
    issuer_response.headers_mut().insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("Application/JSON; charset=utf-8"),
    );
    let transport = fixture_transport([
        Exchange::new(PDS, ProtectedResource, Ok(resource_document())),
        Exchange::new(ISSUER, AuthorizationServer, Ok(issuer_response)),
    ]);
    let protocol = public_protocol(transport.clone());
    let pds_url = Url::parse("https://PDS.example:443/xrpc/example?ignored=1").unwrap();
    let result = protocol.discover_pds(&pds_url).await.unwrap();

    assert_eq!(result.issuer(), ISSUER);
    assert_eq!(
        result.authorization_endpoint().as_str(),
        format!("{ISSUER}/authorize")
    );
    transport.assert_finished();
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn requires_status_200_and_does_not_follow_metadata_redirects() {
    for (document, status) in [
        (ProtectedResource, StatusCode::NO_CONTENT),
        (ProtectedResource, StatusCode::FOUND),
        (ProtectedResource, StatusCode::NOT_FOUND),
        (AuthorizationServer, StatusCode::CREATED),
        (AuthorizationServer, StatusCode::MOVED_PERMANENTLY),
        (AuthorizationServer, StatusCode::INTERNAL_SERVER_ERROR),
    ] {
        let mut reply = response(status, Some("application/json"), Bytes::new());
        if status.is_redirection() {
            reply.headers_mut().insert(
                header::LOCATION,
                HeaderValue::from_static("https://redirect.example/metadata"),
            );
        }
        assert_pds_failure(
            document,
            reply,
            MetadataError::UnexpectedStatus {
                document,
                status: status.as_u16(),
            },
        )
        .await;
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn requires_json_and_rejects_malformed_documents() {
    for document in [ProtectedResource, AuthorizationServer] {
        for content_type in [None, Some("text/html"), Some("application/problem+json")] {
            let reply = response(StatusCode::OK, content_type, Bytes::from_static(b"{}"));
            assert_pds_failure(document, reply, MetadataError::ContentType(document)).await;
        }
        let reply = response(
            StatusCode::OK,
            Some("application/json"),
            Bytes::from_static(b"{"),
        );
        assert_pds_failure(document, reply, MetadataError::MalformedDocument(document)).await;
    }
    // A structurally incomplete resource document cannot turn the PDS into an
    // issuer during an identifier-first discovery.
    assert_pds_failure(
        ProtectedResource,
        json_response(&json!({"unexpected": true})),
        MetadataError::MalformedDocument(ProtectedResource),
    )
    .await;
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn server_target_prefers_its_valid_protected_resource_document() {
    let transport = fixture_transport([
        Exchange::new(PDS, ProtectedResource, Ok(resource_document())),
        Exchange::new(
            ISSUER,
            AuthorizationServer,
            Ok(json_response(&example_metadata(ISSUER))),
        ),
    ]);
    let protocol = public_protocol(transport.clone());
    let result = protocol
        .discover_server(&Url::parse(PDS).unwrap())
        .await
        .unwrap();
    assert_eq!(result.issuer(), ISSUER);
    transport.assert_finished();
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn server_target_can_be_a_direct_issuer_without_valid_resource_metadata() {
    for resource_reply in [
        response(StatusCode::NOT_FOUND, None, Bytes::new()),
        json_response(&json!({"unexpected": true})),
    ] {
        let transport = fixture_transport([
            Exchange::new(PDS, ProtectedResource, Ok(resource_reply)),
            Exchange::new(
                PDS,
                AuthorizationServer,
                Ok(json_response(&example_metadata(PDS))),
            ),
        ]);
        let protocol = public_protocol(transport.clone());
        let result = protocol
            .discover_server(&Url::parse(PDS).unwrap())
            .await
            .unwrap();
        assert_eq!(result.issuer(), PDS);
        transport.assert_finished();
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn server_target_reports_the_direct_issuer_failure_only_after_prm_404() {
    for (resource_reply, expected) in [
        (
            response(StatusCode::NOT_FOUND, None, Bytes::new()),
            MetadataError::UnexpectedStatus {
                document: AuthorizationServer,
                status: 500,
            },
        ),
        (
            response(StatusCode::FORBIDDEN, None, Bytes::new()),
            MetadataError::UnexpectedStatus {
                document: ProtectedResource,
                status: 403,
            },
        ),
        (
            json_response(&json!({"unexpected": true})),
            MetadataError::MalformedDocument(ProtectedResource),
        ),
    ] {
        let transport = fixture_transport([
            Exchange::new(PDS, ProtectedResource, Ok(resource_reply)),
            Exchange::new(
                PDS,
                AuthorizationServer,
                Ok(response(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    None,
                    Bytes::new(),
                )),
            ),
        ]);
        let protocol = public_protocol(transport.clone());
        let error = protocol
            .discover_server(&Url::parse(PDS).unwrap())
            .await
            .unwrap_err();
        assert_eq!(error, expected);
        transport.assert_finished();
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn server_target_propagates_transport_failure_from_the_direct_issuer_fallback() {
    let calls = fixture_transport([
        Exchange::new(
            PDS,
            ProtectedResource,
            Ok(json_response(&json!({"unexpected": true}))),
        ),
        Exchange::new(
            PDS,
            AuthorizationServer,
            Err(TransportError::PolicyViolation("fixture refusal".into())),
        ),
    ]);
    let protocol = public_protocol(calls.clone());
    assert_eq!(
        protocol
            .discover_server(&Url::parse(PDS).unwrap())
            .await
            .unwrap_err(),
        MetadataError::Transport(AuthorizationServer)
    );
    calls.assert_finished();
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn retries_transient_metadata_transport_failures_until_the_third_attempt() {
    let transport = fixture_transport([
        Exchange::new(
            PDS,
            ProtectedResource,
            Err(TransportError::Connect("fixture".into())),
        ),
        Exchange::new(
            PDS,
            ProtectedResource,
            Err(TransportError::ConnectionLost("fixture".into())),
        ),
        Exchange::new(PDS, ProtectedResource, Ok(resource_document())),
        Exchange::new(
            ISSUER,
            AuthorizationServer,
            Ok(json_response(&example_metadata(ISSUER))),
        ),
    ]);
    let protocol = public_protocol(transport.clone());
    assert_eq!(
        protocol
            .discover_pds(&Url::parse(PDS).unwrap())
            .await
            .unwrap()
            .issuer(),
        ISSUER
    );
    transport.assert_finished();

    let calls = fixture_transport(
        (0..3).map(|_| Exchange::new(PDS, ProtectedResource, Err(TransportError::Timeout))),
    );
    let protocol = public_protocol(calls.clone());
    assert_eq!(
        protocol
            .discover_pds(&Url::parse(PDS).unwrap())
            .await
            .unwrap_err(),
        MetadataError::Transport(ProtectedResource)
    );
    calls.assert_finished();
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn server_target_does_not_retry_or_fall_back_after_non_transient_transport_failures() {
    for error in [
        TransportError::PolicyViolation("fixture refusal".into()),
        TransportError::InvalidRequest("fixture invalid request".into()),
        TransportError::ResponseTooLarge { limit: 32 },
    ] {
        let calls = fixture_transport([Exchange::new(PDS, ProtectedResource, Err(error))]);
        let protocol = public_protocol(calls.clone());
        assert_eq!(
            protocol
                .discover_server(&Url::parse(PDS).unwrap())
                .await
                .unwrap_err(),
            MetadataError::Transport(ProtectedResource)
        );
        calls.assert_finished();
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn validates_issuer_and_listed_protected_resources_before_using_metadata() {
    assert_pds_failure(
        AuthorizationServer,
        json_response(&example_metadata("https://other-issuer.example")),
        MetadataError::IssuerMismatch,
    )
    .await;

    let mut metadata = example_metadata(ISSUER);
    metadata.protected_resources = Some(vec!["https://other-pds.example".into()]);
    assert_pds_failure(
        AuthorizationServer,
        json_response(&metadata),
        MetadataError::ResourceNotProtected,
    )
    .await;
}

struct FixedPds;

impl OAuthIdentityResolver for FixedPds {
    fn resolve_identity<'a>(
        &'a self,
        identifier: &'a AtIdentifier,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>> {
        Box::pin(async move {
            let AtIdentifier::Did(did) = identifier else {
                panic!("expected the test DID");
            };
            Ok(OAuthIdentity {
                did: did.clone(),
                handle: None,
                pds: Url::parse(PDS).unwrap(),
            })
        })
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn discovery_checks_the_selected_client_authentication_before_any_par_or_cab_call() {
    let mut public_only = example_metadata(ISSUER);
    public_only.token_endpoint_auth_methods_supported = vec!["none".to_owned()];
    let calls = fixture_transport([
        Exchange::new(PDS, ProtectedResource, Ok(resource_document())),
        Exchange::new(ISSUER, AuthorizationServer, Ok(json_response(&public_only))),
    ]);
    let protocol = public_protocol(calls.clone());
    assert_eq!(
        protocol
            .discover_pds(&Url::parse(PDS).unwrap())
            .await
            .unwrap()
            .issuer(),
        ISSUER
    );
    calls.assert_finished();

    let mut no_es256 = example_metadata(ISSUER);
    no_es256.token_endpoint_auth_signing_alg_values_supported = vec!["RS256".to_owned()];
    for (metadata, field, value) in [
        (
            public_only,
            "token_endpoint_auth_methods_supported",
            "private_key_jwt",
        ),
        (
            no_es256,
            "token_endpoint_auth_signing_alg_values_supported",
            "ES256",
        ),
    ] {
        let calls = fixture_transport([
            Exchange::new(PDS, ProtectedResource, Ok(resource_document())),
            Exchange::new(ISSUER, AuthorizationServer, Ok(json_response(&metadata))),
        ]);
        let store =
            SessionStore::new(Arc::new(MemorySecretStore::new()), "metadata-tests").unwrap();
        let config = OAuthConfig::new(
            CLIENT,
            Url::parse("https://client.example/callback").unwrap(),
            "atproto",
            ClientAuth::Cab {
                backend_url: Url::parse(CAB).unwrap(),
                client_id: CLIENT.to_owned(),
            },
        )
        .unwrap();
        let client = OAuthClient::new(calls.clone(), Arc::new(FixedPds), store, config).unwrap();
        let did: Did = "did:plc:abcdefghijklmnopqrstuvwx".parse().unwrap();
        let error = client
            .start_authorization(OAuthTarget::Identifier(AtIdentifier::Did(did)))
            .await
            .unwrap_err();
        assert_eq!(
            error,
            OAuthError::Metadata(MetadataError::MissingValue { field, value })
        );
        calls.assert_finished();
    }
}
