//! Bluesky application helpers layered on top of Petrel's XRPC and AT Protocol clients.

use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::Duration;

use async_lock::{Mutex, RwLock};
use bytes::Bytes;
use http::{HeaderMap, HeaderValue, Method, Request};
use petrel::auth::AuthContinuitySnapshot;
use petrel::client::AtProtoClient;
use petrel::media::{ImageMetadataStripper, ImageMetadataStrippingError};
use petrel::net::SendOptions;
use petrel::rt::{BoxFuture, Instant, SystemTime, UNIX_EPOCH, sleep};
use petrel::xrpc::{
    CallOptions, Error as XrpcClientError, XrpcBody, XrpcClient, XrpcLabeler, XrpcResponse,
};
use petrel_api::generated::app::bsky::actor::defs::{
    MutedWord, MutedWordTarget, PostInteractionSettingsPref, SavedFeed,
};
use petrel_api::generated::app::bsky::actor::profile::{Profile, ProfileLabels};
use petrel_api::generated::app::bsky::embed::defs::AspectRatio;
use petrel_api::generated::app::bsky::embed::external::{External, ExternalDef};
use petrel_api::generated::app::bsky::embed::images::{Image as EmbedImage, Images as EmbedImages};
use petrel_api::generated::app::bsky::embed::record::Record as EmbedRecord;
use petrel_api::generated::app::bsky::embed::record_with_media::{
    RecordWithMedia, RecordWithMediaMedia,
};
use petrel_api::generated::app::bsky::embed::video::{
    Caption as VideoCaption, Video as EmbedVideo,
};
use petrel_api::generated::app::bsky::feed::defs::PostView;
use petrel_api::generated::app::bsky::feed::like::Like as FeedLike;
use petrel_api::generated::app::bsky::feed::post::{Post, PostEmbed, PostLabels, ReplyRef};
use petrel_api::generated::app::bsky::feed::postgate::{Postgate, PostgateEmbeddingRules};
use petrel_api::generated::app::bsky::feed::repost::Repost as FeedRepost;
use petrel_api::generated::app::bsky::feed::threadgate::{Threadgate, ThreadgateAllow};
use petrel_api::generated::app::bsky::graph::block::Block as GraphBlock;
use petrel_api::generated::app::bsky::graph::follow::Follow as GraphFollow;
use petrel_api::generated::app::bsky::graph::listblock::Listblock as GraphListblock;
use petrel_api::generated::app::bsky::labeler::get_services::{
    Output as GetServicesOutput, OutputViews,
};
use petrel_api::generated::app::bsky::video::defs::JobStatus;
use petrel_api::generated::com::atproto::label::defs::{SelfLabel, SelfLabels};
use petrel_api::generated::com::atproto::moderation::create_report::{
    Input as CreateReportInput, Output as CreateReportOutput,
};
use petrel_api::generated::com::atproto::repo::strong_ref::StrongRef;
use petrel_core::{
    AtIdentifier, AtUri, Blob, CidString, Datetime, Did, FromValue, Language, Nsid, RecordKey, Uri,
    Value,
};
use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::{Map, Value as JsonValue};
use url::Url;

use crate::moderation::{
    InterpretedLabelValueDefinition, LabelPreference, ModerationOptions, ModerationPrefs,
    interpret_label_value_definitions,
};
use crate::preferences::{
    BskyAppProgressGuide, BskyFeedViewPreferenceUpdate, BskyLegacyFeeds, BskyLiveEventPreferences,
    BskyLiveEventPreferencesAction, BskyNewSavedFeed, BskyPreferences, BskyPreferencesBackend,
    BskyPreferencesEngine, BskyPreferencesSession,
};
use crate::richtext::RichText;

/// DID of the official Bluesky moderation service (`moderation.bsky.app`).
pub const BSKY_LABELER_DID: &str = "did:plc:ar7c4by46qjdydhdevvrndac";

/// Default Bluesky video processing service URL.
pub const VIDEO_SERVICE_URL: &str = "https://video.bsky.app";

/// Errors returned by [`BskyAgent`] and preferences operations.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum BskyAgentError {
    /// No active account DID is available.
    #[error("Not signed in")]
    NotAuthenticated,
    /// Active account or authentication continuity changed mid-operation.
    #[error("Authentication continuity changed during operation")]
    AuthContinuityChanged,
    /// Server returned an XRPC/HTTP error status.
    #[error("{nsid} failed with HTTP {status}")]
    Xrpc {
        /// NSID called.
        nsid: String,
        /// HTTP status code.
        status: u16,
        /// Optional XRPC error name.
        error: Option<String>,
        /// Optional server message.
        message: Option<String>,
    },
    /// Server answered 2xx but the body did not match expectations.
    #[error("{nsid} returned an unusable response: {reason}")]
    InvalidResponse {
        /// NSID called.
        nsid: String,
        /// Failure details.
        reason: String,
    },
    /// Caller supplied invalid input.
    #[error("Invalid input: {0}")]
    InvalidInput(String),
    /// Compare-and-swap writes collided on every retry attempt.
    #[error("Record changed concurrently on each of {attempts} attempts")]
    SwapRetriesExhausted {
        /// Number of attempts made.
        attempts: usize,
    },
    /// Video processing reported failure.
    #[error("Video job {job_id} failed")]
    VideoProcessingFailed {
        /// Video service job identifier.
        job_id: String,
        /// Optional error code.
        error: Option<String>,
        /// Optional error message.
        message: Option<String>,
    },
    /// Video processing did not complete within the timeout.
    #[error("Video job {job_id} did not finish in time")]
    VideoProcessingTimedOut {
        /// Video service job identifier.
        job_id: String,
    },
    /// Image metadata stripping failed.
    #[error(transparent)]
    Media(#[from] ImageMetadataStrippingError),
    /// Lower-level transport or auth failure.
    #[error("Transport error: {0}")]
    Transport(String),
}

impl BskyAgentError {
    /// Returns the XRPC error name if this is an [`BskyAgentError::Xrpc`].
    #[must_use]
    pub fn xrpc_error_name(&self) -> Option<&str> {
        if let Self::Xrpc { error, .. } = self {
            error.as_deref()
        } else {
            None
        }
    }
}

fn map_xrpc_error(nsid: &str, err: XrpcClientError) -> BskyAgentError {
    match err {
        XrpcClientError::Xrpc(xrpc) => BskyAgentError::Xrpc {
            nsid: nsid.to_owned(),
            status: xrpc.metadata.status.as_u16(),
            error: Some(xrpc.code),
            message: xrpc.message,
        },
        XrpcClientError::Decode { source, .. } => BskyAgentError::InvalidResponse {
            nsid: nsid.to_owned(),
            reason: source.to_string(),
        },
        other => BskyAgentError::Transport(other.to_string()),
    }
}

/// A service target for `atproto-proxy` (`<did>#<service_id>`).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ServiceProxy {
    /// Service DID.
    pub did: Did,
    /// DID-document service fragment without `#`.
    pub service_id: String,
}

impl ServiceProxy {
    /// Constructs and validates a service proxy target.
    pub fn new(did: Did, service_id: impl Into<String>) -> Result<Self, BskyAgentError> {
        let service_id = service_id.into();
        if service_id.is_empty()
            || !service_id
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
        {
            return Err(BskyAgentError::InvalidInput(
                "Service identifier must be a plain fragment such as bsky_chat".to_owned(),
            ));
        }
        Ok(Self { did, service_id })
    }

    /// Bluesky chat service (`did:web:api.bsky.chat#bsky_chat`).
    ///
    /// # Panics
    ///
    /// Panics only if the static service DID literal fails validation (unreachable).
    #[must_use]
    pub fn bsky_chat() -> Self {
        Self {
            did: "did:web:api.bsky.chat"
                .parse()
                .expect("literal DID must parse"),
            service_id: "bsky_chat".to_owned(),
        }
    }

    /// Bluesky AppView (`did:web:api.bsky.app#bsky_appview`).
    ///
    /// # Panics
    ///
    /// Panics only if the static service DID literal fails validation (unreachable).
    #[must_use]
    pub fn bsky_app_view() -> Self {
        Self {
            did: "did:web:api.bsky.app"
                .parse()
                .expect("literal DID must parse"),
            service_id: "bsky_appview".to_owned(),
        }
    }

    /// Custom chat service (`<did>#bsky_chat`).
    #[must_use]
    pub fn chat(did: Did) -> Self {
        Self {
            did,
            service_id: "bsky_chat".to_owned(),
        }
    }

    /// Labeler moderation service (`<did>#atproto_labeler`).
    #[must_use]
    pub fn labeler(did: Did) -> Self {
        Self {
            did,
            service_id: "atproto_labeler".to_owned(),
        }
    }

    /// Returns `<did>#<service_id>`.
    #[must_use]
    pub fn header_value(&self) -> String {
        format!("{}#{}", self.did.as_str(), self.service_id)
    }
}

/// Per-call options for [`BskyAgent`] helpers.
#[derive(Debug, Clone, Default)]
pub struct BskyCallOptions {
    /// Override `atproto-proxy` for this call.
    pub proxy: Option<ServiceProxy>,
    /// Override `atproto-accept-labelers` for this call (`Some(vec![])` sends `""`).
    pub accept_labelers: Option<Vec<XrpcLabeler>>,
    /// Extra HTTP headers for this call.
    pub headers: HeaderMap,
    /// Optional direct service URL override (bypasses PDS proxying).
    pub service: Option<Url>,
}

/// Media attachment of a [`PostEmbed`].
#[derive(Debug, Clone, PartialEq)]
pub enum PostEmbedMedia {
    /// One to four uploaded images.
    Images(Vec<EmbedImage>),
    /// One uploaded video.
    Video(EmbedVideo),
    /// External link card.
    External(ExternalDef),
}

/// What a post embeds: media, a quoted record, or both.
#[derive(Debug, Clone, PartialEq)]
pub struct PostEmbedBuilder {
    media: Option<PostEmbedMedia>,
    quote: Option<StrongRef>,
}

impl PostEmbedBuilder {
    /// Maximum images per post (`app.bsky.embed.images`).
    pub const MAX_IMAGES: usize = 4;

    /// Embeds 1..=4 uploaded images.
    pub fn images(images: Vec<EmbedImage>) -> Result<Self, BskyAgentError> {
        if images.is_empty() || images.len() > Self::MAX_IMAGES {
            return Err(BskyAgentError::InvalidInput(format!(
                "A post embeds between 1 and {} images, got {}",
                Self::MAX_IMAGES,
                images.len()
            )));
        }
        Ok(Self {
            media: Some(PostEmbedMedia::Images(images)),
            quote: None,
        })
    }

    /// Embeds an external link card.
    #[must_use]
    pub fn external(
        uri: Uri,
        title: impl Into<String>,
        description: impl Into<String>,
        thumb: Option<Blob>,
    ) -> Self {
        let mut obj = ExternalDef::new(uri, title.into(), description.into());
        obj.thumb = thumb;
        Self {
            media: Some(PostEmbedMedia::External(obj)),
            quote: None,
        }
    }

    /// Embeds an uploaded video.
    #[must_use]
    pub fn video(
        video: Blob,
        alt: Option<String>,
        aspect_ratio: Option<AspectRatio>,
        captions: Option<Vec<VideoCaption>>,
    ) -> Self {
        let mut v = EmbedVideo::new(video);
        v.alt = alt;
        v.aspect_ratio = aspect_ratio;
        v.captions = captions;
        Self {
            media: Some(PostEmbedMedia::Video(v)),
            quote: None,
        }
    }

