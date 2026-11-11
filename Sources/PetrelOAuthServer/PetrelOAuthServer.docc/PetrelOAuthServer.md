# ``PetrelOAuthServer``

An AT Protocol OAuth 2.0 authorization server, and the resource-server verifier that goes with it.

## Overview

`PetrelOAuthServer` is what a PDS or entryway runs to issue tokens: the server side of the [AT Protocol OAuth profile](https://atproto.com/specs/oauth) and the [permission specification](https://atproto.com/specs/permission). It is the counterpart of the OAuth client in the `Petrel` module.

The server is a value with one entry point. ``OAuthAuthorizationServer`` takes an ``OAuthHTTPRequest`` and returns an ``OAuthHTTPResponse``, so it embeds in any web framework; the `Server/` package in the Petrel repository contains a Hummingbird adapter and a runnable example. Everything the server needs from its host is injected:

| Seam | Protocol | Shipped implementation |
|---|---|---|
| Accounts and passwords | ``OAuthAccountAuthenticating`` | none (the host's account system) |
| Persistence | ``OAuthServerStore`` | ``InMemoryOAuthStore`` |
| Client discovery | ``OAuthClientResolving`` | ``OAuthClientMetadataLoader``, ``StaticOAuthClientResolver`` |
| Outbound HTTP | ``OAuthRemoteTransport`` | `PinnedNIOOAuthRemoteTransport` (in the `Server` package's `PetrelOAuthServerHummingbird`); ``URLSessionOAuthRemoteTransport`` only with ``OAuthRemoteFetchPolicy/allowsUnpinnedTransport`` |
| Permission sets | ``OAuthLexiconResolving`` | ``CachingOAuthLexiconResolver``, ``StaticOAuthLexiconResolver`` |
| Authorization Interface | ``OAuthInterfaceRendering`` | ``OAuthDefaultInterface`` |
| Time and randomness | ``OAuthClock``, ``OAuthRandomSource`` | ``SystemOAuthClock``, ``SystemOAuthRandomSource`` |

What the server implements:

- Authorization server and protected-resource metadata.
- Client-ID metadata documents with full validation, `http://localhost` development clients, and confidential clients authenticated with `private_key_jwt`.
- Pushed authorization requests (mandatory), PKCE with S256 only, and the `iss` response parameter.
- DPoP on every request, with rotating server nonces, `jti` replay protection and `ath` at the resource server.
- The Authorization Interface: sign-in, account selection, an optional second factor, consent with plain-language scope descriptions, and denial.
- The `authorization_code` and `refresh_token` grants with single-use refresh rotation, session revocation on code or refresh replay, and the profile's lifetimes for public and confidential clients.
- Token revocation.
- Scopes: `atproto`, the `transition:` scopes, the granular `repo:`, `rpc:`, `blob:`, `account:` and `identity:` permissions, and `include:` permission sets.
- The scope grammar itself lives in the dependency-free `PetrelOAuthScopes` module, which this module re-exports, so clients and servers share one parser.
- General-purpose JOSE types for ES256 and ES256K: ``OAuthJSONWebKey``, ``OAuthJSONWebKeySet``, ``OAuthSigningKey`` and ``OAuthCompactJWT``.

## Topics

### Guides

- <doc:RunYourOwnAuthorizationServer>
- <doc:ConformanceMap>

### Server

- ``OAuthAuthorizationServer``
- ``OAuthAuthorizationServerConfiguration``
- ``OAuthHTTPRequest``
- ``OAuthHTTPResponse``
- ``OAuthHTTPHeaders``
- ``OAuthRoute``
- ``OAuthMetadataPublication``

### Resource server

- ``OAuthResourceServerVerifier``
- ``OAuthAccessGrant``
- ``OAuthResourceAuthorizationFailure``

### Accounts and interface

- ``OAuthAccountAuthenticating``
- ``OAuthAccount``
- ``OAuthSignInResult``
- ``OAuthInterfaceRendering``
- ``OAuthInterfacePage``
- ``OAuthDefaultInterface``
- ``OAuthScopeDescription``

### Clients

- ``OAuthClientResolving``
- ``OAuthClientMetadataLoader``
- ``OAuthClientMetadata``
- ``OAuthResolvedClientMetadata``
- ``OAuthRemoteDocumentFetcher``
- ``OAuthRemoteFetchPolicy``

### Storage

- ``OAuthServerStore``
- ``InMemoryOAuthStore``
- ``OAuthSession``
- ``OAuthGrantBinding``

### DPoP and JOSE

- ``OAuthDPoPProofValidator``
- ``OAuthDPoPNonceService``
- ``OAuthJSONWebKey``
- ``OAuthJSONWebKeySet``
- ``OAuthSigningKey``
- ``OAuthCompactJWT``

### Scopes and permission sets

- ``OAuthLexiconResolving``
- ``CachingOAuthLexiconResolver``
