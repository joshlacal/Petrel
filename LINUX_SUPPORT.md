# Linux support

Petrel provides native Linux support for Swift applications, with automatic runtime selection between desktop keyring integration and encrypted file storage.

## Storage backends

`KeychainManager` coordinates secure credential and DPoP key storage on Linux through two backends:

1. **`LibSecretStore` (desktop Linux)**: Integrates with Secret Service daemons (GNOME Keyring, KDE Wallet) through `CLibSecretShim` wrapping `libsecret`. Active when a desktop keyring service is available.
2. **`FileEncryptedStore` (headless Linux / servers)**: Encrypts secrets using AES-256-GCM. Active when no Secret Service daemon is available (in containers, CI environments, and headless servers).

The backend is selected automatically at runtime by `KeychainManager.createLinuxStorage()`. If neither backend can be initialized, operations throw `KeychainError.storageUnavailable`.

## System prerequisites

To build Petrel with `libsecret` support on Linux, install the required development packages for your distribution:

**Debian / Ubuntu:**
```bash
sudo apt-get install -y libsecret-1-dev libglib2.0-dev pkg-config
```

**Fedora / RHEL / CentOS:**
```bash
sudo dnf install -y libsecret-devel glib2-devel pkg-config
```

**Arch Linux:**
```bash
sudo pacman -S --noconfirm libsecret glib2 pkgconf
```

**Alpine Linux:**
```bash
apk add libsecret-dev glib-dev pkgconf
```

## Configuring encrypted file storage

When running in headless environments where `LibSecretStore` is unavailable, `FileEncryptedStore` manages encrypted credential files on disk.

### Environment variables

- **`PETREL_MASTER_KEY`**: A base64-encoded 32-byte (256-bit) symmetric encryption key used for AES-GCM operations.
  - Mandatory when running without `LibSecretStore`. Construction fails closed with `missingMasterKey` if unset; ephemeral keys are never generated and key material is never logged.
  - Generate a secure key:
    ```bash
    export PETREL_MASTER_KEY=$(openssl rand -base64 32)
    ```
- **`PETREL_SECRETS_DIR`**: Path to the directory where encrypted secret files are stored.
  - If unset, Petrel defaults to `$HOME/.petrel-secrets`. `$HOME` must be set; temporary directory paths (`/tmp`, `/private/tmp`, `/var/tmp`) are unconditionally rejected.
  - The directory must be owner-only (`0700`) and owned by the running `uid`. Stored secret files are written atomically with owner-only `0600` permissions.

### Deployment configurations

#### Systemd service

```ini
[Unit]
Description=Petrel AT Protocol Application
After=network.target

[Service]
Type=simple
User=petrel
Group=petrel
WorkingDirectory=/opt/petrel-app
ExecStart=/opt/petrel-app/bin/App
Restart=always

Environment="PETREL_MASTER_KEY=YOUR_BASE64_ENCODED_32_BYTE_KEY"
Environment="PETREL_SECRETS_DIR=/var/lib/petrel-app/secrets"

[Install]
WantedBy=multi-user.target
```

#### Docker container

```dockerfile
FROM swift:6.0 as builder
WORKDIR /build
COPY . .
RUN swift build -c release

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    libsecret-1-0 \
    libglib2.0-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/.build/release/App /app/App

# Inject PETREL_MASTER_KEY at container run time
ENV PETREL_SECRETS_DIR="/data/secrets"
VOLUME ["/data/secrets"]

ENTRYPOINT ["/app/App"]
```

#### Kubernetes deployment and secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: petrel-secrets
type: Opaque
stringData:
  master-key: "YOUR_BASE64_ENCODED_32_BYTE_KEY"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petrel-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: petrel-app
  template:
    metadata:
      labels:
        app: petrel-app
    spec:
      containers:
      - name: app
        image: registry.example.com/petrel-app:latest
        env:
        - name: PETREL_MASTER_KEY
          valueFrom:
            secretKeyRef:
              name: petrel-secrets
              key: master-key
        - name: PETREL_SECRETS_DIR
          value: "/var/lib/petrel/secrets"
        volumeMounts:
        - name: secret-storage
          mountPath: "/var/lib/petrel/secrets"
      volumes:
      - name: secret-storage
        persistentVolumeClaim:
          claimName: petrel-secrets-pvc
```

## Using KeychainManager on Linux

`KeychainManager` provides identical method signatures across all supported platforms.

### Storing and retrieving generic data

```swift
import Foundation
import Petrel

let namespace = "com.example.app"
let key = "access-token"
let tokenData = Data("sample-token".utf8)

// Store
try KeychainManager.store(
    key: key,
    value: tokenData,
    namespace: namespace
)

// Retrieve
let retrievedData = try KeychainManager.retrieve(
    key: key,
    namespace: namespace
)

// Delete
try KeychainManager.delete(
    key: key,
    namespace: namespace
)
```

### Storing and retrieving DPoP keys

```swift
import CryptoKit
import Petrel

let dpopKey = P256.Signing.PrivateKey()
let keyTag = "com.example.app.dpop"

// Store DPoP private key
try KeychainManager.storeDPoPKey(
    dpopKey,
    keyTag: keyTag
)

// Retrieve DPoP private key
let retrievedKey = try KeychainManager.retrieveDPoPKey(
    keyTag: keyTag
)

// Delete DPoP key
try KeychainManager.deleteDPoPKey(
    keyTag: keyTag
)
```

### Asynchronous API variants

For actor contexts or non-blocking execution, `KeychainManager` provides async methods:

```swift
// Async store and retrieve
try await KeychainManager.storeAsync(
    key: "session",
    value: sessionData,
    namespace: "com.example.app"
)

let sessionData = try await KeychainManager.retrieveAsync(
    key: "session",
    namespace: "com.example.app"
)

try await KeychainManager.deleteAsync(
    key: "session",
    namespace: "com.example.app"
)
```

## Initializing ATProtoClient on Linux

`ATProtoClient` automatically coordinates with `KeychainManager`:

```swift
import Foundation
import Petrel

let oauthConfig = OAuthConfig(
    clientId: "https://example.com/client-metadata.json",
    redirectUri: "https://example.com/callback",
    scope: "atproto transition:generic"
)

let client = try await ATProtoClient(
    oauthConfig: oauthConfig,
    namespace: "com.example.app"
)
```

## Troubleshooting

### "Missing protected master key for file-encrypted storage" (`missingMasterKey`)

- **Cause**: The application is running with `FileEncryptedStore` on a headless system and `PETREL_MASTER_KEY` is not set.
- **Solution**: Generate a 32-byte base64 key (`openssl rand -base64 32`) and export `PETREL_MASTER_KEY` in your environment or service definition.

### Missing Secret Service daemon on desktop

- **Cause**: Running in a desktop session where GNOME Keyring or KDE Wallet is stopped.
- **Solution**: Ensure the daemon is running in your session (e.g. `eval $(gnome-keyring-daemon --start --components=secrets)`), or permit Petrel to fall back to `FileEncryptedStore`.
