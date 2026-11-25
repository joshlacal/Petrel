//! Space authority host engine: delegation verification, credential issuance,
//! notification registration, writer-set sequencing, and revocation notices.

use std::collections::{BTreeMap, HashMap, HashSet};
use std::sync::{Arc, Mutex};

use http::HeaderMap;
use petrel_api::generated::com::atproto::space::{
    authorize_space_sync::{Input as AuthorizeSpaceSyncInput, Output as AuthorizeSpaceSyncOutput},
    confirm_registration::{
        Input as ConfirmRegistrationInput, Output as ConfirmRegistrationOutput,
    },
    defs::{RepoRemoved, RepoWrite},
    get_space::{Output as GetSpaceOutput, OutputPolicy},
    list_writers::{Output as ListWritersOutput, OutputRepos},
    notify_credentials_revoked::Input as NotifyCredentialsRevokedInput,
    notify_repo_update::Input as NotifyRepoUpdateInput,
    notify_space_update::{Input as NotifySpaceUpdateInput, InputUpdate, SpaceDeleted},
    remove_writer::Input as RemoveWriterInput,
};
use petrel_core::{Bytes, Did, SpaceRef, Tid};
use petrel_crypto::{
    ATProtoCrypto, Hex, P256DIDKey,
    rt::{BoxFuture, MaybeSend, MaybeSync},
};

use crate::error::{Result, SpaceError, parse_space_ref};
use crate::http_signature::{VerifiedSpaceHeaders, verify_credential_request};
use crate::signature_replay::{
    DEFAULT_REPLAY_CLOCK_SKEW_SECS, InMemorySignatureReplayCache, SignatureReplayStore,
    check_presentation_replay,
};
use crate::tokens::{
    MAX_CREDENTIAL_LIFETIME_SECS, SigningKeyPair, SigningKeyResolver, generate_jti,
    mint_credential_token, verify_delegation_token,
};

/// Default credential TTL minted by a `SpaceHost` (15 minutes, matching spec cap).
pub const DEFAULT_CREDENTIAL_TTL_SECS: i64 = MAX_CREDENTIAL_LIFETIME_SECS;

/// Registered notification callback for a space syncer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NotifyRegistration {
    pub space: SpaceRef,
    pub endpoint: String,
    pub token: String,
    pub challenge: String,
    pub confirmed: bool,
    pub created_at: i64,
}

/// Persisted writer entry stored by a space host.
#[derive(Debug, Clone, PartialEq)]
pub enum WriterState {
    Active {
        repo: Did,
        repo_rev: Tid,
        data: Vec<u8>,
        space_rev: Tid,
    },
    Removed {
        repo: Did,
        space_rev: Tid,
        removed_at: i64,
    },
}

impl WriterState {
    pub fn repo(&self) -> &Did {
        match self {
            Self::Active { repo, .. } | Self::Removed { repo, .. } => repo,
        }
    }

    pub fn space_rev(&self) -> &Tid {
        match self {
            Self::Active { space_rev, .. } | Self::Removed { space_rev, .. } => space_rev,
        }
    }
}

/// Space metadata held by a space host backend.
#[derive(Debug, Clone)]
pub struct HostedSpace {
    pub space: SpaceRef,
    pub policy: OutputPolicy,
    pub allowed_readers: HashSet<Did>,
    pub allowed_writers: HashSet<Did>,
    pub deleted: bool,
}

/// Storage & authorization backend required by [`SpaceHost`].
pub trait SpaceHostBackend: MaybeSend + MaybeSync {
    fn get_space<'a>(&'a self, space: &'a SpaceRef) -> BoxFuture<'a, Result<Option<HostedSpace>>>;

