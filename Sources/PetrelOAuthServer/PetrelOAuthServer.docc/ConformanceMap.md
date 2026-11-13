# Conformance map

Where each requirement of the AT Protocol OAuth profile and permission specification is implemented and tested.

## Overview

Each row names a requirement, the type that implements it, and the test suite that exercises it. Suites are Swift Testing suites; find one by the file of the same name. Most are in `Tests/PetrelOAuthServerTests`. The Hummingbird adapter and `PinnedNIOOAuthRemoteTransport` are in this package (product `PetrelOAuthServerHummingbird`, trait `OAuthServerHummingbird`), but their tests, which run the example server over real sockets, are in the separate `Server/` package: `Server/Tests/PetrelOAuthServerHummingbirdTests` and `Server/Tests/PetrelClientInteropTests`.

### Server metadata and transport

| Requirement | Implemented in | Tested by |
|---|---|---|
| `/.well-known/oauth-authorization-server` with issuer, endpoints, `code`, both grants, `S256`, `none` and `private_key_jwt`, `ES256`, `atproto` scope, `iss` parameter, PAR required, client-ID metadata documents | ``OAuthAuthorizationServerMetadata`` | `OAuthMetadataTests` |
| Issuer is an https origin with no path or default port | ``OAuthAuthorizationServerConfiguration`` | `OAuthMetadataTests.issuerValidation` |
| `/.well-known/oauth-protected-resource` naming exactly one authorization server | ``OAuthProtectedResourceMetadata`` | `OAuthMetadataTests` |
| CORS on metadata, PAR, token and revocation; `DPoP-Nonce` exposed | ``OAuthAuthorizationServer`` | `OAuthMetadataTests.cors` |

### Clients

| Requirement | Implemented in | Tested by |
|---|---|---|
| `client_id` is an https URL without a port | ``OAuthClientMetadata`` | `OAuthClientMetadataTests.clientIDRules` |
| Metadata fetch: exact 200, JSON content type, no redirects, public addresses only, bounded size and time | ``OAuthRemoteDocumentFetcher``; connections pinned to the checked addresses (``OAuthRemoteTransport/pinsConnectionsToApprovedPeers``) | `OAuthClientMetadataLoaderTests`, `PinnedNIOOAuthRemoteTransportTests` |
| Metadata caching with prompt re-fetch of confidential keys | ``OAuthClientMetadataLoader`` | `OAuthClientMetadataLoaderTests.fetchAndCache`, `OAuthTokenEndpointTests.keyRemovedFromJWKS` |
| Field validation (`client_id` match, application type, grants, scope, response types, redirect URIs, DPoP binding, signing algorithm, `jwks` or `jwks_uri`, display URIs) | ``OAuthClientMetadata`` | `OAuthClientMetadataTests.invalidDocuments`, `.confidentialClients` |
| Loopback development clients | ``OAuthClientMetadata`` | `OAuthClientMetadataTests.loopbackClients`, `OAuthEndToEndFlowTests.loopbackClientFlow` |
| Redirect URI rules for web and native clients, exact matching | ``OAuthClientMetadata`` | `OAuthClientMetadataTests.nativeRedirects`, `OAuthPushedAuthorizationRequestTests.invalidParameters` |
| Unverified client name and logo hidden for untrusted clients | ``OAuthClientPresentation`` | `OAuthAuthorizationInterfaceTests.untrustedClientPresentation` |
| `private_key_jwt`: assertion type, audience, lifetime, `jti` uniqueness, ES256 and ES256K, high-S signatures | ``OAuthClientAssertionValidator`` | `OAuthPushedAuthorizationRequestTests.clientAssertionFailures`, `.secp256k1Assertion` |
| Session bound to the client key; revoked when the key leaves the JWKS | ``OAuthClientKeyBinding`` | `OAuthTokenEndpointTests.confidentialKeyBinding`, `.keyRemovedFromJWKS` |

### Authorization requests

