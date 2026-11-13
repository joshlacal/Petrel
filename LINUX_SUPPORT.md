# Linux support

Every library product in the root package builds and is tested on Linux. CI runs the full
test suite, a debug build and a release build on Ubuntu 22.04 (`swift:6.1.2-jammy`, Swift 6.1.2)
with strict concurrency, and fails on any compiler warning in Petrel-owned code
(`.github/workflows/swift.yml`, `Scripts/verify-owned-warnings.sh`). Swift 6.1 is the minimum
toolchain (`swift-tools-version: 6.1`).

## System prerequisites

The `Petrel` product links `libsecret` on Linux (through the `CLibSecret` and `CLibSecretShim`
targets) so it can use a desktop keyring when one is running. Install the development packages
before building:

**Debian / Ubuntu** (what CI installs):
```bash
sudo apt-get install -y libsecret-1-dev libglib2.0-dev pkg-config
```

**Fedora / RHEL:**
```bash
sudo dnf install -y libsecret-devel glib2-devel pkg-config
```

**Arch Linux:**
```bash
sudo pacman -S --noconfirm libsecret glib2 pkgconf
```

At run time only the shared libraries are needed (`libsecret-1-0` and `libglib2.0-0` on
Debian/Ubuntu).

## What differs from Apple platforms