    fn is_sync_authorized<'a>(
        &'a self,
        space: &'a SpaceRef,
        user: &'a Did,
    ) -> BoxFuture<'a, Result<bool>>;

    fn record_issued_credential<'a>(
        &'a self,
        space: &'a SpaceRef,
        user: &'a Did,
        jti: &'a str,
        expires_at: i64,
    ) -> BoxFuture<'a, Result<()>>;

    fn is_credential_revoked<'a>(
        &'a self,
        space: &'a SpaceRef,
        jti: &'a str,
    ) -> BoxFuture<'a, Result<bool>>;

    fn revoke_user_credentials<'a>(
        &'a self,
        space: &'a SpaceRef,
        user: &'a Did,
    ) -> BoxFuture<'a, Result<Vec<String>>>;

    fn upsert_writer<'a>(
        &'a self,
        space: &'a SpaceRef,
        repo: &'a Did,
        repo_rev: &'a Tid,
        data: &'a [u8],
        space_rev: &'a Tid,
    ) -> BoxFuture<'a, Result<Option<Tid>>>;

    fn remove_writer<'a>(
        &'a self,
        space: &'a SpaceRef,
        repo: &'a Did,
        space_rev: &'a Tid,
        now_secs: i64,
    ) -> BoxFuture<'a, Result<Option<Tid>>>;

    fn list_writers<'a>(
        &'a self,
        space: &'a SpaceRef,
        cursor: Option<&'a str>,
        limit: usize,
    ) -> BoxFuture<'a, Result<Vec<WriterState>>>;

    fn save_registration(&self, reg: NotifyRegistration) -> BoxFuture<'_, Result<()>>;

    fn confirm_registration<'a>(
        &'a self,
        space: &'a SpaceRef,
        endpoint: &'a str,
        token: &'a str,
        challenge: &'a str,
    ) -> BoxFuture<'a, Result<bool>>;
}

#[derive(Default)]
struct InMemoryHostState {
    spaces: HashMap<SpaceRef, HostedSpace>,
    writers: HashMap<SpaceRef, BTreeMap<Did, WriterState>>,
    issued_creds: HashMap<(SpaceRef, Did), Vec<(String, i64)>>,
    revoked_jtis: HashMap<SpaceRef, HashSet<String>>,
    registrations: HashMap<(SpaceRef, String), NotifyRegistration>,
    rev_counter: u64,
}

/// Thread-safe in-memory [`SpaceHostBackend`] suitable for tests and local reference hosts.
#[derive(Default)]
pub struct InMemorySpaceHostBackend {
    state: Mutex<InMemoryHostState>,
}

impl core::fmt::Debug for InMemorySpaceHostBackend {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("InMemorySpaceHostBackend")
            .finish_non_exhaustive()
    }
}

impl InMemorySpaceHostBackend {
    pub fn new() -> Self {
        Self::default()
    }

    /// Insert or replace a hosted space configuration.
    pub fn put_space(&self, space: HostedSpace) -> Result<()> {
        let mut guard = self
            .state
            .lock()
            .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
        guard.spaces.insert(space.space.clone(), space);
        Ok(())
    }

    /// Mark a space deleted so subsequent `authorizeSpaceSync` calls return `SpaceDeleted`.
    pub fn mark_deleted(&self, space: &SpaceRef) -> Result<()> {
        let mut guard = self
            .state
            .lock()
            .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
        if let Some(entry) = guard.spaces.get_mut(space) {
            entry.deleted = true;
        }
        Ok(())
    }

    /// Generate a monotonically increasing test/host TID using internal sequence state.
    pub fn next_space_rev(&self, base_micros: u64) -> Result<Tid> {
        let mut guard = self
            .state
            .lock()
            .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
        guard.rev_counter += 1;
        let ts = base_micros.saturating_add(guard.rev_counter);
        let clk = (guard.rev_counter & 0x3ff) as u16;
        Tid::from_parts(ts, clk).map_err(|e| SpaceError::InvalidTid(e.to_string()))
    }
}

impl SpaceHostBackend for InMemorySpaceHostBackend {
    fn get_space<'a>(&'a self, space: &'a SpaceRef) -> BoxFuture<'a, Result<Option<HostedSpace>>> {
        Box::pin(async move {
            let guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            Ok(guard.spaces.get(space).cloned())
        })
    }

