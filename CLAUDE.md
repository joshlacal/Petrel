# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Petrel is a Swift library providing a complete implementation of the ATProtocol and Bluesky APIs. The codebase uses automated code generation from Bluesky's Lexicon JSON files to create Swift types and networking code.

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

# Overlay package (PetrelCatbird — Catbird's custom lexicons), run from this repo root
python3 run.py --manifest ../PetrelCatbird/manifests/petrel-catbird.json

# Legacy positional CLI still works:
python3 run.py generator/lexicons Sources/Petrel/Generated --language both
```
The committed generated code is post-SwiftFormat; raw generator output differs
until `swiftformat Sources/Petrel/Generated` runs (CI enforces the regen+format
round-trip producing an empty diff).

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