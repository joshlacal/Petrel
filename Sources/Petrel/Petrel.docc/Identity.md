# Resolving Handles and DIDs

Turn a handle or a DID into a verified identity: the DID document, the PDS endpoint, the signing key, and a handle that has been confirmed in both directions.

## Overview

``IdentityResolver`` implements the identity parts of the AT Protocol: the
[DID](https://atproto.com/specs/did) and [handle](https://atproto.com/specs/handle)
specifications. It needs no ``ATProtoClient``, no account and no keychain, and it runs on Apple
platforms and Linux, so it works in a server as well as in an app.

<!-- compile-example: identity-overview -->
```swift
import Petrel

func resolveVerifiedIdentity() async throws {
    let resolver = IdentityResolver()

    let identity = try await resolver.resolveIdentity("atproto.com")
    _ = identity.did                // did:plc:ewvi7nxzyoun6zhxrhs64oiz
    _ = identity.handle             // atproto.com
    _ = identity.pdsEndpoint        // the account's PDS
    _ = try identity.signingKey()   // the #atproto key, for verifying signatures
}
```

### Handle to DID

`IdentityResolver.resolveHandle(_:forceRefresh:)` returns a DID only when the link
holds in both directions: the handle's domain names the DID, and the DID's document claims the
handle.

<!-- compile-example: identity-handle-to-did -->
```swift
import Petrel

func resolveHandleOnly(resolver: IdentityResolver) async throws -> DID {
    try await resolver.resolveHandle("atproto.com")
}
```

The handle's domain is asked two ways at once, as the handle specification describes:

- **DNS TXT** at `_atproto.<handle>`. Only values that start with `did=` count. If several such
  records name different DIDs, resolution fails with
  ``IdentityError/handleAmbiguous(handle:dids:)``.
- **HTTPS** at `https://<handle>/.well-known/atproto-did`. Any `2xx` status is accepted, the
  `Content-Type` is not checked, surrounding whitespace is stripped, and the body must then be a
  DID and nothing else. Redirects are followed, up to five.

When the two disagree, the DNS answer is used. Set
``IdentityResolver/Options/handleConflictPolicy`` to ``HandleConflictPolicy/reject`` to fail
instead.

Handles in a reserved top-level domain (`.alt`, `.arpa`, `.example`, `.internal`, `.invalid`,
`.local`, `.localhost`, `.onion`) fail with ``IdentityError/reservedHandleTLD(_:)`` before any
DNS or HTTP request is made. `.test` handles fail the same way unless
``IdentityResolver/Options/allowsDevelopmentIdentifiers`` is set.

### DID to document

`IdentityResolver.resolveDIDDocument(_:forceRefresh:)` supports the two DID methods
the protocol blesses:

- `did:plc`, fetched from the PLC directory. The directory defaults to `https://plc.directory`
  and is set with ``IdentityResolver/Options/plcDirectoryURL``.
- `did:web`, fetched from `https://<host>/.well-known/did.json`. Only hostname-level DIDs are
  supported. A path (`did:web:example.com:user`) fails with
  ``IdentityError/unsupportedDIDWebPath(_:)``, and a port is accepted only on `localhost`, which
  is itself accepted only with ``IdentityResolver/Options/allowsDevelopmentIdentifiers``.

DID document fetches do not follow redirects.

Any other method fails with ``IdentityError/unsupportedDIDMethod(did:method:)``, and a string
that is not a DID fails with ``IdentityError/invalidDIDSyntax(_:)``. The returned document's `id`
always equals the DID that was asked for; a document that names another DID fails with
``IdentityError/documentIDMismatch(expected:actual:)``.

<!-- compile-example: identity-did-document -->
```swift
import Petrel

func inspectDIDDocument(resolver: IdentityResolver) async throws {
    let document = try await resolver.resolveDIDDocument("did:plc:ewvi7nxzyoun6zhxrhs64oiz")

    _ = document.claimedHandle                    // the first valid at:// entry in alsoKnownAs (unverified)
    _ = document.pdsEndpoint                      // #atproto_pds, type AtprotoPersonalDataServer
    _ = try document.atprotoSigningKey()          // #atproto: Multikey or a legacy 2019 key type
    _ = try document.atprotoSigningDIDKey()       // the same key as a did:key string
    _ = try document.serviceEndpoint(.labeler)        // #atproto_labeler
    _ = try document.serviceEndpoint(.feedGenerator)  // #bsky_fg
}
```

``DIDDocument`` applies the rules of the DID specification for you: the first matching entry
wins, a signing key must be controlled by the DID itself, and a service endpoint must be an
`https` origin with no path, query or user info.

### A verified identity, and handle.invalid

``IdentityResolver/resolveIdentity(_:forceRefresh:)`` accepts a handle or a DID and returns a
``ResolvedIdentity``. Given a DID, a handle that cannot be confirmed does not fail the call. The
account is still usable, so the identity is returned with the handle `handle.invalid`, and
``ResolvedIdentity/handleVerification`` says why.

<!-- compile-example: identity-handle-invalid -->
```swift
import Petrel

func displayVerifiedHandleOrDID(resolver: IdentityResolver) async throws -> String {
    let identity = try await resolver.resolveIdentity("did:plc:ewvi7nxzyoun6zhxrhs64oiz")

    if identity.isHandleVerified {
        return "@\(identity.handle)"
    } else {
        // identity.handle is "handle.invalid". Do not display identity.claimedHandle as if it
        // were the account's handle.
        return identity.did.didString()
    }
}
```

### Verifying a signature from another account

Service authentication and repository verification need an account's signing key, or the
endpoint of one of its services.

<!-- compile-example: identity-signing-key -->
```swift
import Foundation
import Petrel

func fetchPeerKeyAndPDS(resolver: IdentityResolver, issuerDID: String) async throws {
    let key = try await resolver.resolveSigningKey(for: issuerDID)
    let pds = try await resolver.resolveServiceEndpoint(for: issuerDID, service: .pds)
    _ = (key, pds)
}
```

Keys rotate. When a signature does not verify against the cached key, ask again with
`forceRefresh: true` before rejecting it.

<!-- compile-example: identity-signing-key-refresh -->
```swift
import Petrel

func refreshPeerSigningKey(resolver: IdentityResolver, issuerDID: String) async throws -> ATProtoJWTVerificationKey {
    try await resolver.resolveSigningKey(for: issuerDID, forceRefresh: true)
}
```

### Configuration

<!-- compile-example: identity-configuration -->
```swift
import Foundation
import Petrel

func buildConfiguredIdentityResolver() -> IdentityResolver {
    IdentityResolver(
        options: IdentityResolver.Options(
            plcDirectoryURL: URL(string: "https://plc.example.net")!,
            handleStrategy: .direct,
            timeout: 3,
            cachePolicy: IdentityCachePolicy(freshFor: 15 * 60, maximumAge: 6 * 60 * 60)
        ),
        cache: InMemoryIdentityCache(capacity: 50_000)
    )
}
```

- ``HandleResolutionStrategy/direct`` asks the handle's own domain. A client that would rather
  rely on a service, which the handle specification permits, uses
  ``HandleResolutionStrategy/xrpc(service:fallbackToDirect:)``. The answer is verified against
  the DID document either way.
- ``IdentityCachePolicy`` sets how long results are served from the cache. Entries past
  ``IdentityCachePolicy/freshFor`` are resolved again; if that attempt fails in transit, the old
  entry is served until ``IdentityCachePolicy/maximumAge``. Call
  ``IdentityResolver/invalidate(did:)`` when a firehose `#identity` or `#account` event names a
  DID.
- ``IdentityCache`` is a protocol. Implement it to share one cache between processes.

### Network safety

Handle hosts and `did:web` hosts are chosen by whoever owns the identifier. The resolver treats
every one of them as untrusted:

- Requests carry no credentials, cookies, proxy headers or account-specific headers, and a `401`
  never leads to a retry with credentials.
- The default transport, ``HardenedIdentityHTTPTransport``, resolves each host before
  connecting and refuses private, loopback, link-local and other reserved addresses, on the
  first request and on every redirect.
- Responses are size-limited: 4 KiB for a well-known handle file,
  ``IdentityResolver/Options/maximumDocumentBytes`` for a DID document.
- Each HTTP request and DNS query is abandoned after ``IdentityResolver/Options/timeout``.

To send lookups through your own HTTP client, DNS over HTTPS, or test doubles, supply an
``IdentityHTTPTransport`` and an ``IdentityDNSResolver``.

<!-- compile-example: identity-custom-dns -->
```swift
import Petrel

struct FixedDNS: IdentityDNSResolver {
    let records: [String: [String]]

    func queryTXT(name: String) async throws -> [String] {
        records[name] ?? []
    }
}

func makeResolverWithFixedDNS() -> IdentityResolver {
    IdentityResolver(dnsResolver: FixedDNS(records: [
        "_atproto.alice.example.com": ["did=did:plc:ewvi7nxzyoun6zhxrhs64oiz"],
    ]))
}
```

### With ATProtoClient

``ATProtoClient`` resolves identities with an ``IdentityResolver`` of its own. For handles it
first asks the service it is connected to (`com.atproto.identity.resolveHandle`), falls back to
the handle's domain, and verifies the answer against the DID document in every case.

<!-- compile-example: identity-with-client -->
```swift
import Foundation
import Petrel

func resolveThroughClient() async throws -> ResolvedIdentity {
    let client = await ATProtoClient(baseURL: URL(string: "https://public.api.bsky.app")!)

    let did = try await client.resolveHandleToDID(handle: "atproto.com")
    return try await client.resolveIdentity(did)
}
```

To make a client resolve handles directly, or to share one resolver and its cache between
clients, pass your own.

<!-- compile-example: identity-shared-resolver -->
```swift
import Foundation
import Petrel

func shareResolverWithClient() async -> ATProtoClient {
    let resolver = IdentityResolver()
    return await ATProtoClient(
        baseURL: URL(string: "https://public.api.bsky.app")!,
        didResolver: resolver
    )
}
```

### Errors

Every failure is an ``IdentityError``. The cases separate what the specifications ask
implementations to tell apart: invalid syntax, an unsupported method, an identifier that does not
exist, and a lookup that could not be completed.

<!-- compile-example: identity-errors -->
```swift
import Petrel

func classifyHandleLookup(resolver: IdentityResolver, input: String) async -> String {
    do {
        let did = try await resolver.resolveHandle(input)
        return did.didString()
    } catch IdentityError.invalidHandleSyntax {
        return "not a handle"
    } catch IdentityError.handleNotFound {
        return "no DNS record and no well-known file"
    } catch IdentityError.handleNotClaimedByDID {
        return "the DID document does not claim this handle"
    } catch IdentityError.handleLookupFailed {
        return "DNS or web server unreachable; retry later"
    } catch {
        return "other identity error: \(error)"
    }
}
```

## Topics

### Resolving

- ``IdentityResolver``
- ``ResolvedIdentity``
- ``HandleVerification``
- ``IdentityError``

### DID documents

- ``DIDDocument``
- ``Service``
- ``VerificationMethod``
- ``DIDServiceIdentifier``
- ``DIDWebIdentifier``

### Configuration

- ``HandleResolutionStrategy``
- ``HandleConflictPolicy``
- ``IdentityCachePolicy``
- ``IdentityCache``
- ``InMemoryIdentityCache``
- ``IdentityCacheEntry``

### Transport

- ``IdentityHTTPTransport``
- ``HardenedIdentityHTTPTransport``
- ``IdentityHTTPRequest``
- ``IdentityHTTPResponse``
- ``IdentityDNSResolver``
- ``SystemIdentityDNSResolver``

### Client integration

- ``DIDResolving``
