# Petrel repository structure

This document outlines the organization of the Petrel repository, covering both the Swift SDK and the Kotlin counterpart.

## Top-level layout

```
Petrel/
├── Sources/              # Swift package source targets
│   ├── Petrel/           # Main AT Protocol SDK library
│   ├── PetrelLoad/       # Concurrency and load testing executable
│   ├── CLibSecretShim/   # C shim for Linux Secret Service (libsecret)
│   └── CLibSecret/       # System library target for libsecret on Linux
├── Tests/                # Test suites for Petrel and test harnesses
│   ├── PetrelTests/      # SDK unit, integration, and auth tests
│   └── PetrelLoadTests/  # Tests for the load harness
├── generator/            # Python code generator for Swift and Kotlin
│   ├── manifests/        # Manifest configurations (petrel-core.json)
│   └── templates/        # Code generation templates
├── kotlin/               # Kotlin multiplatform library implementation
│   └── src/main/kotlin/blue/catbird/petrel/
├── Examples/             # Standalone scripts and example CLI tools
├── Server/               # Standalone petrel-cab-server package
├── Scripts/              # Build, validation, and maintenance scripts
└── docs/                 # Documentation assets and contracts
```

## Swift SDK (`Sources/Petrel/`)

The primary Swift library is divided into functional modules:

- **`Client/`**: High-level client extensions and labeler management.
- **`Core/`**: Core AT Protocol types (CID, DID, ATProtocolDate, ATProtocolURI), CAR archive decoding, and serialization utilities.
- **`Auth/`**: Authentication engine (`AuthManager`), credential managers, token refresh coordinators, and strategy implementations (`OAuth/`, `Space/`, `Strategies/`).
- **`Network/`**: XRPC communication layer (`NetworkService`), DID resolution (`DIDResolving`), host resolution, and IP validation.
- **`Storage/`**: Platform-specific credential storage implementations conforming to `SecureStorage`: `AppleKeychainStore` (macOS/iOS Keychain), `LibSecretStore` (Linux desktop libsecret), and `FileEncryptedStore` (Linux headless AES-GCM).
- **`Account/`**: Multi-account management (`AccountManager`), account switching, and auth event broadcasting.
- **`Logging/`**: Structured OSLog integration (`OSLogHandler`).
- **`Generated/`**: Auto-generated lexicon models and client API namespace accessors:
  - `Client/`: Generated `ATProtoClient` extension properties (`app`, `com`, `chat`).
  - `Lexicons/`: Generated types grouped by namespace (`App/Bsky/`, `Chat/Bsky/`, `Com/Atproto/`).
  - `Compatibility/`: Backward-compatibility shims for earlier releases.
- **`Petrel.docc/`**: DocC documentation catalog (`Petrel.md`, `Authentication.md`, `GettingStarted.md`).

## Kotlin library (`kotlin/`)

The Kotlin implementation mirrors the Swift SDK structure under `kotlin/src/main/kotlin/blue/catbird/petrel/`:

- **`client/`**: `ATProtoClient` implementation and extension methods.
- **`auth/`**: Authentication configuration, token coordination, and gateway handling.
- **`core/`**: Core types, primitives, and serialization helpers.
- **`network/`**: Network transport and XRPC request execution.
- **`runtime/`**: Event subscription and stream processing.
- **`generated/`**: Lexicon definitions and generated client methods emitted by `generator/`.

## Code generation

Code generation is driven by Python scripts in `generator/` and configured via `generator/manifests/petrel-core.json`.

To regenerate both Swift and Kotlin targets from lexicon definitions:

```bash
python3 run.py --manifest generator/manifests/petrel-core.json --language both
swiftformat Sources/Petrel/Generated
```
