#![allow(dead_code)]

use std::{
    collections::{BTreeMap, VecDeque},
    future::Future,
    sync::{
        Arc, Mutex,
        atomic::{AtomicUsize, Ordering},
    },
};

use bytes::Bytes;
use http::{Method, Request, Response};
use petrel::net::{HttpTransport, SendOptions, SharedTransport, TransportError};
use petrel_crypto::{K256Keypair, P256Keypair};
use petrel_plc::{
    PlcAtProfile, PlcAuditEntry, PlcAuditLogVerifier, PlcClientConfiguration, PlcDidDocument,
    PlcDirectoryClient, PlcOperation, PlcOperationCodec, PlcOperationLimits, UnsignedPlcOperation,
};
use serde_json::{Value as Json, json};
use url::Url;

pub(crate) const EXPORT_LEGACY: &[u8] =
    include_bytes!("../../../../Tests/PetrelPLCTests/Vectors/plc-directory/export-legacy.jsonl");
pub(crate) const EXPORT_SEQUENCED: &[u8] =
    include_bytes!("../../../../Tests/PetrelPLCTests/Vectors/plc-directory/export-sequenced.jsonl");

pub(crate) const AUDIT_LOGS: &[(&str, &str)] = &[
    (
        "did:plc:4dtbz2ivhp5app3sbntcccxc",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_4dtbz2ivhp5app3sbntcccxc.json"
        ),
    ),
    (
        "did:plc:5qepwfemd2p3ts3phpzjvmsi",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_5qepwfemd2p3ts3phpzjvmsi.json"
        ),
    ),
    (
        "did:plc:ar7c4by46qjdydhdevvrndac",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_ar7c4by46qjdydhdevvrndac.json"
        ),
    ),
    (
        "did:plc:eon2iu7v3x2ukgxkqaf7e5np",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_eon2iu7v3x2ukgxkqaf7e5np.json"
        ),
    ),
    (
        "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_ewvi7nxzyoun6zhxrhs64oiz.json"
        ),
    ),
    (
        "did:plc:hymtrrab3tb62ktcluou37ce",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_hymtrrab3tb62ktcluou37ce.json"
        ),
    ),
    (
        "did:plc:k525d5my7ob3divsqd5ogf7b",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_k525d5my7ob3divsqd5ogf7b.json"
        ),
    ),
    (
        "did:plc:n7eilcz7ouze6kj5hwvyt4ju",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_n7eilcz7ouze6kj5hwvyt4ju.json"
        ),
    ),
    (
        "did:plc:nlkuhfcmtu7jluphj37j5o4f",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_nlkuhfcmtu7jluphj37j5o4f.json"
        ),
    ),
    (
        "did:plc:oc6vwdlmk2kqyida5i74d3p5",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_oc6vwdlmk2kqyida5i74d3p5.json"
        ),
    ),
    (
        "did:plc:xgj5yvayzto5fx3qq2o7ichg",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_xgj5yvayzto5fx3qq2o7ichg.json"
        ),
    ),
    (
        "did:plc:z72i7hdynmk6r22z27h6tvur",
        include_str!(
            "../../../../Tests/PetrelPLCTests/Vectors/plc-directory/audit/did_plc_z72i7hdynmk6r22z27h6tvur.json"
        ),
    ),
];

pub(crate) fn audit_json_for(did: &str) -> &'static [u8] {
    AUDIT_LOGS
        .iter()
        .find(|(d, _)| *d == did)
        .map(|(_, data)| data.as_bytes())
        .expect("known corpus DID")
}

pub(crate) fn plc_test_timestamp(milliseconds: i64) -> String {
    // Civil-from-days (Howard Hinnant's Euclidean affine algorithm)
    let secs = milliseconds.div_euclid(1_000);
    let millis = milliseconds.rem_euclid(1_000);
    let days = secs.div_euclid(86_400);
    let day_secs = secs.rem_euclid(86_400);
    let hour = day_secs / 3_600;
    let minute = (day_secs % 3_600) / 60;
    let second = day_secs % 60;

    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = mp + if mp < 10 { 3 } else { -9 };
    let year = y + i64::from(m <= 2);
    format!("{year:04}-{m:02}-{d:02}T{hour:02}:{minute:02}:{second:02}.{millis:03}Z")
}

#[derive(Debug, Clone)]
pub(crate) struct RecordedRequest {
    pub(crate) method: Method,
    pub(crate) url: Url,
    pub(crate) accept: Option<String>,
    pub(crate) content_type: Option<String>,
    pub(crate) body: Vec<u8>,
}

#[derive(Debug, Clone)]
struct SequencedOp {
    seq: u64,
    did: String,
    cid: String,
}

