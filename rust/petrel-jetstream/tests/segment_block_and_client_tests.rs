use std::collections::{BTreeMap, VecDeque};
use std::sync::Arc;
use std::time::Duration;

use async_lock::Mutex;
use bytes::Bytes;
use futures_util::StreamExt;
use petrel::net::TransportError;
use petrel::rt::BoxFuture;
use petrel_core::{Value, dagcbor};
use petrel_firehose::{
    FirehoseBackoffConfiguration, FirehoseCursorStorage, FirehoseSubscriptionError,
    FirehoseWebSocketSession, FirehoseWebSocketSessionFactory, InMemoryFirehoseCursorStorage,
    RelayRepoAction,
};
use petrel_jetstream::{
    CursorStorageOperation, JetstreamClient, JetstreamClientConfiguration, JetstreamClientError,
    JetstreamEvent, JetstreamFilter, JetstreamHttpTransport, JetstreamKind, JetstreamMode,
    JetstreamSubscriptionError, JetstreamZstd, SegmentBlockDecoder, SegmentBlockError,
    SegmentBytesReader, SegmentEvent, SnapshotBlockRange, SnapshotPlan, SnapshotPlanSegment,
    SnapshotPlanStats,
};
use serde_json::json;
use url::Url;

#[cfg(not(target_arch = "wasm32"))]
use tokio::test as async_test;
#[cfg(target_arch = "wasm32")]
use wasm_bindgen_test::wasm_bindgen_test as async_test;

fn encode_columnar_block(events: &[SegmentEvent]) -> Vec<u8> {
    let n = events.len();
    let mut out = Vec::new();
    out.extend_from_slice(&(u32::try_from(n).unwrap()).to_le_bytes());
    if n == 0 {
        return out;
    }
    for e in events {
        out.extend_from_slice(&e.seq.to_le_bytes());
    }
    for e in events {
        out.extend_from_slice(&e.witnessed_at_us.to_le_bytes());
    }
    for e in events {
        out.extend_from_slice(&e.indexed_at_us.to_le_bytes());
    }
    for e in events {
        out.push(e.kind);
    }
    for e in events {
        out.push(u8::try_from(e.collection.len()).unwrap());
    }
    for e in events {
        out.extend_from_slice(&u16::try_from(e.did.len()).unwrap().to_le_bytes());
    }
    for e in events {
        out.push(u8::try_from(e.rkey.len()).unwrap());
    }
    for e in events {
        out.push(u8::try_from(e.rev.len()).unwrap());
    }
    for e in events {
        out.extend_from_slice(&u32::try_from(e.payload.len()).unwrap().to_le_bytes());
    }
    for e in events {
        out.extend_from_slice(e.collection.as_bytes());
    }
    for e in events {
        out.extend_from_slice(e.did.as_bytes());
    }
    for e in events {
        out.extend_from_slice(e.rkey.as_bytes());
    }
    for e in events {
        out.extend_from_slice(e.rev.as_bytes());
    }
    for e in events {
        out.extend_from_slice(&e.payload);
    }
    out
}

fn encode_jss_segment(blocks: &[Vec<u8>]) -> Vec<u8> {
    let mut body = Vec::new();
    for blk in blocks {
        let compressed = JetstreamZstd::compress(blk).unwrap();
        body.extend_from_slice(&(compressed.len() as u64).to_le_bytes());
        body.extend_from_slice(&compressed);
    }
    let footer_offset = 256_u64 + body.len() as u64;
    let mut header = [0_u8; 256];
    header[0..4].copy_from_slice(b"jss0");
    header[4..12].copy_from_slice(&1_u64.to_le_bytes()); // sealed checksum != 0
    header[12..14].copy_from_slice(&1_u16.to_le_bytes()); // version = 1
    header[14..18].copy_from_slice(&(u32::try_from(blocks.len()).unwrap()).to_le_bytes());
    header[58..66].copy_from_slice(&footer_offset.to_le_bytes());

    let mut full = Vec::with_capacity(256 + body.len());
    full.extend_from_slice(&header);
    full.extend_from_slice(&body);
    full
}

fn make_post_cbor(text: &str) -> Vec<u8> {
    let mut map = BTreeMap::new();
    map.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".to_owned()),
    );
    map.insert("text".to_owned(), Value::String(text.to_owned()));
    dagcbor::encode(&Value::Object(map))
}