    /// Embeds a quoted record.
    #[must_use]
    pub const fn quote(record: StrongRef) -> Self {
        Self {
            media: None,
            quote: Some(record),
        }
    }

    /// Attaches a quoted record to this embed while keeping its media.
    #[must_use]
    pub fn quoting(mut self, record: StrongRef) -> Self {
        self.quote = Some(record);
        self
    }

    /// Converts to the generated `PostEmbed` union.
    #[must_use]
    pub fn into_post_embed(self) -> Option<PostEmbed> {
        match (self.quote, self.media) {
            (Some(record), None) => Some(PostEmbed::Record(Box::new(EmbedRecord::new(record)))),
            (None, Some(media)) => Some(match media {
                PostEmbedMedia::Images(images) => {
                    PostEmbed::Images(Box::new(EmbedImages::new(images)))
                }
                PostEmbedMedia::Video(video) => PostEmbed::Video(Box::new(video)),
                PostEmbedMedia::External(external) => {
                    PostEmbed::External(Box::new(External::new(external)))
                }
            }),
            (Some(record), Some(media)) => {
                let media_union = match media {
                    PostEmbedMedia::Images(images) => {
                        RecordWithMediaMedia::Images(Box::new(EmbedImages::new(images)))
                    }
                    PostEmbedMedia::Video(video) => RecordWithMediaMedia::Video(Box::new(video)),
                    PostEmbedMedia::External(external) => {
                        RecordWithMediaMedia::External(Box::new(External::new(external)))
                    }
                };
                Some(PostEmbed::RecordWithMedia(Box::new(RecordWithMedia::new(
                    EmbedRecord::new(record),
                    media_union,
                ))))
            }
            (None, None) => None,
        }
    }
}

/// Image attachment prior to upload.
#[derive(Debug, Clone, PartialEq)]
pub struct PostImage {
    /// Raw image bytes.
    pub data: Bytes,
    /// Media type (must start with `image/`).
    pub mime_type: String,
    /// Alt text.
    pub alt: String,
    /// Optional pixel dimensions.
    pub aspect_ratio: Option<AspectRatio>,
}

/// Compare-and-swap precondition for `put_record`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RecordSwap {
    /// Write unconditionally.
    Any,
    /// Write only if no record exists at this key.
    MustNotExist,
    /// Write only if the stored record has this CID.
    Matches(CidString),
}

/// Mutable copy of `app.bsky.actor.profile` for [`BskyAgent::upsert_profile`].
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ProfileUpdate {
    /// Display name (<= 64 graphemes).
    pub display_name: Option<String>,
    /// Profile bio/description (<= 256 graphemes).
    pub description: Option<String>,
    /// Free-form pronouns.
    pub pronouns: Option<String>,
    /// Website URL.
    pub website: Option<Uri>,
    /// Uploaded avatar blob.
    pub avatar: Option<Blob>,
    /// Uploaded banner blob.
    pub banner: Option<Blob>,
    /// Self-labels applied to the profile.
    pub labels: Option<ProfileLabels>,
    /// Starter pack joined through.
    pub joined_via_starter_pack: Option<StrongRef>,
    /// Pinned post ref.
    pub pinned_post: Option<StrongRef>,
    /// Profile links.
    pub links: Option<Vec<StrongRef>>,
    /// Profile creation timestamp.
    pub created_at: Option<Datetime>,
    /// Unmodeled fields preserved across round-trips.
    pub extra_data: Option<BTreeMap<String, Value>>,
}

impl ProfileUpdate {
    /// Starts from an existing profile record, or empty defaults.
    #[must_use]
    pub fn from_existing(existing: Option<&Profile>) -> Self {
        let Some(existing) = existing else {
            return Self::default();
        };
        Self {
            display_name: existing.display_name.clone(),
            description: existing.description.clone(),
            pronouns: existing.pronouns.clone(),
            website: existing.website.clone(),
            avatar: existing.avatar.clone(),
            banner: existing.banner.clone(),
            labels: existing.labels.clone(),
            joined_via_starter_pack: existing.joined_via_starter_pack.clone(),
            pinned_post: existing.pinned_post.clone(),
            links: existing.links.clone(),
            created_at: existing.created_at.clone(),
            extra_data: existing.extra_data.clone(),
        }
    }

    /// Converts into an `app.bsky.actor.profile` record.
    #[must_use]
    pub fn into_record(self) -> Profile {
        Profile {
            display_name: self.display_name,
            description: self.description,
            pronouns: self.pronouns,
            website: self.website,
            avatar: self.avatar,
            banner: self.banner,
            labels: self.labels,
            joined_via_starter_pack: self.joined_via_starter_pack,
            pinned_post: self.pinned_post,
            links: self.links,
            created_at: self.created_at,
            extra_data: self.extra_data,
        }
    }
}

#[derive(Clone)]
enum AgentTransport {
    Client(Arc<AtProtoClient>),
    Xrpc {
        xrpc: Arc<RwLock<XrpcClient>>,
        did: Option<Did>,
    },
}

/// High-level Bluesky helper client over [`AtProtoClient`] or [`XrpcClient`].
#[derive(Clone)]
pub struct BskyAgent {
    transport: AgentTransport,
    app_labelers: Vec<Did>,
    preferences_lock: Arc<Mutex<()>>,
}

impl std::fmt::Debug for BskyAgent {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("BskyAgent")
            .field("app_labelers", &self.app_labelers)
            .finish_non_exhaustive()
    }
}

impl BskyAgent {
    /// Creates an agent backed by `client` with the default Bluesky moderation labeler.
    ///
    /// # Panics
    ///
    /// Panics only if the built-in Bluesky labeler DID literal fails validation (unreachable).
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    #[must_use]
    pub fn from_client(client: Arc<AtProtoClient>) -> Self {
        Self {
            transport: AgentTransport::Client(client),
            app_labelers: vec![BSKY_LABELER_DID.parse().expect("literal DID must parse")],
            preferences_lock: Arc::new(Mutex::new(())),
        }
    }

    /// Creates an agent over a raw [`XrpcClient`] with optional fixed account DID.
    ///
    /// # Panics
    ///
    /// Panics only if the built-in Bluesky labeler DID literal fails validation (unreachable).
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    #[must_use]
    pub fn from_xrpc(xrpc: XrpcClient, did: Option<Did>) -> Self {
        Self {
            transport: AgentTransport::Xrpc {
                xrpc: Arc::new(RwLock::new(xrpc)),
                did,
            },
            app_labelers: vec![BSKY_LABELER_DID.parse().expect("literal DID must parse")],
            preferences_lock: Arc::new(Mutex::new(())),
        }
    }

    /// Overrides the always-applied app labelers (each sent with `;redact`).
    #[must_use]
    pub fn with_app_labelers(mut self, app_labelers: Vec<Did>) -> Self {
        self.app_labelers = app_labelers;
        self
    }

    /// Returns the configured app labelers.
    #[must_use]
    pub fn app_labelers(&self) -> &[Did] {
        &self.app_labelers
    }

    /// Returns the active DID of the signed-in account.
    pub async fn did(&self) -> Result<Did, BskyAgentError> {
        match &self.transport {
            AgentTransport::Client(client) => client
                .get_did()
                .await
                .map_err(|e| BskyAgentError::Transport(e.to_string()))?
                .ok_or(BskyAgentError::NotAuthenticated),
            AgentTransport::Xrpc { did, .. } => did.clone().ok_or(BskyAgentError::NotAuthenticated),
        }
    }

    /// Returns the current base PDS URL.
    pub async fn base_url(&self) -> Url {
        match &self.transport {
            AgentTransport::Client(client) => client.base_url().await,
            AgentTransport::Xrpc { xrpc, .. } => xrpc.read().await.base_url().clone(),
        }
    }

    async fn xrpc_snapshot(&self) -> XrpcClient {
        match &self.transport {
            AgentTransport::Client(client) => client.xrpc().await,
            AgentTransport::Xrpc { xrpc, .. } => xrpc.read().await.clone(),
        }
    }

    fn build_call_options(options: &BskyCallOptions) -> CallOptions {
        let mut call = CallOptions {
            headers: options.headers.clone(),
            proxy: options.proxy.as_ref().map(ServiceProxy::header_value),
            accept_labelers: options.accept_labelers.clone(),
            service: options.service.clone(),
            ..CallOptions::default()
        };
        if call
            .service
            .as_ref()
            .is_some_and(|u| u.scheme() == "http" && is_loopback_host(u.host_str()))
        {
            call.transport.allow_loopback = true;
        }
        call
    }

    async fn xrpc_query(
        &self,
        nsid: &str,
        params: &[(&str, String)],
        options: &BskyCallOptions,
    ) -> Result<XrpcResponse, BskyAgentError> {
        let call = Self::build_call_options(options);
        let pairs: Vec<(&str, &str)> = params.iter().map(|(k, v)| (*k, v.as_str())).collect();
        let res = match &self.transport {
            AgentTransport::Client(client) if call.service.is_none() => {
                client.query(nsid, pairs, &call).await
            }
            _ => {
                let xrpc = self.xrpc_snapshot().await;
                xrpc.query(nsid, pairs, &call).await
            }
        };
        res.map_err(|err| map_xrpc_error(nsid, err))
    }

    async fn xrpc_procedure(
        &self,
        nsid: &str,
        body: Option<XrpcBody>,
        options: &BskyCallOptions,
    ) -> Result<XrpcResponse, BskyAgentError> {
        let call = Self::build_call_options(options);
        let empty: [(&str, &str); 0] = [];
        let res = match &self.transport {
            AgentTransport::Client(client) if call.service.is_none() => {
                client.procedure(nsid, empty, body, &call).await
            }
            _ => {
                let xrpc = self.xrpc_snapshot().await;
                xrpc.procedure(nsid, empty, body, &call).await
            }
        };
        res.map_err(|err| map_xrpc_error(nsid, err))
    }

    /// Calls an XRPC query with per-call proxy/labeler/header overrides and decodes JSON output.
    pub async fn query<Output: DeserializeOwned>(
        &self,
        nsid: &str,
        params: &[(&str, String)],
        options: &BskyCallOptions,
    ) -> Result<Output, BskyAgentError> {
        let resp = self.xrpc_query(nsid, params, options).await?;
        decode_response_json(&resp.body, nsid)
    }

    /// Calls an XRPC procedure with JSON input and decodes JSON output.
    pub async fn procedure<Input: Serialize, Output: DeserializeOwned>(
        &self,
        nsid: &str,
        input: &Input,
        options: &BskyCallOptions,
    ) -> Result<Output, BskyAgentError> {
        let encoded = serde_json::to_vec(input)
            .map_err(|e| BskyAgentError::InvalidInput(format!("encode {nsid}: {e}")))?;
        let resp = self
            .xrpc_procedure(nsid, Some(XrpcBody::json(encoded)), options)
            .await?;
        decode_response_json(&resp.body, nsid)
    }

    /// Calls an XRPC procedure that returns no body.
    pub async fn procedure_empty<Input: Serialize>(
        &self,
        nsid: &str,
        input: &Input,
        options: &BskyCallOptions,
    ) -> Result<(), BskyAgentError> {
        let encoded = serde_json::to_vec(input)
            .map_err(|e| BskyAgentError::InvalidInput(format!("encode {nsid}: {e}")))?;
        self.xrpc_procedure(nsid, Some(XrpcBody::json(encoded)), options)
            .await?;
        Ok(())
    }

    // MARK: Labelers & Moderation Options

