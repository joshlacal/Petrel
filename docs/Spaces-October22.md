# October 22 Spaces compatibility

Petrel targets the fixed ATProto Spaces alpha implementation `ac0c9f15392f6f0298d71dc52aa88c05036150be`, published as `0.0.0-spaces-alpha-20261022141228`. The vendored Space and SimpleSpace schemas are byte-identical to that revision, and their provenance manifest is checked independently of regeneration. Ordinary weekly lexicon sync preserves this separately pinned corpus.

`SpaceCredentialManager` exchanges a user delegation token in the JSON request body with a fresh P-256 `credentialKid`. Its optional client-attestation provider supports authorities that require application identity. The exchange carries no delegation Authorization header and no HTTP signature. Credential reads use `Atproto-Space-Credential`, the `atproto-space-credential` signature label/tag, and exact Authorization/audience bytes. Authority discovery uses the account's `#atproto_pds`; credential JWT headers must identify `#atproto`.

## Verified credential reads

Use the existing `get(url:space:audience:)` method for credential-authenticated reads. It returns `(Data, HTTPURLResponse)` and retains the response headers. For `getLatestCommit`, `getRepo`, `listRepoOps`, and `getRecord`, it resolves the author's dedicated `#atproto_kem` key and generates a separate ephemeral key for every HTTP request. A MAC mismatch refreshes the author key once and retries with another ephemeral key; repeated failure is terminal. Missing/malformed MACs fail closed. Other operations, including `getBlob` and `listRepos`, do not acquire MAC headers.

A successful `getRecord` returns only after URI binding, MAC verification, and canonical record/CID verification. A successful `getRepo` returns only after the complete STAR archive has passed metadata/MAC validation, minimal-varint/framing/ordering checks, canonical record validation, and full LtHash digest verification. `listRepoOps` verifies each returned commit's MAC; callers retaining incremental repository state must still compare the complete final set digest before publishing it. Pages without a commit carry no response MAC, but still receive a fresh request key share.

The optional `authorKEMKeyProvider` accepts `(repoDID, forceRefresh)` and returns a P-256 `did:key`. A custom caching provider must honor `forceRefresh`; the default fetches the current DID document through the hardened resolver. KEM keys and credential-binding keys are distinct.

## Owner OAuth and archive consumers

Generated endpoint calls retain their existing OAuth transport behavior. They do not claim response-MAC or archive verification. Owner-OAuth callers of `getRepo` can validate the received complete archive with:

```swift
let verified = try SpaceSTAR.verify(archive: bytes, space: space, repo: ownerDID)
```

This verifies the archive's internal digest and request identity. Authentication comes from the owner's OAuth exchange and transport. Credential callers must use `SpaceCredentialManager.get`, or supply the matching request secret and response MAC to `SpaceSTAR.verify(archive:space:repo:sharedSecret:mac:)`. Never treat an unauthenticated archive's self-consistent digest as proof of its author.

`VerifiedSpaceRepository` exposes the revision, digest, and complete records (`path`, `cid`, `bytes`). Replace the caller's local repository atomically after verification, removing records absent from the new snapshot. Public repository CAR helpers remain separate and unchanged.

## Bounds and lifecycle

STAR records are limited to 1 MiB, metadata to 64 KiB, and the standalone verifier's default archive limit is 128 MiB. The credential manager retains its existing 10 MiB hardened network limit; this implementation buffers and verifies a complete response. These bounds are deliberate and do not establish large-repository capacity. Existing DAG-CBOR depth/node limits also apply.

A cached credential is reused until its `exp` less a margin of min(60 s, half its issued lifetime `exp - iat`), and never past that margin before one lifetime after local receipt, so a device clock behind the issuer's cannot extend reuse. A 60 s credential is therefore reused for about 30 s. Without an `iat` claim the margin is 60 s. Each renewal exchanges a fresh credential bound to a fresh key.

Only an exact structured `SpaceDeleted` error from the authority's credential exchange is classified as deletion. A body or message merely mentioning that text is not. `InvalidDelegationToken` at HTTP 400 is token rejection, not membership removal. Invalidation cancels acquisition, retires the credential generation, and discards responses that finish after that generation was invalidated. Callers remain responsible for purging their projections and caches, and for adopting a deliberately recreated Space as fresh state.

## Reproducible checks

The regression tests include the upstream RFC 9180 DHKEM vector, independent Python HMAC vectors, and a complete STAR fixture generated with Python `cbor2==5.6.5` and `blake3==1.0.8`. `Scripts/generate-space-vectors.py` regenerates that fixture without invoking Petrel. These package-level checks do not qualify real OAuth, cross-host interoperability, downstream apps, deployments, or migration/restore operations.
