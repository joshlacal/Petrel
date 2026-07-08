# Client Assertion Backend — Petrel CAB completion + reference server

**Date:** 2026-07-08
**Status:** Approved design, pre-implementation
**Basis:** Bluesky proposal "Client assertion backend for browser-based applications" (Devin Ivy / Matthieu Sieben, June 2025) — RFC 7523 client assertions bound to the session DPoP key via `cnf`/`jkt`.

## Goal

Make Petrel's existing-but-broken Client Assertion Backend auth mode (`AuthMode.cab`) fully functional, and ship a small, easily configurable reference server (`petrel-cab-server`) that anyone can deploy to turn a Petrel-based app into a confidential OAuth client — without token custody or session state on the server.

**Primary consumers:** Petrel users. Catbird stays on gateway (nest) mode; migrating it is explicitly out of scope.

## Context & findings (2026-07-08)

- `CABOAuthStrategy.swift` (638 lines) already exists on Petrel main, with `AuthMode.cab(backendURL:)`. It fetches a DPoP-bound assertion from `POST {backend}/oauth/client-assertion` and injects it into token exchange and refresh. The lost Swift TMB server predating it was confirmed unrecoverable; this project supersedes it with the lighter assertion-backend pattern.
- **Fatal gap:** the PAR request omits the client assertion. `@atproto/oauth-provider` authenticates confidential clients at PAR (`pushedAuthorizationRequest` → `authenticateClient`), so the current CAB flow fails at the first request against real `private_key_jwt` client metadata.
- **Contract gap:** the assertion's `aud` must be the user's AS issuer (varies per PDS), but the current fetch sends an empty body — the backend cannot know what `aud` to mint.
- **AS support status** (verified against `atproto/` checkout @ 2026-07-06): plain RFC 7523 `private_key_jwt` works today (nest authenticates this way in production). The proposal's `cnf`/`jkt` *enforcement* on client assertions is **not yet implemented** upstream — `cnf.jkt` is only validated on access tokens. Unknown claims are ignored, so including `cnf` now is harmless and forward-compatible; the backend enforces binding semantics on its side meanwhile, and retains veto power over every refresh regardless.
- AS constraints to respect: `jti` is required and replay-checked per request (fresh assertion per PAR/token/refresh call); the DPoP proof key MUST differ from the assertion signing key (satisfied by design: device signs proofs, server signs assertions); `kid` header required.

## Part 1 — Wire contract (v2)

This contract is the seam between Petrel and any backend implementation. It lands as a spec doc in `docs/` and both sides implement against it.

```
POST {backend}/oauth/client-assertion
DPoP: <proof: htm=POST, htu=endpoint URL, signed by the session's DPoP key>
Content-Type: application/x-www-form-urlencoded

aud=<authorization server issuer URL>          # required — NEW in v2
```

Success `200` (`Cache-Control: no-store`, CORS headers):

```json
{ "client_id": "https://…/oauth-client-metadata.json", "client_assertion": "eyJ…" }
```

Assertion JWT: ES256, `kid` header; claims `iss` = `sub` = client_id, `aud` = requested issuer, unique `jti`, `iat`, `exp` = `iat` + 60s (configurable), `cnf: { "jkt": <RFC 7638 thumbprint of the DPoP proof's key> }`.

Errors (OAuth-style `{"error", "error_description"}` JSON):

| Status | `error` | Meaning / client behavior |
|---|---|---|
| 400 | `use_dpop_nonce` | `DPoP-Nonce` header present; client retries **once** with the nonce |
| 400 | `invalid_dpop_proof` | Proof failed validation; hard failure |
| 400 | `invalid_request` | Missing/malformed `aud`, or `aud` not in allowlist |
| 403 | `access_denied` | Device (`jkt`) refused by policy |

## Part 2 — Petrel changes (all in existing files; no public API breaks)

1. `OAuthCore.pushAuthorizationRequest(...)` gains `additionalParameters: [String: String]? = nil`, merged into the PAR body. Callers: `PublicOAuthStrategy` (passes nothing), `CABOAuthStrategy` (passes assertion params).
2. `CABOAuthStrategy` fetches a **fresh** assertion before PAR and passes `client_assertion` + `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`. Fresh-per-call is mandatory (AS `jti` replay check); exchange/refresh already fetch per-call.
3. `fetchClientAssertion` gains an `aud` parameter (form-encoded body) and a single-retry handler for the backend's `use_dpop_nonce` challenge. A second nonce challenge is a hard failure.
4. Token exchange and refresh pass `aud` (= `AuthorizationServerMetadata.issuer`); otherwise unchanged.
5. Backend errors surface as typed `AuthError` cases — never swallowed into generic network errors.
6. `startOAuthFlowForSignUp` continues to throw in CAB mode (out of scope).

## Part 3 — Reference server: `petrel-cab-server`