    /// Builds `acceptedLabelers` combining app labelers (with `;redact`) and user labelers, deduplicated.
    #[must_use]
    pub fn accepted_labelers(&self, user_labelers: &[Did]) -> Vec<XrpcLabeler> {
        let mut combined: Vec<XrpcLabeler> = self
            .app_labelers
            .iter()
            .map(|did| XrpcLabeler {
                did: did.as_str().to_owned(),
                redact: true,
            })
            .collect();
        combined.extend(user_labelers.iter().map(|did| XrpcLabeler {
            did: did.as_str().to_owned(),
            redact: false,
        }));
        XrpcLabeler::deduplicated(&combined)
    }

    /// Configures `atproto-accept-labelers` on all subsequent client calls.
    pub async fn configure_labelers(&self, user_labelers: &[Did]) -> Result<(), BskyAgentError> {
        let accepted = self.accepted_labelers(user_labelers);
        self.set_raw_labelers(accepted).await
    }

    async fn set_raw_labelers(&self, labelers: Vec<XrpcLabeler>) -> Result<(), BskyAgentError> {
        match &self.transport {
            AgentTransport::Client(client) => client
                .configure_labelers(&labelers)
                .await
                .map_err(|e| BskyAgentError::Transport(e.to_string())),
            AgentTransport::Xrpc { xrpc, .. } => {
                let mut guard = xrpc.write().await;
                let updated = guard.clone().with_labelers(labelers);
                *guard = updated;
                Ok(())
            }
        }
    }

    /// Fetches and interprets custom label definitions for `labelers` plus `self.app_labelers`.
    pub async fn get_label_definitions(
        &self,
        labelers: &[Did],
    ) -> Result<BTreeMap<Did, Vec<InterpretedLabelValueDefinition>>, BskyAgentError> {
        let mut dids = Vec::new();
        for did in self.app_labelers.iter().chain(labelers.iter()) {
            if !dids.contains(did) {
                dids.push(did.clone());
            }
        }
        if dids.is_empty() {
            return Ok(BTreeMap::new());
        }
        let mut params: Vec<(&str, String)> = dids
            .iter()
            .map(|d| ("dids", d.as_str().to_owned()))
            .collect();
        params.push(("detailed", "true".to_owned()));

        let output: GetServicesOutput = self
            .query(
                "app.bsky.labeler.getServices",
                &params,
                &BskyCallOptions::default(),
            )
            .await?;

        let mut definitions = BTreeMap::new();
        for view in output.views {
            if let OutputViews::LabelerViewDetailed(detailed) = view {
                definitions.insert(
                    detailed.creator.did.clone(),
                    interpret_label_value_definitions(&detailed),
                );
            }
        }
        Ok(definitions)
    }

    /// Fetches label definitions for the labelers in `prefs`.
    pub async fn get_label_definitions_for_prefs(
        &self,
        prefs: &ModerationPrefs,
    ) -> Result<BTreeMap<Did, Vec<InterpretedLabelValueDefinition>>, BskyAgentError> {
        let dids: Vec<Did> = prefs.labelers.iter().map(|l| l.did.clone()).collect();
        self.get_label_definitions(&dids).await
    }

    /// Loads preferences, user DID, and labeler definitions for [`crate::moderation::Moderation`].
    pub async fn moderation_options(&self) -> Result<ModerationOptions, BskyAgentError> {
        let prefs = self.get_preferences().await?.moderation_prefs;
        let user_did = self.did().await.ok();
        let defs_tree = self.get_label_definitions_for_prefs(&prefs).await?;
        let mut opts = ModerationOptions::new(user_did, prefs);
        opts.label_defs = defs_tree.into_iter().collect();
        Ok(opts)
    }

    /// Files a moderation report, optionally proxied to a specific labeler (`<did>#atproto_labeler`).
    pub async fn create_moderation_report(
        &self,
        input: &CreateReportInput,
        labeler: Option<&Did>,
    ) -> Result<CreateReportOutput, BskyAgentError> {
        let opts = BskyCallOptions {
            proxy: labeler.cloned().map(ServiceProxy::labeler),
            ..BskyCallOptions::default()
        };
        self.procedure("com.atproto.moderation.createReport", input, &opts)
            .await
    }

    // MARK: Records

    /// Creates a record in the signed-in account's repository.
    pub async fn create_record<Record: Serialize>(
        &self,
        record: &Record,
        collection: Option<&str>,
        rkey: Option<&str>,
        validate: Option<bool>,
        swap_commit: Option<&CidString>,
    ) -> Result<StrongRef, BskyAgentError> {
        let session = self.begin_pinned_session().await?;
        session
            .create_record(record, collection, rkey, validate, swap_commit)
            .await
    }

    /// Creates or replaces a record at `rkey` in the signed-in account's repository.
    pub async fn put_record<Record: Serialize>(
        &self,
        record: &Record,
        collection: Option<&str>,
        rkey: &str,
        validate: Option<bool>,
        swap_record: &RecordSwap,
    ) -> Result<StrongRef, BskyAgentError> {
        let (json, resolved_collection) = record_json(record, collection)?;
        let session = self.begin_pinned_session().await?;
        session
            .put_record_json(&json, &resolved_collection, rkey, validate, swap_record)
            .await
    }

    /// Deletes a record identified by `uri`.
    pub async fn delete_record(&self, uri: &AtUri) -> Result<(), BskyAgentError> {
        let session = self.begin_pinned_session().await?;
        session.delete_record(uri).await
    }

    /// Reads and decodes a record at `uri`, returning `None` on `RecordNotFound`.
    pub async fn get_record<Record: DeserializeOwned>(
        &self,
        uri: &AtUri,
    ) -> Result<Option<(Record, StrongRef)>, BskyAgentError> {
        let (Some(collection), Some(rkey)) = (uri.collection(), uri.rkey()) else {
            return Err(BskyAgentError::InvalidInput(format!(
                "Not a record URI: {}",
                uri.as_str()
            )));
        };
        let Some(raw) = self
            .get_record_json(uri.authority().as_str(), collection.as_str(), rkey.as_str())
            .await?
        else {
            return Ok(None);
        };
        let nsid = "com.atproto.repo.getRecord";
        let Some(strong_ref) = raw.strong_ref() else {
            return Err(BskyAgentError::InvalidResponse {
                nsid: nsid.to_owned(),
                reason: "Missing or malformed record URI or CID".to_owned(),
            });
        };
        let record = serde_json::from_value::<Record>(raw.value).map_err(|e| {
            BskyAgentError::InvalidResponse {
                nsid: nsid.to_owned(),
                reason: format!("Record could not be decoded: {e}"),
            }
        })?;
        Ok(Some((record, strong_ref)))
    }

    async fn get_record_json(
        &self,
        repo: &str,
        collection: &str,
        rkey: &str,
    ) -> Result<Option<RawRecord>, BskyAgentError> {
        let nsid = "com.atproto.repo.getRecord";
        let resp = match self
            .xrpc_query(
                nsid,
                &[
                    ("repo", repo.to_owned()),
                    ("collection", collection.to_owned()),
                    ("rkey", rkey.to_owned()),
                ],
                &BskyCallOptions::default(),
            )
            .await
        {
            Ok(resp) => resp,
            Err(err) if err.xrpc_error_name() == Some("RecordNotFound") => return Ok(None),
            Err(err) => return Err(err),
        };
        decode_raw_record(&resp.body, nsid).map(Some)
    }

    async fn upsert_record_json<F>(
        &self,
        collection: &str,
        rkey: &str,
        transform: F,
    ) -> Result<StrongRef, BskyAgentError>
    where
        F: FnMut(Option<&RawRecord>) -> Result<JsonValue, BskyAgentError>,
    {
        let session = self.begin_pinned_session().await?;
        session
            .upsert_record_json(collection, rkey, transform)
            .await
    }

    // MARK: Posts, Replies, Gates, Blobs, Handles

    /// Publishes plain text, automatically resolving mentioned handles to DIDs.
    #[allow(clippy::too_many_arguments)]
    pub async fn post_text(
        &self,
        text: &str,
        reply: Option<ReplyRef>,
        embed: Option<PostEmbedBuilder>,
        langs: Option<Vec<String>>,
        labels: Option<Vec<String>>,
        tags: Option<Vec<String>>,
        created_at: Option<Datetime>,
    ) -> Result<StrongRef, BskyAgentError> {
        let session = self.begin_pinned_session().await?;
        self.post_text_on_session(
            &session, text, reply, embed, langs, labels, tags, created_at,
        )
        .await
    }

    #[allow(clippy::too_many_arguments)]
    async fn post_text_on_session(
        &self,
        session: &PinnedAgentSession<'_>,
        text: &str,
        reply: Option<ReplyRef>,
        embed: Option<PostEmbedBuilder>,
        langs: Option<Vec<String>>,
        labels: Option<Vec<String>>,
        tags: Option<Vec<String>>,
        created_at: Option<Datetime>,
    ) -> Result<StrongRef, BskyAgentError> {
        let mut rt = RichText::from_text(text);
        rt.detect_facets(|handle| async move { self.resolve_handle(&handle).await.ok().flatten() })
            .await;
        let record = build_post_record(&rt, reply, embed, langs, labels, tags, created_at)?;
        session
            .create_record(&record, Some(Post::TYPE_IDENTIFIER), None, None, None)
            .await
    }

    /// Publishes a post with prebuilt `RichText` text and facets.
    #[allow(clippy::too_many_arguments)]
    pub async fn post_rich_text(
        &self,
        rich_text: &RichText,
        reply: Option<ReplyRef>,
        embed: Option<PostEmbedBuilder>,
        langs: Option<Vec<String>>,
        labels: Option<Vec<String>>,
        tags: Option<Vec<String>>,
        created_at: Option<Datetime>,
    ) -> Result<StrongRef, BskyAgentError> {
        let record = build_post_record(rich_text, reply, embed, langs, labels, tags, created_at)?;
        self.post_record(&record).await
    }

    /// Publishes a formed `app.bsky.feed.post` record.
    pub async fn post_record(&self, record: &Post) -> Result<StrongRef, BskyAgentError> {
        self.create_record(record, Some(Post::TYPE_IDENTIFIER), None, None, None)
            .await
    }

    /// Deletes one of the account's posts.
    pub async fn delete_post(&self, uri: &AtUri) -> Result<(), BskyAgentError> {
        let _ = record_location(uri, Post::TYPE_IDENTIFIER)?;
        self.delete_record(uri).await
    }

    /// Builds a `ReplyRef` for `parent` by fetching the parent record to find the thread root.
    pub async fn reply_ref(&self, parent: StrongRef) -> Result<ReplyRef, BskyAgentError> {
        let (repo, rkey) = record_location(&parent.uri, Post::TYPE_IDENTIFIER)?;
        let Some(raw) = self
            .get_record_json(repo, Post::TYPE_IDENTIFIER, rkey)
            .await?
        else {
            return Err(BskyAgentError::InvalidInput(format!(
                "The post being replied to does not exist: {}",
                parent.uri.as_str()
            )));
        };
        if let Some(root_val) = raw.value.get("reply").and_then(|r| r.get("root"))
            && let Ok(root_ref) = serde_json::from_value::<StrongRef>(root_val.clone())
        {
            return Ok(ReplyRef::new(root_ref, parent));
        }
        Ok(ReplyRef::new(parent.clone(), parent))
    }

