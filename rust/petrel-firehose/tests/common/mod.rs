#![allow(dead_code, unreachable_pub)]

use std::collections::{BTreeMap, VecDeque};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

use async_lock::Mutex;
use k256::ecdsa::SigningKey as K256SigningKey;
use p256::ecdsa::SigningKey as P256SigningKey;
use p256::ecdsa::signature::Signer as _;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::{Cid, Tid, Value, dagcbor};
use petrel_firehose::repo_seam::{
    CANONICAL_EMPTY_MST_CID, RepoCommitVerifier, RepositoryBlockSource, RepositoryCommitDiffError,
    RepositoryCommitError, SigningPublicKey,
};
use petrel_firehose::{
    FirehoseSubscriptionError, FirehoseWebSocketSession, FirehoseWebSocketSessionFactory,
    PublicFirehoseRepoAction, PublicFirehoseRepoOp, RelayAcceptedHeadStorage, RelayRepositoryHead,
    RelayVerifierError, RepositorySigningKeyResolver,
};
use sha2::{Digest, Sha256};
use url::Url;

pub fn encode_car(roots: &[Cid], blocks: &[(Cid, Vec<u8>)]) -> Vec<u8> {
    let mut header = BTreeMap::new();
    header.insert("version".to_owned(), Value::Integer(1));
    header.insert(
        "roots".to_owned(),
        Value::Array(roots.iter().cloned().map(Value::Link).collect()),
    );
    let header_bytes = dagcbor::encode(&Value::Object(header));

    let mut out = Vec::new();
    push_varint(&mut out, header_bytes.len());
    out.extend_from_slice(&header_bytes);

    for (cid, body) in blocks {
        let frame_len = cid.as_bytes().len() + body.len();
        push_varint(&mut out, frame_len);
        out.extend_from_slice(cid.as_bytes());
        out.extend_from_slice(body);
    }
    out
}

fn push_varint(out: &mut Vec<u8>, mut value: usize) {
    loop {
        let mut byte = u8::try_from(value & 0x7f).unwrap_or(0);
        value >>= 7;
        if value != 0 {
            byte |= 0x80;
        }
        out.push(byte);
        if value == 0 {
            break;
        }
    }
}

pub fn dag_cbor_cid(bytes: &[u8]) -> Cid {
    Cid::for_dag_cbor(bytes)
}

pub fn mst_layer(key: &[u8]) -> usize {
    let digest = Sha256::digest(key);
    let mut zeros = 0usize;
    for byte in digest {
        if byte == 0 {
            zeros += 4;
            continue;
        }
        if (byte & 0b1100_0000) == 0 {
            zeros += 1;
            if (byte & 0b0011_0000) == 0 {
                zeros += 1;
                if (byte & 0b0000_1100) == 0 {
                    zeros += 1;
                }
            }
        }
        break;
    }
    zeros
}

#[derive(Debug, Clone)]
struct TestMstEntry {
    key: Vec<u8>,
    val: Cid,
    right: Option<TestMstNode>,
}

#[derive(Debug, Clone)]
struct TestMstNode {
    left: Option<Box<TestMstNode>>,
    entries: Vec<TestMstEntry>,
}

impl TestMstNode {
    fn empty() -> Self {
        Self {
            left: None,
            entries: Vec::new(),
        }
    }

    fn insert(self, key: Vec<u8>, val: Cid) -> Self {
        let mut items: BTreeMap<Vec<u8>, Cid> = BTreeMap::new();
        self.collect(&mut items);
        items.insert(key, val);
        Self::from_sorted(&items.into_iter().collect::<Vec<_>>())
    }

    fn delete(self, key: &[u8]) -> Self {
        let mut items: BTreeMap<Vec<u8>, Cid> = BTreeMap::new();
        self.collect(&mut items);
        items.remove(key);
        Self::from_sorted(&items.into_iter().collect::<Vec<_>>())
    }

