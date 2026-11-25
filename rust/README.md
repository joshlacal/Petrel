# Petrel for Rust

This directory is the Rust target of Petrel, the AT Protocol SDK. It is being
built by the Petrel Rust program so that our Rust services and clients can stop
depending on the third-party `jacquard` library. The first consumer is Catmos,
which needs an OAuth client that can ask a client assertion backend (CAB: a
small server that signs the client's identity proof, so the app never holds the
signing key) for a fresh assertion on every token request.

**Status: implemented, not yet released.** Phases 0 to 3 of the Petrel Rust
program are built and tested: the generated API crates, the runtime, and OAuth
against the Swift example authorization server and client assertion backend.
Nothing is published to crates.io. The Catmos desktop app is the first
consumer. The governing plan is
`docs/execution-plans/2026-11-24-petrel-rust.md` in the Catbird+Petrel
workspace repository, with decisions logged in `docs/DECISIONS.md` there under
the tag `petrel-rust`.

Known gaps, all outside phases 0 to 3:

- Subscriptions are declared but there is no event-stream frame decoder.
- The file store runs blocking file I/O inside its async methods and does not
  bind a ciphertext to its file name. Both follow the Swift store it shares a
  format with.

## Crates

| Crate | What it is | Built by lane |
|---|---|---|
| `petrel-core` | Identifiers, the data-model `Value`, strict DAG-CBOR, the typed-to-`Value` bridge, XRPC endpoint traits. No HTTP, no crypto beyond SHA-256. | A |
| `petrel-api` | API types generated from `generator/manifests/petrel-core.json`. | B |
| `petrel-oauth-scopes` | The OAuth scope grammar. Depends on nothing else here. | C |
| `petrel` | The runtime: transport, XRPC pipeline, identity, crypto, OAuth, storage, service auth. | D and E |
| `petrel-e2e` | End-to-end tests against the Swift test servers. Never published. | F |

The workspace uses Cargo resolver 3 and Rust edition 2024. The developer and
CI toolchain is pinned in `rust-toolchain.toml`. CI tests compatibility with
the minimum supported Rust version, 1.88.

## Commands

Run from this directory. In the Catbird+Petrel workspace every one of these
goes through the build queue: prefix it with
`CTL_AGENT=<you> ctl run --slot cargo --`.

```bash
cargo check --workspace --locked
```

```bash
cargo check --workspace --locked --target wasm32-unknown-unknown --no-default-features --features wasm
```

```bash
cargo clippy --workspace --locked --all-targets --all-features -- -D warnings
```

```bash
cargo test --locked -p petrel-core --test spike
```

```bash
cargo tree --locked -p petrel --target wasm32-unknown-unknown --no-default-features --features wasm -e normal
```

The last command must list no `tokio`, `mio`, `hickory` or `aws-lc` crate.

Notes on the wasm command:

- Every member crate defines a `wasm` feature (an empty one where it has
  nothing to switch), which is what lets `--features wasm` be passed to the
  whole workspace.
- `petrel-e2e` spawns processes; on `wasm32` it compiles to an empty crate.
- If the build fails inside `audiopus_sys` or another CMake project, that is
  the workspace's known CMake 4 problem, not this code: set
  `CMAKE_POLICY_VERSION_MINIMUM=3.5`.

## Features of `petrel`

| Feature | Pulls in | Notes |
|---|---|---|
| `native` (default) | reqwest over rustls, Tokio timers, Hickory DNS | Native targets. |
| `wasm` | Browser Fetch through `web-sys`, Gloo timers, JavaScript entropy | Browser and worker targets. |
| `file-store` | AES-GCM and platform file locks | Encrypted native storage. |

Native-only dependencies sit in a `cfg(not(target_arch = "wasm32"))` target
table, so even building for wasm with default features cannot pull tokio in.