#[cfg_attr(target_arch = "wasm32", async_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn segment_block_and_jss_reader_decode_and_validate_headers() {
    let ev1 = SegmentEvent {
        seq: 10,
        witnessed_at_us: 1_000_000,
        indexed_at_us: 2_000_000,
        kind: 1,
        collection: "app.bsky.feed.post".to_owned(),
        did: "did:plc:alice".to_owned(),
        rkey: "3k7a".to_owned(),
        rev: "3k7v2abc23456".to_owned(),
        payload: make_post_cbor("hello"),
    };
    let ev2 = SegmentEvent {
        seq: 11,
        witnessed_at_us: 1_500_000,
        indexed_at_us: 0,
        kind: 3,
        collection: "app.bsky.feed.post".to_owned(),
        did: "did:plc:alice".to_owned(),
        rkey: "3k7a".to_owned(),
        rev: "3k7v2abc23457".to_owned(),
        payload: Vec::new(),
    };

    let raw_blk = encode_columnar_block(&[ev1.clone(), ev2.clone()]);
    let frame = JetstreamZstd::compress(&raw_blk).unwrap();
    let decoded = SegmentBlockDecoder::decode_frame(&frame).unwrap();
    assert_eq!(decoded, vec![ev1.clone(), ev2]);

    let j1 = decoded[0].to_jetstream_event().unwrap();
    let JetstreamEvent::Commit(c1) = j1 else {
        panic!("expected commit");
    };
    assert_eq!(c1.time_us, 2_000_000);
    assert_eq!(c1.operation, RelayRepoAction::Create);
    assert!(c1.decoded_record().is_some());

    let j2 = decoded[1].to_jetstream_event().unwrap();
    assert!(matches!(
        j2,
        JetstreamEvent::Commit(ref c) if c.time_us == 1_500_000 && c.operation == RelayRepoAction::Delete
    ));

    // Test SegmentBytesReader (works on native + wasm32)
    let empty_blk = encode_columnar_block(&[]);
    let jss = encode_jss_segment(&[raw_blk, empty_blk]);
    let mut reader = SegmentBytesReader::new(&jss).unwrap();
    assert_eq!(reader.block_count, 2);
    assert_eq!(reader.next_block().unwrap().unwrap().len(), 2);
    assert_eq!(reader.next_block().unwrap().unwrap().len(), 0);
    assert!(reader.next_block().unwrap().is_none());

    // Error checks on bad headers
    let mut bad_magic = jss.clone();
    bad_magic[0] = b'x';
    assert_eq!(
        SegmentBytesReader::new(&bad_magic).unwrap_err(),
        SegmentBlockError::BadMagic
    );
    let mut unsealed = jss.clone();
    unsealed[4..12].fill(0);
    assert_eq!(
        SegmentBytesReader::new(&unsealed).unwrap_err(),
        SegmentBlockError::NotSealed
    );
    let mut bad_ver = jss;
    bad_ver[12..14].copy_from_slice(&2_u16.to_le_bytes());
    assert_eq!(
        SegmentBytesReader::new(&bad_ver).unwrap_err(),
        SegmentBlockError::UnsupportedVersion(2)
    );

    // Crafted 38-byte single-event block with kind=1, col_len=1, payload_len=u32::MAX must
    // return Truncated (no 32-bit usize wraparound on wasm32 or slice panic).
    let mut crafted = vec![0_u8; 38];
    crafted[0..4].copy_from_slice(&1_u32.to_le_bytes()); // event_count = 1
    crafted[28] = 1; // kind = 1
    crafted[29] = 1; // col_len = 1
    crafted[34..38].copy_from_slice(&u32::MAX.to_le_bytes()); // payload_len = u32::MAX
    assert_eq!(
        SegmentBlockDecoder::decode_uncompressed(&crafted).unwrap_err(),
        SegmentBlockError::Truncated
    );
}

#[cfg(not(target_arch = "wasm32"))]
#[test]
fn native_segment_file_reader_reads_jss_file() {
    let ev = SegmentEvent {
        seq: 1,
        witnessed_at_us: 100,
        indexed_at_us: 200,
        kind: 7,
        collection: "app.bsky.feed.post".to_owned(),
        did: "did:plc:file".to_owned(),
        rkey: "3k7file".to_owned(),
        rev: "3k7v2abc23456".to_owned(),
        payload: make_post_cbor("from file"),
    };
    let jss = encode_jss_segment(&[encode_columnar_block(&[ev])]);
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("seg-0.jss");
    std::fs::write(&path, jss).unwrap();

    let mut reader = petrel_jetstream::SegmentFileReader::open(&path).unwrap();
    let block = reader.next_block().unwrap().unwrap();
    assert_eq!(block.len(), 1);
    assert_eq!(block[0].seq, 1);
    assert!(reader.next_block().unwrap().is_none());

    // Malformed 264-byte file with footer_offset=u64::MAX and first block_len=u64::MAX-264 must
    // return Truncated without attempting to allocate u64::MAX bytes.
    let mut bad = vec![0_u8; 264];
    bad[0..4].copy_from_slice(b"jss0");
    bad[4..12].copy_from_slice(&1_u64.to_le_bytes()); // non-zero checksum
    bad[12..14].copy_from_slice(&1_u16.to_le_bytes()); // version 1
    bad[14..18].copy_from_slice(&1_u32.to_le_bytes()); // block_count = 1
    bad[58..66].copy_from_slice(&u64::MAX.to_le_bytes());
    bad[256..264].copy_from_slice(&(u64::MAX - 264).to_le_bytes());
    let bad_path = dir.path().join("bad-overflow.jss");
    std::fs::write(&bad_path, bad).unwrap();
    assert_eq!(
        petrel_jetstream::SegmentFileReader::open(&bad_path).unwrap_err(),
        SegmentBlockError::Truncated
    );
}