    /// Builds a `ReplyRef` directly from a `PostView` without a network read.
    #[must_use]
    pub fn reply_ref_from_view(&self, parent: &PostView) -> ReplyRef {
        let parent_ref = StrongRef::new(parent.uri.clone(), parent.cid.clone());
        if let Ok(record) = Post::from_value(parent.record.clone())
            && let Some(reply) = record.reply
        {
            return ReplyRef::new(reply.root, parent_ref);
        }
        ReplyRef::new(parent_ref.clone(), parent_ref)
    }

    /// Replies to `parent`, detecting facets in `text`.
    pub async fn reply(
        &self,
        parent: StrongRef,
        text: &str,
        embed: Option<PostEmbedBuilder>,
        langs: Option<Vec<String>>,
        labels: Option<Vec<String>>,
    ) -> Result<StrongRef, BskyAgentError> {
        let reference = self.reply_ref(parent).await?;
        self.post_text(text, Some(reference), embed, langs, labels, None, None)
            .await
    }

    /// Quote-posts `record`, detecting facets in `text`.
    pub async fn quote(
        &self,
        record: StrongRef,
        text: &str,
        media: Option<PostEmbedBuilder>,
        langs: Option<Vec<String>>,
        labels: Option<Vec<String>>,
    ) -> Result<StrongRef, BskyAgentError> {
        let embed = match media {
            Some(m) => m.quoting(record),
            None => PostEmbedBuilder::quote(record),
        };
        self.post_text(text, None, Some(embed), langs, labels, None, None)
            .await
    }

    /// Updates or creates the threadgate (`app.bsky.feed.threadgate`) on `post`, preserving unmodeled fields.
    pub async fn set_threadgate(
        &self,
        post: &AtUri,
        allow: Option<Vec<ThreadgateAllow>>,
    ) -> Result<StrongRef, BskyAgentError> {
        let (_, rkey) = record_location(post, Post::TYPE_IDENTIFIER)?;
        let mut gate = Threadgate::new(post.clone(), now_datetime());
        gate.allow = allow;
        self.update_gate(&gate, Threadgate::TYPE_IDENTIFIER, rkey, "allow")
            .await
    }

    /// Updates or creates the postgate (`app.bsky.feed.postgate`) on `post`, preserving unmodeled fields.
    pub async fn set_postgate(
        &self,
        post: &AtUri,
        embedding_rules: Option<Vec<PostgateEmbeddingRules>>,
    ) -> Result<StrongRef, BskyAgentError> {
        let (_, rkey) = record_location(post, Post::TYPE_IDENTIFIER)?;
        let mut gate = Postgate::new(now_datetime(), post.clone());
        gate.embedding_rules = embedding_rules;
        self.update_gate(&gate, Postgate::TYPE_IDENTIFIER, rkey, "embeddingRules")
            .await
    }

    async fn update_gate<Gate: Serialize>(
        &self,
        gate: &Gate,
        collection: &str,
        rkey: &str,
        rule_key: &str,
    ) -> Result<StrongRef, BskyAgentError> {
        let (fresh, _) = record_json(gate, Some(collection))?;
        let Some(fresh_obj) = fresh.as_object() else {
            return Err(BskyAgentError::InvalidInput(
                "A record must encode to a JSON object".to_owned(),
            ));
        };
        let fresh_type = fresh_obj.get("$type").cloned();
        let fresh_post = fresh_obj.get("post").cloned();
        let fresh_rule = fresh_obj.get(rule_key).cloned();
        let fresh_created_at = fresh_obj.get("createdAt").cloned();

        self.upsert_record_json(collection, rkey, |existing| {
            let Some(existing) = existing else {
                return Ok(fresh.clone());
            };
            let Some(mut record) = existing.value.as_object().cloned() else {
                return Ok(fresh.clone());
            };
            if let Some(val) = &fresh_type {
                record.insert("$type".to_owned(), val.clone());
            } else {
                record.remove("$type");
            }
            if let Some(val) = &fresh_post {
                record.insert("post".to_owned(), val.clone());
            } else {
                record.remove("post");
            }
            if let Some(val) = &fresh_rule {
                record.insert(rule_key.to_owned(), val.clone());
            } else {
                record.remove(rule_key);
            }
            if !record.contains_key("createdAt")
                && let Some(val) = &fresh_created_at
            {
                record.insert("createdAt".to_owned(), val.clone());
            }
            Ok(JsonValue::Object(record))
        })
        .await
    }

    /// Uploads an image blob, stripping container metadata by default.
    pub async fn upload_image(
        &self,
        data: Bytes,
        mime_type: &str,
        strip_metadata: bool,
    ) -> Result<Blob, BskyAgentError> {
        let prepared = prepared_image(&data, mime_type, strip_metadata)?;
        self.upload_blob(prepared, mime_type).await
    }

    /// Publishes a post with 1..=4 uploaded images (stripping metadata from ALL images before any upload).
    #[allow(clippy::too_many_arguments)]
    pub async fn post_with_images(
        &self,
        text: &str,
        images: &[PostImage],
        strip_image_metadata: bool,
        quote: Option<StrongRef>,
        reply: Option<ReplyRef>,
        langs: Option<Vec<String>>,
        labels: Option<Vec<String>>,
        tags: Option<Vec<String>>,
        created_at: Option<Datetime>,
    ) -> Result<StrongRef, BskyAgentError> {
        if images.is_empty() || images.len() > PostEmbedBuilder::MAX_IMAGES {
            return Err(BskyAgentError::InvalidInput(format!(
                "A post embeds between 1 and {} images, got {}",
                PostEmbedBuilder::MAX_IMAGES,
                images.len()
            )));
        }
        let session = self.begin_pinned_session().await?;
        let mut prepared = Vec::with_capacity(images.len());
        for image in images {
            prepared.push(prepared_image(
                &image.data,
                &image.mime_type,
                strip_image_metadata,
            )?);
        }
        let mut uploaded = Vec::with_capacity(images.len());
        for (image, payload) in images.iter().zip(prepared) {
            let blob = session.upload_blob(payload, &image.mime_type).await?;
            let mut img = EmbedImage::new(blob, image.alt.clone());
            img.aspect_ratio.clone_from(&image.aspect_ratio);
            uploaded.push(img);
        }
        let embed = PostEmbedBuilder::images(uploaded)?;
        let embed = match quote {
            Some(q) => embed.quoting(q),
            None => embed,
        };
        self.post_text_on_session(
            &session,
            text,
            reply,
            Some(embed),
            langs,
            labels,
            tags,
            created_at,
        )
        .await
    }

    async fn set_profile_image(
        &self,
        data: Bytes,
        mime_type: &str,
        strip_metadata: bool,
        is_avatar: bool,
    ) -> Result<StrongRef, BskyAgentError> {
        let session = self.begin_pinned_session().await?;
        let blob = session
            .upload_image(data, mime_type, strip_metadata)
            .await?;
        Self::upsert_profile_on_session(&session, |existing| {
            let mut profile = ProfileUpdate::from_existing(existing);
            if is_avatar {
                profile.avatar = Some(blob.clone());
            } else {
                profile.banner = Some(blob.clone());
            }
            Ok(profile.into_record())
        })
        .await
    }

    /// Uploads and sets the account avatar image.
    pub async fn set_avatar(
        &self,
        data: Bytes,
        mime_type: &str,
        strip_metadata: bool,
    ) -> Result<StrongRef, BskyAgentError> {
        self.set_profile_image(data, mime_type, strip_metadata, true)
            .await
    }

    /// Uploads and sets the account banner image.
    pub async fn set_banner(
        &self,
        data: Bytes,
        mime_type: &str,
        strip_metadata: bool,
    ) -> Result<StrongRef, BskyAgentError> {
        self.set_profile_image(data, mime_type, strip_metadata, false)
            .await
    }

    /// Uploads raw blob bytes via `com.atproto.repo.uploadBlob`.
    pub async fn upload_blob(&self, data: Bytes, mime_type: &str) -> Result<Blob, BskyAgentError> {
        let session = self.begin_pinned_session().await?;
        session.upload_blob(data, mime_type).await
    }

    /// Resolves a handle to its DID (`com.atproto.identity.resolveHandle`), returning `None` on HTTP 400.
    pub async fn resolve_handle(&self, handle: &str) -> Result<Option<Did>, BskyAgentError> {
        let nsid = "com.atproto.identity.resolveHandle";
        let resp = match self
            .xrpc_query(
                nsid,
                &[("handle", handle.to_owned())],
                &BskyCallOptions::default(),
            )
            .await
        {
            Ok(resp) => resp,
            Err(BskyAgentError::Xrpc { status: 400, .. }) => return Ok(None),
            Err(err) => return Err(err),
        };
        let json: JsonValue = decode_response_json(&resp.body, nsid)?;
        let Some(did_str) = json.get("did").and_then(JsonValue::as_str) else {
            return Err(BskyAgentError::InvalidResponse {
                nsid: nsid.to_owned(),
                reason: "Missing or malformed did".to_owned(),
            });
        };
        let did = did_str
            .parse::<Did>()
            .map_err(|_| BskyAgentError::InvalidResponse {
                nsid: nsid.to_owned(),
                reason: "Missing or malformed did".to_owned(),
            })?;
        Ok(Some(did))
    }

    // MARK: Likes, Reposts, Follows, Blocks, Mutes, Notifications, Profile

    /// Likes a record.
    pub async fn like(
        &self,
        subject: StrongRef,
        via: Option<StrongRef>,
    ) -> Result<StrongRef, BskyAgentError> {
        let mut record = FeedLike::new(subject, now_datetime());
        record.via = via;
        self.create_record(&record, Some(FeedLike::TYPE_IDENTIFIER), None, None, None)
            .await
    }

    /// Deletes a like record.
    pub async fn delete_like(&self, like_uri: &AtUri) -> Result<(), BskyAgentError> {
        let _ = record_location(like_uri, FeedLike::TYPE_IDENTIFIER)?;
        self.delete_record(like_uri).await
    }

    /// Reposts a post.
    pub async fn repost(
        &self,
        subject: StrongRef,
        via: Option<StrongRef>,
    ) -> Result<StrongRef, BskyAgentError> {
        let mut record = FeedRepost::new(subject, now_datetime());
        record.via = via;
        self.create_record(&record, Some(FeedRepost::TYPE_IDENTIFIER), None, None, None)
            .await
    }

    /// Deletes a repost record.
    pub async fn delete_repost(&self, repost_uri: &AtUri) -> Result<(), BskyAgentError> {
        let _ = record_location(repost_uri, FeedRepost::TYPE_IDENTIFIER)?;
        self.delete_record(repost_uri).await
    }

    /// Follows an account.
    pub async fn follow(
        &self,
        subject: Did,
        via: Option<StrongRef>,
    ) -> Result<StrongRef, BskyAgentError> {
        let mut record = GraphFollow::new(subject, now_datetime());
        record.via = via;
        self.create_record(
            &record,
            Some(GraphFollow::TYPE_IDENTIFIER),
            None,
            None,
            None,
        )
        .await
    }

    /// Unfollows an account by deleting its follow record.
    pub async fn delete_follow(&self, follow_uri: &AtUri) -> Result<(), BskyAgentError> {
        let _ = record_location(follow_uri, GraphFollow::TYPE_IDENTIFIER)?;
        self.delete_record(follow_uri).await
    }

    /// Blocks an account.
    pub async fn block(&self, subject: Did) -> Result<StrongRef, BskyAgentError> {
        let record = GraphBlock::new(subject, now_datetime());
        self.create_record(&record, Some(GraphBlock::TYPE_IDENTIFIER), None, None, None)
            .await
    }

