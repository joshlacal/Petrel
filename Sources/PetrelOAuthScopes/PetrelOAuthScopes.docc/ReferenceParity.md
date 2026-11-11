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

Two consequences are worth knowing. A canonical string is the reference's serialisation, not a normal form that is guaranteed to parse back to the same value: the last four `rpc` and `blob` rows show canonical strings whose own percent-escapes or `+` would be decoded again. And a canonical string does not identify a grant: two scopes that grant different things can share one (below). So do not canonicalise twice, and do not decide anything by comparing canonical strings — this module never does.

### Sending a scope: `scopeString`

Because a canonical string may not parse back, it is not always the right thing to put in a request. ``ATProtoScope/scopeString`` is: it is the canonical string whenever that reads back as the same scope, and otherwise the same string with the offending `+` or `%` left percent-encoded, which the reference implementation and Petrel both read as the intended value.

| Scope | `canonicalScopeString()` | `scopeString` |
|---|---|---|
| `blob` accepting `image/png` and `image/svg+xml` | `blob?accept=image/png&accept=image/svg+xml` (rejected if parsed) | `blob?accept=image/png&accept=image/svg%2Bxml` |
| `rpc` with audience `did:web:example.com#a%41` | `…?aud=did:web:example.com%23a%41` (reads back as `#aA`) | `…?aud=did:web:example.com%23a%2541` |
| everything else | the canonical string | the same |

``ATProtoScopeSet/init(_:)`` keeps the typed scopes it is given and stores their `scopeString`, so a set built from typed scopes grants exactly what the values say and serialises to something a server reads the same way. Whether one scope covers another (`covers(_:)`) is decided from what the scopes grant, never from their spelling.

### Scopes are compared by what they grant

Nothing in this module decides whether two scopes are "the same" by comparing strings — not the strings as written, since one grant has many spellings, and not canonical strings, since different grants can share one:

| Scope | Audience it names | `canonicalScopeString()` |
|---|---|---|
| `rpc:com.example.method?aud=did:web:example.com%23svc%26admin` | `did:web:example.com#svc&admin` | `rpc:com.example.method?aud=did:web:example.com%23svc%26admin` |
| `rpc:com.example.method?aud=did:web:example.com%23svc%2526admin` | `did:web:example.com#svc%26admin` | the same string |

The questions are answered from the parsed values the matchers themselves read:

- **Is a requested scope declared by the client?** ``OAuthScopeAdmissionPolicy/isDeclared(_:by:)``, used by ``OAuthScopeAdmissionPolicy/admit(requested:declaredBy:unknownScopes:)``: some declared scope must grant exactly what the requested one grants. The second scope above is not declared by a client that declared the first. A wildcard beside a specific value, a `type/*` beside `type/subtype`, `manage` beside `read`, a repeated value and the positional or named form of a parameter do not change what a scope grants, so those spellings are interchangeable; a narrower or a wider scope is a different one. The reference authorization server requires the requested string to appear verbatim among the declared ones (`oauth-provider/src/client/client.ts:297-312`), so everything it admits Petrel admits, and Petrel additionally admits another spelling of a declared grant — never another grant. Whenever a scope is admitted, every request it allows is allowed by the declared scopes; `ScopeAdmissionMeaningTests` checks that for every pair of scopes in the reference corpus.
- **Does a set cover a scope?** `covers(_:)`, likewise from the parsed values.
- **Are two sets equal?** ``ATProtoScopeSet`` `==` is identity of the strings the token carries, byte for byte, and says so; it is not a statement about grants. Use `covers(_:)` in both directions for that.

Three places do work on strings, because a string is what they are about. ``OAuthScopeTokenizer`` rejects a token that appears twice, byte for byte, as a malformed request; two spellings of one grant are not duplicates. ``OAuthScopeBudget`` counts strings and bytes, since it bounds storage. And a scope that does not parse has no meaning to compare, so it is declared, or covered, only by the identical bytes.

A scope that has to be written down — sent in a request, or stored in a grant after an `include:` scope is expanded — is written as a string that parses back to the same grant: ``ATProtoScope/scopeString`` above, and ``IncludedPermission/scopeString()`` for the permissions ``IncludeScope/expandToScopeStrings(_:)`` returns. For an `rpc` permission that inherits the second audience in the table, that is the string with `%2526`; the canonical string would be read back by a resource server as the first audience.

### Comparisons are byte-wise

Everything that decides whether a request is allowed — a collection, a method, a service, a media type, an attribute, the `chat.bsky.` prefix that separates the two transition scopes, the namespace authority of a permission set — compares bytes. The reference implementation compares UTF-16 code units, which amounts to the same thing. Swift's own `String ==` and `hasPrefix` compare by Unicode canonical equivalence, under which U+212A KELVIN SIGN equals `K` and `e` followed by U+0301 equals `é`, so they are not used: `repo:com.example.Key` does not allow a write to a collection spelled with a Kelvin sign, and a method name cannot hide its `chat.bsky.` prefix behind a combining mark. The parameter values (``CollectionParam``, ``LxmParam``, ``AudParam``, ``AcceptPattern``) are `Equatable` and `Hashable` on the same terms.