type HttpHandler = Arc<
    dyn Fn(&http::Request<Bytes>) -> Result<http::Response<Bytes>, TransportError> + Send + Sync,
>;

#[derive(Clone)]
struct MockHttpTransport {
    handler: HttpHandler,
}

impl std::fmt::Debug for MockHttpTransport {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("MockHttpTransport").finish_non_exhaustive()
    }
}

impl JetstreamHttpTransport for MockHttpTransport {
    fn send(
        &self,
        request: http::Request<Bytes>,
    ) -> BoxFuture<'_, Result<http::Response<Bytes>, TransportError>> {
        let handler = Arc::clone(&self.handler);
        Box::pin(async move { handler(&request) })
    }
}

#[derive(Debug)]
struct MockWsSession {
    frames: Mutex<VecDeque<Result<Vec<u8>, FirehoseSubscriptionError>>>,
}

impl FirehoseWebSocketSession for MockWsSession {
    fn receive_message(&self) -> BoxFuture<'_, Result<Vec<u8>, FirehoseSubscriptionError>> {
        Box::pin(async move {
            self.frames
                .lock()
                .await
                .pop_front()
                .unwrap_or(Err(FirehoseSubscriptionError::ConnectionClosed))
        })
    }

    fn close(&self) -> BoxFuture<'_, ()> {
        Box::pin(async {})
    }
}

#[derive(Debug)]
struct MockWsFactory {
    outcomes: Mutex<VecDeque<Result<Arc<MockWsSession>, FirehoseSubscriptionError>>>,
    urls: Mutex<Vec<Url>>,
}

impl FirehoseWebSocketSessionFactory for MockWsFactory {
    fn make_session(
        &self,
        url: Url,
    ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>> {
        self.make_session_with_subprotocols(url, Vec::new())
    }

    fn make_session_with_subprotocols(
        &self,
        url: Url,
        _subprotocols: Vec<String>,
    ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>> {
        Box::pin(async move {
            self.urls.lock().await.push(url);
            let next = self
                .outcomes
                .lock()
                .await
                .pop_front()
                .unwrap_or(Err(FirehoseSubscriptionError::ConnectionClosed));
            next.map(|s| Box::new(WsWrap(s)) as Box<dyn FirehoseWebSocketSession>)
        })
    }
}

#[derive(Debug)]
struct WsWrap(Arc<MockWsSession>);

impl FirehoseWebSocketSession for WsWrap {
    fn receive_message(&self) -> BoxFuture<'_, Result<Vec<u8>, FirehoseSubscriptionError>> {
        self.0.receive_message()
    }
    fn close(&self) -> BoxFuture<'_, ()> {
        self.0.close()
    }
}