    /// Unblocks an account.
    pub async fn delete_block(&self, block_uri: &AtUri) -> Result<(), BskyAgentError> {
        let _ = record_location(block_uri, GraphBlock::TYPE_IDENTIFIER)?;
        self.delete_record(block_uri).await
    }

    /// Blocks a moderation list.
    pub async fn block_mod_list(&self, list: AtUri) -> Result<StrongRef, BskyAgentError> {
        let _ = record_location(&list, "app.bsky.graph.list")?;
        let record = GraphListblock::new(list, now_datetime());
        self.create_record(
            &record,
            Some(GraphListblock::TYPE_IDENTIFIER),
            None,
            None,
            None,
        )
        .await
    }

    /// Unblocks a moderation list, returning whether a block record was found and removed.
    pub async fn unblock_mod_list(&self, list: &AtUri) -> Result<bool, BskyAgentError> {
        let session = self.begin_pinned_session().await?;
        let nsid = "app.bsky.graph.getList";
        let resp = session
            .xrpc_query(
                nsid,
                &[
                    ("list", list.as_str().to_owned()),
                    ("limit", "1".to_owned()),
                ],
                &BskyCallOptions::default(),
            )
            .await?;
        let json: JsonValue = decode_response_json(&resp.body, nsid)?;
        let Some(blocked) = json
            .get("list")
            .and_then(|l| l.get("viewer"))
            .and_then(|v| v.get("blocked"))
            .and_then(JsonValue::as_str)
        else {
            return Ok(false);
        };
        let block_uri = blocked
            .parse::<AtUri>()
            .map_err(|_| BskyAgentError::InvalidResponse {
                nsid: nsid.to_owned(),
                reason: "viewer.blocked is not an at:// URI".to_owned(),
            })?;
        let _ = record_location(&block_uri, GraphListblock::TYPE_IDENTIFIER)?;
        session.delete_record(&block_uri).await?;
        Ok(true)
    }

    /// Mutes an account.
    pub async fn mute(&self, actor: &AtIdentifier) -> Result<(), BskyAgentError> {
        let body = serde_json::json!({ "actor": actor.as_str() });
        self.procedure_empty(
            "app.bsky.graph.muteActor",
            &body,
            &BskyCallOptions::default(),
        )
        .await
    }

    /// Unmutes an account.
    pub async fn unmute(&self, actor: &AtIdentifier) -> Result<(), BskyAgentError> {
        let body = serde_json::json!({ "actor": actor.as_str() });
        self.procedure_empty(
            "app.bsky.graph.unmuteActor",
            &body,
            &BskyCallOptions::default(),
        )
        .await
    }

    /// Mutes a moderation list.
    pub async fn mute_mod_list(&self, list: &AtUri) -> Result<(), BskyAgentError> {
        let body = serde_json::json!({ "list": list.as_str() });
        self.procedure_empty(
            "app.bsky.graph.muteActorList",
            &body,
            &BskyCallOptions::default(),
        )
        .await
    }

    /// Unmutes a moderation list.
    pub async fn unmute_mod_list(&self, list: &AtUri) -> Result<(), BskyAgentError> {
        let body = serde_json::json!({ "list": list.as_str() });
        self.procedure_empty(
            "app.bsky.graph.unmuteActorList",
            &body,
            &BskyCallOptions::default(),
        )
        .await
    }

    /// Mutes a thread root.
    pub async fn mute_thread(&self, root: &AtUri) -> Result<(), BskyAgentError> {
        let body = serde_json::json!({ "root": root.as_str() });
        self.procedure_empty(
            "app.bsky.graph.muteThread",
            &body,
            &BskyCallOptions::default(),
        )
        .await
    }

    /// Unmutes a thread root.
    pub async fn unmute_thread(&self, root: &AtUri) -> Result<(), BskyAgentError> {
        let body = serde_json::json!({ "root": root.as_str() });
        self.procedure_empty(
            "app.bsky.graph.unmuteThread",
            &body,
            &BskyCallOptions::default(),
        )
        .await
    }

    /// Marks notifications seen up to `seen_at` (defaults to now).
    pub async fn update_seen_notifications(
        &self,
        seen_at: Option<Datetime>,
    ) -> Result<(), BskyAgentError> {
        let ts = seen_at.unwrap_or_else(now_datetime);
        let body = serde_json::json!({ "seenAt": ts.as_str() });
        self.procedure_empty(
            "app.bsky.notification.updateSeen",
            &body,
            &BskyCallOptions::default(),
        )
        .await
    }

    /// Creates or updates `app.bsky.actor.profile/self` via compare-and-swap, carrying over unmodeled fields.
    pub async fn upsert_profile<F>(&self, update: F) -> Result<StrongRef, BskyAgentError>
    where
        F: FnMut(Option<&Profile>) -> Result<Profile, BskyAgentError>,
    {
        let session = self.begin_pinned_session().await?;
        Self::upsert_profile_on_session(&session, update).await
    }

    async fn upsert_profile_on_session<F>(
        session: &PinnedAgentSession<'_>,
        mut update: F,
    ) -> Result<StrongRef, BskyAgentError>
    where
        F: FnMut(Option<&Profile>) -> Result<Profile, BskyAgentError>,
    {
        let collection = Profile::TYPE_IDENTIFIER;
        session
            .upsert_record_json(collection, "self", |existing| {
                let existing_profile = existing
                    .and_then(|raw| serde_json::from_value::<Profile>(raw.value.clone()).ok());
                let updated = update(existing_profile.as_ref())?;
                let mut record = record_json(&updated, Some(collection))?.0;
                if let (Some(existing), Some(existing_profile)) = (existing, existing_profile)
                    && let (Some(stored), Some(modeled), Some(record_obj)) = (
                        existing.value.as_object(),
                        serde_json::to_value(&existing_profile)
                            .ok()
                            .and_then(|v| v.as_object().cloned()),
                        record.as_object_mut(),
                    )
                {
                    for (k, v) in stored {
                        if !modeled.contains_key(k) && !record_obj.contains_key(k) {
                            record_obj.insert(k.clone(), v.clone());
                        }
                    }
                }
                Ok(record)
            })
            .await
    }

    // MARK: Video

    /// Uploads a video via `app.bsky.video.uploadVideo` and polls `app.bsky.video.getJobStatus` until completion.
    #[allow(clippy::too_many_arguments)]
    pub async fn upload_video<F>(
        &self,
        data: Bytes,
        mime_type: &str,
        name: &str,
        service: Option<Url>,
        pds_did: Option<&Did>,
        poll_interval: Duration,
        timeout: Duration,
        mut on_progress: F,
    ) -> Result<Blob, BskyAgentError>
    where
        F: FnMut(&JobStatus),
    {
        let did = self.did().await?;
        let service_url = match service {
            Some(url) => url,
            None => Url::parse(VIDEO_SERVICE_URL)
                .map_err(|e| BskyAgentError::InvalidInput(e.to_string()))?,
        };
        let audience = self.video_upload_audience(pds_did).await?;
        let token = self.fetch_video_upload_token(&audience).await?;

        let upload_nsid = "app.bsky.video.uploadVideo";
        let (upload_status, upload_body) = self
            .send_video_upload(&service_url, did.as_str(), name, data, mime_type, &token)
            .await?;
        let upload_json: Option<JsonValue> = serde_json::from_slice(&upload_body).ok();
        let reports_existing_job = upload_status == 409
            && upload_json
                .as_ref()
                .and_then(|v| v.get("jobId"))
                .and_then(JsonValue::as_str)
                .is_some();
        if !((200..=299).contains(&upload_status) || reports_existing_job) {
            return Err(BskyAgentError::Xrpc {
                nsid: upload_nsid.to_owned(),
                status: upload_status,
                error: upload_json
                    .as_ref()
                    .and_then(|v| v.get("error"))
                    .and_then(JsonValue::as_str)
                    .map(ToOwned::to_owned),
                message: upload_json
                    .as_ref()
                    .and_then(|v| v.get("message"))
                    .and_then(JsonValue::as_str)
                    .map(ToOwned::to_owned),
            });
        }
        let Some(upload_json) = upload_json else {
            return Err(BskyAgentError::InvalidResponse {
                nsid: upload_nsid.to_owned(),
                reason: "Body is not JSON".to_owned(),
            });
        };
        let first = upload_json.get("jobStatus").unwrap_or(&upload_json);
        let Some(job_id) = first
            .get("jobId")
            .and_then(JsonValue::as_str)
            .map(ToOwned::to_owned)
        else {
            return Err(BskyAgentError::InvalidResponse {
                nsid: upload_nsid.to_owned(),
                reason: "Missing jobId".to_owned(),
            });
        };
        if let Some(blob) = check_video_job(first, &job_id, &mut on_progress)? {
            return Ok(blob);
        }
        self.poll_video_job(&service_url, &job_id, poll_interval, timeout, on_progress)
            .await
    }

    async fn video_upload_audience(&self, pds_did: Option<&Did>) -> Result<String, BskyAgentError> {
        if let Some(pds_did) = pds_did {
            return Ok(pds_did.as_str().to_owned());
        }
        let base = self.base_url().await;
        let Some(host) = base.host_str() else {
            return Err(BskyAgentError::InvalidInput(
                "Cannot derive the PDS DID; pass pds_did".to_owned(),
            ));
        };
        Ok(match base.port() {
            Some(port) => format!("did:web:{host}%3A{port}"),
            None => format!("did:web:{host}"),
        })
    }

    async fn fetch_video_upload_token(&self, audience: &str) -> Result<String, BskyAgentError> {
        let auth_nsid = "com.atproto.server.getServiceAuth";
        let expiry = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or(Duration::ZERO)
            .as_secs()
            + 30 * 60;
        let auth_resp = self
            .xrpc_query(
                auth_nsid,
                &[
                    ("aud", audience.to_owned()),
                    ("lxm", "com.atproto.repo.uploadBlob".to_owned()),
                    ("exp", expiry.to_string()),
                ],
                &BskyCallOptions::default(),
            )
            .await?;
        let auth_json: JsonValue = decode_response_json(&auth_resp.body, auth_nsid)?;
        auth_json
            .get("token")
            .and_then(JsonValue::as_str)
            .map(ToOwned::to_owned)
            .ok_or_else(|| BskyAgentError::InvalidResponse {
                nsid: auth_nsid.to_owned(),
                reason: "Missing token".to_owned(),
            })
    }

    async fn poll_video_job<F>(
        &self,
        service_url: &Url,
        job_id: &str,
        poll_interval: Duration,
        timeout: Duration,
        mut on_progress: F,
    ) -> Result<Blob, BskyAgentError>
    where
        F: FnMut(&JobStatus),
    {
        let status_nsid = "app.bsky.video.getJobStatus";
        let started = Instant::now();
        while started.elapsed() < timeout {
            sleep(poll_interval).await;
            let status_opts = BskyCallOptions {
                service: Some(service_url.clone()),
                ..BskyCallOptions::default()
            };
            let status_resp = self
                .xrpc_query(status_nsid, &[("jobId", job_id.to_owned())], &status_opts)
                .await?;
            let status_json: JsonValue = decode_response_json(&status_resp.body, status_nsid)?;
            let Some(job) = status_json.get("jobStatus") else {
                return Err(BskyAgentError::InvalidResponse {
                    nsid: status_nsid.to_owned(),
                    reason: "Missing jobStatus".to_owned(),
                });
            };
            if let Some(blob) = check_video_job(job, job_id, &mut on_progress)? {
                return Ok(blob);
            }
        }
        Err(BskyAgentError::VideoProcessingTimedOut {
            job_id: job_id.to_owned(),
        })
    }