    fn is_sync_authorized<'a>(
        &'a self,
        space: &'a SpaceRef,
        user: &'a Did,
    ) -> BoxFuture<'a, Result<bool>> {
        Box::pin(async move {
            let guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            let Some(hosted) = guard.spaces.get(space) else {
                return Ok(false);
            };
            Ok(hosted.allowed_readers.contains(user) || hosted.allowed_writers.contains(user))
        })
    }

    fn record_issued_credential<'a>(
        &'a self,
        space: &'a SpaceRef,
        user: &'a Did,
        jti: &'a str,
        expires_at: i64,
    ) -> BoxFuture<'a, Result<()>> {
        Box::pin(async move {
            let mut guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            guard
                .issued_creds
                .entry((space.clone(), user.clone()))
                .or_default()
                .push((jti.to_owned(), expires_at));
            Ok(())
        })
    }

    fn is_credential_revoked<'a>(
        &'a self,
        space: &'a SpaceRef,
        jti: &'a str,
    ) -> BoxFuture<'a, Result<bool>> {
        Box::pin(async move {
            let guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            Ok(guard
                .revoked_jtis
                .get(space)
                .is_some_and(|set| set.contains(jti)))
        })
    }

    fn revoke_user_credentials<'a>(
        &'a self,
        space: &'a SpaceRef,
        user: &'a Did,
    ) -> BoxFuture<'a, Result<Vec<String>>> {
        Box::pin(async move {
            let mut guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            let removed = guard
                .issued_creds
                .remove(&(space.clone(), user.clone()))
                .unwrap_or_default();
            let jtis: Vec<String> = removed.into_iter().map(|(jti, _)| jti).collect();
            let rev_set = guard.revoked_jtis.entry(space.clone()).or_default();
            for jti in &jtis {
                rev_set.insert(jti.clone());
            }
            Ok(jtis)
        })
    }

    fn upsert_writer<'a>(
        &'a self,
        space: &'a SpaceRef,
        repo: &'a Did,
        repo_rev: &'a Tid,
        data: &'a [u8],
        space_rev: &'a Tid,
    ) -> BoxFuture<'a, Result<Option<Tid>>> {
        Box::pin(async move {
            let mut guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            let map = guard.writers.entry(space.clone()).or_default();
            let prev = map.get(repo).map(|w| w.space_rev().clone());
            map.insert(
                repo.clone(),
                WriterState::Active {
                    repo: repo.clone(),
                    repo_rev: repo_rev.clone(),
                    data: data.to_vec(),
                    space_rev: space_rev.clone(),
                },
            );
            Ok(prev)
        })
    }

    fn remove_writer<'a>(
        &'a self,
        space: &'a SpaceRef,
        repo: &'a Did,
        space_rev: &'a Tid,
        now_secs: i64,
    ) -> BoxFuture<'a, Result<Option<Tid>>> {
        Box::pin(async move {
            let mut guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            let map = guard.writers.entry(space.clone()).or_default();
            let prev = map.get(repo).map(|w| w.space_rev().clone());
            map.insert(
                repo.clone(),
                WriterState::Removed {
                    repo: repo.clone(),
                    space_rev: space_rev.clone(),
                    removed_at: now_secs,
                },
            );
            Ok(prev)
        })
    }

    fn list_writers<'a>(
        &'a self,
        space: &'a SpaceRef,
        cursor: Option<&'a str>,
        limit: usize,
    ) -> BoxFuture<'a, Result<Vec<WriterState>>> {
        Box::pin(async move {
            let guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            let Some(map) = guard.writers.get(space) else {
                return Ok(Vec::new());
            };
            let mut entries: Vec<WriterState> = map.values().cloned().collect();
            entries.sort_by(|a, b| a.space_rev().as_str().cmp(b.space_rev().as_str()));
            if let Some(cur) = cursor {
                entries.retain(|w| w.space_rev().as_str() > cur);
            }
            entries.truncate(limit);
            Ok(entries)
        })
    }

    fn save_registration(&self, reg: NotifyRegistration) -> BoxFuture<'_, Result<()>> {
        Box::pin(async move {
            let mut guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            guard
                .registrations
                .insert((reg.space.clone(), reg.endpoint.clone()), reg);
            Ok(())
        })
    }

    fn confirm_registration<'a>(
        &'a self,
        space: &'a SpaceRef,
        endpoint: &'a str,
        token: &'a str,
        challenge: &'a str,
    ) -> BoxFuture<'a, Result<bool>> {
        Box::pin(async move {
            let mut guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("host backend mutex poisoned".into()))?;
            if let Some(reg) = guard
                .registrations
                .get_mut(&(space.clone(), endpoint.to_owned()))
                && reg.token == token
                && reg.challenge == challenge
            {
                reg.confirmed = true;
                return Ok(true);
            }
            Ok(false)
        })
    }
}

