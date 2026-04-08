# Configurable ATProtoClient Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Petrel's ATProtoClient support unauthenticated requests, CAB OAuth, and easy lightweight client creation.

**Architecture:** Auth becomes an optional subsystem on the same `ATProtoClient` actor. Shared OAuth machinery is extracted from `PublicOAuthStrategy` into `OAuthCore`. A new `CABOAuthStrategy` composes `OAuthCore` and adds the client assertion fetch step. The Jinja template is the source of truth for the client — all changes to `ATProtoClient` go through the template, then regenerate.

**Tech Stack:** Swift 6, Swift Testing, Jinja2 generator, P256/DPoP/PKCE (jose-swift)

---

### Task 1: Update AuthMode Enum and APIError in Generator Template

**Files:**
- Modify: `Generator/templates/ATProtoClientGeneratedMain.jinja:10-33`

- [ ] **Step 1: Add `.none` and `.cab` cases to AuthMode**

In `Generator/templates/ATProtoClientGeneratedMain.jinja`, replace the AuthMode enum (lines 10-20):

```swift
// MARK: - Authentication Mode Enum

/// Enum to represent the available authentication modes.
public enum AuthMode: Sendable {
    /// No authentication — raw XRPC calls only.
    case none
    /// Legacy password-based authentication (App Passwords).
    case legacy
    /// Public OAuth for mobile/native apps (PAR + PKCE + DPoP).
    case publicOAuth
    /// Confidential gateway authentication via a backend service.
    case gateway
    /// Client Assertion Backend — DPoP-bound client assertions for confidential browser-based apps.
    case cab(backendURL: URL)
}
```

- [ ] **Step 2: Add `authenticationRequired` case to APIError**

In the same file, replace the APIError enum (lines 24-33):

```swift
/// Errors that can occur during API operations
enum APIError: Error {
    case expiredToken
    case invalidToken
    case invalidResponse
    case methodNotSupported
    case authorizationFailed
    case invalidPDSURL
    case serviceNotInitialized
    case unauthenticatedClient(String)
}
```

Note: Changing from `String` raw value to plain enum since `unauthenticatedClient` has an associated value. Check all `APIError` usage sites to ensure backward compatibility — search for `APIError.expiredToken`, `APIError.serviceNotInitialized` raw value usage.

- [ ] **Step 3: Verify no code relies on APIError raw values**

Run:
```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel && grep -rn "APIError.*rawValue\|APIError(rawValue" Sources/ Tests/
```

If any matches exist, update them. If none, the change is safe.

- [ ] **Step 4: Commit**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
git add Generator/templates/ATProtoClientGeneratedMain.jinja
git commit -m "Petrel: add .none and .cab auth modes, add unauthenticatedClient error"
```

---

### Task 2: Make Auth Properties Optional and Add Convenience Init

**Files:**
- Modify: `Generator/templates/ATProtoClientGeneratedMain.jinja:80-209`

- [ ] **Step 1: Make auth properties optional**

Replace the properties section (lines 81-109) with:

```swift
    // MARK: - Properties

    /// The network service used for all API requests.
    let networkService: NetworkService

    /// The authentication manager handling all auth strategies.
    private let authManager: AuthManager?

    /// The account manager for handling multiple accounts.
    private let accountManager: AccountManager?

    /// The DID resolver for resolving DIDs to handles and PDS URLs.
    let didResolver: (any DIDResolving)?

    /// The storage layer for persistent data.
    private let storage: KeychainStorage?

    /// The OAuth configuration.
    private let oauthConfig: OAuthConfig?

    /// The delegate for authentication events.
    private weak var authDelegate: AuthenticationDelegate?

    /// Temporary storage for account info after OAuth callback
    private var justAuthenticatedAccount: (did: String, handle: String?, pdsURL: URL)?

    /// Whether the client is operating in gateway mode (all requests go through gateway)
    private let isGatewayMode: Bool

    /// The authentication mode.
    public let authMode: AuthMode
```

- [ ] **Step 2: Add unauthenticated convenience init**

Add this init **before** the existing `public init(baseURL:oauthConfig:...)` (before the `// MARK: - Initialization` section):

```swift
    // MARK: - Unauthenticated Initialization

    /// Creates a lightweight unauthenticated client for public XRPC calls.
    /// No keychain, account manager, or auth strategy is created.
    /// - Parameters:
    ///   - baseURL: The base URL for API requests (typically a PDS URL).
    ///   - userAgent: Optional user agent string for requests.
    ///   - didResolver: Optional custom DID resolver implementation.
    public init(
        baseURL: URL,
        userAgent: String? = nil,
        didResolver: (any DIDResolving)? = nil
    ) async {
        self.authMode = .none
        self.isGatewayMode = false
        self.authManager = nil
        self.accountManager = nil
        self.storage = nil
        self.oauthConfig = nil

        networkService = NetworkService(baseURL: baseURL)

        if let userAgent {
            await networkService.setUserAgent(userAgent)
        }

        if let didResolver {
            self.didResolver = didResolver
        } else {
            self.didResolver = await DIDResolutionService(networkService: networkService)
        }
    }
```

- [ ] **Step 3: Update existing init to set authMode**

In the existing `public init(baseURL:oauthConfig:namespace:authMode:...)`, add `self.authMode = authMode` at the beginning of the init body, after `self.oauthConfig = oauthConfig`:

```swift
        storage = KeychainStorage(namespace: namespace, accessGroup: accessGroup)
        self.oauthConfig = oauthConfig
        self.authMode = authMode
```

Also update the `AuthMode` → `AuthManager.Mode` switch to handle the new cases (replace lines 179-188):

```swift
        // Convert AuthMode to AuthManager.Mode
        let managerMode: AuthManager.Mode
        switch authMode {
        case .none:
            fatalError("Use the unauthenticated init for .none mode")
        case .legacy:
            managerMode = .legacy
        case .publicOAuth:
            managerMode = .publicOAuth
        case .gateway:
            managerMode = .gateway
        case .cab(let backendURL):
            managerMode = .cab(backendURL: backendURL)
        }
```

