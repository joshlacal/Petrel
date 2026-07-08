# Client Assertion Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Petrel's `AuthMode.cab` confidential-client flow (assertion at PAR, `aud` plumbing, backend nonce retry) and ship `petrel-cab-server`, a small configurable server that mints DPoP-bound RFC 7523 client assertions, verified end-to-end against real authorization servers.

**Architecture:** Petrel's existing `CABOAuthStrategy` fetches short-lived client-assertion JWTs from a backend before PAR/token/refresh calls; the new `Server/` package (independent SPM package inside the Petrel repo) implements that backend: it validates an incoming DPoP proof, applies device policy, and returns an ES256 assertion with `iss=sub=client_id`, requested `aud`, unique `jti`, and `cnf:{jkt}`. The wire contract doc is the seam both sides implement.

**Tech Stack:** Swift 6 (actors, Swift Testing), Hummingbird 2.25, jose-swift 6.0 (same JOSE library both sides), swift-argument-parser, CryptoKit/swift-crypto.

**Spec:** `docs/superpowers/specs/2026-07-08-client-assertion-backend-design.md`

## Global Constraints

- Petrel repo root is `/Users/joshlacalamito/Developer/Catbird+Petrel/Petrel` — all paths below are relative to it. Run Petrel commands from the repo root; run Server commands from `Server/`.
- Swift 6 strict concurrency everywhere. Petrel sources use 2-space indent — EXCEPT `Sources/Petrel/Auth/AuthenticationService.swift`, which uses 4-space indent; match the file you are editing.
- New tests use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), never XCTest.
- Do NOT touch anything under `Sources/Petrel/Generated/` — no codegen is involved in this project.
- The Petrel SDK gains ZERO new dependencies; only the `Server/` package (its own `Package.swift`) depends on Hummingbird.
- Dependency direction: `Server/` may depend on Petrel (path `".."`) for its demo executable and integration tests; Petrel never depends on Server.
- Assertion type constant everywhere: `urn:ietf:params:oauth:client-assertion-type:jwt-bearer`.
- Defaults from the spec: assertion TTL 60 s; DPoP proof `iat` window ±300 s; nonce requirement off by default.
- jose-swift gotchas (verified against the 6.0.0 checkout): `JWS.verify(key:)` returns `true` unconditionally for `alg: "none"` — always pin `protectedHeader.algorithm == .ES256` BEFORE verifying; raw `JWS(payload:protectedHeader:key:)` does not set `typ` unless you pass `type:`; `JWT.signed` force-defaults `typ` to `"JWT"` when nil.
- If `swift build` hangs on macOS: `export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)` and `pkill -9 -f swift-build` to clear stale locks.
- Commit prefixes: `Petrel:` for SDK changes, `cab-server:` for Server/ changes, `docs:` for docs-only. This repo is jj-colocated; plain `git add`/`git commit` works and is what the steps below use.
- Definition of done for the whole plan: Task 16's e2e login succeeds against bsky.social AND joshpds.duckdns.org with observable output — green unit tests alone do NOT count.

## File Structure

```
Petrel/
  docs/cab-backend-contract.md                     # NEW — wire contract (Task 1)
  Sources/Petrel/Auth/OAuth/OAuthCore.swift        # MODIFIED — buildPARParameters + additionalParameters (Task 2)
  Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift  # MODIFIED — fetch v2, PAR injection (Tasks 3–4)
  Sources/Petrel/Auth/AuthenticationService.swift  # MODIFIED — AuthError.clientAssertionBackendError (Task 3)
  Tests/PetrelTests/Auth/PARParameterTests.swift   # NEW (Task 2)
  Tests/PetrelTests/Auth/ClientAssertionFetchTests.swift  # NEW (Task 3, includes MockURLProtocol)
  Server/                                          # NEW independent SPM package
    Package.swift
    config.example.json
    README.md
    Dockerfile
    deploy/petrel-cab-server.service
    Sources/PetrelCABServerCore/
      JSONValue.swift            # any-JSON Codable passthrough
      ServerConfig.swift         # config file + env overrides + validation
      KeyStore.swift             # PEM loading, active kid, JWKS document
      OAuthErrors.swift          # CABRequestError, HTTPField.Name extensions, error body
      DPoPValidator.swift        # proof parse/verify/claims pipeline
      ReplayStore.swift          # jti replay actor
      NonceService.swift         # stateless HMAC nonces
      DeviceStore.swift          # protocol + InMemoryDeviceStore
      AssertionMinter.swift      # signs the client assertion
      RateLimiter.swift          # token bucket actor
      CABServer.swift            # ties it together: buildRouter()/buildApplication()
    Sources/petrel-cab-server/ServerCommand.swift  # ArgumentParser: serve + generate-key
    Sources/petrel-cab-demo/DemoCommand.swift      # e2e demo CLI (depends on Petrel)
    Tests/PetrelCABServerCoreTests/                # unit tests per component
    Tests/PetrelCABIntegrationTests/               # Petrel client ↔ real server over HTTP
```

---

### Task 1: Wire contract document

**Files:**
- Create: `docs/cab-backend-contract.md`

**Interfaces:**
- Produces: the contract text that Tasks 3, 7, 10 implement. No code.

- [ ] **Step 1: Write the contract doc**

Write `docs/cab-backend-contract.md` with exactly this content:

````markdown
# CAB Backend Wire Contract (v2)

The seam between Petrel's `AuthMode.cab` client and any client-assertion
backend. `petrel-cab-server` is the reference implementation.

## Request

```
POST {backend}/oauth/client-assertion
DPoP: <proof>
Content-Type: application/x-www-form-urlencoded

aud=<authorization server issuer URL>     (required)
```

The `DPoP` header is an RFC 9449 proof signed by the **session's DPoP key**
(the ephemeral flow key during authorization, the per-DID key for refresh):
`typ: "dpop+jwt"`, `alg: ES256`, embedded public `jwk`; claims `htm: "POST"`,
`htu: <this endpoint>`, fresh `iat`, unique `jti`, and `nonce` when the
backend has issued one.

`aud` is the **issuer** value from the authorization server's metadata
(`/.well-known/oauth-authorization-server` → `issuer`) — the AS the client is
about to authenticate to. It varies per user in a multi-PDS world.

## Success response (200)

```
Content-Type: application/json
Cache-Control: no-store

{ "client_id": "https://…/oauth-client-metadata.json",
  "client_assertion": "eyJ…" }
```

The assertion is an ES256 JWS with a `kid` header naming a key published in
the backend's JWKS, and claims:

| claim | value |
|---|---|
| `iss`, `sub` | the client_id |
| `aud` | the requested issuer |
| `jti` | unique per assertion (the AS replay-checks it — clients MUST fetch a fresh assertion per AS request: PAR, token exchange, refresh) |
| `iat` / `exp` | now / now + 60 s (configurable) |
| `cnf` | `{ "jkt": "<RFC 7638 thumbprint of the DPoP proof's key>" }` |

## Error responses

OAuth-style JSON: `{ "error": "...", "error_description": "..." }`.

| Status | `error` | Client behavior |
|---|---|---|
| 400 | `use_dpop_nonce` | `DPoP-Nonce` response header carries a nonce; retry ONCE with it in the proof. A second challenge is a hard failure. |
| 400 | `invalid_dpop_proof` | Hard failure. |
| 400 | `invalid_request` | Missing/malformed `aud`, or `aud` rejected by allowlist. |
| 403 | `access_denied` | Device (`jkt`) refused by backend policy. |
| 429 | `rate_limited` | Back off. |

## Notes

- The endpoint is intentionally unauthenticated beyond the DPoP proof
  (per the upstream proposal); backends mitigate with rate limits and
  per-`jkt` device policy, and MAY add their own auth.
- The assertion-signing key MUST differ from any DPoP key (the AS rejects
  proofs signed with the client-auth key).
- The `cnf`/`jkt` binding is not yet enforced by `@atproto/oauth-provider`
  (verified 2026-07-06); it is forward-compatible and enforced by the
  backend's own policy meanwhile.
````

- [ ] **Step 2: Commit**

```bash
git add docs/cab-backend-contract.md
git commit -m "docs: CAB backend wire contract v2"
```

---

### Task 2: OAuthCore — `buildPARParameters` + `additionalParameters` on PAR

**Files:**
- Modify: `Sources/Petrel/Auth/OAuth/OAuthCore.swift` (method `pushAuthorizationRequest`, currently at line ~356)
- Test: `Tests/PetrelTests/Auth/PARParameterTests.swift` (new)

**Interfaces:**
- Consumes: existing `OAuthCore` init (`storage:accountManager:networkService:oauthConfig:didResolver:`); test doubles `MockAccountManager`, `MockDIDResolver` already exist at internal scope in `Tests/PetrelTests/Auth/RefreshTokenReliabilityTests.swift` and are visible to new files in the same test target.
- Produces: `func buildPARParameters(codeChallenge:identifier:state:additionalParameters:) -> [String: String]` (internal, on actor `OAuthCore`) and a new trailing parameter `additionalParameters: [String: String]? = nil` on `pushAuthorizationRequest`. Task 4 passes the client assertion through it.

- [ ] **Step 1: Write the failing tests**

Create `Tests/PetrelTests/Auth/PARParameterTests.swift`:

```swift
#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
@testable import Petrel
import Testing

@Suite("PAR parameter construction")
struct PARParameterTests {
  private func makeCore(namespace: String) -> OAuthCore {
    OAuthCore(
      storage: KeychainStorage(namespace: namespace),
      accountManager: MockAccountManager(
        account: Account(
          did: "did:plc:test",
          handle: "test.example",
          pdsURL: URL(string: "https://pds.test")!
        )
      ),
      networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
      oauthConfig: OAuthConfig(
        clientId: "https://client.example/oauth-client-metadata.json",
        redirectUri: "https://client.example/callback",
        scope: "atproto"
      ),
      didResolver: MockDIDResolver()
    )
  }

  @Test("Base parameters match today's PAR body when no extras are given")
  func baseParameters() async {
    let core = makeCore(namespace: "test.par.base")
    let params = await core.buildPARParameters(
      codeChallenge: "challenge123",
      identifier: "alice.test",
      state: "state456",
      additionalParameters: nil
    )
    #expect(params["client_id"] == "https://client.example/oauth-client-metadata.json")
    #expect(params["redirect_uri"] == "https://client.example/callback")
    #expect(params["response_type"] == "code")
    #expect(params["code_challenge_method"] == "S256")
    #expect(params["code_challenge"] == "challenge123")
    #expect(params["state"] == "state456")
    #expect(params["scope"] == "atproto")
    #expect(params["login_hint"] == "alice.test")
    #expect(params["client_assertion"] == nil)
    #expect(params.count == 8)
  }

  @Test("login_hint is omitted when identifier is nil")
  func noLoginHint() async {
    let core = makeCore(namespace: "test.par.nohint")
    let params = await core.buildPARParameters(
      codeChallenge: "c", identifier: nil, state: "s", additionalParameters: nil
    )
    #expect(params["login_hint"] == nil)
    #expect(params.count == 7)
  }

  @Test("Additional parameters merge in (client assertion case)")
  func additionalParametersMerged() async {
    let core = makeCore(namespace: "test.par.extra")
    let params = await core.buildPARParameters(
      codeChallenge: "c", identifier: nil, state: "s",
      additionalParameters: [
        "client_assertion": "eyJ.assertion.sig",
        "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      ]
    )
    #expect(params["client_assertion"] == "eyJ.assertion.sig")
    #expect(params["client_assertion_type"] == "urn:ietf:params:oauth:client-assertion-type:jwt-bearer")
    #expect(params["client_id"] == "https://client.example/oauth-client-metadata.json")
    #expect(params.count == 9)
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter PARParameterTests
```
Expected: COMPILE ERROR — `value of type 'OAuthCore' has no member 'buildPARParameters'`.

- [ ] **Step 3: Implement**

In `Sources/Petrel/Auth/OAuth/OAuthCore.swift`, immediately ABOVE `func pushAuthorizationRequest(` insert:

```swift
  /// Builds the form parameters for a pushed authorization request.
  /// `additionalParameters` (e.g. a confidential client's `client_assertion`)
  /// override base entries on key collision.
  func buildPARParameters(
    codeChallenge: String,
    identifier: String?,
    state: String,
    additionalParameters: [String: String]? = nil
  ) -> [String: String] {
    var parameters: [String: String] = [
      "client_id": oauthConfig.clientId,
      "redirect_uri": oauthConfig.redirectUri,
      "response_type": "code",
      "code_challenge_method": "S256",
      "code_challenge": codeChallenge,
      "state": state,
      "scope": oauthConfig.scope,
    ]

    if let identifier {
      parameters["login_hint"] = identifier
    }

    if let additionalParameters {
      parameters.merge(additionalParameters) { _, new in new }
    }

    return parameters
  }
```

Then change `pushAuthorizationRequest`'s signature to add a trailing parameter:

```swift
  func pushAuthorizationRequest(
    codeChallenge: String,
    identifier: String?,
    endpoint: String,
    authServerURL: URL,
    state: String,
    ephemeralKeyForFlow: P256.Signing.PrivateKey?,
    additionalParameters: [String: String]? = nil
  ) async throws -> (requestURI: String, parNonce: String?) {
```

and replace its inline parameter construction — delete this block from the method body:

```swift
    var parameters: [String: String] = [
      "client_id": oauthConfig.clientId,
      "redirect_uri": oauthConfig.redirectUri,
      "response_type": "code",
      "code_challenge_method": "S256",
      "code_challenge": codeChallenge,
      "state": state,
      "scope": oauthConfig.scope,
    ]

    if let identifier = identifier {
      parameters["login_hint"] = identifier
    }
```

and replace it with:

```swift
    let parameters = buildPARParameters(
      codeChallenge: codeChallenge,
      identifier: identifier,
      state: state,
      additionalParameters: additionalParameters
    )
```

The existing call sites (`PublicOAuthStrategy.swift` lines ~120 and ~360, `CABOAuthStrategy.swift` line ~330) need no change — the new parameter defaults to `nil`.

- [ ] **Step 4: Run tests to verify they pass, and nothing else broke**

```bash
swift test --filter PARParameterTests
swift build
```
Expected: 3 tests PASS; clean build.

- [ ] **Step 5: Commit**

```bash
git add Sources/Petrel/Auth/OAuth/OAuthCore.swift Tests/PetrelTests/Auth/PARParameterTests.swift
git commit -m "Petrel: PAR body accepts additional parameters (client assertion seam)"
```

---

### Task 3: CAB — assertion fetch v2 (`aud`, backend nonce retry, URLSession seam, typed error)

**Files:**
- Modify: `Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift`
- Modify: `Sources/Petrel/Auth/AuthenticationService.swift` (AuthError — 4-space indent in this file!)
- Test: `Tests/PetrelTests/Auth/ClientAssertionFetchTests.swift` (new)

**Interfaces:**
- Consumes: `core.createDPoPProof(for:url:type:accessToken:did:ephemeralKey:nonce:)`, `core.encodeFormData(_:)`, `core.extractNonceFromHeaders(_:)` (all internal on `OAuthCore`); `struct OAuthErrorResponse: Decodable { let error: String; let errorDescription: String? }` (internal, `OAuthCore.swift`); test doubles `MockAccountManager` / `MockDIDResolver` from `RefreshTokenReliabilityTests.swift`.
- Produces:
  - `CABOAuthStrategy.init(backendURL:storage:accountManager:networkService:oauthConfig:didResolver:urlSession:)` — new trailing param `urlSession: URLSession = .shared`.
  - `func fetchClientAssertion(aud: String, ephemeralKey: P256.Signing.PrivateKey? = nil, did: String? = nil) async throws -> ClientAssertionResponse` — now INTERNAL (was private), form-posts `aud`, retries once on `use_dpop_nonce`.
  - `AuthError.clientAssertionBackendError(Int, String?)` — public case (status, OAuth error code).
  - `static let clientAssertionTypeJWTBearer` on `CABOAuthStrategy`.
  - Tasks 4, 13 call `fetchClientAssertion(aud:ephemeralKey:did:)` exactly as declared here.

- [ ] **Step 1: Write the failing tests**

Create `Tests/PetrelTests/Auth/ClientAssertionFetchTests.swift`:

```swift
#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
@testable import Petrel
import Synchronization
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Mock transport

/// URLProtocol that routes requests to a scriptable handler. One handler per
/// process at a time — suites using it must be `.serialized`.
final class MockURLProtocol: URLProtocol {
    private static let handlerStorage = Mutex<(@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?>(nil)

    static func setHandler(_ new: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) {
        handlerStorage.withLock { $0 = new }
    }

    override static func canInit(with _: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handlerStorage.withLock({ $0 }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// URLSession moves `httpBody` into `httpBodyStream` before URLProtocol
    /// sees the request — read whichever is populated.
    var bodyBytes: Data? {
        if let body = httpBody { return body }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

// MARK: - Helpers

private func decodeProofPayload(_ compactJWS: String) throws -> [String: Any] {
    let parts = compactJWS.split(separator: ".")
    try #require(parts.count == 3)
    var payloadB64 = String(parts[1])
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while payloadB64.count % 4 != 0 { payloadB64 += "=" }
    let payloadData = try #require(Data(base64Encoded: payloadB64))
    return try #require(try JSONSerialization.jsonObject(with: payloadData) as? [String: Any])
}

// MARK: - Tests

@Suite("CAB client assertion fetch", .serialized)
struct ClientAssertionFetchTests {
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeStrategy(namespace: String, session: URLSession) -> CABOAuthStrategy {
        CABOAuthStrategy(
            backendURL: URL(string: "https://cab.example.com")!,
            storage: KeychainStorage(namespace: namespace),
            accountManager: MockAccountManager(
                account: Account(
                    did: "did:plc:test",
                    handle: "test.example",
                    pdsURL: URL(string: "https://pds.test")!
                )
            ),
            networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
            oauthConfig: OAuthConfig(
                clientId: "https://cab.example.com/oauth-client-metadata.json",
                redirectUri: "https://client.example/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver(),
            urlSession: session
        )
    }

    @Test("Posts aud form field and DPoP proof, decodes the response")
    func fetchSendsAudAndProof() async throws {
        let strategy = makeStrategy(namespace: "test.cab.fetch", session: makeMockSession())
        let captured = Mutex<[URLRequest]>([])
        MockURLProtocol.setHandler { request in
            captured.withLock { $0.append(request) }
            let body = #"{"client_id":"https://cab.example.com/oauth-client-metadata.json","client_assertion":"header.payload.sig"}"#
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(body.utf8)
            )
        }
        defer { MockURLProtocol.setHandler(nil) }

        let response = try await strategy.fetchClientAssertion(
            aud: "https://auth.pds.test",
            ephemeralKey: P256.Signing.PrivateKey()
        )

        #expect(response.clientAssertion == "header.payload.sig")
        #expect(response.clientId == "https://cab.example.com/oauth-client-metadata.json")

        let requests = captured.withLock { $0 }
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url?.absoluteString == "https://cab.example.com/oauth/client-assertion")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "DPoP") != nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let bodyString = String(data: request.bodyBytes ?? Data(), encoding: .utf8) ?? ""
        #expect(bodyString.hasPrefix("aud="))
        #expect(bodyString.contains("auth.pds.test"))
    }

    @Test("Retries exactly once on use_dpop_nonce, echoing the server nonce")
    func fetchRetriesOnNonceChallenge() async throws {
        let strategy = makeStrategy(namespace: "test.cab.nonce", session: makeMockSession())
        let captured = Mutex<[URLRequest]>([])
        MockURLProtocol.setHandler { request in
            let isFirst = captured.withLock { requests -> Bool in
                requests.append(request)
                return requests.count == 1
            }
            if isFirst {
                let error = #"{"error":"use_dpop_nonce","error_description":"nonce required"}"#
                return (
                    HTTPURLResponse(
                        url: request.url!, statusCode: 400, httpVersion: nil,
                        headerFields: ["DPoP-Nonce": "server-nonce-1", "Content-Type": "application/json"]
                    )!,
                    Data(error.utf8)
                )
            }
            let body = #"{"client_id":"cid","client_assertion":"a.b.c"}"#
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(body.utf8)
            )
        }
        defer { MockURLProtocol.setHandler(nil) }

        let response = try await strategy.fetchClientAssertion(
            aud: "https://auth.pds.test",
            ephemeralKey: P256.Signing.PrivateKey()
        )
        #expect(response.clientAssertion == "a.b.c")

        let requests = captured.withLock { $0 }
        try #require(requests.count == 2)
        let retryProof = try #require(requests[1].value(forHTTPHeaderField: "DPoP"))
        let payload = try decodeProofPayload(retryProof)
        #expect(payload["nonce"] as? String == "server-nonce-1")
        #expect(payload["htu"] as? String == "https://cab.example.com/oauth/client-assertion")
        #expect(payload["htm"] as? String == "POST")
    }

    @Test("A second nonce challenge is a hard, typed failure")
    func secondNonceChallengeFails() async throws {
        let strategy = makeStrategy(namespace: "test.cab.nonce2", session: makeMockSession())
        MockURLProtocol.setHandler { request in
            let error = #"{"error":"use_dpop_nonce"}"#
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 400, httpVersion: nil,
                    headerFields: ["DPoP-Nonce": "server-nonce-x"]
                )!,
                Data(error.utf8)
            )
        }
        defer { MockURLProtocol.setHandler(nil) }

        await #expect(throws: AuthError.clientAssertionBackendError(400, "use_dpop_nonce")) {
            _ = try await strategy.fetchClientAssertion(
                aud: "https://auth.pds.test",
                ephemeralKey: P256.Signing.PrivateKey()
            )
        }
    }

    @Test("Backend refusal surfaces as clientAssertionBackendError")
    func backendRefusalIsTyped() async throws {
        let strategy = makeStrategy(namespace: "test.cab.refusal", session: makeMockSession())
        MockURLProtocol.setHandler { request in
            let error = #"{"error":"access_denied","error_description":"device refused"}"#
            return (
                HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!,
                Data(error.utf8)
            )
        }
        defer { MockURLProtocol.setHandler(nil) }

        await #expect(throws: AuthError.clientAssertionBackendError(403, "access_denied")) {
            _ = try await strategy.fetchClientAssertion(
                aud: "https://auth.pds.test",
                ephemeralKey: P256.Signing.PrivateKey()
            )
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter ClientAssertionFetchTests
```
Expected: COMPILE ERROR — no `urlSession:` init parameter, no `fetchClientAssertion(aud:ephemeralKey:)` (it is private and has no `aud`), no `AuthError.clientAssertionBackendError`.

- [ ] **Step 3: Implement — AuthError case**

In `Sources/Petrel/Auth/AuthenticationService.swift` (4-space indent):

(a) Inside `public enum AuthError` (line ~130), after `case serviceMaintenance` add:

```swift
    /// The client assertion backend returned a non-success response.
    /// Payload: HTTP status code and the OAuth `error` code when present.
    case clientAssertionBackendError(Int, String?)
```

(b) In `errorDescription` (the switch is exhaustive — add an arm before its closing brace):

```swift
        case let .clientAssertionBackendError(status, code):
            return "The client assertion backend refused the request (HTTP \(status)\(code.map { ": \($0)" } ?? ""))."
```

(c) `failureReason` and `recoverySuggestion` both end in `default:` arms — no change needed there.

(d) In `public static func ==` add, before the `default:` arm:

```swift
        case let (.clientAssertionBackendError(lhsStatus, lhsCode), .clientAssertionBackendError(rhsStatus, rhsCode)):
            return lhsStatus == rhsStatus && lhsCode == rhsCode
```

- [ ] **Step 4: Implement — CABOAuthStrategy changes**

In `Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift` (2-space indent):

(a) Add the constant and the session property. Below `let backendURL: URL` add:

```swift
  /// Transport for backend assertion fetches — injectable for tests.
  let urlSession: URLSession

  static let clientAssertionTypeJWTBearer = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
```

(b) Extend the init — add a trailing parameter and assignment:

```swift
  init(
    backendURL: URL,
    storage: KeychainStorage,
    accountManager: AccountManaging,
    networkService: NetworkService,
    oauthConfig: OAuthConfig,
    didResolver: DIDResolving,
    urlSession: URLSession = .shared
  ) {
    self.backendURL = backendURL
    self.urlSession = urlSession
    self.core = OAuthCore(
      storage: storage,
      accountManager: accountManager,
      networkService: networkService,
      oauthConfig: oauthConfig,
      didResolver: didResolver
    )
  }
```

(c) Replace the entire `private func fetchClientAssertion(ephemeralKey:did:nonce:)` method (lines ~368–407) with:

```swift
  /// Fetches a DPoP-bound client assertion for the given authorization
  /// server issuer. Retries exactly once when the backend answers
  /// 400 `use_dpop_nonce` with a `DPoP-Nonce` header.
  func fetchClientAssertion(
    aud: String,
    ephemeralKey: P256.Signing.PrivateKey? = nil,
    did: String? = nil
  ) async throws -> ClientAssertionResponse {
    try await fetchClientAssertionAttempt(
      aud: aud, ephemeralKey: ephemeralKey, did: did, nonce: nil, isRetry: false
    )
  }

  private func fetchClientAssertionAttempt(
    aud: String,
    ephemeralKey: P256.Signing.PrivateKey?,
    did: String?,
    nonce: String?,
    isRetry: Bool
  ) async throws -> ClientAssertionResponse {
    let assertionURL = backendURL.appendingPathComponent("oauth/client-assertion")

    let dpopProof: String
    if let key = ephemeralKey {
      dpopProof = try await core.createDPoPProof(
        for: "POST",
        url: assertionURL.absoluteString,
        type: .tokenRequest,
        did: did,
        ephemeralKey: key,
        nonce: nonce
      )
    } else if let did {
      dpopProof = try await core.createDPoPProof(
        for: "POST",
        url: assertionURL.absoluteString,
        type: .tokenRefresh,
        did: did,
        nonce: nonce
      )
    } else {
      throw AuthError.dpopKeyError
    }

    var request = URLRequest(url: assertionURL)
    request.httpMethod = "POST"
    request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = await core.encodeFormData(["aud": aud])
    request.timeoutInterval = 30.0

    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AuthError.invalidResponse
    }

    if (200 ..< 300).contains(httpResponse.statusCode) {
      return try JSONDecoder().decode(ClientAssertionResponse.self, from: data)
    }

    let oauthError = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data)
    if !isRetry,
       oauthError?.error == "use_dpop_nonce",
       let serverNonce = await core.extractNonceFromHeaders(httpResponse.allHeaderFields)
    {
      return try await fetchClientAssertionAttempt(
        aud: aud, ephemeralKey: ephemeralKey, did: did, nonce: serverNonce, isRetry: true
      )
    }

    throw AuthError.clientAssertionBackendError(httpResponse.statusCode, oauthError?.error)
  }
```

(d) Fix the two existing callers (they still pass the old arguments):

In `exchangeCodeForTokens` (line ~411) — the method needs the issuer. Change its signature to add `issuer: String`:

```swift
  private func exchangeCodeForTokens(
    code: String,
    codeVerifier: String,
    tokenEndpoint: String,
    issuer: String,
    authServerURL: URL,
    ephemeralKey: P256.Signing.PrivateKey?,
    initialNonce: String?,
    resourceURL: URL?
  ) async throws -> TokenResponse {
```

and replace its fetch line

```swift
    let assertionResponse = try await fetchClientAssertion(ephemeralKey: key, nonce: initialNonce)
```

with (note: the AS's PAR nonce is deliberately NOT sent to the backend — backend nonces come only from the backend's own challenge):

```swift
    let assertionResponse = try await fetchClientAssertion(aud: issuer, ephemeralKey: key)
```

In `handleOAuthCallback` (line ~138), the call site gains the issuer argument (`metadata` is already in scope there):

```swift
    let tokenResponse = try await exchangeCodeForTokens(
      code: code,
      codeVerifier: oauthState.codeVerifier,
      tokenEndpoint: metadata.tokenEndpoint,
      issuer: metadata.issuer,
      authServerURL: authServerURL,
      ephemeralKey: ephemeralKey,
      initialNonce: oauthState.parResponseNonce,
      resourceURL: pdsURL
    )
```

In `performTokenRefresh` (line ~588), replace

```swift
    let assertionResponse = try await fetchClientAssertion(did: did)
```

with (`metadata` is already bound from `account.authorizationServerMetadata` at the top of the method):

```swift
    let assertionResponse = try await fetchClientAssertion(aud: metadata.issuer, did: did)
```

(e) DRY the assertion-type literal: in the two token-request parameter dictionaries (in `exchangeCodeForTokens` and `performTokenRefresh`), replace

```swift
      "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
```

with

```swift
      "client_assertion_type": Self.clientAssertionTypeJWTBearer,
```

(f) One factory constructs this strategy — `Sources/Petrel/Auth/AuthManager.swift` `createStrategy` (lines ~121–168). The new init parameter has a default, so no change is required there; verify it still compiles.

- [ ] **Step 5: Run tests to verify they pass**

```bash
swift test --filter ClientAssertionFetchTests
swift test --filter PARParameterTests
swift build
```
Expected: all PASS, clean build.

- [ ] **Step 6: Commit**

```bash
git add Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift Sources/Petrel/Auth/AuthenticationService.swift Tests/PetrelTests/Auth/ClientAssertionFetchTests.swift
git commit -m "Petrel: CAB assertion fetch v2 — aud param, backend nonce retry, typed errors, URLSession seam"
```

---

### Task 4: CAB — inject the client assertion at PAR

**Files:**
- Modify: `Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift` (`_startOAuthFlowImpl`, lines ~302–364)

**Interfaces:**
- Consumes: `fetchClientAssertion(aud:ephemeralKey:did:)` (Task 3), `core.pushAuthorizationRequest(...additionalParameters:)` (Task 2), `metadata.issuer` (`AuthorizationServerMetadata`).
- Produces: CAB authorization flows now authenticate at PAR. No signature changes.

- [ ] **Step 1: Implement**

In `_startOAuthFlowImpl`, replace the PAR call block

```swift
    let oauthConfig = await core.oauthConfig
    let (requestURI, parNonce) = try await core.pushAuthorizationRequest(
      codeChallenge: codeChallenge,
      identifier: identifier,
      endpoint: metadata.pushedAuthorizationRequestEndpoint,
      authServerURL: authServerURL,
      state: stateToken,
      ephemeralKeyForFlow: ephemeralKey
    )
```

with:

```swift
    let oauthConfig = await core.oauthConfig

    // Confidential clients authenticate at PAR too. Assertions are
    // single-use (the AS replay-checks jti), so this one is fetched fresh
    // and used only for this PAR request.
    let parAssertion = try await fetchClientAssertion(
      aud: metadata.issuer, ephemeralKey: ephemeralKey
    )

    let (requestURI, parNonce) = try await core.pushAuthorizationRequest(
      codeChallenge: codeChallenge,
      identifier: identifier,
      endpoint: metadata.pushedAuthorizationRequestEndpoint,
      authServerURL: authServerURL,
      state: stateToken,
      ephemeralKeyForFlow: ephemeralKey,
      additionalParameters: [
        "client_assertion": parAssertion.clientAssertion,
        "client_assertion_type": Self.clientAssertionTypeJWTBearer,
      ]
    )
```

- [ ] **Step 2: Build and run the full Petrel test suite**

```bash
swift build && swift test
```
Expected: clean build, all tests pass. There is no isolated unit test for this glue (the PAR transport has no seam); the parameter merge is covered by Task 2's tests and the full flow is exercised for real in Tasks 13 and 16.

- [ ] **Step 3: Commit**

```bash
git add Sources/Petrel/Auth/Strategies/CABOAuthStrategy.swift
git commit -m "Petrel: CAB sends client assertion at PAR (fixes confidential-client authorization)"
```

---

### Task 5: Server scaffold — package, config, health endpoint

**Files:**
- Create: `Server/Package.swift`
- Create: `Server/Sources/PetrelCABServerCore/JSONValue.swift`
- Create: `Server/Sources/PetrelCABServerCore/ServerConfig.swift`
- Create: `Server/Sources/PetrelCABServerCore/CABServer.swift`
- Create: `Server/Sources/petrel-cab-server/ServerCommand.swift`
- Create: `Server/Sources/petrel-cab-demo/DemoCommand.swift` (placeholder main so the package builds; real demo is Task 15)
- Test: `Server/Tests/PetrelCABServerCoreTests/ServerConfigTests.swift`
- Modify: `.gitignore` (repo root — ensure `Server/.build` is ignored; the existing `.build/` pattern covers it only if written without a leading slash — check and fix)

**Interfaces:**
- Produces: `ServerConfig` (all fields below — later tasks consume them exactly as named), `ServerConfig.load(path:environment:)`, `ConfigError`, `JSONValue`, `CABServer` struct with `init(config:) throws` and `buildRouter() -> Router<BasicRequestContext>` and `buildApplication(logger:) throws -> some ApplicationProtocol`. Executable `petrel-cab-server` with `serve` subcommand.

- [ ] **Step 1: Write the package manifest**

Create `Server/Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "petrel-cab-server",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "petrel-cab-server", targets: ["petrel-cab-server"]),
    .executable(name: "petrel-cab-demo", targets: ["petrel-cab-demo"]),
    .library(name: "PetrelCABServerCore", targets: ["PetrelCABServerCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.25.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    .package(url: "https://github.com/beatt83/jose-swift.git", .upToNextMajor(from: "6.0.0")),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    .package(name: "Petrel", path: ".."),
  ],
  targets: [
    .target(
      name: "PetrelCABServerCore",
      dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "jose-swift", package: "jose-swift"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .executableTarget(
      name: "petrel-cab-server",
      dependencies: [
        "PetrelCABServerCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .executableTarget(
      name: "petrel-cab-demo",
      dependencies: [
        "PetrelCABServerCore",
        .product(name: "Petrel", package: "Petrel"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Hummingbird", package: "hummingbird"),
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .testTarget(
      name: "PetrelCABServerCoreTests",
      dependencies: [
        "PetrelCABServerCore",
        .product(name: "HummingbirdTesting", package: "hummingbird"),
      ]
    ),
    .testTarget(
      name: "PetrelCABIntegrationTests",
      dependencies: [
        "PetrelCABServerCore",
        .product(name: "Petrel", package: "Petrel"),
        .product(name: "HummingbirdTesting", package: "hummingbird"),
      ]
    ),
  ]
)
```

Create the two test directories with a placeholder each so SPM accepts the manifest before Tasks 6/13 fill them:

`Server/Tests/PetrelCABIntegrationTests/PlaceholderTests.swift`:

```swift
import Testing

@Suite struct PlaceholderIntegration {
  @Test func placeholder() { #expect(Bool(true)) }
}
```

`Server/Sources/petrel-cab-demo/DemoCommand.swift` (placeholder until Task 15):

```swift
import ArgumentParser

@main
struct DemoCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "petrel-cab-demo",
    abstract: "End-to-end demo client for petrel-cab-server (implemented in a later task)"
  )

  func run() async throws {
    print("petrel-cab-demo: not yet implemented")
  }
}
```

- [ ] **Step 2: Write JSONValue**

Create `Server/Sources/PetrelCABServerCore/JSONValue.swift`:

```swift
import Foundation

/// Arbitrary JSON value — passes the optional client metadata document
/// through the config file verbatim.
public enum JSONValue: Codable, Sendable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unsupported JSON value"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case let .bool(value): try container.encode(value)
    case let .number(value): try container.encode(value)
    case let .string(value): try container.encode(value)
    case let .object(value): try container.encode(value)
    case let .array(value): try container.encode(value)
    }
  }

  /// Convenience for tests and validation: object member access.
  public subscript(key: String) -> JSONValue? {
    if case let .object(dict) = self { return dict[key] }
    return nil
  }

  public var stringValue: String? {
    if case let .string(value) = self { return value }
    return nil
  }
}
```

- [ ] **Step 3: Write the failing config tests**

Create `Server/Tests/PetrelCABServerCoreTests/ServerConfigTests.swift`:

```swift
import Foundation
@testable import PetrelCABServerCore
import Testing

@Suite("Server configuration")
struct ServerConfigTests {
  private func write(_ json: String) throws -> String {
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent("cab-config-\(UUID().uuidString).json").path
    try json.write(toFile: path, atomically: true, encoding: .utf8)
    return path
  }

  @Test("Minimal config decodes with documented defaults")
  func minimalConfig() throws {
    let path = try write(
      """
      {
        "client_id": "https://cab.example.com/oauth-client-metadata.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1"
      }
      """
    )
    let config = try ServerConfig.load(path: path, environment: [:])
    #expect(config.clientId == "https://cab.example.com/oauth-client-metadata.json")
    #expect(config.publicUrl == "https://cab.example.com")
    #expect(config.host == "127.0.0.1")
    #expect(config.port == 8080)
    #expect(config.allowedOrigins.isEmpty)
    #expect(config.requireOrigin == false)
    #expect(config.audAllowlist == nil)
    #expect(config.assertionTtlSeconds == 60)
    #expect(config.iatWindowSeconds == 300)
    #expect(config.requireNonce == false)
    #expect(config.deniedJkts.isEmpty)
    #expect(config.clientMetadata == nil)
    #expect(config.rateLimit == nil)
  }

  @Test("Environment variables override file values")
  func envOverrides() throws {
    let path = try write(
      """
      {
        "client_id": "https://file.example/meta.json",
        "public_url": "https://file.example",
        "port": 1111,
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1"
      }
      """
    )
    let config = try ServerConfig.load(
      path: path,
      environment: [
        "CAB_CLIENT_ID": "https://env.example/meta.json",
        "CAB_PUBLIC_URL": "https://env.example",
        "CAB_PORT": "2222",
        "CAB_HOST": "0.0.0.0",
        "CAB_ALLOWED_ORIGINS": "https://a.example,https://b.example",
        "CAB_REQUIRE_NONCE": "true",
        "CAB_DENIED_JKTS": "badjkt1,badjkt2",
      ]
    )
    #expect(config.clientId == "https://env.example/meta.json")
    #expect(config.publicUrl == "https://env.example")
    #expect(config.port == 2222)
    #expect(config.host == "0.0.0.0")
    #expect(config.allowedOrigins == ["https://a.example", "https://b.example"])
    #expect(config.requireNonce == true)
    #expect(config.deniedJkts == ["badjkt1", "badjkt2"])
  }

  @Test("Env-only configuration works without a file")
  func envOnly() throws {
    let config = try ServerConfig.load(
      path: nil,
      environment: [
        "CAB_CLIENT_ID": "https://env.example/meta.json",
        "CAB_PUBLIC_URL": "https://env.example",
        "CAB_KEY_PEM_BASE64": "aWdub3JlZA==",
        "CAB_KEY_KID": "envkey",
      ]
    )
    #expect(config.clientId == "https://env.example/meta.json")
    #expect(config.keys.count == 1)
    #expect(config.keys[0].kid == "envkey")
    #expect(config.activeKid == "envkey")
  }

  @Test("Validation rejects unknown active_kid")
  func unknownActiveKid() throws {
    let path = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "nope"
      }
      """
    )
    #expect(throws: ConfigError.self) {
      _ = try ServerConfig.load(path: path, environment: [:])
    }
  }

  @Test("Validation rejects non-https public_url (except loopback)")
  func rejectsPlainHTTP() throws {
    let path = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "http://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1"
      }
      """
    )
    #expect(throws: ConfigError.self) {
      _ = try ServerConfig.load(path: path, environment: [:])
    }
    // Loopback is fine for development:
    let loopbackPath = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "http://127.0.0.1:8080",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1"
      }
      """
    )
    let config = try ServerConfig.load(path: loopbackPath, environment: [:])
    #expect(config.publicUrl == "http://127.0.0.1:8080")
  }
}
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
cd Server && swift test --filter ServerConfigTests
```
Expected: COMPILE ERROR — `ServerConfig` does not exist yet. (First run resolves dependencies; takes a few minutes.)

- [ ] **Step 5: Implement ServerConfig**

Create `Server/Sources/PetrelCABServerCore/ServerConfig.swift`:

```swift
import Foundation

public enum ConfigError: Error, Equatable, CustomStringConvertible {
  case fileNotReadable(String)
  case missingField(String)
  case unknownActiveKid(String)
  case invalidKeyMaterial(kid: String)
  case invalidURL(field: String, value: String)

  public var description: String {
    switch self {
    case let .fileNotReadable(path): "config file not readable: \(path)"
    case let .missingField(name): "missing required config field: \(name)"
    case let .unknownActiveKid(kid): "active_kid \"\(kid)\" is not in keys"
    case let .invalidKeyMaterial(kid): "key \"\(kid)\" has no loadable PEM (need pem_path or pem_base64 containing a P-256 private key)"
    case let .invalidURL(field, value): "\(field) must be an https URL (or http on 127.0.0.1/localhost for development): \(value)"
    }
  }
}

public struct KeyConfig: Codable, Sendable, Equatable {
  public var kid: String
  public var pemPath: String?
  public var pemBase64: String?

  enum CodingKeys: String, CodingKey {
    case kid
    case pemPath = "pem_path"
    case pemBase64 = "pem_base64"
  }

  public init(kid: String, pemPath: String? = nil, pemBase64: String? = nil) {
    self.kid = kid
    self.pemPath = pemPath
    self.pemBase64 = pemBase64
  }
}

public struct RateLimitConfig: Codable, Sendable, Equatable {
  public var requestsPerMinute: Int

  enum CodingKeys: String, CodingKey {
    case requestsPerMinute = "requests_per_minute"
  }

  public init(requestsPerMinute: Int = 60) {
    self.requestsPerMinute = requestsPerMinute
  }
}

public struct ServerConfig: Codable, Sendable, Equatable {
  public var clientId: String
  public var publicUrl: String
  public var host: String
  public var port: Int
  public var keys: [KeyConfig]
  public var activeKid: String
  public var allowedOrigins: [String]
  public var requireOrigin: Bool
  public var audAllowlist: [String]?
  public var assertionTtlSeconds: Int
  public var iatWindowSeconds: Int
  public var requireNonce: Bool
  public var nonceSecretBase64: String?
  public var deniedJkts: [String]
  public var clientMetadata: JSONValue?
  public var rateLimit: RateLimitConfig?

  enum CodingKeys: String, CodingKey {
    case clientId = "client_id"
    case publicUrl = "public_url"
    case host
    case port
    case keys
    case activeKid = "active_kid"
    case allowedOrigins = "allowed_origins"
    case requireOrigin = "require_origin"
    case audAllowlist = "aud_allowlist"
    case assertionTtlSeconds = "assertion_ttl_seconds"
    case iatWindowSeconds = "iat_window_seconds"
    case requireNonce = "require_nonce"
    case nonceSecretBase64 = "nonce_secret_base64"
    case deniedJkts = "denied_jkts"
    case clientMetadata = "client_metadata"
    case rateLimit = "rate_limit"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    clientId = try container.decodeIfPresent(String.self, forKey: .clientId) ?? ""
    publicUrl = try container.decodeIfPresent(String.self, forKey: .publicUrl) ?? ""
    host = try container.decodeIfPresent(String.self, forKey: .host) ?? "127.0.0.1"
    port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 8080
    keys = try container.decodeIfPresent([KeyConfig].self, forKey: .keys) ?? []
    activeKid = try container.decodeIfPresent(String.self, forKey: .activeKid) ?? ""
    allowedOrigins = try container.decodeIfPresent([String].self, forKey: .allowedOrigins) ?? []
    requireOrigin = try container.decodeIfPresent(Bool.self, forKey: .requireOrigin) ?? false
    audAllowlist = try container.decodeIfPresent([String].self, forKey: .audAllowlist)
    assertionTtlSeconds = try container.decodeIfPresent(Int.self, forKey: .assertionTtlSeconds) ?? 60
    iatWindowSeconds = try container.decodeIfPresent(Int.self, forKey: .iatWindowSeconds) ?? 300
    requireNonce = try container.decodeIfPresent(Bool.self, forKey: .requireNonce) ?? false
    nonceSecretBase64 = try container.decodeIfPresent(String.self, forKey: .nonceSecretBase64)
    deniedJkts = try container.decodeIfPresent([String].self, forKey: .deniedJkts) ?? []
    clientMetadata = try container.decodeIfPresent(JSONValue.self, forKey: .clientMetadata)
    rateLimit = try container.decodeIfPresent(RateLimitConfig.self, forKey: .rateLimit)
  }

  /// Loads config from an optional JSON file, then applies environment
  /// overrides, then validates. Env-only operation (path == nil) is supported.
  public static func load(
    path: String?,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> ServerConfig {
    var config: ServerConfig
    if let path {
      guard let data = FileManager.default.contents(atPath: path) else {
        throw ConfigError.fileNotReadable(path)
      }
      config = try JSONDecoder().decode(ServerConfig.self, from: data)
    } else {
      config = try JSONDecoder().decode(ServerConfig.self, from: Data("{}".utf8))
    }

    if let value = environment["CAB_CLIENT_ID"] { config.clientId = value }
    if let value = environment["CAB_PUBLIC_URL"] { config.publicUrl = value }
    if let value = environment["CAB_HOST"] { config.host = value }
    if let value = environment["CAB_PORT"], let port = Int(value) { config.port = port }
    if let value = environment["CAB_ACTIVE_KID"] { config.activeKid = value }
    if let value = environment["CAB_KEY_PEM_BASE64"] {
      let kid = environment["CAB_KEY_KID"] ?? "cab-key-1"
      config.keys.append(KeyConfig(kid: kid, pemBase64: value))
      if config.activeKid.isEmpty { config.activeKid = kid }
    }
    if let value = environment["CAB_ALLOWED_ORIGINS"] {
      config.allowedOrigins = value.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespaces)
      }
    }
    if let value = environment["CAB_REQUIRE_NONCE"] {
      config.requireNonce = value == "true" || value == "1"
    }
    if let value = environment["CAB_NONCE_SECRET_BASE64"] { config.nonceSecretBase64 = value }
    if let value = environment["CAB_DENIED_JKTS"] {
      config.deniedJkts = value.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespaces)
      }
    }

    try config.validate()
    return config
  }

  public func validate() throws {
    guard !clientId.isEmpty else { throw ConfigError.missingField("client_id") }
    guard !publicUrl.isEmpty else { throw ConfigError.missingField("public_url") }
    try Self.requireWebURL(clientId, field: "client_id")
    try Self.requireWebURL(publicUrl, field: "public_url")
    guard !keys.isEmpty else { throw ConfigError.missingField("keys") }
    guard keys.contains(where: { $0.kid == activeKid }) else {
      throw ConfigError.unknownActiveKid(activeKid)
    }
    for key in keys where key.pemPath == nil && key.pemBase64 == nil {
      throw ConfigError.invalidKeyMaterial(kid: key.kid)
    }
  }

  /// https required; plain http allowed only on loopback hosts (development).
  static func requireWebURL(_ value: String, field: String) throws {
    guard let url = URL(string: value), let scheme = url.scheme, let host = url.host else {
      throw ConfigError.invalidURL(field: field, value: value)
    }
    if scheme == "https" { return }
    if scheme == "http", host == "127.0.0.1" || host == "localhost" || host == "::1" { return }
    throw ConfigError.invalidURL(field: field, value: value)
  }
}
```

- [ ] **Step 6: Implement CABServer + executable entry point**

Create `Server/Sources/PetrelCABServerCore/CABServer.swift` (grows in later tasks; this version only wires `/health`):

```swift
import Hummingbird
import Logging

/// Assembles the configured server. `init` builds all stateful components;
/// `buildRouter()` wires routes; `buildApplication(logger:)` returns a
/// runnable app.
public struct CABServer: Sendable {
  public let config: ServerConfig

  public init(config: ServerConfig) throws {
    self.config = config
  }

  public func buildRouter() -> Router<BasicRequestContext> {
    let router = Router(context: BasicRequestContext.self)
    router.get("/health") { _, _ in "OK" }
    return router
  }

  public func buildApplication(logger: Logger) -> some ApplicationProtocol {
    Application(
      router: buildRouter(),
      configuration: .init(
        address: .hostname(config.host, port: config.port),
        serverName: "petrel-cab-server"
      ),
      logger: logger
    )
  }
}
```

Create `Server/Sources/petrel-cab-server/ServerCommand.swift`:

```swift
import ArgumentParser
import Logging
import PetrelCABServerCore

@main
struct ServerCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "petrel-cab-server",
    abstract: "ATProto OAuth client assertion backend",
    subcommands: [Serve.self],
    defaultSubcommand: Serve.self
  )
}

struct Serve: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "serve",
    abstract: "Run the assertion server"
  )

  @Option(name: [.short, .long], help: "Path to a JSON config file (env vars override it)")
  var config: String?

  @Option(name: .long, help: "Log level (trace|debug|info|notice|warning|error|critical)")
  var logLevel: String = "info"

  func run() async throws {
    var logger = Logger(label: "petrel-cab-server")
    logger.logLevel = Logger.Level(rawValue: logLevel) ?? .info

    let serverConfig = try ServerConfig.load(path: config)
    let server = try CABServer(config: serverConfig)
    logger.info(
      "starting",
      metadata: [
        "client_id": .string(serverConfig.clientId),
        "public_url": .string(serverConfig.publicUrl),
        "address": .string("\(serverConfig.host):\(serverConfig.port)"),
      ]
    )
    try await server.buildApplication(logger: logger).runService()
  }
}
```

- [ ] **Step 7: Run tests and build**

```bash
cd Server && swift test --filter ServerConfigTests && swift build
```
Expected: 5 tests PASS; whole package (both executables) builds.

- [ ] **Step 8: Check .gitignore covers Server/.build, then commit**

```bash
grep -n "\.build" ../.gitignore
```
If the pattern is `/.build` (anchored to root), add a line `Server/.build/`; if it is `.build/` (unanchored), no change needed.

```bash
cd .. && git add Server .gitignore
git commit -m "cab-server: package scaffold — config loading, env overrides, health endpoint"
```

---

### Task 6: KeyStore, `generate-key`, JWKS endpoint

**Files:**
- Create: `Server/Sources/PetrelCABServerCore/KeyStore.swift`
- Modify: `Server/Sources/PetrelCABServerCore/CABServer.swift` (hold a `KeyStore`, serve JWKS)
- Modify: `Server/Sources/petrel-cab-server/ServerCommand.swift` (add `GenerateKey` subcommand)
- Test: `Server/Tests/PetrelCABServerCoreTests/KeyStoreTests.swift`

**Interfaces:**
- Consumes: `ServerConfig`, `KeyConfig`, `ConfigError.invalidKeyMaterial/unknownActiveKid` (Task 5); jose-swift `JWK`, `P256.Signing.PrivateKey.pemRepresentation` / `.publicKey.jwkRepresentation`.
- Produces: `SigningKey { kid: String; privateKey: P256.Signing.PrivateKey; publicJWK: JWK }`, `KeyStore { keys: [SigningKey]; activeKid: String; activeKey: SigningKey; init(config:) throws; jwksDocument() throws -> Data }`. `CABServer` gains `public let keyStore: KeyStore`. Tasks 10, 13 sign/verify with `keyStore.activeKey`.

- [ ] **Step 1: Write the failing tests**

Create `Server/Tests/PetrelCABServerCoreTests/KeyStoreTests.swift`:

```swift
#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import Hummingbird
import HummingbirdTesting
@testable import PetrelCABServerCore
import Testing

/// Builds a config whose single key is a freshly generated P-256 PEM.
func makeTestConfig(
  mutate: (inout ServerConfig) -> Void = { _ in }
) throws -> (ServerConfig, P256.Signing.PrivateKey) {
  let key = P256.Signing.PrivateKey()
  let pemBase64 = Data(key.pemRepresentation.utf8).base64EncodedString()
  let json = """
    {
      "client_id": "https://cab.test/oauth-client-metadata.json",
      "public_url": "https://cab.test",
      "keys": [{ "kid": "test-key-1", "pem_base64": "\(pemBase64)" }],
      "active_kid": "test-key-1"
    }
    """
  var config = try JSONDecoder().decode(ServerConfig.self, from: Data(json.utf8))
  mutate(&config)
  try config.validate()
  return (config, key)
}

@Suite("Key store")
struct KeyStoreTests {
  @Test("Loads a base64 PEM key and exposes it as the active key")
  func loadsBase64PEM() throws {
    let (config, key) = try makeTestConfig()
    let store = try KeyStore(config: config)
    #expect(store.keys.count == 1)
    #expect(store.activeKey.kid == "test-key-1")
    #expect(store.activeKey.privateKey.rawRepresentation == key.rawRepresentation)
  }

  @Test("Loads a PEM key from a file path")
  func loadsPEMFile() throws {
    let key = P256.Signing.PrivateKey()
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent("cab-key-\(UUID().uuidString).pem").path
    try key.pemRepresentation.write(toFile: path, atomically: true, encoding: .utf8)
    var (config, _) = try makeTestConfig()
    config.keys = [KeyConfig(kid: "file-key", pemPath: path)]
    config.activeKid = "file-key"
    let store = try KeyStore(config: config)
    #expect(store.activeKey.privateKey.rawRepresentation == key.rawRepresentation)
  }

  @Test("Garbage key material throws invalidKeyMaterial")
  func garbageKeyMaterial() throws {
    var (config, _) = try makeTestConfig()
    config.keys = [KeyConfig(kid: "bad", pemBase64: Data("not a pem".utf8).base64EncodedString())]
    config.activeKid = "bad"
    #expect(throws: ConfigError.invalidKeyMaterial(kid: "bad")) {
      _ = try KeyStore(config: config)
    }
  }

  @Test("JWKS document contains every public key and no private material")
  func jwksShape() throws {
    let (config, _) = try makeTestConfig()
    let store = try KeyStore(config: config)
    let document = try store.jwksDocument()
    let parsed = try #require(
      try JSONSerialization.jsonObject(with: document) as? [String: Any]
    )
    let keys = try #require(parsed["keys"] as? [[String: Any]])
    try #require(keys.count == 1)
    #expect(keys[0]["kty"] as? String == "EC")
    #expect(keys[0]["crv"] as? String == "P-256")
    #expect(keys[0]["kid"] as? String == "test-key-1")
    #expect(keys[0]["x"] is String)
    #expect(keys[0]["y"] is String)
    #expect(keys[0]["d"] == nil)
  }

  @Test("GET /.well-known/jwks.json serves the document")
  func jwksEndpoint() async throws {
    let (config, _) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      try await client.execute(uri: "/.well-known/jwks.json", method: .get) { response in
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "application/json")
        let body = String(buffer: response.body)
        #expect(body.contains("\"keys\""))
        #expect(body.contains("test-key-1"))
        #expect(!body.contains("\"d\""))
      }
    }
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Server && swift test --filter KeyStoreTests
```
Expected: COMPILE ERROR — `KeyStore` does not exist.

- [ ] **Step 3: Implement KeyStore**

Create `Server/Sources/PetrelCABServerCore/KeyStore.swift`:

```swift
#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import JSONWebKey

public struct SigningKey: Sendable {
  public let kid: String
  public let privateKey: P256.Signing.PrivateKey

  public var publicJWK: JWK {
    var jwk = privateKey.publicKey.jwkRepresentation
    jwk.keyID = kid
    return jwk
  }
}

public struct KeyStore: Sendable {
  public let keys: [SigningKey]
  public let activeKid: String

  public var activeKey: SigningKey {
    // Presence is guaranteed by init.
    keys.first { $0.kid == activeKid }!
  }

  public init(config: ServerConfig) throws {
    var loaded: [SigningKey] = []
    for keyConfig in config.keys {
      let pem: String
      if let path = keyConfig.pemPath {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
          throw ConfigError.invalidKeyMaterial(kid: keyConfig.kid)
        }
        pem = contents
      } else if let base64 = keyConfig.pemBase64 {
        guard let data = Data(base64Encoded: base64),
              let contents = String(data: data, encoding: .utf8)
        else {
          throw ConfigError.invalidKeyMaterial(kid: keyConfig.kid)
        }
        pem = contents
      } else {
        throw ConfigError.invalidKeyMaterial(kid: keyConfig.kid)
      }
      guard let privateKey = try? P256.Signing.PrivateKey(pemRepresentation: pem) else {
        throw ConfigError.invalidKeyMaterial(kid: keyConfig.kid)
      }
      loaded.append(SigningKey(kid: keyConfig.kid, privateKey: privateKey))
    }
    guard loaded.contains(where: { $0.kid == config.activeKid }) else {
      throw ConfigError.unknownActiveKid(config.activeKid)
    }
    keys = loaded
    activeKid = config.activeKid
  }

  /// RFC 7517 JWK Set of every configured public key. All keys stay
  /// published so assertions signed before a rotation keep verifying.
  public func jwksDocument() throws -> Data {
    struct JWKSet: Encodable {
      let keys: [JWK]
    }
    let publicKeys = keys.map { key -> JWK in
      var jwk = key.publicJWK
      jwk.algorithm = "ES256"
      return jwk
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(JWKSet(keys: publicKeys))
  }
}
```

- [ ] **Step 4: Wire into CABServer**

In `Server/Sources/PetrelCABServerCore/CABServer.swift`:

Add the stored property and build it in init:

```swift
public struct CABServer: Sendable {
  public let config: ServerConfig
  public let keyStore: KeyStore

  public init(config: ServerConfig) throws {
    self.config = config
    keyStore = try KeyStore(config: config)
  }
```

In `buildRouter()`, after the `/health` route add:

```swift
    // JWKS must be precomputable — fail at startup, not per request.
    let jwksBody = (try? keyStore.jwksDocument()) ?? Data()
    router.get("/.well-known/jwks.json") { _, _ -> Response in
      Response(
        status: .ok,
        headers: [.contentType: "application/json", .cacheControl: "public, max-age=300"],
        body: .init(byteBuffer: ByteBuffer(data: jwksBody))
      )
    }
```

- [ ] **Step 5: Add the GenerateKey subcommand**

In `Server/Sources/petrel-cab-server/ServerCommand.swift`, add `GenerateKey.self` to `subcommands:` in `ServerCommand.configuration`:

```swift
    subcommands: [Serve.self, GenerateKey.self],
```

and append at the bottom of the file:

```swift
#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import JSONWebKey

struct GenerateKey: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "generate-key",
    abstract: "Generate a P-256 signing key and print its PEM + public JWK"
  )

  @Option(name: .long, help: "Key ID to embed in the JWK")
  var kid: String = "cab-key-1"

  func run() throws {
    let key = P256.Signing.PrivateKey()
    var jwk = key.publicKey.jwkRepresentation
    jwk.keyID = kid
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jwkJSON = String(data: try encoder.encode(jwk), encoding: .utf8) ?? "{}"

    print("Private key PEM (store securely — e.g. keys/\(kid).pem):\n")
    print(key.pemRepresentation)
    print("\nPublic JWK (\(kid)):\n")
    print(jwkJSON)
    print("\nBase64 PEM (for the CAB_KEY_PEM_BASE64 env var):\n")
    print(Data(key.pemRepresentation.utf8).base64EncodedString())
  }
}
```

- [ ] **Step 6: Run tests, exercise generate-key**

```bash
cd Server && swift test --filter KeyStoreTests
swift run petrel-cab-server generate-key --kid smoke-test-key
```
Expected: 5 tests PASS; generate-key prints a PEM block, a JWK with `"kid": "smoke-test-key"`, and a base64 line.

- [ ] **Step 7: Commit**

```bash
cd .. && git add Server
git commit -m "cab-server: KeyStore (PEM/base64, rotation-ready JWKS) + generate-key CLI"
```

---

### Task 7: OAuth error types + DPoP proof validator

**Files:**
- Create: `Server/Sources/PetrelCABServerCore/OAuthErrors.swift`
- Create: `Server/Sources/PetrelCABServerCore/DPoPValidator.swift`
- Test: `Server/Tests/PetrelCABServerCoreTests/DPoPValidatorTests.swift`

**Interfaces:**
- Consumes: jose-swift `JWS(jwsString:)`, `jws.protectedHeader.{type,algorithm,jwk}`, `jws.verify(key:)`, `jwk.thumbprint()`, `DefaultJWSHeaderImpl(algorithm:jwk:type:)` (test helper).
- Produces:
  - `CABRequestError { status: Int; error: String; description: String }` with factories `.invalidDPoPProof(_:)`, `.invalidRequest(_:)`, `.useDPoPNonce()`, `.accessDenied(_:)`, `.rateLimited()`.
  - `extension HTTPField.Name { static let dpop; static let dpopNonce }`.
  - `ValidatedProof { jkt: String; jti: String }`, `DPoPProofClaims { jti, htm, htu, iat, exp?, nonce? }`.
  - `DPoPValidator { init(endpointURL: String, iatWindow: TimeInterval); validate(proof: String, now: Date) throws -> (ValidatedProof, DPoPProofClaims) }` — stateless checks only (signature/typ/alg/jwk/htm/htu/iat); replay, nonce, and device policy are the route handler's job (Task 10).
  - Test helper `makeDPoPProof(...)` reused by Tasks 10 and 13's tests.

- [ ] **Step 1: Write OAuthErrors (tiny, no test of its own — exercised by every validator test)**

Create `Server/Sources/PetrelCABServerCore/OAuthErrors.swift`:

```swift
import Hummingbird

extension HTTPField.Name {
  public static let dpop = Self("DPoP")!
  public static let dpopNonce = Self("DPoP-Nonce")!
}

/// OAuth-style request error. The route layer converts these into JSON
/// `{"error": ..., "error_description": ...}` responses.
public struct CABRequestError: Error, Sendable, Equatable {
  public let status: Int
  public let error: String
  public let description: String

  public static func invalidDPoPProof(_ description: String) -> CABRequestError {
    CABRequestError(status: 400, error: "invalid_dpop_proof", description: description)
  }

  public static func invalidRequest(_ description: String) -> CABRequestError {
    CABRequestError(status: 400, error: "invalid_request", description: description)
  }

  public static func useDPoPNonce() -> CABRequestError {
    CABRequestError(
      status: 400, error: "use_dpop_nonce",
      description: "A DPoP nonce is required; retry with the DPoP-Nonce header value"
    )
  }

  public static func accessDenied(_ description: String) -> CABRequestError {
    CABRequestError(status: 403, error: "access_denied", description: description)
  }

  public static func rateLimited() -> CABRequestError {
    CABRequestError(status: 429, error: "rate_limited", description: "Too many requests")
  }
}
```

- [ ] **Step 2: Write the failing validator tests**

Create `Server/Tests/PetrelCABServerCoreTests/DPoPValidatorTests.swift`:

```swift
#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import JSONWebKey
import JSONWebSignature
@testable import PetrelCABServerCore
import Testing

let testEndpoint = "https://cab.test/oauth/client-assertion"

/// Builds DPoP proofs with every field overridable, for the validation matrix.
/// `embedJWKOf` lets a test embed a DIFFERENT public key than the signer
/// (wrong-key case). `includePrivateKey` leaks `d` into the header jwk.
func makeDPoPProof(
  key: P256.Signing.PrivateKey = .init(),
  typ: String? = "dpop+jwt",
  htm: String = "POST",
  htu: String = testEndpoint,
  iat: Int = Int(Date().timeIntervalSince1970),
  jti: String = UUID().uuidString,
  nonce: String? = nil,
  includePrivateKey: Bool = false,
  embedJWKOf: P256.Signing.PrivateKey? = nil
) throws -> String {
  var jwk = (embedJWKOf ?? key).publicKey.jwkRepresentation
  if includePrivateKey { jwk.d = key.rawRepresentation }
  let header = DefaultJWSHeaderImpl(algorithm: .ES256, jwk: jwk, type: typ)
  struct Claims: Encodable {
    let jti: String
    let htm: String
    let htu: String
    let iat: Int
    let nonce: String?
  }
  let payload = try JSONEncoder().encode(
    Claims(jti: jti, htm: htm, htu: htu, iat: iat, nonce: nonce)
  )
  return try JWS(payload: payload, protectedHeader: header, key: key).compactSerialization
}

/// Hand-crafted `alg: none` token — jose-swift will not sign one, so build
/// the compact serialization manually.
func makeAlgNoneProof(htu: String = testEndpoint) throws -> String {
  func b64url(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
  let jwk = P256.Signing.PrivateKey().publicKey.jwkRepresentation
  let jwkJSON = String(data: try JSONEncoder().encode(jwk), encoding: .utf8)!
  let header = #"{"alg":"none","typ":"dpop+jwt","jwk":\#(jwkJSON)}"#
  let payload = #"{"jti":"\#(UUID().uuidString)","htm":"POST","htu":"\#(htu)","iat":\#(Int(Date().timeIntervalSince1970))}"#
  return "\(b64url(Data(header.utf8))).\(b64url(Data(payload.utf8)))."
}

@Suite("DPoP proof validation")
struct DPoPValidatorTests {
  let validator = DPoPValidator(endpointURL: testEndpoint, iatWindow: 300)

  @Test("Valid proof passes and yields the key's RFC 7638 thumbprint")
  func validProof() throws {
    let key = P256.Signing.PrivateKey()
    let proof = try makeDPoPProof(key: key, jti: "jti-1")
    let (validated, claims) = try validator.validate(proof: proof)
    #expect(validated.jti == "jti-1")
    #expect(claims.htm == "POST")
    let expectedJKT = try key.publicKey.jwkRepresentation.thumbprint()
    #expect(validated.jkt == expectedJKT)
  }

  @Test("Canonically-equivalent htu forms pass")
  func htuCanonicalization() throws {
    for htu in [
      "HTTPS://CAB.TEST/oauth/client-assertion",
      "https://cab.test:443/oauth/client-assertion",
      "https://cab.test/oauth/client-assertion?ignored=1",
      "https://cab.test/oauth/client-assertion#frag",
    ] {
      let proof = try makeDPoPProof(htu: htu)
      _ = try validator.validate(proof: proof)
    }
  }

  @Test("Rejection matrix", arguments: [
    "wrong-typ", "missing-typ", "wrong-htm", "wrong-htu", "stale-iat",
    "future-iat", "private-jwk", "wrong-key", "malformed",
  ])
  func rejections(kind: String) throws {
    let proof: String
    switch kind {
    case "wrong-typ": proof = try makeDPoPProof(typ: "jwt")
    case "missing-typ": proof = try makeDPoPProof(typ: nil)
    case "wrong-htm": proof = try makeDPoPProof(htm: "GET")
    case "wrong-htu": proof = try makeDPoPProof(htu: "https://other.example/oauth/client-assertion")
    case "stale-iat": proof = try makeDPoPProof(iat: Int(Date().timeIntervalSince1970) - 3600)
    case "future-iat": proof = try makeDPoPProof(iat: Int(Date().timeIntervalSince1970) + 3600)
    case "private-jwk": proof = try makeDPoPProof(includePrivateKey: true)
    case "wrong-key": proof = try makeDPoPProof(embedJWKOf: P256.Signing.PrivateKey())
    case "malformed": proof = "not.a.jws"
    default: fatalError("unknown kind")
    }
    #expect(throws: CABRequestError.self) {
      _ = try validator.validate(proof: proof)
    }
  }

  @Test("alg none is rejected even though jose-swift would 'verify' it")
  func algNoneRejected() throws {
    let proof = try makeAlgNoneProof()
    #expect(throws: CABRequestError.self) {
      _ = try validator.validate(proof: proof)
    }
  }

  @Test("Rejections carry the invalid_dpop_proof error code")
  func rejectionErrorCode() throws {
    do {
      _ = try validator.validate(proof: try makeDPoPProof(htm: "GET"))
      Issue.record("expected throw")
    } catch let error as CABRequestError {
      #expect(error.error == "invalid_dpop_proof")
      #expect(error.status == 400)
    }
  }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd Server && swift test --filter DPoPValidatorTests
```
Expected: COMPILE ERROR — `DPoPValidator` does not exist.

- [ ] **Step 4: Implement the validator**

Create `Server/Sources/PetrelCABServerCore/DPoPValidator.swift`:

```swift
#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import JSONWebKey
import JSONWebSignature

public struct ValidatedProof: Sendable, Equatable {
  public let jkt: String
  public let jti: String
}

public struct DPoPProofClaims: Decodable, Sendable {
  public let jti: String
  public let htm: String
  public let htu: String
  public let iat: Int
  public let exp: Int?
  public let nonce: String?
}

/// Stateless DPoP proof checks (RFC 9449): structure, typ/alg pinning,
/// embedded-key signature, htm/htu, iat freshness. Stateful checks (jti
/// replay, nonce requirement, device policy) belong to the route handler.
public struct DPoPValidator: Sendable {
  public let expectedHTU: String
  public let iatWindow: TimeInterval

  public init(endpointURL: String, iatWindow: TimeInterval) {
    expectedHTU = Self.canonicalize(endpointURL)
    self.iatWindow = iatWindow
  }

  public func validate(
    proof: String, now: Date = Date()
  ) throws -> (ValidatedProof, DPoPProofClaims) {
    let jws: JWS
    do {
      jws = try JWS(jwsString: proof)
    } catch {
      throw CABRequestError.invalidDPoPProof("malformed JWS")
    }

    guard jws.protectedHeader.type == "dpop+jwt" else {
      throw CABRequestError.invalidDPoPProof("typ must be dpop+jwt")
    }
    // jose-swift's JWS.verify returns true unconditionally for alg=none —
    // the algorithm MUST be pinned before verifying.
    guard jws.protectedHeader.algorithm == .ES256 else {
      throw CABRequestError.invalidDPoPProof("alg must be ES256")
    }
    guard let jwk = jws.protectedHeader.jwk,
          jwk.keyType == .ellipticCurve,
          jwk.curve == .p256
    else {
      throw CABRequestError.invalidDPoPProof("header jwk must be an EC P-256 public key")
    }
    guard jwk.d == nil else {
      throw CABRequestError.invalidDPoPProof("header jwk must not contain private key material")
    }
    guard (try? jws.verify(key: jwk)) == true else {
      throw CABRequestError.invalidDPoPProof("signature verification failed")
    }

    let claims: DPoPProofClaims
    do {
      claims = try JSONDecoder().decode(DPoPProofClaims.self, from: jws.payload)
    } catch {
      throw CABRequestError.invalidDPoPProof("malformed claims")
    }

    guard claims.htm == "POST" else {
      throw CABRequestError.invalidDPoPProof("htm must be POST")
    }
    guard Self.canonicalize(claims.htu) == expectedHTU else {
      throw CABRequestError.invalidDPoPProof("htu does not match this endpoint")
    }
    let age = now.timeIntervalSince1970 - TimeInterval(claims.iat)
    guard abs(age) <= iatWindow else {
      throw CABRequestError.invalidDPoPProof("iat outside acceptance window")
    }
    if let exp = claims.exp, TimeInterval(exp) < now.timeIntervalSince1970 {
      throw CABRequestError.invalidDPoPProof("proof expired")
    }

    guard let jkt = try? jwk.thumbprint() else {
      throw CABRequestError.invalidDPoPProof("could not compute key thumbprint")
    }
    return (ValidatedProof(jkt: jkt, jti: claims.jti), claims)
  }

  /// RFC 9449 §4.3 htu comparison: no query/fragment, lowercase
  /// scheme/host, default ports stripped.
  static func canonicalize(_ url: String) -> String {
    guard var components = URLComponents(string: url) else { return url }
    components.query = nil
    components.fragment = nil
    components.scheme = components.scheme?.lowercased()
    components.host = components.host?.lowercased()
    if let scheme = components.scheme, let port = components.port,
       (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
    {
      components.port = nil
    }
    return components.string ?? url
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd Server && swift test --filter DPoPValidatorTests
```
Expected: all PASS (4 named tests + 9 matrix cases).