/// Space authority server protocol handler implementing `authorizeSpaceSync`,
/// credential presentation verification, `listWriters`, `notifyRepoUpdate`, `removeWriter`,
/// `getSpace`, registration confirmation, and credential revocation.
pub struct SpaceHost<
    B: SpaceHostBackend,
    R: SigningKeyResolver,
    S: SignatureReplayStore = InMemorySignatureReplayCache,
> {
    host_did: Did,
    signing_key: SigningKeyPair,
    backend: Arc<B>,
    did_resolver: Arc<R>,
    replay_store: Arc<S>,
    credential_ttl_secs: i64,
}

impl<B: SpaceHostBackend, R: SigningKeyResolver, S: SignatureReplayStore> core::fmt::Debug
    for SpaceHost<B, R, S>
{
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("SpaceHost")
            .field("host_did", &self.host_did)
            .field("credential_ttl_secs", &self.credential_ttl_secs)
            .finish_non_exhaustive()
    }
}

impl<B: SpaceHostBackend, R: SigningKeyResolver> SpaceHost<B, R, InMemorySignatureReplayCache> {
    pub fn with_in_memory_replay(
        host_did: Did,
        signing_key: SigningKeyPair,
        backend: Arc<B>,
        did_resolver: Arc<R>,
    ) -> Self {
        Self::new(
            host_did,
            signing_key,
            backend,
            did_resolver,
            Arc::new(InMemorySignatureReplayCache::default()),
        )
    }
}

impl<B: SpaceHostBackend, R: SigningKeyResolver, S: SignatureReplayStore> SpaceHost<B, R, S> {
    pub fn new(
        host_did: Did,
        signing_key: SigningKeyPair,
        backend: Arc<B>,
        did_resolver: Arc<R>,
        replay_store: Arc<S>,
    ) -> Self {
        Self {
            host_did,
            signing_key,
            backend,
            did_resolver,
            replay_store,
            credential_ttl_secs: DEFAULT_CREDENTIAL_TTL_SECS,
        }
    }

    #[must_use]
    pub fn with_credential_ttl_secs(mut self, secs: i64) -> Self {
        self.credential_ttl_secs = secs.clamp(1, MAX_CREDENTIAL_LIFETIME_SECS);
        self
    }

    pub fn host_did(&self) -> &Did {
        &self.host_did
    }

    /// Handle `com.atproto.space.authorizeSpaceSync`.
    ///
    /// Verifies the bearer/embedded delegation JWT (`sub == input.space`, `aud == host_did`),
    /// validates `input.credential_key` is a P-256 `did:key:`, checks space existence and policy
    /// authorization, mints an `atproto-space-credential+jwt`, and records any pending notification
    /// registration challenge.
    pub async fn handle_authorize_space_sync(
        &self,
        input: &AuthorizeSpaceSyncInput,
        delegation_jwt: Option<&str>,
        now_secs: i64,
    ) -> Result<(AuthorizeSpaceSyncOutput, Option<NotifyRegistration>)> {
        let space = parse_space_ref(input.space.as_str())?;
        let _ = P256DIDKey::parse(&input.credential_key)
            .map_err(|e| SpaceError::InvalidKemKey(e.to_string()))?;

        let raw_delegation = delegation_jwt
            .or(input.delegation_token.as_deref())
            .ok_or_else(|| SpaceError::Unauthorized("missing delegation token".into()))?;

        let claims = verify_delegation_token(
            raw_delegation,
            self.host_did.as_str(),
            now_secs,
            self.did_resolver.as_ref(),
        )
        .await?;
        let claimed_space = claims.space_ref()?;
        if claimed_space != space {
            return Err(SpaceError::InvalidSubject(format!(
                "delegation sub '{claimed_space}' does not match requested space '{space}'"
            )));
        }

        let hosted = self
            .backend
            .get_space(&space)
            .await?
            .ok_or_else(|| SpaceError::SpaceNotFound(space.as_str().to_owned()))?;
        if hosted.deleted {
            return Err(SpaceError::SpaceDeleted(space.as_str().to_owned()));
        }

        let user = claims.issuer_did()?;
        if !self.backend.is_sync_authorized(&space, &user).await? {
            return Err(SpaceError::AuthorizationRefused {
                space: space.as_str().to_owned(),
                detail: Some(format!("{user} is not authorized to sync space")),
            });
        }

        let jti = generate_jti()?;
        let exp = now_secs.saturating_add(self.credential_ttl_secs);
        let token = mint_credential_token(
            &self.signing_key,
            &self.host_did,
            &space,
            &input.credential_key,
            now_secs,
            exp,
            Some(&jti),
            Some("#atproto"),
        )?;
        self.backend
            .record_issued_credential(&space, &user, &jti, exp)
            .await?;

        let mut reg_out = None;
        if let Some(notify) = &input.notify {
            let chal_bytes: [u8; 16] =
                ATProtoCrypto::random_array().map_err(|e| SpaceError::KemError(e.to_string()))?;
            let reg = NotifyRegistration {
                space: space.clone(),
                endpoint: notify.endpoint.as_str().to_owned(),
                token: notify.token.clone(),
                challenge: Hex::encode(&chal_bytes),
                confirmed: false,
                created_at: now_secs,
            };
            self.backend.save_registration(reg.clone()).await?;
            reg_out = Some(reg);
        }

        Ok((AuthorizeSpaceSyncOutput::new(token), reg_out))
    }

