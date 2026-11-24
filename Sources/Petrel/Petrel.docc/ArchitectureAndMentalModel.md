# How the AT Protocol Fits Together

The parts of the network your app talks to, and the Petrel type that handles each.

## Overview

An AT Protocol app deals with five things: an account's identity, the server that stores its data, the streams that carry everyone's data, the services that index it, and OAuth. This article describes each in a paragraph and names the Petrel API for it.

## Identity: DIDs and handles

An account has two identifiers. The DID (`did:plc:…` or `did:web:…`) is permanent: record URIs, follows and OAuth tokens all refer to it. The handle (`alice.example.com`) is a domain name for people to read, and the account can change it at any time.

A handle counts only when it checks out in both directions. The handle's domain names a DID, through a DNS TXT record at `_atproto.<handle>` or `https://<handle>/.well-known/atproto-did`. The DID's document then lists the handle under `alsoKnownAs`. The same document holds the account's signing key and the URL of its PDS.

``IdentityResolver`` does this resolution and needs no account; see <doc:Identity>. ``DID`` and ``Handle`` validate the syntax; see <doc:Identifiers>. The `PetrelPLC` product reads the `did:plc` directory and verifies an identity's audit log.

## The PDS and the repository

A Personal Data Server (PDS) hosts the account. It stores the account's public records in a repository, stores its blobs, and is where the app sends authenticated requests.

A record lives at `<collection>/<rkey>`, for example `app.bsky.feed.post/3k2yihcrp6f2c`. The collection is the NSID of the record's Lexicon, and the record key is usually a ``TID``. Records are encoded as DAG-CBOR and addressed by CID. The repository arranges them in a Merkle Search Tree, and the account's key signs the root on every commit. Because the repository is signed, it can move to another PDS and its `at://` URIs keep working.

You read and write records with the `com.atproto.repo` methods on ``ATProtoClient``, or with ``BskyAgent`` for Bluesky records (<doc:BlueskyPosting>). <doc:LexiconTypesInSwift> shows how a record's Lexicon becomes a Swift type. To read, verify or build whole repositories, use the `PetrelRepo` product; `PetrelCore`, which `Petrel` re-exports, has `CID`, `DAGCBOR` and `CARReader`.

## Relays, the firehose and Jetstream

Services that need everyone's data do not poll every PDS. A relay collects the commits of many PDSs into one stream, the firehose (`com.atproto.sync.subscribeRepos`). It is binary: each event carries a signed commit and the changed blocks, so a consumer can verify it. Jetstream republishes the same events as JSON, filtered on the server by collection and DID. It is simpler to consume, and you trust the Jetstream host instead of verifying.

`PetrelFirehose` consumes the firehose and can verify its events. `PetrelJetstream` consumes Jetstream. See <doc:StreamingAndVerification>.

## AppViews and proxying

A PDS stores records but does not build timelines or search. An AppView does: it indexes the firehose and answers queries such as `app.bsky.feed.getTimeline`. Bluesky's AppView is `did:web:api.bsky.app#bsky_appview`, and its chat service is `did:web:api.bsky.chat#bsky_chat`.

A signed-in client does not call the AppView directly. It sends the request to the user's PDS with an `atproto-proxy` header that names the service. The PDS authenticates the user, signs a short-lived service-auth token, and forwards the request. Requests the PDS answers itself, such as `com.atproto.repo.*` and `app.bsky.actor.getPreferences`, carry no proxy header.

``ATProtoClient`` adds the header for you: `app.bsky.*` calls go to the Bluesky AppView and `chat.bsky.*` calls to the chat service. To route a namespace to another service, such as an AppView for your own Lexicons, register it:

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

``XRPCCallOptions`` sets the proxy for a single call (<doc:XRPCClient>). If you run a service that receives proxied requests, <doc:ServiceAuthentication> shows how to verify the tokens.

Without an account, you can query the public Bluesky AppView at `https://public.api.bsky.app` directly, as <doc:GettingStarted> does.

## OAuth

There are many PDSs, so an app cannot register with each authorization server in advance. The [atproto OAuth profile](https://atproto.com/specs/oauth) works without registration:

- The client ID is the `https` URL of a metadata document the app publishes. Any authorization server can fetch it.
- The client finds the server from the account: handle to DID, DID document to PDS, PDS metadata to authorization server.
- Tokens are bound to a key the client holds (DPoP). Each request carries a proof signed with that key, so a stolen token is useless alone.

``ATProtoClient`` runs the flow, stores the session and refreshes tokens. You supply an ``OAuthConfig`` and show one URL in a browser. See <doc:OAuthClient>.
