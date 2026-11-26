use std::{
    future::{Future, ready},
    net::IpAddr,
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
    time::Duration,
};

use bytes::Bytes;
use http::Request;
use petrel_core::{Did, Handle};
use web_time::UNIX_EPOCH;

use super::*;
use crate::net::{
    SendOptions, TransportError,
    test_support::{MockTransport, reply},
};

const DID: &str = "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa";
const HANDLE: &str = "alice.example.com";
const DOCUMENT: &[u8] = br#"{
    "id":"did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
    "alsoKnownAs":["at://alice.example.com"]
}"#;
const OTHER: &[u8] = b"did:plc:bbbbbbbbbbbbbbbbbbbbbbbb";

struct Dns {
    records: &'static [&'static str],
    calls: AtomicUsize,
}

impl Dns {
    fn new(records: &'static [&'static str]) -> Self {
        Self {
            records,
            calls: AtomicUsize::new(0),
        }
    }
}

impl DnsResolver for Arc<Dns> {
    fn txt(&self, name: &str) -> impl Future<Output = Result<Vec<String>, DnsError>> + Send {
        assert_eq!(name, "_atproto.alice.example.com");
        self.calls.fetch_add(1, Ordering::Relaxed);
        ready(Ok(self
            .records
            .iter()
            .map(|record| (*record).to_owned())
            .collect()))
    }

    fn lookup_ip(&self, _host: &str) -> impl Future<Output = Result<Vec<IpAddr>, DnsError>> + Send {
        ready(Err(DnsError::Lookup(
            "mock HTTP transport does not look up IP addresses".to_owned(),
        )))
    }
}

#[tokio::test]
async fn bidirectional_lookup_prefers_dns_or_reports_a_conflict() {
    let http = Arc::new(MockTransport::new(
        |request: &Request<Bytes>, options: &SendOptions, _| {
            assert!(options.anonymous);
            for name in [
                "authorization",
                "dpop",
                "atproto-proxy",
                "atproto-accept-labelers",
                "cookie",
            ] {
                assert!(!request.headers().contains_key(name));
            }
            Ok(if request.uri().host() == Some("plc.directory") {
                assert_eq!(request.uri().path(), format!("/{DID}"));
                reply(200, DOCUMENT)
            } else {
                assert_eq!(request.uri().path(), "/.well-known/atproto-did");
                reply(200, OTHER)
            })
        },
    ));
    let dns = Arc::new(Dns::new(&[
        "did=foo",
        "did=did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
    ]));
    let handle: Handle = "Alice.Example.Com".parse().unwrap();
    let did: Did = DID.parse().unwrap();
    let prefer = IdentityResolver::new(http.clone(), dns.clone(), IdentityOptions::default());
    assert_eq!(prefer.resolve_handle(&handle).await.unwrap(), did);
    let identity = prefer.resolve_identity(&did).await.unwrap();
    assert_eq!(identity.handle.normalized(), HANDLE);
    assert_eq!(identity.verification, HandleVerification::Verified);

    let reject = IdentityResolver::new(
        http,
        dns,
        IdentityOptions {
            handle_conflict: HandleConflictPolicy::Reject,
            ..IdentityOptions::default()
        },
    );
    assert!(matches!(
        reject.resolve_handle(&handle).await,
        Err(IdentityError::HandleAmbiguous { dids, .. }) if dids.len() == 2 && dids[0] == did
    ));
}

#[tokio::test]
async fn conflicting_dns_records_are_rejected_and_reserved_handles_are_never_queried() {
    let http = Arc::new(MockTransport::new(
        |_: &Request<Bytes>, _: &SendOptions, _| {
            panic!("immediate DNS ambiguity and reserved TLD both finish before HTTP")
        },
    ));
    let dns = Arc::new(Dns::new(&[
        "did=did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
        "did=did:plc:bbbbbbbbbbbbbbbbbbbbbbbb",
    ]));
    let resolver = IdentityResolver::new(http, dns.clone(), IdentityOptions::default());
    assert!(matches!(
        resolver
            .resolve_handle(&"alice.local".parse().unwrap())
            .await,
        Err(IdentityError::ReservedHandleTld(_))
    ));
    assert_eq!(dns.calls.load(Ordering::Relaxed), 0);
    assert!(matches!(
        resolver.resolve_handle(&HANDLE.parse().unwrap()).await,
        Err(IdentityError::HandleAmbiguous { .. })
    ));
    assert_eq!(dns.calls.load(Ordering::Relaxed), 1);
}