#[allow(clippy::too_many_lines)]
#[async_test]
async fn client_snapshot_then_live_backfills_dedups_cutover_and_persists_cursor() {
    let seg_bytes = encode_jss_segment(&[encode_columnar_block(&[
        SegmentEvent {
            seq: 1,
            witnessed_at_us: 100,
            indexed_at_us: 100,
            kind: 1,
            collection: "app.bsky.feed.post".to_owned(),
            did: "did:plc:alice".to_owned(),
            rkey: "r1".to_owned(),
            rev: "3k7v2abc23456".to_owned(),
            payload: make_post_cbor("one"),
        },
        SegmentEvent {
            seq: 2,
            witnessed_at_us: 200,
            indexed_at_us: 200,
            kind: 1,
            collection: "app.bsky.feed.like".to_owned(), // filtered out!
            did: "did:plc:alice".to_owned(),
            rkey: "r2".to_owned(),
            rev: "3k7v2abc23457".to_owned(),
            payload: Vec::new(),
        },
    ])]);
    let block_frame = JetstreamZstd::compress(&encode_columnar_block(&[SegmentEvent {
        seq: 3,
        witnessed_at_us: 300,
        indexed_at_us: 300,
        kind: 1,
        collection: "app.bsky.feed.post".to_owned(),
        did: "did:plc:alice".to_owned(),
        rkey: "r3".to_owned(),
        rev: "3k7v2abc23458".to_owned(),
        payload: make_post_cbor("three"),
    }]))
    .unwrap();

    let seg_bytes_c = seg_bytes.clone();
    let block_frame_c = block_frame.clone();
    let http = Arc::new(MockHttpTransport {
        handler: Arc::new(move |req| {
            let path = req.uri().path();
            if path.ends_with("planSnapshot") {
                let plan = SnapshotPlan {
                    planned_through_seq: 3,
                    sealed_tip_seq: 3,
                    segments: vec![
                        SnapshotPlanSegment {
                            name: "seg-0".to_owned(),
                            index: 0,
                            checksum: "sha".to_owned(),
                            min_seq: 1,
                            max_seq: 2,
                            mode: "segment".to_owned(),
                            blocks: None,
                        },
                        SnapshotPlanSegment {
                            name: "seg-1".to_owned(),
                            index: 1,
                            checksum: "sha2".to_owned(),
                            min_seq: 3,
                            max_seq: 3,
                            mode: "blocks".to_owned(),
                            blocks: Some(vec![SnapshotBlockRange { first: 0, last: 0 }]),
                        },
                    ],
                    stats: SnapshotPlanStats {
                        segments_examined: 2,
                        segments_matched: 2,
                        blocks_matched: 1,
                        entries: 3,
                    },
                };
                Ok(http::Response::builder()
                    .status(200)
                    .body(Bytes::from(serde_json::to_vec(&plan).unwrap()))
                    .unwrap())
            } else if path.ends_with("getSegment") {
                Ok(http::Response::builder()
                    .status(200)
                    .body(Bytes::from(seg_bytes_c.clone()))
                    .unwrap())
            } else if path.ends_with("getBlock") {
                Ok(http::Response::builder()
                    .status(200)
                    .body(Bytes::from(block_frame_c.clone()))
                    .unwrap())
            } else {
                Ok(http::Response::builder()
                    .status(426)
                    .body(Bytes::new())
                    .unwrap())
            }
        }),
    });

    // Live socket delivers seq=3 (at cutover -> dropped!), seq=4 (delivered!), then FutureCursor
    let f_dup = serde_json::to_vec(&json!({
        "$type": "message",
        "payload": {
            "$type": "network.bsky.jetstream.subscribeEvents#commit",
            "seq": 3, "did": "did:plc:alice", "time": "2026-01-01T00:00:00Z",
            "rev": "3k7v2abc23458", "operation": "create", "collection": "app.bsky.feed.post", "rkey": "r3"
        }
    }))
    .unwrap();
    let f4 = serde_json::to_vec(&json!({
        "$type": "message",
        "payload": {
            "$type": "network.bsky.jetstream.subscribeEvents#commit",
            "seq": 4, "did": "did:plc:alice", "time": "2026-01-01T00:00:01Z",
            "rev": "3k7v2abc23459", "operation": "create", "collection": "app.bsky.feed.post", "rkey": "r4"
        }
    }))
    .unwrap();
    let f_err = serde_json::to_vec(&json!({
        "$type": "error",
        "error": "FutureCursor",
        "message": "done"
    }))
    .unwrap();

    let ws_session = Arc::new(MockWsSession {
        frames: Mutex::new(VecDeque::from(vec![Ok(f_dup), Ok(f4), Ok(f_err)])),
    });
    let ws_factory = Arc::new(MockWsFactory {
        outcomes: Mutex::new(VecDeque::from(vec![Ok(ws_session)])),
        urls: Mutex::new(Vec::new()),
    });
    let cursor_storage = Arc::new(InMemoryFirehoseCursorStorage::new());

    let mut cfg = JetstreamClientConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg.mode = JetstreamMode::SnapshotThenLive { after_seq: 0 };
    cfg.filter = JetstreamFilter {
        kinds: vec![JetstreamKind::Commit],
        dids: Vec::new(),
        collections: vec!["app.bsky.feed.post".to_owned()],
    };
    cfg.cursor_storage = Some(cursor_storage.clone());
    cfg.transport = http;
    cfg.session_factory = ws_factory.clone();
    cfg.backoff = FirehoseBackoffConfiguration {
        initial_delay: Duration::from_millis(1),
        max_delay: Duration::from_millis(2),
        multiplier: 2.0,
        jitter: 0.0,
    };

    let client = JetstreamClient::new(cfg);
    let mut stream = client.events();

    let b1 = stream.next().await.unwrap().unwrap();
    assert_eq!(b1.events.len(), 1);
    assert_eq!(b1.events[0].seq(), Some(1));
    assert_eq!(b1.last_cursor, 2); // seq 2 was filtered out but still moved cursor!
    assert_eq!(cursor_storage.load_cursor().await.unwrap(), None);

    let b2 = stream.next().await.unwrap().unwrap();
    assert_eq!(cursor_storage.load_cursor().await.unwrap(), Some(2)); // b1 saved when consumer asked for b2!
    assert_eq!(b2.events[0].seq(), Some(3));

    let b3 = stream.next().await.unwrap().unwrap();
    assert_eq!(b3.events[0].seq(), Some(4));

    let end = stream.next().await.unwrap();
    assert!(matches!(end, Err(JetstreamClientError::Subscription(_))));
    assert_eq!(cursor_storage.load_cursor().await.unwrap(), Some(4));
}

