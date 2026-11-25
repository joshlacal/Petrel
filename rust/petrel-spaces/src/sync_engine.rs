//! Verified Space client sync engine: writer enumeration, MAC-authenticated commit/record/STAR fetching,
//! incremental op application, and KEM-key-rotation single-retry recovery.

use std::collections::{BTreeMap, HashSet};
use std::sync::Arc;

use bytes::Bytes;
use http::{HeaderMap, Method, StatusCode};
use petrel::net::{RedirectPolicy, SendOptions, SharedTransport, send_with_redirects};
use petrel_api::generated::com::atproto::space::{
    defs::{Commit, RepoWrite},
    get_latest_commit::{NSID as GET_LATEST_COMMIT_NSID, Output as GetLatestCommitOutput},
    get_record::{NSID as GET_RECORD_NSID, Output as GetRecordOutput},
    get_repo::NSID as GET_REPO_NSID,
    list_repo_ops::{NSID as LIST_REPO_OPS_NSID, OpEntry, Output as ListRepoOpsOutput},
    list_writers::{NSID as LIST_WRITERS_NSID, Output as ListWritersOutput, OutputRepos},
};
use petrel_core::{Cid, Did, Nsid, RecordKey, SpaceRef, Tid, to_dag_cbor};
use petrel_crypto::SpaceSetHash;
use serde::Deserialize;
use url::Url;

use crate::credential_manager::{CredentialExchanger, SpaceCredentialManager};
use crate::error::{Result, SpaceError, parse_space_ref};
use crate::http_signature::{derive_audience, sign_credential_request};
use crate::kem::encapsulate_p256;
use crate::mac_header::{
    MacProfile, VerifiedCommitMac, VerifiedRecordMac, format_accept_signature, verify_commit_mac,
    verify_record_mac,
};
use crate::resolver::SpaceHostResolver;
use crate::star::{StarRepo, read_star_repo_authenticated, verify_record_cid};

/// Maximum `listWriters` pagination rounds before failing with an error to avoid infinite loops.
const MAX_LIST_PAGES: usize = 1000;

/// Verified active writer state collected from `com.atproto.space.listWriters`.
#[derive(Debug, Clone, PartialEq)]
pub struct ActiveWriterSet {
    pub active: Vec<RepoWrite>,
    pub removed: Vec<Did>,
    pub latest_space_rev: Option<Tid>,
}

/// Verified `getLatestCommit` response paired with its MAC verification result.
#[derive(Debug, Clone)]
pub struct VerifiedLatestCommit {
    pub commit: Commit,
    pub mac: VerifiedCommitMac,
}

/// Verified `getRecord` response paired with canonical DAG-CBOR bytes and MAC verification.
#[derive(Debug, Clone)]
pub struct VerifiedSpaceRecord {
    pub output: GetRecordOutput,
    pub cid: Cid,
    pub cbor: Vec<u8>,
    pub mac: VerifiedRecordMac,
}

/// Result of a verified incremental `listRepoOps` sync for a single writer repo.
#[derive(Debug, Clone)]
pub struct SyncedWriterOps {
    pub commit: Commit,
    pub ops: Vec<OpEntry>,
    pub set_hash_digest: [u8; 32],
}

/// Verified ATProto Space sync client coordinating `SpaceCredentialManager`, `SpaceHostResolver`,
/// RFC 9421 credential presentation, HPKE `Accept-Signature` MACs, and `SpaceSTAR` verification.
pub struct SpaceSyncEngine<E: CredentialExchanger> {
    transport: SharedTransport,
    credentials: Arc<SpaceCredentialManager<E>>,
    resolver: Arc<SpaceHostResolver>,
}

impl<E: CredentialExchanger + core::fmt::Debug> core::fmt::Debug for SpaceSyncEngine<E> {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("SpaceSyncEngine")
            .field("credentials", &self.credentials)
            .field("resolver", &self.resolver)
            .finish_non_exhaustive()
    }
}

