# Configurable ATProtoClient — Design Spec

**Date:** 2026-04-08
**Scope:** Petrel Swift Package

## Problem

ATProtoClient currently requires full auth configuration (OAuthConfig, KeychainStorage, AccountManager) for every instance. This makes it impossible to create a lightweight client for unauthenticated XRPC calls — for example, resolving a DID to a PDS and pulling public records like `place.stream.video`. Additionally, the ATProto ecosystem is gaining a new auth mode (Client Assertion Backend) that Petrel should support.

## Goals

1. Support unauthenticated clients with minimal setup: `ATProtoClient(baseURL: pdsURL)`
2. Add CAB (Client Assertion Backend) OAuth support per the Bluesky proposal
3. Keep the existing `.legacy`, `.publicOAuth`, and `.gateway` paths unchanged
4. Single concrete type (`ATProtoClient`) for all modes — no protocol split

## Approach

Auth becomes an optional subsystem. For `.none` mode, no KeychainStorage, AccountManager, or AuthManager are created. NetworkService sends raw requests without auth headers. For authenticated modes, everything works as today. CAB reuses shared OAuth machinery extracted from PublicOAuthStrategy.

---

## AuthMode Enum

```swift
public enum AuthMode: Sendable {
    case none                      // Unauthenticated — raw XRPC only
    case legacy                    // App Passwords
    case publicOAuth               // PAR + PKCE + DPoP
    case gateway                   // Confidential client via BFF (nest)
    case cab(backendURL: URL)      // Client Assertion Backend
}
```

## ATProtoClient Init Changes

### Convenience init for unauthenticated

```swift
public init(
    baseURL: URL,
    userAgent: String? = nil,
    didResolver: DIDResolving? = nil
) async throws
```

This creates only `NetworkService` and an optional `DIDResolutionService`. Auth properties are nil.

### Existing full init (unchanged signature)

```swift
public init(
    baseURL: URL = URL(string: "https://bsky.social")!,
    oauthConfig: OAuthConfig,
    namespace: String,
    authMode: AuthMode = .publicOAuth,
    gatewayURL: URL? = nil,
    userAgent: String? = nil,
    didResolver: DIDResolving? = nil,
    bskyAppViewDID: String = "did:web:api.bsky.app#bsky_appview",
    bskyChatDID: String = "did:web:api.bsky.chat#bsky_chat",
    accessGroup: String? = nil
) async throws
```

For `.cab(let backendURL)`, the backendURL is passed through to AuthManager which creates a `CABOAuthStrategy`.

## Optional Auth Properties

```swift
public actor ATProtoClient {
    let networkService: NetworkService            // Always present
    private let authManager: AuthManager?         // nil for .none
    private let accountManager: AccountManager?   // nil for .none
    private let storage: KeychainStorage?         // nil for .none
    private let oauthConfig: OAuthConfig?         // nil for .none
    let didResolver: (any DIDResolving)?          // Optional (both paths)
    public let authMode: AuthMode                 // Always present
}
```

All public auth methods (`startOAuthFlow`, `loginWithPassword`, `handleOAuthCallback`, `logout`, `switchAuthMode`, `listAccounts`, `switchToAccount`, `removeAccount`, `hasValidSession`) guard on `authManager` and throw `APIError.authenticationRequired` when nil.

## NetworkService — No Auth Provider Path

NetworkService already stores `authProvider: AuthenticationProvider?`. When nil:
- Skip `prepareAuthenticatedRequest` — send raw request
- Skip 401 retry/refresh logic — throw the error directly
- Skip DPoP nonce extraction

When `authProvider` is nil and a 401 is received, NetworkService throws the HTTP error directly — no retry, no refresh attempt. This is a small guard clause addition in the existing 401 handling block.

## OAuthCore Extraction

Shared OAuth machinery extracted from `PublicOAuthStrategy` into an internal `OAuthCore` actor:

```swift
actor OAuthCore {
    let storage: KeychainStorage
    let accountManager: AccountManaging
    let networkService: NetworkService
    let oauthConfig: OAuthConfig
    let didResolver: DIDResolving

    var refreshCoordinators: [String: TokenRefreshCoordinator]
    let refreshCircuitBreaker: RefreshCircuitBreaker
    var noncesByThumbprint: [String: [String: String]]
    var usedRefreshTokens: Set<String>
    var activeRefreshTasks: [String: Task<TokenRefreshResult, Error>]
}
```

