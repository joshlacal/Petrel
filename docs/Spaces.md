# AT Protocol Spaces (alpha)

AT Protocol Spaces is Bluesky's proposal for permissioned data: records that live in a *space* owned by an authority account and are readable only by accounts and apps the space's policy admits. Spaces is an **alpha protocol**. Its Lexicons, wire formats and URI syntax change between alpha releases without compatibility guarantees, and Petrel follows each release it adopts with source-breaking changes and no dual support for older formats. Do not build anything on Spaces that you cannot migrate.

Petrel currently targets the **November 12 alpha**: `bluesky-social/atproto` commit `d4def6e9f521896ed8222f576d54923d00b5fbeb`, published to npm as `0.0.0-spaces-alpha-20261112204144`. Servers running an earlier alpha speak a different credential and MAC format and will not interoperate with this version of Petrel.

Petrel's Spaces support has two layers:

- **Generated bindings** for every Spaces Lexicon, called like any other XRPC endpoint (`client.com.atproto.space.createSpace(input:)` and so on). They use your client's normal authentication and do not verify response MACs.
- **A hand-written credential client**, `SpaceCredentialManager`, which exchanges a delegation token for a space credential, signs credential-authenticated reads, and verifies the MACs and archives that come back. `SpaceSTAR` verifies repository archives, and `SpaceRef` and `ATProtocolURI` model space identifiers.

## Space identifiers

A space is named by an AT-URI with a `space` path segment:

```text
at://SPACE-DID/space/SPACE-TYPE/SKEY
at://SPACE-DID/space/SPACE-TYPE/SKEY/AUTHOR-DID/COLLECTION/RKEY
```

The first form names the space itself and is modelled by `SpaceRef` (`spaceDID`, `spaceType`, `skey`, `uriString()`). `SpaceRef(uriString:)` accepts only that three-part form. The second form names a record inside the space, written by one of its members; `SpaceRef.recordURI(authorDID:collection:recordKey:)` builds it.

This space form is not part of the published AT-URI specification. Petrel follows the Spaces reference implementation, whose `at-uri` parser accepts it, because Spaces endpoints such as `com.atproto.space.createRecord` return space record URIs in `at-uri` fields. Consequently `ATProtocolURI(uriString:)`, its `Decodable` conformance and `ATProtocolURI.isValidATURI(_:)` accept both grammars by default. When a field must hold only a published-grammar AT-URI, pass `grammar: .restricted`, or check `isSpace` on a decoded value:

<!-- compile-example: spaces-uri-grammar -->
```swift
import Petrel

func classify(_ string: String) throws -> String {
    let uri = try ATProtocolURI(uriString: string)
    guard uri.isSpace else {
        return "public record in \(uri.authority)"
    }
    // A space URI is rejected by the published grammar.
    _ = ATProtocolURI.isValidATURI(string, grammar: .restricted)
    let space = try SpaceRef(
        spaceDID: uri.spaceDID ?? "",
        spaceType: uri.spaceType ?? "",
        skey: uri.skey ?? ""
    )
    return "space \(space.uriString()), author \(uri.authorDID ?? "none")"
}
```

The URI syntax is one of the parts of the alpha most likely to change: upstream has discussed moving space URIs to an `at:space/` form before the beta. If that happens, Petrel's parsers will change with it.

## Generated bindings

Petrel vendors the `com.atproto.space`, `com.atproto.memberspace`, `com.atproto.managedspace` and `com.atproto.personalspace` Lexicons and generates Swift types and client methods for all of them. The space policy is an open union of `com.atproto.personalspace.policy`, `com.atproto.memberspace.policy` and `com.atproto.managedspace.policy`.

Generated calls behave like every other Petrel endpoint: they return `(responseCode, data)`, use the client's OAuth or session authentication, and are bounded by the client's response limits. They do **not** check response MACs. Owner-authenticated calls (for example `createSpace`, `getSpace`, `listSpaces`, or `getRepo` on your own repository) are authenticated by the owner's OAuth exchange and transport. `getSpace` requires authentication as the space authority; other accounts can read the published `com.atproto.space.policy` record instead.