- [ ] **Step 6: Commit**

```bash
cd .. && git add Server
git commit -m "cab-server: DPoP proof validator (typ/alg pinning, embedded-key verify, htu canonicalization) + OAuth error types"
```

---

### Task 8: ReplayStore + NonceService

**Files:**
- Create: `Server/Sources/PetrelCABServerCore/ReplayStore.swift`
- Create: `Server/Sources/PetrelCABServerCore/NonceService.swift`
- Test: `Server/Tests/PetrelCABServerCoreTests/ReplayAndNonceTests.swift`

**Interfaces:**
- Consumes: CryptoKit `HMAC<SHA256>`, `SymmetricKey`.
- Produces:
  - `actor ReplayStore { init(ttl: TimeInterval); checkAndInsert(_ jti: String, now: Date) -> Bool }` (true = fresh, recorded; false = replay).
  - `struct NonceService { init(secretBase64: String?, validity: TimeInterval); issue(now: Date) -> String; isValid(_ nonce: String, now: Date) -> Bool }`.
  - `extension Data { func base64URLEncodedString() -> String }` (public, in NonceService.swift — Task 10's minter also uses it indirectly via jose).

- [ ] **Step 1: Write the failing tests**

Create `Server/Tests/PetrelCABServerCoreTests/ReplayAndNonceTests.swift`:

```swift
import Foundation
@testable import PetrelCABServerCore
import Testing

@Suite("Replay store")
struct ReplayStoreTests {
  @Test("First use is fresh, second is a replay")
  func replayDetected() async {
    let store = ReplayStore(ttl: 300)
    #expect(await store.checkAndInsert("jti-a", now: Date()) == true)
    #expect(await store.checkAndInsert("jti-a", now: Date()) == false)
    #expect(await store.checkAndInsert("jti-b", now: Date()) == true)
  }

  @Test("Entries expire after the TTL")
  func entriesExpire() async {
    let store = ReplayStore(ttl: 10)
    let start = Date()
    #expect(await store.checkAndInsert("jti-x", now: start) == true)
    // Within TTL: still a replay.
    #expect(await store.checkAndInsert("jti-x", now: start.addingTimeInterval(5)) == false)
    // Past TTL: treated as fresh again (the proof's own iat window has
    // long since rejected proofs this old anyway).
    #expect(await store.checkAndInsert("jti-x", now: start.addingTimeInterval(11)) == true)
  }
}

@Suite("Nonce service")
struct NonceServiceTests {
  @Test("Issued nonces validate within the window")
  func roundTrip() {
    let service = NonceService(secretBase64: nil, validity: 300)
    let nonce = service.issue(now: Date())
    #expect(service.isValid(nonce, now: Date()) == true)
  }

  @Test("Tampered nonces fail")
  func tamperFails() {
    let service = NonceService(secretBase64: nil, validity: 300)
    let nonce = service.issue(now: Date())
    #expect(service.isValid(nonce + "x", now: Date()) == false)
    #expect(service.isValid("999999." + nonce.split(separator: ".")[1], now: Date()) == false)
    #expect(service.isValid("garbage", now: Date()) == false)
  }

  @Test("Nonces expire after the validity window")
  func expiry() {
    let service = NonceService(secretBase64: nil, validity: 300)
    let issued = Date()
    let nonce = service.issue(now: issued)
    #expect(service.isValid(nonce, now: issued.addingTimeInterval(301)) == false)
  }

  @Test("A fixed secret validates across instances; different secrets do not")
  func secretStability() {
    let secret = Data((0 ..< 32).map { UInt8($0) }).base64EncodedString()
    let a = NonceService(secretBase64: secret, validity: 300)
    let b = NonceService(secretBase64: secret, validity: 300)
    let c = NonceService(secretBase64: nil, validity: 300)
    let nonce = a.issue(now: Date())
    #expect(b.isValid(nonce, now: Date()) == true)
    #expect(c.isValid(nonce, now: Date()) == false)
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Server && swift test --filter ReplayStoreTests
```
Expected: COMPILE ERROR.

- [ ] **Step 3: Implement**

Create `Server/Sources/PetrelCABServerCore/ReplayStore.swift`:

```swift
import Foundation

/// Tracks seen DPoP proof `jti` values for the proof-acceptance window.
/// In-memory by design: replay protection only needs to span the iat window,
/// and a restart inside that window is an acceptable trade for a
/// zero-dependency server.
public actor ReplayStore {
  private var seen: [String: Date] = [:]
  private let ttl: TimeInterval

  public init(ttl: TimeInterval) {
    self.ttl = ttl
  }

  /// Returns true when the jti is fresh (and records it); false on replay.
  public func checkAndInsert(_ jti: String, now: Date = Date()) -> Bool {
    // O(n) prune per call is fine at this endpoint's request rates.
    seen = seen.filter { $0.value > now }
    if seen[jti] != nil { return false }
    seen[jti] = now.addingTimeInterval(ttl)
    return true
  }
}
```

Create `Server/Sources/PetrelCABServerCore/NonceService.swift`:

```swift
#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation

extension Data {
  public func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

/// Stateless server nonces: `<unix-ts>.<HMAC-SHA256(ts)>`. No storage —
/// any instance holding the secret can validate. With no configured secret
/// a random one is generated at startup (nonces then die with the process,
/// which is fine: clients transparently retry on the next challenge).
public struct NonceService: Sendable {
  private let secret: SymmetricKey
  private let validity: TimeInterval

  public init(secretBase64: String?, validity: TimeInterval = 300) {
    if let secretBase64, let data = Data(base64Encoded: secretBase64), !data.isEmpty {
      secret = SymmetricKey(data: data)
    } else {
      secret = SymmetricKey(size: .bits256)
    }
    self.validity = validity
  }

  public func issue(now: Date = Date()) -> String {
    let timestamp = String(Int(now.timeIntervalSince1970))
    return "\(timestamp).\(mac(timestamp))"
  }

  public func isValid(_ nonce: String, now: Date = Date()) -> Bool {
    let parts = nonce.split(separator: ".", maxSplits: 1)
    guard parts.count == 2, let timestamp = Int(parts[0]) else { return false }
    guard abs(now.timeIntervalSince1970 - TimeInterval(timestamp)) <= validity else {
      return false
    }
    // Nonces are freshness markers, not secrets — plain comparison is fine.
    return mac(String(parts[0])) == String(parts[1])
  }

  private func mac(_ value: String) -> String {
    let digest = HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: secret)
    return Data(digest).base64URLEncodedString()
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Server && swift test --filter ReplayStoreTests && swift test --filter NonceServiceTests
```
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
cd .. && git add Server
git commit -m "cab-server: jti replay store + stateless HMAC nonce service"
```

---

### Task 9: DeviceStore

**Files:**
- Create: `Server/Sources/PetrelCABServerCore/DeviceStore.swift`
- Test: `Server/Tests/PetrelCABServerCoreTests/DeviceStoreTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `struct DeviceRecord { firstSeen: Date; lastSeen: Date; requestCount: Int }`.
  - `protocol DeviceStore: Sendable { func record(jkt: String, now: Date) async; func isDenied(jkt: String) async -> Bool; func snapshot() async -> [String: DeviceRecord] }`.
  - `actor InMemoryDeviceStore: DeviceStore { init(deniedJKTs: [String]) }`.
  - This protocol is the documented v2 seam for SQLite persistence.

- [ ] **Step 1: Write the failing tests**

Create `Server/Tests/PetrelCABServerCoreTests/DeviceStoreTests.swift`:

```swift
import Foundation
@testable import PetrelCABServerCore
import Testing

@Suite("Device store")
struct DeviceStoreTests {
  @Test("Records first-seen, last-seen, and request counts per jkt")
  func recordsUsage() async {
    let store = InMemoryDeviceStore(deniedJKTs: [])
    let first = Date(timeIntervalSince1970: 1_000_000)
    let second = Date(timeIntervalSince1970: 1_000_100)
    await store.record(jkt: "device-1", now: first)
    await store.record(jkt: "device-1", now: second)
    await store.record(jkt: "device-2", now: second)

    let snapshot = await store.snapshot()
    #expect(snapshot.count == 2)
    #expect(snapshot["device-1"]?.firstSeen == first)
    #expect(snapshot["device-1"]?.lastSeen == second)
    #expect(snapshot["device-1"]?.requestCount == 2)
    #expect(snapshot["device-2"]?.requestCount == 1)
  }

  @Test("Denies exactly the configured jkts")
  func denyList() async {
    let store = InMemoryDeviceStore(deniedJKTs: ["bad-jkt"])
    #expect(await store.isDenied(jkt: "bad-jkt") == true)
    #expect(await store.isDenied(jkt: "good-jkt") == false)
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Server && swift test --filter DeviceStoreTests
```
Expected: COMPILE ERROR.

- [ ] **Step 3: Implement**

Create `Server/Sources/PetrelCABServerCore/DeviceStore.swift`:

```swift
import Foundation

public struct DeviceRecord: Sendable, Equatable {
  public var firstSeen: Date
  public var lastSeen: Date
  public var requestCount: Int
}

/// Per-device (`jkt`) usage tracking and refusal policy — the backend's
/// veto power from the proposal. Implementations may persist; the protocol
/// is the seam for a future SQLite-backed store.
public protocol DeviceStore: Sendable {
  func record(jkt: String, now: Date) async
  func isDenied(jkt: String) async -> Bool
  func snapshot() async -> [String: DeviceRecord]
}

public actor InMemoryDeviceStore: DeviceStore {
  private var devices: [String: DeviceRecord] = [:]
  private let deniedJKTs: Set<String>

  public init(deniedJKTs: [String]) {
    self.deniedJKTs = Set(deniedJKTs)
  }

  public func record(jkt: String, now: Date) {
    if var record = devices[jkt] {
      record.lastSeen = now
      record.requestCount += 1
      devices[jkt] = record
    } else {
      devices[jkt] = DeviceRecord(firstSeen: now, lastSeen: now, requestCount: 1)
    }
  }

  public func isDenied(jkt: String) -> Bool {
    deniedJKTs.contains(jkt)
  }

  public func snapshot() -> [String: DeviceRecord] {
    devices
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Server && swift test --filter DeviceStoreTests
```
Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd .. && git add Server
git commit -m "cab-server: DeviceStore protocol + in-memory implementation with deny list"
```

---

### Task 10: AssertionMinter + `POST /oauth/client-assertion` + CORS/origin policy

**Files:**
- Create: `Server/Sources/PetrelCABServerCore/AssertionMinter.swift`
- Create: `Server/Sources/PetrelCABServerCore/OriginPolicyMiddleware.swift`
- Modify: `Server/Sources/PetrelCABServerCore/CABServer.swift` (full wiring)
- Test: `Server/Tests/PetrelCABServerCoreTests/AssertionEndpointTests.swift`

**Interfaces:**
- Consumes: `KeyStore`/`SigningKey` (Task 6), `DPoPValidator`/`CABRequestError`/`HTTPField.Name.dpop/.dpopNonce` (Task 7), `ReplayStore`/`NonceService` (Task 8), `DeviceStore` (Task 9); test helpers `makeTestConfig` (KeyStoreTests.swift) and `makeDPoPProof` (DPoPValidatorTests.swift) — same test module, file-scope internal, directly callable.
- Produces:
  - `AssertionMinter { init(clientId: String, signingKey: SigningKey, ttl: TimeInterval); mint(aud: String, jkt: String, now: Date) throws -> String }`.
  - `OriginPolicyMiddleware<Context>` (origin allowlist + CORS + preflight).
  - `CABServer` gains `validator`, `replayStore`, `nonceService`, `deviceStore`, `minter` and the assertion route; also `static func checkAud(_:allowlist:)` and `static func errorResponse(_:nonceService:)`.
  - Task 13's integration tests and Task 15's demo consume the running endpoint as specified by the contract doc (Task 1).

- [ ] **Step 1: Write the failing tests**

Create `Server/Tests/PetrelCABServerCoreTests/AssertionEndpointTests.swift`:

```swift
#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import Hummingbird
import HummingbirdTesting
import JSONWebKey
import JSONWebSignature
@testable import PetrelCABServerCore
import Testing

private let endpointHTU = "https://cab.test/oauth/client-assertion"

private struct AssertionClaims: Decodable {
  struct Cnf: Decodable { let jkt: String }
  let iss: String
  let sub: String
  let aud: String
  let jti: String
  let iat: Int
  let exp: Int
  let cnf: Cnf
}

private func postAssertion(
  _ client: any TestClientProtocol,
  proof: String?,
  body: String = "aud=https://auth.example",
  origin: String? = nil
) async throws -> TestResponse {
  var headers: HTTPFields = [.contentType: "application/x-www-form-urlencoded"]
  if let proof { headers[.dpop] = proof }
  if let origin { headers[HTTPField.Name("Origin")!] = origin }
  return try await client.execute(
    uri: "/oauth/client-assertion", method: .post, headers: headers,
    body: ByteBuffer(string: body)
  )
}

@Suite("Assertion endpoint")
struct AssertionEndpointTests {
  @Test("Happy path mints a verifiable, correctly-shaped assertion")
  func happyPath() async throws {
    let (config, signingKey) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let deviceKey = P256.Signing.PrivateKey()
      let proof = try makeDPoPProof(key: deviceKey, htu: endpointHTU)
      let response = try await postAssertion(client, proof: proof)
      #expect(response.status == .ok)
      #expect(response.headers[.cacheControl] == "no-store")

      struct Body: Decodable {
        let clientId: String
        let clientAssertion: String
        enum CodingKeys: String, CodingKey {
          case clientId = "client_id"
          case clientAssertion = "client_assertion"
        }
      }
      let body = try JSONDecoder().decode(Body.self, from: Data(buffer: response.body))
      #expect(body.clientId == config.clientId)

      let jws = try JWS(jwsString: body.clientAssertion)
      #expect(jws.protectedHeader.algorithm == .ES256)
      #expect(jws.protectedHeader.keyID == "test-key-1")
      #expect(try jws.verify(key: signingKey.publicKey.jwkRepresentation))

      let claims = try JSONDecoder().decode(AssertionClaims.self, from: jws.payload)
      #expect(claims.iss == config.clientId)
      #expect(claims.sub == config.clientId)
      #expect(claims.aud == "https://auth.example")
      #expect(claims.exp - claims.iat == 60)
      #expect(claims.cnf.jkt == (try deviceKey.publicKey.jwkRepresentation.thumbprint()))
      #expect(!claims.jti.isEmpty)
    }
  }

  @Test("Missing DPoP header is invalid_dpop_proof")
  func missingProof() async throws {
    let (config, _) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let response = try await postAssertion(client, proof: nil)
      #expect(response.status == .badRequest)
      #expect(String(buffer: response.body).contains("invalid_dpop_proof"))
    }
  }

  @Test("Replaying a proof (same jti) is refused")
  func replayRefused() async throws {
    let (config, _) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let proof = try makeDPoPProof(htu: endpointHTU)
      let first = try await postAssertion(client, proof: proof)
      #expect(first.status == .ok)
      let second = try await postAssertion(client, proof: proof)
      #expect(second.status == .badRequest)
      #expect(String(buffer: second.body).contains("invalid_dpop_proof"))
    }
  }

  @Test("A denied jkt gets access_denied")
  func deniedDevice() async throws {
    let deviceKey = P256.Signing.PrivateKey()
    let jkt = try deviceKey.publicKey.jwkRepresentation.thumbprint()
    let (config, _) = try makeTestConfig { $0.deniedJkts = [jkt] }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let proof = try makeDPoPProof(key: deviceKey, htu: endpointHTU)
      let response = try await postAssertion(client, proof: proof)
      #expect(response.status == .forbidden)
      #expect(String(buffer: response.body).contains("access_denied"))
    }
  }

  @Test("Missing aud is invalid_request")
  func missingAud() async throws {
    let (config, _) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let proof = try makeDPoPProof(htu: endpointHTU)
      let response = try await postAssertion(client, proof: proof, body: "")
      #expect(response.status == .badRequest)
      #expect(String(buffer: response.body).contains("invalid_request"))
    }
  }

  @Test("aud outside the allowlist is refused")
  func audAllowlist() async throws {
    let (config, _) = try makeTestConfig { $0.audAllowlist = ["https://bsky.social"] }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let refused = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), body: "aud=https://evil.example"
      )
      #expect(refused.status == .badRequest)
      let allowed = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), body: "aud=https://bsky.social"
      )
      #expect(allowed.status == .ok)
    }
  }

  @Test("require_nonce challenges then accepts the echoed nonce")
  func nonceFlow() async throws {
    let (config, _) = try makeTestConfig { $0.requireNonce = true }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let deviceKey = P256.Signing.PrivateKey()
      let challenge = try await postAssertion(
        client, proof: try makeDPoPProof(key: deviceKey, htu: endpointHTU)
      )
      #expect(challenge.status == .badRequest)
      #expect(String(buffer: challenge.body).contains("use_dpop_nonce"))
      let nonce = try #require(challenge.headers[.dpopNonce])

      let retry = try await postAssertion(
        client, proof: try makeDPoPProof(key: deviceKey, htu: endpointHTU, nonce: nonce)
      )
      #expect(retry.status == .ok)
    }
  }

  @Test("Origin policy: allowlisted origins get CORS headers, others get 403")
  func originPolicy() async throws {
    let (config, _) = try makeTestConfig { $0.allowedOrigins = ["https://app.example"] }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let ok = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), origin: "https://app.example"
      )
      #expect(ok.status == .ok)
      #expect(ok.headers[HTTPField.Name("Access-Control-Allow-Origin")!] == "https://app.example")

      let refused = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), origin: "https://evil.example"
      )
      #expect(refused.status == .forbidden)

      // Preflight
      let preflight = try await client.execute(
        uri: "/oauth/client-assertion", method: .options,
        headers: [HTTPField.Name("Origin")!: "https://app.example"]
      )
      #expect(preflight.status == .noContent)
      #expect(
        preflight.headers[HTTPField.Name("Access-Control-Allow-Headers")!]?
          .contains("DPoP") == true
      )
    }
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Server && swift test --filter AssertionEndpointTests
```
Expected: COMPILE ERROR (route/minter/middleware missing) or 404s.

- [ ] **Step 3: Implement AssertionMinter**

Create `Server/Sources/PetrelCABServerCore/AssertionMinter.swift`:

```swift
import Foundation
import JSONWebKey
import JSONWebSignature