    async fn send_video_upload(
        &self,
        service: &Url,
        did: &str,
        name: &str,
        data: Bytes,
        mime_type: &str,
        bearer_token: &str,
    ) -> Result<(u16, Bytes), BskyAgentError> {
        let mut url = service.clone();
        {
            let mut segs = url.path_segments_mut().map_err(|()| {
                BskyAgentError::InvalidInput("Video service URL cannot be a base".to_owned())
            })?;
            segs.pop_if_empty();
            segs.push("xrpc");
            segs.push("app.bsky.video.uploadVideo");
        }
        url.query_pairs_mut()
            .append_pair("did", did)
            .append_pair("name", name);

        let ct = HeaderValue::from_str(mime_type)
            .map_err(|_| BskyAgentError::InvalidInput(format!("Invalid mime type: {mime_type}")))?;
        let auth = HeaderValue::from_str(&format!("Bearer {bearer_token}"))
            .map_err(|_| BskyAgentError::InvalidInput("Invalid service auth token".to_owned()))?;
        let req = Request::builder()
            .method(Method::POST)
            .uri(url.as_str())
            .header(http::header::ACCEPT, "application/json")
            .header(http::header::CONTENT_TYPE, ct)
            .header(http::header::AUTHORIZATION, auth)
            .body(data)
            .map_err(|e| BskyAgentError::Transport(e.to_string()))?;

        let mut send_opts = SendOptions::new();
        if url.scheme() == "http" && is_loopback_host(url.host_str()) {
            send_opts.allow_loopback = true;
        }
        let xrpc = self.xrpc_snapshot().await;
        let resp = xrpc
            .transport()
            .send_dyn(req, &send_opts)
            .await
            .map_err(|e| BskyAgentError::Transport(e.to_string()))?;
        Ok((resp.status().as_u16(), resp.into_body()))
    }

    // MARK: Preferences

    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    fn preferences_engine(&self) -> BskyPreferencesEngine {
        let backend: Arc<dyn BskyPreferencesBackend> = Arc::new(NetworkPreferencesBackend {
            agent: self.clone(),
        });
        BskyPreferencesEngine::new(
            backend,
            Arc::clone(&self.preferences_lock),
            self.app_labelers.clone(),
        )
    }

    /// Fetches and parses account preferences (auto-migrating v1 feeds & configuring labelers).
    pub async fn get_preferences(&self) -> Result<BskyPreferences, BskyAgentError> {
        self.preferences_engine().get_preferences().await
    }

    /// Replaces the saved-feeds list (v2).
    pub async fn overwrite_saved_feeds(
        &self,
        saved_feeds: &[SavedFeed],
    ) -> Result<Vec<SavedFeed>, BskyAgentError> {
        self.preferences_engine()
            .overwrite_saved_feeds(saved_feeds)
            .await
    }

    /// Updates pinned flags of saved feeds matched by ID.
    pub async fn update_saved_feeds(
        &self,
        saved_feeds: &[SavedFeed],
    ) -> Result<Vec<SavedFeed>, BskyAgentError> {
        self.preferences_engine()
            .update_saved_feeds(saved_feeds)
            .await
    }

    /// Appends saved feeds with fresh TIDs.
    pub async fn add_saved_feeds(
        &self,
        saved_feeds: &[BskyNewSavedFeed],
    ) -> Result<Vec<SavedFeed>, BskyAgentError> {
        self.preferences_engine().add_saved_feeds(saved_feeds).await
    }

    /// Removes saved feeds by ID.
    pub async fn remove_saved_feeds(
        &self,
        ids: &[String],
    ) -> Result<Vec<SavedFeed>, BskyAgentError> {
        self.preferences_engine().remove_saved_feeds(ids).await
    }

    /// Legacy v1: replaces saved and pinned feed URI arrays.
    pub async fn set_saved_feeds(
        &self,
        saved: &[AtUri],
        pinned: &[AtUri],
    ) -> Result<BskyLegacyFeeds, BskyAgentError> {
        self.preferences_engine()
            .set_saved_feeds(saved, pinned)
            .await
    }

    /// Legacy v1: saves a feed URI.
    pub async fn add_saved_feed(&self, uri: &AtUri) -> Result<BskyLegacyFeeds, BskyAgentError> {
        self.preferences_engine().add_saved_feed(uri).await
    }

    /// Legacy v1: removes a feed URI.
    pub async fn remove_saved_feed(&self, uri: &AtUri) -> Result<BskyLegacyFeeds, BskyAgentError> {
        self.preferences_engine().remove_saved_feed(uri).await
    }

    /// Legacy v1: saves and pins a feed URI.
    pub async fn add_pinned_feed(&self, uri: &AtUri) -> Result<BskyLegacyFeeds, BskyAgentError> {
        self.preferences_engine().add_pinned_feed(uri).await
    }

    /// Legacy v1: unpins a feed URI.
    pub async fn remove_pinned_feed(&self, uri: &AtUri) -> Result<BskyLegacyFeeds, BskyAgentError> {
        self.preferences_engine().remove_pinned_feed(uri).await
    }

    /// Enables or disables adult content.
    pub async fn set_adult_content_enabled(&self, enabled: bool) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .set_adult_content_enabled(enabled)
            .await
    }

    /// Sets how content carrying `label` is treated (globally or per labeler).
    pub async fn set_content_label_pref(
        &self,
        label: &str,
        value: LabelPreference,
        labeler_did: Option<&Did>,
    ) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .set_content_label_pref(label, value, labeler_did)
            .await
    }

    /// Subscribes to a labeler and updates `atproto-accept-labelers`.
    pub async fn add_labeler(&self, did: &Did) -> Result<(), BskyAgentError> {
        self.preferences_engine().add_labeler(did).await
    }

    /// Unsubscribes from a labeler and updates `atproto-accept-labelers`.
    pub async fn remove_labeler(&self, did: &Did) -> Result<(), BskyAgentError> {
        self.preferences_engine().remove_labeler(did).await
    }

    /// Mutes a word or tag.
    pub async fn add_muted_word(
        &self,
        value: &str,
        targets: &[MutedWordTarget],
        actor_target: Option<&str>,
        expires_at: Option<&Datetime>,
    ) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .add_muted_word(value, targets, actor_target, expires_at)
            .await
    }

    /// Mutes multiple words in order.
    pub async fn add_muted_words(&self, words: &[MutedWord]) -> Result<(), BskyAgentError> {
        self.preferences_engine().add_muted_words(words).await
    }

    /// Updates a stored muted word.
    pub async fn update_muted_word(&self, word: &MutedWord) -> Result<(), BskyAgentError> {
        self.preferences_engine().update_muted_word(word).await
    }

    /// Unmutes a stored word.
    pub async fn remove_muted_word(&self, word: &MutedWord) -> Result<(), BskyAgentError> {
        self.preferences_engine().remove_muted_word(word).await
    }

    /// Unmutes multiple words in order.
    pub async fn remove_muted_words(&self, words: &[MutedWord]) -> Result<(), BskyAgentError> {
        self.preferences_engine().remove_muted_words(words).await
    }

    /// Hides a post from feeds.
    pub async fn hide_post(&self, uri: &AtUri) -> Result<(), BskyAgentError> {
        self.preferences_engine().hide_post(uri).await
    }

    /// Unhides a post.
    pub async fn unhide_post(&self, uri: &AtUri) -> Result<(), BskyAgentError> {
        self.preferences_engine().unhide_post(uri).await
    }

    /// Declares or clears (`None`) birth date.
    pub async fn set_personal_details(
        &self,
        birth_date: Option<&Datetime>,
    ) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .set_personal_details(birth_date)
            .await
    }

    /// Updates view preferences for `feed`.
    pub async fn set_feed_view_prefs(
        &self,
        feed: &str,
        update: &BskyFeedViewPreferenceUpdate,
    ) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .set_feed_view_prefs(feed, update)
            .await
    }

    /// Sets thread reply sort order.
    pub async fn set_thread_view_prefs(&self, sort: &str) -> Result<(), BskyAgentError> {
        self.preferences_engine().set_thread_view_prefs(sort).await
    }

    /// Sets onboarding interests.
    pub async fn set_interests_pref(&self, tags: &[String]) -> Result<(), BskyAgentError> {
        self.preferences_engine().set_interests_pref(tags).await
    }

    /// Sets default reply and quote restrictions for new posts.
    pub async fn set_post_interaction_settings(
        &self,
        settings: &PostInteractionSettingsPref,
    ) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .set_post_interaction_settings(settings)
            .await
    }

    /// Sets verification badge display preference.
    pub async fn set_verification_prefs(&self, hide_badges: bool) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .set_verification_prefs(hide_badges)
            .await
    }

    /// Applies an action to live-event preferences.
    pub async fn update_live_event_preferences(
        &self,
        action: &BskyLiveEventPreferencesAction,
    ) -> Result<BskyLiveEventPreferences, BskyAgentError> {
        self.preferences_engine()
            .update_live_event_preferences(action)
            .await
    }

    /// Appends official app nudges.
    pub async fn bsky_app_queue_nudges(&self, nudges: &[String]) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .bsky_app_queue_nudges(nudges)
            .await
    }

    /// Dismisses official app nudges.
    pub async fn bsky_app_dismiss_nudges(&self, nudges: &[String]) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .bsky_app_dismiss_nudges(nudges)
            .await
    }

    /// Sets or clears (`None`) active onboarding progress guide.
    pub async fn bsky_app_set_active_progress_guide(
        &self,
        guide: Option<&BskyAppProgressGuide>,
    ) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .bsky_app_set_active_progress_guide(guide)
            .await
    }

    /// Records beta user membership.
    pub async fn set_is_beta_user(&self, is_beta_user: bool) -> Result<(), BskyAgentError> {
        self.preferences_engine()
            .set_is_beta_user(is_beta_user)
            .await
    }

    /// Inserts or replaces an official app NUX entry.
    pub async fn bsky_app_upsert_nux(
        &self,
        nux: &petrel_api::generated::app::bsky::actor::defs::Nux,
    ) -> Result<(), BskyAgentError> {
        self.preferences_engine().bsky_app_upsert_nux(nux).await
    }

    /// Removes NUX entries by ID.
    pub async fn bsky_app_remove_nuxs(&self, ids: &[String]) -> Result<(), BskyAgentError> {
        self.preferences_engine().bsky_app_remove_nuxs(ids).await
    }
}

struct NetworkPreferencesBackend {
    agent: BskyAgent,
}

struct NetworkPreferencesSession {
    agent: BskyAgent,
    xrpc: XrpcClient,
    expected_continuity: Option<AuthContinuitySnapshot>,
    expected_did: Option<Did>,
}

impl BskyAgent {
    async fn begin_pinned_session(&self) -> Result<PinnedAgentSession<'_>, BskyAgentError> {
        match &self.transport {
            AgentTransport::Client(client) => {
                let continuity = client.auth_continuity_snapshot().await;
                let did = client
                    .get_did()
                    .await
                    .map_err(|e| BskyAgentError::Transport(e.to_string()))?
                    .ok_or(BskyAgentError::NotAuthenticated)?;
                let xrpc = client.xrpc().await;
                verify_continuity_binding(&self.transport, Some(&continuity), Some(&did)).await?;
                Ok(PinnedAgentSession {
                    agent: self,
                    did,
                    xrpc,
                    expected_continuity: Some(continuity),
                })
            }
            AgentTransport::Xrpc { xrpc, did } => {
                let did = did.clone().ok_or(BskyAgentError::NotAuthenticated)?;
                Ok(PinnedAgentSession {
                    agent: self,
                    did,
                    xrpc: xrpc.read().await.clone(),
                    expected_continuity: None,
                })
            }
        }
    }
}

