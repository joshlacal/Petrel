# Reference parity

Where the specification's text and the reference implementation differ, Petrel follows the reference implementation.

## Overview

A scope string that one implementation accepts and another rejects, or that two implementations canonicalise differently, breaks sessions in ways that are hard to diagnose: a client's declared scope stops matching what it requests, or a token's scope stops matching what a resource server expects. The network's authorization servers run the reference implementation, `@atproto/oauth-scopes`, so Petrel's rule is parity with it for both the accept-or-reject decision and the canonical form.

Parity is enforced by `UpstreamScopeConformanceTests`, which runs every value in a fixture generated from the reference package at a pinned commit (`Tests/PetrelOAuthScopesTests/UpstreamGoldens/regenerate.sh` regenerates it).

### Ten cases where a literal reading of the specification would answer differently

Each is pinned individually by `ReferenceParityTests`.

| Scope string | Reference and Petrel | A literal reading of the specification |
|---|---|---|
| `account:email?action=manage&action=read` | accepted | `action` is a single value, so a repeat would be rejected |
| `account:email?action=read&action=manage` | accepted | as above |
| `account:email?action=read&action=read` | accepted; canonical form `account:email` | as above |
| `rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a+b` | rejected: `+` in a parameter value decodes to a space | `+` is an ordinary character, so the value would be accepted |
| `blob?accept=image/svg+xml` | rejected, for the same reason; write `image/svg%2Bxml` | accepted |
| `rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2Bb` | canonical form ends `%23a+b` | the canonical form would keep `%2B` |
| `blob?accept=image/svg%2Bxml&accept=image/png` | canonical form `blob?accept=image/png&accept=image/svg+xml` | the canonical form would keep `%2B` |
| `rpc:app.bsky.feed.getFeed?aud=did:web:localhost%253A8080%23svc` | canonical form has `localhost%3A8080` | the canonical form would keep `%253A` |
| `rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2541` | canonical form ends `%23a%41` | the canonical form would keep `%2541` |
| `blob?accept=image/png&accept=image/png` | canonical form `blob?accept=image/png` | a single value could use the positional form `blob:image/png` |

Two consequences are worth knowing. A canonical string is the reference's serialisation, not a normal form that is guaranteed to parse back to the same value: the last four `rpc` and `blob` rows show canonical strings whose own percent-escapes or `+` would be decoded again. Compare scopes by canonical string from the same input, and do not canonicalise twice.

### Sending a scope: `scopeString`

Because a canonical string may not parse back, it is not always the right thing to put in a request. ``ATProtoScope/scopeString`` is: it is the canonical string whenever that reads back as the same scope, and otherwise the same string with the offending `+` or `%` left percent-encoded, which the reference implementation and Petrel both read as the intended value.

| Scope | `canonicalScopeString()` | `scopeString` |
|---|---|---|
| `blob` accepting `image/png` and `image/svg+xml` | `blob?accept=image/png&accept=image/svg+xml` (rejected if parsed) | `blob?accept=image/png&accept=image/svg%2Bxml` |
| `rpc` with audience `did:web:example.com#a%41` | `…?aud=did:web:example.com%23a%41` (reads back as `#aA`) | `…?aud=did:web:example.com%23a%2541` |
| everything else | the canonical string | the same |

``ATProtoScopeSet/init(_:)`` keeps the typed scopes it is given and stores their `scopeString`, so a set built from typed scopes grants exactly what the values say and serialises to something a server reads the same way. Whether one scope covers another (`covers(_:)`) is decided from what the scopes grant, never from their spelling.

### Media type case

The reference implementation compares media types exactly as written when matching (`lib/mime.ts`), but lower-cases them when it writes the canonical scope string (`scopes/blob-permission.ts`). There, `blob:IMAGE/PNG` does not allow an `image/png` upload, while its own canonical form `blob:image/png` does: canonicalising changes what the permission grants.

Petrel resolves this one way. Media type names are case-insensitive (RFC 6838 §4.2), so patterns and requested types are compared without regard to case, in ``BlobPermission/matches(_:)``, in ``ATProtoScopeSet/allowsBlob(_:)`` and in `covers` alike, and the canonical form stays the reference's lower-case string. For media types written in lower case — which is what the reference emits and what clients send — the two implementations answer identically; they differ only for a pattern or an upload type containing upper-case letters, where Petrel's answer is the one the canonical form implies.

### Where Petrel is stricter than the reference

Petrel deliberately rejects two values the reference accepts: the MIME patterns `im*ge/*` and `*a/*` (as `blob:im*ge/*` and `blob:*a/*`). The specification does not list a partial wildcard among the forms `accept` may take, and no media type can match one, so nothing is granted or denied differently; such a scope is invalid here where the reference treats it as valid and inert. A DID service reference whose `did:web` host percent-decodes to non-ASCII text is likewise rejected. These are listed in `UpstreamScopeCorpus` and asserted by `UpstreamScopeCorpusIntegrityTests`.