impl<E: CredentialExchanger> SpaceSyncEngine<E> {
    /// Create a new `SpaceSyncEngine`.
    pub fn new(
        transport: SharedTransport,
        credentials: Arc<SpaceCredentialManager<E>>,
        resolver: Arc<SpaceHostResolver>,
    ) -> Self {
        Self {
            transport,
            credentials,
            resolver,
        }
    }

    /// Fetch a single page of `com.atproto.space.listWriters` from the space host.
    pub async fn list_writers(
        &self,
        space: &SpaceRef,
        host_url: &Url,
        host_did: Option<&Did>,
        cursor: Option<&str>,
        limit: usize,
        now_secs: i64,
    ) -> Result<ListWritersOutput> {
        let mut url = host_url.clone();
        url.set_path(&format!("/xrpc/{LIST_WRITERS_NSID}"));
        {
            let mut q = url.query_pairs_mut();
            q.clear();
            q.append_pair("space", space.as_str());
            q.append_pair("limit", &limit.clamp(1, 500).to_string());
            if let Some(c) = cursor {
                q.append_pair("cursor", c);
            }
        }
        let resp = self
            .credentials
            .send_signed_request(
                &self.transport,
                space,
                Method::GET,
                &url,
                host_did.or(Some(space.space_did())),
                &HeaderMap::new(),
                Bytes::new(),
                now_secs,
                None,
            )
            .await?;
        check_http_status(&resp)?;
        serde_json::from_slice(resp.body()).map_err(|e| SpaceError::MalformedPayload(e.to_string()))
    }

    /// Walk all `listWriters` pages since `since_space_rev` and return the net active/removed sets.
    pub async fn list_active_writers(
        &self,
        space: &SpaceRef,
        host_url: &Url,
        host_did: Option<&Did>,
        since_space_rev: Option<&Tid>,
        now_secs: i64,
    ) -> Result<ActiveWriterSet> {
        let mut cursor = since_space_rev.map(|t| t.as_str().to_owned());
        let mut active_map: BTreeMap<Did, RepoWrite> = BTreeMap::new();
        let mut removed_set: HashSet<Did> = HashSet::new();
        let mut latest_space_rev: Option<Tid> = since_space_rev.cloned();
        let mut completed = false;

        for _ in 0..MAX_LIST_PAGES {
            let page = self
                .list_writers(space, host_url, host_did, cursor.as_deref(), 100, now_secs)
                .await?;
            let empty_page = page.repos.is_empty();
            for entry in page.repos {
                match entry {
                    OutputRepos::RepoWrite(w) => {
                        if latest_space_rev
                            .as_ref()
                            .is_none_or(|cur| w.space_rev.as_str() > cur.as_str())
                        {
                            latest_space_rev = Some(w.space_rev.clone());
                        }
                        removed_set.remove(&w.repo);
                        active_map.insert(w.repo.clone(), *w);
                    }
                    OutputRepos::RepoRemoved(r) => {
                        if latest_space_rev
                            .as_ref()
                            .is_none_or(|cur| r.space_rev.as_str() > cur.as_str())
                        {
                            latest_space_rev = Some(r.space_rev.clone());
                        }
                        active_map.remove(&r.repo);
                        removed_set.insert(r.repo);
                    }
                    OutputRepos::Unknown(_) => {}
                }
            }
            match page.cursor {
                Some(next) if !empty_page && cursor.as_deref() != Some(next.as_str()) => {
                    cursor = Some(next);
                }
                _ => {
                    completed = true;
                    break;
                }
            }
        }

        if !completed {
            return Err(SpaceError::MalformedPayload(format!(
                "listWriters exceeded {MAX_LIST_PAGES} pages"
            )));
        }

        let mut removed: Vec<Did> = removed_set.into_iter().collect();
        removed.sort_by(|a, b| a.as_str().cmp(b.as_str()));
        Ok(ActiveWriterSet {
            active: active_map.into_values().collect(),
            removed,
            latest_space_rev,
        })
    }

