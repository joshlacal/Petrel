# October 29 Spaces compatibility

Petrel targets the fixed ATProto Spaces alpha implementation `5d88b414a98de1ada22c94c78fa0667a7028163c`, published as `0.0.0-spaces-alpha-20261029171913`. The vendored `com.atproto.space`, `com.atproto.memberspace`, `com.atproto.managedspace` and `com.atproto.personalspace` schemas are byte-identical to that revision, and their provenance manifest is checked independently of regeneration. Ordinary weekly lexicon sync preserves this separately pinned corpus.

The October 29 release replaces `com.atproto.simplespace` with a single space `policy` (an open union of `com.atproto.personalspace.policy`, `com.atproto.memberspace.policy` and `com.atproto.managedspace.policy`). Petrel ships these only as generated APIs: `createSpace`, `updateSpace`, `getSpace` and `deleteSpace` move to `com.atproto.space`, the member list methods to `com.atproto.memberspace`, and `checkUserAccess` to `com.atproto.managedspace`. `getSpace` is owner-only, so credential holders read a published `com.atproto.space.policy` record instead. The new `clearRecords`, `removeWriter`, `importRepo`, `exportSpaceMeta` and `importSpaceMeta` methods are generated but have no hand-written helpers. The credential, MAC and STAR wire format is unchanged from October 22.

`SpaceCredentialManager` exchanges a user delegation token in the JSON request body with a fresh P-256 `credentialKid`. Its optional client-attestation provider supports authorities that require application identity. The exchange carries no delegation Authorization header and no HTTP signature. Credential reads use `Atproto-Space-Credential`, the `atproto-space-credential` signature label/tag, and exact Authorization/audience bytes. Authority discovery uses the account's `#atproto_pds`; credential JWT headers must identify `#atproto`.

## Verified credential reads

Use the existing `get(url:space:audience:)` method for credential-authenticated reads. It returns `(Data, HTTPURLResponse)` and retains the response headers. For `getLatestCommit`, `getRepo`, `listRepoOps`, and `getRecord`, it resolves the author's dedicated `#atproto_kem` key and generates a separate ephemeral key for every HTTP request. A MAC mismatch refreshes the author key once and retries with another ephemeral key; repeated failure is terminal. Missing/malformed MACs fail closed. Other operations, including `getBlob` and `listRepos`, do not acquire MAC headers.

A successful `getRecord` returns only after URI binding, MAC verification, and canonical record/CID verification. A successful `getRepo` returns only after the complete STAR archive has passed metadata/MAC validation, minimal-varint/framing/ordering checks, canonical record validation, and full LtHash digest verification. `listRepoOps` verifies each returned commit's MAC; callers retaining incremental repository state must still compare the complete final set digest before publishing it. Pages without a commit carry no response MAC, but still receive a fresh request key share.

The optional `authorKEMKeyProvider` accepts `(repoDID, forceRefresh)` and returns a P-256 `did:key`. A custom caching provider must honor `forceRefresh`; the default fetches the current DID document through the hardened resolver. KEM keys and credential-binding keys are distinct.

## Owner OAuth and archive consumers

Generated endpoint calls retain their existing OAuth transport behavior. They do not claim response-MAC or archive verification. They are bounded by the client's `NetworkService` response limits, 10 MiB by default. To read an owner archive or blob above that, wrap the call in `NetworkService.withResponseLimits(_:operation:)`; each field of the scoped limits is clamped to 128 MiB (`SpaceSTAR.defaultMaximumArchiveBytes`). Owner-OAuth callers of `getRepo` can validate the received complete archive with:

```swift
let verified = try SpaceSTAR.verify(archive: bytes, space: space, repo: ownerDID)
```

This verifies the archive's internal digest and request identity. Authentication comes from the owner's OAuth exchange and transport. Credential callers must use `SpaceCredentialManager.get`, or supply the matching request secret and response MAC to `SpaceSTAR.verify(archive:space:repo:sharedSecret:mac:)`. Never treat an unauthenticated archive's self-consistent digest as proof of its author.

`VerifiedSpaceRepository` exposes the revision, digest, and complete records (`path`, `cid`, `bytes`). Replace the caller's local repository atomically after verification, removing records absent from the new snapshot. Public repository CAR helpers remain separate and unchanged.

## Bounds and lifecycle

STAR records are limited to 1 MiB, metadata to 64 KiB, and the standalone verifier's default archive limit is 128 MiB. The credential manager keeps its 10 MiB hardened network limit by default. Passing `maximumArchiveBytes` to `get(url:space:audience:maximumArchiveBytes:)` replaces that limit for a single `getRepo` request, up to the 128 MiB archive limit, and bounds that archive's verification; other methods ignore it. `maximumBlobBytes` does the same for a single `getBlob` request, also up to 128 MiB. The upstream reference host has no `getBlob` cap of its own; the uploading PDS's blob upload limit (5 MiB by default) bounds it, and Swan accepts permissioned blobs up to 256 MiB, so a blob above 128 MiB cannot be read through Petrel. The implementation buffers and verifies a complete response. These bounds are deliberate and do not establish large-repository capacity. Existing DAG-CBOR depth/node limits also apply.

A cached credential is reused until its `exp` less a margin of min(60 s, half its issued lifetime `exp - iat`), and never past that margin before one lifetime after local receipt, so a device clock behind the issuer's cannot extend reuse. A 60 s credential is therefore reused for about 30 s. Without an `iat` claim the margin is 60 s. Each renewal exchanges a fresh credential bound to a fresh key.

Only an exact structured `SpaceDeleted` error from the authority's credential exchange is classified as deletion. A body or message merely mentioning that text is not. `InvalidDelegationToken` at HTTP 400 is token rejection, not membership removal. `InvalidClientAttestation` is also `tokenRejected`, with that error name and a description naming the client attestation; it does not trigger the `describeServer` evidence probe. `SpaceNotFound` at HTTP 400 (the reference host) or 404 (Swan) is `authorizationRefused` with error `SpaceNotFound`, meaning "not found or not authorized": the authority does not host the space, does not authorize this user, or, without a delegation token, the space is not public. Since October 29 the reference authority checks the user before the app and answers `SpaceNotFound` where it previously answered `UserNotAuthorized`, including for a non-member using a disallowed app. `UserNotAuthorized`, `AppNotAuthorized` and `NotAuthorized` are still handled, because other authorities may return them. Neither means the space was deleted. Invalidation cancels acquisition, retires the credential generation, and discards responses that finish after that generation was invalidated. Callers remain responsible for purging their projections and caches, and for adopting a deliberately recreated Space as fresh state.

## Reproducible checks

The regression tests include the upstream RFC 9180 DHKEM vector, independent Python HMAC vectors, and a complete STAR fixture generated with Python `cbor2==5.6.5` and `blake3==1.0.8`. `Scripts/generate-space-vectors.py` regenerates that fixture without invoking Petrel. These package-level checks do not qualify real OAuth, cross-host interoperability, downstream apps, deployments, or migration/restore operations.