    /// Build a `com.atproto.space.confirmRegistration#Input` payload for a pending registration.
    pub fn build_confirm_registration(&self, reg: &NotifyRegistration) -> ConfirmRegistrationInput {
        ConfirmRegistrationInput::new(reg.space.clone(), reg.token.clone(), reg.challenge.clone())
    }

    /// Verify a `com.atproto.space.confirmRegistration#Output` echo and mark confirmed.
    pub async fn verify_confirm_registration_response(
        &self,
        reg: &NotifyRegistration,
        output: &ConfirmRegistrationOutput,
    ) -> Result<()> {
        if output.challenge != reg.challenge {
            return Err(SpaceError::Unauthorized(
                "registration confirmation challenge mismatch".into(),
            ));
        }
        let ok = self
            .backend
            .confirm_registration(&reg.space, &reg.endpoint, &reg.token, &reg.challenge)
            .await?;
        if !ok {
            return Err(SpaceError::Unauthorized(
                "pending registration not found for confirmation".into(),
            ));
        }
        Ok(())
    }

    /// Verify an incoming RFC 9421 space credential presentation, enforcing replay protection
    /// and credential revocation status.
    pub async fn verify_presentation(
        &self,
        headers: &HeaderMap,
        expected_space: Option<&SpaceRef>,
        now_secs: i64,
    ) -> Result<VerifiedSpaceHeaders> {
        let verified = verify_credential_request(
            headers,
            self.host_did.as_str(),
            now_secs,
            self.did_resolver.as_ref(),
        )
        .await?;

        let space = verified.claims.space_ref()?;
        if let Some(exp_space) = expected_space
            && &space != exp_space
        {
            return Err(SpaceError::InvalidSubject(format!(
                "credential sub '{space}' does not match '{exp_space}'"
            )));
        }

        if self
            .backend
            .is_credential_revoked(&space, &verified.claims.jti)
            .await?
        {
            return Err(SpaceError::Xrpc {
                status: 401,
                error: "CredentialRevoked".to_owned(),
                message: Some("space credential has been revoked".to_owned()),
            });
        }

        check_presentation_replay(
            self.replay_store.as_ref(),
            &verified.claims.iss,
            verified.nonce.as_deref(),
            verified.created,
            verified.expires,
            verified.claims.exp,
            crate::http_signature::MAX_HTTP_SIGNATURE_AGE_SECS,
            DEFAULT_REPLAY_CLOCK_SKEW_SECS,
            DEFAULT_REPLAY_CLOCK_SKEW_SECS,
            now_secs,
        )
        .await?;

        Ok(verified)
    }

    /// Handle `com.atproto.space.listWriters`.
    pub async fn handle_list_writers(
        &self,
        space: &SpaceRef,
        cursor: Option<&str>,
        limit: usize,
    ) -> Result<ListWritersOutput> {
        let hosted = self
            .backend
            .get_space(space)
            .await?
            .ok_or_else(|| SpaceError::SpaceNotFound(space.as_str().to_owned()))?;
        if hosted.deleted {
            return Err(SpaceError::SpaceNotFound(space.as_str().to_owned()));
        }
        let rows = self
            .backend
            .list_writers(space, cursor, limit.clamp(1, 500))
            .await?;
        let next_cursor = rows.last().map(|w| w.space_rev().as_str().to_owned());
        let repos = rows
            .into_iter()
            .map(|row| match row {
                WriterState::Active {
                    repo,
                    repo_rev,
                    data,
                    space_rev,
                } => OutputRepos::RepoWrite(Box::new(RepoWrite::new(
                    repo,
                    repo_rev,
                    Bytes(data),
                    space_rev,
                ))),
                WriterState::Removed {
                    repo, space_rev, ..
                } => OutputRepos::RepoRemoved(Box::new(RepoRemoved::new(repo, space_rev))),
            })
            .collect();
        Ok(ListWritersOutput {
            repos,
            cursor: next_cursor,
        })
    }

