# Changelog

All notable changes to this project will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

## [2.0.0] - Unreleased

Petrel 2.0.0 turns the single `Petrel` library of 1.1.0 into a family of products that together
cover the AT Protocol SDK feature set: identity, cryptography, service auth, repositories, PLC,
event streams, Lexicon, OAuth client and OAuth authorization server. This section is written
for code upgrading from 1.1.0. Products other than `Petrel` are new in 2.0.0, so changes made to
them during the release cycle are not listed as breaking.

Toolchain floor: swift-tools 6.1 (Xcode 16.3 / Swift 6.1). Platforms: iOS 18, macOS 15, tvOS 18,
Linux (CI: Swift 6.1.2 on Ubuntu 22.04). See [LINUX_SUPPORT.md](LINUX_SUPPORT.md).

### Upgrading from 1.1.0: what usually needs a code change

1. Generated calls now throw for non-2xx responses instead of returning `(status, nil)`.
   Catch `ATProtoError<E>` (endpoints with declared errors) or `ATProtoXRPCError`, both of
   which carry the server's `error` and `message`.
2. Lexicon fields with `format: "cid"` are `CIDString` instead of `CID`
   (`CIDString(cid)` / `.cid`); `cid-link` fields in `subscribeRepos` messages are `ATProtoLink`.
3. Optional-and-nullable fields are `ATProtoNullable<T>?`, so "absent" and "explicit null" are
   different values (for example `ComAtprotoRepoPutRecord.Input.swapRecord`).
4. `ComAtprotoSimplespace*` and the October Spaces renames (see *Spaces* below).
5. Exhaustive `switch` statements over `ATProtocolError`, `AuthError`, `AuthEvent` and
   `NetworkError` need the new cases.
6. Rebuild against swift-tools 6.1.
7. Generated query parameters default to their Lexicon `default`, which is now sent
   (`getTimeline()` sends `limit=50`). Pass `nil` to omit one.
8. PetrelJetstream: exhaustive `switch` statements over `JetstreamSubscriptionEvent` and
   `JetstreamSubscriptionError` need `.ignoredFrame` and `.cursorStorageFailure`.
9. Petrel no longer sends `X-Catbird-Request-Id` or `X-Catbird-Client`. A server that read them
   needs the app to opt in with `setRequestIDHeader(name:)` / `setHeader(name:value:)`.

`api-breakage-allowlist.txt` lists every reviewed API diagnostic, and
[docs/api-compatibility/0.1.0-spaces-migration.md](docs/api-compatibility/0.1.0-spaces-migration.md)
classifies the core-type move.

### Petrel