    /// Fetch and MAC-verify `com.atproto.space.getLatestCommit` for a writer repo.
    pub async fn get_latest_commit_verified(
        &self,
        space: &SpaceRef,
        writer_did: &Did,
        pds_url: &Url,
        pds_did: Option<&Did>,
        now_secs: i64,
    ) -> Result<VerifiedLatestCommit> {
        let mut url = pds_url.clone();
        url.set_path(&format!("/xrpc/{GET_LATEST_COMMIT_NSID}"));
        {
            let mut q = url.query_pairs_mut();
            q.clear();
            q.append_pair("space", space.as_str());
            q.append_pair("repo", writer_did.as_str());
        }

        let (resp, shared_secret) = self
            .send_mac_protected_get(
                space,
                writer_did,
                &url,
                pds_did,
                MacProfile::Commit,
                None,
                now_secs,
            )
            .await?;

        let (covered, sig_input, sig) = extract_mac_headers(resp.headers(), MacProfile::Commit)?;
        let mac = verify_commit_mac(&shared_secret, covered, sig_input, sig)?;
        let out: GetLatestCommitOutput = serde_json::from_slice(resp.body())
            .map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;

        validate_commit_matches_mac(&out.commit, &mac, space, writer_did)?;
        Ok(VerifiedLatestCommit {
            commit: out.commit,
            mac,
        })
    }

    /// Fetch and MAC+STAR-verify a full writer repository via `com.atproto.space.getRepo`.
    pub async fn recover_writer_repo_via_star(
        &self,
        space: &SpaceRef,
        writer_did: &Did,
        pds_url: &Url,
        pds_did: Option<&Did>,
        now_secs: i64,
    ) -> Result<StarRepo> {
        let mut url = pds_url.clone();
        url.set_path(&format!("/xrpc/{GET_REPO_NSID}"));
        {
            let mut q = url.query_pairs_mut();
            q.clear();
            q.append_pair("space", space.as_str());
            q.append_pair("repo", writer_did.as_str());
        }

        let max_archive_bytes = self.credentials.max_archive_bytes();
        let max_response_bytes = Some(u64::try_from(max_archive_bytes).unwrap_or(u64::MAX));
        let (resp, shared_secret) = self
            .send_mac_protected_get(
                space,
                writer_did,
                &url,
                pds_did,
                MacProfile::Commit,
                max_response_bytes,
                now_secs,
            )
            .await?;

        let (covered, sig_input, sig) = extract_mac_headers(resp.headers(), MacProfile::Commit)?;
        let mac = verify_commit_mac(&shared_secret, covered, sig_input, sig)?;
        if &mac.space != space || &mac.repo != writer_did {
            return Err(SpaceError::MacMismatch);
        }

        read_star_repo_authenticated(
            resp.body(),
            space,
            Some(writer_did),
            Some(&mac.rev),
            Some(&mac.data),
            max_archive_bytes,
        )
    }