/// Signs RFC 7523 client assertion JWTs bound to a DPoP key via cnf/jkt.
public struct AssertionMinter: Sendable {
  public let clientId: String
  public let signingKey: SigningKey
  public let ttl: TimeInterval

  struct CnfClaim: Codable {
    let jkt: String
  }

  struct AssertionClaims: Codable {
    let iss: String
    let sub: String
    let aud: String
    let jti: String
    let iat: Int
    let exp: Int
    let cnf: CnfClaim
  }

  public init(clientId: String, signingKey: SigningKey, ttl: TimeInterval) {
    self.clientId = clientId
    self.signingKey = signingKey
    self.ttl = ttl
  }

  public func mint(aud: String, jkt: String, now: Date = Date()) throws -> String {
    let iat = Int(now.timeIntervalSince1970)
    let claims = AssertionClaims(
      iss: clientId,
      sub: clientId,
      aud: aud,
      jti: UUID().uuidString,
      iat: iat,
      exp: iat + Int(ttl),
      cnf: CnfClaim(jkt: jkt)
    )
    // kid is REQUIRED by @atproto/oauth-provider's client-assertion check.
    let header = DefaultJWSHeaderImpl(algorithm: .ES256, keyID: signingKey.kid)
    let payload = try JSONEncoder().encode(claims)
    return try JWS(payload: payload, protectedHeader: header, key: signingKey.privateKey)
      .compactSerialization
  }
}
```

- [ ] **Step 4: Implement OriginPolicyMiddleware**

Create `Server/Sources/PetrelCABServerCore/OriginPolicyMiddleware.swift`:

```swift
import Hummingbird

/// Enforces the configured Origin policy and answers CORS for browser
/// clients. Requests without an Origin header (native apps, curl) pass
/// unless `requireOrigin` is set. Custom implementation (not hummingbird's
/// CORSMiddleware) so refusals are 403s and DPoP-Nonce is always exposed.
struct OriginPolicyMiddleware<Context: RequestContext>: RouterMiddleware {
  let allowedOrigins: Set<String>
  let requireOrigin: Bool

  private enum Header {
    static let origin = HTTPField.Name("Origin")!
    static let allowOrigin = HTTPField.Name("Access-Control-Allow-Origin")!
    static let allowMethods = HTTPField.Name("Access-Control-Allow-Methods")!
    static let allowHeaders = HTTPField.Name("Access-Control-Allow-Headers")!
    static let exposeHeaders = HTTPField.Name("Access-Control-Expose-Headers")!
    static let maxAge = HTTPField.Name("Access-Control-Max-Age")!
    static let vary = HTTPField.Name("Vary")!
  }

  func handle(
    _ request: Request, context: Context,
    next: (Request, Context) async throws -> Response
  ) async throws -> Response {
    let origin = request.headers[Header.origin]

    if requireOrigin, origin == nil {
      return Self.forbidden("Origin header required")
    }
    if let origin, !allowedOrigins.contains(origin) {
      // With no configured origins, any browser origin is refused —
      // configure allowed_origins to serve browser clients.
      return Self.forbidden("origin not allowed")
    }

    if request.method == .options, let origin {
      var headers = HTTPFields()
      headers[Header.allowOrigin] = origin
      headers[Header.allowMethods] = "POST, GET, OPTIONS"
      headers[Header.allowHeaders] = "Content-Type, DPoP"
      headers[Header.exposeHeaders] = "DPoP-Nonce"
      headers[Header.maxAge] = "3600"
      headers[Header.vary] = "Origin"
      return Response(status: .noContent, headers: headers)
    }

    var response = try await next(request, context)
    if let origin {
      response.headers[Header.allowOrigin] = origin
      response.headers[Header.exposeHeaders] = "DPoP-Nonce"
      response.headers[Header.vary] = "Origin"
    }
    return response
  }

  static func forbidden(_ detail: String) -> Response {
    let body = #"{"error":"access_denied","error_description":"\#(detail)"}"#
    return Response(
      status: .forbidden,
      headers: [.contentType: "application/json"],
      body: .init(byteBuffer: ByteBuffer(string: body))
    )
  }
}
```

- [ ] **Step 5: Wire the endpoint into CABServer**

Replace the whole of `Server/Sources/PetrelCABServerCore/CABServer.swift` with:

```swift
import Foundation
import Hummingbird
import Logging

/// Assembles the configured server. `init` builds all stateful components;
/// `buildRouter()` wires routes; `buildApplication(logger:)` returns a
/// runnable app.
public struct CABServer: Sendable {
  public let config: ServerConfig
  public let keyStore: KeyStore
  let validator: DPoPValidator
  let replayStore: ReplayStore
  let nonceService: NonceService
  let deviceStore: any DeviceStore
  let minter: AssertionMinter

  public init(config: ServerConfig) throws {
    self.config = config
    let loadedKeyStore = try KeyStore(config: config)
    keyStore = loadedKeyStore
    validator = DPoPValidator(
      endpointURL: Self.assertionEndpoint(publicUrl: config.publicUrl),
      iatWindow: TimeInterval(config.iatWindowSeconds)
    )
    replayStore = ReplayStore(ttl: TimeInterval(config.iatWindowSeconds))
    nonceService = NonceService(secretBase64: config.nonceSecretBase64)
    deviceStore = InMemoryDeviceStore(deniedJKTs: config.deniedJkts)
    minter = AssertionMinter(
      clientId: config.clientId,
      signingKey: loadedKeyStore.activeKey,
      ttl: TimeInterval(config.assertionTtlSeconds)
    )
  }

  static func assertionEndpoint(publicUrl: String) -> String {
    let base = publicUrl.hasSuffix("/") ? String(publicUrl.dropLast()) : publicUrl
    return base + "/oauth/client-assertion"
  }

  public func buildRouter() -> Router<BasicRequestContext> {
    let router = Router(context: BasicRequestContext.self)
    router.middlewares.add(
      OriginPolicyMiddleware(
        allowedOrigins: Set(config.allowedOrigins),
        requireOrigin: config.requireOrigin
      )
    )

    router.get("/health") { _, _ in "OK" }

    // JWKS must be precomputable — fail at startup, not per request.
    let jwksBody = (try? keyStore.jwksDocument()) ?? Data()
    router.get("/.well-known/jwks.json") { _, _ -> Response in
      Response(
        status: .ok,
        headers: [.contentType: "application/json", .cacheControl: "public, max-age=300"],
        body: .init(byteBuffer: ByteBuffer(data: jwksBody))
      )
    }

    let config = self.config
    let validator = self.validator
    let replayStore = self.replayStore
    let nonceService = self.nonceService
    let deviceStore = self.deviceStore
    let minter = self.minter

    router.post("/oauth/client-assertion") { request, context -> Response in
      do {
        guard let proof = request.headers[.dpop] else {
          throw CABRequestError.invalidDPoPProof("missing DPoP header")
        }
        let (validated, claims) = try validator.validate(proof: proof)

        if config.requireNonce {
          guard let nonce = claims.nonce, nonceService.isValid(nonce) else {
            throw CABRequestError.useDPoPNonce()
          }
        }
        guard await replayStore.checkAndInsert(validated.jti) else {
          throw CABRequestError.invalidDPoPProof("jti replayed")
        }
        if await deviceStore.isDenied(jkt: validated.jkt) {
          context.logger.warning(
            "device refused", metadata: ["jkt": .string(validated.jkt)]
          )
          throw CABRequestError.accessDenied("device refused by policy")
        }
        await deviceStore.record(jkt: validated.jkt, now: Date())

        struct AssertionForm: Decodable {
          let aud: String?
        }
        let form = try? await URLEncodedFormDecoder().decode(
          AssertionForm.self, from: request, context: context
        )
        guard let aud = form?.aud, !aud.isEmpty else {
          throw CABRequestError.invalidRequest("missing aud")
        }
        try CABServer.checkAud(aud, allowlist: config.audAllowlist)

        let assertion = try minter.mint(aud: aud, jkt: validated.jkt)
        context.logger.info(
          "assertion minted",
          metadata: ["jkt": .string(validated.jkt), "aud": .string(aud)]
        )

        struct ClientAssertionResponseBody: ResponseEncodable {
          let clientId: String
          let clientAssertion: String
          enum CodingKeys: String, CodingKey {
            case clientId = "client_id"
            case clientAssertion = "client_assertion"
          }
        }
        let body = ClientAssertionResponseBody(
          clientId: config.clientId, clientAssertion: assertion
        )
        var response = try context.responseEncoder.encode(
          body, from: request, context: context
        )
        response.headers[.cacheControl] = "no-store"
        return response
      } catch let error as CABRequestError {
        if error.error != "use_dpop_nonce" {
          context.logger.notice(
            "assertion refused",
            metadata: ["error": .string(error.error), "detail": .string(error.description)]
          )
        }
        return CABServer.errorResponse(error, nonceService: nonceService)
      }
    }

    return router
  }

  static func checkAud(_ aud: String, allowlist: [String]?) throws {
    guard let url = URL(string: aud), let scheme = url.scheme, let host = url.host else {
      throw CABRequestError.invalidRequest("aud must be a valid URL")
    }
    let isLoopback = host == "127.0.0.1" || host == "localhost" || host == "::1"
    guard scheme == "https" || (scheme == "http" && isLoopback) else {
      throw CABRequestError.invalidRequest("aud must be an https URL")
    }
    if let allowlist, !allowlist.contains(aud) {
      throw CABRequestError.invalidRequest("aud not allowed by this backend")
    }
  }

  static func errorResponse(_ error: CABRequestError, nonceService: NonceService) -> Response {
    struct ErrorBody: Encodable {
      let error: String
      let errorDescription: String
      enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
      }
    }
    let data =
      (try? JSONEncoder().encode(
        ErrorBody(error: error.error, errorDescription: error.description)
      )) ?? Data()
    var headers: HTTPFields = [.contentType: "application/json", .cacheControl: "no-store"]
    if error.error == "use_dpop_nonce" {
      headers[.dpopNonce] = nonceService.issue()
    }
    return Response(
      status: .init(code: error.status, reasonPhrase: ""),
      headers: headers,
      body: .init(byteBuffer: ByteBuffer(data: data))
    )
  }

  public func buildApplication(logger: Logger) -> some ApplicationProtocol {
    Application(
      router: buildRouter(),
      configuration: .init(
        address: .hostname(config.host, port: config.port),
        serverName: "petrel-cab-server"
      ),
      logger: logger
    )
  }
}
```

- [ ] **Step 6: Run the endpoint tests and the whole server suite**

```bash
cd Server && swift test --filter AssertionEndpointTests && swift test
```
Expected: 8 endpoint tests PASS; all prior suites still PASS.

- [ ] **Step 7: Commit**

```bash
cd .. && git add Server
git commit -m "cab-server: assertion endpoint — DPoP-gated minting with cnf/jkt, nonce challenge, device policy, CORS"
```

---

### Task 11: RateLimiter + optional client-metadata endpoint

**Files:**
- Create: `Server/Sources/PetrelCABServerCore/RateLimiter.swift`
- Modify: `Server/Sources/PetrelCABServerCore/CABServer.swift` (rate-limit check + metadata route)
- Test: `Server/Tests/PetrelCABServerCoreTests/RateLimitAndMetadataTests.swift`

**Interfaces:**
- Consumes: `RateLimitConfig` (Task 5), `JSONValue` (Task 5), everything wired in Task 10.
- Produces: `actor RateLimiter { init(requestsPerMinute: Int); allow(key: String, now: Date) -> Bool }`; `CABServer` gains `let rateLimiter: RateLimiter?` and serves `GET /oauth-client-metadata.json` when `config.clientMetadata` is set.
- Deliberate narrowing vs the spec: rate limiting keys on `jkt` only (post-proof-validation), not per-IP — `BasicRequestContext` exposes no reliable client address, and jkt keying can't be gamed onto someone else's budget without their key. Documented in the README (Task 12); per-IP limiting belongs in the fronting reverse proxy.

- [ ] **Step 1: Write the failing tests**

Create `Server/Tests/PetrelCABServerCoreTests/RateLimitAndMetadataTests.swift`:

```swift
#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import Hummingbird
import HummingbirdTesting
@testable import PetrelCABServerCore
import Testing

@Suite("Rate limiter")
struct RateLimiterTests {
  @Test("Allows up to the per-minute budget, then refuses, then refills")
  func tokenBucket() async {
    let limiter = RateLimiter(requestsPerMinute: 3)
    let start = Date(timeIntervalSince1970: 2_000_000)
    #expect(await limiter.allow(key: "k", now: start) == true)
    #expect(await limiter.allow(key: "k", now: start) == true)
    #expect(await limiter.allow(key: "k", now: start) == true)
    #expect(await limiter.allow(key: "k", now: start) == false)
    // Independent keys have independent budgets.
    #expect(await limiter.allow(key: "other", now: start) == true)
    // One second refills 3/60 = 0.05 tokens — not enough.
    #expect(await limiter.allow(key: "k", now: start.addingTimeInterval(1)) == false)
    // Twenty-one seconds refills > 1 token.
    #expect(await limiter.allow(key: "k", now: start.addingTimeInterval(21)) == true)
  }
}

@Suite("Rate-limited endpoint")
struct RateLimitedEndpointTests {
  @Test("Per-jkt budget exhaustion yields 429 rate_limited")
  func endpointRateLimit() async throws {
    let (config, _) = try makeTestConfig {
      $0.rateLimit = RateLimitConfig(requestsPerMinute: 2)
    }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let deviceKey = P256.Signing.PrivateKey()
      for expected in [HTTPResponse.Status.ok, .ok, .tooManyRequests] {
        let proof = try makeDPoPProof(
          key: deviceKey, htu: "https://cab.test/oauth/client-assertion"
        )
        let response = try await client.execute(
          uri: "/oauth/client-assertion", method: .post,
          headers: [
            .contentType: "application/x-www-form-urlencoded",
            .dpop: proof,
          ],
          body: ByteBuffer(string: "aud=https://auth.example")
        )
        #expect(response.status == expected)
      }
    }
  }
}

@Suite("Client metadata endpoint")
struct ClientMetadataEndpointTests {
  @Test("Serves the configured document verbatim; absent config yields 404")
  func metadataToggle() async throws {
    let (bare, _) = try makeTestConfig()
    let bareServer = try CABServer(config: bare)
    let bareApp = Application(router: bareServer.buildRouter())
    try await bareApp.test(.router) { client in
      try await client.execute(uri: "/oauth-client-metadata.json", method: .get) { response in
        #expect(response.status == .notFound)
      }
    }

    let (config, _) = try makeTestConfig {
      $0.clientMetadata = .object([
        "client_id": .string("https://cab.test/oauth-client-metadata.json"),
        "token_endpoint_auth_method": .string("private_key_jwt"),
        "jwks_uri": .string("https://cab.test/.well-known/jwks.json"),
        "dpop_bound_access_tokens": .bool(true),
      ])
    }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      try await client.execute(uri: "/oauth-client-metadata.json", method: .get) { response in
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "application/json")
        let parsed = try JSONSerialization.jsonObject(
          with: Data(buffer: response.body)
        ) as? [String: Any]
        #expect(parsed?["token_endpoint_auth_method"] as? String == "private_key_jwt")
        #expect(parsed?["dpop_bound_access_tokens"] as? Bool == true)
      }
    }
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Server && swift test --filter RateLimiterTests
```
Expected: COMPILE ERROR — `RateLimiter` does not exist.

- [ ] **Step 3: Implement RateLimiter**

Create `Server/Sources/PetrelCABServerCore/RateLimiter.swift`:

```swift
import Foundation