    fn collect(&self, out: &mut BTreeMap<Vec<u8>, Cid>) {
        if let Some(l) = &self.left {
            l.collect(out);
        }
        for e in &self.entries {
            out.insert(e.key.clone(), e.val.clone());
            if let Some(r) = &e.right {
                r.collect(out);
            }
        }
    }

    pub fn build(entries: &BTreeMap<String, Cid>) -> Self {
        let vec: Vec<(Vec<u8>, Cid)> = entries
            .iter()
            .map(|(k, v)| (k.as_bytes().to_vec(), v.clone()))
            .collect();
        Self::from_sorted(&vec)
    }

    fn from_sorted(sorted: &[(Vec<u8>, Cid)]) -> Self {
        if sorted.is_empty() {
            return Self::empty();
        }
        let max_layer = sorted.iter().map(|(k, _)| mst_layer(k)).max().unwrap_or(0);
        Self::build_at_layer(sorted, max_layer)
    }

    fn build_at_layer(slice: &[(Vec<u8>, Cid)], layer: usize) -> Self {
        if slice.is_empty() {
            return Self::empty();
        }
        let indices: Vec<usize> = slice
            .iter()
            .enumerate()
            .filter(|(_, (k, _))| mst_layer(k) == layer)
            .map(|(i, _)| i)
            .collect();
        if indices.is_empty() {
            if layer == 0 {
                return Self::empty();
            }
            let child = Self::build_at_layer(slice, layer - 1);
            return Self {
                left: Some(Box::new(child)),
                entries: Vec::new(),
            };
        }

        let first = indices[0];
        let left = if first > 0 && layer > 0 {
            Some(Box::new(Self::build_at_layer(&slice[..first], layer - 1)))
        } else {
            None
        };

        let mut entries = Vec::with_capacity(indices.len());
        for (pos, &idx) in indices.iter().enumerate() {
            let end = if pos + 1 < indices.len() {
                indices[pos + 1]
            } else {
                slice.len()
            };
            let right_slice = &slice[idx + 1..end];
            let right = if !right_slice.is_empty() && layer > 0 {
                Some(Self::build_at_layer(right_slice, layer - 1))
            } else {
                None
            };
            entries.push(TestMstEntry {
                key: slice[idx].0.clone(),
                val: slice[idx].1.clone(),
                right,
            });
        }
        Self { left, entries }
    }

    fn encode_blocks(&self, out: &mut BTreeMap<Cid, Vec<u8>>) -> Cid {
        let l_val = match &self.left {
            Some(l) => Value::Link(l.encode_blocks(out)),
            None => Value::Null,
        };
        let mut prev: &[u8] = &[];
        let mut e_vals = Vec::with_capacity(self.entries.len());
        for entry in &self.entries {
            let mut shared = 0usize;
            while shared < prev.len()
                && shared < entry.key.len()
                && prev[shared] == entry.key[shared]
            {
                shared += 1;
            }
            let t_val = match &entry.right {
                Some(r) => Value::Link(r.encode_blocks(out)),
                None => Value::Null,
            };
            let mut emap = BTreeMap::new();
            emap.insert(
                "p".to_owned(),
                Value::Integer(i64::try_from(shared).unwrap_or(i64::MAX)),
            );
            emap.insert("k".to_owned(), Value::Bytes(entry.key[shared..].to_vec()));
            emap.insert("v".to_owned(), Value::Link(entry.val.clone()));
            emap.insert("t".to_owned(), t_val);
            e_vals.push(Value::Object(emap));
            prev = &entry.key;
        }
        let mut node_map = BTreeMap::new();
        node_map.insert("l".to_owned(), l_val);
        node_map.insert("e".to_owned(), Value::Array(e_vals));
        let bytes = dagcbor::encode(&Value::Object(node_map));
        let cid = dag_cbor_cid(&bytes);
        out.insert(cid.clone(), bytes);
        cid
    }
}

