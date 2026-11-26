#![forbid(unsafe_code)]
//! AT Protocol Jetstream client (`v2` `xrpc.v1.json` + archive segments/blocks + legacy `v1`
//! `/subscribe`) with pure-Rust `ruzstd` decompression (standalone and custom dictionaries) on
//! both native and `wasm32-unknown-unknown`.

pub mod channel;
pub mod client;
pub mod event;
pub mod http;
pub mod segment_block;
pub mod subscription;
pub mod wire;
pub mod zstd;

pub use channel::{JetstreamBatch, JetstreamBatchSender, jetstream_batch_channel};
pub use client::{
    JetstreamClient, JetstreamClientConfiguration, JetstreamClientError, JetstreamMode,
};
pub use event::{
    JetstreamAccountEvent, JetstreamCommitEvent, JetstreamEvent, JetstreamFilter,
    JetstreamIdentityEvent, JetstreamInfoEvent, JetstreamKind, JetstreamSyncEvent,
};
pub use http::{
    DEFAULT_MAX_SEGMENT_BYTES, JetstreamHttpError, JetstreamHttpTransport, JetstreamXrpcClient,
    JetstreamXrpcError, PetrelJetstreamHttpTransport, SnapshotBlockRange, SnapshotPlan,
    SnapshotPlanRequest, SnapshotPlanSegment, SnapshotPlanStats, default_http_transport,
};
#[cfg(not(target_arch = "wasm32"))]
pub use segment_block::SegmentFileReader;
pub use segment_block::{SegmentBlockDecoder, SegmentBlockError, SegmentBytesReader, SegmentEvent};
pub use subscription::{
    CursorStorageOperation, JetstreamApiVersion, JetstreamIgnoredFrame, JetstreamIgnoredReason,
    JetstreamOptionsUpdate, JetstreamSubscription, JetstreamSubscriptionConfiguration,
    JetstreamSubscriptionError, JetstreamSubscriptionEvent, build_legacy_websocket_url,
    build_websocket_url,
};
pub use wire::{JetstreamWire, JetstreamWireError, JetstreamWireFrame};
pub use zstd::{
    DEFAULT_MAX_DICT_FRAME_BYTES, DEFAULT_MAX_DICTIONARY_BYTES, DEFAULT_MAX_STANDALONE_BYTES,
    JetstreamZstd, JetstreamZstdDictionaryDecoder, JetstreamZstdError,
};