#[tokio::test]
async fn temporary_lookup_failure_and_unclaimed_handle_have_distinct_outcomes() {
    let http = Arc::new(MockTransport::new(
        |request: &Request<Bytes>, _: &SendOptions, ordinal| {
            if ordinal == 0 {
                return Ok(reply(503, b""));
            }
            assert_eq!(request.uri().host(), Some("plc.directory"));
            Ok(reply(200, br#"{"id":"did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"}"#))
        },
    ));
    let handle: Handle = HANDLE.parse().unwrap();
    let resolver = IdentityResolver::new(
        http.clone(),
        Arc::new(Dns::new(&[])),
        IdentityOptions::default(),
    );
    assert!(matches!(
        resolver.resolve_handle(&handle).await,
        Err(IdentityError::HandleLookupFailed { .. })
    ));

    let resolver = IdentityResolver::new(
        http,
        Arc::new(Dns::new(&["did=did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"])),
        IdentityOptions::default(),
    );
    assert!(matches!(
        resolver.resolve_handle(&handle).await,
        Err(IdentityError::HandleNotClaimedByDid { .. })
    ));
    let did = DID.parse().unwrap();
    let identity = resolver.resolve_identity(&did).await.unwrap();
    assert_eq!(identity.handle.normalized(), "handle.invalid");
    assert_eq!(identity.verification, HandleVerification::NoHandleClaimed);
}

#[tokio::test]
async fn stale_documents_are_only_used_for_transient_failures_on_forward_time() {
    let http = Arc::new(MockTransport::new(
        |_: &Request<Bytes>, _: &SendOptions, ordinal| match ordinal {
            0 => Ok(reply(200, DOCUMENT)),
            _ => Err(TransportError::Timeout),
        },
    ));
    let clock = Arc::new(AtomicUsize::new(100_000));
    let resolver = IdentityResolver::new(
        http.clone(),
        Arc::new(Dns::new(&[])),
        IdentityOptions::default(),
    )
    .with_clock({
        let clock = clock.clone();
        move || UNIX_EPOCH + Duration::from_secs(clock.load(Ordering::Relaxed) as u64)
    });
    let did: Did = DID.parse().unwrap();

    resolver.resolve_did_document(&did).await.unwrap();
    resolver.resolve_did_document(&did).await.unwrap();
    assert_eq!(http.seen().len(), 1);

    clock.store(104_000, Ordering::Relaxed);
    assert!(resolver.resolve_did_document(&did).await.is_ok());
    assert_eq!(http.seen().len(), 2);
    assert!(matches!(
        resolver.refresh_did_document(&did).await,
        Err(IdentityError::TimedOut)
    ));

    clock.store(99_000, Ordering::Relaxed);
    assert!(matches!(
        resolver.resolve_did_document(&did).await,
        Err(IdentityError::TimedOut)
    ));
    clock.store(186_400, Ordering::Relaxed);
    assert!(matches!(
        resolver.resolve_did_document(&did).await,
        Err(IdentityError::TimedOut)
    ));
    assert_eq!(http.seen().len(), 5);
}

#[tokio::test]
async fn a_plc_tombstone_drops_the_cached_document() {
    let http = Arc::new(MockTransport::new(
        |_: &Request<Bytes>, _: &SendOptions, ordinal| {
            Ok(match ordinal {
                0 => reply(200, DOCUMENT),
                1 => reply(410, b""),
                _ => reply(404, b""),
            })
        },
    ));
    let resolver = IdentityResolver::new(
        http.clone(),
        Arc::new(Dns::new(&[])),
        IdentityOptions::default(),
    );
    let did: Did = DID.parse().unwrap();
    resolver.resolve_did_document(&did).await.unwrap();
    assert_eq!(
        resolver.refresh_did_document(&did).await.unwrap_err(),
        IdentityError::DidTombstoned(did.clone())
    );
    assert_eq!(
        resolver.resolve_did_document(&did).await.unwrap_err(),
        IdentityError::DidNotFound(did)
    );
    assert_eq!(http.seen().len(), 3);
}

#[tokio::test]
#[ignore = "requires live public DNS and HTTPS"]
async fn live_atproto_handle_round_trips() {
    use crate::net::ReqwestTransport;

    let transport = Arc::new(ReqwestTransport::new().unwrap());
    let dns = HickoryResolver::system().unwrap();
    let resolver = IdentityResolver::new(transport, dns, IdentityOptions::default());
    let handle: Handle = "atproto.com".parse().unwrap();
    let did = resolver.resolve_handle(&handle).await.unwrap();
    let identity = resolver.resolve_identity(&did).await.unwrap();
    assert_eq!(identity.handle, handle);
    assert_eq!(identity.verification, HandleVerification::Verified);
}

#[tokio::test]
async fn claimed_handle_matches_swift_first_valid_at_entry_rule() {
    let document: DidDocument = serde_json::from_slice(
        br#"{
            "id": "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
            "alsoKnownAs": [
                "https://example.com",
                "example.com",
                "at://not a handle",
                "at://invalid..handle",
                "at://First.Example.com",
                "at://second.example.com"
            ]
        }"#,
    )
    .unwrap();
    assert_eq!(
        document.claimed_handle().unwrap().normalized(),
        "first.example.com"
    );
}

#[tokio::test]
async fn allow_development_identifiers_does_not_allow_loopback_endpoints_from_public_plc() {
    let localhost_doc = br##"{
        "id": "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
        "service": [{
            "id": "#atproto_pds",
            "type": "AtprotoPersonalDataServer",
            "serviceEndpoint": "http://localhost:2583"
        }]
    }"##;
    let http = Arc::new(MockTransport::new(
        move |_: &Request<Bytes>, options: &SendOptions, _| {
            assert!(!options.allow_loopback);
            Ok(reply(200, localhost_doc))
        },
    ));
    let resolver = IdentityResolver::new(
        http,
        Arc::new(Dns::new(&[])),
        IdentityOptions {
            allow_development_identifiers: true,
            ..IdentityOptions::default()
        },
    );
    let did: Did = DID.parse().unwrap();
    assert!(matches!(
        resolver
            .resolve_service_endpoint(&did, ServiceKind::Pds)
            .await,
        Err(IdentityError::InvalidServiceEndpoint { .. })
    ));
    assert!(matches!(
        resolver.resolve_did_to_pds_url(DID).await,
        Err(IdentityError::InvalidServiceEndpoint { .. })
    ));
    assert!(matches!(
        resolver.resolve_did_to_handle_and_pds_url(DID).await,
        Err(IdentityError::InvalidServiceEndpoint { .. })
    ));
}