pub fn build_mst_blocks(entries: &BTreeMap<String, Cid>) -> (Cid, BTreeMap<Cid, Vec<u8>>) {
    let mut blocks = BTreeMap::new();
    let root = TestMstNode::build(entries).encode_blocks(&mut blocks);
    (root, blocks)
}

#[derive(Debug, Default)]
pub struct MapBlockSource {
    pub blocks: BTreeMap<Cid, Vec<u8>>,
}

impl RepositoryBlockSource for MapBlockSource {
    fn block<'a>(
        &'a self,
        cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, RepositoryCommitDiffError>> {
        let found = self.blocks.get(cid).cloned();
        Box::pin(async move { Ok(found) })
    }
}

#[derive(Debug, Clone)]
pub enum TestSigningKey {
    P256(P256SigningKey),
    K256(K256SigningKey),
}

impl TestSigningKey {
    pub fn p256_deterministic(seed: u8) -> Self {
        let mut bytes = [0u8; 32];
        bytes[31] = seed.max(1);
        Self::P256(P256SigningKey::from_bytes(&bytes.into()).expect("valid P-256 key"))
    }

    pub fn k256_deterministic(seed: u8) -> Self {
        let mut bytes = [0u8; 32];
        bytes[31] = seed.max(1);
        Self::K256(K256SigningKey::from_bytes(&bytes.into()).expect("valid K-256 key"))
    }

    pub fn public_key(&self) -> SigningPublicKey {
        match self {
            Self::P256(sk) => SigningPublicKey::P256(*sk.verifying_key()),
            Self::K256(sk) => SigningPublicKey::K256(*sk.verifying_key()),
        }
    }

    pub fn sign(&self, message: &[u8]) -> Vec<u8> {
        match self {
            Self::P256(sk) => {
                let sig: p256::ecdsa::Signature = sk.sign(message);
                sig.normalize_s().unwrap_or(sig).to_bytes().to_vec()
            }
            Self::K256(sk) => {
                let sig: k256::ecdsa::Signature = sk.sign(message);
                sig.normalize_s().unwrap_or(sig).to_bytes().to_vec()
            }
        }
    }
}

#[derive(Debug)]
pub struct TestKeyResolver {
    pub keys: Mutex<BTreeMap<String, SigningPublicKey>>,
}

impl TestKeyResolver {
    pub fn new() -> Self {
        Self {
            keys: Mutex::new(BTreeMap::new()),
        }
    }

    pub async fn insert(&self, did: impl Into<String>, key: SigningPublicKey) {
        self.keys.lock().await.insert(did.into(), key);
    }
}

impl RepositorySigningKeyResolver for TestKeyResolver {
    fn resolve_signing_key<'a>(
        &'a self,
        did: &'a str,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<Box<dyn RepoCommitVerifier>, RepositoryCommitError>> {
        Box::pin(async move {
            let key = self
                .keys
                .lock()
                .await
                .get(did)
                .cloned()
                .ok_or_else(|| RepositoryCommitError::KeyResolution(did.to_owned()))?;
            Ok(Box::new(key) as Box<dyn RepoCommitVerifier>)
        })
    }
}

pub struct BuiltCommit {
    pub rev: String,
    pub since: Option<String>,
    pub commit_cid: Cid,
    pub data_cid: Cid,
    pub prev_data_cid: Option<Cid>,
    pub diff_car: Vec<u8>,
    pub full_car: Vec<u8>,
    pub ops: Vec<PublicFirehoseRepoOp>,
    pub all_blocks: BTreeMap<Cid, Vec<u8>>,
}

pub struct TestRepoState {
    pub did: String,
    pub key: TestSigningKey,
    pub records: BTreeMap<String, (Cid, Vec<u8>)>,
    pub prev_commit: Option<Cid>,
    pub prev_data: Option<Cid>,
    pub prev_rev: Option<String>,
    pub prev_blocks: BTreeMap<Cid, Vec<u8>>,
    rev_counter: u64,
}

