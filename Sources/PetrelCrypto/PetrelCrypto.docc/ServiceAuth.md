# Service Authentication

Mint inter-service JWTs, and authenticate the requests that carry them.

## Overview

Services in the AT Protocol network authenticate to each other with short-lived
JWTs signed by an account's (or a service's) atproto signing key. A PDS mints
one when it proxies a request to an AppView, feed generator or labeler; the
receiving service resolves the issuer's DID document, finds the key, and
verifies the signature, the audience and the endpoint the token is bound to.
The format is defined in the XRPC specification under
[Inter-Service Authentication](https://atproto.com/specs/xrpc#inter-service-authentication-jwt).

This module covers both directions:

- ``ServiceJWT`` mints tokens on either curve (`ES256` for P-256, `ES256K` for
  K-256) with any ``ATProtoSigner``.
- ``ServiceAuthVerifier`` takes an `Authorization` header and returns the
  verified caller, resolving the issuer's key through a
  ``ServiceAuthKeyResolver``.

Every snippet on this page is compiled and run by
`Tests/PetrelCryptoTests/ServiceAuthDocumentationTests.swift`.

## Mint a token

Sign with the key published in the issuer's DID document. `lexiconMethod`
(`lxm`) binds the token to one endpoint; `jti` is a fresh random nonce; the
lifetime defaults to the 60 seconds the specification recommends.

```swift
let keypair = K256Keypair.generate()

let token = try await ServiceJWT.mint(
    issuer: "did:plc:abcdefghijklmnopqrstuvwx",
    audience: "did:web:feed.example.com#bsky_fg",
    lexiconMethod: "app.bsky.feed.getFeedSkeleton",
    signer: keypair
)
let authorization = ServiceJWT.bearerAuthorization(token)   // "Bearer eyJ…"
```

The audience is the receiving service's DID followed by its service
identifier. ``ATProtoServiceReference`` builds and parses that string; it is
the same value the `atproto-proxy` header carries.

A service that signs with a key other than `#atproto` names it in the `kid`
header, and can ask for a longer lifetime, up to ``ServiceJWT/maximumLifetime``
(one hour):

```swift
let labelerToken = try await ServiceJWT.mint(
    issuer: "did:web:labeler.example.com",
    audience: "did:web:appview.example.com#bsky_appview",
    lexiconMethod: "com.atproto.label.queryLabels",
    signer: labelingKey,
    keyID: "#atproto_label",
    lifetime: 5 * 60
)
```

A client application does not hold the account's signing key. It asks its PDS
for a token instead; see `ATProtoClient.getServiceAuthToken` in the `Petrel`
module.

## Authenticate a request

A service creates one ``ServiceAuthVerifier`` and calls it from each
authenticated endpoint. This is the whole of request authentication for a feed
generator:

```swift
struct FeedGenerator {
    let verifier: ServiceAuthVerifier

    init(keyResolver: any ServiceAuthKeyResolver) {
        verifier = ServiceAuthVerifier(
            // This service's DID and service identifier. PDSes that predate
            // the Spring 2026 specification send the bare DID when proxying.
            audience: .service(did: "did:web:feed.example.com", id: "bsky_fg", acceptBareDID: true),
            keyResolver: keyResolver,
            replayStore: InMemoryServiceAuthReplayStore()
        )
    }

    /// GET /xrpc/app.bsky.feed.getFeedSkeleton
    func getFeedSkeleton(authorizationHeader: String?) async -> (status: Int, body: [String: String]) {
        do {
            let caller = try await verifier.verify(
                authorizationHeader: authorizationHeader,
                method: .exactly("app.bsky.feed.getFeedSkeleton")
            )
            return (200, ["viewer": caller.issuer])
        } catch {
            // 401 {"error": "BadJwtAudience", "message": "jwt audience does not match service did"}
            return (error.httpStatus, ["error": error.xrpcErrorName, "message": error.message])
        }
    }
}
```

`verify` performs, in order:

1. **Decoding.** Three base64url segments, a duplicate-free JSON header and
   payload, and none of the token types that are not service tokens
   (`at+jwt`, `refresh+jwt`, `dpop+jwt`).
2. **Expiry.** `exp` must not be in the past (five seconds of clock skew by
   default), and the token must not live longer than
   ``ServiceAuthVerifier/Configuration/maximumLifetime`` — one hour by default,
   which is the longest a reference PDS issues.
3. **Audience.** `aud` must be one of the values in the
   ``ServiceAuthAudience``.
4. **Method.** `lxm` is checked by a ``ServiceAuthMethodPolicy``.
5. **Issuer and key.** `iss` must be a DID. The token's `kid` (default
   `#atproto`) must be a key this service accepts.