#[derive(Debug)]
struct WindowTestTransport {
    plan_json: Vec<u8>,
    segments: BTreeMap<String, Vec<u8>>,
    gate_seg0: Arc<std::sync::atomic::AtomicBool>,
    requested: Arc<Mutex<Vec<String>>>,
}

impl JetstreamHttpTransport for WindowTestTransport {
    fn send(
        &self,
        request: http::Request<Bytes>,
    ) -> BoxFuture<'_, Result<http::Response<Bytes>, TransportError>> {
        let path = request.uri().path().to_owned();
        let query = request.uri().query().unwrap_or("").to_owned();
        let plan_json = self.plan_json.clone();
        let segments = self.segments.clone();
        let gate_seg0 = Arc::clone(&self.gate_seg0);
        let requested = Arc::clone(&self.requested);
        Box::pin(async move {
            if path.ends_with("planSnapshot") {
                return Ok(http::Response::builder()
                    .status(200)
                    .body(Bytes::from(plan_json))
                    .unwrap());
            }
            if path.ends_with("getSegment") {
                let name = query
                    .split('&')
                    .find_map(|p| p.strip_prefix("name="))
                    .unwrap_or("")
                    .to_owned();
                requested.lock().await.push(name.clone());
                if name == "seg0" {
                    while !gate_seg0.load(std::sync::atomic::Ordering::SeqCst) {
                        petrel::rt::sleep(Duration::from_millis(2)).await;
                    }
                }
                let body = segments.get(&name).cloned().unwrap_or_default();
                return Ok(http::Response::builder()
                    .status(200)
                    .body(Bytes::from(body))
                    .unwrap());
            }
            Ok(http::Response::builder()
                .status(404)
                .body(Bytes::new())
                .unwrap())
        })
    }
}

#[async_test]
async fn snapshot_backfill_bounds_completed_buffer_when_earliest_unit_is_slow() {
    let mut plan_segments = Vec::new();
    let mut seg_bytes = BTreeMap::new();
    for i in 0..8usize {
        let name = format!("seg{i}");
        let seq = i64::try_from(i).unwrap() + 1;
        plan_segments.push(SnapshotPlanSegment {
            name: name.clone(),
            index: i,
            checksum: "sha".to_owned(),
            min_seq: seq,
            max_seq: seq,
            mode: "segment".to_owned(),
            blocks: None,
        });
        let raw = encode_columnar_block(&[SegmentEvent {
            seq,
            witnessed_at_us: 1_000_000,
            indexed_at_us: 1_000_000,
            kind: 1,
            collection: "app.bsky.feed.post".to_owned(),
            did: "did:plc:alice".to_owned(),
            rkey: format!("rk{i}"),
            rev: format!("rev{i}"),
            payload: Vec::new(),
        }]);
        seg_bytes.insert(name, encode_jss_segment(&[raw]));
    }
    let plan = SnapshotPlan {
        sealed_tip_seq: 8,
        planned_through_seq: 8,
        segments: plan_segments,
        stats: SnapshotPlanStats {
            segments_examined: 8,
            segments_matched: 8,
            blocks_matched: 8,
            entries: 8,
        },
    };
    let gate_seg0 = Arc::new(std::sync::atomic::AtomicBool::new(false));
    let requested = Arc::new(Mutex::new(Vec::new()));
    let http = Arc::new(WindowTestTransport {
        plan_json: serde_json::to_vec(&plan).unwrap(),
        segments: seg_bytes,
        gate_seg0: Arc::clone(&gate_seg0),
        requested: Arc::clone(&requested),
    });

    let mut cfg = JetstreamClientConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg.mode = JetstreamMode::SnapshotOnly {
        after_seq: 0,
        before_seq: Some(8),
    };
    cfg.download_concurrency = 2;
    cfg.transport = http;

    let mut stream = JetstreamClient::new(cfg).events();
    petrel::rt::sleep(Duration::from_millis(25)).await;
    {
        let reqs = requested.lock().await;
        // With download_concurrency = 2 (window = 4) and seg0 blocked, seg4..seg7 must NOT be requested yet.
        assert!(
            reqs.len() <= 4,
            "expected sliding window <= 4 downloads while seg0 blocked, got {reqs:?}"
        );
    }

    gate_seg0.store(true, std::sync::atomic::Ordering::SeqCst);
    let mut seqs = Vec::new();
    while let Some(item) = stream.next().await {
        for ev in item.unwrap().events {
            seqs.push(ev.seq().unwrap());
        }
    }
    assert_eq!(seqs, vec![1, 2, 3, 4, 5, 6, 7, 8]);
}

#[derive(Debug)]
struct IdleWsSession {
    closed: Arc<std::sync::atomic::AtomicBool>,
}

impl FirehoseWebSocketSession for IdleWsSession {
    fn receive_message(&self) -> BoxFuture<'_, Result<Vec<u8>, FirehoseSubscriptionError>> {
        Box::pin(async {
            petrel::rt::sleep(Duration::from_secs(60)).await;
            Err(FirehoseSubscriptionError::ConnectionClosed)
        })
    }

    fn close(&self) -> BoxFuture<'_, ()> {
        let closed = Arc::clone(&self.closed);
        Box::pin(async move {
            closed.store(true, std::sync::atomic::Ordering::SeqCst);
        })
    }
}

