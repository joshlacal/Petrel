#![forbid(unsafe_code)]
//! AT Protocol firehose (`com.atproto.sync.subscribeRepos`), generic event-stream subscriptions,
//! canonical DAG-CBOR frame encoding/decoding, diff CAR extraction, and relay commit/MST
//! verification.
//!
//! Mirrors Swift's `PetrelFirehose` module on both native (`tokio` + `tokio-tungstenite` +
//! `rustls-tls-webpki-roots`) and `wasm32-unknown-unknown` (`web-sys` WebSocket).

pub mod car;
pub mod decoder;
pub mod encoder;
pub mod limits;
pub mod pump;
pub mod records;
pub mod repo_seam;
pub mod subscription;
pub mod transport;
pub mod types;
pub mod verification;

pub use car::{
    CarBlock, CarBlockMap, DiffCarBlockReader, ParsedCarArchive, PublicFirehoseDiffCAR,
    PublicFirehoseDiffCarError,
};
pub use decoder::{
    EventStreamIgnoredFrame, IgnoredFrameReason, ParsedRelayFrame, RelayFrame, RelayFrameDecoder,
    RelayFrameDecodingMode,
};
pub use encoder::FirehoseFrameEncoder;
pub use limits::{FirehoseFrameEncoderError, FirehoseFrameLimits};
pub use pump::{
    BoxedEventStream, EventStreamError, FirehoseBackoffConfiguration, FirehoseBoundedReceiver,
    FirehoseBoundedSender, FirehoseCursorStorage, FirehoseStreamError,
    InMemoryFirehoseCursorStorage, bounded_firehose_channel,
};
pub use records::RelayRecordOperation;
pub use repo_seam::{
    FixedRepositorySigningKey, RepoBlockSourceAdapter, RepoCommitVerifier,
    RepoCommitVerifierAdapter, RepoSigningKeyResolverAdapter, RepositoryBlockSource,
    RepositorySigningKeyResolver, SigningPublicKey, ThrottledSigningKeyResolver,
};
pub use subscription::{
    EventStreamEvent, EventStreamSubscription, FirehoseEndpoint, FirehoseSubscription,
    FirehoseSubscriptionConfiguration, FirehoseSubscriptionEvent, LabelSubscription,
};
#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
pub use transport::{BrowserWebSocketFactory, BrowserWebSocketSession};
pub use transport::{
    FirehoseSubscriptionError, FirehoseWebSocketOptions, FirehoseWebSocketSession,
    FirehoseWebSocketSessionFactory, TextFrameHandling, default_websocket_factory,
};
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub use transport::{TungsteniteWebSocketFactory, TungsteniteWebSocketSession};
pub use types::{
    PublicFirehoseAccountMaterial, PublicFirehoseAccountStatus, PublicFirehoseCommitMaterial,
    PublicFirehoseEventKind, PublicFirehoseIdentityMaterial, PublicFirehoseRepoAction,
    PublicFirehoseRepoOp, PublicFirehoseSourceKey, PublicFirehoseSyncMaterial, PublicFirehoseTime,
    PublicFirehoseTimeError, RelayAccountEvent, RelayCommitEvent, RelayErrorEvent, RelayEvent,
    RelayGetRepoObservation, RelayGetRepoQueryMode, RelayIdentityEvent, RelayInfoEvent,
    RelayNamedCheck, RelayReconnectEvidence, RelayRepoAction, RelayRepoOp, RelayRepositoryHead,
    RelayRepositoryPayloadKind, RelayRepositorySnapshot, RelaySequenceVerification, RelaySyncEvent,
    RelayVerificationAggregate, RelayVerificationCheckName, RelayVerificationCheckOutcome,
    RelayVerifierError,
};
pub use verification::{
    InMemoryRelayAcceptedHeadStorage, RelayAcceptedHeadStorage, RelayCommitSemanticVerifier,
    RelayFullRepositoryVerifier, RelayGetRepoPolicy, RelayLifecycleVerifier, RelayRepositoryDigest,
    RelayRepositoryVerificationState, RelaySequenceVerifier, RelayVerifiedFullRepository,
};
