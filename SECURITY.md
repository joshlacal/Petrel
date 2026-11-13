# Security policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 2.x | Yes: security fixes are released as 2.x patch or minor versions |
| 1.x and earlier | No: upgrade to 2.x (see [CHANGELOG.md](CHANGELOG.md)) |

Only the latest 2.x release receives fixes. Security fixes ship as patch releases where
possible, so a dependency declared with `.upToNextMinor(from: "2.0.0")` picks them up without code
changes.

## Reporting a vulnerability

Report privately through GitHub: open the repository's **Security** tab and choose
**Report a vulnerability**
([direct link](https://github.com/joshlacal/Petrel/security/advisories/new)).

If that form is unavailable to you, send a direct message to the maintainer on Bluesky,
[@josh.uno](https://bsky.app/profile/josh.uno), asking for a private channel. Do not include
vulnerability details in the first message.

Do not report suspected vulnerabilities in public issues, pull requests or discussions.

Please include:

- the affected product (`Petrel`, `PetrelCrypto`, `PetrelOAuthServer`, …) and version or commit;
- the platform (iOS, macOS, Linux, and which credential-storage backend if relevant);
- reproduction steps or a minimal test case;
- the impact you expect and any fix you suggest.

## What happens next

1. Acknowledgement within 3 business days.
2. The maintainer confirms the issue and the affected versions.
3. A fix is developed and tested privately.
4. Disclosure is coordinated with you: a GitHub security advisory is published together with the
   patched release, crediting you unless you prefer otherwise.

## Security-relevant design

A short map of where Petrel defends against the obvious attacks, for reviewers and reporters.

- **Server-side request forgery (client).** Requests Petrel makes on its own behalf to hosts it did
  not choose (identity resolution, DID documents, `did:web`, permissioned-space hosts) resolve the
  host first and refuse private, loopback, link-local and reserved addresses, again on every
  redirect; cleartext HTTP is allowed only to loopback names. On Apple platforms the address
  actually connected to is checked too; on Linux it cannot be (see
  [LINUX_SUPPORT.md](LINUX_SUPPORT.md#what-differs-from-apple-platforms)).
  `Sources/Petrel/Network/IPAddress.swift`, `Sources/Petrel/Identity/IdentityTransport.swift`
  (`HardenedIdentityHTTPTransport`), `Sources/Petrel/Network/HardenedURLSessionDelegate.swift`.
- **Server-side request forgery and DNS rebinding (authorization server).** `PetrelOAuthServer`
  fetches client metadata only over a transport that connects to the addresses it approved, and
  refuses any other transport unless the host sets `OAuthRemoteFetchPolicy.allowsUnpinnedTransport`.
  `Sources/PetrelOAuthServer/Clients/OAuthRemoteFetch.swift`; the pinning implementation is
  `Sources/PetrelOAuthServerNIO/PinnedNIOOAuthRemoteTransport.swift` (product
  `PetrelOAuthServerNIO`, package trait `OAuthServerNIO`).
- **Token binding.** OAuth sessions use PAR, PKCE and DPoP; DPoP private keys live in the same
  credential storage as the session. `Sources/Petrel/Auth/OAuth/`.
- **Credential storage.** Sessions and DPoP keys go to the Apple Keychain, libsecret, or
  AES-256-GCM encrypted files with owner-only permissions; the file store never generates or logs
  a key and refuses temporary directories and symlinks. `Sources/Petrel/Storage/`.
- **Response size limits.** Every response read by `NetworkService` is capped at 10 MiB on the wire
  and after decompression by default (`NetworkResponseLimits`), so a hostile server cannot exhaust
  memory. Callers that need larger bodies raise the limit for a scoped operation with
  `NetworkService.withResponseLimits(_:operation:)`. `Sources/Petrel/Network/NetworkService.swift`.
- **Signatures.** K-256 and P-256 signatures are verified in low-S form only, matching the
  AT Protocol cryptography spec. `Sources/PetrelCrypto/`.
- **Uploaded images.** Image uploads strip EXIF/GPS and other metadata by default and fail closed
  rather than upload an image that could not be stripped.
  `Sources/Petrel/Core/Utils/ImageMetadataStripper.swift`.