/// Token-bucket limiter keyed by arbitrary strings (this server keys by
/// device `jkt` after proof validation, so attackers can't exhaust someone
/// else's budget without their key).
public actor RateLimiter {
  private var buckets: [String: (tokens: Double, lastRefill: Date)] = [:]
  private let capacity: Double
  private let refillPerSecond: Double

  public init(requestsPerMinute: Int) {
    capacity = Double(requestsPerMinute)
    refillPerSecond = Double(requestsPerMinute) / 60.0
  }

  public func allow(key: String, now: Date = Date()) -> Bool {
    var bucket = buckets[key] ?? (tokens: capacity, lastRefill: now)
    bucket.tokens = min(
      capacity,
      bucket.tokens + now.timeIntervalSince(bucket.lastRefill) * refillPerSecond
    )
    bucket.lastRefill = now
    if bucket.tokens < 1 {
      buckets[key] = bucket
      return false
    }
    bucket.tokens -= 1
    buckets[key] = bucket
    return true
  }
}
```

- [ ] **Step 4: Wire into CABServer**

In `Server/Sources/PetrelCABServerCore/CABServer.swift`:

(a) Add the stored property after `let minter: AssertionMinter`:

```swift
  let rateLimiter: RateLimiter?
```

and in `init`, after `minter = ...`:

```swift
    rateLimiter = config.rateLimit.map { RateLimiter(requestsPerMinute: $0.requestsPerMinute) }
```

(b) In `buildRouter()`, add alongside the other local captures:

```swift
    let rateLimiter = self.rateLimiter
```

and in the assertion handler, immediately AFTER the `deviceStore.isDenied` check (before `deviceStore.record`):

```swift
        if let rateLimiter, await rateLimiter.allow(key: "jkt:\(validated.jkt)") == false {
          throw CABRequestError.rateLimited()
        }
```

(c) Still in `buildRouter()`, after the JWKS route, add the metadata route:

```swift
    if let metadata = config.clientMetadata {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let metadataBody = (try? encoder.encode(metadata)) ?? Data()
      router.get("/oauth-client-metadata.json") { _, _ -> Response in
        Response(
          status: .ok,
          headers: [.contentType: "application/json", .cacheControl: "public, max-age=300"],
          body: .init(byteBuffer: ByteBuffer(data: metadataBody))
        )
      }
    }
```

- [ ] **Step 5: Run tests**

```bash
cd Server && swift test
```
Expected: all suites PASS.

- [ ] **Step 6: Commit**

```bash
cd .. && git add Server
git commit -m "cab-server: per-jkt rate limiting + optional client-metadata hosting"
```

---

### Task 12: Packaging — example config, README, Dockerfile, systemd unit

**Files:**
- Create: `Server/config.example.json`
- Create: `Server/README.md`
- Create: `Server/Dockerfile`
- Create: `Server/deploy/petrel-cab-server.service`

**Interfaces:**
- Consumes: every config field from Task 5 (names must match `CodingKeys` exactly); CLI surface from Tasks 5–6.
- Produces: user-facing docs; nothing programmatic.

- [ ] **Step 1: Write config.example.json**

Create `Server/config.example.json`:

```json
{
  "client_id": "https://cab.example.com/oauth-client-metadata.json",
  "public_url": "https://cab.example.com",
  "host": "127.0.0.1",
  "port": 8080,
  "keys": [{ "kid": "cab-key-1", "pem_path": "keys/cab-key-1.pem" }],
  "active_kid": "cab-key-1",
  "allowed_origins": [],
  "require_origin": false,
  "aud_allowlist": null,
  "assertion_ttl_seconds": 60,
  "iat_window_seconds": 300,
  "require_nonce": false,
  "denied_jkts": [],
  "rate_limit": { "requests_per_minute": 60 },
  "client_metadata": {
    "client_id": "https://cab.example.com/oauth-client-metadata.json",
    "client_name": "My App",
    "application_type": "web",
    "grant_types": ["authorization_code", "refresh_token"],
    "response_types": ["code"],
    "redirect_uris": ["https://app.example.com/oauth/callback"],
    "scope": "atproto transition:generic",
    "token_endpoint_auth_method": "private_key_jwt",
    "token_endpoint_auth_signing_alg": "ES256",
    "jwks_uri": "https://cab.example.com/.well-known/jwks.json",
    "dpop_bound_access_tokens": true
  }
}
```

`application_type` MUST be `"web"` and every redirect URI MUST be `https` —
`@atproto/oauth-provider` rejects `native` clients with any auth method other
than `none` (its source cites this very proposal as the future reason to lift
that restriction), and loopback/custom-scheme redirects are native-only.
Mobile apps should use https universal-link redirects (Catbird-style).

- [ ] **Step 2: Write the README**

Create `Server/README.md` covering, in this order (write real prose, not stubs):
1. **What it is** — two paragraphs: the client-assertion-backend pattern (link the proposal and `../docs/cab-backend-contract.md`), and what this buys you (confidential client, mass/per-device revocation, no token custody).
2. **Quickstart** — the exact commands:
   ```bash
   swift run petrel-cab-server generate-key --kid cab-key-1   # save the PEM to keys/cab-key-1.pem
   cp config.example.json config.json                          # edit client_id/public_url
   swift run petrel-cab-server serve --config config.json
   curl -s http://127.0.0.1:8080/health                        # → OK
   curl -s http://127.0.0.1:8080/.well-known/jwks.json | jq .
   ```
3. **Using it from Petrel** — the three-line client change: `ATProtoClient(oauthConfig:..., authMode: .cab(backendURL: URL(string: "https://cab.example.com")!))`, plus a note that `client_id` in `OAuthConfig` must equal the backend's `client_id`.
4. **Configuration reference** — a table of every field in `config.example.json` (name, default, meaning) plus the env overrides `CAB_CLIENT_ID`, `CAB_PUBLIC_URL`, `CAB_HOST`, `CAB_PORT`, `CAB_ACTIVE_KID`, `CAB_KEY_PEM_BASE64`, `CAB_KEY_KID`, `CAB_ALLOWED_ORIGINS`, `CAB_REQUIRE_NONCE`, `CAB_NONCE_SECRET_BASE64`, `CAB_DENIED_JKTS`.
5. **Key rotation = mass session revocation** — the AS pins the client-auth key (`kid`/`alg`/`jkt`) per session at initial token issuance and rejects refreshes signed by any other key (`invalid_grant` → users re-login). Switching `active_kid` therefore deliberately revokes every existing session — this is the proposal's mass-revocation lever, not a gentle rotation. Keep superseded keys listed in `keys` briefly only so assertions minted seconds before the switch still verify.
6. **AS constraints today** (verified against @atproto/oauth-provider, 2026-07): `application_type` must be `web` with https redirect URIs (native + private_key_jwt is rejected until the client-assertion-backend proposal is adopted upstream; `http://localhost` redirects are rejected for everyone); client assertions must have `iat` within 60 s (CLIENT_ASSERTION_MAX_AGE) — keep server clocks NTP-synced; the `cnf`/`jkt` binding is not yet AS-enforced (forward-compatible). The AS fetches `client_id` and `jwks_uri` through an SSRF-guarded client: public **https only, standard port, no IP-literal hosts, ≤512 kB, redirects rejected**, metadata must be served with `Content-Type: application/json`, and both documents are cached for **10 minutes** — `client_id` must also have a non-root path (e.g. `/oauth-client-metadata.json`) with no trailing slash.
7. **Security model** — condensed from the spec: open endpoint by design, DPoP-bound, per-jkt rate limit + deny list, no token custody; `require_nonce` and `aud_allowlist` hardening knobs; run behind TLS (reverse proxy) with `public_url` set to the external URL.
8. **Deployment** — Docker build/run commands (below) and the systemd unit.

- [ ] **Step 3: Write the Dockerfile**

Create `Server/Dockerfile`:

```dockerfile
# Build from the PETREL REPO ROOT so the path dependency resolves:
#   docker build -f Server/Dockerfile -t petrel-cab-server .
FROM swift:6.1-noble AS build
# libsecret is only needed to satisfy Petrel's Linux system-library target
# during dependency resolution; the server product itself never links it.
RUN apt-get update && apt-get install -y --no-install-recommends \
      libsecret-1-dev libglib2.0-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /repo
COPY . .
WORKDIR /repo/Server
RUN swift build -c release --product petrel-cab-server

FROM swift:6.1-noble-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /repo/Server/.build/release/petrel-cab-server /usr/local/bin/petrel-cab-server
EXPOSE 8080
ENTRYPOINT ["petrel-cab-server"]
CMD ["serve"]
```

- [ ] **Step 4: Write the systemd unit**

Create `Server/deploy/petrel-cab-server.service`:

```ini
[Unit]
Description=Petrel CAB server (ATProto OAuth client assertion backend)
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=cab
Group=cab
WorkingDirectory=/opt/petrel-cab-server
ExecStart=/opt/petrel-cab-server/petrel-cab-server serve --config /opt/petrel-cab-server/config.json
Restart=on-failure
RestartSec=2
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/opt/petrel-cab-server

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 5: Verify the quickstart actually works, then commit**

```bash
cd Server
swift run petrel-cab-server generate-key --kid smoke > /tmp/smoke-key.txt && head -1 /tmp/smoke-key.txt
CAB_CLIENT_ID=https://cab.example.com/meta.json \
CAB_PUBLIC_URL=https://cab.example.com \
CAB_KEY_PEM_BASE64=$(swift run petrel-cab-server generate-key --kid k1 | awk '/Base64 PEM/{getline; getline; print}') \
swift run petrel-cab-server serve &
sleep 3
curl -sf http://127.0.0.1:8080/health
curl -sf http://127.0.0.1:8080/.well-known/jwks.json
kill %1
```
Expected: `OK` and a JWKS document. (Docker build is verified in Task 16 on the deploy box or skipped on macOS if Docker is unavailable — note the result either way.)

```bash
cd .. && git add Server
git commit -m "cab-server: packaging — example config, README, Dockerfile, systemd unit"
```

---

### Task 13: Cross-package integration tests — Petrel client ↔ real server over HTTP

**Files:**
- Create: `Server/Tests/PetrelCABIntegrationTests/ClientServerIntegrationTests.swift`
- Delete: `Server/Tests/PetrelCABIntegrationTests/PlaceholderTests.swift`

**Interfaces:**
- Consumes: `CABServer` (Tasks 10–11); Petrel's `CABOAuthStrategy.fetchClientAssertion(aud:ephemeralKey:did:)` and `AuthError.clientAssertionBackendError` (Task 3) via `@testable import Petrel`; jose-swift for assertion verification.
- Produces: proof that both sides implement the Task 1 contract identically, including the nonce dance, over a real TCP socket.

- [ ] **Step 1: Write the failing tests**

Replace `PlaceholderTests.swift` with `Server/Tests/PetrelCABIntegrationTests/ClientServerIntegrationTests.swift`:

```swift
#if canImport(CryptoKit)
  import CryptoKit
#else
  @preconcurrency import Crypto
#endif
import Foundation
import Hummingbird
import JSONWebKey
import JSONWebSignature
import Logging
@testable import Petrel
@testable import PetrelCABServerCore
import Testing

// MARK: - Petrel-side test doubles (this target cannot see PetrelTests')

actor IntegrationAccountManager: AccountManaging {
  private let account: Account
  init(account: Account) { self.account = account }
  func addAccount(_: Account) async throws {}
  func getAccount(did: String) async -> Account? { did == account.did ? account : nil }
  func updateAccountFromStorage(did _: String) async throws {}
  func removeAccount(did _: String) async throws {}
  func setCurrentAccount(did _: String) async throws {}
  func getCurrentAccount() async -> Account? { account }
  func listAccounts() async -> [Account] { [account] }
  func clearCurrentAccount() async {}
  func updateServiceDIDs(bskyAppViewDID _: String, bskyChatDID _: String) async throws {}
}

final class IntegrationDIDResolver: DIDResolving, @unchecked Sendable {
  func resolveHandleToDID(handle _: String) async throws -> String { "did:plc:test" }
  func resolveDIDToPDSURL(did _: String) async throws -> URL { URL(string: "https://pds.test")! }
  func resolveDIDToHandleAndPDSURL(did _: String) async throws -> (String, URL) {
    ("test.example", URL(string: "https://pds.test")!)
  }
}

// MARK: - Harness

/// Runs a fully-wired CABServer on a random loopback port for the duration
/// of `body`. Port collisions are possible but vanishingly rare; rerun on a
/// bind failure.
func withRunningServer(
  mutateConfig: @escaping @Sendable (inout ServerConfig) -> Void = { _ in },
  _ body: @Sendable (_ port: Int, _ serverKey: P256.Signing.PrivateKey) async throws -> Void
) async throws {
  let port = Int.random(in: 20000 ..< 60000)
  let serverKey = P256.Signing.PrivateKey()
  let pemBase64 = Data(serverKey.pemRepresentation.utf8).base64EncodedString()
  let json = """
    {
      "client_id": "https://cab.test/oauth-client-metadata.json",
      "public_url": "http://127.0.0.1:\(port)",
      "host": "127.0.0.1",
      "port": \(port),
      "keys": [{ "kid": "integration-key", "pem_base64": "\(pemBase64)" }],
      "active_kid": "integration-key"
    }
    """
  var config = try JSONDecoder().decode(ServerConfig.self, from: Data(json.utf8))
  mutateConfig(&config)
  try config.validate()

  let server = try CABServer(config: config)
  var logger = Logger(label: "integration")
  logger.logLevel = .error
  let app = server.buildApplication(logger: logger)

  let serverTask = Task { try await app.runService() }
  defer { serverTask.cancel() }

  // Wait for readiness by polling /health.
  let healthURL = URL(string: "http://127.0.0.1:\(port)/health")!
  var ready = false
  for _ in 0 ..< 50 {
    if let (_, response) = try? await URLSession.shared.data(from: healthURL),
       (response as? HTTPURLResponse)?.statusCode == 200
    {
      ready = true
      break
    }
    try await Task.sleep(nanoseconds: 100_000_000)
  }
  try #require(ready, "server did not become ready on port \(port)")

  try await body(port, serverKey)
}

func makeStrategy(port: Int, namespace: String) -> CABOAuthStrategy {
  CABOAuthStrategy(
    backendURL: URL(string: "http://127.0.0.1:\(port)")!,
    storage: KeychainStorage(namespace: namespace),
    accountManager: IntegrationAccountManager(
      account: Account(
        did: "did:plc:test",
        handle: "test.example",
        pdsURL: URL(string: "https://pds.test")!
      )
    ),
    networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
    oauthConfig: OAuthConfig(
      clientId: "https://cab.test/oauth-client-metadata.json",
      redirectUri: "https://client.example/callback",
      scope: "atproto"
    ),
    didResolver: IntegrationDIDResolver()
  )
}

// MARK: - Tests

@Suite("Petrel ↔ petrel-cab-server integration", .serialized)
struct ClientServerIntegrationTests {
  @Test("Petrel fetches a verifiable assertion from the real server")
  func fetchRoundTrip() async throws {
    try await withRunningServer { port, serverKey in
      let strategy = makeStrategy(port: port, namespace: "integration.fetch")
      let deviceKey = P256.Signing.PrivateKey()

      let response = try await strategy.fetchClientAssertion(
        aud: "https://auth.example", ephemeralKey: deviceKey
      )

      #expect(response.clientId == "https://cab.test/oauth-client-metadata.json")
      let jws = try JWS(jwsString: response.clientAssertion)
      #expect(jws.protectedHeader.keyID == "integration-key")
      #expect(try jws.verify(key: serverKey.publicKey.jwkRepresentation))

      struct Claims: Decodable {
        struct Cnf: Decodable { let jkt: String }
        let iss: String
        let aud: String
        let cnf: Cnf
      }
      let claims = try JSONDecoder().decode(Claims.self, from: jws.payload)
      #expect(claims.iss == "https://cab.test/oauth-client-metadata.json")
      #expect(claims.aud == "https://auth.example")
      #expect(claims.cnf.jkt == (try deviceKey.publicKey.jwkRepresentation.thumbprint()))
    }
  }

  @Test("Nonce dance is transparent: require_nonce server, one client call")
  func nonceDance() async throws {
    try await withRunningServer(mutateConfig: { $0.requireNonce = true }) { port, _ in
      let strategy = makeStrategy(port: port, namespace: "integration.nonce")
      let response = try await strategy.fetchClientAssertion(
        aud: "https://auth.example", ephemeralKey: P256.Signing.PrivateKey()
      )
      #expect(!response.clientAssertion.isEmpty)
    }
  }

