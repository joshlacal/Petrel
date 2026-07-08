# Client Assertion Backend — E2E Verification Results

**Date:** 2026-07-08
**Scope:** Live end-to-end verification of the Petrel CAB client + `petrel-cab-server`
reference server against a real ATProto authorization server, per Task 16 of
`2026-07-08-client-assertion-backend.md`.

## Environment

- **Server + demo built** from the reviewed branch head with the Xcode-beta
  matched toolchain (`env -u SDKROOT -u TOOLCHAINS …/XcodeDefault.xctoolchain/usr/bin/swift`).
- **Public exposure:** two `cloudflared` quick tunnels (dead after teardown, safe to record):
  - server: `https://mount-crystal-keep-brakes.trycloudflare.com`
  - callback: `https://surgery-closed-extending-distributor.trycloudflare.com`
- **Server config:** `application_type: "web"`, `token_endpoint_auth_method: "private_key_jwt"`,
  ES256, `dpop_bound_access_tokens: true`, single active key `e2e-key-1`.
- **Public reachability confirmed** before login — the AS-facing endpoints returned the
  expected documents through the tunnel:
  - `GET /oauth-client-metadata.json` → `token_endpoint_auth_method == "private_key_jwt"` ✓
  - `GET /.well-known/jwks.json` → `keys[0].kid == "e2e-key-1"` ✓ (public key only; no `d`)

## Result summary

| Scenario | Outcome |
|----------|---------|
| bsky.social login (full OAuth via CAB) | ✅ **PASS** |
| bsky.social forced token refresh | ✅ **PASS** |
| Backend veto of refresh (denied `jkt`) | ✅ **PASS** (refused as designed) |
| Self-hosted PDS (joshpds.duckdns.org) login | ⛔ **BLOCKED** — PDS unreachable (infrastructure, not CAB code) |

The plan's done-criteria call for `E2E RESULT: PASS` against **both** bsky.social
and the self-hosted PDS. bsky.social passed fully, including the veto property;
the self-hosted PDS could not be exercised because the host was down at test time
(see Deviations). The CAB client↔server contract itself is proven end-to-end against
a real, unmodified ATProto AS.

## Evidence

### bsky.social — full login (PASS)

Demo terminal output (final line):

```
E2E RESULT: PASS — handle=j0sh.bsky.social did=did:plc:34x52srgxttjewbke5hguloh
```

The flow printed all five stages: authorize URL issued, callback received on
`127.0.0.1:8378`, token exchange complete, authenticated session
(`j0sh.bsky.social` / `did:plc:34x52srgxttjewbke5hguloh`), forced refresh + re-verify.

Server log — assertions minted with the correct `aud`, one per protocol step
(PAR, token exchange, refresh), all bound to the device's DPoP key thumbprint
(`request.id` redacted):

```
aud=https://bsky.social jkt=pZBDwPWd…LE3onY [PetrelCABServerCore] assertion minted   # PAR
aud=https://bsky.social jkt=pZBDwPWd…LE3onY [PetrelCABServerCore] assertion minted   # token exchange
aud=https://bsky.social jkt=pZBDwPWd…LE3onY [PetrelCABServerCore] assertion minted   # login-time refresh
```

`aud=https://bsky.social` confirms the client sends the requested-issuer audience
and the server mints for it; the shared `jkt` across all mints confirms every
assertion is bound to the one device key (`cnf.jkt`), as the proposal requires.

### Backend veto of refresh (PASS — the proposal's key property)

Step 7a — refresh with the device allowed:

```
REFRESH RESULT: PASS            (exit 0)
aud=https://bsky.social jkt=pZBDwPWd…LE3onY assertion minted
```

Step 7b — the same device `jkt` added to `denied_jkts`, server restarted, identical
refresh re-run:

```
REFRESH RESULT: FAIL — clientAssertionBackendError(403, Optional("access_denied"))   (exit 1)
```

Server log for the vetoed attempt:

```
warning … jkt=pZBDwPWd…LE3onY [PetrelCABServerCore] device refused
notice  … detail=device refused by policy error=access_denied [PetrelCABServerCore] assertion refused
```

This is the proposal's central guarantee observed end-to-end: the backend can
refuse to mint a client assertion for a specific device, and without a fresh
assertion the client's refresh cannot proceed — the AS never sees the refresh
because the assertion it requires is withheld. The refusal surfaces in Petrel as
the typed `AuthError.clientAssertionBackendError(403, "access_denied")`.

## Deviations

- **Self-hosted PDS (TEST_ACCOUNT_3 on `joshpds.duckdns.org`) was unreachable.**
  Every probe timed out at the 10 s limit with no response (`curl` write-out
  `%{http_code}` = `000`): `/xrpc/_health`, `/.well-known/oauth-protected-resource`,
  and `com.atproto.identity.resolveHandle` all failed identically. The demo's
  `login` for this account hung in handle/PDS-metadata resolution — *before* any
  CAB backend interaction — consistent with the PDS host being down, not with any
  fault in the CAB client or server. Per the plan's instruction ("record the exact
  error and stop to discuss rather than hacking around it"), this scenario was not
  forced. The per-PDS `aud` handling it was meant to exercise is nonetheless
  covered by the cross-package integration tests (Task 13) and is exercised for
  real against bsky.social above; re-running Step 6 once the PDS is back up is the
  only outstanding item.

## Reproduction

The transient config, key, and tunnel logs lived under `/tmp` and were removed at
teardown; the tunnels are dead. To re-run: rebuild the Server package, start two
`cloudflared` quick tunnels, generate a key, write the config against the tunnel
URLs (`application_type: "web"`, https redirect), and run `petrel-cab-demo login`
per Task 16 Steps 2–6.
