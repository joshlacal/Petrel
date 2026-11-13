# Architecture and the AT Protocol Mental Model

How identity, Personal Data Servers, repositories, relays, AppViews and OAuth fit together, and which Petrel module covers each.

## Overview

Developers arriving at the AT Protocol from traditional REST APIs often ask a fair question: *why are there DIDs alongside handles, why do writes go to a Personal Data Server while timeline reads go to an AppView, and why does OAuth bind every token to a key held by the client?*

This article walks through the five building blocks of the protocol. Petrel follows the same boundaries with separate Swift products, so an iOS app, a Jetstream indexer, a custom Lexicon package and a server-side OAuth provider can each link only the layers they need.

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           Your Swift Application                           │
└───────────────┬─────────────────────────────┬──────────────────────────────┘
                │ Authenticated XRPC + DPoP   │ WebSocket / HTTP Backfill
                ▼                             ▼
┌───────────────────────────────┐   ┌────────────────────────────────────────┐
│  Personal Data Server (PDS)   │   │       Relays & Event Streams           │
│  • Stores user's signed Repo  │──▶│  • Firehose (DAG-CBOR + MST proofs)    │
│  • Hosts blobs                │   │  • Jetstream (filtered JSON + zstd)    │
│  • Proxies atproto-proxy RPCs │   └───────────────────┬────────────────────┘
└───────────────┬───────────────┘                       │ Indexes commits
                │ Mints short-lived Service JWT         ▼
                │                           ┌────────────────────────────────┐
                └──────────────────────────▶│   AppViews & Microservices     │
                                            │  • Bluesky AppView (app.bsky)  │
                                            │  • Chat Service (chat.bsky)    │
                                            │  • Labelers & Feed Generators  │
                                            └────────────────────────────────┘
```


## The Five Protocol Pillars

### 1. Identity: `DID` vs. `Handle`

Every account in the ATmosphere has **two** identifiers with deliberately separated jobs:

- **`Handle` (`alice.bsky.social`, `atproto.com`)**: A human-readable domain name that can change whenever the user switches domains or providers without breaking their social graph, posts, or followers.
- **`DID` (`did:plc:...` or `did:web:...`)**: A permanent cryptographic account identifier. Every record `at://` URI, follow, like, and OAuth token `sub` claim anchors to the `DID`, never the handle.

A handle is trusted **only when verified bidirectionally**:

1. **Forward (`Handle → DID`)**: Querying `_atproto.<handle>` via DNS TXT or `https://<handle>/.well-known/atproto-did` yields a candidate DID.
2. **Reverse (`DID → DID Document`)**: Resolving the DID document (from `https://plc.directory` for `did:plc`, or `https://<host>/.well-known/did.json` for `did:web`) confirms `alsoKnownAs` lists `at://<handle>`, exposes the `#atproto` repository signing public key (`P-256` or `secp256k1`), and advertises the `#atproto_pds` service endpoint where the account currently lives.

In Petrel, ``IdentityResolver`` performs full bidirectional resolution without requiring an authenticated client, while `PetrelPLC` (`PLCDirectoryClient` and `PLCAuditLogVerifier`) cryptographically audits the underlying `did:plc` operation chain.

### 2. Personal Data Servers (`PDS`), Repositories, and `MST`s

Unlike centralized social APIs where user posts live only in an application database, an AT Protocol user's public records live in a **signed v3 repository** hosted on their Personal Data Server (`PDS`):

- Records are keyed by `<collection>/<rkey>` — for example, `app.bsky.feed.post/3k2yihcrp6f2c` — where the collection is a Lexicon NSID and the record key is typically a monotonic timestamp identifier (``TID``).
- Every record is serialized as deterministic **DAG-CBOR** and addressed by its SHA-256 **CIDv1** (`PetrelCore`).
- Paths are organized in a **Merkle Search Tree (`MST`)** whose root CID is signed by the account's `#atproto` key on every commit (`PetrelRepo`).
- Whole repositories and per-commit diffs travel over the wire as **CAR v1** archives (`CARReader`, `PublicRepositoryCAR`).

Because repositories are self-certifying, an account can migrate from one PDS host to another while keeping every `at://did:plc:.../collection/rkey` link and signature intact.

