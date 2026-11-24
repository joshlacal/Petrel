//! End-to-end harness for the Petrel Rust runtime.
//!
//! Stub created by Lane 0. Lane F of the Petrel Rust program owns this crate
//! (map: `docs/execution-plans/2026-11-24-petrel-rust/maps/test-servers.md`,
//! packages E0 to E7). It spawns the Swift OAuth and CAB example servers,
//! runs its own fake PLC directory, and drives public-client and CAB-client
//! sign-in, refresh rotation and revocation against them.
//!
//! The harness spawns processes, so it is native-only and compiles to an empty
//! crate on `wasm32`.
#![cfg(not(target_arch = "wasm32"))]
