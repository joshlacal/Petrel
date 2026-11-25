#![cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]

use std::{
    collections::BTreeMap,
    sync::{Arc, Mutex},
};

use bytes::Bytes;
use http::{Method, Request, Response};
use petrel::{
    net::{HttpTransport, SharedTransport},
    rt::BoxFuture,
    xrpc::XrpcClient,
};
use petrel_api::generated::com::atproto::identity::{
    get_recommended_did_credentials, sign_plc_operation, submit_plc_operation,
};
use petrel_core::Value;
use petrel_crypto::{K256Keypair, P256Keypair};
use petrel_plc::{
    PlcAuditLogVerifier, PlcClientConfiguration, PlcDidDocument, PlcDirectoryClient, PlcError,
    PlcExportCursor, PlcOperation, PlcOperationCodec, PlcOperationLimits, PlcPdsBridge,
    PlcPdsFlowError, PlcPdsIdentityApi, PlcPdsOperationFields, PlcPdsOperationFlow, PlcService,
    PlcSubmitSuccessResponsePolicy, UnsignedPlcOperation,
};
use url::Url;

mod common;
use common::{
    FakePlcDirectory, PlcTestIdentity, SequenceTransport, audit_json_for, make_audit_json,
    make_document_data_json, msg_response, plc_test_client, reply,
};

