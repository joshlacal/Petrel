//! Service auth: short-lived tokens for calling another service as the user.
//!
//! Stub created by Lane 0. Lane E owns this module (map:
//! `docs/execution-plans/2026-11-24-petrel-rust/maps/serviceauth-space-storage.md`,
//! package SA1) and adds the client call only: `get_service_auth`, which asks
//! the user's PDS (`com.atproto.server.getServiceAuth`) for a token scoped to
//! an audience and an optional lexicon method.
//!
//! Fail closed where Swift is loose (plan decision 14): check `iss` on the
//! returned token.
//!
//! Out of scope for phases 0 to 3: *verifying* service-auth tokens (mls-ds
//! and circle-appview already do that with their own code), and Space
//! credentials (`catbird-atproto/atproto-spaces` already implements them).
