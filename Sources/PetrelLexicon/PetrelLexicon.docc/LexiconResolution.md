# Resolving Lexicons from the Network

Find the schema for an NSID the way the specification describes: one DNS
lookup, one DID resolution, one record fetch.

## Overview

Lexicons are published as `com.atproto.lexicon.schema` records. The record key
is the NSID, and the repository that holds the record is named by a DNS TXT
record on the NSID's authority domain.

## Where a Lexicon is published

The authority domain of an NSID is everything but its final name segment, in
reverse order. The TXT record lives at `_lexicon.` plus that domain, and its
value is `did=` followed by the DID of the publishing repository.

<!-- Mirrors DocumentationSnippetTests.documentationAuthorityName -->

<!-- compile-example: lexicon-authority-name -->
```swift
import PetrelLexicon

func authority() throws -> String {
    let name = try LexiconAuthority.dnsName(for: "edu.university.dept.lab.blogging.getBlogPost")
    // "_lexicon.blogging.lab.dept.university.edu"

    let did = try LexiconAuthority.did(fromTXT: ["did=did:plc:ewvi7nxzyoun6zhxrhs64oiz"], name: name)
    // "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    return did
}
```

Resolution is not hierarchical. Exactly that one name is queried; if it has no
`did=` record the resolution fails, and no parent or child domain is tried.
TXT records without the `did=` prefix are ignored, the same value repeated is
fine, and two different values are a conflict that fails the resolution.

## Resolve a Lexicon

With Petrel's identity layer, one initializer wires up all three steps: the
system DNS resolver for the TXT lookup, an `IdentityResolver` for the DID, and
a credential-free HTTP transport for the record.

<!-- Mirrors DocumentationSnippetTests.documentationResolveWithIdentity -->

<!-- compile-example: lexicon-resolve-with-identity -->
```swift
import Petrel
import PetrelLexicon

func resolveNoteSchema() async throws -> ResolvedLexicon {
    let resolver = DefaultLexiconResolver(
        identity: IdentityResolver(),
        cache: LexiconResolutionCache(timeToLive: 300)
    )

    let resolved = try await resolver.resolve("com.example.note")
    return resolved
}
```

``IdentityLexiconDNSResolver`` and ``IdentityLexiconDIDResolver`` are the two
adapters behind that initializer; use them directly to combine the identity
layer with a record source of your own.

## Replace a step

``DefaultLexiconResolver`` runs the procedure over three small protocols, so
each step can use whatever the application already has:

- ``LexiconDNSTXTResolving`` returns the TXT records of a name.
- ``LexiconDIDDocumentResolving`` turns a DID into the endpoint of its PDS.
- ``LexiconRecordFetching`` fetches one record from a repository. The default
  is ``LexiconHTTPRecordFetcher``, an unauthenticated
  `com.atproto.repo.getRecord` request.

<!-- Mirrors DocumentationSnippetTests.documentationResolve -->

<!-- compile-example: lexicon-resolve-custom-steps -->
```swift
import Foundation
import PetrelLexicon

struct ExampleDNS: LexiconDNSTXTResolving {
    func resolveTXT(_ name: String) async throws -> [String] {
        // Query your DNS resolver for the TXT records of `name`.
        name == "_lexicon.example.com" ? ["did=did:web:example.com"] : []
    }
}

struct ExampleDIDResolver: LexiconDIDDocumentResolving {
    func resolvePDSEndpoint(for did: String) async throws -> URL {
        // Resolve the DID document and return its #atproto_pds endpoint.
        URL(string: "https://pds.example.com")!
    }
}

func resolveAndLoad(fetcher: any LexiconRecordFetching) async throws -> LexiconCatalog {
    let resolver = DefaultLexiconResolver(
        dns: ExampleDNS(),
        didResolver: ExampleDIDResolver(),
        fetcher: fetcher, // omit to use LexiconHTTPRecordFetcher
        cache: LexiconResolutionCache(timeToLive: 300)
    )

    let resolved = try await resolver.resolve("com.example.note")

    var catalog = LexiconCatalog()
    try catalog.add(resolved.doc)
    return catalog
}
```

The fetched record is not trusted as found. Before a ``ResolvedLexicon`` is
returned the resolver checks that:

- `$type` is `com.atproto.lexicon.schema`;
- `lexicon` is the integer `1`;
- `id` equals the NSID that was asked for, which is also the record key;
- the document passes the same schema validation as any other Lexicon;
- when the record source reported a CID, the record's canonical DAG-CBOR
  encoding hashes to it.

Each failure is a distinct ``LexiconResolutionError`` case.

## What the default fetcher does and does not do

The PDS a schema is fetched from is named by a DNS record and a DID document
that anyone can publish, so ``LexiconHTTPRecordFetcher`` treats it as an
untrusted host. Its default transport sends no credentials or cookies, follows
no redirects, bounds the time and the size of the response, and refuses hosts
that resolve to private, loopback or reserved addresses. On a closed network,
where the PDS is at such an address, pass
``LexiconHTTPRecordFetcher/urlSessionTransport`` or a transport of your own.

The fetcher trusts the PDS it talks to and the TLS connection
to it. It does not verify the record against a signed repository commit. Where
that matters, supply a ``LexiconRecordFetching`` implementation that uses
`com.atproto.sync.getRecord` and verifies the Merkle proof (`PetrelRepo`
provides the verification).

## Caching

DNS changes are not announced anywhere, so a resolved schema should not be
kept for long. ``LexiconResolutionCache`` is a small time-to-live cache with a
five-minute default; pass one to the resolver to avoid repeating lookups, and
call `invalidate` to drop an entry early. Failures are never cached.