#[derive(Debug)]
struct FakeDirState {
    logs: BTreeMap<String, Vec<PlcAuditEntry>>,
    sequence: Vec<SequencedOp>,
    clock_ms: i64,
    injected: BTreeMap<String, VecDeque<Response<Bytes>>>,
    requests: Vec<RecordedRequest>,
}

/// In-memory PLC directory implementing `HttpTransport`.
#[derive(Debug, Clone)]
pub(crate) struct FakePlcDirectory {
    state: Arc<Mutex<FakeDirState>>,
}

impl Default for FakePlcDirectory {
    fn default() -> Self {
        Self::new()
    }
}

impl FakePlcDirectory {
    pub(crate) fn new() -> Self {
        Self {
            state: Arc::new(Mutex::new(FakeDirState {
                logs: BTreeMap::new(),
                sequence: Vec::new(),
                clock_ms: 1_767_225_600_000, // 2026-01-01T00:00:00.000Z
                injected: BTreeMap::new(),
                requests: Vec::new(),
            })),
        }
    }

    pub(crate) fn advance_hours(&self, hours: f64) {
        let mut st = self.state.lock().expect("lock");
        #[allow(clippy::cast_possible_truncation)]
        let delta = (hours * 3_600_000.0) as i64;
        st.clock_ms += delta;
    }

    pub(crate) fn seed(&self, did: &str, audit_log_json: &[u8]) {
        let entries = PlcAuditLogVerifier::decode(audit_log_json, did).expect("valid seed audit");
        let mut st = self.state.lock().expect("lock");
        for entry in &entries {
            let seq = (st.sequence.len() + 1) as u64;
            st.sequence.push(SequencedOp {
                seq,
                did: did.to_owned(),
                cid: entry.cid.clone(),
            });
        }
        st.logs.insert(did.to_owned(), entries);
    }

    pub(crate) fn inject(&self, path: &str, response: Response<Bytes>) {
        let mut st = self.state.lock().expect("lock");
        st.injected
            .entry(path.to_owned())
            .or_default()
            .push_back(response);
    }

    pub(crate) fn requests(&self) -> Vec<RecordedRequest> {
        self.state.lock().expect("lock").requests.clone()
    }

    pub(crate) fn post_count(&self) -> usize {
        self.state
            .lock()
            .expect("lock")
            .requests
            .iter()
            .filter(|r| r.method == Method::POST)
            .count()
    }

    pub(crate) fn entries(&self, did: &str) -> Vec<PlcAuditEntry> {
        self.state
            .lock()
            .expect("lock")
            .logs
            .get(did)
            .cloned()
            .unwrap_or_default()
    }
}

impl HttpTransport for FakePlcDirectory {
    fn send(
        &self,
        request: Request<Bytes>,
        _options: &SendOptions,
    ) -> impl Future<Output = Result<Response<Bytes>, TransportError>> + petrel::rt::MaybeSend {
        let state = self.state.clone();
        async move {
            let url = Url::parse(&request.uri().to_string())
                .map_err(|e| TransportError::InvalidRequest(e.to_string()))?;
            let path = url.path().to_owned();
            let method = request.method().clone();
            let accept = request
                .headers()
                .get("accept")
                .and_then(|v| v.to_str().ok())
                .map(str::to_owned);
            let content_type = request
                .headers()
                .get("content-type")
                .and_then(|v| v.to_str().ok())
                .map(str::to_owned);
            let body = request.body().to_vec();

            let mut st = state.lock().expect("lock");
            st.requests.push(RecordedRequest {
                method: method.clone(),
                url: url.clone(),
                accept,
                content_type,
                body: body.clone(),
            });

            if let Some(queue) = st.injected.get_mut(&path)
                && let Some(resp) = queue.pop_front()
            {
                return Ok(resp);
            }

            Ok(route_request(&mut st, &method, &url, &body))
        }
    }
}