<!-- compile-example: spaces-list-spaces -->
```swift
import Petrel

func listMySpaces(client: ATProtoClient) async throws -> [SpaceRef] {
    let (code, output) = try await client.com.atproto.space.listSpaces(
        input: .init()
    )
    guard code == 200, let output else { return [] }
    return output.spaces.map(\.space)
}
```

### Changes from the October alphas

The November 12 alpha renamed most Spaces methods, fields and errors. If you used an earlier Petrel build with Spaces, these are the changes you will see:

| Before | Now |
| --- | --- |
| `getSpaceCredential`, input `credentialKid` | `authorizeSpaceSync` (`ComAtprotoSpaceAuthorizeSpaceSync`), input `credentialKey`, optional `notify`; output adds `spaceRev` |
| `listRepos`, `.Repo` | `listWriters` (`ComAtprotoSpaceListWriters`); entries are `ComAtprotoSpaceDefs.RepoWrite` or `.RepoRemoved` |
| `notifyWrite`, `notifyCredentialRevoked` | `notifyRepoUpdate`, `notifyCredentialsRevoked` |
| `registerNotify`, `unregisterNotify`, `notifySpaceDeleted` | removed; `confirmRegistration` and `notifySpaceUpdate` are new |
| `memberspace.putMember`, `removeMember`, `ComAtprotoMemberspaceListMembers.Member` | `putMembers`, `removeMembers` (arrays), `ComAtprotoMemberspaceDefs.Member` |
| `managedspace.checkUserAccess` (`user`, `access` → `authorized`) | `checkAccess` (optional `repo`, `clientId` → `read`, `write`) |
| `createSpace` and `getSpace` output `uri`; `listSpaces` parameter `did`, entries `{ uri }` | output `space`; parameter `spaceDid`; entries `{ space, repoRev?, data?, spaceRev? }` |
| `removeWriter` input `did`; `listRecords` `reverse`; `listBlobs` `since` | `repo`; removed; removed |
| `listRepoOps` output `commit` optional | `commit` required on every page |
| errors `NotSpaceOwner`, `UserNotAuthorized`, `BadSpaceMac`, `MalformedCursor` | `NotAuthorized`, `AccountNotAuthorized`, `InvalidSpaceMac`, `InvalidCursor`; new `RepoTakendown`, `RepoDeactivated`, `RegistrationNotConfirmed`, `InvalidRepoFile`, `RepoMismatch`, `InvalidSpaceMeta` |
| space declaration `name`, `nameLang` | optional `title`, `titleLang` |
| `SpaceMAC.commit`, `SpaceMAC.record`, `SpaceMAC.verify(mac:expected:)` | removed; verification happens inside `SpaceCredentialManager` |
| `SpaceSTAR.verify(archive:space:repo:sharedSecret:mac:maximumArchiveBytes:)` | `SpaceSTAR.verify(archive:space:repo:maximumArchiveBytes:)` |

`SpaceCredential.spaceRev`, `SpaceSTAR.maximumMetadataBytes` and `SpaceSTAR.maximumKeyBytes` are new.

## Credential-authenticated reads

An app reading a space it does not own needs a *space credential*, a short-lived JWT issued by the space's host. `SpaceCredentialManager` obtains and uses it:

1. It resolves the space authority's DID document and uses its `#atproto_pds` service as the space host (through `SpaceHostResolver`, or your own `authorityHostProvider`).
2. It asks the user's PDS for a delegation token with the generated `com.atproto.space.getDelegationToken` call on your `ATProtoClient`, or calls your `delegationTokenProvider`.
3. It posts the delegation token, a fresh P-256 `credentialKey` (as a `did:key`) and, if you supplied a `clientAttestationProvider`, a client attestation to `com.atproto.space.authorizeSpaceSync`. The exchange is a plain JSON body, with no delegation `Authorization` header and no HTTP signature. Petrel does not request update notifications.
4. It verifies the returned credential before caching it: `typ` `atproto-space-credential+jwt`, algorithm `ES256` or `ES256K`, `kid` `#atproto` (or `<authority DID>#atproto`), issuer equal to the authority DID, subject equal to the space URI, `cnf.kid` equal to the requested key, no `aud` claim, a lifetime of at most one hour, and a valid signature from the authority's `#atproto` key (refetched once if verification fails).