### 3. Relays, the Firehose, and Jetstream

Downstream services do not poll thousands of individual PDS hosts. Instead, **Relays** aggregate repository commits across the network into real-time streams:

| Stream | Wire Format | Cryptographic Proofs | Best For | Petrel Module |
| :--- | :--- | :--- | :--- | :--- |
| **Firehose** (`com.atproto.sync.subscribeRepos`) | Binary DAG-CBOR + inline diff CARs | Yes — commit signatures + MST inclusion/exclusion proofs (verification is opt-in in Petrel) | Full indexers, labelers, verifiers | `PetrelFirehose` + `PetrelRepo` |
| **Jetstream** (`network.bsky.jetstream.subscribeEvents` / `/subscribe`) | UTF-8 JSON (optional `zstd`), plus archive backfill on hosts that offer it | Trusting the Jetstream host | App backends, bots, custom Lexicon indexers filtering 1–2 collections | `PetrelJetstream` |

### 4. AppViews and Service Proxying (`atproto-proxy`)

A PDS stores raw records (`com.atproto.repo.createRecord`, `putRecord`, `uploadBlob`), but it does not know how to assemble a hydrated Bluesky home timeline or search the global social graph. That is the job of an **AppView** (`did:web:api.bsky.app#bsky_appview`) or specialized service (`did:web:api.bsky.chat#bsky_chat`).

When an authenticated ``ATProtoClient`` calls `client.app.bsky.feed.getTimeline(input:)`:

1. Petrel sends the request to **your user's PDS** with DPoP-bound OAuth credentials and attaches `atproto-proxy: did:web:api.bsky.app#bsky_appview`.
2. Your PDS authenticates you, mints a short-lived service-auth JWT signed with your account's signing key, and forwards the call to the AppView. (`PetrelCrypto` can mint and verify such tokens if you build a service; see <doc:ServiceAuthentication>.)
3. Account-local endpoints such as `com.atproto.repo.*`, `app.bsky.actor.getPreferences` and `app.bsky.actor.putPreferences` go to the PDS itself without an `atproto-proxy` header.

### 5. OAuth with PAR, PKCE, and DPoP