fn route_request(
    st: &mut FakeDirState,
    method: &Method,
    url: &Url,
    body: &[u8],
) -> Response<Bytes> {
    let parts: Vec<&str> = url
        .path()
        .split('/')
        .filter(|seg| !seg.is_empty())
        .collect();
    let Some(&first) = parts.first() else {
        return msg_response(404, "not found");
    };
    if first == "export" && parts.len() == 1 && method == Method::GET {
        return handle_export(st, url);
    }
    let did = first;
    if PlcOperationCodec::validate_canonical_did(did).is_err() {
        return msg_response(
            400,
            &format!("Resolution of non-PLC DIDs not supported: {did}"),
        );
    }
    if method == Method::POST {
        if parts.len() != 1 {
            return msg_response(404, "not found");
        }
        return handle_post(st, did, body);
    }
    let Some(log) = st.logs.get(did) else {
        return msg_response(404, &format!("DID not registered: {did}"));
    };
    let active: Vec<&PlcAuditEntry> = log.iter().filter(|e| !e.nullified).collect();
    let Some(&head) = active.last() else {
        return msg_response(404, &format!("DID not registered: {did}"));
    };

    match parts[1..] {
        [] => {
            let Some(data) = head.operation.document_data(did) else {
                return msg_response(404, &format!("DID not available: {did}"));
            };
            let doc = PlcDidDocument::from_data(&data);
            json_response(
                200,
                "application/did+ld+json; charset=utf-8",
                &serde_json::to_value(doc).unwrap(),
            )
        }
        ["data"] => {
            let Some(data) = head.operation.document_data(did) else {
                return msg_response(404, &format!("DID not available: {did}"));
            };
            json_response(
                200,
                "application/json; charset=utf-8",
                &serde_json::to_value(data).unwrap(),
            )
        }
        ["log"] => {
            let ops: Vec<Json> = active
                .iter()
                .map(|e| serde_json::from_slice(&e.operation.canonical_json().unwrap()).unwrap())
                .collect();
            json_response(200, "application/json; charset=utf-8", &Json::Array(ops))
        }
        ["log", "audit"] => {
            let arr: Vec<Json> = log.iter().map(audit_to_json).collect();
            json_response(200, "application/json; charset=utf-8", &Json::Array(arr))
        }
        ["log", "last"] => {
            let val: Json =
                serde_json::from_slice(&head.operation.canonical_json().unwrap()).unwrap();
            json_response(200, "application/json; charset=utf-8", &val)
        }
        _ => msg_response(404, "not found"),
    }
}

fn handle_post(st: &mut FakeDirState, did: &str, body: &[u8]) -> Response<Bytes> {
    let op = match PlcOperationCodec::decode_signed_json(body) {
        Ok(op) => op,
        Err(err) => return msg_response(400, &format!("Not a valid operation: {err}")),
    };
    if let Err(err) =
        PlcOperationCodec::validate_for_submission(&op, &PlcOperationLimits::REFERENCE_DIRECTORY)
    {
        return msg_response(400, &format!("Not a valid operation: {err}"));
    }
    st.clock_ms += 1_000;
    let cid = op.cid_string().unwrap();
    let mut candidate = st.logs.get(did).cloned().unwrap_or_default();
    candidate.push(PlcAuditEntry {
        did: did.to_owned(),
        operation: op,
        cid: cid.clone(),
        nullified: false,
        created_at: plc_test_timestamp(st.clock_ms),
    });
    match PlcAuditLogVerifier::verify(&candidate, did) {
        Ok(verified) => {
            st.logs.insert(did.to_owned(), verified.entries);
            let seq = (st.sequence.len() + 1) as u64;
            st.sequence.push(SequencedOp {
                seq,
                did: did.to_owned(),
                cid,
            });
            Response::builder()
                .status(200)
                .header("content-type", "text/plain; charset=utf-8")
                .body(Bytes::from_static(b"OK"))
                .unwrap()
        }
        Err(err) => msg_response(400, &format!("Invalid operation: {err}")),
    }
}

fn handle_export(st: &FakeDirState, url: &Url) -> Response<Bytes> {
    let pairs: BTreeMap<String, String> = url.query_pairs().into_owned().collect();
    let count = pairs
        .get("count")
        .and_then(|v| v.parse::<usize>().ok())
        .unwrap_or(1_000)
        .min(1_000);
    let after = pairs.get("after");
    let mut lines = Vec::new();
    for item in &st.sequence {
        if lines.len() >= count {
            break;
        }
        let Some(entry) = st
            .logs
            .get(&item.did)
            .and_then(|l| l.iter().find(|e| e.cid == item.cid))
        else {
            continue;
        };
        let Json::Object(mut obj) = audit_to_json(entry) else {
            unreachable!()
        };
        if let Some(after_val) = after {
            if let Ok(after_seq) = after_val.parse::<u64>() {
                if item.seq <= after_seq {
                    continue;
                }
                obj.insert("seq".to_owned(), Json::Number(item.seq.into()));
                obj.insert("type".to_owned(), Json::String("sequenced_op".to_owned()));
                obj.remove("nullified");
            } else if entry.created_at.as_str() <= after_val.as_str() {
                continue;
            }
        }
        lines.push(serde_json::to_string(&Json::Object(obj)).unwrap());
    }
    Response::builder()
        .status(200)
        .header("content-type", "application/jsonlines")
        .body(Bytes::from(lines.join("\n")))
        .unwrap()
}

fn audit_to_json(entry: &PlcAuditEntry) -> Json {
    let op_val: Json = serde_json::from_slice(&entry.operation.canonical_json().unwrap()).unwrap();
    json!({
        "did": entry.did,
        "operation": op_val,
        "cid": entry.cid,
        "nullified": entry.nullified,
        "createdAt": entry.created_at,
    })
}