`get(url:space:audience:maximumArchiveBytes:maximumBlobBytes:)` then sends a GET with `Authorization: Atproto-Space-Credential <token>`, an `Atproto-Space-Audience` header, and an RFC 9421 HTTP message signature (label and tag `atproto-space-credential`) over exactly those two values, made with the credential key. The audience defaults to the URL's `repo` query parameter, or the space authority's DID when there is none. Only `https` URLs, or `http` to `localhost`, `127.0.0.1` or `::1`, are accepted. It returns the raw `(Data, HTTPURLResponse)`, including response headers.

<!-- compile-example: spaces-credential-get-repo -->
```swift
import Foundation
import Petrel

func readMemberRepository(
    client: ATProtoClient,
    space: SpaceRef,
    member: String,
    memberPDS: URL
) async throws -> VerifiedSpaceRepository {
    let manager = SpaceCredentialManager(
        client: client,
        resolver: SpaceHostResolver(didResolver: IdentityResolver())
    )

    var components = URLComponents(
        url: memberPDS.appendingPathComponent("xrpc/com.atproto.space.getRepo"),
        resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
        URLQueryItem(name: "space", value: space.uriString()),
        URLQueryItem(name: "repo", value: member),
    ]
    guard let url = components?.url else { throw URLError(.badURL) }

    // Accept an archive up to 64 MiB for this one request.
    let (archive, response) = try await manager.get(
        url: url,
        space: space,
        maximumArchiveBytes: 64 * 1_048_576
    )
    guard response.statusCode == 200 else { throw URLError(.badServerResponse) }

    // The MAC and archive were verified inside `get`; parse the records.
    return try SpaceSTAR.verify(archive: archive, space: space, repo: member)
}
```

### Response MACs