6. **Signature.** The key comes from the ``ServiceAuthKeyResolver``. If the
   signature does not verify, the resolver is asked once more with
   `forceRefresh: true`, so an issuer that has just rotated its key is not
   locked out until a cache expires. Either S value is accepted, as the
   specification requires for JWTs.
7. **Replay.** With a ``ServiceAuthReplayStore``, each `jti` is accepted once.

The result is a ``VerifiedServiceAuth``: the issuer's DID, the key that
verified the token, and the claims.

### Resolve the issuer's key

``ServiceAuthKeyResolver`` is the seam to DID resolution. In the `Petrel`
module, `DIDDocumentServiceAuthKeyResolver` reads the key out of a resolved DID
document. For tests, or a service with a known set of callers,
``StaticServiceAuthKeyResolver`` holds a table, and
``ClosureServiceAuthKeyResolver`` adapts any lookup you already have:

```swift
let resolver = ClosureServiceAuthKeyResolver { did, keyID, forceRefresh in
    let multikey = try await directory.publicKeyMultibase(for: did, keyID: keyID, bypassCache: forceRefresh)
    return try ATProtoPublicKey(multikey: multikey)
}
// Cache keys, and stop forged tokens from forcing a DID resolution each.
let keyResolver = CachingServiceAuthKeyResolver(upstream: resolver)
```

A verifier asks for a forced refresh whenever a signature fails, and anyone can
send a token with a bad signature. ``CachingServiceAuthKeyResolver`` answers
such a refresh from upstream at most once per interval for a given issuer.

### Choose what to accept

```swift
var configuration = ServiceAuthVerifier.Configuration(
    audience: .exactly("did:web:appview.example.com#bsky_appview")
)
// Labelers sign with their labeling key.
configuration.acceptedKeyIDs = ["#atproto", "#atproto_label"]
// This service only ever expects the usual one-minute tokens.
configuration.maximumLifetime = 5 * 60
// Insist on typ, iat and jti, which the specification lists as required.
configuration.requiredClaims = .specification

let appView = ServiceAuthVerifier(configuration: configuration, keyResolver: keyResolver)
```

``ServiceAuthMethodPolicy`` has four cases. Use `.exactly(nsid)` in an endpoint
handler. `.exactlyIfPresent(nsid)` also admits the method-less tokens a PDS
issues for at most a minute; `.required` and `.optional` leave the comparison
to you.

### Answer failures

Every failure is a ``ServiceAuthError``. Its
``ServiceAuthError/xrpcErrorName`` is the error name the TypeScript reference
implementation uses for the same condition — `BadJwt`, `BadJwtType`,
`JwtExpired`, `BadJwtAudience`, `BadJwtLexiconMethod`, `BadJwtIss`,
`BadJwtSignature` — and ``ServiceAuthError/httpStatus`` is 401.

## Verify against a key you already hold

When the issuer's key is already in hand, ``ServiceJWT`` verifies directly.
Pass the audience and method you expect; leaving them out skips those checks.

```swift
let claims = try ServiceJWT.verify(
    token,
    publicKey: keypair.publicKey,
    expectedAudience: "did:web:feed.example.com#bsky_fg",
    expectedMethod: "app.bsky.feed.getFeedSkeleton"
)
```

To look inside a token without verifying it — for example one a PDS just
issued to you — use ``ServiceJWT/inspect(_:)``.

## Interoperability

`Tests/PetrelTests/Vectors/service-auth` holds tokens minted by the TypeScript
reference implementation, by OpenSSL and by `jose`, on both curves and with
both S heights, together with the verdict of the reference `verifyJwt` on each;
the test suite requires Petrel to reach the same verdict with the same error
name. The same directory holds Petrel-minted tokens and the reference
verifier's acceptance of them. Its README lists the four cases where Petrel's
defaults are deliberately stricter than the reference, and the option that
relaxes each.

## Topics

### Minting

- ``ServiceJWT``
- ``ServiceJWTClaims``
- ``ATProtoServiceReference``

### Authenticating requests

- ``ServiceAuthVerifier``
- ``VerifiedServiceAuth``
- ``ServiceAuthAudience``
- ``ServiceAuthMethodPolicy``
- ``ServiceAuthRequiredClaims``
- ``ServiceAuthError``

### Resolving issuer keys

- ``ServiceAuthKeyResolver``
- ``StaticServiceAuthKeyResolver``
- ``ClosureServiceAuthKeyResolver``
- ``CachingServiceAuthKeyResolver``

### Preventing replay

- ``ServiceAuthReplayStore``
- ``InMemoryServiceAuthReplayStore``

### Inspecting tokens

- ``ServiceJWTInspection``
