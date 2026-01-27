# Petrel Project Structure

This document describes the mirrored directory structure for both the Swift and Kotlin implementations of the Petrel AT Protocol library.

## Design Principles

1. **Mirrored Organization**: Swift and Kotlin codebases follow the same logical structure
2. **Clear Separation of Concerns**: Each module has a specific responsibility
3. **Hierarchical Generated Code**: Lexicon files are organized by namespace
4. **Easy Discovery**: Main client files are separated from generated code

## Directory Structure

### Swift (`Sources/Petrel/`)

```
Sources/Petrel/
├── Client/                              # Main client and extensions
│   ├── Petrel.swift                     # Core client implementation
│   ├── ATProtoClient+Generated.swift    # Generated namespace extensions (AUTO-GENERATED)
│   ├── ATProtoClient+Labelers.swift     # Labeler extensions
│   └── ATProtoClient+Debug.swift        # Debug utilities
│
├── Core/                                # Core types and utilities
│   ├── Types/                           # Protocol types and value containers
│   │   ├── ATProtocolValueContainer.swift  # Type factory (AUTO-GENERATED)
│   │   └── ...                          # CID, DID, custom types
│   ├── Protocols/                       # Swift protocols and interfaces
│   └── Utils/                           # Helper utilities
│       ├── SafeDecoder.swift
│       ├── DateValidation.swift
│       └── QueryParameters.swift
│
├── Auth/                                # Authentication & authorization
│   ├── AuthenticationService.swift
│   ├── KeychainManager.swift
│   ├── OAuth/                           # OAuth-specific code
│   │   ├── OAuthConfig.swift
│   │   └── OAuthCallbackBuffer.swift
│   └── Token/                           # Token management
│       ├── TokenRefreshCoordinator.swift
│       └── RefreshCircuitBreaker.swift
│
├── Network/                             # Networking layer
│   ├── NetworkService.swift
│   ├── RequestDeduplicator.swift
│   ├── DIDResolving.swift
│   ├── HardenedURLSessionDelegate.swift
│   ├── IPAddress.swift
│   └── URLRequest+Extensions.swift
│
├── Storage/                             # Secure storage implementations
│   ├── SecureStorage.swift
│   ├── AppleKeychainStore.swift         # Platform-specific
│   ├── LibSecretStore.swift             # Platform-specific (Linux)
│   ├── FileEncryptedStore.swift
│   └── KeychainStorage.swift
│
├── Account/                             # Account management
│   ├── AccountManager.swift
│   ├── AccountSwitchCoordinator.swift
│   └── LogManager.swift
│
└── Generated/                           # All generated code (AUTO-GENERATED)
    └── Lexicons/                        # Hierarchical lexicon organization
        ├── App/
        │   └── Bsky/                    # app.bsky.* lexicons
        │       ├── AppBskyFeedPost.swift
        │       ├── AppBskyActorProfile.swift
        │       └── ...
        ├── Com/
        │   └── Atproto/                 # com.atproto.* lexicons
        │       ├── ComAtprotoRepoCreateRecord.swift
        │       └── ...
        ├── Chat/
        │   └── Bsky/                    # chat.bsky.* lexicons
        └── Tools/
            └── Ozone/                   # tools.ozone.* lexicons
```

### Kotlin (`petrel-kotlin/src/main/kotlin/com/atproto/`)

