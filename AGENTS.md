# AGENTS.md

This file provides guidance to AI coding agents (e.g., Claude Code, GitHub Copilot, OpenAI-based agents) when working with code in this repository.

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
python run.py Generator/lexicons Sources/Petrel/Generated
```

## High-Level Architecture

### Code Generation Pipeline
The project uses a Python-based generator that reads Lexicon JSON files and produces Swift code:
- Entry point: `run.py` → `Generator/main.py`
- Templates: `Generator/templates/` (Jinja2)
- Input: `Generator/lexicons/` (JSON files from Bluesky)
- Output: `Sources/Petrel/Generated/`
- Note: The generator filters out `subscribe` endpoints and Ozone-related code

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
- `TokenRefreshCoordinator` uses actor isolation for concurrent token refresh

### Error Handling
- `NetworkError` enum for all networking errors
- Proper error propagation through async throws
- Retry logic for transient failures

