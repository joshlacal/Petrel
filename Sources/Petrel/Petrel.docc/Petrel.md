# ``Petrel``

A Swift 6 SDK for the AT Protocol and Bluesky: typed XRPC calls, OAuth, identity, and Bluesky helpers.

## Overview

Petrel is a Swift 6 SDK for the AT Protocol and Bluesky. The `Petrel` module gives you
``ATProtoClient``, which carries a typed method for every query, procedure and
subscription in the bundled Lexicons (`com.atproto.*`, `app.bsky.*`, `chat.bsky.*`),
grouped by NSID: `app.bsky.feed.getTimeline` is `client.app.bsky.feed.getTimeline`.
Authentication (atproto OAuth with PAR, PKCE and DPoP, or app passwords), token refresh,
service routing and retries apply to every call. Start with <doc:GettingStarted>.

For Bluesky apps, `client.bsky` (``ATProtoClient/bsky``) returns a ``BskyAgent`` with
higher-level helpers: posting with rich-text facets, images and replies, the social-graph
verbs, preferences, and moderation decisions. See <doc:BlueskyPosting>,
<doc:BlueskyModeration> and <doc:BlueskyPreferences>.

To generate the same typed API for your own Lexicons, see <doc:CustomLexicons>.

### Modules

Petrel is split into products so you link only what you use:

| Product | Purpose |
| :--- | :--- |
| `Petrel` | Client SDK: ``ATProtoClient``, ``BskyAgent``, ``RichText``, ``Moderation``, ``OAuthConfig``, ``IdentityResolver``, and the generated `com.atproto`, `app.bsky` and `chat.bsky` API |
| `PetrelCore` | IPLD data model with no networking: `CID`, `DAGCBOR`, `OrderedCBORMap`, `CARReader`, `JSONCoders` |
| `PetrelCrypto` | P-256 and secp256k1 signing (including Secure Enclave P-256), `did:key` codecs, service-auth JWTs |
| `PetrelRepo` | Repository engine: commits, CAR files and Merkle Search Trees |
| `PetrelFirehose` | Event-stream consumers for `com.atproto.sync.subscribeRepos` and other subscriptions |
| `PetrelJetstream` | Jetstream client (JSON, optional `zstd` compression) |
| `PetrelPLC` | `did:plc` directory client and audit-log verification |
| `PetrelPLCPDS` | PLC identity updates coordinated with a PDS |
| `PetrelOAuthScopes` | The atproto permission-scope grammar (`repo:`, `rpc:`, `blob:`, `account:`, `identity:`, `include:`); re-exported by `Petrel` |
| `PetrelOAuthServer` | An embeddable atproto OAuth authorization server |
| `PetrelOAuthServerLexicon` | Lexicon resolution for `include:` permission sets |
| `PetrelOAuthServerNIO` | Address-pinning SwiftNIO transport (`PinnedNIOOAuthRemoteTransport`) for `PetrelOAuthServer` on any server framework (needs the `OAuthServerNIO` package trait) |
| `PetrelOAuthServerHummingbird` | Hummingbird adapter for `PetrelOAuthServer` (needs the `OAuthServerHummingbird` package trait, which enables `OAuthServerNIO`) |
| `PetrelLexicon` | Runtime Lexicon schema validation and Lexicon resolution |
| `PetrelOzone` | Generated `tools.ozone.*` moderation and administration API |

Each module other than `Petrel` has its own documentation. <doc:StreamingAndVerification>
shows how the streaming and repository modules fit together.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ArchitectureAndMentalModel>
- <doc:RosettaStone>
- <doc:StreamingAndVerification>

### Client & Networking

- ``ATProtoClient``
- ``AuthMode``
- ``ATProtocolValueContainer``
- ``ATProtoError``
- ``NetworkError``

### XRPC & Lexicons

- <doc:XRPCClient>
- <doc:CustomLexicons>
- <doc:CustomLexiconsAndOverlays>
- ``ATProtoXRPCError``
- ``XRPCResponseDecodingError``
- ``XRPCCallOptions``
- ``XRPCResponse``
- ``XRPCResponseMetadata``
- ``XRPCRateLimit``
- ``XRPCLabeler``
- ``XRPCPages``
- ``XRPCCursorPaginatedParameters``
- ``XRPCCursorPaginatedOutput``
- ``EventStreamError``
- ``ATProtoNullable``
- ``CIDString``
- ``LexiconPermissionSet``
- ``LexiconRecordKeyType``

### Authentication, OAuth & Scopes

- <doc:Authentication>
- <doc:OAuthClient>
- ``OAuthConfig``
- ``GatewayConfiguration``
- ``AuthError``
- ``AccountStatus``
- ``AccountStatusError``
- ``CredentialStorageConfiguration``

### Bluesky Agent, Rich Text & Moderation

- <doc:BlueskyPosting>
- <doc:BlueskyModeration>
- <doc:BlueskyPreferences>
- ``BskyAgent``
- ``BskyAgentError``
- ``RichText``
- ``RichTextSegment``
- ``PostEmbed``
- ``PostImage``
- ``ImageMetadataStripper``
- ``Moderation``
- ``ModerationOptions``
- ``ModerationDecision``
- ``BskyPreferences``

### Identity, Identifiers & Service Auth

- <doc:Identity>
- <doc:Identifiers>
- <doc:ServiceAuthentication>
- ``IdentityResolver``
- ``ResolvedIdentity``
- ``DIDDocument``
- ``DID``
- ``Handle``
- ``ATIdentifier``
- ``NSID``
- ``RecordKey``
- ``TID``
- ``TIDGenerator``
- ``ATProtocolURI``
- ``ATProtocolDate``
- ``LanguageTag``
- ``LanguageCodeContainer``
- ``URI``
- ``CIDSyntax``
- ``ATProtocolError``
