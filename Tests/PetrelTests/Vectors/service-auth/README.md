# Service-auth interop vectors

Cross-implementation evidence for inter-service authentication JWTs
(XRPC specification, "Inter-Service Authentication (JWT)"). Everything here is
read by `Tests/PetrelTests/ServiceAuth/ServiceAuthInteropTests.swift` through
`Bundle.module`.

## Files

| File | What it is | Produced by |
|---|---|---|
| `service-jwt-vectors.json` | 63 tokens minted by the TypeScript reference implementation, by OpenSSL and by `jose`, each with the verdict of the reference `verifyJwt` | `generate-ts-vectors.mjs` |
| `petrel-minted-tokens.json` | 16 tokens minted by Petrel (`ServiceJWT.mint`), 8 per curve | the Swift test `writeMintedTokens` |
| `petrel-minted-tokens.verified-by-ts.json` | What the reference `verifyJwt`, strict `@atproto/crypto`, OpenSSL and `jose` said about those 16 tokens | `verify-petrel-tokens.mjs` |
| `syntax/{did,nsid}_syntax_{valid,invalid}.txt` | Official syntax vectors, copied unmodified | `bluesky-social/atproto-interop-tests`, `syntax/` (CC0) |

## What the reference vectors cover

`service-jwt-vectors.json` was generated with the published reference packages
(versions are recorded in the file's `generator` object: `@atproto/xrpc-server`
0.13.11, `@atproto/crypto` 0.5.7, `jose` 6.2.17, Node 22). Each vector records:

- `token`: the compact JWT;
- `source`: who signed it — `createServiceJwt` (the reference minter),
  `node:crypto` (OpenSSL, which does not normalize S), `jose` (WebCrypto), or a
  hand-built header or payload signed with the reference keypair;
- `highS`: whether the signature's S is above n/2;
- `verifier`: how the receiving service is configured — its own DID
  (`audience`), the endpoint (`lxm`), the key its cache holds (`key`) and the
  key a forced refresh returns (`refreshedKey`, different after a rotation);
- `ts`: what `verifyJwt(token, audience, lxm, getSigningKey)` did at the
  pinned clock (`now`, 1 700 000 000): the returned payload, or the XRPC error
  name and message, plus every `getSigningKey` call it made;
- `petrel` (only where Petrel deliberately differs): Petrel's verdict, the
  reason, and the configuration under which Petrel accepts the token.

Both curves get the same cases: tokens with and without `lxm`; 60 second,
30 minute (what the official app requests for `com.atproto.repo.uploadBlob`),
one hour and two hour lifetimes; high-S and low-S signatures; a key rotation;
a wrong key; expired, wrong-audience and wrong-method tokens; `typ` values
`at+jwt`, `refresh+jwt` and `dpop+jwt`; `kid` headers; a legacy
`did#service` issuer; `alg` mismatches; malformed payloads.

The fixed private keys in the file are SHA-256 of a label string. They exist
only for these vectors.

### Deliberate differences

Four kinds of token are accepted by the reference verifier and refused by
Petrel's default configuration. Each is accepted when the option named in
`petrel.okWith` is set, and a test asserts that.

| Vector | Reference | Petrel default | Why |
|---|---|---|---|
| `*-der` | accepted | `BadJwt` | A JWS signature is 64-byte `r‖s` (RFC 7518 §3.4). `allowMalleableSig` in `@atproto/crypto` also admits ASN.1 DER; Petrel does only with `signatureOptions = .allowMalleable`. |
| `*-2h` | accepted | `BadJwt` | Petrel caps accepted lifetime at one hour, the most a reference PDS issues. `maximumLifetime` raises it. |
| `*-kid-other` | accepted | `BadJwt` | The specification says receivers "must only accept specific key types"; the reference verifier does not read `kid` yet. `acceptedKeyIDs` opts in. |
| `*-duplicate-claim` | accepted | `BadJwt` | `JSON.parse` keeps the last duplicate member; Petrel refuses ambiguous JSON. Not configurable. |

## Regenerating

Node.js 22 and network access to the npm registry are needed. Nothing is
installed into this repository.

```sh
mkdir -p /tmp/ts-interop && cd /tmp/ts-interop
npm init -y >/dev/null && npm install @atproto/xrpc-server @atproto/crypto jose
VECTORS=<repo>/Tests/PetrelTests/Vectors/service-auth

# 1. Reference -> Petrel
node $VECTORS/generate-ts-vectors.mjs $VECTORS/service-jwt-vectors.json

# 2. Petrel -> reference (run from the repository root)
PETREL_SERVICE_AUTH_WRITE_TOKENS=$VECTORS/petrel-minted-tokens.json \
  swift test --filter ServiceAuthInteropTests
cd /tmp/ts-interop
node $VECTORS/verify-petrel-tokens.mjs \
  $VECTORS/petrel-minted-tokens.json \
  $VECTORS/petrel-minted-tokens.verified-by-ts.json
```

`jti` values are random and P-256 signatures from Swift Crypto are randomized,
so regenerated files differ byte-for-byte from the committed ones while
describing the same cases.

## Live round trip

The committed files are a snapshot. To have the test suite mint fresh tokens
with fresh random keys and verify them in the TypeScript reference in a child
process, point it at the directory holding `node_modules`:

```sh
PETREL_TS_INTEROP_DIR=/tmp/ts-interop swift test --filter ServiceAuthInteropTests
```

Without that variable the live test is skipped and the snapshot tests still
run.