pub(crate) fn json_response(status: u16, content_type: &str, value: &Json) -> Response<Bytes> {
    Response::builder()
        .status(status)
        .header("content-type", content_type)
        .body(Bytes::from(serde_json::to_vec(value).unwrap()))
        .unwrap()
}

pub(crate) fn msg_response(status: u16, msg: &str) -> Response<Bytes> {
    json_response(
        status,
        "application/json; charset=utf-8",
        &json!({ "message": msg }),
    )
}

pub(crate) fn plc_test_client(
    directory: FakePlcDirectory,
    limits: PlcOperationLimits,
) -> PlcDirectoryClient {
    let origin = Url::parse("https://plc.test").unwrap();
    let config = PlcClientConfiguration::production_with_options(&origin, limits, false).unwrap();
    PlcDirectoryClient::new(config, Arc::new(directory) as SharedTransport)
}

pub(crate) struct PlcTestIdentity {
    pub(crate) signing_key: K256Keypair,
    pub(crate) primary_rotation_key: K256Keypair,
    pub(crate) backup_rotation: P256Keypair,
}

impl PlcTestIdentity {
    pub(crate) fn generate() -> Self {
        Self {
            signing_key: K256Keypair::generate().unwrap(),
            primary_rotation_key: K256Keypair::generate().unwrap(),
            backup_rotation: P256Keypair::generate().unwrap(),
        }
    }

    pub(crate) fn rotation_keys(&self) -> Vec<String> {
        vec![
            self.primary_rotation_key.did_key(),
            self.backup_rotation.did_key(),
        ]
    }

    pub(crate) async fn genesis(&self, handle: &str) -> (String, PlcOperation) {
        let unsigned = PlcAtProfile::genesis_operation(
            handle,
            &self.signing_key.did_key(),
            &self.rotation_keys(),
            "https://pds.example.com",
        )
        .unwrap();
        let op = PlcOperationCodec::sign(
            &UnsignedPlcOperation::Regular(unsigned),
            &self.primary_rotation_key,
        )
        .await
        .unwrap();
        let did = PlcOperationCodec::genesis_did(&op).unwrap();
        (did, op)
    }
}

pub(crate) fn make_audit_json(
    did: &str,
    operations: &[PlcOperation],
    timestamps: Option<&[&str]>,
    claimed_nullified: Option<&[bool]>,
) -> Vec<u8> {
    let entries: Vec<Json> = operations
        .iter()
        .enumerate()
        .map(|(i, op)| {
            let op_json: Json = serde_json::from_slice(&op.canonical_json().unwrap()).unwrap();
            let ts = timestamps.map_or_else(
                || format!("2026-07-27T12:00:{i:02}.000Z"),
                |t| t[i].to_owned(),
            );
            let nullified = claimed_nullified.is_some_and(|flags| flags[i]);
            json!({
                "did": did,
                "operation": op_json,
                "cid": op.cid_string().unwrap(),
                "nullified": nullified,
                "createdAt": ts,
            })
        })
        .collect();
    serde_json::to_vec(&entries).unwrap()
}

pub(crate) fn make_document_data_json(did: &str, op: &PlcOperation) -> Vec<u8> {
    let data = op.document_data(did).unwrap();
    serde_json::to_vec(&data).unwrap()
}

pub(crate) fn reply(status: u16, body: &'static [u8]) -> Response<Bytes> {
    Response::builder()
        .status(status)
        .body(Bytes::from_static(body))
        .unwrap()
}

type HandlerFn = Box<
    dyn Fn(&Request<Bytes>, &SendOptions, usize) -> Result<Response<Bytes>, TransportError>
        + Send
        + Sync,
>;

pub(crate) struct SequenceTransport {
    ordinal: AtomicUsize,
    handler: HandlerFn,
}

impl SequenceTransport {
    pub(crate) fn new<F>(handler: F) -> Self
    where
        F: Fn(&Request<Bytes>, &SendOptions, usize) -> Result<Response<Bytes>, TransportError>
            + Send
            + Sync
            + 'static,
    {
        Self {
            ordinal: AtomicUsize::new(0),
            handler: Box::new(handler),
        }
    }
}

impl HttpTransport for SequenceTransport {
    fn send(
        &self,
        request: Request<Bytes>,
        options: &SendOptions,
    ) -> impl Future<Output = Result<Response<Bytes>, TransportError>> + petrel::rt::MaybeSend {
        let ordinal = self.ordinal.fetch_add(1, Ordering::Relaxed);
        let result = (self.handler)(&request, options, ordinal);
        std::future::ready(result)
    }
}