  @Test("Server device refusal surfaces as the typed Petrel error")
  func deviceRefusal() async throws {
    let deviceKey = P256.Signing.PrivateKey()
    let jkt = try deviceKey.publicKey.jwkRepresentation.thumbprint()
    try await withRunningServer(mutateConfig: { $0.deniedJkts = [jkt] }) { port, _ in
      let strategy = makeStrategy(port: port, namespace: "integration.denied")
      await #expect(throws: AuthError.clientAssertionBackendError(403, "access_denied")) {
        _ = try await strategy.fetchClientAssertion(
          aud: "https://auth.example", ephemeralKey: deviceKey
        )
      }
    }
  }
}
```

- [ ] **Step 2: Run the integration tests**

```bash
cd Server && swift test --filter ClientServerIntegrationTests
```
Expected: 3 tests PASS. If Petrel's `fetchClientAssertion` and the server disagree about any part of the contract (form encoding, htu canonicalization, nonce header name, error shape), it surfaces HERE — fix the offending side to match `docs/cab-backend-contract.md`, never both-ways.

Note: these tests hit the real network stack on loopback and Petrel's real DPoP proof generation (ephemeral-key path touches no keychain). If a keychain prompt ever appears, something regressed in Petrel's nonce-resolution path — investigate rather than suppress.

- [ ] **Step 3: Commit**

```bash
cd .. && git add Server
git commit -m "cab-server: integration tests — Petrel CAB strategy against the live server (contract, nonce dance, refusal)"
```

---

### Task 14: Demo CLI (`petrel-cab-demo`)

**Files:**
- Modify: `Server/Sources/petrel-cab-demo/DemoCommand.swift` (replace the Task 5 placeholder entirely)

**Interfaces:**
- Consumes: Petrel public API — `ATProtoClient(oauthConfig:namespace:authMode:)` with `AuthMode.cab(backendURL:)`, `startOAuthFlow(identifier:) -> URL`, `handleOAuthCallback(url:)`, `refreshToken() -> Bool`, `client.com.atproto.server.getSession() -> (responseCode: Int, data: ComAtprotoServerGetSession.Output?)`; Hummingbird for the callback listener.
- Produces: the executable Task 16 drives. Exit code 0 with `E2E RESULT: PASS` printed only when login + authenticated call + forced refresh + second authenticated call ALL succeed.

**AS constraint shaping this design (verified in the atproto checkout):** confidential clients must be `application_type: web` with **https** redirect URIs — no loopback. The demo therefore listens on a local port and expects a tunnel (or any https reverse proxy) to front it; `--redirect-uri` is the public https URL that maps to this listener.

- [ ] **Step 1: Implement the demo**

Replace `Server/Sources/petrel-cab-demo/DemoCommand.swift` with:

```swift
import ArgumentParser
import Foundation
import Hummingbird
import Logging
import Petrel

@main
struct DemoCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "petrel-cab-demo",
    abstract: "End-to-end demo: log into an ATProto account via a CAB backend",
    subcommands: [Login.self, Refresh.self],
    defaultSubcommand: Login.self
  )
}

struct Refresh: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "refresh",
    abstract: "Force a token refresh for the session stored by a previous login"
  )

  @Option(name: .long, help: "CAB backend base URL")
  var backend: String

  @Option(name: .long, help: "client_id URL (must match the backend's client_id)")
  var clientId: String

  @Option(name: .long, help: "Redirect URI used at login (config consistency only)")
  var redirectUri: String

  @Option(name: .long, help: "OAuth scope")
  var scope: String = "atproto transition:generic"

  func run() async throws {
    guard let backendURL = URL(string: backend) else {
      throw ValidationError("--backend is not a valid URL")
    }
    let client = try await ATProtoClient(
      oauthConfig: OAuthConfig(clientId: clientId, redirectUri: redirectUri, scope: scope),
      namespace: "blue.catbird.cabdemo",
      authMode: .cab(backendURL: backendURL),
      userAgent: "petrel-cab-demo/1.0"
    )
    do {
      let refreshed = try await client.refreshToken()
      print("REFRESH RESULT: \(refreshed ? "PASS" : "FAIL")")
      if !refreshed { throw ExitCode.failure }
    } catch {
      print("REFRESH RESULT: FAIL — \(error)")
      throw ExitCode.failure
    }
  }
}

struct Login: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "login",
    abstract: "Run the full CAB OAuth flow and verify an authenticated call + refresh"
  )

  @Option(name: .long, help: "Account handle to log in (e.g. alice.bsky.social)")
  var handle: String

  @Option(name: .long, help: "CAB backend base URL (e.g. https://xxx.trycloudflare.com)")
  var backend: String

  @Option(name: .long, help: "client_id URL (must match the backend's client_id)")
  var clientId: String

  @Option(
    name: .long,
    help: "Public https redirect URI (fronted by a tunnel that forwards to --callback-port)"
  )
  var redirectUri: String

  @Option(name: .long, help: "Local port the callback listener binds on 127.0.0.1")
  var callbackPort: Int = 8378

  @Option(name: .long, help: "OAuth scope")
  var scope: String = "atproto transition:generic"

  func run() async throws {
    guard let backendURL = URL(string: backend) else {
      throw ValidationError("--backend is not a valid URL")
    }

    let client = try await ATProtoClient(
      oauthConfig: OAuthConfig(clientId: clientId, redirectUri: redirectUri, scope: scope),
      namespace: "blue.catbird.cabdemo",
      authMode: .cab(backendURL: backendURL),
      userAgent: "petrel-cab-demo/1.0"
    )

    // 1. Start the flow (PAR with client assertion happens inside Petrel).
    let authURL = try await client.startOAuthFlow(identifier: handle)
    print("\n[1/5] Authorization URL (opening in browser):\n\(authURL.absoluteString)\n")
    #if os(macOS)
      let opener = Process()
      opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      opener.arguments = [authURL.absoluteString]
      try? opener.run()
    #endif

    // 2. Catch the redirect on a local listener (the tunnel forwards the
    //    public https redirect URI here).
    print("[2/5] Waiting for the OAuth callback on 127.0.0.1:\(callbackPort) …")
    let query = try await Self.waitForCallback(port: callbackPort)
    guard let callbackURL = URL(string: "\(redirectUri)?\(query)") else {
      throw ValidationError("could not reconstruct callback URL")
    }

    // 3. Exchange the code (fresh client assertion fetched inside Petrel).
    try await client.handleOAuthCallback(url: callbackURL)
    print("[3/5] Token exchange complete.")

    // 4. Authenticated call.
    let (code, session) = try await client.com.atproto.server.getSession()
    guard code == 200, let session else {
      print("E2E RESULT: FAIL — getSession returned \(code)")
      throw ExitCode.failure
    }
    print("[4/5] Authenticated as \(session.handle) (\(session.did))")

    // 5. Forced refresh (assertion-authenticated), then prove the new
    //    tokens work.
    let refreshed = try await client.refreshToken()
    let (codeAfter, _) = try await client.com.atproto.server.getSession()
    guard refreshed, codeAfter == 200 else {
      print("E2E RESULT: FAIL — refresh=\(refreshed) getSessionAfter=\(codeAfter)")
      throw ExitCode.failure
    }
    print("[5/5] Forced token refresh + re-verified session.")
    print("\nE2E RESULT: PASS — handle=\(session.handle) did=\(session.did)")
  }

  /// One-shot HTTP listener: serves GET /callback, returns its raw query
  /// string, then shuts down.
  static func waitForCallback(port: Int) async throws -> String {
    let (stream, continuation) = AsyncStream<String>.makeStream()
    let router = Router(context: BasicRequestContext.self)
    router.get("/callback") { request, _ -> Response in
      continuation.yield(request.uri.query ?? "")
      return Response(
        status: .ok,
        headers: [.contentType: "text/html; charset=utf-8"],
        body: .init(byteBuffer: ByteBuffer(
          string: "<html><body><h2>Login complete</h2><p>Return to the terminal.</p></body></html>"
        ))
      )
    }
    var logger = Logger(label: "cab-demo-callback")
    logger.logLevel = .error
    let app = Application(
      router: router,
      configuration: .init(address: .hostname("127.0.0.1", port: port)),
      logger: logger
    )
    let serverTask = Task { try await app.runService() }
    defer { serverTask.cancel() }

    var iterator = stream.makeAsyncIterator()
    guard let query = await iterator.next() else {
      throw ValidationError("callback listener ended without a request")
    }
    // Give the response a moment to flush before the listener dies.
    try await Task.sleep(nanoseconds: 500_000_000)
    return query
  }
}
```

- [ ] **Step 2: Build and smoke-test argument parsing**

```bash
cd Server && swift build --product petrel-cab-demo
swift run petrel-cab-demo login --help
```
Expected: builds; help text lists `--handle`, `--backend`, `--client-id`, `--redirect-uri`, `--callback-port`, `--scope`. (Full-flow verification is Task 16 — it needs live tunnels.)

- [ ] **Step 3: Commit**

```bash
cd .. && git add Server
git commit -m "cab-server: petrel-cab-demo — full CAB login flow driver with callback listener"
```

---

### Task 15: Docs sync — spec correction, CLAUDE.md pointer, Kotlin follow-up

**Files:**
- Modify: `docs/superpowers/specs/2026-07-08-client-assertion-backend-design.md` (Part 5 — the capstone-e2e paragraph)
- Modify: `CLAUDE.md` (repo root — add a pointer under the architecture/docs area)
- Modify: `docs/cab-backend-contract.md` (add the AS-constraints note)

**Interfaces:** none — documentation truthing.

- [ ] **Step 1: Correct the spec's e2e paragraph**

In the spec's Part 5 capstone-e2e bullet, replace the phrase `demo CLI uses a loopback redirect as a native client` with `demo CLI is registered as an application_type "web" client with an https redirect URI served through a second tunnel (the AS rejects native + private_key_jwt until the upstream proposal is adopted; loopback redirects are native-only)`.

- [ ] **Step 2: Append the AS-constraints note to the contract doc**

Add at the end of `docs/cab-backend-contract.md`'s Notes section:

```markdown
- @atproto/oauth-provider constraints (verified 2026-07): confidential
  clients must publish `application_type: "web"` with https redirect URIs;
  assertion `iat` must be within 60 s (CLIENT_ASSERTION_MAX_AGE); the AS pins
  the client-auth key (`kid`/`alg`/`jkt`) per session at initial issuance, so
  backend key rotation revokes all existing sessions (`invalid_grant` on
  refresh) — that is the intended mass-revocation mechanism.
```

- [ ] **Step 3: Add pointers to Petrel's CLAUDE.md**

In `CLAUDE.md` (repo root), under the "Overview" section, append:

```markdown
## CAB Server (Server/)

`Server/` is an independent SPM package (NOT part of the Petrel library):
`petrel-cab-server`, a client-assertion backend implementing
`docs/cab-backend-contract.md` for `AuthMode.cab`. Build/test it from
`Server/` (`cd Server && swift test`). The Petrel SDK must never depend on it.
Kotlin parity for `AuthMode.cab` v2 (aud + PAR assertion) is an open
follow-up — the Kotlin client still implements the v1 contract.
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-07-08-client-assertion-backend-design.md docs/cab-backend-contract.md CLAUDE.md
git commit -m "docs: sync spec/contract/CLAUDE.md with verified AS constraints"
```

---

### Task 16: End-to-end verification against real authorization servers

**Files:**
- Create: `docs/superpowers/plans/2026-07-08-client-assertion-backend-e2e-results.md` (evidence)
- Create (transient, not committed): `/tmp` configs and tunnel logs

**Interfaces:**
- Consumes: everything. Test accounts from `../.env` (`TEST_ACCOUNT_2_USERNAME`/`_PASSWORD` on bsky.social; `TEST_ACCOUNT_3_USERNAME`/`_PASSWORD`/`_PDS` on `https://joshpds.duckdns.org`).
- Produces: the plan's done-criteria — `E2E RESULT: PASS` against BOTH a bsky.social account and the self-hosted PDS account, with evidence committed.

This is interactive (a real browser login) — run it with the user present or drive the login form with browser automation. Never print passwords; source them from `../.env`.

Headless fallback (verified in the oauth-provider source): the authorize UI's own backend is scriptable — `POST {issuer}/@atproto/oauth-provider/~api/sign-in` with JSON `{locale, username, password, remember?}` plus self-set `Origin`/`Referer`/`Sec-Fetch-Mode: same-origin`/`Sec-Fetch-Site: same-origin` headers and the device cookie from first GETting the authorize URL, then `POST …/~api/consent`. Those guards are browser anti-CSRF, not a bot barrier. Use only if interactive login is impractical.

Timing note: the AS caches fetched client metadata and JWKS for 10 minutes — if you edit `client_metadata` mid-run (not needed in the steps below), expect staleness.

- [ ] **Step 1: Install cloudflared (not currently installed)**

```bash
brew install cloudflared
```

- [ ] **Step 2: Start two quick tunnels (backend + callback) and capture their URLs**

```bash
cloudflared tunnel --url http://127.0.0.1:8080 > /tmp/cab-tunnel-server.log 2>&1 &
cloudflared tunnel --url http://127.0.0.1:8378 > /tmp/cab-tunnel-callback.log 2>&1 &
sleep 8
SERVER_TUNNEL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cab-tunnel-server.log | head -1)
CALLBACK_TUNNEL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cab-tunnel-callback.log | head -1)
echo "server: $SERVER_TUNNEL  callback: $CALLBACK_TUNNEL"
```
Expected: two distinct `https://….trycloudflare.com` URLs. (Quick tunnels need no Cloudflare account.)

- [ ] **Step 3: Generate a key and write the e2e config**

```bash
cd Server
swift run petrel-cab-server generate-key --kid e2e-key-1 | sed -n '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/p' > /tmp/cab-e2e-key.pem
cat > /tmp/cab-e2e-config.json <<EOF
{
  "client_id": "$SERVER_TUNNEL/oauth-client-metadata.json",
  "public_url": "$SERVER_TUNNEL",
  "host": "127.0.0.1",
  "port": 8080,
  "keys": [{ "kid": "e2e-key-1", "pem_path": "/tmp/cab-e2e-key.pem" }],
  "active_kid": "e2e-key-1",
  "client_metadata": {
    "client_id": "$SERVER_TUNNEL/oauth-client-metadata.json",
    "client_name": "Petrel CAB E2E",
    "application_type": "web",
    "grant_types": ["authorization_code", "refresh_token"],
    "response_types": ["code"],
    "redirect_uris": ["$CALLBACK_TUNNEL/callback"],
    "scope": "atproto transition:generic",
    "token_endpoint_auth_method": "private_key_jwt",
    "token_endpoint_auth_signing_alg": "ES256",
    "jwks_uri": "$SERVER_TUNNEL/.well-known/jwks.json",
    "dpop_bound_access_tokens": true
  }
}
EOF
```

- [ ] **Step 4: Run the server and verify public reachability**

```bash
swift run petrel-cab-server serve --config /tmp/cab-e2e-config.json > /tmp/cab-e2e-server.log 2>&1 &
sleep 3
curl -sf "$SERVER_TUNNEL/oauth-client-metadata.json" | jq -e '.token_endpoint_auth_method == "private_key_jwt"'
curl -sf "$SERVER_TUNNEL/.well-known/jwks.json" | jq -e '.keys[0].kid == "e2e-key-1"'
```
Expected: both `jq -e` checks print `true`. This is what the AS will fetch.

- [ ] **Step 5: Run the demo against bsky.social (TEST_ACCOUNT_2)**

```bash
set -a; source ../../.env; set +a
swift run petrel-cab-demo login \
  --handle "$TEST_ACCOUNT_2_USERNAME" \
  --backend "$SERVER_TUNNEL" \
  --client-id "$SERVER_TUNNEL/oauth-client-metadata.json" \
  --redirect-uri "$CALLBACK_TUNNEL/callback" \
  --callback-port 8378
```
Complete the browser login with `TEST_ACCOUNT_2_USERNAME`'s credentials (from `.env`; never echo the password).
Expected terminal output ends with `E2E RESULT: PASS — handle=j0sh.bsky.social …`. Also check `/tmp/cab-e2e-server.log` for two-plus `assertion minted` lines (PAR + token exchange + refresh) with `aud=https://bsky.social`.

- [ ] **Step 6: Repeat against the self-hosted PDS (TEST_ACCOUNT_3)**

```bash
swift run petrel-cab-demo login \
  --handle "$TEST_ACCOUNT_3_USERNAME" \
  --backend "$SERVER_TUNNEL" \
  --client-id "$SERVER_TUNNEL/oauth-client-metadata.json" \
  --redirect-uri "$CALLBACK_TUNNEL/callback" \
  --callback-port 8378
```
Expected: `E2E RESULT: PASS`, and the server log now shows `aud=` values for the joshpds issuer — proving per-PDS `aud` handling. If joshpds runs an older PDS that rejects anything, record the exact error and stop to discuss rather than hacking around it.

- [ ] **Step 7: Negative check — veto power**

The step 6 login left a live session in the demo's keychain namespace. First prove the refresh path works, then prove the backend can veto it:

```bash
swift run petrel-cab-demo refresh \
  --backend "$SERVER_TUNNEL" \
  --client-id "$SERVER_TUNNEL/oauth-client-metadata.json" \
  --redirect-uri "$CALLBACK_TUNNEL/callback"
# → REFRESH RESULT: PASS. Note the `jkt` logged in /tmp/cab-e2e-server.log for this call.
```

Add that `jkt` to `denied_jkts` in `/tmp/cab-e2e-config.json`, restart the server (`kill` the serve job, re-run step 4's serve command), and re-run the same `refresh` command.
Expected: `REFRESH RESULT: FAIL — …clientAssertionBackendError(403, …access_denied…)` and a `device refused` line in the server log — the proposal's veto property, observed end-to-end.

- [ ] **Step 8: Write the evidence doc, clean up, commit**

Write `docs/superpowers/plans/2026-07-08-client-assertion-backend-e2e-results.md` with: date, cloudflared URLs used (they're dead after teardown — safe to record), the two `E2E RESULT: PASS` lines verbatim, redacted server-log excerpts showing `assertion minted` for both `aud` values, the veto observation from step 7, and any deviations encountered.

```bash
kill %1 %2 %3 2>/dev/null   # server + both tunnels
cd .. && git add docs/superpowers/plans/2026-07-08-client-assertion-backend-e2e-results.md
git commit -m "docs: CAB e2e verification results — bsky.social + self-hosted PDS"
```

---

## Execution order & parallelism

Tasks 1→4 (Petrel) are strictly sequential. Tasks 5→12 (server) are sequential among themselves but independent of Petrel Tasks 2–4 after Task 1 lands. Task 13 needs Tasks 3 + 11. Task 14 needs Tasks 4 + 11. Task 16 needs everything. Suggested single-worker order: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16.