| Requirement | Implemented in | Tested by |
|---|---|---|
| PAR endpoint; PAR mandatory | ``OAuthAuthorizationServer`` | `OAuthPushedAuthorizationRequestTests`, `OAuthAuthorizationInterfaceTests.nonPARRefused` |
| `response_type=code`, PKCE S256 only, `state`, `redirect_uri`, scope subset including `atproto`, `login_hint` | ``OAuthAuthorizationServer``, `OAuthScopeAdmissionPolicy` | `OAuthPushedAuthorizationRequestTests.invalidParameters` |
| `code_challenge` not reusable; duplicate `state` refused | ``OAuthReplayStore`` | `OAuthPushedAuthorizationRequestTests.codeChallengeReuse` |
| DPoP from the first request, key bound to the session, nonce returned | ``OAuthDPoPProofValidator`` | `OAuthPushedAuthorizationRequestTests.nonceChallenge`, `OAuthTokenEndpointTests.differentDPoPKey` |
| Authorization Interface: sign-in, account selection, `login_hint`, consent naming the client and describing scopes, denial | ``OAuthInterfacePage``, ``OAuthDefaultInterface`` | `OAuthAuthorizationInterfaceTests` |
| Redirect with `code`, `state` and `iss` | ``OAuthAuthorizationServer`` | `OAuthAuthorizationInterfaceTests.approvalRedirect` |
| Code single-use; reuse revokes the session | ``OAuthSessionStore`` | `OAuthTokenEndpointTests.codeReplay`, `InMemoryOAuthStoreTests.codeRedemption` |
| Session listing and revocation | ``OAuthAuthorizationServer`` | `OAuthTokenEndpointTests.sessionManagement` |

### Tokens

| Requirement | Implemented in | Tested by |
|---|---|---|
| `authorization_code` grant: verifier, redirect URI, client authentication, DPoP | ``OAuthAuthorizationServer`` | `OAuthTokenEndpointTests.wrongBinding`, `.differentClient` |
| Response carries `sub` (the account DID), `scope` and `token_type: DPoP` | ``OAuthTokenResponse`` | `OAuthTokenEndpointTests.responseShape` |
| `refresh_token` grant, single-use rotation, only when declared | ``OAuthSessionStore`` | `OAuthTokenEndpointTests.refreshReuse`, `.noRefreshGrant` |
| Lifetimes: access under 30 minutes; public session and refresh two weeks; confidential refresh 180 days | ``OAuthAuthorizationServerConfiguration`` | `OAuthTokenEndpointTests.publicClientLifetimes`, `.confidentialRefreshLifetime`, `OAuthMetadataTests.configurationLimits` |
| Tokens bound to one DPoP key and one client | ``OAuthGrantBinding`` | `OAuthTokenEndpointTests.refreshWithDifferentKey`, `.refreshByAnotherClient` |
| Revocation | ``OAuthAuthorizationServer`` | `OAuthTokenEndpointTests.revocation` |
| Access token with `sub` and `cnf.jkt` | ``OAuthAccessTokenClaims`` | `OAuthEndToEndFlowTests.signedAccessTokens` |

### DPoP

| Requirement | Implemented in | Tested by |
|---|---|---|
| Proof validation: `typ`, embedded key, signature, `htm`, `htu` with RFC 3986 normalisation, `iat` window | ``OAuthDPoPProofValidator`` | `OAuthDPoPTests` |
| Mandatory server nonces with `use_dpop_nonce`; rotation; recently stale nonces accepted; lifetime under five minutes | ``OAuthDPoPNonceService`` | `OAuthDPoPTests.nonceRequired`, `.nonceRotation` |
| `DPoP-Nonce` on responses | ``OAuthAuthorizationServer``, ``OAuthResourceServerVerifier`` | `OAuthTokenEndpointTests.responseShape`, `OAuthResourceServerVerifierTests.failures` |
| `jti` replay rejection | ``OAuthReplayStore`` | `OAuthDPoPTests.replay`, `OAuthResourceServerVerifierTests.proofReplay` |
| Resource server: `Authorization: DPoP`, `ath`, `cnf.jkt` match, `WWW-Authenticate` challenge | ``OAuthResourceServerVerifier`` | `OAuthResourceServerVerifierTests` |

### Scopes and permissions