#[test]
fn did_and_handle_syntax_vectors_match_petrel_core_and_resolver() {
    let valid_dids =
        include_str!("../../../../Tests/PetrelTests/Vectors/identity/did_syntax_valid.txt");
    let invalid_dids =
        include_str!("../../../../Tests/PetrelTests/Vectors/identity/did_syntax_invalid.txt");
    let valid_handles =
        include_str!("../../../../Tests/PetrelTests/Vectors/identity/handle_syntax_valid.txt");
    let invalid_handles =
        include_str!("../../../../Tests/PetrelTests/Vectors/identity/handle_syntax_invalid.txt");

    let parse_lines = |raw: &'static str| -> Vec<&'static str> {
        raw.lines()
            .filter(|line| !line.is_empty() && !line.starts_with('#'))
            .collect()
    };

    for did in parse_lines(valid_dids) {
        assert!(is_strictly_valid_did(did), "expected valid DID: {did}");
    }
    for did in parse_lines(invalid_dids) {
        assert!(!is_strictly_valid_did(did), "expected invalid DID: {did}");
    }
    for handle in parse_lines(valid_handles) {
        assert!(
            handle.parse::<Handle>().is_ok(),
            "expected valid Handle: {handle}"
        );
    }
    for handle in parse_lines(invalid_handles) {
        assert!(
            handle.parse::<Handle>().is_err(),
            "expected invalid Handle: {handle}"
        );
    }
}

