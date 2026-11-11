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

### Where Petrel is stricter than the reference

Petrel deliberately rejects two values the reference accepts: the MIME patterns `im*ge/*` and `*a/*` (as `blob:im*ge/*` and `blob:*a/*`). The specification does not list a partial wildcard among the forms `accept` may take, and no media type can match one, so nothing is granted or denied differently; such a scope is invalid here where the reference treats it as valid and inert. A DID service reference whose `did:web` host percent-decodes to non-ASCII text is likewise rejected. These are listed in `UpstreamScopeCorpus` and asserted by `UpstreamScopeCorpusIntegrityTests`.