struct PinnedAgentSession<'a> {
    agent: &'a BskyAgent,
    did: Did,
    xrpc: XrpcClient,
    expected_continuity: Option<AuthContinuitySnapshot>,
}

impl PinnedAgentSession<'_> {
    async fn verify_continuity(&self) -> Result<(), BskyAgentError> {
        verify_continuity_binding(
            &self.agent.transport,
            self.expected_continuity.as_ref(),
            Some(&self.did),
        )
        .await
    }

    async fn xrpc_query(
        &self,
        nsid: &str,
        params: &[(&str, String)],
        options: &BskyCallOptions,
    ) -> Result<XrpcResponse, BskyAgentError> {
        self.verify_continuity().await?;
        let call = BskyAgent::build_call_options(options);
        let pairs: Vec<(&str, &str)> = params.iter().map(|(k, v)| (*k, v.as_str())).collect();
        let resp = match self.xrpc.query(nsid, pairs, &call).await {
            Ok(resp) => resp,
            Err(err) => {
                self.verify_continuity().await?;
                return Err(map_xrpc_error(nsid, err));
            }
        };
        self.verify_continuity().await?;
        Ok(resp)
    }

    async fn xrpc_procedure(
        &self,
        nsid: &str,
        body: Option<XrpcBody>,
        options: &BskyCallOptions,
    ) -> Result<XrpcResponse, BskyAgentError> {
        self.verify_continuity().await?;
        let call = BskyAgent::build_call_options(options);
        let empty: [(&str, &str); 0] = [];
        let resp = match self.xrpc.procedure(nsid, empty, body, &call).await {
            Ok(resp) => resp,
            Err(err) => {
                self.verify_continuity().await?;
                return Err(map_xrpc_error(nsid, err));
            }
        };
        self.verify_continuity().await?;
        Ok(resp)
    }

    async fn upload_blob(&self, data: Bytes, mime_type: &str) -> Result<Blob, BskyAgentError> {
        let nsid = "com.atproto.repo.uploadBlob";
        if mime_type.is_empty() || mime_type.contains(['\r', '\n']) {
            return Err(BskyAgentError::InvalidInput(
                "A blob needs a media type such as image/png".to_owned(),
            ));
        }
        self.verify_continuity().await?;
        let out = match self
            .xrpc
            .upload_blob(data, mime_type, None, &CallOptions::default())
            .await
        {
            Ok(out) => out,
            Err(err) => {
                self.verify_continuity().await?;
                return Err(map_xrpc_error(nsid, err));
            }
        };
        self.verify_continuity().await?;
        Ok(out.blob)
    }

    async fn upload_image(
        &self,
        data: Bytes,
        mime_type: &str,
        strip_metadata: bool,
    ) -> Result<Blob, BskyAgentError> {
        let prepared = prepared_image(&data, mime_type, strip_metadata)?;
        self.upload_blob(prepared, mime_type).await
    }

    async fn create_record<Record: Serialize>(
        &self,
        record: &Record,
        collection: Option<&str>,
        rkey: Option<&str>,
        validate: Option<bool>,
        swap_commit: Option<&CidString>,
    ) -> Result<StrongRef, BskyAgentError> {
        let nsid = "com.atproto.repo.createRecord";
        let (json, resolved_collection) = record_json(record, collection)?;
        let mut body = Map::new();
        body.insert(
            "repo".to_owned(),
            JsonValue::String(self.did.as_str().to_owned()),
        );
        body.insert(
            "collection".to_owned(),
            JsonValue::String(resolved_collection),
        );
        body.insert("record".to_owned(), json);
        if let Some(rkey) = rkey {
            body.insert(
                "rkey".to_owned(),
                JsonValue::String(validated_record_key(rkey)?.to_owned()),
            );
        }
        if let Some(validate) = validate {
            body.insert("validate".to_owned(), JsonValue::Bool(validate));
        }
        if let Some(swap) = swap_commit {
            body.insert(
                "swapCommit".to_owned(),
                JsonValue::String(swap.as_str().to_owned()),
            );
        }
        let encoded = serde_json::to_vec(&JsonValue::Object(body))
            .map_err(|e| BskyAgentError::InvalidInput(e.to_string()))?;
        let resp = self
            .xrpc_procedure(
                nsid,
                Some(XrpcBody::json(encoded)),
                &BskyCallOptions::default(),
            )
            .await?;
        decode_response_json(&resp.body, nsid)
    }

    async fn delete_record(&self, uri: &AtUri) -> Result<(), BskyAgentError> {
        let (Some(collection), Some(rkey)) = (uri.collection(), uri.rkey()) else {
            return Err(BskyAgentError::InvalidInput(format!(
                "Not a record URI: {}",
                uri.as_str()
            )));
        };
        let mut body = Map::new();
        body.insert(
            "repo".to_owned(),
            JsonValue::String(uri.authority().as_str().to_owned()),
        );
        body.insert(
            "collection".to_owned(),
            JsonValue::String(collection.as_str().to_owned()),
        );
        body.insert(
            "rkey".to_owned(),
            JsonValue::String(rkey.as_str().to_owned()),
        );
        let encoded = serde_json::to_vec(&JsonValue::Object(body))
            .map_err(|e| BskyAgentError::InvalidInput(e.to_string()))?;
        self.xrpc_procedure(
            "com.atproto.repo.deleteRecord",
            Some(XrpcBody::json(encoded)),
            &BskyCallOptions::default(),
        )
        .await?;
        Ok(())
    }

    async fn get_record_json(
        &self,
        repo: &str,
        collection: &str,
        rkey: &str,
    ) -> Result<Option<RawRecord>, BskyAgentError> {
        let nsid = "com.atproto.repo.getRecord";
        let resp = match self
            .xrpc_query(
                nsid,
                &[
                    ("repo", repo.to_owned()),
                    ("collection", collection.to_owned()),
                    ("rkey", rkey.to_owned()),
                ],
                &BskyCallOptions::default(),
            )
            .await
        {
            Ok(resp) => resp,
            Err(err) if err.xrpc_error_name() == Some("RecordNotFound") => return Ok(None),
            Err(err) => return Err(err),
        };
        decode_raw_record(&resp.body, nsid).map(Some)
    }

    async fn put_record_json(
        &self,
        record: &JsonValue,
        collection: &str,
        rkey: &str,
        validate: Option<bool>,
        swap_record: &RecordSwap,
    ) -> Result<StrongRef, BskyAgentError> {
        let nsid = "com.atproto.repo.putRecord";
        let mut body = Map::new();
        body.insert(
            "repo".to_owned(),
            JsonValue::String(self.did.as_str().to_owned()),
        );
        body.insert(
            "collection".to_owned(),
            JsonValue::String(collection.to_owned()),
        );
        body.insert(
            "rkey".to_owned(),
            JsonValue::String(validated_record_key(rkey)?.to_owned()),
        );
        body.insert("record".to_owned(), record.clone());
        if let Some(validate) = validate {
            body.insert("validate".to_owned(), JsonValue::Bool(validate));
        }
        match swap_record {
            RecordSwap::Any => {}
            RecordSwap::MustNotExist => {
                body.insert("swapRecord".to_owned(), JsonValue::Null);
            }
            RecordSwap::Matches(cid) => {
                body.insert(
                    "swapRecord".to_owned(),
                    JsonValue::String(cid.as_str().to_owned()),
                );
            }
        }
        let encoded = serde_json::to_vec(&JsonValue::Object(body))
            .map_err(|e| BskyAgentError::InvalidInput(e.to_string()))?;
        let resp = self
            .xrpc_procedure(
                nsid,
                Some(XrpcBody::json(encoded)),
                &BskyCallOptions::default(),
            )
            .await?;
        decode_response_json(&resp.body, nsid)
    }

    async fn upsert_record_json<F>(
        &self,
        collection: &str,
        rkey: &str,
        mut transform: F,
    ) -> Result<StrongRef, BskyAgentError>
    where
        F: FnMut(Option<&RawRecord>) -> Result<JsonValue, BskyAgentError>,
    {
        const MAX_ATTEMPTS: usize = 6;
        for _ in 0..MAX_ATTEMPTS {
            self.verify_continuity().await?;
            let existing = self
                .get_record_json(self.did.as_str(), collection, rkey)
                .await?;
            let record = transform(existing.as_ref())?;
            let swap = if let Some(existing) = &existing {
                let Some(strong_ref) = existing.strong_ref() else {
                    return Err(BskyAgentError::InvalidResponse {
                        nsid: "com.atproto.repo.getRecord".to_owned(),
                        reason: "Missing or malformed record CID".to_owned(),
                    });
                };
                RecordSwap::Matches(strong_ref.cid)
            } else {
                RecordSwap::MustNotExist
            };
            match self
                .put_record_json(&record, collection, rkey, None, &swap)
                .await
            {
                Ok(strong) => return Ok(strong),
                Err(err) if err.xrpc_error_name() == Some("InvalidSwap") => {}
                Err(err) => return Err(err),
            }
        }
        Err(BskyAgentError::SwapRetriesExhausted {
            attempts: MAX_ATTEMPTS,
        })
    }
}

async fn verify_continuity_binding(
    transport: &AgentTransport,
    expected_continuity: Option<&AuthContinuitySnapshot>,
    expected_did: Option<&Did>,
) -> Result<(), BskyAgentError> {
    let Some(expected) = expected_continuity else {
        return Ok(());
    };
    let AgentTransport::Client(client) = transport else {
        return Ok(());
    };
    let current_continuity = client.auth_continuity_snapshot().await;
    let current_did = client
        .get_did()
        .await
        .map_err(|e| BskyAgentError::Transport(e.to_string()))?;
    if current_continuity != *expected || current_did.as_ref() != expected_did {
        return Err(BskyAgentError::AuthContinuityChanged);
    }
    Ok(())
}

impl NetworkPreferencesSession {
    async fn verify_continuity(&self) -> Result<(), BskyAgentError> {
        verify_continuity_binding(
            &self.agent.transport,
            self.expected_continuity.as_ref(),
            self.expected_did.as_ref(),
        )
        .await
    }
}