Browser Fetch omits ambient credentials and refuses opaque redirects. The
browser controls DNS and decompression, so the SDK can limit the decoded body
size while native transport also checks IP addresses and compressed wire size.
For cross-origin OAuth and XRPC, servers must expose `DPoP-Nonce` and
`WWW-Authenticate` through CORS for the SDK to handle nonce challenges.

Browser embedders can use `crypto::WebCryptoDpopSigner` for non-extractable
P-256 keys. The signer can validate a restored key handle against its public
JWK. The embedder supplies persistence for the handle and for session records.

`getrandom` is wired for the 0.2 line only (`getrandom/js`), which is what
`p256` 0.13 uses. If a later dependency brings `getrandom` 0.3 or 0.4 into the
wasm graph, add the aliased dependencies described in
`maps/rust-deps-wasm.md`; `cargo tree -i getrandom` on the wasm target shows
whether that has happened.

## The shared contracts

Names shared by the generator and the runtime. Changing one needs a dated
`petrel-rust` entry in `docs/DECISIONS.md`.

**`petrel_core`**

- `Value`: `Null`, `Bool`, `Integer(i64)`, `String`, `Bytes`, `Link(Cid)`,
  `Array`, `Object(BTreeMap<String, Value>)`. No floats.
- Identifiers: `Did`, `Handle`, `AtIdentifier`, `Nsid`, `AtUri`, `SpaceRef`,
  `Uri`, `Tid`, `RecordKey`, `Datetime`, `Language`, `CidString`. Each has
  `parse`, `as_str`, `into_string`, `FromStr`, `Display`, and the bridge and
  serde traits.
- Wire wrappers: `Cid`, `CidLink`, `Bytes`, `Blob`, `Nullable<T>`.
- Service audiences and proxy values: `ServiceRef` and `ServiceRefError`.
- The bridge: `ToValue`, `FromValue`, `ObjectReader`, `ObjectWriter`,
  `to_json`, `from_json`, `to_dag_cbor`, `from_dag_cbor`,
  `serde_bridge::{serialize, deserialize}`, `unknown::{type_of, tagged}`.
- `dagcbor::{encode, decode, decode_with, Limits}`.
- XRPC: `XrpcRequest`, `XrpcMethod`, `Collection`, `RecordKeyType`,
  `XrpcInput`, `XrpcOutput`, `DeclaredXrpcError`, `ToQueryParams`, and in
  `petrel_core::xrpc` also `QueryValue`, `UndeclaredError`, `XrpcErrorBody`,
  `json_body`, `push_param`, `push_optional_param`, `push_array_param`.
- Errors: `SyntaxError`, `SyntaxKind`, `CidError`, `DagCborError`,
  `DecodeError`, `EncodeError`.

**`petrel`**

- `rt::{MaybeSend, MaybeSync, BoxFuture}`
- `net::{HttpTransport, DynHttpTransport, SharedTransport, SendOptions, TransportError}`
- `xrpc::{AuthProvider, AuthCtx, UnauthorizedAction, AuthError}`
- `crypto::{DpopSigner, EcPublicJwk, CryptoError}`
- `oauth::{ClientAuth, AssertionSigner}`
- `storage::{SecretStore, StoreError}`

## How generated types serialize

Generated types do not derive serde traits and never use `#[serde(flatten)]`.
The generator emits `impl ToValue` and `impl FromValue` as plain calls on
`ObjectWriter` and `ObjectReader`, plus two one-line serde impls that delegate
to `petrel_core::serde_bridge`. JSON and DAG-CBOR are both reached through
`Value`, so a CID link stays CBOR tag 42 and bytes stay a byte string.

`petrel-core/tests/spike.rs` is the reference: three type groups written by
hand exactly as the generator will write them, and the tests that prove the
behaviour (byte-identical round-trips in both codecs, unknown union members
and unknown fields kept verbatim, a malformed optional field degrading to
`None` while its raw value is kept and re-emitted, a missing required-nullable
key being an error, `$type` written exactly once, canonical map key order,
floats refused, and the three official data-model fixtures reproducing their
CBOR bytes and CIDs). Lane B should copy its shapes.