#### Added
- `IdentityResolver`: standalone handle and DID resolution (`did:plc`, `did:web`; handles by DNS
  TXT and HTTPS well-known) with bidirectional handle verification, typed DID documents and a
  cache. Requests to third-party hosts carry no account credentials. (#43)
- Bluesky helpers on `client.bsky` (`BskyAgent`): rich text with facet detection, record verbs
  (post, reply, quote, embeds, like, repost, follow, block, mutes, threadgates, postgates,
  `upsertProfile`, video upload), typed preferences with setters, `moderateProfile` /
  `moderatePost` with muted words and labeler configuration (`configureLabelers`), and
  `at://` ↔ bsky.app URL conversion. (#44)
- Service auth: `ATProtoClient.getServiceAuthToken`, `ServiceAuthKeyResolver` (static, closure
  and caching resolvers; `IdentityResolver` conforms), and `atproto-proxy` routing per namespace
  or endpoint. Verification lives in PetrelCrypto. (#49)
- OAuth client: in-process `private_key_jwt` client authentication, a client-metadata builder,
  loopback-client configuration, token revocation on sign-out, typed account-status errors.
  Scope types come from PetrelOAuthScopes. (#45, #46)
- Generic XRPC: `ATProtoClient.query` / `procedure`, `NetworkService.xrpcQuery` /
  `xrpcProcedure`, `XRPCCallOptions`, `NetworkService.withResponseMetadata`,
  `XRPCResponseDecodingError`; generated types gain `extraFields` so unknown fields round-trip;
  `ATProtoNullable<T>`, `CIDString`; token and `knownValues` constants; permission-set types. (#52)
- Identifier syntax: `LanguageTag`, `CIDSyntax`, validating initializers that throw the new
  `ATProtocolError` cases, all checked against the official atproto syntax vectors. (#40)
- `CredentialStorageConfiguration` and `ATProtoClient(…, credentialStorage:)`: per-client
  credential storage, including `.encryptedFiles(directory:masterKey:)`. The existing
  initializers keep the platform default. (#55)
- `NetworkService.withResponseLimits(_:operation:)` runs an operation with the given
  `NetworkResponseLimits` in place of each `NetworkService`'s own limits (10 MiB by default) for
  every request it sends. Each field is clamped to 0...128 MiB. The scope covers child tasks and
  any authentication refresh or retry the requests trigger; scoped requests are not deduplicated
  with other in-flight requests, and the hardened transport checks are unchanged. (#34)
- `NetworkResponseLimits` is documented: the 10 MiB default, raising it for one call (such as
  `com.atproto.sync.getRepo`) with `withResponseLimits`, the 128 MiB clamp, and the lack of a
  streaming download API. (#65)
- `XRPCPages` pages through any cursor-paginated query (every generated query with a plain
  `cursor` parameter and output field conforms to `XRPCCursorPaginatedParameters` /
  `XRPCCursorPaginatedOutput`). It stops at a nil, empty or repeated cursor, after `maxPages`, or
  on a body-less response:
  `XRPCPages(startingAt: AppBskyFeedGetTimeline.Parameters(limit: 50)) { try await client.app.bsky.feed.getTimeline(input: $0) }`.
  (#66)
- `NetworkService.serverSentEvents(_:additionalHeaders:endpoint:as:)` backs generated
  `text/event-stream` queries. They now compile and run on Linux, refuse redirects, decode UTF-8
  split across chunks correctly, and cap one event at 8 MiB. (#66)
- `NetworkService.setRequestIDHeader(name:)` sends a fresh per-request ID under a header name the
  app chooses (never to anonymous third-party hosts). Off by default. (#64)
- Lexicons synced with bluesky-social/atproto, including 3-segment and 5+-segment NSIDs. (#52)

#### Changed
- Petrel no longer calls `LoggingSystem.bootstrap`, which swift-log allows once per process, so an
  app can bootstrap its own handler at any time. On Apple platforms Petrel's loggers still write to
  the unified log; elsewhere they use the app's handler. **Migrate:** an app that relied on
  Petrel's bootstrap (unified log for its own swift-log loggers on Apple platforms, standard output
  on Linux) now gets swift-log's default, standard error, until it bootstraps itself. (#65)
- Generated query `Parameters` initializers default to the Lexicon's `default` values (integers,
  booleans, plain strings, closed enums), and those values are sent, as the spec says a client
  should. Pass `nil` to omit one. (#66)
- The default lenient decoder keeps a malformed optional field raw in `extraFields` (the property
  reads as `nil`), so writing the record back is byte-identical in JSON and DAG-CBOR and keeps its
  CID. A value set on the property wins over an extra field of the same name. Strict decoding is
  unchanged. As a result `ATProtocolValueContainer` returns `.knownType` for such a record where
  it used to return `.unknownType`. (#66)
- `setReportLabeler(did:)` and `clearReportLabeler()` are deprecated; pass the labeler to
  `client.bsky.createModerationReport(_:labeler:)`. (#66)
- Petrel sends no app-specific headers: `X-Catbird-Request-Id` and `X-Catbird-Client` are gone.
  **Migrate:** an app that wants a correlation ID calls `setRequestIDHeader(name:)`, and adds
  any client header with `setHeader(name:value:)`. (#64)
- WebSocket subscriptions carry the client's non-credential `setHeader` headers and User-Agent,
  as HTTP requests do; a third-party stream host gets only the headers the call itself set. (#64)
- Error envelopes are kept: a 401 on a client without an account and an unexpected status code
  return the server's response on the final attempt (or throw `authenticationRequired` /
  `NetworkError.responseError(statusCode:)`) instead of a bare `requestFailed`. A procedure body
  with an empty or invalid `Content-Type` is refused before sending. (#64)
- `DIDDocument.serviceEndpoint(_:)` (and `pdsEndpoint`) follow the first matching service entry
  even when it is unreadable (non-string `serviceEndpoint`, no `type`): it throws
  `invalidServiceEndpoint` instead of falling through to a later entry. (#70)
- `ATProtocolURI` documents that `format: at-uri` accepts the Spaces URI form, as the reference
  implementation does, and how to check against the specification grammar alone
  (`ATProtocolURI.isValidATURI(_:grammar: .restricted)`). No behaviour change. (#71)
- Non-2xx responses from generated endpoints throw `ATProtoError<E>` / `ATProtoXRPCError`
  (previously many returned the status with a `nil` body). (#52)
- Retries: never on 501, never resend a POST after a 5xx or timeout, and honour `Retry-After` up
  to 30 s. Query values containing `+` are percent-encoded. (#52)
- `uploadBlob` still strips image metadata by default (`stripMetadata: true`), but now only for
  `image/*` bodies, losslessly and without changing format, with a pure-Swift path for JPEG, PNG,
  WebP and GIF that also works on Linux. Non-image bodies are sent exactly as given; an image that
  cannot be stripped throws `NetworkError.metadataStrippingFailed` instead of being uploaded.
  (#52; decision D8)
- Identifier parsing follows the syntax specs exactly: stricter AT-URI, datetime, language and
  URI decoding; `URI` never rewrites its input; `Handle` encodes as written; `TIDGenerator` is
  monotonic at microsecond resolution. (#40)
- `.test` handles and `did:web:localhost` resolve only in DEBUG builds. (#43)
- OAuth: authorization-server metadata errors are typed (`OAuthMetadataError`) with no silent
  fallback; `Session.isExpiringSoon` means within 60 s (was 15 minutes); an error callback other
  than `access_denied` is reported as a server error; `removeAccount` revokes tokens; a sign-in in
  flight when the client restarts must be started again; `transition:chat.bsky` alone no longer
  implies chat access. (#45)
- Muted words on a quote post that also attaches media are judged against the quoting author,
  and also cover the quoted post's own media; both are stricter than the TypeScript reference
  (local display only). (#44; decisions D11, D13 addendum)
- `setAcceptLabelers` is deprecated in favour of `configureLabelers(_:)`. (#44)

#### Breaking (with migration)
- Non-2xx responses throw (see *Changed*). **Migrate:** wrap calls in `do`/`catch`; the
  response tuple's data is non-`nil` on success. (#52)
- `format: "cid"` fields are `CIDString` (120 declarations). **Migrate:** `CIDString(cid)` to
  build, `.cid` to read a parsed `CID`. (#52)
- `subscribeRepos` `Commit.commit`, `Commit.blobs`, `Commit.prevData`, `RepoOp.cid` and
  `RepoOp.prev` are `ATProtoLink`. **Migrate:** read the CID through the link. (#52)
- Optional-and-nullable fields are `ATProtoNullable<T>?` (for example
  `ComAtprotoRepoPutRecord.Input.swapRecord`). **Migrate:** `.value(x)` for a value, `.null` to
  send an explicit null, `nil` to omit. (#52)
- Removed the untyped union arrays `AppBskyEmbedGallery.Items` / `ItemsForUnionArray` and
  `AppBskyRichtextFacet.Features` / `FeaturesForUnionArray`, and the `.unexpected` cases of
  `ComAtprotoRepoApplyWrites.InputWritesUnion` / `OutputResultsUnion`. **Migrate:** use the
  typed union arrays the generator now emits. (#52)
- Removed the namespace accessors for permission-set lexicons, which had no endpoints
  (`client.app.bsky.authCreatePosts` … `authViewAll`, `client.chat.bsky.authFullChatClient`,
  `client.com.germnetwork.declaration`). **Migrate:** delete the references. (#52)
- New enum cases: `ATProtocolError.invalidDID`, `.invalidHandle`, `.invalidNSID`,
  `.invalidRecordKey`, `.invalidDatetime`, `.invalidLanguage`, `.invalidCID` (#40);
  `AuthError.invalidClientMetadata`, `.nativeClientNoneAuthRequired`,
  `.oauthFlowStateUnavailable`; `AuthEvent.gatewaySessionRejected`; `NetworkError.streamOverflow`,
  `.responseLimitExceeded`, `.metadataStrippingFailed`. **Migrate:** add the cases or a `default`.
- Core data-model types (`CID`, `CIDCodec`, `Multihash`, `ATProtoLink`, `DAGCBOR*`,
  `OrderedCBORMap`, `CARReader`, base32 helpers) moved to PetrelCore. `import Petrel` re-exports
  them, so ordinary calls, including `ATProtoLink(cid:)`, `ATProtoLink(cidString:)`,
  `link.cid` and `Data.hexDump()`, and qualified names such as `Petrel.CID` compile unchanged.
  Rebuild; the move is not ABI-compatible. (#34)
- `NetworkService.init(baseURL:authService:)` and the memberwise `OAuthState.init(stateToken:…)`
  gained defaulted parameters. Ordinary calls compile unchanged. **Migrate:** only exact
  initializer references (`NetworkService.init(baseURL:authService:)` as a function value) need
  the new full signature or a closure. (#34)
- Removed: the SwiftASN1 conformances on `Int` and `Bool` that Petrel supplied through a
  dependency. **Migrate:** depend on and import SwiftASN1 directly if you use its APIs.
  `RepoOp.cid` is optional (the lexicon allows null). New cases on moved
  enums: `DAGCBORError.depthLimitExceeded`, `.nodeLimitExceeded`, `.unconsumedTrailingBytes`,
  `.invalidLength`; `CARReaderError.blockCIDMismatch`, `.duplicateBlockConflict`. See
  `docs/api-compatibility/0.1.0-spaces-migration.md`. (#34)
- swift-tools-version 6.1 (was 6.0). (#41)

#### Fixed
- A request cancelled before its data task started could hang. (#57)
- `HardenedIdentityHTTPTransport` was released mid-request on Linux ("Session invalidated");
  legacy blob objects round-trip; a `#main` fragment in `$type` is accepted. (#52)
- Rich-text `facetsAsAttributedString` could trap on out-of-range facets. (#44)
- Handle resolution on Apple platforms no longer waits out a timeout when DNS is unavailable.
  (#43)

#### Security
- A `401` from a third-party host (handle host, `did:web` host, PDS-proxied service) no longer
  triggers token refresh, request resend or logout; third-party requests carry no account
  headers and use an ephemeral session. (#43)
- OAuth authorization-server metadata must be HTTPS with an issuer equal to the fetch origin;
  protected-resource metadata, `sub` and granted scopes are checked. (#45)
- Lexicon documents fetched from the network are treated as untrusted input. (#52)
- Explicit encrypted-file credential storage fails closed when the key does not decrypt the
  existing credentials. (#55)
- An encrypted-file credential directory is bound to one key, even while empty: the first
  configuration writes an owner-only `.petrel-key-check` file, and a different key (or a damaged
  check file) fails with the new `EncryptedFileCredentialStorageError.keyMismatch(directory:)`
  before anything is written. Directories from earlier versions gain the file the next time the
  right key opens them. (#65)
- A 401 on a client without an account no longer broadcasts `autoLogout`, and `ExpiredToken` is
  recognised only as the envelope's `error` name, not anywhere in the body. Logged request
  headers redact credentials (Authorization, DPoP, Cookie and any bearer or DPoP value). (#64)

#### Spaces (permissioned data, alpha protocol)

The Spaces lexicons track an unreleased atproto proposal and change between alphas.

##### Added
- `SpaceCredentialManager.get(url:space:audience:maximumArchiveBytes:)`: the optional `maximumArchiveBytes` (default `nil`, unchanged behaviour) replaces the hardened 10 MiB response limit for a single `getRepo` request and bounds that archive's STAR verification, so callers can fetch verified repositories larger than 10 MiB. Values above `SpaceSTAR.defaultMaximumArchiveBytes` (128 MiB) are clamped; other methods ignore it. Existing calls compile unchanged.
- `NetworkService.withResponseLimits(_:operation:)` runs an operation with the given `NetworkResponseLimits` in place of each `NetworkService`'s own limits (10 MiB by default) for every request it sends, so a generated call such as `com.atproto.space.getRepo` or `com.atproto.space.getBlob` can accept a larger response. Each field is clamped to 0...128 MiB (`SpaceSTAR.defaultMaximumArchiveBytes`). The scope covers child tasks and any authentication refresh or retry the requests trigger; scoped requests are not deduplicated with other in-flight requests, and the hardened transport checks are unchanged. Requests outside a scope keep their limits.
- `SpaceCredentialManager.get(url:space:audience:maximumArchiveBytes:maximumBlobBytes:)`: the optional `maximumBlobBytes` (default `nil`, unchanged behaviour) replaces the hardened 10 MiB response limit for a single `getBlob` request, clamped to 128 MiB, as `maximumArchiveBytes` does for `getRepo`. Other methods ignore it, and `maximumArchiveBytes` still does not apply to `getBlob`. Existing calls compile unchanged.

##### Changed
- Spaces lexicons follow the October 29, 2026 alpha (atproto `5d88b414`, npm `0.0.0-spaces-alpha-20261029171913`), byte-identical to upstream. Source-breaking: every `ComAtprotoSimplespace*` type and `ATProtoClient.Com.Atproto.Simplespace` are removed, including `ComAtprotoSimplespaceDefs` and its `publicPolicy`, `memberListPolicy`, `managingAppPolicy`, `open` and `allowList` types. `createSpace`, `updateSpace`, `getSpace` and `deleteSpace` move to `ComAtprotoSpace*` and take or return one `policy` union in place of `readPolicy`, `writePolicy` and `appAccess`; `putMember`, `removeMember` and `listMembers` move to `ComAtprotoMemberspace*`; `checkUserAccess` moves to `ComAtprotoManagedspaceCheckUserAccess`. Added: the policy objects `ComAtprotoPersonalspacePolicy`, `ComAtprotoMemberspacePolicy` and `ComAtprotoManagedspacePolicy`, the records `ComAtprotoSpacePolicy` and `ComAtprotoMemberspaceMember`, and the generated methods `com.atproto.space.clearRecords`, `removeWriter`, `importRepo`, `exportSpaceMeta` and `importSpaceMeta`. `getSpaceCredential` documents that `SpaceNotFound` may stand in for `UserNotAuthorized`, and the `SpaceCredentialError` description for `SpaceNotFound` now reads "not found or not authorized". Classification is unchanged.
- Regenerated Swift and Kotlin SimpleSpace APIs against the September 10 Spaces alpha (`9d787ebf`): independent `readPolicy`/`writePolicy`, `putMember` with required read/write flags, and access-specific managing-app checks. The obsolete `addMember` endpoint is removed.
- Spaces lexicons follow the October 22, 2026 alpha (atproto `ac0c9f15`, npm `0.0.0-spaces-alpha-20261022141228`), byte-identical to upstream. Source-breaking changes from the October 1 alpha (`679724ad`): `ComAtprotoSimplespaceCreateSpace.Input.type` and `ComAtprotoSpaceListSpaces.Parameters.type` are now `spaceType`; `ComAtprotoSpaceNotifyWrite.Input.rev` and `ComAtprotoSpaceListRepos.Repo.rev` are now `repoRev`. `notifyWrite` adds optional `spaceRev`/`prevSpaceRev` and typed `SpaceNotFound`/`FutureRev` errors; `listRepos` entries add `spaceRev`, and its cursor is an exclusive space-revision checkpoint. Source-breaking changes from the October 22 alpha: `ComAtprotoSpaceDefs.SignedCommit`, which carried `hash`, `ikm`, `sig` and `mac`, is replaced by `ComAtprotoSpaceDefs.Commit` (`ver`, `space`, `repo`, `rev`, `data`); `hash` is now `data` in `notifyWrite` input and `listRepos` entries; `ComAtprotoSpaceGetSpaceCredential.Input` requires `credentialKid` and takes an optional `delegationToken`; `getRepo` returns a STAR archive (`application/octet-stream`) and drops `excludeValues`; `getLatestCommit`, `getRecord`, `getRepo` and `listRepoOps` declare `BadSpaceMac`.
- `SpaceCredentialManager` follows the October 22 credential flow. The `getSpaceCredential` exchange sends the space, a fresh P-256 `did:key` as `credentialKid`, the delegation token and any client attestation in its JSON body, with no Authorization header or HTTP signature; the returned credential's JWT header must name `#atproto`. `get(url:space:audience:)` sends `Authorization: Atproto-Space-Credential <credential>`, `Atproto-Space-Audience` (the `repo` DID, else the space authority DID), and an HTTP Message Signature over both under the `atproto-space-credential` label and tag, replacing Spaces DPoP. For `getLatestCommit`, `getRepo`, `listRepoOps` and `getRecord` it requests and verifies a response MAC keyed to the author's `#atproto_kem` key, and it returns a `getRepo` archive only after full STAR verification. A `401 CredentialRevoked` response drops the cached credential. Ordinary OAuth DPoP is unchanged.

##### Fixed
- `SpaceCredentialManager` reuses a cached space credential until its `exp` less min(60 s, half its issued lifetime `exp - iat`), bounded by that lifetime from local receipt. The previous flat 60 s margin never reused a 60 s credential, so every read repeated the delegation and credential exchange.
- Credential-exchange errors keep their protocol names. `SpaceNotFound` at HTTP 400 (the reference host) or 404 (Swan) is now `SpaceCredentialError.authorizationRefused` with error `SpaceNotFound` (previously `exchangeFailed`, which dropped the name or kept it only inside the raw body); it never means deletion. `InvalidClientAttestation` remains `tokenRejected` with that error name, but its description names the client attestation instead of the delegation token, and it no longer triggers the `describeServer` evidence probe. No enum cases were added, so exhaustive switches still compile.
- `SpaceHostResolver.fetchDIDDocument(for:urlSession:limits:)` (when no `urlSession` is passed) and `SpaceHostResolver.fetchBoundedPublicJSON(from:limits:fixtureSession:)` invalidate the hardened session they create for each call once its request finishes. URLSession keeps a strong reference to its delegate until it is invalidated, so every call previously leaked that session and its delegate.
- A `SpaceHostResolver` or `SpaceCredentialManager` that creates its own session (no `urlSession` passed) invalidates it when it is released, so a short-lived resolver or manager no longer leaks its session and delegate. A session passed in remains the caller's to invalidate.
- `com.atproto.space` and `com.atproto.simplespace` lexicons are re-vendored verbatim from bluesky-social/atproto PR #5187 (`57b0a0424fb27d8e4989e74fa37fbc0ce4527ded`). This replaces a non-upstream `com.atproto.space.defs#signedCommit` shape (a "v2 authenticated transition" with optional `did`, `space`, `prevRev`, `prevHash`, `path`, `action`, `cid`, `prevCid`, `val` and optional `ikm`/`mac`) with the upstream v1 shape, where `ikm` and `mac` are required and the v2-only fields no longer exist. This is a source-breaking change for code that constructed or read the removed fields. The same vendor drop replaces `simplespace.addMember` with `simplespace.putMember` and adds `space.notifyCredentialRevoked`. The October 22 alpha later replaced that `signedCommit` shape with `#commit` (see Changed).

### PetrelCore (new product)
- CID, DAG-CBOR, DAG-JSON bridge and CAR reading, extracted from `Petrel` (which re-exports
  it). `Dictionary` conforms to `DAGCBOREncodable`. (#34, #38, #52)

### PetrelCrypto (new product)
- P-256 and K-256 keypairs behind one `ATProtoSigner` / `ATProtoKeypair` / `ATProtoPublicKey`
  API, `did:key` and Multikey encoding, low-S signing and strict low-S verification (with an
  explicit opt-in for malleable signatures), external signers and a Secure Enclave signer on Apple
  platforms. (#41)
- `ServiceJWT` signing with any signer on both curves, and `ServiceAuthVerifier`, which checks
  signature, `aud`, `lxm`, lifetime and clock skew using a pluggable issuer-key resolver
  (`Petrel` supplies one that reads the issuer's DID document). Verified against
  reference-generated vectors. (#41, #49)
- PetrelCrypto service JWTs can bind an XRPC request body through the `requestBodyDigest` claim.
- K-256 uses `21-DOT-DEV/swift-secp256k1` (module `P256K`) in place of the GigaBitcoin package.
  (#41, #56; decision D10)
- `P256Keypair` and `K256Keypair` no longer expose the private scalar through `dump` or `Mirror`;
  their reflection shows only the public `did:key`. (#70)
- Strict JWT verification reports a high-S signature with the same
  `.unauthorized("JWT signature is not a canonical low-S compact signature")` on P-256 and K-256
  (P-256 used to throw `.malformed`). (#70)
- `CachingServiceAuthKeyResolver` follows an issuer's key rotation at the first forced refresh
  instead of refusing its tokens for up to 30 seconds; forced refreshes are still rate-limited.
  (#70)

### PetrelRepo (new product)
- Repository primitives: Merkle Search Tree, commits, CAR import and export, record proofs.
- `Repository`: open a repository from a CAR (verifying the commit signature and the whole
  tree), list and fetch records, build and verify inclusion and exclusion proofs, apply writes as
  a new signed commit with its diff CAR, and export. `Repository.create` starts an empty one and
  refuses, before signing, a first commit its own limits could not export. (#48)
- Commits are signed and verified on P-256 and K-256 through `ATProtoRepositoryCommitSigner`
  (any `ATProtoSigner`); high-S signatures are refused, and legacy version 2 commits and a
  non-null `prev` can be read. (#48)
- Every ceiling is configurable through `PublicRepositoryLimits`; `.networkScale` (what
  `Repository` uses) admits 20 million records. A commit that would cross one throws
  `RepositoryError.limitExceeded(_:limit:)` with a `RepositoryLimitKind` (`.records`, `.mstNodes`,
  `.carBlocks`, `.carBytes`, `.blockBytes`); a record that does not decode throws
  `.invalidRecord(path:)`. Imports stream into a `RepositoryBlockStore`, file-backed or in
  memory. (#48)
- `RepositoryCommitDiff` computes diffs with their covering proofs, verifies operation inversion,
  and verifies a firehose `#commit` or `#sync` event from its own fields. `PetrelFirehose` does not
  call it yet. (#48)
- Tested against the official MST, data-model and commit-proof vectors and a real exported
  repository (1,868 records, K-256); exercised up to 250,000 records. (#48)
- **Breaking:** `CID.parse` rejects non-canonical strings, and `CARReader` requires a version and
  at least one root. Structural CIDs must be in the blessed format; links inside record data are
  still accepted on read and kept byte for byte. `PetrelCID` is deprecated (use `CID`). (#48)

### PetrelPLC and PetrelPLCPDS (new products)
- Read every operation a PLC directory serves (document, data, operation log, audit log, last
  operation, export as an async sequence), verify audit chains including the 72-hour recovery
  window, create (including legacy genesis operations) and sign updates with any
  `ATProtoSigner` on either curve. Reads are lenient and writes strict; directory errors are typed
  (`.notFound`, `.rejected`, `.rateLimited`, `.unavailable`). (#47)
- `PetrelPLCPDS`: change a `did:plc` identity through the PDS that hosts the account. (#47)
- The one-call update helpers work for identities whose current operation repeats a rotation key
  or alias, including legacy accounts whose recovery key equals their signing key. (#70)
- `PLCClientConfiguration.production()` checks writes against
  `PLCOperationLimits.referenceDirectory` (plc.directory's 4,000-byte, 10-alias, 10-service
  limits) by default, so an operation plc.directory would reject is refused before it is sent.
  Pass `operationLimits: .specification` for the previous limits. (#70)

### PetrelFirehose and PetrelJetstream (new products)
- `EventStreamSubscription<Message>` for any Lexicon subscription, `LabelSubscription`, the
  repository firehose with commit verification, and a Jetstream client (`/subscribe`,
  `options_update`, zstd). Unknown message types are skipped, sequence gaps are reported as
  events, error frames end the stream with a typed `EventStreamError`, reconnection with the last
  cursor is opt-in, and consumption is pull-based so a slow consumer applies backpressure. (#42)
- The WebSocket transport is replaceable (`FirehoseWebSocketSessionFactory`). The built-in
  `URLSession` transport needs a WebSocket-capable libcurl on Linux; see LINUX_SUPPORT.md.
- Jetstream reports frames it cannot use (malformed, undecompressable, unknown type, undecodable
  payload, duplicate `seq`) as `JetstreamSubscriptionEvent.ignoredFrame(JetstreamIgnoredFrame)`
  instead of dropping them silently; on the v2 API the cursor moves past one that carries a new
  `seq`. A compressed frame that does not decompress no longer reconnects at the same cursor
  forever. **Breaking** for exhaustive switches: add `case .ignoredFrame: break` to keep the old
  behaviour. (#61)
- A failed cursor `loadCursor()` or `saveCursor(_:)` ends the Jetstream stream with
  `JetstreamSubscriptionError.cursorStorageFailure(operation:message:)`; a failed load used to
  start silently at the live tip. (#61)

### PetrelLexicon and PetrelOzone (new products)
- `PetrelLexicon`: parse Lexicon documents (`LexiconDoc`), hold them in a `LexiconCatalog`,
  validate data against them (`LexValue`), and resolve schemas from the network
  (`DefaultLexiconResolver`). Checked against the official Lexicon interop vectors. `LexValue`
  decoded through `Codable` keeps Foundation's 38-significant-digit limit; use `LexValue(json:)`
  to reject such numbers. (#52; decision D12)
- `PetrelOzone`: the generated `tools.ozone` moderation-service API. (#52)

### PetrelOAuthScopes (new product)
- One OAuth scope and permission grammar (`ATProtoScope`, `ATProtoScopeSet`, permission sets
  and `include:` expansion) shared by the OAuth client and server. Accept/reject and canonical
  form follow the TypeScript reference; the cases where that differs from the spec text are
  documented and pinned by tests. `ScopePermission.grantingScope(for:)` returns a scope string
  only when it parses back and covers the target. (#46; decisions D9, D14)

### PetrelOAuthServer (new product)
- A framework-agnostic AT Protocol OAuth authorization server and resource-server verifier
  (`OAuthResourceServerVerifier`): PAR, PKCE S256, DPoP with nonces and replay protection,
  ES256/ES256K, `private_key_jwt` and loopback clients, refresh-token rotation with family
  revocation, revocation, metadata, and permission sets. Interoperates with
  `@atproto/oauth-client-node`. (#51)
- Client metadata is fetched only over a transport that pins the addresses it approved, which
  closes a DNS-rebinding hole; any other transport is refused unless the host sets
  `OAuthRemoteFetchPolicy.allowsUnpinnedTransport`. There is no default transport. (#51;
  decision D13)
- Signed (`.signedJWT`) access tokens are capped at 15 minutes, since a stateless resource server
  cannot see a revocation; a configuration with a longer lifetime now fails validation, and the
  verifier refuses longer signed tokens. Opaque tokens keep the 30-minute limit. (#63)
- Expired state is purged while the server handles requests, at most once per
  `expiredStatePurgeInterval` (5 minutes by default, `nil` to turn off); hosts can call
  `purgeExpiredState()` themselves. (#63)
- `retiringAccessTokenKeys` are published in `/oauth/jwks` after the current key and still
  accepted, for key rotation. (#63)
- Each authorization has its own flow cookie, so two tabs or two applications signing in at once
  no longer overwrite each other. (#63)

### PetrelOAuthServerLexicon (new product)
- `AuthenticatedOAuthLexiconResolver` resolves `include:` permission sets the way
  `@atproto/lex-resolver` does: DNS `_lexicon` TXT to a DID, the DID document to the PDS and key,
  then `com.atproto.sync.getRecord`, accepting the record only when the signed commit, the DID and
  the MST proof all check out. Every fetch goes through the address-pinning transport rules
  (D13). Without it, the authorization server refused every `include:` scope unless the host wrote
  its own resolver. (#62)

### Server/ (nested package)
- `PetrelOAuthServerHummingbird` (HTTP adapter plus the address-pinning NIO transport) and the
  runnable `petrel-oauth-server-example`. (#51)
- The connection's client address reaches the account authenticator (`OAuthServerRequestContext`);
  `clientAddress: .forwardedFor(trustedProxies:)` uses `X-Forwarded-For` only from a trusted
  proxy. `ExampleServer.router()` returns `Router<OAuthServerRequestContext>`. The example server
  uses `AuthenticatedOAuthLexiconResolver`. (#62, #63)

### Kotlin bindings
- Binary-output endpoints return raw bytes. (#37)
- Kotlin 2.4, Ktor 3.6, Gradle 9.9 with a checksum-verified wrapper; regenerated with the
  Spaces lexicons. (#33, #36, #38, #56)

### Generator
- Any NSID shape and every Lexicon definition type; invalid Lexicons are refused; CI requires
  regeneration to produce an empty diff; the `petrel-lexgen` package plugin generates Swift from
  your own Lexicons. (#52)
- An inline object whose generated name collides with a named definition gets an `Object` suffix
  instead of failing generation. (#66)
- CI: a scheduled `Live network smoke` workflow runs the firehose, labeler, Jetstream and identity
  live tests (never on pull requests). (#61)

### Dependencies
- swift-crypto `"3.15.1"..<"6.0.0"`, swift-log 1.15.1 or later, swift-async-dns-resolver
  `0.8.x`, swift-secp256k1 `0.25.x`, swift-docc-plugin from the `swiftlang` organisation,
  vendored BLAKE3 1.8.7. (#56)

## [1.0.0] – [1.1.0] - 2026-07-17 to 2026-08-18

Released as tags 1.0.0 through 1.1.0 (prepared as a release candidate before the 1.x tags
were cut; recorded together here).

### Added
- Exact typed AT Protocol errors for generated queries and procedures.
- A lossless DAG-CBOR/DAG-JSON bridge for Blob, Bytes, CID, null, and integer values within the signed 64-bit range.
- A generated-value-container decoder that preserves primitive roots, special link/byte objects, unknown fields, and re-encodable fallback values.
- Deterministic generated-source ownership, stale-file removal, and pinned release tooling.
- A two-overlay compiler fixture proving PetrelCatbird and PetrelBluemoji can extend one Petrel-owned `Blue` namespace.
- A fail-closed DocC validator that treats documentation diagnostics as errors and compile-checks every Swift example in the public guides under the sealed release toolchain.

### Changed
- Generated namespace reference classes are immutable `Sendable` structs. This was an intentional source compatibility break for code that named or relied on namespace class identity.
- Petrel now owns shared overlay namespace roots; overlays add only their child namespaces.
- Public installation documentation targets the iOS 18/macOS 15 platform floors.
- The SPM release gate is explicitly Swift-scoped; Kotlin publication and parity remain outside it.
- PetrelLoad rejects unsupported scenarios and invalid base URLs, propagates OAuth setup and verification failures, and exits nonzero when stress requests fail.

### Fixed
- Generated wire discriminators preserve exact lexicon fragments, including underscore-bearing Bluemoji format identifiers.
- Declared endpoint errors use exact protocol names instead of embedding descriptions in raw values.
- DAG-CBOR decoding rejects invalid ATProto link CIDs and malformed/out-of-range numeric values without losing valid unpadded byte values.
- Registered typed values preserve their top-level `$type` framing across JSON and DAG-CBOR container round trips.
- Generated endpoints receive declared terminal HTTP errors after the existing authentication and retry pipeline, allowing their typed error parsers to inspect the real response body.
- Regeneration removes only stale files carrying Petrel's exact generated-source ownership header.
- Authentication refresh callers now await the shared refresh task and receive its actual result or failure instead of an early success result.

## [0.1.0] - 2026-06-12

### Added
- MIT LICENSE.
- Manifest-driven code generation (`python3 run.py --manifest <file>`): configurable lexicon dirs, namespace exclusions, per-language outputs.
- **Overlay packages**: generate extra lexicon namespaces as a separate Swift/Kotlin package against the public core (`package.kind: "overlay"`), including namespace extensions and `ATProtocolValueContainer.registerDecoder` registration.
- Configurable keychain accessibility (`KeychainAccessibility`), default `afterFirstUnlockThisDeviceOnly`.
- `ATProtoClient.defaultBaseURL` constant.
- Typed decoder registry on `ATProtocolValueContainer` (`registerDecoder(forType:)`).

### Changed
- **OAuth reliability overhaul**: refresh tokens are only marked consumed on success or definitive `invalid_grant`; transient failures (timeout, offline, 5xx) are retried with the same token. Rotated sessions survive keychain write failures (retry + pending-key + in-memory fallback). Session writes are newest-wins; recovery never resurrects an older session. Pre-refresh session reads bypass the in-memory cache (cross-process safety with app extensions).
- All standard lexicons synced to bluesky-social/atproto (incl. chat.bsky group chats GA, `getUnreadCounts`, `tools.ozone.queue/report`).
- Generated namespace accessors are now lowerCamelCase (`client.app.bsky.authManageLabelerService`); old all-lowercase names remain as deprecated aliases for one release.
- Malformed *optional* fields in responses/records decode to `nil` with a warning instead of failing the whole response.
- Sensitive values in DEBUG logs are truncated again (full-token logging removed).
- atproto syntax validators (handle/DID/record-key/TID/datetime) now pass the official interop fixtures.
- `NetworkService`, `LogManager`, and generated namespace classes are `public` (overlay-package SPI; pre-1.0 surface).

### Removed
- `blue.catbird.*` and `place.stream.*` lexicons and generated types — moved to the private PetrelCatbird overlay package.
- Dead code: `OAuthCallbackBuffer` (stored authorization codes in plaintext UserDefaults), `SafeDecoder`, `CIDTestUtility`.
- All `print()`/`fputs()` calls in library code (routed through `LogManager`).

### Fixed
- "Session expired early": a transiently-failed refresh permanently poisoned the refresh token in-process until app restart.
- Loss of rotated refresh token when the keychain write failed after a successful refresh.
- Stale `session.backup`/`session.temp` could resurrect an already-rotated refresh token.
- Linux: secure-storage initialization failure no longer calls `fatalError` (throws `KeychainError.storageUnavailable`).