    /// Fetch and verify a single record via `com.atproto.space.getRecord` (both `atproto-space-record`
    /// MAC and canonical DAG-CBOR CID match).
    #[allow(clippy::too_many_arguments)]
    pub async fn get_record_verified(
        &self,
        space: &SpaceRef,
        writer_did: &Did,
        collection: &Nsid,
        rkey: &RecordKey,
        pds_url: &Url,
        pds_did: Option<&Did>,
        now_secs: i64,
    ) -> Result<VerifiedSpaceRecord> {
        let mut url = pds_url.clone();
        url.set_path(&format!("/xrpc/{GET_RECORD_NSID}"));
        {
            let mut q = url.query_pairs_mut();
            q.clear();
            q.append_pair("space", space.as_str());
            q.append_pair("repo", writer_did.as_str());
            q.append_pair("collection", collection.as_str());
            q.append_pair("rkey", rkey.as_str());
        }

        let (resp, shared_secret) = self
            .send_mac_protected_get(
                space,
                writer_did,
                &url,
                pds_did,
                MacProfile::Record,
                None,
                now_secs,
            )
            .await?;

        let (covered, sig_input, sig) = extract_mac_headers(resp.headers(), MacProfile::Record)?;
        let mac = verify_record_mac(&shared_secret, covered, sig_input, sig)?;

        let expected_uri = space
            .record_uri(writer_did, collection, rkey)
            .map_err(|e| SpaceError::InvalidUri(e.to_string()))?;
        if mac.uri.as_str() != expected_uri.as_str() {
            return Err(SpaceError::MacMismatch);
        }

        let out: GetRecordOutput = serde_json::from_slice(resp.body())
            .map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;
        let out_uri_str = out.uri.as_str();
        let _ = parse_space_ref_record(out_uri_str)?;
        if out_uri_str != expected_uri.as_str() {
            return Err(SpaceError::InvalidUri(format!(
                "getRecord uri '{out_uri_str}' != '{expected_uri}'"
            )));
        }

        let body_cid =
            Cid::parse(out.cid.as_str()).map_err(|e| SpaceError::InvalidCid(e.to_string()))?;
        if body_cid != mac.cid {
            return Err(SpaceError::DataHashMismatch {
                expected: mac.cid.to_string(),
                actual: body_cid.to_string(),
            });
        }

        let raw_json: serde_json::Value = serde_json::from_slice(resp.body())
            .map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;
        let val_json = raw_json
            .get("value")
            .ok_or_else(|| SpaceError::MalformedPayload("getRecord output missing value".into()))?;
        let cbor = verify_record_cid(val_json, &mac.cid)?;

        Ok(VerifiedSpaceRecord {
            output: out,
            cid: body_cid,
            cbor,
            mac,
        })
    }

    /// Incrementally fetch `listRepoOps`, verify the MAC on each page, update `local_records`
    /// (`"{collection}/{rkey}" -> Cid`) and `set_hash`, and assert final `set_hash.digest() == commit.data`.
    #[allow(clippy::too_many_arguments)]
    pub async fn sync_writer_ops_verified(
        &self,
        space: &SpaceRef,
        writer_did: &Did,
        pds_url: &Url,
        pds_did: Option<&Did>,
        since: Option<&Tid>,
        local_records: &mut BTreeMap<String, Cid>,
        set_hash: &mut SpaceSetHash,
        now_secs: i64,
    ) -> Result<SyncedWriterOps> {
        let mut cursor: Option<String> = None;
        let mut collected_ops = Vec::new();
        let mut final_commit: Option<Commit> = None;
        let mut staged_records = local_records.clone();
        let mut staged_hash = set_hash.clone();
        let mut completed = false;

        for _ in 0..MAX_LIST_PAGES {
            let mut url = pds_url.clone();
            url.set_path(&format!("/xrpc/{LIST_REPO_OPS_NSID}"));
            {
                let mut q = url.query_pairs_mut();
                q.clear();
                q.append_pair("space", space.as_str());
                q.append_pair("repo", writer_did.as_str());
                if let Some(s) = since {
                    q.append_pair("since", s.as_str());
                }
                q.append_pair("limit", "100");
                if let Some(c) = cursor.as_deref() {
                    q.append_pair("cursor", c);
                }
            }

            let (resp, shared_secret) = self
                .send_mac_protected_get(
                    space,
                    writer_did,
                    &url,
                    pds_did,
                    MacProfile::Commit,
                    None,
                    now_secs,
                )
                .await?;
            let (covered, sig_input, sig) =
                extract_mac_headers(resp.headers(), MacProfile::Commit)?;
            let mac = verify_commit_mac(&shared_secret, covered, sig_input, sig)?;
            let page: ListRepoOpsOutput = serde_json::from_slice(resp.body())
                .map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;
            validate_commit_matches_mac(&page.commit, &mac, space, writer_did)?;

            for op in &page.ops {
                let path = format!("{}/{}", op.collection, op.rkey);
                if let Some(prev_cid) = staged_records.remove(&path) {
                    staged_hash.remove(&path, &prev_cid.to_string());
                }
                if let Some(new_cid_str) = &op.cid {
                    let new_cid = Cid::parse(new_cid_str.as_str())
                        .map_err(|e| SpaceError::InvalidCid(e.to_string()))?;
                    if let Some(val) = &op.value {
                        let cbor = to_dag_cbor(val)
                            .map_err(|e| SpaceError::CborEncoding(e.to_string()))?;
                        let actual_cid = Cid::for_dag_cbor(&cbor);
                        if actual_cid != new_cid {
                            return Err(SpaceError::DataHashMismatch {
                                expected: new_cid.to_string(),
                                actual: actual_cid.to_string(),
                            });
                        }
                    }
                    staged_hash.add(&path, &new_cid.to_string());
                    staged_records.insert(path, new_cid);
                }
            }

            collected_ops.extend(page.ops);
            final_commit = Some(page.commit);
            match page.cursor {
                Some(next) if cursor.as_deref() != Some(next.as_str()) => cursor = Some(next),
                _ => {
                    completed = true;
                    break;
                }
            }
        }

        if !completed {
            return Err(SpaceError::MalformedPayload(format!(
                "listRepoOps exceeded {MAX_LIST_PAGES} pages"
            )));
        }
        let commit = final_commit
            .ok_or_else(|| SpaceError::MalformedPayload("listRepoOps returned no commit".into()))?;
        let digest = staged_hash.digest();
        if digest.as_slice() != commit.data.0.as_slice() {
            return Err(SpaceError::DataHashMismatch {
                expected: petrel_crypto::Hex::encode(&commit.data.0),
                actual: petrel_crypto::Hex::encode(&digest),
            });
        }
        *local_records = staged_records;
        *set_hash = staged_hash;
        Ok(SyncedWriterOps {
            commit,
            ops: collected_ops,
            set_hash_digest: digest,
        })
    }