impl TestRepoState {
    pub fn new(did: impl Into<String>, key: TestSigningKey) -> Self {
        Self {
            did: did.into(),
            key,
            records: BTreeMap::new(),
            prev_commit: None,
            prev_data: None,
            prev_rev: None,
            prev_blocks: BTreeMap::new(),
            rev_counter: 1000,
        }
    }

    pub fn make_record_bytes(text: &str) -> (Cid, Vec<u8>) {
        let mut map = BTreeMap::new();
        map.insert(
            "$type".to_owned(),
            Value::String("app.bsky.feed.post".to_owned()),
        );
        map.insert("text".to_owned(), Value::String(text.to_owned()));
        let bytes = dagcbor::encode(&Value::Object(map));
        let cid = dag_cbor_cid(&bytes);
        (cid, bytes)
    }

    #[allow(clippy::type_complexity, clippy::too_many_lines)]
    pub fn commit(&mut self, mutations: &[(&str, Option<(&str, Vec<u8>)>)]) -> BuiltCommit {
        self.rev_counter += 1;
        let rev = Tid::from_parts(self.rev_counter * 1000, 0)
            .expect("valid tid")
            .to_string();
        let since = self.prev_rev.clone();
        let prev_data_cid = self.prev_data.clone();

        let mut ops = Vec::new();
        let mut new_record_blocks = Vec::new();
        for (path, next) in mutations {
            let old_cid = self.records.get(*path).map(|(c, _)| c.clone());
            match (old_cid, next) {
                (None, Some((text, raw))) => {
                    let (cid, bytes) = if raw.is_empty() {
                        Self::make_record_bytes(text)
                    } else {
                        (dag_cbor_cid(raw), raw.clone())
                    };
                    self.records
                        .insert((*path).to_owned(), (cid.clone(), bytes.clone()));
                    new_record_blocks.push((cid.clone(), bytes));
                    ops.push(PublicFirehoseRepoOp {
                        action: PublicFirehoseRepoAction::Create,
                        path: (*path).to_owned(),
                        cid: Some(cid.to_string()),
                        prev: None,
                    });
                }
                (Some(prev_cid), Some((text, raw))) => {
                    let (cid, bytes) = if raw.is_empty() {
                        Self::make_record_bytes(text)
                    } else {
                        (dag_cbor_cid(raw), raw.clone())
                    };
                    self.records
                        .insert((*path).to_owned(), (cid.clone(), bytes.clone()));
                    new_record_blocks.push((cid.clone(), bytes));
                    ops.push(PublicFirehoseRepoOp {
                        action: PublicFirehoseRepoAction::Update,
                        path: (*path).to_owned(),
                        cid: Some(cid.to_string()),
                        prev: Some(prev_cid.to_string()),
                    });
                }
                (Some(prev_cid), None) => {
                    self.records.remove(*path);
                    ops.push(PublicFirehoseRepoOp {
                        action: PublicFirehoseRepoAction::Delete,
                        path: (*path).to_owned(),
                        cid: None,
                        prev: Some(prev_cid.to_string()),
                    });
                }
                (None, None) => panic!("cannot delete non-existent path {path}"),
            }
        }

        let mst_map: BTreeMap<String, Cid> = self
            .records
            .iter()
            .map(|(k, (c, _))| (k.clone(), c.clone()))
            .collect();
        let (data_cid, new_mst_blocks) = build_mst_blocks(&mst_map);

        let mut unsigned_commit = BTreeMap::new();
        unsigned_commit.insert("did".to_owned(), Value::String(self.did.clone()));
        unsigned_commit.insert("version".to_owned(), Value::Integer(3));
        unsigned_commit.insert("data".to_owned(), Value::Link(data_cid.clone()));
        unsigned_commit.insert("rev".to_owned(), Value::String(rev.clone()));
        unsigned_commit.insert(
            "prev".to_owned(),
            match &self.prev_commit {
                Some(p) => Value::Link(p.clone()),
                None => Value::Null,
            },
        );
        let unsigned_bytes = dagcbor::encode(&Value::Object(unsigned_commit.clone()));
        let sig = self.key.sign(&unsigned_bytes);
        unsigned_commit.insert("sig".to_owned(), Value::Bytes(sig));
        let commit_bytes = dagcbor::encode(&Value::Object(unsigned_commit));
        let commit_cid = dag_cbor_cid(&commit_bytes);

        let mut diff_blocks = vec![(commit_cid.clone(), commit_bytes.clone())];
        for (cid, bytes) in &new_mst_blocks {
            if !self.prev_blocks.contains_key(cid) || *cid == data_cid {
                diff_blocks.push((cid.clone(), bytes.clone()));
            }
        }
        // Include empty canonical MST block when empty so lazy verifier can load root if needed.
        if mst_map.is_empty() {
            let empty_cid: Cid = CANONICAL_EMPTY_MST_CID.parse().expect("valid empty mst");
            if let Some(empty_bytes) = new_mst_blocks.get(&empty_cid)
                && !diff_blocks.iter().any(|(c, _)| c == &empty_cid)
            {
                diff_blocks.push((empty_cid, empty_bytes.clone()));
            }
        }
        for (cid, bytes) in &new_record_blocks {
            diff_blocks.push((cid.clone(), bytes.clone()));
        }

        let mut full_blocks: BTreeMap<Cid, Vec<u8>> = new_mst_blocks.clone();
        for (cid, bytes) in self.records.values() {
            full_blocks.insert(cid.clone(), bytes.clone());
        }
        full_blocks.insert(commit_cid.clone(), commit_bytes.clone());

        let diff_car = encode_car(std::slice::from_ref(&commit_cid), &diff_blocks);
        let full_vec: Vec<(Cid, Vec<u8>)> = full_blocks
            .iter()
            .map(|(k, v)| (k.clone(), v.clone()))
            .collect();
        let full_car = encode_car(std::slice::from_ref(&commit_cid), &full_vec);

        self.prev_commit = Some(commit_cid.clone());
        self.prev_data = Some(data_cid.clone());
        self.prev_rev = Some(rev.clone());
        self.prev_blocks = new_mst_blocks;

        BuiltCommit {
            rev,
            since,
            commit_cid,
            data_cid,
            prev_data_cid,
            diff_car,
            full_car,
            ops,
            all_blocks: full_blocks,
        }
    }
}