### Methods in OAuthCore

| Method | Purpose |
|--------|---------|
| `generatePKCE()` | Create code_verifier + code_challenge |
| `createEphemeralDPoPKey()` | Generate P256 signing key |
| `createDPoPProof(...)` | Sign a DPoP JWT for a given HTTP method + URL |
| `pushAuthorizationRequest(...)` | PAR with nonce retry |
| `resolveAuthServerMetadata(...)` | Discover token/PAR endpoints |
| `saveDPoPKey(...)` / `loadDPoPKey(...)` | Keychain persistence for DPoP keys |
| `saveOAuthState(...)` / `loadOAuthState(...)` | Persist mid-flow state |
| `persistSession(...)` | Store tokens + account |
| `updateDPoPNonce(...)` | Nonce management |
| `prepareAuthenticatedRequest(...)` | Add Bearer + DPoP headers |
| `deduplicateRefresh(...)` | Single-flight refresh coordination |

## CAB OAuth Strategy

`CABOAuthStrategy` conforms to `AuthStrategy` and composes `OAuthCore`.

### Flow differences from PublicOAuth

**Token exchange:**
1. Create DPoP proof for the CAB backend URL
2. `POST` to `backendURL` with the DPoP proof in the `DPoP` header (empty body)
3. Receive `{ client_id: String, client_assertion: String }` response
4. Include `client_assertion` + `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer` in the token request alongside the standard params (code, code_verifier, DPoP proof)

**Token refresh:**
Same pattern — fetch a fresh client assertion from the backend before hitting the token endpoint with a refresh_token grant.

**Everything else is identical to PublicOAuth:** PAR, PKCE, DPoP key generation, nonce management, callback handling, session persistence.

### CAB properties

```swift
actor CABOAuthStrategy: AuthStrategy {
    private let core: OAuthCore
    private let backendURL: URL
}
```

The backend URL is the only additional configuration. Per the spec, the endpoint:
- Accepts `POST` with a `DPoP` header
- Returns `client_id` and `client_assertion` (a JWT with `cnf.jkt` bound to the DPoP key)
- No additional authentication required (CORS + DPoP binding is sufficient)

## PublicOAuthStrategy Refactor

Refactored to compose `OAuthCore` instead of owning the machinery:

```swift
actor PublicOAuthStrategy: AuthStrategy {
    private let core: OAuthCore
}
```

`exchangeCodeForTokens` and `performActualRefresh` remain on `PublicOAuthStrategy` — they call the token endpoint directly without a client assertion step.

All shared methods delegate to `core`.

---

## File Changes

### New Files

| File | Purpose |
|------|---------|
| `Sources/Petrel/Auth/OAuth/OAuthCore.swift` | Extracted shared OAuth machinery |
| `Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift` | Client Assertion Backend strategy |

### Modified Files

| File | Change |
|------|--------|
| `Generator/templates/ATProtoClientGeneratedMain.jinja` | AuthMode enum (+2 cases), convenience init, optional auth properties, guards on auth methods |
| `Sources/Petrel/Auth/AuthManager.swift` | Add `.cab` to internal Mode enum, strategy factory creates `CABOAuthStrategy` |
| `Sources/Petrel/Auth/Strategies/PublicOAuthStrategy.swift` | Refactor to compose `OAuthCore` instead of owning machinery directly |
| `Sources/Petrel/Network/NetworkService.swift` | Explicit nil check on auth provider in 401 path |

### Regenerated Files

| File | How |
|------|-----|
| `Sources/Petrel/Generated/Client/ATProtoClient+Generated.swift` | Run generator after template changes |

### Unchanged

- All generated XRPC types / request / response structs
- `LegacyPasswordStrategy`
- `ConfidentialGatewayStrategy`
- `DIDResolving` / `DIDResolutionService`
- `KeychainStorage`, `AccountManager`
- Catbird call sites (uses `.gateway`, no API change)

## Consumer Impact

- **Catbird (iOS/macOS):** No changes needed. `.gateway` path untouched.
- **Streamplace fix:** After this work, create `ATProtoClient(baseURL: pdsURL)` and call `listRecords` against the PDS directly for public records.
- **Future CAB consumers:** Pass `.cab(backendURL: URL)` with an `OAuthConfig` to get confidential client behavior without running a full TMB.
- **catmos (Tauri desktop):** Could adopt `.publicOAuth` or `.cab` in the future via the Swift layer.