impl BskyPreferencesSession for NetworkPreferencesSession {
    fn load_preferences(&self) -> BoxFuture<'_, Result<Vec<JsonValue>, BskyAgentError>> {
        Box::pin(async move {
            self.verify_continuity().await?;
            let nsid = "app.bsky.actor.getPreferences";
            let empty: [(&str, &str); 0] = [];
            let call = BskyAgent::build_call_options(&BskyCallOptions::default());
            let resp = match self.xrpc.query(nsid, empty, &call).await {
                Ok(resp) => resp,
                Err(err) => {
                    self.verify_continuity().await?;
                    return Err(map_xrpc_error(nsid, err));
                }
            };
            self.verify_continuity().await?;
            let json: JsonValue = decode_response_json(&resp.body, nsid)?;
            json.get("preferences")
                .and_then(JsonValue::as_array)
                .cloned()
                .ok_or_else(|| BskyAgentError::InvalidResponse {
                    nsid: nsid.to_owned(),
                    reason: "Missing preferences array".to_owned(),
                })
        })
    }

    fn save_preferences(
        &self,
        preferences: Vec<JsonValue>,
    ) -> BoxFuture<'_, Result<(), BskyAgentError>> {
        Box::pin(async move {
            self.verify_continuity().await?;
            let nsid = "app.bsky.actor.putPreferences";
            let body = serde_json::json!({ "preferences": preferences });
            let encoded = serde_json::to_vec(&body)
                .map_err(|e| BskyAgentError::InvalidInput(format!("encode {nsid}: {e}")))?;
            let empty: [(&str, &str); 0] = [];
            let call = BskyAgent::build_call_options(&BskyCallOptions::default());
            if let Err(err) = self
                .xrpc
                .procedure(nsid, empty, Some(XrpcBody::json(encoded)), &call)
                .await
            {
                self.verify_continuity().await?;
                return Err(map_xrpc_error(nsid, err));
            }
            self.verify_continuity().await?;
            Ok(())
        })
    }

    fn configure_labelers(
        &self,
        labelers: Vec<XrpcLabeler>,
    ) -> BoxFuture<'_, Result<(), BskyAgentError>> {
        Box::pin(async move {
            match (&self.agent.transport, &self.expected_continuity) {
                (AgentTransport::Client(client), Some(expected)) => {
                    let applied = client
                        .configure_labelers_if_continuity(
                            expected,
                            self.expected_did.as_ref(),
                            &labelers,
                        )
                        .await
                        .map_err(|e| BskyAgentError::Transport(e.to_string()))?;
                    if !applied {
                        return Err(BskyAgentError::AuthContinuityChanged);
                    }
                    Ok(())
                }
                _ => self.agent.set_raw_labelers(labelers).await,
            }
        })
    }
}

impl BskyPreferencesBackend for NetworkPreferencesBackend {
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    fn begin_session(
        &self,
    ) -> BoxFuture<'_, Result<Option<Arc<dyn BskyPreferencesSession>>, BskyAgentError>> {
        Box::pin(async move {
            let (xrpc, expected_continuity, expected_did) = match &self.agent.transport {
                AgentTransport::Client(client) => {
                    let continuity = client.auth_continuity_snapshot().await;
                    let did = client
                        .get_did()
                        .await
                        .map_err(|e| BskyAgentError::Transport(e.to_string()))?;
                    let xrpc = client.xrpc().await;
                    (xrpc, Some(continuity), did)
                }
                AgentTransport::Xrpc { xrpc, did } => {
                    (xrpc.read().await.clone(), None, did.clone())
                }
            };
            Ok(Some(Arc::new(NetworkPreferencesSession {
                agent: self.agent.clone(),
                xrpc,
                expected_continuity,
                expected_did,
            }) as Arc<dyn BskyPreferencesSession>))
        })
    }

    fn load_preferences(&self) -> BoxFuture<'_, Result<Vec<JsonValue>, BskyAgentError>> {
        Box::pin(async move {
            let nsid = "app.bsky.actor.getPreferences";
            let resp = self
                .agent
                .xrpc_query(nsid, &[], &BskyCallOptions::default())
                .await?;
            let json: JsonValue = decode_response_json(&resp.body, nsid)?;
            json.get("preferences")
                .and_then(JsonValue::as_array)
                .cloned()
                .ok_or_else(|| BskyAgentError::InvalidResponse {
                    nsid: nsid.to_owned(),
                    reason: "Missing preferences array".to_owned(),
                })
        })
    }

    fn save_preferences(
        &self,
        preferences: Vec<JsonValue>,
    ) -> BoxFuture<'_, Result<(), BskyAgentError>> {
        Box::pin(async move {
            let body = serde_json::json!({ "preferences": preferences });
            self.agent
                .procedure_empty(
                    "app.bsky.actor.putPreferences",
                    &body,
                    &BskyCallOptions::default(),
                )
                .await
        })
    }

    fn configure_labelers(&self, labelers: Vec<XrpcLabeler>) -> BoxFuture<'_, ()> {
        Box::pin(async move {
            let _ = self.agent.set_raw_labelers(labelers).await;
        })
    }
}

struct RawRecord {
    uri: String,
    cid: Option<String>,
    value: JsonValue,
}

impl RawRecord {
    fn strong_ref(&self) -> Option<StrongRef> {
        let cid_str = self.cid.as_deref()?;
        let uri = self.uri.parse::<AtUri>().ok()?;
        let cid = cid_str.parse::<CidString>().ok()?;
        Some(StrongRef::new(uri, cid))
    }
}

fn decode_response_json<T: DeserializeOwned>(body: &[u8], nsid: &str) -> Result<T, BskyAgentError> {
    serde_json::from_slice(body).map_err(|err| BskyAgentError::InvalidResponse {
        nsid: nsid.to_owned(),
        reason: format!("Body does not match expected JSON ({err})"),
    })
}

fn decode_raw_record(body: &[u8], nsid: &str) -> Result<RawRecord, BskyAgentError> {
    let json: JsonValue = decode_response_json(body, nsid)?;
    let Some(uri) = json.get("uri").and_then(JsonValue::as_str) else {
        return Err(BskyAgentError::InvalidResponse {
            nsid: nsid.to_owned(),
            reason: "Missing uri or value".to_owned(),
        });
    };
    let Some(value) = json.get("value") else {
        return Err(BskyAgentError::InvalidResponse {
            nsid: nsid.to_owned(),
            reason: "Missing uri or value".to_owned(),
        });
    };
    if !value.is_object() {
        return Err(BskyAgentError::InvalidResponse {
            nsid: nsid.to_owned(),
            reason: "Missing uri or value".to_owned(),
        });
    }
    Ok(RawRecord {
        uri: uri.to_owned(),
        cid: json
            .get("cid")
            .and_then(JsonValue::as_str)
            .map(ToOwned::to_owned),
        value: value.clone(),
    })
}

fn build_post_record(
    rich_text: &RichText,
    reply: Option<ReplyRef>,
    embed: Option<PostEmbedBuilder>,
    langs: Option<Vec<String>>,
    labels: Option<Vec<String>>,
    tags: Option<Vec<String>>,
    created_at: Option<Datetime>,
) -> Result<Post, BskyAgentError> {
    if rich_text.exceeds_post_limits() {
        return Err(BskyAgentError::InvalidInput(format!(
            "Post text is {} graphemes / {} bytes; the limit is {} graphemes / {} bytes",
            rich_text.grapheme_length(),
            rich_text.utf8_length(),
            RichText::MAX_POST_GRAPHEMES,
            RichText::MAX_POST_UTF8_BYTES
        )));
    }
    let parsed_langs = if let Some(langs) = langs {
        if langs.len() > 3 {
            return Err(BskyAgentError::InvalidInput(format!(
                "A post declares at most 3 languages, got {}",
                langs.len()
            )));
        }
        let mut out = Vec::with_capacity(langs.len());
        for tag in langs {
            let lang = tag.parse::<Language>().map_err(|_| {
                BskyAgentError::InvalidInput(format!("Invalid language tag: {tag}"))
            })?;
            out.push(lang);
        }
        Some(out)
    } else {
        None
    };

    let post_labels = labels.and_then(|values| {
        if values.is_empty() {
            None
        } else {
            Some(PostLabels::SelfLabels(Box::new(SelfLabels::new(
                values.into_iter().map(SelfLabel::new).collect(),
            ))))
        }
    });

    let mut record = Post::new(
        rich_text.text.clone(),
        created_at.unwrap_or_else(now_datetime),
    );
    record.facets = rich_text.record_facets();
    record.reply = reply;
    record.embed = embed.and_then(PostEmbedBuilder::into_post_embed);
    record.langs = parsed_langs;
    record.labels = post_labels;
    record.tags = tags;
    Ok(record)
}

fn record_json<Record: Serialize>(
    record: &Record,
    collection: Option<&str>,
) -> Result<(JsonValue, String), BskyAgentError> {
    let mut json = serde_json::to_value(record).map_err(|e| {
        BskyAgentError::InvalidInput(format!("The record could not be encoded: {e}"))
    })?;
    let Some(obj) = json.as_object_mut() else {
        return Err(BskyAgentError::InvalidInput(
            "A record must encode to a JSON object".to_owned(),
        ));
    };
    let resolved = collection
        .map(ToOwned::to_owned)
        .or_else(|| {
            obj.get("$type")
                .and_then(JsonValue::as_str)
                .map(ToOwned::to_owned)
        })
        .ok_or_else(|| {
            BskyAgentError::InvalidInput(
                "The record has no $type; pass the collection explicitly".to_owned(),
            )
        })?;
    if resolved.parse::<Nsid>().is_err() {
        return Err(BskyAgentError::InvalidInput(format!(
            "Not a valid collection NSID: {resolved}"
        )));
    }
    if !obj.contains_key("$type") {
        obj.insert("$type".to_owned(), JsonValue::String(resolved.clone()));
    }
    Ok((json, resolved))
}

fn validated_record_key(rkey: &str) -> Result<&str, BskyAgentError> {
    if rkey.parse::<RecordKey>().is_err() {
        return Err(BskyAgentError::InvalidInput(format!(
            "Not a valid record key: {rkey}"
        )));
    }
    Ok(rkey)
}

fn record_location<'a>(
    uri: &'a AtUri,
    expected_collection: &str,
) -> Result<(&'a str, &'a str), BskyAgentError> {
    let matches_collection = uri
        .collection()
        .is_some_and(|col| col.as_str() == expected_collection);
    let Some(rkey) = uri.rkey() else {
        return Err(BskyAgentError::InvalidInput(format!(
            "Expected a {expected_collection} record URI, got {}",
            uri.as_str()
        )));
    };
    if !matches_collection {
        return Err(BskyAgentError::InvalidInput(format!(
            "Expected a {expected_collection} record URI, got {}",
            uri.as_str()
        )));
    }
    Ok((uri.authority().as_str(), rkey.as_str()))
}

fn prepared_image(
    data: &Bytes,
    mime_type: &str,
    strip_metadata: bool,
) -> Result<Bytes, BskyAgentError> {
    let media_type = mime_type.split(';').next().unwrap_or("").trim();
    if !media_type.to_ascii_lowercase().starts_with("image/") {
        return Err(BskyAgentError::InvalidInput(format!(
            "Not an image media type: {mime_type}"
        )));
    }
    if !strip_metadata {
        return Ok(data.clone());
    }
    Ok(ImageMetadataStripper::strip_metadata(data, mime_type)?)
}

fn check_video_job<F: FnMut(&JobStatus)>(
    job: &JsonValue,
    job_id: &str,
    on_progress: &mut F,
) -> Result<Option<Blob>, BskyAgentError> {
    if let Ok(status) = serde_json::from_value::<JobStatus>(job.clone()) {
        on_progress(&status);
    }
    if let Some(blob_val) = job.get("blob")
        && let Ok(blob) = serde_json::from_value::<Blob>(blob_val.clone())
    {
        return Ok(Some(blob));
    }
    if job.get("state").and_then(JsonValue::as_str) == Some("JOB_STATE_FAILED") {
        return Err(BskyAgentError::VideoProcessingFailed {
            job_id: job_id.to_owned(),
            error: job
                .get("error")
                .and_then(JsonValue::as_str)
                .map(ToOwned::to_owned),
            message: job
                .get("message")
                .and_then(JsonValue::as_str)
                .map(ToOwned::to_owned),
        });
    }
    Ok(None)
}

fn now_datetime() -> Datetime {
    Datetime::from_system_time(SystemTime::now())
        .unwrap_or_else(|_| "1970-01-01T00:00:00Z".parse().expect("epoch datetime"))
}

fn is_loopback_host(host: Option<&str>) -> bool {
    matches!(host, Some("localhost" | "127.0.0.1" | "::1" | "[::1]"))
}
