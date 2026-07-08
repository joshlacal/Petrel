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
- @atproto/oauth-provider constraints (verified 2026-07): confidential
  clients must publish `application_type: "web"` with https redirect URIs;
  assertion `iat` must be within 60 s (CLIENT_ASSERTION_MAX_AGE); the AS pins
  the client-auth key (`kid`/`alg`/`jkt`) per session at initial issuance, so
  backend key rotation revokes all existing sessions (`invalid_grant` on
  refresh) — that is the intended mass-revocation mechanism.
