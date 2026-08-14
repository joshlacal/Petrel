# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Petrel is a Swift library providing a complete implementation of the ATProtocol and Bluesky APIs. The codebase uses automated code generation from Bluesky's Lexicon JSON files to create Swift types and networking code.

## CAB Server (Server/)

`Server/` is an independent SPM package (NOT part of the Petrel library):
`petrel-cab-server`, a client-assertion backend implementing
`docs/cab-backend-contract.md` for `AuthMode.cab`. Build/test it from
`Server/` (`cd Server && swift test`). The Petrel SDK must never depend on it.
Kotlin has no `AuthMode.cab` implementation yet — CAB support (assertion fetch,
aud, PAR injection) is an open follow-up for the Kotlin client.

## Common Development Tasks

### Building the Project
```bash
swift build
```

### Running Tests
```bash
swift test
```

### Regenerating Code from Lexicons
```bash
# Canonical: manifest-driven, Swift + Kotlin, then REQUIRED formatting pass
python3 run.py --manifest generator/manifests/petrel-core.json
swiftformat Sources/Petrel/Generated

# Overlay package (PetrelCatbird — Catbird's custom lexicons), run from this repo root,
# then format from the OVERLAY repo — see the formatting note below
python3 run.py --manifest ../PetrelCatbird/manifests/petrel-catbird.json
cd ../PetrelCatbird && swiftformat Sources/PetrelCatbird/Generated

# Legacy positional CLI still works:
python3 run.py generator/lexicons Sources/Petrel/Generated --language both
```
The committed generated code is post-SwiftFormat; raw generator output differs
until `swiftformat Sources/Petrel/Generated` runs (CI enforces the regen+format
round-trip producing an empty diff).

**The two packages format under different rules, and both rely on SwiftFormat's
config auto-discovery — so run each pass from its own repo and pass no `--config`:**

- **Core** picks up `Petrel/.swiftformat` (4-space, `--wraparguments before-first`).
- **Overlay** picks up nothing — PetrelCatbird has no `.swiftformat`, so SwiftFormat
  defaults apply, and that is what the committed overlay output was produced with.
  Passing `--config ../Petrel/.swiftformat` to the overlay does **not** reproduce it:
  it rewraps case tuples and leaves 8 files permanently dirty, which reads like a
  generator bug and is not one. Verify a clean regen by round-tripping to an empty
  `jj diff`, not by eyeballing.

Kotlin output has **no** post-format step in either package — the generator's own
output is the committed form and round-trips byte-identically. Don't go looking for
a ktlint/spotless pass; there isn't one.

## Release Versioning

Downstream packages consume Petrel with `.upToNextMinor(from:)`, so **the minor
component is the compatibility boundary**. Pick the bump before tagging:

| Change | Bump | Example |
|---|---|---|
| Bug fix, no change to any public declaration | **patch** | `1.1.0` → `1.1.1` |
| Lexicon regen, or anything landing in `api-breakage-allowlist.txt` | **minor** | `1.1.1` → `1.2.0` |
| Deliberate redesign of the hand-written API surface | **major** | `1.2.0` → `2.0.0` |

A lexicon regen is a **minor** bump even when the API diff looks additive:
generated memberwise inits gain parameters, field types tighten (`String` →
`TID`), and optionality flips. Some of that is source-compatible and some is
not, and the allowlist deliberately does not distinguish them.

Tagging a regen as a patch is what broke Catbird at 1.0.7 — three call sites
(`DraftSyncService`, `PostManager`, `UIKitThreadView`) stopped compiling on
what consumers had every right to treat as a drop-in fix. Under
`.upToNextMinor`, a correctly-numbered minor is simply not picked up until a
consumer opts in, which is the whole point.

Release train: a Petrel tag requires matching PetrelCatbird and CatbirdMLSCore
tags (CatbirdMLSCore pins **both**), then a Catbird `Package.resolved` bump.

## High-Level Architecture

### Code Generation Pipeline
The project uses a Python-based generator that reads Lexicon JSON files and produces Swift and Kotlin code:
- Entry point: `run.py` → `generator/main.py`; configuration via JSON manifests in `generator/manifests/`
- Templates: `generator/templates/` (Jinja2; `kotlin/` subdir for Kotlin)
- Input: `generator/lexicons/` (standard namespaces only, synced from bluesky-social/atproto; custom lexicons live in overlay packages such as ../PetrelCatbird)
- Output: `Sources/Petrel/Generated/` (Swift), `kotlin/src/main/kotlin/com/atproto/generated/` (Kotlin)
- `exclude_namespaces` in the manifest filters generation (default excludes `tools.ozone`)
- Overlay mode (`package.kind: "overlay"`): generates a separate package against this core — extension-declared client namespaces + decoder-registry registration

### Authentication Architecture
The authentication system supports both OAuth and legacy authentication:
- `AuthenticationService`: Core authentication manager handling tokens and DPoP keys
- `TokenRefreshCoordinator`: Manages automatic token refresh with retry logic
- `KeychainManager`: Secure storage for credentials
- All tokens stored in keychain with proper access control

### Networking Layer
- `NetworkService` protocol: Abstraction for network operations
- Automatic retry for expired tokens (401 responses)
- DPoP (Demonstrating Proof-of-Possession) support for enhanced security
- Request signing and authentication header injection

### API Organization
APIs are organized using namespace properties on the main `ATProtoClient` actor:
- Example: `client.com.atproto.repo.createRecord()` maps to the `com.atproto.repo.createRecord` XRPC endpoint
- Each Lexicon becomes a Swift file (e.g., `app.bsky.feed.post` → `AppBskyFeedPost`)
- Input/Output types are strongly typed structs

### Key Components
- `ATProtoClient`: Main actor-based client for thread-safe API access
- `AccountManager`: Manages user accounts and profiles
- `DIDDocHandler`: Handles DID document resolution and caching
- `RichText`: Utilities for handling Bluesky rich text format
- `TIDGenerator`: Generates Time-based IDs for records
- `CID`: Content Identifier handling for IPLD

### Concurrency Model
The project uses Swift's actor model for thread safety:
- Main client is an actor to prevent data races
- Extensive use of async/await for all network operations
- TokenRefreshCoordinator uses actor isolation for concurrent token refresh

### Error Handling
- `NetworkError` enum for all networking errors
- Proper error propagation through async throws
- Retry logic for transient failures

## Coding Style

- SwiftFormat config: `.swiftformat`
- 2-space indentation
- Swift 6 strict concurrency: actor-based client, async/await throughout