- [ ] **Step 4: Commit**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
git add Generator/templates/ATProtoClientGeneratedMain.jinja
git commit -m "Petrel: optional auth properties and unauthenticated convenience init"
```

---

### Task 3: Add Auth Guards to All Auth Methods

**Files:**
- Modify: `Generator/templates/ATProtoClientGeneratedMain.jinja:270-640`

Every auth method needs a guard. Apply this pattern to each method listed below.

- [ ] **Step 1: Guard auth-dependent methods**

Add `guard let authManager` to the top of each of these methods:

**`hasValidSession` (around line 312):**
```swift
    public func hasValidSession() async -> Bool {
        guard let authManager else { return false }
        let (did, _, _) = await getActiveAccountInfo()
        // ... rest unchanged
    }
```

**`refreshToken` (around line 330):**
```swift
    public func refreshToken() async throws -> Bool {
        guard let authManager else {
            throw APIError.unauthenticatedClient("Cannot refresh token on an unauthenticated client")
        }
        let result = try await authManager.refreshTokenIfNeeded()
        return result == .refreshedSuccessfully
    }
```

**`startSignUpFlow` (around line 354):**
```swift
    public func startSignUpFlow(pdsURL: URL = URL(string: "https://bsky.social")!) async throws -> URL {
        guard let authManager else {
            throw APIError.unauthenticatedClient("Cannot start sign-up flow on an unauthenticated client")
        }
        return try await authManager.startOAuthFlowForSignUp(pdsURL: pdsURL, bskyAppViewDID: nil, bskyChatDID: nil)
    }
```

**`setAuthProgressDelegate` (around line 381):**
```swift
    public func setAuthProgressDelegate(_ delegate: AuthProgressDelegate?) async {
        await authManager?.setProgressDelegate(delegate)
    }
```

**`setFailureDelegate` (around line 387):**
```swift
    public func setFailureDelegate(_ delegate: AuthFailureDelegate?) async {
        await authManager?.setFailureDelegate(delegate)
    }
```

**`attemptRecoveryFromServerFailures` (around line 394):**
```swift
    public func attemptRecoveryFromServerFailures(for did: String? = nil) async throws {
        guard let authManager else {
            throw APIError.unauthenticatedClient("Cannot attempt recovery on an unauthenticated client")
        }
        try await authManager.attemptRecoveryFromServerFailures(for: did)
    }
```

**`startOAuthFlow` (around line 404):**
```swift
    public func startOAuthFlow(identifier: String? = nil, bskyAppViewDID: String? = nil, bskyChatDID: String? = nil) async throws -> URL {
        guard let authManager else {
            throw APIError.unauthenticatedClient("Cannot start OAuth flow on an unauthenticated client")
        }
        return try await authManager.startOAuthFlow(identifier: identifier, bskyAppViewDID: bskyAppViewDID, bskyChatDID: bskyChatDID)
    }
```

**`loginWithPassword` (around line 416):**
```swift
    @discardableResult
    public func loginWithPassword(
        identifier: String,
        password: String,
        bskyAppViewDID: String? = nil,
        bskyChatDID: String? = nil
    ) async throws -> (did: String, handle: String?, pdsURL: URL) {
        guard let authManager else {
            throw APIError.unauthenticatedClient("Cannot login on an unauthenticated client")
        }
        let accountInfo = try await authManager.loginWithPassword(
            identifier: identifier,
            password: password,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        )
        justAuthenticatedAccount = accountInfo
        await initializeFromStoredAccount()
        return accountInfo
    }
```

**`handleOAuthCallback` (around line 440):**
```swift
    public func handleOAuthCallback(url: URL) async throws {
        guard let authManager else {
            throw APIError.unauthenticatedClient("Cannot handle OAuth callback on an unauthenticated client")
        }
        let accountInfo = try await authManager.handleOAuthCallback(url: url)
        justAuthenticatedAccount = accountInfo
        LogManager.logDebug("Stored temporary account info: \(accountInfo.did)")
        await initializeFromStoredAccount()
    }
```

**`logout` (around line 453):**
```swift
    public func logout() async throws {
        guard let authManager else {
            throw APIError.unauthenticatedClient("Cannot logout on an unauthenticated client")
        }
        try await authManager.logout()
    }
```

**`cancelOAuthFlow` (around line 458):**
```swift
    public func cancelOAuthFlow() async {
        await authManager?.cancelOAuthFlow()
    }
```

**`switchAuthMode` (around line 464):**
```swift
    public func switchAuthMode(_ mode: AuthMode) async throws {
        guard let authManager else {
            throw APIError.unauthenticatedClient("Cannot switch auth mode on an unauthenticated client")
        }
        let managerMode: AuthManager.Mode
        switch mode {
        case .none:
            throw APIError.unauthenticatedClient("Cannot switch to .none mode — create a new unauthenticated client instead")
        case .legacy:
            managerMode = .legacy
        case .publicOAuth:
            managerMode = .publicOAuth
        case .gateway:
            managerMode = .gateway
        case .cab(let backendURL):
            managerMode = .cab(backendURL: backendURL)
        }
        try await authManager.switchMode(managerMode)
    }
```

**`currentAuthMode` (around line 478):**
```swift
    public var currentAuthMode: AuthMode {
        get async {
            return authMode
        }
    }
```

**`getActiveAccountInfo` (around line 495):** Guard `accountManager`:
```swift
    public func getActiveAccountInfo() async -> (did: String?, handle: String?, pdsURL: URL?) {
        LogManager.logDebug("getActiveAccountInfo called")

        if let tempAccount = justAuthenticatedAccount {
            LogManager.logDebug("Found temporary account: \(tempAccount.did)")
            if let accountManager, let account = await accountManager.getCurrentAccount(), account.did == tempAccount.did {
                LogManager.logDebug("AccountManager ready, using AccountManager but keeping temp storage")
                return (did: account.did, handle: account.handle, pdsURL: account.pdsURL)
            } else {
                LogManager.logDebug("AccountManager not ready, using temp account")
                return (did: tempAccount.did, handle: tempAccount.handle, pdsURL: tempAccount.pdsURL)
            }
        }

        LogManager.logDebug("Falling back to AccountManager query")
        if let accountManager, let account = await accountManager.getCurrentAccount() {
            LogManager.logDebug("AccountManager returned account: \(account.did)")
            return (did: account.did, handle: account.handle, pdsURL: account.pdsURL)
        } else {
            LogManager.logWarning("AccountManager returned nil - authentication state may be inconsistent")
            return (did: nil, handle: nil, pdsURL: nil)
        }
    }
