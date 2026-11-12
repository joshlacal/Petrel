# ``PetrelOAuthServerLexicon``

Resolve the permission sets behind `include:` scopes, and prove each one came from its authority's signed repository.

## Overview

An `include:` scope names a permission set by NSID, such as `include:com.example.foo.auth`. The authorization server expands it into the permissions the set declares, so whoever controls the set's content controls what a grant allows. ``AuthenticatedOAuthLexiconResolver`` establishes that content the way the reference implementation's `LexResolver` does:

1. Look up DNS `TXT _lexicon.foo.example.com` and require exactly one `did=` line.
2. Resolve that DID's document for its PDS endpoint and `#atproto` signing key.
3. Call `com.atproto.sync.getRecord` on that PDS for `com.atproto.lexicon.schema/<nsid>`.
4. Verify the returned CAR: one root, a commit for that DID, signed by that key, with the record reachable from the commit's Merkle search tree. Then check that the record is a valid Lexicon document whose `id` is the NSID.

If any step fails, the result is ``PetrelOAuthServer/OAuthLexiconResolution/unresolvable`` and the server refuses the scope with `invalid_scope`. A response the PDS fabricates fails the proof.

Every request goes through one ``PetrelOAuthServer/OAuthRemoteDocumentFetcher``: the `getRecord` call and, by default, the DID document fetch (a `did:web` document is served from a host its owner chooses). The fetcher applies the server's outbound policy: HTTPS, public addresses only, a transport that pins its connection to the checked addresses, no redirects, and bounded time and size. Its body limit must be at most 256 KiB, which bounds the parsing and signature work one response can cause.

## Wiring it into a server

```swift
import PetrelOAuthServer
import PetrelOAuthServerLexicon

let fetcher = OAuthRemoteDocumentFetcher(
    policy: try OAuthRemoteFetchPolicy(),
    transport: pinnedTransport
)
let server = try OAuthAuthorizationServer(
    configuration: configuration,
    store: store,
    accounts: accounts,
    clients: OAuthClientMetadataLoader(fetcher: fetcher, cache: store),
    lexiconResolver: CachingOAuthLexiconResolver(
        upstream: try AuthenticatedOAuthLexiconResolver(fetcher: fetcher),
        cache: store
    )
)
```

`CachingOAuthLexiconResolver` adds the permission specification's cache lifetimes. The resolver also caches each authority's DID document for five minutes, but never a proof: every resolution checks the proof again under the key the document currently names.

The test `includeEndToEnd` in `AuthenticatedOAuthLexiconResolverTests` runs this wiring through pushed authorization, consent, token issuance and a resource request.

## Topics

### Resolving permission sets

- ``AuthenticatedOAuthLexiconResolver``
- ``OAuthLexiconResolverConfigurationError``

### The authority's DID document

- ``OAuthLexiconAuthority``
- ``OAuthLexiconAuthorityResolving``
- ``IdentityOAuthLexiconAuthorityResolver``
- ``OAuthLexiconAuthorityError``
- ``OAuthRemoteIdentityHTTPTransport``