#[derive(Debug)]
struct IdleWsFactory {
    opened: Arc<std::sync::atomic::AtomicBool>,
    closed: Arc<std::sync::atomic::AtomicBool>,
}

impl FirehoseWebSocketSessionFactory for IdleWsFactory {
    fn make_session(
        &self,
        _url: Url,
    ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>> {
        let opened = Arc::clone(&self.opened);
        let closed = Arc::clone(&self.closed);
        Box::pin(async move {
            opened.store(true, std::sync::atomic::Ordering::SeqCst);
            Ok(Box::new(IdleWsSession { closed }) as Box<dyn FirehoseWebSocketSession>)
        })
    }
}

#[async_test]
async fn dropping_client_stream_immediately_wakes_and_closes_idle_live_session() {
    let opened = Arc::new(std::sync::atomic::AtomicBool::new(false));
    let closed = Arc::new(std::sync::atomic::AtomicBool::new(false));
    let mut cfg = JetstreamClientConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg.mode = JetstreamMode::Live { cursor: None };
    cfg.session_factory = Arc::new(IdleWsFactory {
        opened: Arc::clone(&opened),
        closed: Arc::clone(&closed),
    });

    let stream = JetstreamClient::new(cfg).events();
    for _ in 0..50 {
        if opened.load(std::sync::atomic::Ordering::SeqCst) {
            break;
        }
        petrel::rt::sleep(Duration::from_millis(2)).await;
    }
    assert!(opened.load(std::sync::atomic::Ordering::SeqCst));
    assert!(!closed.load(std::sync::atomic::Ordering::SeqCst));

    drop(stream);
    for _ in 0..50 {
        if closed.load(std::sync::atomic::Ordering::SeqCst) {
            break;
        }
        petrel::rt::sleep(Duration::from_millis(2)).await;
    }
    assert!(closed.load(std::sync::atomic::Ordering::SeqCst));
}

#[derive(Debug)]
struct FailingLoadCursorStorage;

impl FirehoseCursorStorage for FailingLoadCursorStorage {
    fn load_cursor(&self) -> BoxFuture<'_, Result<Option<i64>, FirehoseSubscriptionError>> {
        Box::pin(async { Err(FirehoseSubscriptionError::StorageFailure) })
    }

    fn save_cursor(&self, _cursor: i64) -> BoxFuture<'_, Result<(), FirehoseSubscriptionError>> {
        Box::pin(async { Ok(()) })
    }
}

#[async_test]
async fn live_client_propagates_cursor_storage_load_error_instead_of_connecting_at_tip() {
    let opened = Arc::new(std::sync::atomic::AtomicBool::new(false));
    let closed = Arc::new(std::sync::atomic::AtomicBool::new(false));
    let mut cfg = JetstreamClientConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg.mode = JetstreamMode::Live { cursor: None };
    cfg.cursor_storage = Some(Arc::new(FailingLoadCursorStorage));
    cfg.session_factory = Arc::new(IdleWsFactory {
        opened: Arc::clone(&opened),
        closed,
    });

    let mut stream = JetstreamClient::new(cfg).events();
    let item = stream.next().await.expect("expected error item");
    assert!(matches!(
        item,
        Err(JetstreamClientError::Subscription(
            JetstreamSubscriptionError::CursorStorageFailure {
                operation: CursorStorageOperation::Load,
                ..
            }
        ))
    ));
    assert!(
        !opened.load(std::sync::atomic::Ordering::SeqCst),
        "must not connect at live tip when durable cursor load fails"
    );
}

#[derive(Debug)]
struct FailingSaveCursorStorage {
    saved: Arc<Mutex<Vec<i64>>>,
}

impl FirehoseCursorStorage for FailingSaveCursorStorage {
    fn load_cursor(&self) -> BoxFuture<'_, Result<Option<i64>, FirehoseSubscriptionError>> {
        Box::pin(async { Ok(None) })
    }

    fn save_cursor(&self, _cursor: i64) -> BoxFuture<'_, Result<(), FirehoseSubscriptionError>> {
        Box::pin(async { Err(FirehoseSubscriptionError::StorageFailure) })
    }
}