#[derive(Debug, Default)]
pub struct FailingHeadStorage {
    pub fail_save: AtomicBool,
    pub heads: Mutex<BTreeMap<String, RelayRepositoryHead>>,
}

impl RelayAcceptedHeadStorage for FailingHeadStorage {
    fn load_accepted_head<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Option<RelayRepositoryHead>, RelayVerifierError>> {
        Box::pin(async move { Ok(self.heads.lock().await.get(did).cloned()) })
    }

    fn save_accepted_head(
        &self,
        head: RelayRepositoryHead,
    ) -> BoxFuture<'_, Result<(), RelayVerifierError>> {
        Box::pin(async move {
            if self.fail_save.load(Ordering::SeqCst) {
                return Err(RelayVerifierError::StorageFailure);
            }
            self.heads.lock().await.insert(head.did.clone(), head);
            Ok(())
        })
    }
}

// --- Scripted WebSocket Factory (cross-platform: works on native + wasm32) ---

pub type ScriptAction = Result<Vec<u8>, FirehoseSubscriptionError>;

#[derive(Debug)]
pub struct ScriptedSession {
    actions: Mutex<VecDeque<ScriptAction>>,
    pub received_count: AtomicUsize,
    pub closed: AtomicBool,
    pub sent_texts: Mutex<Vec<String>>,
}

