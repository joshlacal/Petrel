# Petrel 2.0 Runnable Examples

This directory contains self-contained, runnable Swift 6 starter projects and scripts demonstrating AT Protocol OAuth, custom Lexicon overlays, real-time Jetstream/Firehose streaming, and Bluesky posting with `Petrel`.

## Example Matrix

| Example | Type | What It Demonstrates | Credentials Required |
| :--- | :--- | :--- | :--- |
| [`LoopbackOAuthSwiftUI/`](LoopbackOAuthSwiftUI/) | SwiftUI App Package | Zero-deploy `OAuthConfig.loopback(port: 8765)` + `NWListener`, `WebAuthenticationSession` custom-scheme mode, Keychain session restore, paginated `getTimeline`, and live `RichText` facet composer | Any ATProto / Bluesky account (OAuth) |
| [`StatusphereOverlay/`](StatusphereOverlay/) | Overlay Library + CLI | Custom `xyz.statusphere.*` Lexicons, `"kind": "overlay"` manifest, generated `PetrelStatusphere` Swift package, `PetrelStatusphereLexicons.register()`, `CIDv1` DAG-CBOR hashing, and live PDS record read/write | None for `--demo` & `list`; App Password for `post` |
| [`JetstreamLiveCLI/`](JetstreamLiveCLI/) | Swift 6 CLI Package | Filtered live `PetrelJetstream` streaming, `zstd` dictionary compression, keyword filtering, custom collection wildcards (`xyz.statusphere.*`), and durable file-backed `FirehoseCursorStorage` | None |
| [`FirehoseDemo.swift`](FirehoseDemo.swift) | Root Package Executable | Binary `com.atproto.sync.subscribeRepos` (`PetrelFirehose`), labeler streams (`com.atproto.label.subscribeLabels`), and Jetstream in ~120 lines | None |
| [`PostCLIDemo/`](PostCLIDemo/) | Swift 6 CLI Package | Interactive terminal client demonstrating `AuthMode.legacy` App Password login, profile lookup, and posting | App Password |
| [`SimplePostCLI.swift`](SimplePostCLI.swift) | Single-File Script | Raw Foundation `URLSession` XRPC requests (`createSession` + `createRecord`) showing the wire protocol underneath Petrel | App Password |

---

## Quick Run Commands

### 1. Custom `xyz.statusphere.*` Lexicon Overlay (`StatusphereOverlay`)

```bash
cd Examples/StatusphereOverlay
swift run StatusphereCLI --demo
swift run StatusphereCLI list --actor atproto.com
```

### 2. Live Jetstream Streaming & Filtering (`JetstreamLiveCLI`)

```bash
cd Examples/JetstreamLiveCLI
swift run JetstreamLiveCLI --keyword swift --compress --limit 10
```

### 3. Zero-Deploy OAuth + SwiftUI Reference App (`LoopbackOAuthSwiftUI`)

```bash
cd Examples/LoopbackOAuthSwiftUI
swift build
swift run LoopbackOAuthSwiftUI
```

### 4. Binary Relay Firehose & Labeler Stream (`FirehoseDemo`)

From the repository root:

```bash
swift run FirehoseDemo firehose --count 15
swift run FirehoseDemo labels --count 15
swift run FirehoseDemo jetstream --count 15
```

### 5. Interactive App-Password CLI (`PostCLIDemo`)

```bash
cd Examples/PostCLIDemo
swift run PostCLIDemo
```

---

## Security Notes

- **Prefer OAuth 2.1 + DPoP (`AuthMode.publicOAuth`, `.gateway(_:)`, or `.cab`)** for all user-facing iOS, macOS, and web applications — start from [`LoopbackOAuthSwiftUI/`](LoopbackOAuthSwiftUI/).
- **Scoped App Passwords (`AuthMode.legacy`)** are intended only for headless scripts and developer CLIs. Interactive examples in this folder read App Passwords from standard input with terminal echo disabled (`termios`) so credentials never appear in shell history or process arguments.