#[async_test]
async fn client_propagates_cursor_storage_save_failure_without_advancing_saved_cursor() {
    let frame1 = serde_json::to_vec(&json!({
        "$type": "message",
        "payload": {
            "$type": "network.bsky.jetstream.subscribeEvents#commit",
            "seq": 10, "did": "did:plc:alice", "time": "2026-01-01T00:00:00Z",
            "rev": "3k7v2abc23456", "operation": "create", "collection": "app.bsky.feed.post", "rkey": "r10"
        }
    }))
    .unwrap();
    let frame2 = serde_json::to_vec(&json!({
        "$type": "message",
        "payload": {
            "$type": "network.bsky.jetstream.subscribeEvents#commit",
            "seq": 11, "did": "did:plc:alice", "time": "2026-01-01T00:00:01Z",
            "rev": "3k7v2abc23457", "operation": "create", "collection": "app.bsky.feed.post", "rkey": "r11"
        }
    }))
    .unwrap();
    let ws = Arc::new(MockWsSession {
        frames: Mutex::new(VecDeque::from(vec![Ok(frame1), Ok(frame2)])),
    });
    let mut cfg = JetstreamClientConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg.mode = JetstreamMode::Live { cursor: None };
    let storage = Arc::new(FailingSaveCursorStorage {
        saved: Arc::new(Mutex::new(Vec::new())),
    });
    cfg.cursor_storage = Some(storage.clone());
    cfg.session_factory = Arc::new(MockWsFactory {
        outcomes: Mutex::new(VecDeque::from(vec![Ok(ws)])),
        urls: Mutex::new(Vec::new()),
    });

    let mut stream = JetstreamClient::new(cfg).events();
    let first = stream.next().await.unwrap().unwrap();
    assert_eq!(first.last_cursor, 10);

    // Asking for the second batch triggers checkpoint save for batch 1, which must propagate!
    let second = stream.next().await.expect("expected save failure");
    assert!(matches!(
        second,
        Err(JetstreamClientError::Subscription(
            JetstreamSubscriptionError::CursorStorageFailure {
                operation: CursorStorageOperation::Save,
                ..
            }
        ))
    ));
    assert!(storage.saved.lock().await.is_empty());
}

#[derive(Debug)]
struct LimitEnforcingDynTransport {
    observed_options: Arc<Mutex<Vec<petrel::net::SendOptions>>>,
    payload: Bytes,
}

impl petrel::net::DynHttpTransport for LimitEnforcingDynTransport {
    fn send_dyn<'a>(
        &'a self,
        _request: http::Request<Bytes>,
        options: &'a petrel::net::SendOptions,
    ) -> BoxFuture<'a, Result<http::Response<Bytes>, TransportError>> {
        let observed = Arc::clone(&self.observed_options);
        let payload = self.payload.clone();
        let opts = options.clone();
        Box::pin(async move {
            observed.lock().await.push(opts.clone());
            let limit = opts.max_response_bytes.unwrap_or(10 * 1024 * 1024);
            if payload.len() as u64 > limit {
                return Err(TransportError::ResponseTooLarge { limit });
            }
            Ok(http::Response::builder().status(200).body(payload).unwrap())
        })
    }
}

#[async_test]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
async fn petrel_jetstream_http_transport_propagates_archive_limit_for_large_segments() {
    let observed = Arc::new(Mutex::new(Vec::new()));
    let large_body = Bytes::from(vec![0x55_u8; 11 * 1024 * 1024]);
    let dyn_transport = Arc::new(LimitEnforcingDynTransport {
        observed_options: Arc::clone(&observed),
        payload: large_body.clone(),
    });
    let transport = Arc::new(petrel_jetstream::PetrelJetstreamHttpTransport::new(
        dyn_transport,
    ));
    let client = petrel_jetstream::JetstreamXrpcClient::new(
        Url::parse("http://127.0.0.1:9999").unwrap(),
        transport,
        None,
    );

    let got = client
        .get_segment("seg-large")
        .await
        .expect(">10 MiB segment download must use archive limit");
    assert_eq!(got.len(), large_body.len());

    let opts = observed.lock().await;
    assert_eq!(opts.len(), 1);
    assert!(opts[0].allow_loopback);
    assert_eq!(
        opts[0].max_response_bytes,
        Some(petrel_jetstream::DEFAULT_MAX_SEGMENT_BYTES)
    );
    assert!(opts[0].timeout.is_some());
}

#[cfg_attr(target_arch = "wasm32", async_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn segment_block_decodes_record_payload_with_over_10000_cbor_values() {
    let items: Vec<Value> = (0..10_500_i64).map(Value::Integer).collect();
    let payload = dagcbor::encode(&Value::Object(BTreeMap::from([
        (
            "$type".to_owned(),
            Value::String("app.bsky.feed.post".to_owned()),
        ),
        ("items".to_owned(), Value::Array(items)),
    ])));
    assert!(payload.len() < 1_000_000);
    assert!(dagcbor::decode(&payload).is_err());

    let ev = SegmentEvent {
        seq: 42,
        witnessed_at_us: 1_000_000,
        indexed_at_us: 2_000_000,
        kind: 1,
        collection: "app.bsky.feed.post".to_owned(),
        did: "did:plc:largecbor".to_owned(),
        rkey: "3k7large00001".to_owned(),
        rev: "3k7v2abc23456".to_owned(),
        payload,
    };

    let raw_blk = encode_columnar_block(&[ev]);
    let frame = JetstreamZstd::compress(&raw_blk).unwrap();
    let decoded = SegmentBlockDecoder::decode_frame(&frame).unwrap();
    assert_eq!(decoded.len(), 1);

    let JetstreamEvent::Commit(commit) = decoded[0].to_jetstream_event().unwrap() else {
        panic!("expected commit event");
    };
    let record_json = commit
        .record_json
        .as_ref()
        .expect("segment record payload with >10,000 CBOR values must decode record_json");
    let parsed: serde_json::Value = serde_json::from_slice(record_json).unwrap();
    assert_eq!(
        parsed
            .get("items")
            .and_then(serde_json::Value::as_array)
            .map(Vec::len),
        Some(10_500)
    );
}