| Area | Linux behaviour |
|---|---|
| Networking | `URLSession` comes from `FoundationNetworking` (libcurl). Petrel imports it wherever it uses `URLSession`; your code must do the same (`#if canImport(FoundationNetworking)`). |
| SSRF and DNS rebinding | Before every request Petrel resolves the host and refuses private, loopback, link-local and reserved addresses, on Linux as on Apple platforms. On Apple platforms it then checks the address the connection actually used (server-trust and task metrics). swift-corelibs-foundation offers neither hook (checked on Swift 6.1.2: task metrics are never delivered), and libcurl resolves the host again when it connects, so on Linux a hostile DNS server that answers differently the second time can still steer a request to a private address. Where that matters (a server fetching URLs that users supply), run Petrel behind an egress proxy or firewall that blocks private ranges. |
| Credential storage | No Keychain. See [Credential storage](#credential-storage). |
| Keychain access groups | Apple-only. Passing an `accessGroup` has no effect on Linux backends. |
| Secure Enclave signing | `SecureEnclaveP256Signer` (PetrelCrypto) exists only on iOS, macOS and visionOS. Software P-256 and K-256 keys work everywhere. |
| Image metadata stripping | `ImageMetadataStripper` rewrites JPEG, PNG, WebP and GIF losslessly in pure Swift on every platform, so uploads keep stripping metadata by default on Linux. Other image types (HEIC, HEIF, AVIF, TIFF, …) need ImageIO and are refused on Linux with `ImageMetadataStrippingError.unsupportedImageFormat`; nothing is uploaded unstripped. Pass `stripMetadata: false` to send bytes untouched. |
| Event-stream WebSockets | All WebSocket connections use `URLSessionWebSocketTask`, which on Linux works only if the system libcurl was built with WebSocket support. The libcurl 7.81 in Ubuntu 22.04, and so in the `swift:6.1.2-jammy` image CI uses, is not: connections fail at once. `PetrelFirehose` and `PetrelJetstream` report this as `FirehoseSubscriptionError.webSocketTransportUnavailable` and let you replace the transport: conform a WebSocket client of your choice (for example one built on swift-nio) to `FirehoseWebSocketSessionFactory` / `FirehoseWebSocketSession` and pass it as `sessionFactory` in the subscription or `JetstreamClient` configuration. Petrel does not ship such a transport. The generated subscription methods on `ATProtoClient` (`client.com.atproto.sync.subscribeRepos()`, `subscribeLabels()`) have no replaceable transport, so on such systems use `PetrelFirehose` instead. Frame decoding, commit verification and everything else in both products work unchanged on Linux. |
| OAuth sign-in | There is no system web-authentication sheet. Open the URL returned by `startOAuthFlow` yourself and pass the redirect back with `handleOAuthCallback(url:)` (for example from a loopback HTTP listener). |
| OAuth server metadata fetches | `PetrelOAuthServer` refuses to fetch client metadata over a transport that does not pin the approved IP addresses. The pinning NIO transport lives in the nested `Server/` package (`PetrelOAuthServerHummingbird`), which builds on Linux. |
| DNS TXT records | Handle (`_atproto`) and permission-set (`_lexicon`) lookups use c-ares through swift-async-dns-resolver 0.8.1, which returns each character-string of a TXT record as a separate record. A TXT value split across several strings is therefore not joined on Linux, and a split `did=` value is read truncated. A `did=` line for a `did:plc` or an ordinary `did:web` fits in one 255-byte string, so normal handle and Lexicon resolution is unaffected. |
| Identity redirects in tests | The hardened identity transport's redirect handling (bounded hops, private-address refusal, no redirects for DID documents) is unit-tested only on Apple platforms, because swift-corelibs-foundation cannot redirect from a custom `URLProtocol`. The same code runs on Linux, but no Linux test drives a redirect. The scheduled `Live network smoke` workflow runs the live identity tests on `swift:6.1.2-jammy`, which cover the transport against real hosts (not redirects specifically) and are not a pull-request gate. |

## Credential storage

Authenticated clients store sessions and DPoP keys through a `SecureStorage` backend chosen per
client by `CredentialStorageConfiguration`.

### Platform default (`.platformDefault`)

On Linux the platform default picks a backend once per process:

1. **Secret Service via libsecret** (GNOME Keyring, KDE Wallet) when a Secret Service daemon
   answers.
2. **Encrypted files** otherwise (containers, CI, headless servers): AES-256-GCM, one file per
   secret, configured by environment variables:
   - `PETREL_MASTER_KEY` (required): Base64 of a 32-byte key. If it is missing, storage fails
     closed with `missingMasterKey`; Petrel never generates, persists or logs a key.
   - `PETREL_SECRETS_DIR` (optional): the directory for the files. Defaults to
     `$HOME/.petrel-secrets`.

If neither backend can be initialised, every storage operation throws a storage-unavailable
error that names the underlying cause; the process is never terminated.

### Explicit encrypted files (`.encryptedFiles(directory:masterKey:)`)

To choose the directory and key in code, and to give two clients separate stores in one process,
pass an explicit configuration:

```swift
import Foundation
import Petrel

let directory = URL(fileURLWithPath: "/var/lib/example-app/credentials", isDirectory: true)
let masterKey: Data = try loadKeyFromYourSecretManager()  // 32 bytes

let client = try await ATProtoClient(
    oauthConfig: OAuthConfig(
        clientId: "https://example.com/oauth/client-metadata.json",
        redirectUri: "https://example.com/oauth/callback",
        scope: "atproto transition:generic"
    ),
    namespace: "com.example.app",
    credentialStorage: .encryptedFiles(directory: directory, masterKey: masterKey)
)
```

Omit `masterKey` to read it from `PETREL_MASTER_KEY`. Existing files in the directory must
decrypt with the key before the configuration is accepted.

### File-store rules (both routes)

- The path must be absolute. Temporary directories (`/tmp`, `/private/tmp`, `/var/tmp`) and
  symbolic links are rejected (`insecureDirectoryPath`).
- The directory must be owned by the running user and is kept at mode `0700`; files are written
  atomically with mode `0600` (`insecurePermissions` otherwise).
- Generate a key with `openssl rand -base64 32` and keep it in your secret manager, not next to the
  files.

## Deployment examples

### systemd

```ini
[Service]
User=example-app
ExecStart=/opt/example-app/bin/App
Environment="PETREL_SECRETS_DIR=/var/lib/example-app/secrets"
# Load PETREL_MASTER_KEY from a credential or environment file readable only by the service.
EnvironmentFile=/etc/example-app/petrel.env
```

### Docker

Build and run on the same distribution so the Swift runtime libraries match:

```dockerfile
FROM swift:6.1.2-jammy AS builder
RUN apt-get update && apt-get install -y libsecret-1-dev libglib2.0-dev pkg-config
WORKDIR /build
COPY . .
RUN swift build -c release

FROM swift:6.1.2-jammy-slim
RUN apt-get update && apt-get install -y libsecret-1-0 libglib2.0-0 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /build/.build/release/App /app/App
ENV PETREL_SECRETS_DIR=/data/secrets
VOLUME ["/data/secrets"]
# Inject PETREL_MASTER_KEY at run time from your orchestrator's secret store.
ENTRYPOINT ["/app/App"]
```

## Troubleshooting

**`missingMasterKey`**: the encrypted-file backend is in use and no key was supplied. Set
`PETREL_MASTER_KEY` or pass `masterKey:`.

**`insecureDirectoryPath` / `insecurePermissions`**: the secrets directory is temporary, a
symlink, owned by another user, or readable by others. Use a dedicated directory owned by the
service user.

**Desktop session without a keyring**: start the daemon
(`eval $(gnome-keyring-daemon --start --components=secrets)`) or let Petrel fall back to encrypted
files by setting `PETREL_MASTER_KEY`.

**Firehose or Jetstream connections fail immediately on Ubuntu 22.04**: see the WebSocket row in
the table above.