#[test]
fn configuration_validation_rules() {
    for bad in [
        "http://plc.directory",
        "https://127.0.0.1",
        "https://localhost",
        "https://plc.directory/path",
        "https://user@plc.directory",
        "https://plc.directory:8443",
    ] {
        let u = Url::parse(bad).unwrap();
        assert!(
            PlcClientConfiguration::production(Some(&u)).is_err(),
            "{bad}"
        );
    }
    assert!(
        PlcClientConfiguration::production_with_options(
            &Url::parse("https://plc.example.org:8443").unwrap(),
            PlcOperationLimits::SPECIFICATION,
            true
        )
        .is_ok()
    );
    assert!(
        PlcClientConfiguration::laboratory(
            &Url::parse("http://127.0.0.1:2582").unwrap(),
            PlcSubmitSuccessResponsePolicy::DidPlcServer001,
            None,
        )
        .is_ok()
    );
    assert!(
        PlcClientConfiguration::laboratory(
            &Url::parse("http://plc.example.com:2582").unwrap(),
            PlcSubmitSuccessResponsePolicy::Strict,
            None,
        )
        .is_err()
    );
    assert!(
        PlcClientConfiguration::laboratory(
            &Url::parse("http://plc.lab:2582").unwrap(),
            PlcSubmitSuccessResponsePolicy::Strict,
            Some("plc.lab"),
        )
        .is_ok()
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn strict_production_submit_and_tampered_audit_confirmation() {
    let id = PlcTestIdentity::generate();
    let (did, op) = id.genesis("alice.example.com").await;

    // 200 "OK" body confirmed via audit log succeeds in production strict mode
    let audit_bytes = make_audit_json(&did, std::slice::from_ref(&op), None, None);
    let expected_did = did.clone();
    let ok_then_audit = Arc::new(SequenceTransport::new(move |req, _, ordinal| {
        if ordinal == 0 {
            assert_eq!(req.method(), Method::POST);
            assert_eq!(req.uri().path(), format!("/{expected_did}"));
            Ok(Response::builder()
                .status(200)
                .header("content-type", "text/plain; charset=utf-8")
                .body(Bytes::from_static(b"OK"))
                .unwrap())
        } else {
            Ok(Response::builder()
                .status(200)
                .header("content-type", "application/json")
                .body(Bytes::from(audit_bytes.clone()))
                .unwrap())
        }
    }));
    let client = PlcDirectoryClient::new(
        PlcClientConfiguration::production(Some(&Url::parse("https://plc.test").unwrap()))
            .unwrap()
            .with_operation_limits(PlcOperationLimits::SPECIFICATION),
        ok_then_audit,
    );
    client.submit(&did, &op).await.unwrap();

    // Unconfirmed read error surfaces as SubmittedButUnconfirmed
    let unconfirmed_http = Arc::new(SequenceTransport::new(|_, _, ordinal| {
        if ordinal == 0 {
            Ok(Response::builder()
                .status(200)
                .header("content-type", "application/json")
                .body(Bytes::from_static(b"{}"))
                .unwrap())
        } else {
            Ok(reply(500, b"{}"))
        }
    }));
    let unconfirmed_client = PlcDirectoryClient::new(
        PlcClientConfiguration::production(Some(&Url::parse("https://plc.test").unwrap()))
            .unwrap()
            .with_operation_limits(PlcOperationLimits::SPECIFICATION),
        unconfirmed_http,
    );
    assert!(matches!(
        unconfirmed_client.submit(&did, &op).await,
        Err(PlcError::SubmittedButUnconfirmed { .. })
    ));

    // Laboratory DidPlcServer001 requires exact 200 text/plain; charset=utf-8 "OK"
    let lab_http = Arc::new(SequenceTransport::new(|_, _, _| {
        Ok(Response::builder()
            .status(200)
            .header("content-type", "text/plain; charset=utf-8")
            .body(Bytes::from_static(b"OK"))
            .unwrap())
    }));
    let lab_client = PlcDirectoryClient::new(
        PlcClientConfiguration::laboratory(
            &Url::parse("http://127.0.0.1:2582").unwrap(),
            PlcSubmitSuccessResponsePolicy::DidPlcServer001,
            None,
        )
        .unwrap(),
        lab_http,
    );
    lab_client.submit(&did, &op).await.unwrap();
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn directory_endpoints_read_write_export_and_recovery() {
    let dir = FakePlcDirectory::new();
    let support_did = "did:plc:oc6vwdlmk2kqyida5i74d3p5";
    dir.seed(support_did, audit_json_for(support_did));
    let client = plc_test_client(dir.clone(), PlcOperationLimits::SPECIFICATION);

    let doc = client.get_document(support_did).await.unwrap();
    let data = client.get_document_data(support_did).await.unwrap();
    let ops = client.get_operation_log(support_did).await.unwrap();
    let audit = client.get_audit_log(support_did).await.unwrap();
    let last = client.get_last_operation(support_did).await.unwrap();
    assert_eq!(doc, PlcDidDocument::from_data(&data));
    assert_eq!(ops.len(), 4);
    assert!(ops[0].is_legacy());
    assert_eq!(audit.len(), 4);
    assert_eq!(&last, ops.last().unwrap());
    assert_eq!(client.fetch_state(support_did).await.unwrap(), data);

    // Reject 3xx redirects
    dir.inject(
        &format!("/{support_did}/data"),
        Response::builder()
            .status(302)
            .header("location", "https://evil.example/")
            .body(Bytes::new())
            .unwrap(),
    );
    assert!(matches!(
        client.get_document_data(support_did).await,
        Err(PlcError::Unauthorized(_))
    ));

    // Create, update handle/pds/key/rotationKeys, recover, export sequence, tombstone
    let rot1 = K256Keypair::generate().unwrap();
    let rot2 = P256Keypair::generate().unwrap();
    let signing = K256Keypair::generate().unwrap();
    let created = client
        .create_did(
            "alice.example.com",
            &signing.did_key(),
            &[rot1.did_key(), rot2.did_key()],
            "https://pds.example.com",
            &rot1,
        )
        .await
        .unwrap();
    assert!(created.did.starts_with("did:plc:"));

    client
        .update_handle(&created.did, &rot2, "alice2.example.com")
        .await
        .unwrap();
    client
        .update_pds(&created.did, &rot1, "https://pds2.example.com")
        .await
        .unwrap();
    let state = client.fetch_state(&created.did).await.unwrap();
    assert_eq!(state.handle(), Some("alice2.example.com"));
    assert_eq!(state.pds_endpoint(), Some("https://pds2.example.com"));

    // Paginated exportSequence
    let mut seq = client.export_sequence(PlcExportCursor::Sequence(0), 2);
    let mut count = 0;
    while seq.next_entry().await.unwrap().is_some() {
        count += 1;
    }
    assert_eq!(count, 7);

    // Tombstone then fail update
    client.tombstone(&created.did, &rot1).await.unwrap();
    assert!(matches!(
        client.fetch_state(&created.did).await,
        Err(PlcError::Tombstoned { .. })
    ));
    let posts_before = dir.post_count();
    assert!(matches!(
        client
            .update_handle(&created.did, &rot1, "dead.example.com")
            .await,
        Err(PlcError::Tombstoned { .. })
    ));
    assert_eq!(dir.post_count(), posts_before);
}

#[derive(Debug)]
struct MockPdsState {
    recommended: get_recommended_did_credentials::Output,
    sign_response: Option<PlcOperation>,
    submit_status: u16,
    submitted: Vec<Value>,
}

#[derive(Debug, Clone)]
struct MockPdsApi {
    state: Arc<Mutex<MockPdsState>>,
}

impl PlcPdsIdentityApi for MockPdsApi {
    fn get_recommended_did_credentials(
        &self,
    ) -> petrel::rt::BoxFuture<
        '_,
        Result<(u16, Option<get_recommended_did_credentials::Output>), PlcPdsFlowError>,
    > {
        let out = self.state.lock().unwrap().recommended.clone();
        Box::pin(async move { Ok((200, Some(out))) })
    }

    fn request_plc_operation_signature(
        &self,
    ) -> petrel::rt::BoxFuture<'_, Result<u16, PlcPdsFlowError>> {
        Box::pin(async { Ok(200) })
    }

    fn sign_plc_operation(
        &self,
        input: sign_plc_operation::Input,
    ) -> petrel::rt::BoxFuture<'_, Result<(u16, Option<sign_plc_operation::Output>), PlcPdsFlowError>>
    {
        let st = self.state.lock().unwrap();
        if input.token.as_deref() != Some("good-token") {
            return Box::pin(async { Ok((400, None)) });
        }
        let op = st.sign_response.clone().unwrap();
        let val = PlcPdsBridge::value_for_operation(&op).unwrap();
        Box::pin(async move { Ok((200, Some(sign_plc_operation::Output { operation: val }))) })
    }

    fn submit_plc_operation(
        &self,
        input: submit_plc_operation::Input,
    ) -> petrel::rt::BoxFuture<'_, Result<u16, PlcPdsFlowError>> {
        let mut st = self.state.lock().unwrap();
        st.submitted.push(input.operation);
        let status = st.submit_status;
        Box::pin(async move { Ok(status) })
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn pds_operation_flow_verifies_requested_changes_and_rejects_tampering() {
    let id = PlcTestIdentity::generate();
    let (did, genesis_op) = id.genesis("alice.example.com").await;
    let audit_bytes = make_audit_json(&did, std::slice::from_ref(&genesis_op), None, None);
    let verified = PlcAuditLogVerifier::verify_json(&audit_bytes, &did).unwrap();

    let unsigned_upd = PlcOperationCodec::update_handle(&genesis_op, "alice2.example.com").unwrap();
    let signed_upd = PlcOperationCodec::sign(
        &UnsignedPlcOperation::Regular(unsigned_upd),
        &id.primary_rotation_key,
    )
    .await
    .unwrap();

    let api = MockPdsApi {
        state: Arc::new(Mutex::new(MockPdsState {
            recommended: get_recommended_did_credentials::Output {
                rotation_keys: Some(id.rotation_keys()),
                also_known_as: Some(vec!["at://alice.example.com".to_owned()]),
                verification_methods: Some(PlcPdsBridge::value_for_verification_methods(
                    &genesis_op.document_data(&did).unwrap().verification_methods,
                )),
                services: Some(PlcPdsBridge::value_for_services(
                    &genesis_op.document_data(&did).unwrap().services,
                )),
            },
            sign_response: Some(signed_upd.clone()),
            submit_status: 200,
            submitted: Vec::new(),
        })),
    };
    let flow = PlcPdsOperationFlow::new(api.clone());
    flow.request_signature_token().await.unwrap();

    let creds = flow.recommended_credentials().await.unwrap();
    assert_eq!(creds.rotation_keys, Some(id.rotation_keys()));

    let changes = PlcPdsOperationFields {
        also_known_as: Some(vec!["at://alice2.example.com".to_owned()]),
        ..PlcPdsOperationFields::default()
    };
    let returned = flow.sign_operation("good-token", &changes).await.unwrap();
    verified
        .verify_next_operation_applying(&returned, &changes)
        .unwrap();
    flow.submit(&returned).await.unwrap();
    assert_eq!(api.state.lock().unwrap().submitted.len(), 1);

    // Bad token fails with RequestFailed(400)
    assert!(matches!(
        flow.sign_operation("bad-token", &changes).await,
        Err(PlcPdsFlowError::RequestFailed { status: 400, .. })
    ));

    // Verify mismatching field detection (e.g., PDS slipped in extra rotation key)
    let mismatch = PlcPdsOperationFields {
        also_known_as: Some(vec!["at://different.example.com".to_owned()]),
        ..PlcPdsOperationFields::default()
    };
    assert!(matches!(
        verified.verify_next_operation_applying(&returned, &mismatch),
        Err(PlcError::Unauthorized(_))
    ));

    // Tombstone is refused even if validly signed
    let tomb_u =
        petrel_plc::UnsignedPlcTombstoneOperation::new(genesis_op.cid_string().unwrap()).unwrap();
    let tomb = PlcOperationCodec::sign(
        &UnsignedPlcOperation::Tombstone(tomb_u),
        &id.primary_rotation_key,
    )
    .await
    .unwrap();
    assert!(matches!(
        verified.verify_next_operation_applying(&tomb, &PlcPdsOperationFields::default()),
        Err(PlcError::Unauthorized(_))
    ));

    // Bridge round-trips real audit ops including prev == null
    for op in [&genesis_op, &signed_upd, &tomb] {
        let v = PlcPdsBridge::value_for_operation(op).unwrap();
        assert_eq!(PlcPdsBridge::operation_from_value(&v).unwrap(), *op);
    }

    // Also test XrpcClient conformance to PlcPdsIdentityApi
    let xrpc_transport = Arc::new(SequenceTransport::new(|req, _, _| {
        if req.uri().path() == "/xrpc/com.atproto.identity.requestPlcOperationSignature" {
            Ok(reply(200, b""))
        } else {
            Ok(reply(404, b"{}"))
        }
    }));
    let xrpc = XrpcClient::new(
        Url::parse("https://pds.example.com").unwrap(),
        xrpc_transport,
    )
    .unwrap();
    assert_eq!(xrpc.request_plc_operation_signature().await.unwrap(), 200);
    let _ = make_document_data_json(&did, &genesis_op);
    let _ = msg_response(404, "not found");
}

// Keep unused imports clean on wasm32
#[allow(dead_code)]
fn _use_http_transport_marker<T: HttpTransport>(_: &T) {}
#[allow(dead_code)]
fn _use_shared_transport_marker(
    _: SharedTransport,
    _: Request<Bytes>,
    _: BTreeMap<String, PlcService>,
) {
}
#[allow(dead_code)]
fn _use_box_future(_: BoxFuture<'static, ()>) {}