#[test]
fn did_document_keys_and_tolerant_decoding() {
    use p256::elliptic_curve::sec1::ToEncodedPoint as _;
    use petrel_crypto::{ATProtoKeypair, K256Keypair, P256Keypair};

    let p256 = P256Keypair::generate().unwrap();
    let k256 = K256Keypair::generate().unwrap();

    // Multikey + Legacy 2019 keys + null publicKeyMultibase
    let doc_json = serde_json::json!({
        "id": DID,
        "verificationMethod": [
            {"id": format!("{DID}#atproto"), "type": "Multikey", "controller": DID, "publicKeyMultibase": p256.multikey()},
            {"id": "#k256_legacy", "type": "EcdsaSecp256k1VerificationKey2019", "controller": DID, "publicKeyMultibase": k256.public_key().legacy_multibase()},
            {"id": "#null_key", "type": "JsonWebKey2020", "controller": DID, "publicKeyMultibase": null}
        ]
    });
    let doc: DidDocument = serde_json::from_value(doc_json).unwrap();
    assert_eq!(doc.atproto_signing_did_key().unwrap(), p256.did_key());
    assert_eq!(&doc.atproto_signing_key().unwrap(), p256.public_key());
    assert!(matches!(
        doc.plc_verification_key("k256_legacy").unwrap(),
        petrel_crypto::PLCDIDVerificationKey::Secp256k1(_)
    ));
    assert_eq!(
        doc.verification_method("#null_key")
            .unwrap()
            .public_key_multibase,
        ""
    );

    // Uncompressed R1 legacy multibase yields the same compressed key
    let secret = p256::SecretKey::from_slice(&[7; 32]).unwrap();
    let uncompressed = secret.public_key().to_encoded_point(false);
    let legacy_uncompressed = format!("z{}", bs58::encode(uncompressed.as_bytes()).into_string());
    let compressed = secret.public_key().to_encoded_point(true);
    let mut multikey_bytes = vec![0x80, 0x24];
    multikey_bytes.extend_from_slice(compressed.as_bytes());
    let multikey = format!("z{}", bs58::encode(multikey_bytes).into_string());

    let legacy_doc: DidDocument = serde_json::from_value(serde_json::json!({
        "id": DID,
        "verificationMethod": [
            {"id": "#atproto", "type": "EcdsaSecp256r1VerificationKey2019", "controller": DID, "publicKeyMultibase": legacy_uncompressed}
        ]
    }))
    .unwrap();
    assert_eq!(
        legacy_doc.atproto_signing_did_key().unwrap(),
        format!("did:key:{multikey}")
    );
}

#[test]
fn did_document_services_handles_and_unreadable_entries() {
    let services_doc: DidDocument = serde_json::from_value(serde_json::json!({
        "id": DID,
        "alsoKnownAs": ["https://example.com", "at://not a handle", "at://First.Example.Com", "at://second.example.com"],
        "service": [
            {"id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "HTTPS://pds.example.com"},
            {"id": "#atproto_labeler", "type": "AtprotoLabeler", "serviceEndpoint": "https://labeler.example.com"},
            {"id": "#bsky_fg", "type": "BskyFeedGenerator", "serviceEndpoint": "https://fg.example.com"},
            {"id": "#bsky_notif", "type": "BskyNotificationService", "serviceEndpoint": "https://notif.example.com"},
            {"id": "#bsky_chat", "type": "BskyChatService", "serviceEndpoint": "https://chat.example.com"},
            {"id": "#bsky_appview", "type": "BskyAppView", "serviceEndpoint": "https://appview.example.com"},
            {"id": "#custom", "type": "CustomType", "serviceEndpoint": "https://custom.example.com"}
        ]
    }))
    .unwrap();
    assert_eq!(
        services_doc.claimed_handle().unwrap().normalized(),
        "first.example.com"
    );
    assert_eq!(
        services_doc.pds_endpoint().unwrap().as_str(),
        "https://pds.example.com/"
    );
    assert_eq!(
        services_doc.labeler_endpoint().unwrap().as_str(),
        "https://labeler.example.com/"
    );
    assert_eq!(
        services_doc.feed_generator_endpoint().unwrap().as_str(),
        "https://fg.example.com/"
    );
    assert_eq!(
        services_doc
            .notification_service_endpoint()
            .unwrap()
            .as_str(),
        "https://notif.example.com/"
    );
    assert_eq!(
        services_doc.chat_endpoint().unwrap().as_str(),
        "https://chat.example.com/"
    );
    assert_eq!(
        services_doc.app_view_endpoint().unwrap().as_str(),
        "https://appview.example.com/"
    );
    assert_eq!(
        services_doc
            .service_endpoint(&DidServiceIdentifier::new("custom", Some("CustomType")))
            .unwrap()
            .as_str(),
        "https://custom.example.com/"
    );
    assert!(matches!(
        services_doc.service_endpoint(&DidServiceIdentifier::new("absent", None)),
        Err(IdentityError::MissingService { .. })
    ));

    // Unreadable first matching service wins and is omitted from services Vec,
    // while unreadable entry lacking required type does not shadow later typed entry
    let unreadable: DidDocument = serde_json::from_str(
        r##"{
            "id": "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
            "service": [
                {"id": "#other", "type": "LinkedDomains", "serviceEndpoint": {"origins": ["https://x.example.com"]}},
                {"id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": {"uri": "https://first.example.com"}},
                {"id": "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://later.example.com"},
                {"id": "#atproto_labeler", "type": "AtprotoLabeler", "serviceEndpoint": "https://labeler.example.com"}
            ]
        }"##,
    )
    .unwrap();
    assert_eq!(unreadable.services.len(), 2);
    assert!(unreadable.service(ServiceKind::Pds).is_none());
    assert!(unreadable.pds_endpoint().is_none());
    assert!(matches!(
        unreadable.service_endpoint(&DidServiceIdentifier::pds()),
        Err(IdentityError::InvalidServiceEndpoint { .. })
    ));
    assert_eq!(
        unreadable.labeler_endpoint().unwrap().as_str(),
        "https://labeler.example.com/"
    );

    let mistyped_unreadable: DidDocument = serde_json::from_str(
        r##"{
            "id": "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
            "service": [
                {"id": "#atproto_pds", "serviceEndpoint": {"uri": "https://first.example.com"}},
                {"id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://pds.example.com"}
            ]
        }"##,
    )
    .unwrap();
    assert_eq!(
        mistyped_unreadable.pds_endpoint().unwrap().as_str(),
        "https://pds.example.com/"
    );

    let encoded = serde_json::to_vec(&services_doc).unwrap();
    let decoded: DidDocument = serde_json::from_slice(&encoded).unwrap();
    assert_eq!(decoded, services_doc);
}