**Location:** `Server/` directory inside the Petrel repo as an **independent SPM package** (own `Package.swift`; the Petrel SDK gains zero dependencies).
**Stack:** Hummingbird 2 (HTTP), jose-swift (same JOSE library Petrel uses client-side), swift-crypto, swift-log, swift-argument-parser.

### Endpoints

- `POST /oauth/client-assertion` — core (Part 1 contract)
- `GET /.well-known/jwks.json` — public keys for the AS
- `GET /oauth-client-metadata.json` — optional (config toggle); one deploy = one fully-functioning confidential client
- `GET /health`

### DPoP proof validation pipeline (each step a testable unit)

parse compact JWS → require `typ: "dpop+jwt"`, `alg: ES256`, embedded public EC/P-256 `jwk` with no private members → verify signature with embedded key → `htm == "POST"` → `htu` == endpoint under configured `public_url` (never trust `Host` behind a proxy) → `iat` within freshness window (default ±300s) → `jti` not replayed (in-memory TTL store, pruned) → optional server nonce (stateless HMAC-over-timestamp, config toggle, default off) → compute RFC 7638 `jkt` → device policy check → mint.

### Device tracking & refusal (the proposal's veto power)

`DeviceStore` protocol seam. v1: in-memory per-`jkt` first-seen/last-seen/count with structured logging + `denied_jkts` config list for refusals. SQLite persistence is a documented v2 behind the same protocol.

### Key management

Config points at one or more P-256 PEM files (or base64 env var) with `active_kid` — active key signs; **all** public keys serve in JWKS so rotation doesn't orphan in-flight assertions. `petrel-cab-server generate-key` mints a key and prints PEM + public JWK.

### Configuration

Single JSON config file (Codable, zero extra deps) + env-var overrides for essentials (`PORT`, `PUBLIC_URL`, `CLIENT_ID`, key paths, origins). Fields: `client_id`, `public_url`, `port`, keys + `active_kid`, `allowed_origins` (CORS: browser requests must match; native requests without `Origin` pass unless `require_origin`), optional `aud_allowlist` (default any `https` issuer), `assertion_ttl` (default 60s), `iat_window`, `require_nonce`, `denied_jkts`, optional inline client-metadata document, per-IP/per-`jkt` rate limits.

### Distribution

Dockerfile (multi-stage build → slim runtime), example systemd unit, README quickstart: generate key → 10-line config → point client metadata `jwks_uri` at the server → done.

## Part 4 — Security posture

- Assertions: 60s TTL, single audience, unique `jti`, `cnf`-bound → tiny theft window even before AS-side enforcement.
- Device DPoP key and server assertion key never cross (AS rejects same-key anyway).
- `htu` validated against configured `public_url` — a proof minted for another deployment can't replay here.
- Endpoint stays open per the proposal; mitigations: DPoP binding, rate limits, device policy. Extra auth is a documented extension point, not v1.
- No token custody, no session state. Server compromise exposes signing keys only; key rotation + JWKS update revokes en masse (the proposal's recovery story).

## Part 5 — Testing & verification

- **Server unit tests** (Swift Testing): proof-validation matrix (wrong `htm`/`htu`/`alg`, bad signature, private-key-bearing `jwk`, stale `iat`, replayed `jti`, denied `jkt`, disallowed `aud`, nonce challenge/retry), assertion-claims correctness, JWKS shape, metadata toggle, CORS.
- **Petrel unit tests**: PAR/token/refresh bodies carry fresh assertion + correct `aud`; backend nonce retry; typed error surfacing.
- **Integration**: spawn the real server in-process; drive Petrel's actual `CABOAuthStrategy` fetch path against it.
- **Capstone e2e** (against real authorization servers, using the workspace's e2e test accounts in `../.env` — `TEST_ACCOUNT_1..4`): a small demo CLI completes an actual login — PAR with assertion → authorize (interactive/browser-automated login with test-account credentials) → token exchange → refresh → authenticated XRPC call. Run against **both** bsky.social (`TEST_ACCOUNT_1/2`) and the self-hosted PDS `joshpds.duckdns.org` (`TEST_ACCOUNT_3`) to exercise per-PDS `aud` handling. Constraint: the AS must be able to fetch the client metadata doc and JWKS, so the server runs locally behind a `cloudflared` quick tunnel (temporary public https URL; server serves its own metadata + JWKS); demo CLI is registered as an application_type "web" client with an https redirect URI served through a second tunnel (the AS rejects native + private_key_jwt until the upstream proposal is adopted; loopback redirects are native-only). `atproto/packages/dev-env` remains an optional fallback if a fully-local run is ever needed. Done-criteria per workspace CLAUDE.md: observable end-to-end behavior, not just green tests.

## Out of scope

- Catbird migration off gateway mode (separate later project; zero Catbird changes required by this work).
- Kotlin client parity (tracked follow-up).
- `startOAuthFlowForSignUp` in CAB mode.
- SQLite `DeviceStore`, additional endpoint authentication (documented v2 extension points).
- nest changes (nest remains a full TMB; unaffected).
