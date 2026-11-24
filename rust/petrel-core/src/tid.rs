//! TID generation.
//!
//! Stub created by Lane 0; the [`Tid`](crate::Tid) newtype itself lives in
//! [`crate::syntax`]. Lane A (work package C9) ports
//! `Sources/Petrel/Core/Utils/TIDGenerator.swift` here as `TidGenerator`:
//!
//! - strictly increasing output (`max(clock, last + 1)`), a fixed random
//!   clock id, and an injectable microsecond clock;
//! - `next_after(previous)` refuses a previous TID with the high bit set or
//!   the maximum timestamp, rather than producing a smaller TID;
//! - on `wasm32` the clock comes from `web-time` and the clock id from
//!   `getrandom`'s JS backend (`std::time` panics there), both behind this
//!   crate's `wasm` feature.