    /// Handle `com.atproto.space.notifyRepoUpdate`, returning an outbound `NotifySpaceUpdate`
    /// update variant (`RepoWrite` with `prev_space_rev`).
    pub async fn handle_notify_repo_update(
        &self,
        input: &NotifyRepoUpdateInput,
        space_rev: Tid,
    ) -> Result<InputUpdate> {
        let space = parse_space_ref(input.space.as_str())?;
        let hosted = self
            .backend
            .get_space(&space)
            .await?
            .ok_or_else(|| SpaceError::SpaceNotFound(space.as_str().to_owned()))?;
        if hosted.deleted {
            return Err(SpaceError::SpaceDeleted(space.as_str().to_owned()));
        }
        if !hosted.allowed_writers.contains(&input.repo) {
            return Err(SpaceError::Forbidden(format!(
                "{} is not an authorized writer for {space}",
                input.repo
            )));
        }
        let prev = self
            .backend
            .upsert_writer(
                &space,
                &input.repo,
                &input.repo_rev,
                &input.data.0,
                &space_rev,
            )
            .await?;
        let mut write = RepoWrite::new(
            input.repo.clone(),
            input.repo_rev.clone(),
            input.data.clone(),
            space_rev,
        );
        write.prev_space_rev = prev;
        Ok(InputUpdate::RepoWrite(Box::new(write)))
    }

    /// Handle `com.atproto.space.removeWriter`, returning `RepoRemoved`.
    pub async fn handle_remove_writer(
        &self,
        input: &RemoveWriterInput,
        space_rev: Tid,
        now_secs: i64,
    ) -> Result<InputUpdate> {
        let space = parse_space_ref(input.space.as_str())?;
        let _ = self
            .backend
            .get_space(&space)
            .await?
            .ok_or_else(|| SpaceError::SpaceNotFound(space.as_str().to_owned()))?;
        let prev = self
            .backend
            .remove_writer(&space, &input.repo, &space_rev, now_secs)
            .await?;
        let mut removed = RepoRemoved::new(input.repo.clone(), space_rev);
        removed.prev_space_rev = prev;
        Ok(InputUpdate::RepoRemoved(Box::new(removed)))
    }

    /// Handle `com.atproto.space.getSpace`.
    pub async fn handle_get_space(&self, space: &SpaceRef) -> Result<GetSpaceOutput> {
        let hosted = self
            .backend
            .get_space(space)
            .await?
            .ok_or_else(|| SpaceError::SpaceNotFound(space.as_str().to_owned()))?;
        if hosted.deleted {
            return Err(SpaceError::SpaceNotFound(space.as_str().to_owned()));
        }
        Ok(GetSpaceOutput::new(hosted.space, hosted.policy))
    }

    /// Revoke all credentials issued to `user` in `space` and construct a
    /// `com.atproto.space.notifyCredentialsRevoked` payload (or `None` if no credentials were active).
    pub async fn revoke_user_credentials_and_build_notice(
        &self,
        space: &SpaceRef,
        user: &Did,
    ) -> Result<Option<NotifyCredentialsRevokedInput>> {
        let jtis = self.backend.revoke_user_credentials(space, user).await?;
        if jtis.is_empty() {
            return Ok(None);
        }
        Ok(Some(NotifyCredentialsRevokedInput::new(
            space.clone(),
            jtis,
        )))
    }

    /// Construct a `com.atproto.space.notifySpaceUpdate` payload for a deleted space.
    pub fn build_notify_space_deleted(
        &self,
        space: &SpaceRef,
        registration_token: &str,
    ) -> NotifySpaceUpdateInput {
        NotifySpaceUpdateInput::new(
            space.clone(),
            registration_token.to_owned(),
            InputUpdate::SpaceDeleted(Box::new(SpaceDeleted::new())),
        )
    }
}