| Requirement | Implemented in | Tested by |
|---|---|---|
| `atproto` required | `OAuthScopeAdmissionPolicy` | `OAuthPushedAuthorizationRequestTests.invalidParameters` |
| `transition:generic`, `transition:chat.bsky`, `transition:email` | `ScopePermissions` | `Scopes/Upstream/ScopePermissionsTransitionTests` |
| Scope string syntax | `ScopeStringSyntax` | `Scopes/Upstream/SyntaxStringTests`, `OAuthScopesGrammarTests` |
| `repo`, `rpc`, `blob`, `account`, `identity` | `RepoPermission`, `RpcPermission`, `BlobPermission`, `AccountPermission`, `IdentityPermission` | the suite of the same name under `Scopes/Upstream`, and `UpstreamScopeConformanceTests` against values generated by the reference implementation |
| `include:` permission sets through Lexicon resolution | ``OAuthLexiconScopeResolution``, ``OAuthLexiconResolving`` | `OAuthPermissionSetTests.expansion`, `AuthenticatedOAuthLexiconResolverTests.includeEndToEnd` |
| Permission set authenticated: DNS `_lexicon` TXT, authority DID document, `com.atproto.sync.getRecord`, signed repository proof | `AuthenticatedOAuthLexiconResolver` (product `PetrelOAuthServerLexicon`) | `AuthenticatedOAuthLexiconResolverTests.resolvesValidProof`, `.refusesBrokenProofs`, `.txtRecords`, `.fetchPolicy` |
| Only `repo` and `rpc` in sets, no wildcards, no fixed audience, `inheritAud`, namespace authority, unknown entries ignored | `IncludeScope` | `OAuthScopesIncludeExpansionTests`, `OAuthPermissionSetTests.expansion` |
| Unresolvable set fails the request; cache with stale and expiry bounds; grant recomputed on refresh | ``CachingOAuthLexiconResolver``, `AuthenticatedOAuthLexiconResolver` | `OAuthPermissionSetTests.unresolvable`, `.caching`, `.refreshRederivation`, `AuthenticatedOAuthLexiconResolverTests.refusesBrokenProofs` |
| Consent shows the set's title and detail, localised, with the permissions inside | ``OAuthScopeDescription`` | `OAuthPermissionSetTests.consentDescription` |

### OAuth security best practice

| Requirement | Implemented in | Tested by |
|---|---|---|
| Exact redirect URI matching; no redirect before the request is verified | ``OAuthAuthorizationServer`` | `OAuthAuthorizationInterfaceTests.invalidRequestURI`, `.nonPARRefused` |
| `303` after a form post | ``OAuthAuthorizationServer`` | `OAuthAuthorizationInterfaceTests.approvalRedirect` |
| `Cache-Control: no-store` on token responses and pages | ``OAuthAuthorizationServer`` | `OAuthTokenEndpointTests.responseShape`, `OAuthAuthorizationInterfaceTests.securityHeaders` |
| Clickjacking and CSRF defences | ``OAuthAuthorizationServer``, ``OAuthBrowserFlowService`` | `OAuthAuthorizationInterfaceTests.securityHeaders`, `.csrfProtection` |
| Only the `code` response type and the two profile grants | ``OAuthAuthorizationServer`` | `OAuthPushedAuthorizationRequestTests.invalidParameters`, `OAuthTokenEndpointTests.malformed` |

### Interoperability

| Evidence | Where |
|---|---|
| The reference TypeScript client, `@atproto/oauth-client-node`, completes discovery, PAR, sign-in and consent, the code exchange, a DPoP resource request, refresh and revocation against the example server, with three clients, none pre-registered: a public `http://localhost` client, a public https client, and a confidential `private_key_jwt` client whose keys are at its `jwks_uri`. The server discovers both https clients by fetching their metadata documents (and the JWKS) through `PinnedNIOOAuthRemoteTransport` | `Server/Scripts/ts-client-interop`, run by `ExampleServerEndToEndTests.typeScriptClientInterop` when `PETREL_TS_INTEROP_DIR` is set; the scheduled (nightly) job of `.github/workflows/oauth-server.yml` runs it |
| Petrel's own OAuth client (`ATProtoClient`) signs in, makes resource calls across a refresh and a nonce rotation, and revokes at logout against the example server, as a public loopback client and as a confidential client whose assertions come from `petrel-cab-server` | `Server/Tests/PetrelClientInteropTests` (`PetrelClientAgainstExampleServerTests`) |
| A nonce challenge is validated before client authentication, so the client's retry with the same single-use assertion succeeds (found by that run) | `OAuthPushedAuthorizationRequestTests.nonceChallengeKeepsClientAssertion` |
| `response_mode=fragment`, as browser-based clients request | `OAuthAuthorizationInterfaceTests.fragmentResponseMode` |