#[async_test]
#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
async fn snapshot_plan_rejects_inverted_block_range_and_chunks_large_range() {
    use petrel_jetstream::JetstreamHttpError;

    // 1. Inverted block range (first > last) must return Http(Decode(_)) cleanly.
    let bad_http = Arc::new(MockHttpTransport {
        handler: Arc::new(|_req| {
            let plan = SnapshotPlan {
                planned_through_seq: 10,
                sealed_tip_seq: 10,
                segments: vec![SnapshotPlanSegment {
                    name: "seg-bad".to_owned(),
                    index: 0,
                    checksum: "sha".to_owned(),
                    min_seq: 1,
                    max_seq: 10,
                    mode: "blocks".to_owned(),
                    blocks: Some(vec![SnapshotBlockRange { first: 5, last: 2 }]),
                }],
                stats: SnapshotPlanStats {
                    segments_examined: 1,
                    segments_matched: 1,
                    blocks_matched: 1,
                    entries: 1,
                },
            };
            Ok(http::Response::builder()
                .status(200)
                .body(Bytes::from(serde_json::to_vec(&plan).unwrap()))
                .unwrap())
        }),
    });
    let mut cfg = JetstreamClientConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg.mode = JetstreamMode::SnapshotOnly {
        after_seq: 0,
        before_seq: Some(10),
    };
    cfg.transport = bad_http;
    let err = JetstreamClient::new(cfg)
        .events()
        .next()
        .await
        .expect("expected error")
        .expect_err("inverted block range must fail");
    assert!(matches!(
        err,
        JetstreamClientError::Http(JetstreamHttpError::Decode(_))
    ));

    // 2. A 35-block range chunks cleanly across MAX_BLOCKS_PER_CHUNK (32) boundaries.
    let chunk_http = Arc::new(MockHttpTransport {
        handler: Arc::new(|req| {
            let path = req.uri().path();
            if path.ends_with("planSnapshot") {
                let plan = SnapshotPlan {
                    planned_through_seq: 35,
                    sealed_tip_seq: 35,
                    segments: vec![SnapshotPlanSegment {
                        name: "seg-chunked".to_owned(),
                        index: 0,
                        checksum: "sha".to_owned(),
                        min_seq: 1,
                        max_seq: 35,
                        mode: "blocks".to_owned(),
                        blocks: Some(vec![SnapshotBlockRange { first: 0, last: 34 }]),
                    }],
                    stats: SnapshotPlanStats {
                        segments_examined: 1,
                        segments_matched: 1,
                        blocks_matched: 35,
                        entries: 35,
                    },
                };
                Ok(http::Response::builder()
                    .status(200)
                    .body(Bytes::from(serde_json::to_vec(&plan).unwrap()))
                    .unwrap())
            } else {
                let idx: i64 = url::Url::parse(&format!("https://jet.example{}", req.uri()))
                    .unwrap()
                    .query_pairs()
                    .find(|(k, _)| k == "blockIndex")
                    .and_then(|(_, v)| v.parse().ok())
                    .unwrap_or(0);
                let frame = JetstreamZstd::compress(&encode_columnar_block(&[SegmentEvent {
                    seq: idx + 1,
                    witnessed_at_us: 100,
                    indexed_at_us: 100,
                    kind: 1,
                    collection: "app.bsky.feed.post".to_owned(),
                    did: "did:plc:alice".to_owned(),
                    rkey: format!("r{idx}"),
                    rev: "3k7v2abc23456".to_owned(),
                    payload: make_post_cbor("chunk"),
                }]))
                .unwrap();
                Ok(http::Response::builder()
                    .status(200)
                    .body(Bytes::from(frame))
                    .unwrap())
            }
        }),
    });
    let mut cfg2 = JetstreamClientConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg2.mode = JetstreamMode::SnapshotOnly {
        after_seq: 0,
        before_seq: Some(35),
    };
    cfg2.batch_size = 100;
    cfg2.transport = chunk_http;
    let mut stream2 = JetstreamClient::new(cfg2).events();
    let mut total = 0usize;
    while let Some(res) = stream2.next().await {
        let batch = res.unwrap();
        total += batch.events.len();
    }
    assert_eq!(total, 35);
}