### Media type case

The reference implementation compares media types exactly as written when matching (`lib/mime.ts`), but lower-cases them when it writes the canonical scope string (`scopes/blob-permission.ts`). There, `blob:IMAGE/PNG` does not allow an `image/png` upload, while its own canonical form `blob:image/png` does: canonicalising changes what the permission grants.

Petrel resolves this one way, and it is the one place where a match here can differ from the reference: media type names are case-insensitive (RFC 6838 §4.2), so patterns and requested types are compared without regard to the case of ASCII letters, in ``BlobPermission/matches(_:)``, in ``ATProtoScopeSet/allowsBlob(_:)`` and in `covers` alike, and the canonical form stays the reference's lower-case string. For media types written in lower case — which is what the reference emits and what clients send — the two implementations answer identically. They differ only for a pattern or an upload type containing upper-case letters: Petrel allows `image/png` under `blob:IMAGE/PNG` and `IMAGE/PNG` under `blob:image/png`, where the reference allows neither. Only `A`–`Z` are folded; beyond that the comparison is byte-wise, as above. The canonical form folds the same letters and no others: the reference lower-cases with Unicode case mapping, which writes a pattern containing U+212A KELVIN SIGN as `k` and so names a different media type; Petrel keeps the non-ASCII bytes, percent-encoded. For ASCII patterns the canonical strings are identical.

### Permission sets

An entry of a permission set that carries a field which is JSON `null` or a JSON object is ignored, and the rest of the set stands, as in the reference implementation. Such a value decodes as ``LexiconValue/unsupported``; it is never read as "absent", which for an optional parameter would have meant its default.

`inheritAud` is understood only when it is the boolean `true` and the `include:` scope has an audience to inherit. Any other `inheritAud`, `false` included, is a parameter `rpc` does not define, so the entry is ignored — the reference's behaviour, where the specification's wording (an optional boolean) would make `false` the same as leaving it out. The `type` of a set and of its entries is decoded but not checked; a malformed `title:lang` or `detail:lang` map is ignored rather than failing the set.

### Notes for client code

Behaviour that follows the reference implementation and is worth knowing when building or comparing scopes:

- **Decoding the parameter part never fails.** It is read as `URLSearchParams` reads it: a malformed percent-escape stays as written and invalid UTF-8 becomes U+FFFD. The scope is still rejected, by the parameter's own validation.
- **A parsed permission keeps its values as written** — order, duplicates and letter case. Only ``ATProtoScope/canonicalScopeString()`` sorts, removes duplicates and lower-cases.
- **`==` on ``ATProtoScope`` is structural.** It compares the values as written, including whether a parameter was stated or left to its default, so two scopes granting the same access can be unequal. To ask whether one grant includes another use `covers(_:)` on an ``ATProtoScopeSet``.
- **An empty `actions` list means every action**, exactly as leaving `action` out of the scope string does.
- **Only the builders and `parse` validate.** The permission types' own initializers (`RepoPermission(collection:action:)` and the others) take what they are given. A value assembled that way which no scope string can describe has no ``ATProtoScope/scopeString`` and grants nothing in a set.
- **`did:web:localhost%3A`** — a port separator with no port — is accepted as an audience, as the URL parser behind the reference accepts `http://localhost:`.
- **A scope value is split on SPACE only** (RFC 6749 §3.3), and on the byte: a space followed by a combining mark still separates two tokens. Tabs and newlines are part of a token, which then is not a valid scope. Leading, trailing and repeated spaces are tolerated, by ``ATProtoScopeSet/init(strict:)`` as well.
- **``ATProtoScopeSet/rawScopes`` is a `Set<String>`**, which cannot hold two strings that differ in bytes and are canonically equivalent. Given both in one scope value, ``ATProtoScopeSet/init(scope:)`` keeps the ASCII one — the only one that can be a scope — in either order.
- **A set parsed from a string holds the strings as given.** ``ATProtoScopeSet/scopes`` and ``ATProtoScopeSet/scopeString`` are in sorted order of those strings, not the order given, and two spellings of one permission are two members; ``ATProtoScopeSet/normalizedScopeString`` folds them, and keeps strings it does not recognise as they are.
- **`transition:generic` does not reach `chat.bsky.` methods**, and `transition:chat.bsky` reaches only those. A need for every method on a service is therefore covered by the two together, not by either alone.
- **A scope that does not parse is covered only by the identical string.** `covers` cannot reason about a scope this version does not understand, so it does not report it as covered unless the granted set holds exactly that string.

### Where Petrel is stricter than the reference

Petrel deliberately rejects two values the reference accepts: the MIME patterns `im*ge/*` and `*a/*` (as `blob:im*ge/*` and `blob:*a/*`). The specification does not list a partial wildcard among the forms `accept` may take, and no media type can match one, so nothing is granted or denied differently; such a scope is invalid here where the reference treats it as valid and inert. A DID service reference whose `did:web` host percent-decodes to non-ASCII text is likewise rejected. These are listed in `UpstreamScopeCorpus` and asserted by `UpstreamScopeCorpusIntegrityTests`.