impl ScriptedSession {
    pub fn from_actions(actions: Vec<ScriptAction>) -> Self {
        Self {
            actions: Mutex::new(VecDeque::from(actions)),
            received_count: AtomicUsize::new(0),
            closed: AtomicBool::new(false),
            sent_texts: Mutex::new(Vec::new()),
        }
    }
}

impl FirehoseWebSocketSession for ScriptedSession {
    fn receive_message(&self) -> BoxFuture<'_, Result<Vec<u8>, FirehoseSubscriptionError>> {
        Box::pin(async move {
            if self.closed.load(Ordering::SeqCst) {
                return Err(FirehoseSubscriptionError::ConnectionClosed);
            }
            let next = self.actions.lock().await.pop_front();
            match next {
                Some(Ok(bytes)) => {
                    self.received_count.fetch_add(1, Ordering::SeqCst);
                    Ok(bytes)
                }
                Some(Err(err)) => Err(err),
                None => Err(FirehoseSubscriptionError::ConnectionClosed),
            }
        })
    }

    fn close(&self) -> BoxFuture<'_, ()> {
        Box::pin(async move {
            self.closed.store(true, Ordering::SeqCst);
        })
    }

    fn send_text<'a>(
        &'a self,
        text: &'a str,
    ) -> BoxFuture<'a, Result<(), FirehoseSubscriptionError>> {
        Box::pin(async move {
            self.sent_texts.lock().await.push(text.to_owned());
            Ok(())
        })
    }
}

pub type OpenOutcome = Result<Arc<ScriptedSession>, FirehoseSubscriptionError>;

#[derive(Debug)]
pub struct ScriptedWebSocketFactory {
    outcomes: Mutex<VecDeque<OpenOutcome>>,
    pub requested_urls: Mutex<Vec<Url>>,
    pub offered_subprotocols: Mutex<Vec<Vec<String>>>,
}

impl ScriptedWebSocketFactory {
    pub fn new(outcomes: Vec<OpenOutcome>) -> Self {
        Self {
            outcomes: Mutex::new(VecDeque::from(outcomes)),
            requested_urls: Mutex::new(Vec::new()),
            offered_subprotocols: Mutex::new(Vec::new()),
        }
    }
}

impl FirehoseWebSocketSessionFactory for ScriptedWebSocketFactory {
    fn make_session(
        &self,
        url: Url,
    ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>> {
        self.make_session_with_subprotocols(url, Vec::new())
    }

    fn make_session_with_subprotocols(
        &self,
        url: Url,
        subprotocols: Vec<String>,
    ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>> {
        Box::pin(async move {
            self.requested_urls.lock().await.push(url);
            self.offered_subprotocols.lock().await.push(subprotocols);
            let outcome = self
                .outcomes
                .lock()
                .await
                .pop_front()
                .unwrap_or(Err(FirehoseSubscriptionError::ConnectionClosed));
            outcome.map(|arc| Box::new(ArcSessionWrapper(arc)) as Box<dyn FirehoseWebSocketSession>)
        })
    }
}

#[derive(Debug)]
struct ArcSessionWrapper(Arc<ScriptedSession>);

impl FirehoseWebSocketSession for ArcSessionWrapper {
    fn receive_message(&self) -> BoxFuture<'_, Result<Vec<u8>, FirehoseSubscriptionError>> {
        self.0.receive_message()
    }

    fn close(&self) -> BoxFuture<'_, ()> {
        self.0.close()
    }

    fn send_text<'a>(
        &'a self,
        text: &'a str,
    ) -> BoxFuture<'a, Result<(), FirehoseSubscriptionError>> {
        self.0.send_text(text)
    }
}

pub fn make_test_wrapper<T: MaybeSend + MaybeSync>(v: T) -> T {
    v
}