In an open network with many independent PDS hosts, your app cannot register with every authorization server in advance. The [AT Protocol OAuth profile](https://atproto.com/specs/oauth) solves this with three mechanisms handled automatically by ``ATProtoClient``:

- **Client Metadata Discovery**: Your `client_id` is an `https://` URL hosting your `client-metadata.json` document (or `http://localhost?...` during local development, via ``OAuthConfig/loopback(port:path:scope:)``).
- **Dynamic Server Discovery + PAR + PKCE**: Given a handle like `alice.example.com`, Petrel resolves Alice's DID → PDS → Protected Resource Metadata → Authorization Server Metadata, then submits a Pushed Authorization Request (`PAR`) with PKCE `S256`.
- **Sender-Constrained DPoP (`ES256`)**: Every token exchange, refresh, and XRPC call carries a fresh Proof-of-Possession JWT signed by a per-session P-256 key kept in the client's secure storage, retrying automatically when a PDS or Authorization Server rotates its `DPoP-Nonce`.


## Mapping protocol concepts to Petrel modules

The main library products, by protocol layer (the landing page lists every product):

| Library Product | Protocol Layer | Key Types | Typical Consumer |
| :--- | :--- | :--- | :--- |
| **`Petrel`** | Full Client SDK, Lexicons, OAuth Client, Bluesky Agent | ``ATProtoClient``, ``BskyAgent``, ``RichText``, ``Moderation``, ``OAuthConfig``, ``IdentityResolver`` | iOS, macOS, tvOS, and Linux client apps |
| **`PetrelCore`** | IPLD Data Model, CIDv1, DAG-CBOR, CAR v1 | `CID`, `DAGCBOR`, `OrderedCBORMap`, `CARReader`, `JSONCoders` | Lightweight CLI tools, storage engines |
| **`PetrelCrypto`** | `P-256` & `secp256k1` keys, `did:key`, Service Auth JWTs | `ATProtoCrypto`, `P256Keypair`, `K256Keypair`, `ServiceJWT`, `ServiceAuthVerifier` | Feed generators, labelers, custom verifiers |
| **`PetrelRepo`** | v3 Repository Engine, Merkle Search Trees (`MST`), Genesis | `PublicRepositoryEngine`, `RepositoryMST`, `PublicRepositoryGenesisCodec`, `PublicRepositoryRecordCodec` | PDS implementations, offline CAR/MST tooling |
| **`PetrelFirehose`** | Binary relay firehose; opt-in repository verification | `FirehoseSubscription`, `RelayFullRepositoryVerifier`, `RelayRepositoryVerificationState` | Relay consumers, cryptographic repo auditors |
| **`PetrelJetstream`** | Jetstream v1/v2 Streaming + Snapshot Backfill (`zstd`) | `JetstreamClient`, `JetstreamSubscription`, `JetstreamFilter`, `JetstreamEvent` | Real-time bots, custom Lexicon AppViews |
| **`PetrelPLC`** | `did:plc` Directory Client & Offline Audit-Log Verifier | `PLCDirectoryClient`, `PLCAuditLogVerifier`, `PLCVerifiedAuditLog` | Identity tooling, account recovery & auditing |
| **`PetrelPLCPDS`** | Coordinated PDS ↔ PLC Signed Identity Operations | `PLCPDSOperationFlow` | Account migration & handle/key rotation tools |
| **`PetrelOAuthScopes`** | Typed ATProto Permission Grammar (`repo:`, `rpc:`, `blob:`) | `ATProtoScope`, `ATProtoScopeSet`, `IncludeScope` | Fine-grained OAuth clients & auth servers |
| **`PetrelOAuthServer`** | Embeddable ATProto OAuth 2.1 Authorization Server | `OAuthAuthorizationServer`, `OAuthResourceServerVerifier`, `OAuthDPoPProofValidator` | Self-hosted PDS & entryway servers |

> Note: `Petrel` re-exports `PetrelCore`, `PetrelCrypto` and `PetrelOAuthScopes`, so an app that needs only those layers depends on `.product(name: "Petrel", package: "Petrel")` alone. The streaming, repository, PLC and server modules are separate products you add and import yourself.

<!-- compile-example: arch-modular-imports -->
```swift
import Foundation
import Petrel
import PetrelFirehose
import PetrelJetstream
import PetrelPLC
import PetrelRepo

func configureModularStack() throws {
    // 1. Identity & PLC audit layer (PetrelPLC)
    let plc = try PLCDirectoryClient()
    _ = plc.configuration.origin

    // 2. Filtered JSON event streaming + backfill (PetrelJetstream)
    let jetstream = JetstreamClient(
        configuration: .init(
            host: URL(string: "https://jetstream2.us-east.bsky.network")!,
            mode: .live(),
            filter: JetstreamFilter(kinds: [.commit], collections: ["app.bsky.feed.post"])
        )
    )
    _ = jetstream.configuration

    // 3. Binary relay firehose with cursor persistence (PetrelFirehose)
    let firehose = FirehoseSubscription(
        url: URL(string: "wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos")!,
        cursorStorage: InMemoryFirehoseCursorStorage(),
        autoAcknowledge: true
    )
    _ = firehose.configuration

    // 4. Repository path & MST depth calculation (PetrelRepo + PetrelCore)
    let path = try PublicRepositoryPath(
        collection: "app.bsky.feed.post",
        recordKey: "3jzfcijpj2z2a"
    )
    print("MST path: \(path.mstKey) (depth \(path.keyDepth))")
}
```


## Choosing an Authentication Mode (`AuthMode`)

``ATProtoClient`` supports five modes through ``AuthMode``; the XRPC call sites are the same in all of them:

| Mode | Initializer / Enum Case | Where Keys Live | When to Use It |
| :--- | :--- | :--- | :--- |
| **Unauthenticated** | `await ATProtoClient(baseURL:)` (`.none`) | None | Public AppView queries (`https://public.api.bsky.app`), handle resolution, public repo reads |
| **Public OAuth** | `.publicOAuth` *(default)* | Client secure storage (DPoP `ES256`) | Native iOS, macOS, and desktop apps talking directly to the user's PDS (and localhost dev via `OAuthConfig.loopback`) |
| **Confidential Gateway** | `.gateway` + `gatewayURL:` | Backend BFF server | Mobile or web apps routing traffic through a confidential OAuth Backend-for-Frontend proxy |
| **Client Assertion Backend** | `.cab(backendURL:)` | Device DPoP + Backend `private_key_jwt` | Confidential apps that talk directly to the user's PDS while minting DPoP-bound client assertions on a backend |
| **Legacy App Password** | `.legacy` | Client secure storage (Bearer JWT) | CLI scripts, CI bots, or legacy servers that do not yet advertise OAuth metadata |

<!-- compile-example: arch-auth-modes -->
```swift
import Foundation
import Petrel

func buildClientsForEveryTopology() async throws {
    // 1. Unauthenticated client against the public Bluesky AppView
    let publicClient = await ATProtoClient(
        baseURL: URL(string: "https://public.api.bsky.app")!
    )
    _ = publicClient

    // 2. Public native OAuth (PAR + PKCE + device-bound DPoP)
    let nativeOAuth = OAuthConfig(
        clientId: "https://app.example.com/oauth/client-metadata.json",
        redirectUri: "com.example.app:/oauth/callback",
        scope: "atproto transition:generic"
    )
    let nativeClient = try await ATProtoClient(
        oauthConfig: nativeOAuth,
        namespace: "com.example.app",
        authMode: .publicOAuth
    )
    _ = nativeClient

    // 3. Confidential BFF Gateway mode (all requests route via gatewayURL)
    let gatewayOAuth = OAuthConfig(
        clientId: "https://gateway.example.com/oauth/client-metadata.json",
        redirectUri: "https://gateway.example.com/oauth/callback",
        scope: "atproto transition:generic"
    )
    let gatewayClient = try await ATProtoClient(
        oauthConfig: gatewayOAuth,
        namespace: "com.example.gateway",
        authMode: .gateway,
        gatewayURL: URL(string: "https://gateway.example.com")!
    )
    _ = gatewayClient

    // 4. Client Assertion Backend (.cab): direct-to-PDS with backend client assertions
    let cabClient = try await ATProtoClient(
        oauthConfig: nativeOAuth,
        namespace: "com.example.cab",
        authMode: .cab(backendURL: URL(string: "https://cab.example.com")!)
    )
    _ = cabClient

    // 5. Legacy App Password mode for headless scripts and bots
    let botClient = try await ATProtoClient(
        oauthConfig: OAuthConfig.loopback(port: 8765),
        namespace: "com.example.bot",
        authMode: .legacy
    )
    _ = botClient
}
```


## Service Routing & Custom AppViews

By default, an authenticated ``ATProtoClient`` routes `app.bsky.*` calls to `did:web:api.bsky.app#bsky_appview` and `chat.bsky.*` calls to `did:web:api.bsky.chat#bsky_chat`. To use other services, such as a self-hosted AppView or a service for your own `xyz.myapp.*` Lexicons, register namespace prefixes with ``ATProtoClient/setServiceProxy(_:for:)`` or override a single helper call via ``BskyCallOptions``:

<!-- compile-example: arch-service-routing -->
```swift
import Foundation
import Petrel

func configureCustomServiceRouting(client: ATProtoClient) async throws {
    // Route an entire custom Lexicon namespace through the user's PDS to your AppView:
    try await client.setServiceProxy(
        ATProtoServiceReference(did: "did:web:api.statusphere.example", serviceID: "statusphere_appview"),
        for: "xyz.statusphere"
    )

    // Inspect which service proxy applies to any endpoint NSID:
    if let target = await client.serviceProxy(for: "xyz.statusphere.getStatuses") {
        print("Proxying statusphere queries to \(target)")
    }
}
```

## Next Steps

- See how each Lexicon construct maps to Swift in <doc:RosettaStone>.
- Generate a typed API for your own `xyz.myapp.*` Lexicons in <doc:CustomLexicons>.
- Consume Jetstream and the firehose, and verify repositories and PLC logs, in <doc:StreamingAndVerification>.
- Choose and configure an authentication mode in <doc:Authentication> and <doc:OAuthClient>.
