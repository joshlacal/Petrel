# Petrel for Rust

This directory is the Rust target of Petrel, the AT Protocol SDK. It is being
built by the Petrel Rust program so that our Rust services and clients can stop
depending on the third-party `jacquard` library. The first consumer is Catmos,
which needs an OAuth client that can ask a client assertion backend (CAB: a
small server that signs the client's identity proof, so the app never holds the
signing key) for a fresh assertion on every token request.

**Status: skeleton.** Lane 0 of the program created the workspace, froze the
interfaces the other lanes share, and proved the serialization design with a
test spike. The crates compile and the spike passes; most behaviour is not
written yet. The governing plan is
`docs/execution-plans/2026-11-24-petrel-rust.md` in the Catbird+Petrel
workspace repository, with decisions logged in `docs/DECISIONS.md` there under
the tag `petrel-rust`.

## Crates

| Crate | What it is | Owner lane |
|---|---|---|
| `petrel-core` | Identifiers, the data-model `Value`, strict DAG-CBOR, the typed-to-`Value` bridge, XRPC endpoint traits. No HTTP, no crypto beyond SHA-256. | A |
| `petrel-api` | **Generated** API types, from `generator/manifests/petrel-core.json`. Never hand-edited. Empty until the generator's Rust backend lands. | B |
| `petrel-oauth-scopes` | The OAuth scope grammar. Depends on nothing else here. | C |
| `petrel` | The runtime: transport, XRPC pipeline, identity, crypto, OAuth, storage, service auth. | D and E |
| `petrel-e2e` | End-to-end tests against the Swift test servers. Never published. | F |

Settings: cargo resolver 3, edition 2024, minimum Rust 1.88.

## Commands

Run from this directory. In the Catbird+Petrel workspace every one of these
goes through the build queue: prefix it with
`CTL_AGENT=<you> ctl run --slot cargo --`.

```bash
cargo check --workspace
```

```bash
cargo check --workspace --target wasm32-unknown-unknown --no-default-features --features wasm
```

```bash
cargo clippy --workspace --all-targets -- -D warnings
```

```bash
cargo test -p petrel-core spike
```

```bash
cargo tree -p petrel --target wasm32-unknown-unknown --no-default-features --features wasm
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
| `native` (default) | reqwest over rustls, tokio timers, hickory DNS | Declared only for non-wasm targets. |
| `wasm` | reqwest's fetch backend, gloo timers, `getrandom`'s JS backend | No tokio anywhere on this path. |
| `file-store` | AES-GCM, HKDF, zeroize | The encrypted on-disk secret store. |

Native-only dependencies sit in a `cfg(not(target_arch = "wasm32"))` target
table, so even building for wasm with default features cannot pull tokio in.

`getrandom` is wired for the 0.2 line only (`getrandom/js`), which is what
`p256` 0.13 uses. If a later dependency brings `getrandom` 0.3 or 0.4 into the
wasm graph, add the aliased dependencies described in
`maps/rust-deps-wasm.md`; `cargo tree -i getrandom` on the wasm target shows
whether that has happened.

## Rules for lanes working in parallel

Six lanes build in these crates at the same time. To keep them out of each
other's way:

- **Do not edit** `rust/Cargo.toml`, `rust/petrel/Cargo.toml` or
  `rust/petrel/src/lib.rs`. Every dependency and every module is already
  declared. If something is missing, ask the integrator.
- Each `petrel` module is a directory (`src/oauth/mod.rs` and so on). Add
  files inside the directories your lane owns.
- The interface contracts are frozen. Changing one needs a dated `petrel-rust`
  entry in `docs/DECISIONS.md` and an update to the plan's contracts section.

## The frozen contracts

Names other lanes can rely on. Bodies marked *placeholder* are minimal and get
replaced by the owning lane without a rename.

**`petrel_core`**

- `Value`: `Null`, `Bool`, `Integer(i64)`, `String`, `Bytes`, `Link(Cid)`,
  `Array`, `Object(BTreeMap<String, Value>)`. No floats.
- Identifiers: `Did`, `Handle`, `AtIdentifier`, `Nsid`, `AtUri`, `SpaceRef`,
  `Uri`, `Tid`, `RecordKey`, `Datetime`, `Language`, `CidString`. Each has
  `parse`, `as_str`, `into_string`, `FromStr`, `Display`, and the bridge and
  serde traits. *Validators are placeholders.*
- Wire wrappers: `Cid`, `CidLink`, `Bytes`, `Blob`, `Nullable<T>`.
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
