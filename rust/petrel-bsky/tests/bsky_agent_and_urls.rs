//! Ported BskyAppURL, LabelSet lifecycle, recorded AppView fixture, and BskyAgent tests.

use std::collections::BTreeSet;

use petrel_api::generated::app::bsky::actor::defs::ProfileViewDetailed;
use petrel_api::generated::app::bsky::labeler::get_services::{
    Output as GetServicesOutput, OutputViews,
};
use petrel_api::generated::com::atproto::label::defs::Label;
use petrel_bsky::{
    BSKY_LABELER_DID, BskyAppURL, LabelExt, LabelPreference, LabelSet, LabelStreamEvent,
    Moderation, ModerationContext, ModerationOptions, ModerationPrefs, ModerationPrefsLabeler,
    RichText, interpret_label_value_definitions, known_labels,
};
use petrel_core::{AtUri, Datetime, Uri};
use serde_json::json;
use url::Url;

const ALICE_DID: &str = "did:plc:z72i7hdynmk6r22z27h6tvur";
const FAKE_CID: &str = "bafyreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq";

// MARK: 1. BskyAppURLTests

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn bsky_app_url_round_trips_and_rejects_invalid() {
    let cases = [
        (
            format!("at://{ALICE_DID}"),
            format!("https://bsky.app/profile/{ALICE_DID}"),
        ),
        (
            format!("at://{ALICE_DID}/app.bsky.feed.post/3kabcdefghi2a"),
            format!("https://bsky.app/profile/{ALICE_DID}/post/3kabcdefghi2a"),
        ),
        (
            format!("at://{ALICE_DID}/app.bsky.feed.generator/whats-hot"),
            format!("https://bsky.app/profile/{ALICE_DID}/feed/whats-hot"),
        ),
        (
            format!("at://{ALICE_DID}/app.bsky.graph.list/3klist"),
            format!("https://bsky.app/profile/{ALICE_DID}/lists/3klist"),
        ),
        (
            format!("at://{ALICE_DID}/app.bsky.graph.starterpack/3kpack"),
            format!("https://bsky.app/starter-pack/{ALICE_DID}/3kpack"),
        ),
        (
            "at://bsky.app/app.bsky.feed.post/3kabc".to_owned(),
            "https://bsky.app/profile/bsky.app/post/3kabc".to_owned(),
        ),
    ];

    for (at_uri, web) in cases {
        let uri: AtUri = at_uri.parse().unwrap();
        let url = BskyAppURL::url_for(&uri, None, None).unwrap();
        assert_eq!(url.as_str(), web);
        assert_eq!(BskyAppURL::at_uri_from_url(&url, None), Some(uri));
    }

    let post_uri: AtUri = format!("at://{ALICE_DID}/app.bsky.feed.post/3kabc")
        .parse()
        .unwrap();
    assert_eq!(
        BskyAppURL::url_for(&post_uri, Some("alice.example"), None)
            .unwrap()
            .as_str(),
        "https://bsky.app/profile/alice.example/post/3kabc"
    );
    assert!(BskyAppURL::url_for(&post_uri, Some("not a handle"), None).is_none());
    assert_eq!(
        BskyAppURL::url_for(&post_uri, None, Some("staging.example"))
            .unwrap()
            .as_str(),
        format!("https://staging.example/profile/{ALICE_DID}/post/3kabc")
    );
    assert_eq!(
        BskyAppURL::profile_url("alice.example").unwrap().as_str(),
        "https://bsky.app/profile/alice.example"
    );
    assert!(BskyAppURL::profile_url("../etc").is_none());

    let profile_record: AtUri = format!("at://{ALICE_DID}/app.bsky.actor.profile/self")
        .parse()
        .unwrap();
    assert_eq!(
        BskyAppURL::url_for(&profile_record, None, None)
            .unwrap()
            .as_str(),
        format!("https://bsky.app/profile/{ALICE_DID}")
    );

    for unsupported in [
        format!("at://{ALICE_DID}/app.bsky.feed.like/3kabc"),
        format!("at://{ALICE_DID}/com.example.thing/3kabc"),
        format!("at://{ALICE_DID}/app.bsky.feed.post"),
    ] {
        let uri: AtUri = unsupported.parse().unwrap();
        assert!(BskyAppURL::url_for(&uri, None, None).is_none());
    }

    let short = Url::parse("https://bsky.app/start/alice.example/3kpack").unwrap();
    assert_eq!(
        BskyAppURL::at_uri_from_url(&short, None).unwrap().as_str(),
        "at://alice.example/app.bsky.graph.starterpack/3kpack"
    );

    for bad in [
        "https://example.com/profile/alice.example/post/3kabc",
        "https://bsky.app/",
        "https://bsky.app/settings",
        "https://bsky.app/profile/alice.example/unknown/3kabc",
        "https://bsky.app/profile/alice.example/post",
        "https://bsky.app/profile/not%20a%20handle/post/3kabc",
        "https://bsky.app/profile/alice.example/post/bad%20key",
        "ftp://bsky.app/profile/alice.example",
        "https://bsky.app.evil.example/profile/alice.example",
    ] {
        let url = Url::parse(bad).unwrap();
        assert!(BskyAppURL::at_uri_from_url(&url, None).is_none(), "{bad}");
    }

    let custom = Url::parse("https://staging.example/profile/alice.example").unwrap();
    assert!(BskyAppURL::at_uri_from_url(&custom, None).is_none());
    let hosts = BTreeSet::from(["staging.example".to_owned()]);
    assert_eq!(
        BskyAppURL::at_uri_from_url(&custom, Some(&hosts))
            .unwrap()
            .as_str(),
        "at://alice.example"
    );
}

