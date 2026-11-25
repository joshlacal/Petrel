# Petrel OAuth scopes

This crate ports Swift PetrelOAuthScopes from Petrel commit `28b2624ee`.
It parses scope strings, evaluates grants, expands verified Lexicon permission
sets, and applies admission budgets. Received grants preserve opaque tokens,
including Catmos Space scopes. Opaque tokens confer no typed permissions.

## Conformance tests

The Rust tests read the Swift fixture at
`Tests/PetrelOAuthScopesTests/Fixtures/upstream-oauth-scopes.json` in place.
Its ten data sections include 184 scope values, 8 scope strings, 1,188
permission outcomes, 9 denial diagnostics, 9 permission-set expansions,
21 namespace authority checks, 66 service references, 35 NSIDs, 20 MIME
checks, and 19 encoder inputs. The tests carry Swift's two MIME wildcard
exceptions and its encoded internationalized host exception.

The two Swift suite groups contain 362 test declarations. Parameterized
tests cover multiple cases. The Rust tests group checks by behavior and reuse
the upstream fixture for cases it already covers.

| Swift suite | Declarations | Rust test coverage |
| --- | ---: | --- |
| Upstream AccountPermission | 18 | `upstream` checks parsing, formatting, matching and denials. `client_edges` exhausts the attributes and actions. |
| Upstream BlobPermission | 15 | `upstream` checks acceptance, canonical form, denied targets, and matching. `client_edges` checks concrete MIME targets. |
| Upstream IdentityPermission | 10 | `upstream` checks parsing, wildcard matching, and denials. `families` checks typed construction and matching. |
| Upstream Mime | 15 | `upstream` checks MIME and pattern predicates. `client_edges` checks matching and ASCII-only case folding. `families` rejects empty pattern lists. |
| Upstream RepoPermission | 20 | `upstream` checks defaults, wildcards, formatting, and matching. `client_grammar` checks diagnostics and `client_edges` checks NSID boundaries and byte identity. |
| Upstream RpcPermission | 27 | `upstream` checks required values, formatting, method and audience matching, and denials. `client_grammar` and `client_edges` check diagnostics and audience encoding. |
| Upstream ScopePermissions | 20 | `upstream` checks granular and transitional matching. The granular arm omits the transition permissions, as in Swift. |
| Upstream ScopePermissionsTransition | 6 | `upstream` checks transitional matching. `coverage` checks the chat prefix and combined wildcard coverage. |
| Upstream ScopesSet | 6 | `upstream` checks matching. `client_edges` checks rebuilding grants with changed membership and retaining malformed scopes. |
| Upstream SyntaxString | 12 | `syntax` checks lexical parts, absent and repeated parameters, and decoding both positional and named values. |
| Upstream Syntax | 6 | `syntax` checks direct, positional, and query prefix matching. |
| ClientScopeModelAccount | 9 | `client_grammar`, `client_edges`, and `upstream` check diagnostics, defaults, canonical forms, and matching. |
| ClientScopeModelBlob | 28 | `client_grammar`, `client_edges`, `families`, `admission`, and `upstream` check malformed patterns, matching, normalization, duplicate accepts, and escaped and non-ASCII values. |
| ClientScopeModelIdentity | 9 | `client_grammar`, `families`, and `upstream` check parsing, canonical spelling, wildcards, and denial strings. |
| ClientScopeModelInclude | 24 | `include` checks JSON shape, localization, expansion and rejection reasons, and authority. `upstream` checks the specification expansions and `client_grammar` checks syntax. |
| ClientScopeModelRPC | 24 | `client_grammar`, `client_edges`, `admission`, and `upstream` check diagnostics, method and audience matching, reference syntax, and round-trips. |
| ClientScopeModelRepo | 23 | `client_grammar`, `client_edges`, `families`, and `upstream` check diagnostics, byte matching, NSID limits, actions, wildcards, and structural equality. |
| ClientScopeModelScopeSet | 47 | `coverage`, `client_edges`, `admission`, and `upstream` check membership, strict and lenient parsing, first error ordering, partial grants, transitions, and coverage. |
| ClientScopeModelScope | 13 | `client_grammar`, `families`, and `upstream` check dispatch, parser isolation, builders, round-trips, and structural equality. |
| ClientScopeModelSpecExample | 15 | `client_grammar` and `upstream` check the specification examples, diagnostics, canonicalization, and matching. |
| ClientScopeModelSyntax | 15 | `syntax`, `client_grammar`, and `upstream` check the token alphabet, lexical parts, permissive form decoding, strict positional decoding, and serialization. |

The supplemental tables include 210 typed parser diagnostics, 53 canonical
inputs beyond the fixture's stable cases, 88 grant coverage pairs, 54
permission-set expansion cases, 46 RPC audience inputs, 16 MIME match cases,
and 15 additional namespace authority checks. Swift tests that construct
invalid permission fields directly map to Rust tests that reject those fields
during construction.

Run the same Rust test bodies on the host and in Node.js WebAssembly.

    cargo test -p petrel-oauth-scopes
    cd petrel-oauth-scopes
    wasm-pack test --node