```

**`listAccounts` (around line 535):**
```swift
    public func listAccounts() async -> [Account] {
        guard let accountManager else { return [] }
        return await accountManager.listAccounts()
    }
```

**`switchToAccount` (around line 541):**
```swift
    public func switchToAccount(did: String) async throws {
        guard let accountManager else {
            throw APIError.unauthenticatedClient("Cannot switch accounts on an unauthenticated client")
        }
        try await accountManager.setCurrentAccount(did: did)
        if let account = await accountManager.getAccount(did: did) {
            if !isGatewayMode {
                await networkService.setBaseURL(account.pdsURL)
            }
            await networkService.setServiceDID(account.bskyAppViewDID, for: "app.bsky")
            await networkService.setServiceDID(account.bskyChatDID, for: "chat.bsky")
        }
    }
```

**`removeAccount` (around line 562):**
```swift
    public func removeAccount(did: String) async throws {
        guard let accountManager else {
            throw APIError.unauthenticatedClient("Cannot remove accounts on an unauthenticated client")
        }
        try await accountManager.removeAccount(did: did)
    }
```

**`updateAndPersistServiceDIDs` (around line 582):**
```swift
    public func updateAndPersistServiceDIDs(bskyAppViewDID: String, bskyChatDID: String) async throws {
        guard let accountManager else {
            throw APIError.unauthenticatedClient("Cannot persist service DIDs on an unauthenticated client")
        }
        await updateServiceDIDs(bskyAppViewDID: bskyAppViewDID, bskyChatDID: bskyChatDID)
        try await accountManager.updateServiceDIDs(bskyAppViewDID: bskyAppViewDID, bskyChatDID: bskyChatDID)
    }
```

**`getCurrentAccount` (around line 594):**
```swift
    public func getCurrentAccount() async -> Account? {
        return await accountManager?.getCurrentAccount()
    }
```

**`getDid` (around line 292):**
```swift
    public func getDid() async throws -> String {
        guard authManager != nil else {
            throw APIError.unauthenticatedClient("No authenticated session on unauthenticated client")
        }
        let (did, _, _) = await getActiveAccountInfo()
        guard let did else { throw APIError.serviceNotInitialized }
        return did
    }
```

**`getHandle` (around line 300):**
```swift
    public func getHandle() async throws -> String {
        guard authManager != nil else {
            throw APIError.unauthenticatedClient("No authenticated session on unauthenticated client")
        }
        let (_, handle, _) = await getActiveAccountInfo()
        guard let handle else { throw APIError.serviceNotInitialized }
        return handle
    }
```

**`initializeFromStoredAccount` (around line 230):** Guard on `accountManager`:
```swift
    private func initializeFromStoredAccount() async {
        guard let accountManager else { return }
        LogManager.logInfo("ATProtoClient - initializeFromStoredAccount called, isGatewayMode: \(isGatewayMode)")
        if let account = await accountManager.getCurrentAccount() {
            // ... rest unchanged, but guard authManager for the refresh call:
            if let authManager {
                do {
                    _ = try await authManager.refreshTokenIfNeeded()
                } catch let error as AuthError where error == .dpopKeyError {
                    LogManager.logInfo("Attempting one final explicit token refresh after DPoP error")
                    do {
                        _ = try await authManager.refreshTokenIfNeeded()
                    } catch {
                        LogManager.logError("Final explicit refresh failed: \(error)")
                        authDelegate?.authenticationRequired(client: self)
                    }
                } catch {
                    authDelegate?.authenticationRequired(client: self)
                }
            }
        } else {
            LogManager.logWarning("ATProtoClient - initializeFromStoredAccount: No current account found!")
        }
    }
```

**`validateAuthenticationState` (around line 214):** Guard on `storage`:
```swift
    private func validateAuthenticationState() async {
        guard let storage else { return }
        let validationResult = await storage.validateAndRepairAuthenticationState()
        // ... rest unchanged
    }
```

**`applicationDidBecomeActive` (around line 271):** No change needed — already calls the guarded methods.

**`baseURL` computed property (around line 361):** Guard `accountManager`:
```swift
    public var baseURL: URL {
        get async {
            if let accountManager, let account = await accountManager.getCurrentAccount() {
                return account.pdsURL
            } else {
                return await networkService.baseURL
            }
        }
    }
```

- [ ] **Step 2: Commit**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
git add Generator/templates/ATProtoClientGeneratedMain.jinja
git commit -m "Petrel: add auth guards to all auth-dependent methods in template"
```

---

### Task 4: Regenerate ATProtoClient and Verify Build

**Files:**
- Regenerate: `Sources/Petrel/Generated/Client/ATProtoClient+Generated.swift`

- [ ] **Step 1: Regenerate the client**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
python run.py Generator/lexicons Sources/Petrel/Generated
```

- [ ] **Step 2: Build to verify**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel && swift build
```

Fix any compilation errors. Common issues:
- `APIError` raw value usage if any code used `.rawValue` on the old `String`-backed enum
- Optional chaining needed where `authManager` was previously non-optional
- Force-unwrap of `storage` or `accountManager` in helper methods

- [ ] **Step 3: Run existing tests**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel && swift test
```

Fix any test failures. Tests that use `ATProtoClient(oauthConfig:, namespace:)` should still work — the authenticated init is unchanged.

- [ ] **Step 4: Commit**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
git add Sources/Petrel/Generated/Client/ATProtoClient+Generated.swift
git commit -m "Petrel: regenerate ATProtoClient with optional auth and .none/.cab modes"
```

---

### Task 5: Update AuthManager for CAB Mode

