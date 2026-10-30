# Changelog

All notable changes to this project will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/) (pre-1.0: minor bumps may break).

## [Unreleased]

The changes below are the Petrel 0.2.0 release candidate. Replace this paragraph
with a dated `0.2.0` heading only when the release tag is created.

### Added
- Exact typed AT Protocol errors for generated queries and procedures.
- A lossless DAG-CBOR/DAG-JSON bridge for Blob, Bytes, CID, null, and integer values within the signed 64-bit range.
- A generated-value-container decoder that preserves primitive roots, special link/byte objects, unknown fields, and re-encodable fallback values.
- Deterministic generated-source ownership, stale-file removal, and pinned release tooling.
- A two-overlay compiler fixture proving PetrelCatbird and PetrelBluemoji can extend one Petrel-owned `Blue` namespace.
- A fail-closed DocC validator that treats documentation diagnostics as errors and compile-checks every Swift example in the public guides under the sealed release toolchain.
- PetrelCrypto service JWTs can bind an XRPC request body through the `requestBodyDigest` claim.
- `SpaceCredentialManager.get(url:space:audience:maximumArchiveBytes:)`: the optional `maximumArchiveBytes` (default `nil`, unchanged behaviour) replaces the hardened 10 MiB response limit for a single `getRepo` request and bounds that archive's STAR verification, so callers can fetch verified repositories larger than 10 MiB. Values above `SpaceSTAR.defaultMaximumArchiveBytes` (128 MiB) are clamped; other methods ignore it. Existing calls compile unchanged.
- `NetworkService.withResponseLimits(_:operation:)` runs an operation with the given `NetworkResponseLimits` in place of each `NetworkService`'s own limits (10 MiB by default) for every request it sends, so a generated call such as `com.atproto.space.getRepo` or `com.atproto.space.getBlob` can accept a larger response. Each field is clamped to 0...128 MiB (`SpaceSTAR.defaultMaximumArchiveBytes`). The scope covers child tasks and any authentication refresh or retry the requests trigger; scoped requests are not deduplicated with other in-flight requests, and the hardened transport checks are unchanged. Requests outside a scope keep their limits.
- `SpaceCredentialManager.get(url:space:audience:maximumArchiveBytes:maximumBlobBytes:)`: the optional `maximumBlobBytes` (default `nil`, unchanged behaviour) replaces the hardened 10 MiB response limit for a single `getBlob` request, clamped to 128 MiB, as `maximumArchiveBytes` does for `getRepo`. Other methods ignore it, and `maximumArchiveBytes` still does not apply to `getBlob`. Existing calls compile unchanged.

### Changed
- Regenerated Swift and Kotlin SimpleSpace APIs against the September 10 Spaces alpha (`9d787ebf`): independent `readPolicy`/`writePolicy`, `putMember` with required read/write flags, and access-specific managing-app checks. The obsolete `addMember` endpoint is removed.
- Generated namespace reference classes are immutable `Sendable` structs. This is an intentional pre-1.0 source compatibility break for code that named or relied on namespace class identity.
- Petrel now owns shared overlay namespace roots; overlays add only their child namespaces.
- Public installation documentation now targets Petrel 0.2.0 and the iOS 18/macOS 15 platform floors.
- The 0.2.0 SPM release gate is explicitly Swift-scoped; Kotlin publication and parity remain outside this release candidate.
- PetrelLoad rejects unsupported scenarios and invalid base URLs, propagates OAuth setup and verification failures, and exits nonzero when stress requests fail.
- Spaces lexicons follow the October 22, 2026 alpha (atproto `ac0c9f15`, npm `0.0.0-spaces-alpha-20261022141228`), byte-identical to upstream. Source-breaking changes from the October 1 alpha (`679724ad`): `ComAtprotoSimplespaceCreateSpace.Input.type` and `ComAtprotoSpaceListSpaces.Parameters.type` are now `spaceType`; `ComAtprotoSpaceNotifyWrite.Input.rev` and `ComAtprotoSpaceListRepos.Repo.rev` are now `repoRev`. `notifyWrite` adds optional `spaceRev`/`prevSpaceRev` and typed `SpaceNotFound`/`FutureRev` errors; `listRepos` entries add `spaceRev`, and its cursor is an exclusive space-revision checkpoint. Source-breaking changes from the October 22 alpha: `ComAtprotoSpaceDefs.SignedCommit`, which carried `hash`, `ikm`, `sig` and `mac`, is replaced by `ComAtprotoSpaceDefs.Commit` (`ver`, `space`, `repo`, `rev`, `data`); `hash` is now `data` in `notifyWrite` input and `listRepos` entries; `ComAtprotoSpaceGetSpaceCredential.Input` requires `credentialKid` and takes an optional `delegationToken`; `getRepo` returns a STAR archive (`application/octet-stream`) and drops `excludeValues`; `getLatestCommit`, `getRecord`, `getRepo` and `listRepoOps` declare `BadSpaceMac`.
- `SpaceCredentialManager` follows the October 22 credential flow. The `getSpaceCredential` exchange sends the space, a fresh P-256 `did:key` as `credentialKid`, the delegation token and any client attestation in its JSON body, with no Authorization header or HTTP signature; the returned credential's JWT header must name `#atproto`. `get(url:space:audience:)` sends `Authorization: Atproto-Space-Credential <credential>`, `Atproto-Space-Audience` (the `repo` DID, else the space authority DID), and an HTTP Message Signature over both under the `atproto-space-credential` label and tag, replacing Spaces DPoP. For `getLatestCommit`, `getRepo`, `listRepoOps` and `getRecord` it requests and verifies a response MAC keyed to the author's `#atproto_kem` key, and it returns a `getRepo` archive only after full STAR verification. A `401 CredentialRevoked` response drops the cached credential. Ordinary OAuth DPoP is unchanged.