For `getLatestCommit`, `getRepo`, `listRepoOps` and `getRecord`, the response must be authenticated by the repository's author. Petrel resolves the author's `#atproto_kem` P-256 key (through the `authorKEMKeyProvider` you pass, or by fetching the author's DID document), derives a shared secret with an HPKE secret export (RFC 9180 base mode, P-256 / HKDF-SHA256 / export-only, `info` `atproto-mac`, 32 bytes), and sends the ephemeral key share in an `Accept-Signature` header. Every request, page and retry uses a fresh ephemeral key.

The response must carry exactly one signature with the profile's tag (`atproto-space-commit` or `atproto-space-record`), covering exactly the `Atproto-Space-Commit` or `Atproto-Space-Record` header; anything missing or malformed fails closed with `SpaceVerificationError.malformedHeader`. The commit header must match the commit in the JSON body or the archive metadata (space, repo, revision and digest). The record header must match the requested record URI and the CID Petrel recomputes from the returned record. For `getRepo`, the MAC is checked against the archive metadata before any record is parsed.

If the MAC does not match, Petrel refetches the author's KEM key once (with `forceRefresh: true`) and retries with another ephemeral key, since the author may have rotated it. A second mismatch throws `SpaceMAC.Failure.mismatch`. A custom `authorKEMKeyProvider` that caches keys must honour `forceRefresh`. The KEM key is distinct from the account's signing key.

Other methods sent through `get`, such as `getBlob`, `listRecords` or `listWriters`, are credential-authenticated but carry no MAC.

`listRepoOps` verifies the commit MAC on each page. If you maintain repository state incrementally from its operations, compare your complete final record set's digest with the verified commit before trusting it. `SpaceSetHash` in `PetrelCrypto` computes that digest.

### Repository archives

`getRepo` returns a STAR archive (`application/vnd.dasl.star`). `SpaceSTAR.verify(archive:space:repo:maximumArchiveBytes:)` returns a `VerifiedSpaceRepository` (`revision`, `data`, and `records` with `path`, `cid` and `bytes`) only after it has checked:

- the archive header and canonical DAG-CBOR metadata of type `atproto-space-repo`, with `ver` 1 and the expected space and repo;
- framing: `0x01` before each path/record pair, a single `0x00` at the end and nothing after it;
- strictly ascending record paths of the form `collection/rkey`, with valid NSIDs and record keys;
- canonical DAG-CBOR for every record;
- the set digest over all paths and CIDs against the metadata's `data`.

Replace your local copy of the repository atomically with a verified snapshot, removing records absent from it.

The standalone verifier checks the archive's internal consistency and that it names the requested space and repo. It does **not** authenticate the author. Use it on its own only for an archive whose transport you already trust, such as the owner's own repository fetched with OAuth (see below) or bytes already returned by `SpaceCredentialManager.get`. Never treat a self-consistent digest on an archive from an untrusted source as proof of who wrote it.

## Owner OAuth reads

An account reading its own space repository can call the generated `getRepo` with its normal OAuth session. Generated calls are bounded by the client's `NetworkService` response limits, 10 MiB by default. To accept a larger response for one call, wrap it in `NetworkService.withResponseLimits(_:operation:)`; each field of the scoped limits is clamped to 128 MiB (`SpaceSTAR.defaultMaximumArchiveBytes`). Then validate the archive:

<!-- compile-example: spaces-owner-get-repo -->
```swift
import Petrel

func readOwnRepository(
    client: ATProtoClient,
    space: SpaceRef,
    owner: DID
) async throws -> VerifiedSpaceRepository? {
    let bytes = SpaceSTAR.defaultMaximumArchiveBytes
    let limits = NetworkResponseLimits(maximumWireBytes: bytes, maximumDecodedBytes: bytes)
    let (code, output) = try await NetworkService.withResponseLimits(limits) {
        try await client.com.atproto.space.getRepo(
            input: .init(space: space, repo: owner)
        )
    }
    guard code == 200, let output else { return nil }
    return try SpaceSTAR.verify(
        archive: output.data,
        space: space,
        repo: owner.didString()
    )
}
```

Here authentication comes from the owner's OAuth exchange and transport, and `SpaceSTAR.verify` checks the archive's integrity and request identity.

The scope does not apply to requests that `SpaceCredentialManager` and `SpaceHostResolver` send on their own sessions; use `get`'s `maximumArchiveBytes` and `maximumBlobBytes` for those.

## Bounds

- STAR records are limited to 1 MiB (`SpaceSTAR.maximumRecordBytes`), archive metadata to 64 KiB (`maximumMetadataBytes`), and record paths to 4 KiB (`maximumKeyBytes`). The standalone verifier's default archive limit is 128 MiB (`defaultMaximumArchiveBytes`).
- `SpaceCredentialManager` uses a hardened session with the default 10 MiB response limit when it creates its own session. `maximumArchiveBytes` replaces that limit for a single `getRepo` request and also bounds that archive's verification; `maximumBlobBytes` does the same for a single `getBlob` request. Both are clamped to 128 MiB and ignored for other methods.
- Petrel buffers and verifies complete responses, so a blob or archive larger than 128 MiB cannot be read through these APIs. These limits are deliberate and do not imply support for large repositories. Petrel's usual DAG-CBOR depth and size limits also apply.

## Credential lifetime and invalidation

A cached credential is reused until its `exp` minus a margin of min(60 s, half its issued lifetime `exp - iat`), and never later than that margin before one lifetime after Petrel received it, so a device clock behind the issuer's cannot extend reuse. A 60-second credential is therefore reused for about 30 seconds. Each renewal exchanges a new credential bound to a new key. Concurrent requests for the same space share one exchange.

`credential(for:)` returns the cached or freshly exchanged `SpaceCredential` (`token`, `expiresAt`, `keyRawRepresentation`, `spaceRev`). `invalidate(_:)` drops the cached credential, cancels an exchange in flight, and makes Petrel discard any response that completes after the invalidation. A `401 CredentialRevoked` response to `get` drops the cached credential so it is never presented again; the response is returned unchanged and not retried.

Petrel does not purge anything you derived from a space. When a space is deleted or access ends, removing your projections and caches is up to you, as is treating a deliberately recreated space as new state.

## Credential exchange errors

Failures of the `authorizeSpaceSync` exchange are reported as `SpaceCredentialError`:

| Response | Error |
| --- | --- |
| HTTP 400 with structured error `SpaceDeleted` (checked first) | `.spaceDeleted(host:message:)` |
| HTTP 400 or 404 with `SpaceNotFound` | `.authorizationRefused(host:error:message:)`, `error` `SpaceNotFound` |
| HTTP 400 or 401 with `InvalidClientAttestation` | `.tokenRejected(host:error:message:evidence:)`, `error` `InvalidClientAttestation` |
| HTTP 400 `InvalidDelegationToken`, or HTTP 400/401 `InvalidToken`, `ExpiredToken`, `invalid_token` | `.tokenRejected(host:error:message:evidence:)` |
| HTTP 403, or `AccountNotAuthorized`, `AppNotAuthorized`, `NotAuthorized` and similar | `.authorizationRefused(host:error:message:)` |
| anything else, including `RepoTakendown`, `RepoDeactivated` and `UpstreamFailure` | `.exchangeFailed(statusCode:message:)` |

Only an exact structured `SpaceDeleted` error means the space was deleted; a message that merely mentions the text does not. `SpaceNotFound` means "not found or not authorized": the host does not have the space, does not authorize this account (the reference host answers `SpaceNotFound` in place of `AccountNotAuthorized`), or the space is not public and no delegation token was sent. `tokenRejected` means a presented token was invalid, not that membership changed. For a rejected delegation token, Petrel may attach `evidence` from a short `com.atproto.server.describeServer` probe of the host; it skips that probe for a rejected client attestation. `RepoTakendown`, `RepoDeactivated` and `UpstreamFailure` are exchange failures and never mean the space is gone (unless sent with HTTP 403, which Petrel reports as `authorizationRefused`).

<!-- compile-example: spaces-error-classification -->
```swift
import Petrel

enum SpaceAccess {
    case available(SpaceCredential)
    case deleted
    case noAccess
    case retryLater
}

func checkAccess(manager: SpaceCredentialManager, space: SpaceRef) async -> SpaceAccess {
    do {
        return .available(try await manager.credential(for: space))
    } catch let error as SpaceCredentialError {
        switch error {
        case .spaceDeleted:
            await manager.invalidate(space)
            return .deleted
        case .authorizationRefused:
            return .noAccess
        default:
            // Token rejections and exchange failures do not mean the
            // space is gone or that membership changed.
            return .retryLater
        }
    } catch {
        return .retryLater
    }
}
```

## Lexicon provenance

The Spaces Lexicons are pinned separately from Petrel's weekly standard-Lexicon sync. `generator/provenance/spaces.json` records the upstream repository, the commit (`d4def6e9…`), the SHA-256 of the upstream source archive, the four namespaces, and the SHA-256 of each of the 39 vendored schema files. `generator/lexicons/com/atproto/space/.pin` holds the same commit.

- `python3 Scripts/space_lexicon_provenance.py verify` checks that the vendored files match the manifest byte for byte. With `--archive <tarball>` it also checks a downloaded upstream archive against the recorded hash and file inventory.
- `Scripts/vendor-space-lexicons.sh` (`space_lexicon_provenance.py vendor`) downloads the pinned archive, verifies it, and replaces the four namespaces. Update the manifest only after reviewing a new upstream release.
- `Scripts/sync-standard-lexicons.sh` excludes the four Spaces namespaces from the standard sync and runs the provenance check before and after it, so the weekly sync cannot change them.

## Reproducible checks

Petrel's Spaces tests include the RFC 9180 export-only P-256 HPKE vector and a complete STAR fixture produced by `Scripts/generate-space-vectors.py`, an independent Python implementation (cbor2 and blake3) of the `d4def6e9` wire format that does not use Petrel. These are package-level checks. They do not establish interoperability with a live alpha host, real OAuth deployments, or migration and restore operations.