    /// Execute a GET request carrying both RFC 9421 credential headers and an HPKE
    /// `Accept-Signature` header, retrying once on KEM key rotation (`InvalidSpaceMac`)
    /// or `401 CredentialRevoked`.
    #[allow(clippy::too_many_arguments)]
    async fn send_mac_protected_get(
        &self,
        space: &SpaceRef,
        writer_did: &Did,
        url: &Url,
        pds_did: Option<&Did>,
        profile: MacProfile,
        max_response_bytes: Option<u64>,
        now_secs: i64,
    ) -> Result<(http::Response<Bytes>, zeroize::Zeroizing<[u8; 32]>)> {
        let mut force_kem_refresh = false;
        let mut force_cred_refresh = false;

        for attempt in 0..3 {
            let recipient_kem_did = pds_did.unwrap_or(writer_did);
            let recipient_kem_key = self
                .resolver
                .resolve_kem_key(recipient_kem_did, force_kem_refresh)
                .await?;

            let encap = encapsulate_p256(&recipient_kem_key)?;
            let accept_sig = format_accept_signature(profile, &encap.key_share)?;
            let shared_secret = encap.shared_secret;

            let cred = self
                .credentials
                .credential(space, force_cred_refresh, now_secs)
                .await?;
            let aud = derive_audience(url, pds_did.or(cred.pds_did.as_ref()))?;
            let sig_headers =
                sign_credential_request(&cred.jwt, &cred.proof_key, aud.as_str(), now_secs, None)?;

            let mut headers = HeaderMap::new();
            sig_headers.apply_to_header_map(&mut headers)?;
            headers.insert(
                http::header::HeaderName::from_static("accept-signature"),
                http::HeaderValue::from_str(&accept_sig)
                    .map_err(|e| SpaceError::InvalidAcceptSignature(e.to_string()))?,
            );

            let mut builder = http::Request::builder()
                .method(Method::GET)
                .uri(url.as_str());
            if let Some(h) = builder.headers_mut() {
                *h = headers;
            }
            let req = builder
                .body(Bytes::new())
                .map_err(|e| SpaceError::Transport(e.to_string()))?;

            let mut send_options = SendOptions::new();
            send_options.max_response_bytes = max_response_bytes;
            let resp = send_with_redirects(
                self.transport.as_ref(),
                req,
                &send_options,
                RedirectPolicy::Never,
            )
            .await
            .map_err(|e| SpaceError::Transport(e.to_string()))?;

            if attempt < 2 {
                if self
                    .credentials
                    .evict_if_revoked(space, resp.status(), resp.body())
                {
                    force_cred_refresh = true;
                    continue;
                }
                if is_invalid_space_mac(resp.status(), resp.body()) && !force_kem_refresh {
                    force_kem_refresh = true;
                    continue;
                }
            }

            check_http_status(&resp)?;
            return Ok((resp, shared_secret));
        }
        unreachable!("loop exits within 3 attempts")
    }
}