**Files:**
- Modify: `Sources/Petrel/Auth/AuthManager.swift`

- [ ] **Step 1: Add `.cab` to AuthManager.Mode**

Replace the Mode enum (lines 17-24):

```swift
    enum Mode: Sendable {
        /// Legacy password-based authentication (App Passwords).
        case legacy
        /// Public OAuth for mobile/native apps (PAR + PKCE + DPoP).
        case publicOAuth
        /// Confidential gateway authentication via Nest.
        case gateway
        /// Client Assertion Backend — DPoP-bound client assertions.
        case cab(backendURL: URL)
    }
```

- [ ] **Step 2: Update strategy factory**

Add the `.cab` case to `createStrategy` (after the `.gateway` case, around line 146):

```swift
        case .cab(let backendURL):
            return CABOAuthStrategy(
                backendURL: backendURL,
                storage: storage,
                accountManager: accountManager,
                networkService: networkService,
                oauthConfig: oauthConfig,
                didResolver: didResolver
            )
```

- [ ] **Step 3: Update switchMode to handle .cab**

In `switchMode` (line 100), `Mode` is `Equatable` via enum synthesis — no change needed since `.cab` has an associated value, but verify that `guard mode != currentMode` still compiles. If `Mode` doesn't auto-synthesize `Equatable` due to the `URL` associated value, add conformance:

```swift
    enum Mode: Sendable, Equatable {
```

`URL` conforms to `Equatable`, so this should synthesize automatically.

- [ ] **Step 4: This will not compile yet** — `CABOAuthStrategy` doesn't exist. That's fine; we'll create it in Task 7. Commit the AuthManager change:

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
git add Sources/Petrel/Auth/AuthManager.swift
git commit -m "Petrel: add .cab mode to AuthManager with strategy factory case"
```

---

### Task 6: Extract OAuthCore from PublicOAuthStrategy

**Files:**
- Create: `Sources/Petrel/Auth/OAuth/OAuthCore.swift`
- Modify: `Sources/Petrel/Auth/Strategies/PublicOAuthStrategy.swift`

This is the largest task. The goal is to move shared OAuth machinery into `OAuthCore` so both `PublicOAuthStrategy` and `CABOAuthStrategy` can compose it.

- [ ] **Step 1: Create OAuthCore with shared types and state**

Create `Sources/Petrel/Auth/OAuth/OAuthCore.swift`:

```swift
//
//  OAuthCore.swift
//  Petrel
//
//  Shared OAuth machinery for strategies that use DPoP, PKCE, and PAR.
//  Both PublicOAuthStrategy and CABOAuthStrategy compose this actor.
//

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
import JSONWebAlgorithms
import JSONWebKey
import JSONWebSignature

