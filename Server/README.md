# Petrel CAB Server

## What it is

The Petrel CAB (Client Assertion Backend) server implements the [client-assertion-backend pattern](https://github.com/bluesky-social/atproto-oauth-spec/blob/main/client-assertion-backend.md) for ATProto OAuth. Instead of a native client holding secrets (the OAuth Authorization Server's traditional assumption), the CAB server is a confidential backend that holds the client's private key and mints short-lived assertions on behalf of mobile or browser clients. This is documented in detail in [`../docs/cab-backend-contract.md`](../docs/cab-backend-contract.md).

This architecture decouples OAuth credential lifecycle from app distribution. A native app never holds long-lived secrets or proof-of-possession keys — only the backend does. Sessions can be revoked en masse (by rotating the signing key) or per-device (by denying a specific key material's JKT), and tokens are never stored server-side: each assertion is verified by the AS directly.

## Quickstart

Generate a signing key:

```bash
cd Server
swift run petrel-cab-server generate-key --kid cab-key-1
```

Copy the PEM output to `keys/cab-key-1.pem`. Then copy and edit the config:

```bash
cp config.example.json config.json
# Edit config.json to set client_id and public_url to your URLs
```

Start the server:

```bash
swift run petrel-cab-server serve --config config.json
```

Verify it works:

```bash
curl -s http://127.0.0.1:8080/health                        # → OK
curl -s http://127.0.0.1:8080/.well-known/jwks.json | jq .  # → JWKS document
```

## Using it from Petrel

In your Petrel client, configure OAuth with the CAB backend:

```swift
let client = try await ATProtoClient(
  oauthConfig: myOAuthConfig,
  namespace: "my-app",
  authMode: .cab(backendURL: URL(string: "https://cab.example.com")!)
)
```

The `client_id` in your `OAuthConfig` must match the backend's `client_id` field (both must be the full https metadata URL).

## Configuration reference

All fields in `config.example.json` can be overridden by environment variables:

| Field | Default | Meaning | Env Override |
|-------|---------|---------|--------------|
| `client_id` | required | Full https URL to your client metadata document (no trailing slash) | `CAB_CLIENT_ID` |
| `public_url` | required | External https URL the AS will use to fetch your metadata and JWKS | `CAB_PUBLIC_URL` |
| `host` | `127.0.0.1` | Bind address for the server | `CAB_HOST` |
| `port` | `8080` | Bind port | `CAB_PORT` |
| `keys` | required | Array of signing keys; each has `kid` and `pem_path` | `CAB_KEY_PEM_BASE64` (for inline key) and `CAB_KEY_KID` |
| `active_kid` | required | Which `kid` to use for new assertions | `CAB_ACTIVE_KID` |
| `allowed_origins` | `[]` | CORS whitelist; browser clients must have their Origin listed here; empty list rejects all requests with an Origin header, but requests without Origin (native apps, curl) pass unless `require_origin` is true | `CAB_ALLOWED_ORIGINS` (comma-separated) |
| `require_origin` | `false` | If true, reject requests without Origin header | (none) |
| `aud_allowlist` | `null` | If set, only mint assertions for these ATProto server URLs | (none) |
| `assertion_ttl_seconds` | `60` | How long assertions remain valid (AS enforces 60s max) | (none) |
| `iat_window_seconds` | `300` | Allowable clock skew for assertion `iat` (±5 minutes) | (none) |
| `require_nonce` | `false` | If true, require and validate nonce in requests | `CAB_REQUIRE_NONCE` |
| `nonce_secret_base64` | `null` | Base64-encoded shared secret for nonce validation; if not set with `require_nonce: true`, each process generates a random secret (nonces will fail across restarts or load-balanced instances) | `CAB_NONCE_SECRET_BASE64` |
| `denied_jkts` | `[]` | List of JKT values to rate-limit or reject | `CAB_DENIED_JKTS` (comma-separated) |
| `rate_limit.requests_per_minute` | `60` | Per-JKT rate limit | (none) |
| `client_metadata.*` | (embedded) | OAuth client metadata served at `client_id` URL; see OAuth metadata spec | (none) |

To use `CAB_KEY_PEM_BASE64`: base64-encode your PEM file and pass the string; the server will decode and load it in memory rather than from disk.

## Key rotation = mass session revocation

The ATProto Authorization Server pins the client's key material (`kid`/`alg`/`jkt`) per session at initial token issuance. When you refresh a token, the AS checks that the refresh request is signed with the same key. If the signing key changes, the AS rejects the refresh with `invalid_grant` and the user must re-login.

Therefore, changing `active_kid` deliberately revokes every existing session — this is the proposal's mass-revocation lever. It is not a gentle rotation. Use this when:

- A signing key is compromised and must be retired immediately
- You need to force all users back through OAuth (e.g., to re-consent to new scopes)
- You are rotating keys as part of your security hygiene

After rotating `active_kid`, you can remove the old key from the `keys` array once assertions signed with it expire (default 60 seconds). Keep superseded keys listed for a brief window so assertions minted seconds before the switch still verify.

## AS constraints today

The Bluesky ATProto Authorization Server (as of 2026-07) has these constraints, verified against the upstream `@atproto/oauth-provider` implementation:

- **Application type and redirects**: `application_type` MUST be `"web"`, and every redirect URI MUST use `https`. Native clients with any authentication method other than `none` are rejected (this restriction will lift once the client-assertion-backend proposal is adopted upstream). `http://localhost` or custom-scheme redirects are not supported.
- **Assertion timing**: Client assertions must have `iat` (issued-at) within 60 seconds of the server's clock. Keep server clocks NTP-synced.
- **Key binding** (not yet enforced): The `cnf` and `jkt` claim bindings in assertions are validated structurally but not yet enforced; forward-compatible assertions include them anyway.
- **Metadata fetching**: The AS fetches your `client_id` and `jwks_uri` URLs through an SSRF-guarded client: requests must use `https` on the standard port, no IP-literal hosts, body ≤512 kB, and redirects are rejected. Metadata is cached for **10 minutes**, so changes take time to propagate.
- **Metadata format**: Both documents must be served with `Content-Type: application/json`. The `client_id` URL must have a non-root path (e.g., `/oauth-client-metadata.json`) and no trailing slash.

## Security model

The CAB server is an open endpoint by design:

- **No authentication on the assertion endpoint**: Any client can request an assertion; the AS verifies the signature.
- **DPoP-bound**: Assertions are bound to the requester's DPoP key via the `cnf` claim. An attacker who intercepts an assertion cannot use it without the DPoP key.
- **Rate limiting and deny list**: The server rate-limits per JKT (DPoP public key hash) and supports a deny list for compromised keys. Combine these to mitigate flooding or key leaks.
- **No token custody**: The server does not store tokens, refresh tokens, or user state. The client presents a valid assertion to the AS, which returns tokens directly. This minimizes the server's attack surface.
- **Hardening knobs** (optional): Set `require_nonce` and `aud_allowlist` to further restrict who can mint assertions. Use these if you operate a private network or want to gate access. **Important**: If you enable `require_nonce` without setting a shared `nonce_secret_base64`, each process/restart generates a random secret and nonces silently stop validating. Production deployments using nonce validation MUST set a stable shared secret via `CAB_NONCE_SECRET_BASE64` and share it across all instances and restarts.
- **Run behind TLS**: The server itself does not serve TLS. Run it behind a reverse proxy (nginx, cloudflare, etc.) with `public_url` set to the external URL. This ensures the AS and clients communicate over encrypted channels.

## Deployment

### Docker

Build the image from the Petrel repository root (the path dependency in `Package.swift` requires it):

```bash
docker build -f Server/Dockerfile -t petrel-cab-server .
```

Run it:

```bash
docker run -it --rm \
  -p 8080:8080 \
  -v $(pwd)/config.json:/etc/cab/config.json \
  -v $(pwd)/keys:/etc/cab/keys:ro \
  petrel-cab-server serve --config /etc/cab/config.json
```

### systemd

Copy `petrel-cab-server` binary to `/opt/petrel-cab-server/` and `config.json` + `keys/` alongside it:

```bash
sudo mkdir -p /opt/petrel-cab-server/keys
sudo cp Server/.build/release/petrel-cab-server /opt/petrel-cab-server/
sudo cp config.json /opt/petrel-cab-server/
sudo cp keys/*.pem /opt/petrel-cab-server/keys/
sudo chown -R cab:cab /opt/petrel-cab-server
sudo chmod 600 /opt/petrel-cab-server/keys/*.pem
```

Install the systemd unit:

```bash
sudo cp Server/deploy/petrel-cab-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable petrel-cab-server
sudo systemctl start petrel-cab-server
```

Check status:

```bash
sudo systemctl status petrel-cab-server
sudo journalctl -u petrel-cab-server -f
```
