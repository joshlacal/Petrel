//! Hard event invariants and frame encoding errors for AT Protocol firehose frames.

/// Hard event invariants for complete firehose frames.
///
/// These match the AT Protocol sync subscription limits with stricter
/// per-operation checks layered on top.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FirehoseFrameLimits;

impl FirehoseFrameLimits {
    /// Maximum encoded WebSocket frame size (5 MB).
    pub const MAXIMUM_FRAME_BYTES: usize = 5_000_000;
    /// Maximum `#commit.blocks` diff CAR size (2 MB).
    pub const MAXIMUM_COMMIT_BLOCKS_BYTES: usize = 2_000_000;
    /// Maximum `#sync.blocks` commit CAR size (10 KB).
    pub const MAXIMUM_SYNC_BLOCKS_BYTES: usize = 10_000;
    /// Maximum operations in one `#commit` event.
    pub const MAXIMUM_OPS: usize = 200;
    /// Maximum CBOR nesting depth.
    pub const MAXIMUM_DEPTH: usize = 64;
    /// Maximum aggregate CBOR nodes per frame.
    pub const MAXIMUM_AGGREGATE_NODES: usize = 10_000;
    /// Maximum valid event sequence number (`2^53 - 1`).
    pub const MAXIMUM_SEQUENCE: i64 = 9_007_199_254_740_991;

    /// Validates `1 <= seq <= MAXIMUM_SEQUENCE`.
    pub fn validate_sequence(seq: i64) -> Result<(), FirehoseFrameEncoderError> {
        if (1..=Self::MAXIMUM_SEQUENCE).contains(&seq) {
            Ok(())
        } else {
            Err(FirehoseFrameEncoderError::SequenceOutOfRange)
        }
    }
}

/// Errors produced when encoding a firehose frame.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum FirehoseFrameEncoderError {
    #[error("sequence number out of range")]
    SequenceOutOfRange,
    #[error("too many operations: {0}")]
    TooManyOperations(usize),
    #[error("blocks size {actual} exceeds maximum {maximum}")]
    BlocksTooLarge { actual: usize, maximum: usize },
    #[error("frame size {0} exceeds maximum")]
    FrameTooLarge(usize),
    #[error("invalid CID: {0}")]
    InvalidCid(String),
    #[error("invalid operation at index {index}: {reason}")]
    InvalidOperation { index: usize, reason: String },
    #[error("invalid account status combination")]
    InvalidAccountStatus,
    #[error("frame encoding failed: {0}")]
    Encode(String),
}
