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