/// Shared OAuth core providing DPoP, PKCE, PAR, token storage, and nonce management.
actor OAuthCore {
    // MARK: - Dependencies

    let storage: KeychainStorage
    let accountManager: AccountManaging
    let networkService: NetworkService
    let oauthConfig: OAuthConfig
    let didResolver: DIDResolving

    // MARK: - State

    var refreshCoordinators: [String: TokenRefreshCoordinator] = [:]
    let refreshCircuitBreaker = RefreshCircuitBreaker()
    var noncesByThumbprint: [String: [String: String]] = [:]
    var usedRefreshTokens: Set<String> = []
    var activeRefreshTasks: [String: Task<TokenRefreshResult, Error>] = [:]
    var oauthFlowNonces: [String: String] = [:]
    var ambiguousRefreshUntil: [String: Date] = [:]

    /// One-shot override for refresh
    var nextRefreshResourceOverride: String?

    // MARK: - Initialization

    init(
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving
    ) {
        self.storage = storage
        self.accountManager = accountManager
        self.networkService = networkService
        self.oauthConfig = oauthConfig
        self.didResolver = didResolver
    }
}
```

- [ ] **Step 2: Move utility methods from PublicOAuthStrategy to OAuthCore**

Move these private methods from `PublicOAuthStrategy` into `OAuthCore` (changing access from `private` to `func` since the strategies need to call them):

Methods to move (copy the exact implementations from `PublicOAuthStrategy.swift`):
- `generateCodeVerifier()` → `func generateCodeVerifier() -> String`
- `generateCodeChallenge(from:)` → `func generateCodeChallenge(from verifier: String) -> String`
- `base64URLEncode(_:)` → `func base64URLEncode(_ data: Data) -> String`
- `encodeFormData(_:)` → `func encodeFormData(_ params: [String: String]) -> Data`
- `extractAuthorizationCode(from:)` → `func extractAuthorizationCode(from url: URL) -> String?`
- `extractState(from:)` → `func extractState(from url: URL) -> String?`
- `extractNonceFromHeaders(_:)` → `func extractNonceFromHeaders(_ headers: [AnyHashable: Any]) -> String?`
- `canonicalHTU(_:)` → `func canonicalHTU(_ url: URL) -> String`
- `calculateATH(from:)` → `func calculateATH(from token: String) -> String`
- `createJWK(from:)` → `func createJWK(from privateKey: P256.Signing.PrivateKey) throws -> JWK`
- `calculateJWKThumbprint(jwk:)` → `func calculateJWKThumbprint(jwk: JWK) throws -> String`
- `createDPoPProof(for:url:type:did:ephemeralKey:nonce:)` — full implementation
- `getOrCreateDPoPKey(for:)` — full implementation
- `updateDPoPNonceInternal(domain:nonce:for:)` — full implementation
- `resolveAuthServer(for:)` — full implementation
- `pushAuthorizationRequest(...)` — full implementation
- `fetchProtectedResourceMetadata(pdsURL:)` — full implementation
- `fetchAuthorizationServerMetadata(authServerURL:)` — full implementation
- `revokeToken(refreshToken:endpoint:did:)` — full implementation

Also move the DPoP nonce management method that conforms to `AuthenticationProvider`:
- `updateDPoPNonce(for:from:did:jkt:)` — full implementation

And the token preparation:
- `prepareAuthenticatedRequest(_:)` — full implementation
- `prepareAuthenticatedRequestWithContext(_:)` — full implementation

And refresh coordination:
- `refreshTokenIfNeeded()` / `refreshTokenIfNeeded(forceRefresh:)` — the deduplication and circuit breaker logic (but NOT `performActualRefresh` — that stays strategy-specific)
- `tokensExist()` — full implementation

Keep the method bodies exactly as they are in `PublicOAuthStrategy`. Just change `private` to `func` (internal access within the module).

- [ ] **Step 3: Refactor PublicOAuthStrategy to compose OAuthCore**

Replace `PublicOAuthStrategy`'s properties with a single `core: OAuthCore` reference:

```swift
actor PublicOAuthStrategy: AuthStrategy {
    private let core: OAuthCore

    // Delegates (strategy-specific, not shared)
    private weak var progressDelegate: AuthProgressDelegate?
    private weak var failureDelegate: AuthFailureDelegate?

    // OAuth flow deduplication (strategy-specific)
    private var oauthStartInProgress = false
    private var oauthStartTasks: [String: Task<URL, Error>] = [:]

    init(
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving
    ) {
        self.core = OAuthCore(
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            oauthConfig: oauthConfig,
            didResolver: didResolver
        )
    }
```

Then update all method bodies to delegate to `core`:
- `prepareAuthenticatedRequest` → `try await core.prepareAuthenticatedRequest(request)`
- `prepareAuthenticatedRequestWithContext` → `try await core.prepareAuthenticatedRequestWithContext(request)`
- `refreshTokenIfNeeded` → `try await core.refreshTokenIfNeeded()`
- `updateDPoPNonce` → `await core.updateDPoPNonce(...)`
- `tokensExist` → `await core.tokensExist()`
- etc.

Keep `exchangeCodeForTokens`, `sendTokenRequestWithEphemeralKey`, `performActualRefresh`, `performTokenRefresh`, `startOAuthFlow`, `startOAuthFlowForSignUp`, `handleOAuthCallback`, `loginWithPassword`, `logout`, `handleUnauthorizedResponse` on `PublicOAuthStrategy` — these call into `core` for shared utilities but contain strategy-specific logic.

For methods that need access to `core`'s internal state (like `storage`, `oauthConfig`), access them as `core.storage`, `core.oauthConfig`, etc.

- [ ] **Step 4: Build and test**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel && swift build && swift test
```

This refactor must be behavior-preserving. All existing tests must pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
git add Sources/Petrel/Auth/OAuth/OAuthCore.swift Sources/Petrel/Auth/Strategies/PublicOAuthStrategy.swift
git commit -m "Petrel: extract OAuthCore from PublicOAuthStrategy for shared OAuth machinery"
```

---

### Task 7: Implement CABOAuthStrategy

**Files:**
- Create: `Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift`

- [ ] **Step 1: Create CABOAuthStrategy**

Create `Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift`:

```swift
//
//  CABOAuthStrategy.swift
//  Petrel
//
//  Client Assertion Backend strategy for confidential browser-based apps.
//  Reuses OAuthCore for DPoP, PKCE, PAR, and nonce management.
//  Adds a client assertion fetch step before token exchange and refresh.
//
//  See: https://github.com/nicobao/proposals/blob/main/0002-cab.md
//

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
import JSONWebAlgorithms
import JSONWebKey
import JSONWebSignature

/// Response from the Client Assertion Backend.
struct ClientAssertionResponse: Decodable, Sendable {
    let clientId: String
    let clientAssertion: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case clientAssertion = "client_assertion"
    }
}