// MARK: 2. BskyLabelSetTests

fn mk_label(
    val: &str,
    uri: &str,
    src: &str,
    secs: i64,
    neg: Option<bool>,
    exp: Option<i64>,
) -> Label {
    let mut l = Label::new(
        src.parse().unwrap(),
        uri.parse::<Uri>().unwrap(),
        val.to_owned(),
        Datetime::from_unix(secs, 0).unwrap(),
    );
    l.ver = Some(1);
    l.neg = neg;
    l.exp = exp.map(|e| Datetime::from_unix(e, 0).unwrap());
    l
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn label_set_lifecycle_negation_expiry_cursor_and_prune() {
    let labeler = "did:plc:labeler";
    let post = "at://did:plc:bob/app.bsky.feed.post/3kpost";
    let now = Datetime::from_unix(1000, 0).unwrap();

    assert!(mk_label("spam", post, labeler, 1, None, None).is_active(&now));
    assert!(!mk_label("spam", post, labeler, 1, Some(true), None).is_active(&now));
    assert!(mk_label("spam", post, labeler, 1, Some(false), None).is_active(&now));
    assert!(mk_label("spam", post, labeler, 1, None, Some(2000)).is_active(&now));
    assert!(!mk_label("spam", post, labeler, 1, None, Some(1000)).is_active(&now));
    assert!(mk_label("spam", post, labeler, 1, None, Some(500)).is_expired(&now));
    assert!(mk_label("spam", post, labeler, 1, Some(true), None).is_negation());

    let mut set = LabelSet::new();
    set.apply(mk_label("spam", post, labeler, 10, None, None));
    set.apply(mk_label("rude", post, labeler, 10, None, None));
    assert_eq!(
        set.active_labels(Some(post), &now)
            .iter()
            .map(|l| l.val.as_str())
            .collect::<Vec<_>>(),
        vec!["rude", "spam"]
    );

    set.apply(mk_label("spam", post, labeler, 20, Some(true), None));
    assert_eq!(
        set.active_labels(Some(post), &now)
            .iter()
            .map(|l| l.val.as_str())
            .collect::<Vec<_>>(),
        vec!["rude"]
    );

    // Older replay does not resurrect retracted label
    assert!(!set.apply(mk_label("spam", post, labeler, 10, None, None)));
    assert_eq!(set.active_labels(Some(post), &now).len(), 1);
    assert!(set.apply(mk_label("spam", post, labeler, 30, None, None)));
    assert_eq!(set.active_labels(Some(post), &now).len(), 2);

    // Stream cursor
    set.apply_event(LabelStreamEvent::Labels {
        seq: 41,
        labels: vec![mk_label("new", post, labeler, 40, None, None)],
    });
    set.apply_event(LabelStreamEvent::Info {
        name: "OutdatedCursor".to_owned(),
        message: None,
    });
    assert_eq!(set.cursor(), Some(41));

    // Prune old tombstones
    let mut prune_set = LabelSet::new();
    prune_set.apply(mk_label("old", post, labeler, 10, Some(true), None));
    prune_set.apply(mk_label("recent", post, labeler, 900, Some(true), None));
    prune_set.apply(mk_label("kept", post, labeler, 10, None, None));
    prune_set.prune(&now, &Datetime::from_unix(500, 0).unwrap());
    assert!(prune_set.apply(mk_label("old", post, labeler, 5, None, None)));
    assert!(!prune_set.apply(mk_label("recent", post, labeler, 800, None, None)));
    assert_eq!(
        prune_set
            .active_labels(None, &now)
            .iter()
            .map(|l| l.val.as_str())
            .collect::<Vec<_>>(),
        vec!["kept", "old"]
    );
}

// MARK: 3. BskyRecordedFixtureTests

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn bsky_recorded_fixtures_labeler_services_and_profile() {
    let services_raw =
        include_str!("../../../Tests/PetrelTests/Vectors/bsky-recorded/labeler-services.json");
    let output: GetServicesOutput = serde_json::from_str(services_raw).unwrap();
    let Some(OutputViews::LabelerViewDetailed(view)) = output.views.first() else {
        panic!("expected LabelerViewDetailed");
    };
    assert_eq!(view.creator.did.as_str(), BSKY_LABELER_DID);

    let definitions = interpret_label_value_definitions(view);
    assert!(definitions.len() >= 10);

    let custom_hide = definitions
        .iter()
        .find(|d| {
            d.blurs == "content"
                && d.default_setting == LabelPreference::Hide
                && !known_labels::default_settings().contains_key(&d.identifier)
        })
        .expect("custom hide definition");

    let labeler_did = view.creator.did.clone();
    let post: petrel_api::generated::app::bsky::feed::defs::PostView = serde_json::from_value(json!({
        "uri": "at://did:plc:bob/app.bsky.feed.post/3kpost",
        "cid": FAKE_CID,
        "author": {"did": "did:plc:bob", "handle": "bob.test"},
        "record": {"$type": "app.bsky.feed.post", "text": "hello", "createdAt": "2024-01-01T00:00:00.000Z"},
        "indexedAt": "2024-01-01T00:00:00.000Z",
        "labels": [{
            "src": labeler_did.as_str(),
            "uri": "at://did:plc:bob/app.bsky.feed.post/3kpost",
            "val": custom_hide.identifier,
            "cts": "2024-01-01T00:00:00.000Z"
        }]
    }))
    .unwrap();
    let prefs = ModerationPrefs {
        labelers: vec![ModerationPrefsLabeler::new(labeler_did.clone())],
        ..ModerationPrefs::default()
    };
    let mut informed_opts = ModerationOptions::new(None, prefs.clone());
    informed_opts.label_defs.insert(labeler_did, definitions);
    let now: Datetime = "2024-01-01T00:00:00.000Z".parse().unwrap();
    let ui_informed =
        Moderation::moderate_post(&post, &informed_opts, &now).ui(ModerationContext::ContentList);
    assert!(ui_informed.filter());
    assert!(ui_informed.blur());

    let ui_uninformed =
        Moderation::moderate_post(&post, &ModerationOptions::new(None, prefs), &now)
            .ui(ModerationContext::ContentList);
    assert!(!ui_uninformed.filter() && !ui_uninformed.blur());

    let profile: ProfileViewDetailed = serde_json::from_str(include_str!(
        "../../../Tests/PetrelTests/Vectors/bsky-recorded/profile.json"
    ))
    .unwrap();
    assert_eq!(profile.handle.as_str(), "bsky.app");
    assert_eq!(profile.did.as_str(), ALICE_DID);
    assert!(profile.followers_count.unwrap_or(0) > 1_000_000);

    let d_prof = Moderation::moderate_profile(&profile, &ModerationOptions::default());
    for ctx in ModerationContext::ALL {
        let ui = d_prof.ui(ctx);
        assert!(!ui.filter() && !ui.blur() && !ui.alert() && !ui.inform());
    }
    let at_uri: AtUri = format!("at://{}", profile.did.as_str()).parse().unwrap();
    assert_eq!(
        BskyAppURL::url_for(&at_uri, Some(profile.handle.as_str()), None)
            .unwrap()
            .as_str(),
        "https://bsky.app/profile/bsky.app"
    );
    if let Some(desc) = &profile.description {
        let rt = RichText::from_text(desc);
        for d in RichText::detect(&rt.text) {
            assert_ne!(
                rt.slice(
                    i64::try_from(d.byte_start).unwrap(),
                    i64::try_from(d.byte_end).unwrap()
                ),
                ""
            );
        }
    }
}

// MARK: 4. Mock Transport for BskyAgent record/service/video tests (Native)

#[cfg(not(target_arch = "wasm32"))]
mod agent_tests {
    use super::*;
    use std::sync::{Arc, Mutex};

    use bytes::Bytes;
    use http::{Request, Response, StatusCode};
    use petrel::auth::AuthMode;
    use petrel::client::AtProtoClient;
    use petrel::net::{DynHttpTransport, SendOptions, TransportError};
    use petrel::oauth::{OAuthIdentity, OAuthIdentityError, OAuthIdentityResolver};
    use petrel::rt::BoxFuture;
    use petrel::storage::{MemorySecretStore, SessionStore};
    use petrel::xrpc::XrpcClient;
    use petrel_bsky::{BskyAgent, BskyAgentError, BskyCallOptions, PostImage, ServiceProxy};
    use petrel_core::{AtIdentifier, Blob, Did};
    use serde_json::Value as JsonValue;

    const RAW_BLOB_CID: &str = "bafkreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq";

    #[derive(Clone)]
    struct RecordedReq {
        method: String,
        url: String,
        headers: Vec<(String, String)>,
        body: Bytes,
    }

    impl RecordedReq {
        fn header(&self, name: &str) -> Option<&str> {
            self.headers
                .iter()
                .find(|(k, _)| k.eq_ignore_ascii_case(name))
                .map(|(_, v)| v.as_str())
        }

        fn json(&self) -> Option<JsonValue> {
            serde_json::from_slice(&self.body).ok()
        }
    }

    type RequestHandler = Box<dyn Fn(&RecordedReq) -> (u16, JsonValue) + Send + Sync>;

    struct ScriptedTransport {
        requests: Mutex<Vec<RecordedReq>>,
        handler: RequestHandler,
    }

    impl ScriptedTransport {
        fn new<F>(handler: F) -> Arc<Self>
        where
            F: Fn(&RecordedReq) -> (u16, JsonValue) + Send + Sync + 'static,
        {
            Arc::new(Self {
                requests: Mutex::new(Vec::new()),
                handler: Box::new(handler),
            })
        }
    }

    impl DynHttpTransport for ScriptedTransport {
        fn send_dyn<'a>(
            &'a self,
            request: Request<Bytes>,
            _options: &'a SendOptions,
        ) -> BoxFuture<'a, Result<Response<Bytes>, TransportError>> {
            Box::pin(async move {
                let recorded = RecordedReq {
                    method: request.method().to_string(),
                    url: request.uri().to_string(),
                    headers: request
                        .headers()
                        .iter()
                        .filter_map(|(k, v)| {
                            v.to_str()
                                .ok()
                                .map(|val| (k.as_str().to_owned(), val.to_owned()))
                        })
                        .collect(),
                    body: request.into_body(),
                };
                let (status, json_body) = (self.handler)(&recorded);
                self.requests.lock().unwrap().push(recorded);
                let bytes = serde_json::to_vec(&json_body).unwrap();
                Ok(Response::builder()
                    .status(StatusCode::from_u16(status).unwrap())
                    .header("content-type", "application/json")
                    .body(Bytes::from(bytes))
                    .unwrap())
            })
        }
    }

    struct StubResolver;

    impl OAuthIdentityResolver for StubResolver {
        fn resolve_identity<'a>(
            &'a self,
            _identifier: &'a AtIdentifier,
            _force_refresh: bool,
        ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>> {
            Box::pin(async { Err(OAuthIdentityError) })
        }
    }

    #[tokio::test]
    async fn bsky_agent_service_headers_labelers_and_proxy() {
        let transport = ScriptedTransport::new(|_req| (200, json!({})));
        let dyn_t: Arc<dyn DynHttpTransport> = transport.clone();
        let base_url = Url::parse("https://pds.example.com").unwrap();
        let store = SessionStore::new(Arc::new(MemorySecretStore::new()), "test").unwrap();
        let resolver = Arc::new(StubResolver);
        let client = Arc::new(
            AtProtoClient::new(
                base_url,
                dyn_t,
                store,
                resolver,
                None,
                AuthMode::None,
                false,
            )
            .unwrap(),
        );
        let agent = BskyAgent::from_client(client.clone());

        // Initially omitted
        let _: JsonValue = agent
            .query("com.example.ping", &[], &BskyCallOptions::default())
            .await
            .unwrap();
        assert_eq!(
            transport.requests.lock().unwrap()[0].header("atproto-accept-labelers"),
            None
        );

        // Configure labelers sends header; empty slice sends ""
        agent
            .configure_labelers(&["did:plc:abc123".parse().unwrap()])
            .await
            .unwrap();
        let _: JsonValue = agent
            .query("com.example.ping", &[], &BskyCallOptions::default())
            .await
            .unwrap();
        let hdr = transport.requests.lock().unwrap()[1]
            .header("atproto-accept-labelers")
            .unwrap()
            .to_owned();
        assert_eq!(hdr, format!("{BSKY_LABELER_DID};redact, did:plc:abc123"));

        // Per-call proxy & empty labeler override
        let opts = BskyCallOptions {
            proxy: Some(ServiceProxy::bsky_chat()),
            accept_labelers: Some(Vec::new()),
            ..BskyCallOptions::default()
        };
        let _: JsonValue = agent
            .query("chat.bsky.convo.listConvos", &[], &opts)
            .await
            .unwrap();
        let req2 = transport.requests.lock().unwrap()[2].clone();
        assert_eq!(
            req2.header("atproto-proxy"),
            Some("did:web:api.bsky.chat#bsky_chat")
        );
        assert_eq!(req2.header("atproto-accept-labelers"), Some(""));

        client.clear_labelers().await.unwrap();
        let _: JsonValue = agent
            .query("com.example.ping", &[], &BskyCallOptions::default())
            .await
            .unwrap();
        let req3 = transport.requests.lock().unwrap()[3].clone();
        assert_eq!(req3.header("atproto-accept-labelers"), None);
    }

    #[tokio::test]
    #[allow(clippy::too_many_lines)]
    async fn bsky_agent_records_posts_images_and_video() {
        let _ = (ALICE_DID, FAKE_CID);
        let did: Did = "did:plc:alice".parse().unwrap();
        let poll_count = Arc::new(Mutex::new(0usize));
        let pc_clone = poll_count.clone();
        let transport = ScriptedTransport::new(move |req| {
            let _ = &req.method;
            if req.url.contains("/xrpc/com.atproto.identity.resolveHandle") {
                return (200, json!({ "did": "did:plc:bob" }));
            }
            if req.url.contains("/xrpc/com.atproto.repo.createRecord") {
                let body = req.json().unwrap();
                let col = body["collection"].as_str().unwrap();
                return (
                    200,
                    json!({
                        "uri": format!("at://did:plc:alice/{col}/3knew1"),
                        "cid": FAKE_CID,
                    }),
                );
            }
            if req.url.contains("/xrpc/com.atproto.repo.uploadBlob") {
                return (
                    200,
                    json!({
                        "blob": {
                            "$type": "blob",
                            "ref": { "$link": RAW_BLOB_CID },
                            "mimeType": "image/png",
                            "size": 67
                        }
                    }),
                );
            }
            if req.url.contains("/xrpc/com.atproto.server.getServiceAuth") {
                return (200, json!({ "token": "service-token" }));
            }
            if req.url.contains("/xrpc/app.bsky.video.uploadVideo") {
                return (
                    409,
                    json!({ "jobId": "job-409", "did": "did:plc:alice", "state": "JOB_STATE_ENCODING" }),
                );
            }
            if req.url.contains("/xrpc/app.bsky.video.getJobStatus") {
                let mut count = pc_clone.lock().unwrap();
                *count += 1;
                return (
                    200,
                    json!({
                        "jobStatus": {
                            "jobId": "job-409",
                            "did": "did:plc:alice",
                            "state": "JOB_STATE_COMPLETED",
                            "blob": {
                                "$type": "blob",
                                "ref": { "$link": RAW_BLOB_CID },
                                "mimeType": "video/mp4",
                                "size": 4
                            }
                        }
                    }),
                );
            }
            (200, json!({}))
        });

        let dyn_t: Arc<dyn DynHttpTransport> = transport.clone();
        let xrpc = XrpcClient::new(Url::parse("https://pds.example.com").unwrap(), dyn_t).unwrap();
        let agent = BskyAgent::from_xrpc(xrpc, Some(did.clone()));

        // Post with detected facet + handle resolution
        let post_ref = agent
            .post_text(
                "hi @bob.test https://bsky.app #atproto",
                None,
                None,
                None,
                None,
                None,
                None,
            )
            .await
            .unwrap();
        assert_eq!(
            post_ref.uri.as_str(),
            "at://did:plc:alice/app.bsky.feed.post/3knew1"
        );

        // Reject invalid image BEFORE uploading anything
        let err = agent
            .post_with_images(
                "bad",
                &[PostImage {
                    data: Bytes::from_static(b"not-a-png"),
                    mime_type: "image/png".to_owned(),
                    alt: "broken".to_owned(),
                    aspect_ratio: None,
                }],
                true,
                None,
                None,
                None,
                None,
                None,
                None,
            )
            .await
            .unwrap_err();
        assert!(matches!(err, BskyAgentError::Media(_)));
        assert!(
            !transport
                .requests
                .lock()
                .unwrap()
                .iter()
                .any(|r| r.url.contains("uploadBlob"))
        );

        // Video upload + 409 existing job + polling
        let mut states = Vec::new();
        let blob = agent
            .upload_video(
                Bytes::from_static(&[0, 0, 0, 24]),
                "video/mp4",
                "clip.mp4",
                Some(Url::parse("https://video.example.com").unwrap()),
                None,
                std::time::Duration::from_millis(1),
                std::time::Duration::from_secs(5),
                |status| states.push(status.state.clone()),
            )
            .await
            .unwrap();
        assert_eq!(states, vec!["JOB_STATE_ENCODING", "JOB_STATE_COMPLETED"]);
        let mime = match blob {
            Blob::Typed { mime_type, .. }
            | Blob::TypedWithCid { mime_type, .. }
            | Blob::Legacy { mime_type, .. } => mime_type,
        };
        assert_eq!(mime, "video/mp4");

        // Like & delete-like validation
        let like_ref = agent.like(post_ref.clone(), None).await.unwrap();
        assert!(
            agent.delete_like(&post_ref.uri).await.is_err(),
            "wrong collection rejected"
        );
        agent.delete_like(&like_ref.uri).await.unwrap();
    }

    #[tokio::test]
    #[allow(clippy::too_many_lines)]
    async fn bsky_agent_preferences_reject_write_and_labelers_across_account_switch() {
        use tokio::sync::Notify;

        struct SharedPdsIdentityResolver;
        impl OAuthIdentityResolver for SharedPdsIdentityResolver {
            fn resolve_identity<'a>(
                &'a self,
                identifier: &'a AtIdentifier,
                _force_refresh: bool,
            ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>> {
                let raw = identifier.as_str().to_owned();
                Box::pin(async move {
                    let (did, handle) = match raw.as_str() {
                        "alice.test" | "did:plc:alice" => ("did:plc:alice", "alice.test"),
                        "bob.test" | "did:plc:bob" => ("did:plc:bob", "bob.test"),
                        _ => return Err(OAuthIdentityError),
                    };
                    Ok(OAuthIdentity {
                        did: did.parse().unwrap(),
                        handle: Some(handle.parse().unwrap()),
                        pds: Url::parse("https://shared-pds.test").unwrap(),
                    })
                })
            }
        }

        struct GatedPrefsTransport {
            entered_get: Arc<Notify>,
            release_get: Arc<Notify>,
            entered_put: Arc<Notify>,
            release_put: Arc<Notify>,
            gate_get: std::sync::atomic::AtomicBool,
            gate_put: std::sync::atomic::AtomicBool,
            puts: Mutex<Vec<RecordedReq>>,
        }

        impl DynHttpTransport for GatedPrefsTransport {
            fn send_dyn<'a>(
                &'a self,
                request: Request<Bytes>,
                _options: &'a SendOptions,
            ) -> BoxFuture<'a, Result<Response<Bytes>, TransportError>> {
                Box::pin(async move {
                    let req = RecordedReq {
                        method: request.method().to_string(),
                        url: request.uri().to_string(),
                        headers: request
                            .headers()
                            .iter()
                            .filter_map(|(k, v)| {
                                v.to_str()
                                    .ok()
                                    .map(|val| (k.as_str().to_owned(), val.to_owned()))
                            })
                            .collect(),
                        body: request.into_body(),
                    };
                    if req.url.contains("/xrpc/com.atproto.server.createSession") {
                        let body = req.json().unwrap();
                        let id = body["identifier"].as_str().unwrap_or("");
                        let (did, handle, tok) = if id == "alice.test" {
                            ("did:plc:alice", "alice.test", "tok-alice")
                        } else {
                            ("did:plc:bob", "bob.test", "tok-bob")
                        };
                        let bytes = serde_json::to_vec(&json!({
                            "accessJwt": tok,
                            "refreshJwt": format!("refresh-{tok}"),
                            "handle": handle,
                            "did": did,
                            "active": true
                        }))
                        .unwrap();
                        return Ok(Response::builder()
                            .status(StatusCode::OK)
                            .header("content-type", "application/json")
                            .body(Bytes::from(bytes))
                            .unwrap());
                    }
                    if req.url.contains("/xrpc/app.bsky.actor.getPreferences") {
                        if self.gate_get.load(std::sync::atomic::Ordering::SeqCst) {
                            self.entered_get.notify_one();
                            self.release_get.notified().await;
                        }
                        let bytes = serde_json::to_vec(&json!({
                            "preferences": [
                                { "$type": "app.bsky.actor.defs#adultContentPref", "enabled": false }
                            ]
                        }))
                        .unwrap();
                        return Ok(Response::builder()
                            .status(StatusCode::OK)
                            .header("content-type", "application/json")
                            .body(Bytes::from(bytes))
                            .unwrap());
                    }
                    if req.url.contains("/xrpc/app.bsky.actor.putPreferences") {
                        if self.gate_put.load(std::sync::atomic::Ordering::SeqCst) {
                            self.entered_put.notify_one();
                            self.release_put.notified().await;
                        }
                        self.puts.lock().unwrap().push(req);
                        return Ok(Response::builder()
                            .status(StatusCode::OK)
                            .header("content-type", "application/json")
                            .body(Bytes::from_static(b"{}"))
                            .unwrap());
                    }
                    Ok(Response::builder()
                        .status(StatusCode::NOT_FOUND)
                        .body(Bytes::from_static(b"{}"))
                        .unwrap())
                })
            }
        }

        let transport = Arc::new(GatedPrefsTransport {
            entered_get: Arc::new(Notify::new()),
            release_get: Arc::new(Notify::new()),
            entered_put: Arc::new(Notify::new()),
            release_put: Arc::new(Notify::new()),
            gate_get: std::sync::atomic::AtomicBool::new(true),
            gate_put: std::sync::atomic::AtomicBool::new(false),
            puts: Mutex::new(Vec::new()),
        });
        let store =
            SessionStore::new(Arc::new(MemorySecretStore::new()), "prefs-switch-guard").unwrap();
        let client = Arc::new(
            AtProtoClient::new(
                Url::parse("https://shared-pds.test").unwrap(),
                transport.clone(),
                store,
                Arc::new(SharedPdsIdentityResolver),
                None,
                AuthMode::Legacy,
                false,
            )
            .unwrap(),
        );

        let alice_did: Did = "did:plc:alice".parse().unwrap();
        let bob_did: Did = "did:plc:bob".parse().unwrap();
        client
            .login_with_password("bob.test", "pw", None)
            .await
            .unwrap();
        client
            .login_with_password("alice.test", "pw", None)
            .await
            .unwrap();

        let agent = Arc::new(BskyAgent::from_client(Arc::clone(&client)));

        // 1. Account switch during getPreferences rejects putPreferences before write.
        let agent_a = Arc::clone(&agent);
        let task_a = tokio::spawn(async move { agent_a.set_adult_content_enabled(true).await });
        transport.entered_get.notified().await;
        client.switch_to_account(&bob_did).await.unwrap();
        transport.release_get.notify_one();
        let err_a = task_a.await.unwrap().unwrap_err();
        assert_eq!(err_a, BskyAgentError::AuthContinuityChanged);
        assert_eq!(transport.puts.lock().unwrap().len(), 0);

        // 2. Account switch during update_preferences_applying_labelers rejects configure_labelers.
        client.switch_to_account(&alice_did).await.unwrap();
        transport
            .gate_get
            .store(false, std::sync::atomic::Ordering::SeqCst);
        transport
            .gate_put
            .store(true, std::sync::atomic::Ordering::SeqCst);
        let labeler: Did = "did:plc:customlabeler".parse().unwrap();
        let agent_b = Arc::clone(&agent);
        let task_b = tokio::spawn(async move { agent_b.add_labeler(&labeler).await });
        transport.entered_put.notified().await;
        client.switch_to_account(&bob_did).await.unwrap();
        transport.release_put.notify_one();
        let err_b = task_b.await.unwrap().unwrap_err();
        assert_eq!(err_b, BskyAgentError::AuthContinuityChanged);
        assert!(client.configured_labelers().await.is_none());
    }

    struct GatedRecordTransport {
        entered: Arc<tokio::sync::Notify>,
        release: Arc<tokio::sync::Notify>,
        gate_get: std::sync::atomic::AtomicBool,
        gate_blob: std::sync::atomic::AtomicBool,
        gate_put_swap: std::sync::atomic::AtomicBool,
        fail_swap_once: std::sync::atomic::AtomicBool,
        writes: Mutex<Vec<RecordedReq>>,
    }

    #[allow(clippy::needless_pass_by_value)]
    fn json_resp(status: StatusCode, body: serde_json::Value) -> Response<Bytes> {
        let bytes = serde_json::to_vec(&body).unwrap();
        Response::builder()
            .status(status)
            .header("content-type", "application/json")
            .body(Bytes::from(bytes))
            .unwrap()
    }

    impl DynHttpTransport for GatedRecordTransport {
        fn send_dyn<'a>(
            &'a self,
            request: Request<Bytes>,
            _options: &'a SendOptions,
        ) -> BoxFuture<'a, Result<Response<Bytes>, TransportError>> {
            Box::pin(async move {
                let req = RecordedReq {
                    method: request.method().to_string(),
                    url: request.uri().to_string(),
                    headers: request
                        .headers()
                        .iter()
                        .filter_map(|(k, v)| {
                            v.to_str()
                                .ok()
                                .map(|val| (k.as_str().to_owned(), val.to_owned()))
                        })
                        .collect(),
                    body: request.into_body(),
                };
                if req.url.contains("/xrpc/com.atproto.server.createSession") {
                    let body = req.json().unwrap();
                    let (did, handle, tok) = if body["identifier"].as_str() == Some("alice.test") {
                        ("did:plc:alice", "alice.test", "tok-alice")
                    } else {
                        ("did:plc:bob", "bob.test", "tok-bob")
                    };
                    return Ok(json_resp(
                        StatusCode::OK,
                        json!({
                            "accessJwt": tok, "refreshJwt": format!("refresh-{tok}"),
                            "handle": handle, "did": did, "active": true
                        }),
                    ));
                }
                if req.url.contains("/xrpc/com.atproto.repo.getRecord") {
                    if self
                        .gate_get
                        .swap(false, std::sync::atomic::Ordering::SeqCst)
                    {
                        self.entered.notify_one();
                        self.release.notified().await;
                    }
                    return Ok(json_resp(
                        StatusCode::OK,
                        json!({
                            "uri": "at://did:plc:alice/app.bsky.actor.profile/self",
                            "cid": super::FAKE_CID,
                            "value": { "$type": "app.bsky.actor.profile", "displayName": "Existing" }
                        }),
                    ));
                }
                if req.url.contains("/xrpc/com.atproto.repo.uploadBlob") {
                    if self
                        .gate_blob
                        .swap(false, std::sync::atomic::Ordering::SeqCst)
                    {
                        self.entered.notify_one();
                        self.release.notified().await;
                    }
                    return Ok(json_resp(
                        StatusCode::OK,
                        json!({
                            "blob": {
                                "$type": "blob", "ref": { "$link": RAW_BLOB_CID },
                                "mimeType": "image/png", "size": 3
                            }
                        }),
                    ));
                }
                if req.url.contains("/xrpc/com.atproto.repo.putRecord")
                    || req.url.contains("/xrpc/com.atproto.repo.createRecord")
                {
                    if self
                        .fail_swap_once
                        .swap(false, std::sync::atomic::Ordering::SeqCst)
                    {
                        if self
                            .gate_put_swap
                            .swap(false, std::sync::atomic::Ordering::SeqCst)
                        {
                            self.entered.notify_one();
                            self.release.notified().await;
                        }
                        return Ok(json_resp(
                            StatusCode::BAD_REQUEST,
                            json!({ "error": "InvalidSwap", "message": "stale" }),
                        ));
                    }
                    self.writes.lock().unwrap().push(req);
                    return Ok(json_resp(
                        StatusCode::OK,
                        json!({
                            "uri": "at://did:plc:alice/app.bsky.actor.profile/self",
                            "cid": super::FAKE_CID
                        }),
                    ));
                }
                Ok(json_resp(StatusCode::NOT_FOUND, json!({})))
            })
        }
    }

    struct SharedPdsIdentityResolver;
    impl OAuthIdentityResolver for SharedPdsIdentityResolver {
        fn resolve_identity<'a>(
            &'a self,
            identifier: &'a AtIdentifier,
            _force_refresh: bool,
        ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>> {
            let raw = identifier.as_str().to_owned();
            Box::pin(async move {
                let (did, handle) = match raw.as_str() {
                    "alice.test" | "did:plc:alice" => ("did:plc:alice", "alice.test"),
                    "bob.test" | "did:plc:bob" => ("did:plc:bob", "bob.test"),
                    _ => return Err(OAuthIdentityError),
                };
                Ok(OAuthIdentity {
                    did: did.parse().unwrap(),
                    handle: Some(handle.parse().unwrap()),
                    pds: Url::parse("https://shared-pds.test").unwrap(),
                })
            })
        }
    }

    async fn setup_switch_client<T: DynHttpTransport + 'static>(
        transport: Arc<T>,
        ns: &str,
    ) -> (Arc<AtProtoClient>, Arc<BskyAgent>, Did, Did) {
        let store = SessionStore::new(Arc::new(MemorySecretStore::new()), ns).unwrap();
        let client = Arc::new(
            AtProtoClient::new(
                Url::parse("https://shared-pds.test").unwrap(),
                transport,
                store,
                Arc::new(SharedPdsIdentityResolver),
                None,
                AuthMode::Legacy,
                false,
            )
            .unwrap(),
        );
        let alice_did: Did = "did:plc:alice".parse().unwrap();
        let bob_did: Did = "did:plc:bob".parse().unwrap();
        client
            .login_with_password("bob.test", "pw", None)
            .await
            .unwrap();
        client
            .login_with_password("alice.test", "pw", None)
            .await
            .unwrap();
        let agent = Arc::new(BskyAgent::from_client(Arc::clone(&client)));
        (client, agent, alice_did, bob_did)
    }

    #[tokio::test]
    async fn bsky_agent_upsert_profile_and_siblings_reject_mid_operation_account_switch() {
        use petrel_bsky::ProfileUpdate;
        use tokio::sync::Notify;

        let transport = Arc::new(GatedRecordTransport {
            entered: Arc::new(Notify::new()),
            release: Arc::new(Notify::new()),
            gate_get: std::sync::atomic::AtomicBool::new(false),
            gate_blob: std::sync::atomic::AtomicBool::new(false),
            gate_put_swap: std::sync::atomic::AtomicBool::new(false),
            fail_swap_once: std::sync::atomic::AtomicBool::new(false),
            writes: Mutex::new(Vec::new()),
        });
        let (client, agent, alice_did, bob_did) =
            setup_switch_client(transport.clone(), "upsert-switch-guard").await;

        // 1. Account switch during getRecord rejects putRecord in upsert_profile.
        transport
            .gate_get
            .store(true, std::sync::atomic::Ordering::SeqCst);
        let a1 = Arc::clone(&agent);
        let t1 = tokio::spawn(async move {
            a1.upsert_profile(|_| Ok(ProfileUpdate::default().into_record()))
                .await
        });
        transport.entered.notified().await;
        client.switch_to_account(&bob_did).await.unwrap();
        transport.release.notify_one();
        assert_eq!(
            t1.await.unwrap().unwrap_err(),
            BskyAgentError::AuthContinuityChanged
        );

        // 2. Account switch during InvalidSwap retry rejects next getRecord/putRecord.
        client.switch_to_account(&alice_did).await.unwrap();
        transport
            .fail_swap_once
            .store(true, std::sync::atomic::Ordering::SeqCst);
        transport
            .gate_put_swap
            .store(true, std::sync::atomic::Ordering::SeqCst);
        let a2 = Arc::clone(&agent);
        let t2 = tokio::spawn(async move {
            a2.upsert_profile(|_| Ok(ProfileUpdate::default().into_record()))
                .await
        });
        transport.entered.notified().await;
        client.switch_to_account(&bob_did).await.unwrap();
        transport.release.notify_one();
        assert_eq!(
            t2.await.unwrap().unwrap_err(),
            BskyAgentError::AuthContinuityChanged
        );

        // 3. Account switch after uploadBlob in set_avatar fails closed before upsert_profile.
        client.switch_to_account(&alice_did).await.unwrap();
        transport
            .gate_blob
            .store(true, std::sync::atomic::Ordering::SeqCst);
        let a3 = Arc::clone(&agent);
        let t3 = tokio::spawn(async move {
            a3.set_avatar(Bytes::from_static(b"png"), "image/png", false)
                .await
        });
        transport.entered.notified().await;
        client.switch_to_account(&bob_did).await.unwrap();
        transport.release.notify_one();
        assert_eq!(
            t3.await.unwrap().unwrap_err(),
            BskyAgentError::AuthContinuityChanged
        );

        // 4. Account switch after uploadBlob in post_with_images fails closed before createRecord.
        client.switch_to_account(&alice_did).await.unwrap();
        transport
            .gate_blob
            .store(true, std::sync::atomic::Ordering::SeqCst);
        let a4 = Arc::clone(&agent);
        let t4 = tokio::spawn(async move {
            a4.post_with_images(
                "hi",
                &[PostImage {
                    data: Bytes::from_static(b"png"),
                    mime_type: "image/png".to_owned(),
                    alt: "alt".to_owned(),
                    aspect_ratio: None,
                }],
                false,
                None,
                None,
                None,
                None,
                None,
                None,
            )
            .await
        });
        transport.entered.notified().await;
        client.switch_to_account(&bob_did).await.unwrap();
        transport.release.notify_one();
        assert_eq!(
            t4.await.unwrap().unwrap_err(),
            BskyAgentError::AuthContinuityChanged
        );

        assert_eq!(transport.writes.lock().unwrap().len(), 0);
    }
}