#[test]
fn did_web_identifier_comprehensive_validation() {
    for valid in [
        "did:web:example.com",
        "did:web:a.co",
        "did:web:xn--ls8h.example.com",
        "did:web:8.cn",
        "did:web:sub.sub.example.org",
    ] {
        assert!(DidWebIdentifier::is_valid(valid, false), "{valid}");
    }

    for (did, expected) in [
        (
            "did:web:example.com:users:alice",
            DidWebError::UnsupportedPath,
        ),
        ("did:web:example.com:", DidWebError::InvalidDid),
        ("did:web:example.com::", DidWebError::InvalidDid),
        ("did:web:localhost:path", DidWebError::UnsupportedPath),
        ("did:web:example.com%3A8443", DidWebError::InvalidPort),
        (
            "did:web:example.com%3A8443:users:bob",
            DidWebError::UnsupportedPath,
        ),
        ("did:web:localhost%3A0", DidWebError::InvalidPort),
        ("did:web:localhost%3A65536", DidWebError::InvalidPort),
        ("did:web:localhost%3A80%3A81", DidWebError::InvalidPort),
        ("did:web:localhost%3A", DidWebError::InvalidPort),
        ("did:web:localhost%3Aabc", DidWebError::InvalidPort),
        ("did:web:blah.arpa", DidWebError::ReservedTld),
        ("did:web:user.example", DidWebError::ReservedTld),
        ("did:web:service.internal", DidWebError::ReservedTld),
        ("did:web:handle.invalid", DidWebError::ReservedTld),
        ("did:web:laptop.local", DidWebError::ReservedTld),
        ("did:web:dev.localhost", DidWebError::ReservedTld),
        ("did:web:expyuzz4wqqyqhjn.onion", DidWebError::ReservedTld),
        ("did:web:name.alt", DidWebError::ReservedTld),
        ("did:web:com", DidWebError::InvalidHost),
        ("did:web:127.0.0.1", DidWebError::InvalidHost),
        ("did:web:Example.com", DidWebError::InvalidHost),
        ("did:web:-bad.example.com", DidWebError::InvalidHost),
        ("did:web:bad-.example.com", DidWebError::InvalidHost),
        ("did:web:exa_mple.com", DidWebError::InvalidHost),
        ("did:web:example.com%2F..%2Fx", DidWebError::InvalidHost),
        ("did:web:example..com", DidWebError::InvalidHost),
        ("did:web:.example.com", DidWebError::InvalidHost),
        ("did:web:", DidWebError::InvalidDid),
        ("did:web:example.com/path", DidWebError::InvalidDid),
        ("did:web:example.com?x", DidWebError::InvalidDid),
        ("did:web:example.com#frag", DidWebError::InvalidDid),
        ("did:plc:ewvi7nxzyoun6zhxrhs64oiz", DidWebError::InvalidDid),
    ] {
        assert_eq!(DidWebIdentifier::parse(did, true), Err(expected), "{did}");
    }
}

