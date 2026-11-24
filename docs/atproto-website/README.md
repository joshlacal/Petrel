# Listing Petrel on atproto.com

A draft contribution to [bluesky-social/atproto-website](https://github.com/bluesky-social/atproto-website)
that adds Petrel to the community SDK list at <https://atproto.com/sdks>. Nothing here has been
sent upstream.

## How atproto.com lists SDKs

The SDKs page (`src/app/[locale]/sdks/page.mdx`) renders one component,
`src/components/Libraries.tsx`. Community SDKs are entries in its `community` array, grouped by
language. Each entry has a link, a name, the maintainer's Bluesky handle and a status of `full`,
`partial` or `none` for ten features. The site does not host SDK documentation, guides or MDX
pages for community libraries; each entry links out. Recent additions were single-entry pull
requests that touch only this file (for example "Add CarpaNet to community SDKs", #759, and
"Updating idunno.Bluesky capabilities", #805).

## The change

[`Libraries.tsx.patch`](Libraries.tsx.patch) adds Petrel to the Swift group after
`swift-atproto`, and adds the trailing comma the previous entry is missing. It applies cleanly to
atproto-website `main` at `605a806` (2026-11-23):

```sh
git clone https://github.com/<your-fork>/atproto-website
cd atproto-website
git switch -c add-petrel-sdk
git apply /path/to/Petrel/docs/atproto-website/Libraries.tsx.patch
npm install && npm run dev   # check http://localhost:3000/sdks
```

The entry links to the GitHub repository, whose README links the hosted documentation. To link
the documentation site directly instead, change `href` to
`https://joshlacal.github.io/Petrel/documentation/petrel/`.

### Why every feature is rated `full`

The site defines `full` as "complete or near-complete". Each rating points at the product and
guide that covers it:

| Feature (site's definition) | Petrel |
| :--- | :--- |
| identifiers: DID and handle parsing, normalization and validation | `DID`, `Handle`, `NSID`, `ATProtocolURI`, `RecordKey`, `TID`, `CIDSyntax`; Identifiers guide; atproto-interop-tests syntax vectors |
| bsky helpers: Bluesky lexicons, types and app helpers | Generated `app.bsky.*` and `chat.bsky.*`; `BskyAgent`, `RichText`, `Moderation`, `BskyPreferences` |
| lexicon: generic Lexicon support and XRPC client | Typed XRPC client generated from Lexicons; `petrel-gen` and SwiftPM plugins for your own Lexicons; `PetrelLexicon` runtime validation and Lexicon resolution |
| identity: DID and handle resolution | `IdentityResolver`: DNS TXT and HTTPS handle resolution, `did:plc` and `did:web`, bidirectional handle verification |
| streaming: firehose and Jetstream | `PetrelFirehose` (`subscribeRepos`, labels, commit verification) and `PetrelJetstream` (JSON, zstd) |
| service auth: service-to-service JWTs | `PetrelCrypto` `ServiceJWT` (mint, ES256 and ES256K) and `ServiceAuthVerifier` (verify, key resolution, replay protection) |
| crypto: keys, signing, verification | `PetrelCrypto`: P-256 (including Secure Enclave) and secp256k1, `did:key`; interop crypto vectors |
| repo: parse, read and write repositories | `PetrelRepo`: CAR, MST, commit creation and verification, record proofs; interop mst vectors |
| plc: PLC directory read and write | `PetrelPLC` (read, audit-log verification, signed operations: rotate, create, deactivate) and `PetrelPLCPDS` |
| oauth server: OAuth 2.0 authorization server | `PetrelOAuthServer` with a conformance map, plus NIO and Hummingbird adapters |

## Pull request text

Title:

```
Add Petrel to community SDKs (Swift)
```

Body:

```
Adds Petrel, a Swift 6 SDK for the AT Protocol and Bluesky, to the Swift section of the SDKs page.

Petrel generates a typed XRPC client from the upstream Lexicons and ships the protocol pieces as
separate SwiftPM products: identifiers, identity resolution, crypto and service auth, repositories
and MSTs, firehose and Jetstream, PLC, runtime Lexicon validation, an OAuth client (PAR, PKCE,
DPoP) and an embeddable OAuth authorization server. It runs the atproto-interop-tests vectors in CI
on macOS and Linux, and supports iOS 18, macOS 15, tvOS 18 and Linux.

- Repository: https://github.com/joshlacal/Petrel
- Documentation: https://joshlacal.github.io/Petrel/documentation/petrel/
- Maintainer: @josh.uno

Ratings: every feature is marked full. The documentation has a page for each one, and I'm happy
to lower any rating you read differently.
```

## Before opening it

- Tag Petrel `2.0.0`. Every install snippet in the documentation uses
  `.upToNextMinor(from: "2.0.0")`, and the newest tag today is `1.1.0`, so SwiftPM cannot resolve
  those snippets until the tag exists.
- Confirm <https://joshlacal.github.io/Petrel/documentation/petrel/> serves the current site, so
  the link in the pull request body works.
