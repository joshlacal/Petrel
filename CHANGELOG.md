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
- A fail-closed DocC validator that treats documentation diagnostics as errors under the sealed release toolchain.

### Changed
- Generated namespace reference classes are immutable `Sendable` structs. This is an intentional pre-1.0 source compatibility break for code that named or relied on namespace class identity.
- Petrel now owns shared overlay namespace roots; overlays add only their child namespaces.
- Public installation documentation now targets Petrel 0.2.0 and the iOS 18/macOS 15 platform floors.
- PetrelLoad rejects unsupported scenarios and invalid base URLs, propagates OAuth setup and verification failures, and exits nonzero when stress requests fail.

### Fixed
- Generated wire discriminators preserve exact lexicon fragments, including underscore-bearing Bluemoji format identifiers.
- Declared endpoint errors use exact protocol names instead of embedding descriptions in raw values.
- DAG-CBOR decoding rejects invalid ATProto link CIDs and malformed/out-of-range numeric values without losing valid unpadded byte values.
- Registered typed values preserve their top-level `$type` framing across JSON and DAG-CBOR container round trips.
- Generated endpoints receive declared terminal HTTP errors after the existing authentication and retry pipeline, allowing their typed error parsers to inspect the real response body.
- Regeneration removes only stale files carrying Petrel's exact generated-source ownership header.
- Authentication refresh callers now await the shared refresh task and receive its actual result or failure instead of an early success result.

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