### Fixed
- `SpaceCredentialManager` reuses a cached space credential until its `exp` less min(60 s, half its issued lifetime `exp - iat`), bounded by that lifetime from local receipt. The previous flat 60 s margin never reused a 60 s credential, so every read repeated the delegation and credential exchange.
- Credential-exchange errors keep their protocol names. `SpaceNotFound` at HTTP 400 (the reference host) or 404 (Swan) is now `SpaceCredentialError.authorizationRefused` with error `SpaceNotFound` (previously `exchangeFailed`, which dropped the name or kept it only inside the raw body); it never means deletion. `InvalidClientAttestation` remains `tokenRejected` with that error name, but its description names the client attestation instead of the delegation token, and it no longer triggers the `describeServer` evidence probe. No enum cases were added, so exhaustive switches still compile.
- `SpaceHostResolver.fetchDIDDocument(for:urlSession:limits:)` (when no `urlSession` is passed) and `SpaceHostResolver.fetchBoundedPublicJSON(from:limits:fixtureSession:)` invalidate the hardened session they create for each call once its request finishes. URLSession keeps a strong reference to its delegate until it is invalidated, so every call previously leaked that session and its delegate.
- A `SpaceHostResolver` or `SpaceCredentialManager` that creates its own session (no `urlSession` passed) invalidates it when it is released, so a short-lived resolver or manager no longer leaks its session and delegate. A session passed in remains the caller's to invalidate.
- Generated wire discriminators preserve exact lexicon fragments, including underscore-bearing Bluemoji format identifiers.
- Declared endpoint errors use exact protocol names instead of embedding descriptions in raw values.
- DAG-CBOR decoding rejects invalid ATProto link CIDs and malformed/out-of-range numeric values without losing valid unpadded byte values.
- Registered typed values preserve their top-level `$type` framing across JSON and DAG-CBOR container round trips.
- Generated endpoints receive declared terminal HTTP errors after the existing authentication and retry pipeline, allowing their typed error parsers to inspect the real response body.
- Regeneration removes only stale files carrying Petrel's exact generated-source ownership header.
- Authentication refresh callers now await the shared refresh task and receive its actual result or failure instead of an early success result.
- `com.atproto.space` and `com.atproto.simplespace` lexicons are re-vendored verbatim from bluesky-social/atproto PR #5187 (`57b0a0424fb27d8e4989e74fa37fbc0ce4527ded`). This replaces a non-upstream `com.atproto.space.defs#signedCommit` shape (a "v2 authenticated transition" with optional `did`, `space`, `prevRev`, `prevHash`, `path`, `action`, `cid`, `prevCid`, `val` and optional `ikm`/`mac`) with the upstream v1 shape, where `ikm` and `mac` are required and the v2-only fields no longer exist. This is a source-breaking change for code that constructed or read the removed fields. The same vendor drop replaces `simplespace.addMember` with `simplespace.putMember` and adds `space.notifyCredentialRevoked`. The October 22 alpha later replaced that `signedCommit` shape with `#commit` (see Changed).

## [0.1.0] - 2026-06-12

### Added
- MIT LICENSE.
- Manifest-driven code generation (`python3 run.py --manifest <file>`): configurable lexicon dirs, namespace exclusions, per-language outputs.
- **Overlay packages**: generate extra lexicon namespaces as a separate Swift/Kotlin package against the public core (`package.kind: "overlay"`), including namespace extensions and `ATProtocolValueContainer.registerDecoder` registration.
- Configurable keychain accessibility (`KeychainAccessibility`), default `afterFirstUnlockThisDeviceOnly`.
- `ATProtoClient.defaultBaseURL` constant.
- Typed decoder registry on `ATProtocolValueContainer` (`registerDecoder(forType:)`).

### Changed
- **OAuth reliability overhaul**: refresh tokens are only marked consumed on success or definitive `invalid_grant`; transient failures (timeout, offline, 5xx) are retried with the same token. Rotated sessions survive keychain write failures (retry + pending-key + in-memory fallback). Session writes are newest-wins; recovery never resurrects an older session. Pre-refresh session reads bypass the in-memory cache (cross-process safety with app extensions).
- All standard lexicons synced to bluesky-social/atproto (incl. chat.bsky group chats GA, `getUnreadCounts`, `tools.ozone.queue/report`).
- Generated namespace accessors are now lowerCamelCase (`client.app.bsky.authManageLabelerService`); old all-lowercase names remain as deprecated aliases for one release.
- Malformed *optional* fields in responses/records decode to `nil` with a warning instead of failing the whole response.
- Sensitive values in DEBUG logs are truncated again (full-token logging removed).
- atproto syntax validators (handle/DID/record-key/TID/datetime) now pass the official interop fixtures.
- `NetworkService`, `LogManager`, and generated namespace classes are `public` (overlay-package SPI; pre-1.0 surface).

### Removed
- `blue.catbird.*` and `place.stream.*` lexicons and generated types — moved to the private PetrelCatbird overlay package.
- Dead code: `OAuthCallbackBuffer` (stored authorization codes in plaintext UserDefaults), `SafeDecoder`, `CIDTestUtility`.
- All `print()`/`fputs()` calls in library code (routed through `LogManager`).

### Fixed
- "Session expired early": a transiently-failed refresh permanently poisoned the refresh token in-process until app restart.
- Loss of rotated refresh token when the keychain write failed after a successful refresh.
- Stale `session.backup`/`session.temp` could resurrect an already-rotated refresh token.
- Linux: secure-storage initialization failure no longer calls `fatalError` (throws `KeychainError.storageUnavailable`).