#[tokio::test]
async fn direct_lookup_ordering_dns_first_and_http_first() {
    struct PanicDns;
    impl DnsResolver for PanicDns {
        fn txt(&self, _name: &str) -> impl Future<Output = Result<Vec<String>, DnsError>> + Send {
            ready(Err(DnsError::Lookup(
                "DNS should not be queried in HttpFirst when HTTP wins".into(),
            )))
        }
        fn lookup_ip(
            &self,
            _host: &str,
        ) -> impl Future<Output = Result<Vec<IpAddr>, DnsError>> + Send {
            ready(Err(DnsError::Lookup("unused".into())))
        }
    }

    let handle: Handle = HANDLE.parse().unwrap();
    let did: Did = DID.parse().unwrap();

    // DnsFirst avoids touching HTTP when DNS succeeds under PreferDns
    let http_fail = Arc::new(MockTransport::new(
        |request: &Request<Bytes>, _: &SendOptions, _| {
            if request.uri().host() == Some("plc.directory") {
                return Ok(reply(200, DOCUMENT));
            }
            panic!(
                "HTTP well-known lookup should not run when DnsFirst succeeds: {}",
                request.uri()
            );
        },
    ));
    let dns_ok = Arc::new(Dns::new(&["did=did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"]));
    let resolver_dns_first = IdentityResolver::new(
        http_fail,
        dns_ok.clone(),
        IdentityOptions {
            direct_order: DirectLookupOrder::DnsFirst,
            ..IdentityOptions::default()
        },
    );
    assert_eq!(
        resolver_dns_first.resolve_handle(&handle).await.unwrap(),
        did
    );
    assert_eq!(dns_ok.calls.load(Ordering::Relaxed), 1);

    // HttpFirst avoids touching DNS when HTTPS well-known succeeds under PreferDns
    let http_ok = Arc::new(MockTransport::new(
        |request: &Request<Bytes>, _: &SendOptions, _| {
            if request.uri().host() == Some("plc.directory") {
                Ok(reply(200, DOCUMENT))
            } else {
                Ok(reply(200, DID.as_bytes()))
            }
        },
    ));
    let resolver_http_first = IdentityResolver::new(
        http_ok.clone(),
        PanicDns,
        IdentityOptions {
            direct_order: DirectLookupOrder::HttpFirst,
            ..IdentityOptions::default()
        },
    );
    assert_eq!(
        resolver_http_first.resolve_handle(&handle).await.unwrap(),
        did
    );

    // HttpFirst falls back to DNS when HTTPS returns 404
    let http_404 = Arc::new(MockTransport::new(
        |request: &Request<Bytes>, _: &SendOptions, _| {
            if request.uri().host() == Some("plc.directory") {
                Ok(reply(200, DOCUMENT))
            } else {
                Ok(reply(404, b""))
            }
        },
    ));
    let dns_fallback = Arc::new(Dns::new(&["did=did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"]));
    let resolver_fallback = IdentityResolver::new(
        http_404,
        dns_fallback.clone(),
        IdentityOptions {
            direct_order: DirectLookupOrder::HttpFirst,
            ..IdentityOptions::default()
        },
    );
    assert_eq!(
        resolver_fallback.resolve_handle(&handle).await.unwrap(),
        did
    );
    assert_eq!(dns_fallback.calls.load(Ordering::Relaxed), 1);
}

