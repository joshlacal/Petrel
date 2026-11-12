# ``PetrelOAuthScopes``

The AT Protocol OAuth scope and permission grammar, shared by OAuth clients and servers.

## Overview

`PetrelOAuthScopes` parses, builds, canonicalises and matches the scope strings of the [AT Protocol permission specification](https://atproto.com/specs/permission): `atproto`, the `transition:` scopes, the granular `repo:`, `rpc:`, `blob:`, `account:` and `identity:` permissions, and `include:` permission sets with their expansion rules. It depends only on Foundation, so a client and an authorization server use the same parser.

```swift
let granted = ATProtoScopeSet(scope: "atproto repo:app.bsky.feed.post?action=create")
granted.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create))   // true
try granted.covers(.repo(collections: ["app.bsky.feed.post"], actions: [.delete])) // false
```

The grammar is held to the reference implementation, `@atproto/oauth-scopes`: the test suite runs every value of a fixture generated from that package and requires the same accept-or-reject decision and the same canonical string. See <doc:ReferenceParity> for the places where that differs from a literal reading of the specification.

## Topics

### Scopes

- ``ATProtoScope``
- ``ATProtoScopeSet``
- ``ScopeParseError``
- ``ScopeDenied``

### Permissions

- ``RepoPermission``
- ``RpcPermission``
- ``BlobPermission``
- ``AccountPermission``
- ``IdentityPermission``

### Permission sets

- ``IncludeScope``
- ``IncludedPermission``
- ``LexiconPermissionSet``
- ``LexiconPermission``

### Requests

- ``OAuthScopeTokenizer``
- ``OAuthScopeAdmissionPolicy``
- ``OAuthScopeBudget``

### Reference parity

- <doc:ReferenceParity>