/// Authentication strategy using Client Assertion Backend (CAB).
/// The client holds its own DPoP key but fetches a DPoP-bound client assertion
/// from a backend before each token request, making it a confidential client.
actor CABOAuthStrategy: AuthStrategy {
    // MARK: - Properties

    private let core: OAuthCore
    private let backendURL: URL

    // Delegates
    private weak var progressDelegate: AuthProgressDelegate?
    private weak var failureDelegate: AuthFailureDelegate?

    // OAuth flow deduplication
    private var oauthStartTasks: [String: Task<URL, Error>] = [:]

    // MARK: - Initialization

    init(
        backendURL: URL,
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving
    ) {
        self.backendURL = backendURL
        self.core = OAuthCore(
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            oauthConfig: oauthConfig,
            didResolver: didResolver
        )
    }

    // MARK: - Client Assertion Fetching

    /// Fetches a DPoP-bound client assertion from the CAB backend.
    /// - Parameters:
    ///   - dpopKey: The DPoP signing key to bind the assertion to.
    ///   - tokenEndpointURL: The token endpoint URL (used for DPoP proof's htu).
    /// - Returns: The client assertion response containing client_id and client_assertion JWT.
    private func fetchClientAssertion(
        dpopKey: P256.Signing.PrivateKey,
        tokenEndpointURL: String
    ) async throws -> ClientAssertionResponse {
        let assertionEndpoint = backendURL.appendingPathComponent("oauth/client-assertion")

        // Create a DPoP proof for the backend endpoint
        let dpopProof = try await core.createDPoPProof(
            for: "POST",
            url: assertionEndpoint.absoluteString,
            type: .tokenRequest,
            did: nil,
            ephemeralKey: dpopKey,
            nonce: nil
        )

        var request = URLRequest(url: assertionEndpoint)
        request.httpMethod = "POST"
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        request.timeoutInterval = 15.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else {
            throw AuthError.invalidOAuthConfiguration
        }

        return try JSONDecoder().decode(ClientAssertionResponse.self, from: data)
    }

    // MARK: - Token Exchange (with client assertion)

    /// Exchanges an authorization code for tokens, including a client assertion.
    private func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        tokenEndpoint: String,
        authServerURL: URL,
        ephemeralKey: P256.Signing.PrivateKey,
        initialNonce: String?,
        resourceURL: URL?
    ) async throws -> TokenResponse {
        // 1. Fetch client assertion from backend
        let assertionResponse = try await fetchClientAssertion(
            dpopKey: ephemeralKey,
            tokenEndpointURL: tokenEndpoint
        )

        // 2. Build token request with client assertion
        guard let url = URL(string: tokenEndpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        var params: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": core.oauthConfig.redirectUri,
            "client_id": assertionResponse.clientId,
            "code_verifier": codeVerifier,
            "client_assertion": assertionResponse.clientAssertion,
            "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        ]
        if let resourceURL {
            params["resource"] = resourceURL.absoluteString
        }
        request.httpBody = core.encodeFormData(params)

        // 3. Create DPoP proof for token endpoint
        let dpopProof = try await core.createDPoPProof(
            for: "POST",
            url: tokenEndpoint,
            type: .tokenRequest,
            did: nil,
            ephemeralKey: ephemeralKey,
            nonce: initialNonce
        )
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")

        // 4. Send request
        let (data, urlResponse) = try await core.networkService.request(request, skipTokenRefresh: true)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if (200 ..< 300).contains(httpResponse.statusCode) {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } else if httpResponse.statusCode == 400 {
            // Handle use_dpop_nonce error
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
               errorResponse.error == "use_dpop_nonce",
               let receivedNonce = core.extractNonceFromHeaders(httpResponse.allHeaderFields)
            {
                // Retry with nonce
                let newProof = try await core.createDPoPProof(
                    for: "POST",
                    url: tokenEndpoint,
                    type: .tokenRequest,
                    did: nil,
                    ephemeralKey: ephemeralKey,
                    nonce: receivedNonce
                )
                var retryRequest = request
                retryRequest.setValue(newProof, forHTTPHeaderField: "DPoP")

                let (retryData, retryResponse) = try await core.networkService.request(retryRequest, skipTokenRefresh: true)
                guard let retryHttp = retryResponse as? HTTPURLResponse,
                      (200 ..< 300).contains(retryHttp.statusCode)
                else {
                    throw AuthError.tokenRefreshFailed
                }
                return try JSONDecoder().decode(TokenResponse.self, from: retryData)
            }
            throw AuthError.invalidCredentials
        } else {
            throw AuthError.tokenRefreshFailed
        }
    }

    // MARK: - Token Refresh (with client assertion)

    private func performActualRefresh(for account: Account, session: Session) async throws -> TokenRefreshResult {
        guard let metadata = account.authorizationServerMetadata,
              let refreshToken = session.refreshToken
        else {
            throw AuthError.tokenRefreshFailed
        }

        // 1. Get DPoP key for this account
        let dpopKey = try await core.getOrCreateDPoPKey(for: account.did)

        // 2. Fetch client assertion
        let assertionResponse = try await fetchClientAssertion(
            dpopKey: dpopKey,
            tokenEndpointURL: metadata.tokenEndpoint
        )

        // 3. Build refresh request with client assertion
        guard let endpointURL = URL(string: metadata.tokenEndpoint) else {
            throw AuthError.tokenRefreshFailed
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": assertionResponse.clientId,
            "client_assertion": assertionResponse.clientAssertion,
            "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        ]
        request.httpBody = core.encodeFormData(params)

        // 4. DPoP proof for token endpoint
        let proof = try await core.createDPoPProof(
            for: "POST", url: metadata.tokenEndpoint, type: .tokenRefresh, did: account.did
        )
        request.setValue(proof, forHTTPHeaderField: "DPoP")

        // 5. Send refresh request
        let (data, response) = try await core.networkService.request(request, skipTokenRefresh: true)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        // Handle nonce retry
        if httpResponse.statusCode == 400 {
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
               errorResponse.error == "use_dpop_nonce",
               let receivedNonce = core.extractNonceFromHeaders(httpResponse.allHeaderFields)
            {
                if let domain = endpointURL.host?.lowercased() {
                    await core.updateDPoPNonceInternal(domain: domain, nonce: receivedNonce, for: account.did)
                }
                let retryProof = try await core.createDPoPProof(
                    for: "POST", url: metadata.tokenEndpoint, type: .tokenRefresh, did: account.did
                )
                var retryRequest = request
                retryRequest.setValue(retryProof, forHTTPHeaderField: "DPoP")

                let (retryData, retryResponse) = try await core.networkService.request(retryRequest, skipTokenRefresh: true)
                guard let retryHttp = retryResponse as? HTTPURLResponse,
                      (200 ..< 300).contains(retryHttp.statusCode)
                else {
                    throw AuthError.tokenRefreshFailed
                }

                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: retryData)
                let newSession = Session(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: tokenResponse.refreshToken,
                    createdAt: Date(),
                    expiresIn: TimeInterval(tokenResponse.expiresIn),
                    tokenType: session.tokenType,
                    did: account.did
                )
                try await core.storage.saveAccountAndSession(account, session: newSession, for: account.did)
                await core.refreshCircuitBreaker.recordSuccess(for: account.did)
                return .refreshedSuccessfully
            }
        }

        if (200 ..< 300).contains(httpResponse.statusCode) {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            let newSession = Session(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                createdAt: Date(),
                expiresIn: TimeInterval(tokenResponse.expiresIn),
                tokenType: session.tokenType,
                did: account.did
            )
            try await core.storage.saveAccountAndSession(account, session: newSession, for: account.did)
            await core.refreshCircuitBreaker.recordSuccess(for: account.did)
            return .refreshedSuccessfully
        } else {
            throw AuthError.tokenRefreshFailed
        }
    }

    // MARK: - AuthStrategy Conformance

    func startOAuthFlow(
        identifier: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        // Reuse the same PAR + PKCE flow as public OAuth.
        // The only difference is at token exchange time, which happens in handleOAuthCallback.
        let key = identifier?.lowercased() ?? "__signup__"

        if let existing = oauthStartTasks[key] {
            return try await existing.value
        }

        let task = Task.detached(priority: .userInitiated) { [weak self] () throws -> URL in
            guard let self else { throw AuthError.invalidOAuthConfiguration }
            return try await self._startOAuthFlowImpl(
                identifier: identifier,
                bskyAppViewDID: bskyAppViewDID,
                bskyChatDID: bskyChatDID
            )
        }
        oauthStartTasks[key] = task
        defer { oauthStartTasks.removeValue(forKey: key) }
        return try await task.value
    }

    func startOAuthFlowForSignUp(
        pdsURL: URL?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        // CAB is for login flows — account creation uses the PDS directly
        throw AuthError.invalidOAuthConfiguration
    }

    func handleOAuthCallback(url: URL) async throws -> (did: String, handle: String?, pdsURL: URL) {
        // Extract code and state from callback
        guard let code = core.extractAuthorizationCode(from: url),
              let state = core.extractState(from: url)
        else {
            throw AuthError.invalidOAuthCallback
        }

        // Load stored OAuth state
        guard let oauthState = try await core.storage.loadOAuthState(forKey: state) else {
            throw AuthError.invalidOAuthCallback
        }

        // Reconstruct ephemeral key
        guard let keyData = oauthState.ephemeralDPoPKeyData else {
            throw AuthError.dpopKeyError
        }
        let ephemeralKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)

        // Exchange code for tokens (with client assertion)
        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: oauthState.codeVerifier,
            tokenEndpoint: oauthState.tokenEndpoint,
            authServerURL: oauthState.authServerURL,
            ephemeralKey: ephemeralKey,
            initialNonce: oauthState.parNonce,
            resourceURL: oauthState.pdsURL
        )

        // Resolve actual PDS from the DID in the token
        let did = tokenResponse.sub ?? ""
        let pdsURL = try await core.didResolver.resolveDIDToPDSURL(did: did)
        let handleAndPDS = try? await core.didResolver.resolveDIDToHandleAndPDSURL(did: did)

        // Save DPoP key
        try await core.storage.saveDPoPKey(ephemeralKey, for: did)

        // Create and save session
        let session = Session(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            createdAt: Date(),
            expiresIn: TimeInterval(tokenResponse.expiresIn),
            tokenType: "DPoP",
            did: did
        )

        let account = Account(
            did: did,
            handle: handleAndPDS?.0,
            pdsURL: pdsURL,
            authorizationServerMetadata: oauthState.authServerMetadata,
            bskyAppViewDID: oauthState.bskyAppViewDID ?? "did:web:api.bsky.app#bsky_appview",
            bskyChatDID: oauthState.bskyChatDID ?? "did:web:api.bsky.chat#bsky_chat"
        )

        try await core.storage.saveAccountAndSession(account, session: session, for: did)
        try await core.accountManager.setCurrentAccount(did: did)

        // Clean up stored OAuth state
        try? await core.storage.deleteOAuthState(forKey: state)

        return (did: did, handle: handleAndPDS?.0, pdsURL: pdsURL)
    }

    func loginWithPassword(
        identifier: String,
        password: String,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> (did: String, handle: String?, pdsURL: URL) {
        throw AuthError.invalidOAuthConfiguration // CAB doesn't support password login
    }

    func logout() async throws {
        // Revoke tokens if possible, then clear storage
        guard let account = await core.accountManager.getCurrentAccount(),
              let session = try? await core.storage.loadSession(for: account.did)
        else {
            return
        }

        if let metadata = account.authorizationServerMetadata,
           let refreshToken = session.refreshToken,
           let revocationEndpoint = metadata.revocationEndpoint
        {
            await core.revokeToken(refreshToken: refreshToken, endpoint: revocationEndpoint, did: account.did)
        }

        try await core.storage.deleteSession(for: account.did)
        try await core.storage.deleteDPoPKey(for: account.did)
    }

    func cancelOAuthFlow() async {
        for task in oauthStartTasks.values {
            task.cancel()
        }
        oauthStartTasks.removeAll()
    }

    func tokensExist() async -> Bool {
        await core.tokensExist()
    }

    func setProgressDelegate(_ delegate: AuthProgressDelegate?) async {
        progressDelegate = delegate
    }

    func setFailureDelegate(_ delegate: AuthFailureDelegate?) async {
        failureDelegate = delegate
    }

    func attemptRecoveryFromServerFailures(for did: String?) async throws {
        if let did {
            await core.refreshCircuitBreaker.reset(for: did)
        }
    }

    // MARK: - AuthenticationProvider Forwarding

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        try await core.prepareAuthenticatedRequest(request)
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        try await core.prepareAuthenticatedRequestWithContext(request)
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        try await core.refreshTokenIfNeeded()
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        // Same as public OAuth — attempt token refresh
        _ = try await core.refreshTokenIfNeeded(forceRefresh: true)
        let (authedRequest, _) = try await core.prepareAuthenticatedRequestWithContext(request)
        let (retryData, retryResponse) = try await core.networkService.request(authedRequest, skipTokenRefresh: true)
        guard let retryHttp = retryResponse as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        return (retryData, retryHttp)
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async {
        await core.updateDPoPNonce(for: url, from: headers, did: did, jkt: jkt)
    }

    // MARK: - Private OAuth Flow Implementation

    private func _startOAuthFlowImpl(
        identifier: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        // Identical to PublicOAuthStrategy._startOAuthFlowImpl
        // Resolves PDS, fetches metadata, creates PKCE + ephemeral DPoP key,
        // performs PAR, saves OAuth state, returns authorization URL
        // The only difference is that token exchange (in handleOAuthCallback)
        // will include a client assertion

        guard let identifier else {
            throw AuthError.invalidOAuthConfiguration
        }

        let did = try await core.didResolver.resolveHandleToDID(handle: identifier)
        let pdsURL = try await core.didResolver.resolveDIDToPDSURL(did: did)
        let authServerURL = try await core.resolveAuthServer(for: pdsURL)
        let metadata = try await core.fetchAuthorizationServerMetadata(authServerURL: authServerURL)

        let ephemeralKey = P256.Signing.PrivateKey()
        let codeVerifier = core.generateCodeVerifier()
        let codeChallenge = core.generateCodeChallenge(from: codeVerifier)
        let state = UUID().uuidString

        let (requestURI, parNonce) = try await core.pushAuthorizationRequest(
            codeChallenge: codeChallenge,
            identifier: identifier,
            endpoint: metadata.pushedAuthorizationRequestEndpoint ?? metadata.tokenEndpoint,
            authServerURL: authServerURL,
            state: state,
            ephemeralKeyForFlow: ephemeralKey
        )

        // Save OAuth state for callback
        let oauthState = OAuthState(
            codeVerifier: codeVerifier,
            state: state,
            tokenEndpoint: metadata.tokenEndpoint,
            authServerURL: authServerURL,
            pdsURL: pdsURL,
            ephemeralDPoPKeyData: ephemeralKey.rawRepresentation,
            parNonce: parNonce,
            authServerMetadata: metadata,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        )
        try await core.storage.saveOAuthState(oauthState, forKey: state)

        // Build authorization URL
        var components = URLComponents(url: authServerURL.appendingPathComponent("authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "request_uri", value: requestURI),
            URLQueryItem(name: "client_id", value: core.oauthConfig.clientId),
        ]

        guard let authURL = components.url else {
            throw AuthError.invalidOAuthConfiguration
        }
        return authURL
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel && swift build
```

Fix compilation issues. Common problems:
- `OAuthCore` method visibility — some methods may need to be `public` or have different access
- Missing type references (`OAuthState`, `TokenResponse`, `OAuthErrorResponse`, `Session`, `Account`, etc.) — these should already be visible within the module
- `core.generateCodeVerifier()` etc. — since `OAuthCore` is an actor, these need `await` if called from outside the actor

- [ ] **Step 3: Run tests**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel && swift test
```

- [ ] **Step 4: Commit**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
git add Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift
git commit -m "Petrel: implement CABOAuthStrategy with DPoP-bound client assertions"
```

---

### Task 8: Write Tests for Unauthenticated Client

**Files:**
- Create: `Tests/PetrelTests/UnauthenticatedClientTests.swift`

- [ ] **Step 1: Write tests**

Create `Tests/PetrelTests/UnauthenticatedClientTests.swift`:

```swift
import Foundation
@testable import Petrel
import Testing

@Suite("Unauthenticated ATProtoClient Tests")
struct UnauthenticatedClientTests {

    @Test("Unauthenticated client initializes with baseURL only")
    func initWithBaseURL() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)

        let url = await client.baseURL
        #expect(url.absoluteString == "https://bsky.social")
    }

    @Test("Unauthenticated client has .none auth mode")
    func authModeIsNone() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)

        #expect(client.authMode == .none)
    }

    @Test("Auth methods throw unauthenticatedClient error")
    func authMethodsThrow() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)

        await #expect(throws: APIError.self) {
            try await client.startOAuthFlow()
        }

        await #expect(throws: APIError.self) {
            try await client.loginWithPassword(identifier: "test", password: "test")
        }

        await #expect(throws: APIError.self) {
            try await client.logout()
        }

        await #expect(throws: APIError.self) {
            try await client.switchAuthMode(.legacy)
        }

        await #expect(throws: APIError.self) {
            try await client.getDid()
        }

        await #expect(throws: APIError.self) {
            try await client.getHandle()
        }

        await #expect(throws: APIError.self) {
            try await client.switchToAccount(did: "did:plc:test")
        }

        await #expect(throws: APIError.self) {
            try await client.removeAccount(did: "did:plc:test")
        }
    }

    @Test("hasValidSession returns false for unauthenticated client")
    func hasValidSessionFalse() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)

        let valid = await client.hasValidSession()
        #expect(valid == false)
    }

    @Test("listAccounts returns empty for unauthenticated client")
    func listAccountsEmpty() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)

        let accounts = await client.listAccounts()
        #expect(accounts.isEmpty)
    }

    @Test("getCurrentAccount returns nil for unauthenticated client")
    func getCurrentAccountNil() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)

        let account = await client.getCurrentAccount()
        #expect(account == nil)
    }

    @Test("API namespaces are available on unauthenticated client")
    func namespacesAvailable() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)

        // The generated namespace chain should be available
        // (actual XRPC calls would fail with 401 from the server, not from the client)
        #expect(client.com != nil)
        #expect(client.app != nil)
    }

    @Test("cancelOAuthFlow is safe on unauthenticated client")
    func cancelOAuthFlowSafe() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)

        // Should not crash — just no-ops
        await client.cancelOAuthFlow()
    }
}
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel && swift test --filter UnauthenticatedClientTests
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
git add Tests/PetrelTests/UnauthenticatedClientTests.swift
git commit -m "Petrel: add tests for unauthenticated ATProtoClient"
```

---

### Task 9: Build Catbird to Verify No Regressions

**Files:**
- No changes — verification only

- [ ] **Step 1: Build Catbird for iOS simulator**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel
xcodebuild -project Catbird/Catbird.xcodeproj -scheme Catbird \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Catbird uses `.gateway` mode exclusively. Since we didn't change the `ConfidentialGatewayStrategy`, `LegacyPasswordStrategy`, or the authenticated init signature, this should build cleanly.

If there are errors, they'll be from:
- `APIError` enum changes (raw value removal)
- Optional property access where Catbird expects non-optional

Fix any issues in the Catbird call sites.

- [ ] **Step 2: Run Petrel full test suite one final time**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel && swift test
```

- [ ] **Step 3: Commit any Catbird fixes if needed**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Catbird
git add -A && git commit -m "Catbird: adapt to Petrel configurable ATProtoClient changes"
```

---

### Task 10: Final Regeneration and Full Verification

**Files:**
- Regenerate: `Sources/Petrel/Generated/Client/ATProtoClient+Generated.swift`

- [ ] **Step 1: Regenerate from template one final time**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
python run.py Generator/lexicons Sources/Petrel/Generated
```

- [ ] **Step 2: Build everything**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel && swift build && swift test
```

- [ ] **Step 3: Verify Catbird builds**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel
xcodebuild -project Catbird/Catbird.xcodeproj -scheme Catbird \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- [ ] **Step 4: Final commit**

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
git add Sources/Petrel/Generated/Client/ATProtoClient+Generated.swift
git commit -m "Petrel: final regeneration with configurable ATProtoClient"
```