#[tokio::test]
async fn cache_policy_disabled_capacity_eviction_invalidation_and_negative_ttl() {
    let clock = Arc::new(AtomicUsize::new(10_000));
    let http = Arc::new(MockTransport::new(
        |request: &Request<Bytes>, _: &SendOptions, ordinal| {
            let path = request.uri().path();
            if path == "/did:plc:missing000000000000000000" {
                return Ok(reply(404, b""));
            }
            if path == "/did:plc:transient0000000000000000" {
                return Ok(if ordinal == 1 {
                    reply(503, b"")
                } else {
                    reply(200, br#"{"id":"did:plc:transient0000000000000000"}"#)
                });
            }
            let did = path.trim_start_matches('/');
            let body = format!(r#"{{"id":"{did}"}}"#);
            Ok(http::Response::builder()
                .status(200)
                .body(Bytes::from(body))
                .unwrap())
        },
    ));

    // Negative TTL caches 404, expires after negative_ttl, does NOT cache 503, clears on invalidate
    let resolver = IdentityResolver::with_cache_capacity(
        http.clone(),
        Arc::new(Dns::new(&[])),
        IdentityOptions {
            cache_policy: CachePolicy::default().with_negative_ttl(Duration::from_secs(30)),
            ..IdentityOptions::default()
        },
        2,
    )
    .with_clock({
        let clock = clock.clone();
        move || UNIX_EPOCH + Duration::from_secs(clock.load(Ordering::Relaxed) as u64)
    });

    let missing: Did = "did:plc:missing000000000000000000".parse().unwrap();
    assert_eq!(
        resolver.resolve_did_document(&missing).await.unwrap_err(),
        IdentityError::DidNotFound(missing.clone())
    );
    assert_eq!(
        resolver.resolve_did_document(&missing).await.unwrap_err(),
        IdentityError::DidNotFound(missing.clone())
    );
    assert_eq!(http.seen().len(), 1);

    // Transient 503 is never negatively cached
    let transient: Did = "did:plc:transient0000000000000000".parse().unwrap();
    assert!(matches!(
        resolver.resolve_did_document(&transient).await,
        Err(IdentityError::UnexpectedStatus { .. })
    ));
    assert!(resolver.resolve_did_document(&transient).await.is_ok());

    // Negative entry expires after negative_ttl
    clock.store(10_040, Ordering::Relaxed);
    assert_eq!(
        resolver.resolve_did_document(&missing).await.unwrap_err(),
        IdentityError::DidNotFound(missing.clone())
    );
    let hits_before_invalidate = http.seen().len();
    resolver.invalidate_did(&missing).await;
    assert_eq!(
        resolver.resolve_did_document(&missing).await.unwrap_err(),
        IdentityError::DidNotFound(missing.clone())
    );
    assert_eq!(http.seen().len(), hits_before_invalidate + 1);

    // Disabled policy serves nothing from cache
    let disabled = IdentityResolver::new(
        http.clone(),
        Arc::new(Dns::new(&[])),
        IdentityOptions {
            cache_policy: CachePolicy::disabled(),
            ..IdentityOptions::default()
        },
    );
    let hits = http.seen().len();
    disabled.resolve_did_document(&transient).await.unwrap();
    disabled.resolve_did_document(&transient).await.unwrap();
    assert_eq!(http.seen().len(), hits + 2);
}

#[tokio::test]
async fn did_document_service_auth_key_resolver_works() {
    use petrel_crypto::{
        ATProtoKeypair, K256Keypair, P256Keypair, ServiceAuthError, ServiceAuthKeyResolver,
    };

    let first = P256Keypair::generate().unwrap();
    let label_key = K256Keypair::generate().unwrap();
    let doc: DidDocument = serde_json::from_value(serde_json::json!({
        "id": DID,
        "verificationMethod": [
            {"id": format!("{DID}#atproto"), "type": "Multikey", "controller": DID, "publicKeyMultibase": first.multikey()},
            {"id": format!("{DID}#atproto_label"), "type": "Multikey", "controller": DID, "publicKeyMultibase": label_key.multikey()}
        ]
    }))
    .unwrap();
    let doc_clone = doc.clone();
    let resolver = DidDocumentServiceAuthKeyResolver::new(move |req_did, _| {
        let doc = doc_clone.clone();
        Box::pin(async move {
            if req_did == doc.id.as_str() {
                Ok(doc)
            } else {
                Err(ServiceAuthError::KeyResolutionFailed {
                    did: req_did.to_owned(),
                    key_id: "#atproto".to_owned(),
                    reason: "not found".to_owned(),
                })
            }
        })
    });
    assert_eq!(
        &resolver.signing_key(DID, false).await.unwrap(),
        first.public_key()
    );
    assert_eq!(
        &resolver
            .signing_key_for_id(DID, "#atproto_label", false)
            .await
            .unwrap(),
        label_key.public_key()
    );
    assert!(matches!(
        DidDocumentServiceAuthKeyResolver::signing_key_in_document(
            &doc,
            "did:plc:zzzzzzzzzzzzzzzzzzzzzzzz",
            "#atproto"
        ),
        Err(ServiceAuthError::KeyResolutionFailed { .. })
    ));
}

#[tokio::test]
async fn identity_resolver_picks_up_rotated_service_auth_key() {
    use petrel_crypto::{
        ATProtoKeypair, CachingServiceAuthKeyResolver, P256Keypair, ServiceAuthAudience,
        ServiceAuthMethodPolicy, ServiceAuthVerifier, ServiceJWT, ServiceJWTMintOptions,
    };

    let first = P256Keypair::generate().unwrap();
    let rotated = P256Keypair::generate().unwrap();
    let make_doc = |key: &P256Keypair| {
        serde_json::to_vec(&serde_json::json!({
            "id": DID,
            "verificationMethod": [
                {"id": format!("{DID}#atproto"), "type": "Multikey", "controller": DID, "publicKeyMultibase": key.multikey()}
            ]
        }))
        .unwrap()
    };
    let first_bytes = make_doc(&first);
    let rotated_bytes = make_doc(&rotated);

    let http = Arc::new(MockTransport::new(
        move |_: &Request<Bytes>, _: &SendOptions, ordinal| {
            let body = if ordinal == 0 {
                first_bytes.clone()
            } else {
                rotated_bytes.clone()
            };
            Ok(http::Response::builder()
                .status(200)
                .body(Bytes::from(body))
                .unwrap())
        },
    ));
    let resolver = IdentityResolver::new(
        http.clone(),
        Arc::new(Dns::new(&[])),
        IdentityOptions::default(),
    );
    let cached = Arc::new(CachingServiceAuthKeyResolver::new(resolver));
    let verifier = ServiceAuthVerifier::new(
        ServiceAuthAudience::service("did:web:feed.example.com", "bsky_fg", true),
        cached,
    );

    let mut opts = ServiceJWTMintOptions::new(
        DID,
        "did:web:feed.example.com#bsky_fg",
        Some("app.bsky.feed.getFeedSkeleton"),
    );
    opts.now = UNIX_EPOCH + Duration::from_secs(1_700_000_000);
    let token_first = ServiceJWT::mint(&opts, &first).await.unwrap();
    let token_rotated = ServiceJWT::mint(&opts, &rotated).await.unwrap();
    let method = ServiceAuthMethodPolicy::Exactly("app.bsky.feed.getFeedSkeleton".into());

    verifier
        .verify_authorization_header_at(Some(&format!("Bearer {token_first}")), &method, opts.now)
        .await
        .unwrap();
    verifier
        .verify_authorization_header_at(Some(&format!("Bearer {token_rotated}")), &method, opts.now)
        .await
        .unwrap();
    assert_eq!(http.seen().len(), 2);
}

#[tokio::test]
async fn did_resolving_and_did_resolution_service() {
    let http = Arc::new(MockTransport::new(
        |request: &Request<Bytes>, _: &SendOptions, _| {
            if request.uri().host() == Some("plc.directory") {
                return Ok(reply(
                    200,
                    br##"{
                        "id":"did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
                        "alsoKnownAs":["at://alice.example.com"],
                        "service":[{"id":"#atproto_pds","type":"AtprotoPersonalDataServer","serviceEndpoint":"https://pds.example.com"}]
                    }"##,
                ));
            }
            if request.uri().path() == "/xrpc/com.atproto.identity.resolveHandle" {
                return Ok(reply(200, br#"{"did":"did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"}"#));
            }
            Ok(reply(404, b""))
        },
    ));
    let service = DidResolutionService::with_service_url(
        http,
        Arc::new(Dns::new(&[])),
        url::Url::parse("https://pds.example.com").unwrap(),
        false,
    );
    let did = service
        .resolve_handle_to_did("alice.example.com")
        .await
        .unwrap();
    assert_eq!(did.as_str(), DID);
    let (handle, pds) = service
        .resolve_did_to_handle_and_pds_url(DID)
        .await
        .unwrap();
    assert_eq!(handle.normalized(), HANDLE);
    assert_eq!(pds.as_str(), "https://pds.example.com/");
}

#[test]
fn large_malformed_services_endpoint_lookup_is_linear_time() {
    let mut entries: Vec<serde_json::Value> = vec![serde_json::json!({"id": "x"}); 20_000];
    entries.push(serde_json::json!({
        "id": "#atproto_pds",
        "type": "AtprotoPersonalDataServer",
        "serviceEndpoint": "https://pds.example.com"
    }));
    let payload = serde_json::to_vec(&serde_json::json!({
        "id": DID,
        "service": entries
    }))
    .unwrap();
    let doc: DidDocument = serde_json::from_slice(&payload).unwrap();
    assert_eq!(
        doc.pds_endpoint().unwrap().as_str(),
        "https://pds.example.com/"
    );

    // An unreadable first-matching entry at the tail after 20k malformed entries still blocks fallback.
    let mut blocked_entries: Vec<serde_json::Value> = vec![serde_json::json!({"id": "x"}); 20_000];
    blocked_entries.push(serde_json::json!({
        "id": "#atproto_pds",
        "type": "AtprotoPersonalDataServer",
        "serviceEndpoint": 42
    }));
    blocked_entries.push(serde_json::json!({
        "id": "#atproto_pds",
        "type": "AtprotoPersonalDataServer",
        "serviceEndpoint": "https://fallback.example.com"
    }));
    let blocked_payload = serde_json::to_vec(&serde_json::json!({
        "id": DID,
        "service": blocked_entries
    }))
    .unwrap();
    let blocked_doc: DidDocument = serde_json::from_slice(&blocked_payload).unwrap();
    assert_eq!(blocked_doc.pds_endpoint(), None);
}