#[derive(Deserialize)]
struct WireErr {
    error: Option<String>,
    message: Option<String>,
}

fn is_invalid_space_mac(status: StatusCode, body: &[u8]) -> bool {
    if status != StatusCode::BAD_REQUEST {
        return false;
    }
    serde_json::from_slice::<WireErr>(body)
        .ok()
        .and_then(|e| e.error)
        .as_deref()
        == Some("InvalidSpaceMac")
}

fn check_http_status(resp: &http::Response<Bytes>) -> Result<()> {
    let status = resp.status();
    if status.is_success() {
        return Ok(());
    }
    let parsed = serde_json::from_slice::<WireErr>(resp.body()).ok();
    let error = parsed.as_ref().and_then(|p| p.error.clone());
    let message = parsed.as_ref().and_then(|p| p.message.clone());
    if let Some(err_name) = error {
        return Err(SpaceError::Xrpc {
            status: status.as_u16(),
            error: err_name,
            message,
        });
    }
    Err(SpaceError::HttpStatus {
        status: status.as_u16(),
        error: None,
        message,
    })
}

fn extract_mac_headers(headers: &HeaderMap, profile: MacProfile) -> Result<(&str, &str, &str)> {
    let get = |name: &str| -> Result<&str> {
        headers
            .get(name)
            .ok_or_else(|| SpaceError::MissingHeader(name.to_owned()))?
            .to_str()
            .map_err(|_| SpaceError::MalformedHeader(format!("non-ASCII '{name}' header")))
    };
    let covered_hdr = match headers.get(profile.response_header()) {
        Some(v) => v
            .to_str()
            .map_err(|_| SpaceError::MalformedHeader("non-ASCII MAC header".into()))?,
        None => get("covered-signature")?,
    };
    Ok((covered_hdr, get("signature-input")?, get("signature")?))
}

fn validate_commit_matches_mac(
    commit: &Commit,
    mac: &VerifiedCommitMac,
    expected_space: &SpaceRef,
    expected_repo: &Did,
) -> Result<()> {
    let body_space = parse_space_ref(commit.space.as_str())?;
    if &body_space != expected_space || &mac.space != expected_space {
        return Err(SpaceError::MacMismatch);
    }
    if &commit.repo != expected_repo || &mac.repo != expected_repo {
        return Err(SpaceError::MacMismatch);
    }
    if commit.rev != mac.rev || commit.data.0.as_slice() != mac.data.as_slice() {
        return Err(SpaceError::MacMismatch);
    }
    Ok(())
}

fn parse_space_ref_record(uri: &str) -> Result<SpaceRef> {
    if uri.starts_with("at://") && uri[5..].contains("/space/") {
        return Err(SpaceError::LegacySpaceUriRejected(uri.to_owned()));
    }
    let parsed = petrel_core::AtUri::parse_with_grammar(
        uri,
        petrel_core::syntax::Grammar::RestrictedOrSpace,
    )
    .map_err(|e| SpaceError::InvalidUri(e.to_string()))?;
    parsed
        .space_ref()
        .ok_or_else(|| SpaceError::InvalidUri(format!("not a Nov 24 at:space/ URI: {uri}")))
}
