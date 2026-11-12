# Service Authentication and Proxying

Reach other services through your PDS, get a service token when you call one directly, and authenticate callers when you are the service.

## Overview

Most requests an app makes are not for its PDS. Timelines come from an AppView,
messages from a chat service, labels from a labeler. The protocol gives a
client two ways to reach them, both built on short-lived JWTs signed with the
account's signing key ("service auth"):

- **Proxying.** The client sends the request to its PDS with an `atproto-proxy`
  header naming the target service. The PDS mints the token and forwards the
  request.
- **Direct calls.** The client asks its PDS for a token with
  `com.atproto.server.getServiceAuth` and sends the request itself.

A Swift service on the receiving end — a feed generator, a labeler — verifies
those tokens against the issuer's DID document.

The token format, minting and verification live in the `PetrelCrypto` module,
which `import Petrel` re-exports; its *Service Authentication* article
documents `ServiceJWT` and `ServiceAuthVerifier` in full. This page covers the
parts that need a client or a DID document.

## Proxy requests through the PDS

``ATProtoClient`` attaches `atproto-proxy` by lexicon namespace. An OAuth or
app-password client starts with `app.bsky` routed to the Bluesky AppView
(`did:web:api.bsky.app#bsky_appview`) and `chat.bsky` to the Bluesky chat
service (`did:web:api.bsky.chat#bsky_chat`). Change a route, or add one for a
single endpoint, with ``ATProtoClient/setServiceProxy(_:for:)``:

```swift
// Everything under app.bsky goes to a self-hosted AppView…
try await client.setServiceProxy(
    ATProtoServiceReference("did:web:appview.example.com#bsky_appview"), for: "app.bsky"
)
// …and one endpoint goes to a labeler.
try await client.setServiceProxy(
    ATProtoServiceReference(did: "did:web:labeler.example.com", serviceID: "atproto_labeler"),
    for: "com.atproto.label.queryLabels"
)
```

The longest matching prefix wins. `app.bsky.actor.getPreferences` and
`putPreferences` are never proxied, because preferences are stored on the PDS.
The header is only attached to requests addressed to the PDS host.
``ATProtoClient/serviceProxy(for:)`` reports where a given endpoint is routed.

`ATProtoServiceReference` is the `did#service` pair: the DID of the service
and the identifier of an entry in its DID document's `service` array.

## Request a token for a direct call

```swift
let token = try await client.getServiceAuthToken(
    audience: ATProtoServiceReference("did:web:video.example.com#video_service"),
    lexiconMethod: "com.atproto.repo.uploadBlob",
    lifetime: 30 * 60
)
request.setValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
```

``ATProtoClient/getServiceAuthToken(audience:lexiconMethod:lifetime:now:)``
returns a ``ServiceAuthToken`` with the claims decoded, so the caller can see
when it expires (``ServiceAuthToken/expiresAt``,
``ServiceAuthToken/isExpired(at:margin:)``). It throws
``ServiceAuthRequestError/unexpectedClaims(_:)`` rather than hand back a token
the PDS issued for a different service or endpoint.

Bind the token to the endpoint you are about to call. A PDS issues method-less
tokens (`lexiconMethod: nil`) only for a lifetime of at most one minute, and
grants at most one hour with a method.

## Authenticate callers in a Swift service

`ServiceAuthVerifier` (in `PetrelCrypto`) turns an `Authorization` header into
a verified caller. It needs the issuer's public key, which is published in the
issuer's DID document. ``IdentityResolver`` resolves DID documents and can be
used as the verifier's key source directly:

```swift
let verifier = ServiceAuthVerifier(
    audience: .service(did: "did:web:feed.example.com", id: "bsky_fg", acceptBareDID: true),
    keyResolver: CachingServiceAuthKeyResolver(upstream: IdentityResolver())
)
let caller = try await verifier.verify(
    authorizationHeader: request.headers["Authorization"],
    method: .exactly("app.bsky.feed.getFeedSkeleton")
)
```

`CachingServiceAuthKeyResolver` limits how often a failed signature can make
the resolver fetch a DID document again; anyone can send a token with a bad
signature.

To read keys from a document source of your own — a PLC mirror, a database —
use ``DIDDocumentServiceAuthKeyResolver`` and give it any way of fetching a
DID document:

```swift
struct FeedGenerator {
    static let serviceDID = "did:web:feed.example.com"
    let verifier: ServiceAuthVerifier

    init(directory: Directory) {
        // DID documents → keys, cached, with forced refreshes rate-limited.
        let keys = CachingServiceAuthKeyResolver(
            upstream: DIDDocumentServiceAuthKeyResolver { did, forceRefresh in
                try await directory.document(for: did, forceRefresh: forceRefresh)
            }
        )
        verifier = ServiceAuthVerifier(
            // Requests proxied by a PDS may still carry the bare DID.
            audience: .service(did: Self.serviceDID, id: "bsky_fg", acceptBareDID: true),
            keyResolver: keys,
            replayStore: InMemoryServiceAuthReplayStore()
        )
    }

    /// Returns the viewer's DID, or the XRPC error to answer with.
    func viewer(authorizationHeader: String?) async -> Result<String, ServiceAuthError> {
        do {
            let caller = try await verifier.verify(
                authorizationHeader: authorizationHeader,
                method: .exactly("app.bsky.feed.getFeedSkeleton")
            )
            return .success(caller.issuer)
        } catch {
            return .failure(error)
        }
    }
}
```

`directory` stands for your DID-document source: a PLC directory client, a
`did:web` fetch, a local mirror. It must honour `forceRefresh`. When a
signature fails the verifier asks once more with `forceRefresh: true`, which
is what lets an account that has just rotated its signing key keep working.

On failure, answer with HTTP 401 and an XRPC error body built from the
`ServiceAuthError`: `xrpcErrorName` (for example `BadJwtAudience`,
`JwtExpired`, `BadJwtSignature`) and `message`.

A labeler authenticates the same way, with its own audience
(`.service(did: labelerDID, id: "atproto_labeler")`) and method NSIDs.

The proxying and token snippets on this page are exercised on the wire by
`Tests/PetrelTests/ServiceAuth/ServiceAuthClientTests.swift`; the identity
resolver snippet by `ServiceAuthIdentityResolverTests.swift` and the feed
generator by `ServiceAuthDIDDocumentTests.swift`, in the same directory.

## Topics

### Proxying

- ``ATProtoClient/setServiceProxy(_:for:)``
- ``ATProtoClient/serviceProxy(for:)``

### Requesting tokens

- ``ATProtoClient/getServiceAuthToken(audience:lexiconMethod:lifetime:now:)``
- ``ServiceAuthToken``
- ``ServiceAuthRequestError``

### Verifying tokens

- ``IdentityResolver``
- ``DIDDocumentServiceAuthKeyResolver``