```
petrel-kotlin/src/main/kotlin/com/atproto/
├── client/                              # Main client and extensions
│   ├── ATProtoClient.kt                 # Core client implementation
│   └── ATProtoClientGenerated.kt        # Generated namespace extensions (AUTO-GENERATED)
│
├── core/                                # Core types and utilities
│   ├── types/                           # Protocol types
│   │   ├── ATProtoTypes.kt              # Core AT Protocol types
│   │   └── ...                          # CID, DID, custom types
│   ├── protocols/                       # Kotlin interfaces
│   └── utils/                           # Helper utilities
│       ├── SafeDecoder.kt
│       └── QueryParameters.kt
│
├── auth/                                # Authentication & authorization
│   ├── AuthenticationService.kt
│   ├── KeychainManager.kt
│   ├── oauth/                           # OAuth-specific code
│   │   └── OAuthConfig.kt
│   └── token/                           # Token management
│       └── TokenRefreshCoordinator.kt
│
├── network/                             # Networking layer
│   ├── NetworkService.kt
│   ├── RequestDeduplicator.kt
│   └── DIDResolving.kt
│
├── storage/                             # Secure storage implementations
│   ├── SecureStorage.kt
│   ├── KeychainStore.kt                 # Platform-specific
│   └── FileEncryptedStore.kt
│
├── account/                             # Account management
│   ├── AccountManager.kt
│   └── AccountSwitchCoordinator.kt
│
└── generated/                           # All generated code (AUTO-GENERATED)
    └── lexicons/                        # Hierarchical lexicon organization
        ├── app/
        │   └── bsky/                    # app.bsky.* lexicons
        │       ├── AppBskyFeedPost.kt
        │       ├── AppBskyActorProfile.kt
        │       └── ...
        ├── com/
        │   └── atproto/                 # com.atproto.* lexicons
        │       ├── ComAtprotoRepoCreateRecord.kt
        │       └── ...
        ├── chat/
        │   └── bsky/                    # chat.bsky.* lexicons
        └── tools/
            └── ozone/                   # tools.ozone.* lexicons
```

## Module Responsibilities

### Client
Main client implementation and generated namespace extensions. This is the primary entry point for using the library.

### Core
Fundamental types, protocols, and utilities used throughout the library:
- **Types**: AT Protocol core types (CID, DID, ATProtocolDate, etc.)
- **Protocols**: Shared interfaces and protocols
- **Utils**: Helper functions and utilities (query parameters, decoders, validators)

### Auth
Complete authentication and authorization system:
- OAuth flow implementation
- Token management and refresh
- Keychain integration
- Circuit breaker for rate limiting

### Network
Low-level networking:
- HTTP client with retry logic
- Request deduplication
- DID resolution
- Security hardening

### Storage
Secure credential and data storage:
- Platform-specific keychain implementations
- Encrypted file storage
- Secure storage protocols

### Account
High-level account management:
- Multi-account support
- Account switching
- Logging and debugging

### Generated
**AUTO-GENERATED CODE - DO NOT EDIT MANUALLY**

All files in this directory are generated from AT Protocol lexicon definitions. To regenerate:

#### Swift
```bash
python run.py Generator/lexicons Sources/Petrel/Generated
```

#### Kotlin
```bash
python run.py --language kotlin Generator/lexicons petrel-kotlin/src/main/kotlin/com/atproto/generated
```

## Code Generation

The generator creates a hierarchical structure matching the lexicon namespaces:

- Lexicon: `app.bsky.feed.post` → `Generated/Lexicons/App/Bsky/AppBskyFeedPost.swift`
- Lexicon: `com.atproto.repo.createRecord` → `Generated/Lexicons/Com/Atproto/ComAtprotoRepoCreateRecord.swift`

Main client files with namespace extensions are placed in the `Client/` directory for easy access.

## Naming Conventions

### Swift
- **Files**: PascalCase matching the primary type
- **Directories**: PascalCase (Client, Core, Auth, etc.)
- **Generated files**: PascalCase based on lexicon ID

### Kotlin
- **Files**: PascalCase matching the primary type
- **Directories**: lowercase (client, core, auth, etc.)
- **Packages**: lowercase dot-separated (com.atproto.client)
- **Generated files**: PascalCase based on lexicon ID

## Benefits of This Structure

1. **Discoverability**: Easy to find main client files and specific modules
2. **Maintainability**: Clear separation makes code easier to maintain
3. **Consistency**: Mirrored structure reduces cognitive load when switching languages
4. **Scalability**: Hierarchical generated code scales well as lexicons grow
5. **Team Collaboration**: Clear boundaries between manually written and generated code
