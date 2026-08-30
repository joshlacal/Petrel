# Petrel examples

This directory contains executable example scripts and projects demonstrating how to interact with AT Protocol and Bluesky using Swift.

## Available examples

| Example | Type | Description | Authentication |
|---|---|---|---|
| `FirehoseDemo.swift` | Standalone script | Connects to the Bluesky firehose WebSocket and decodes event frames in real time | None required |
| `SimplePostCLI.swift` | Standalone script | Posts to Bluesky using direct HTTPS XRPC requests via Foundation | App password |
| `PostCLIDemo/` | Swift Package CLI | Interactive CLI that uses the Petrel SDK to authenticate, post messages, and inspect profiles | App password |

## Requirements

- Swift 6.0 or later
- macOS 15.0 or later (or Linux with Swift 6.0 toolchain installed)

## Run the firehose monitor

`FirehoseDemo.swift` subscribes to the unauthenticated firehose stream (`com.atproto.sync.subscribeRepos`) and parses incoming commit events.

To run the script:

```bash
swift Examples/FirehoseDemo.swift
```

To stop the stream, press `Ctrl+C`.

## Run the standalone poster

`SimplePostCLI.swift` demonstrates direct HTTP XRPC requests against Bluesky servers without depending on the Petrel package. It creates a session via `com.atproto.server.createSession` and creates a record via `com.atproto.repo.createRecord`.

To run the script:

```bash
swift Examples/SimplePostCLI.swift
```

When prompted:
1. Enter your handle (for example, `alice.bsky.social`).
2. Enter an app password generated from your account settings (passwords are entered securely without terminal echo).
3. Enter your post text.

## Run the Petrel CLI application

`PostCLIDemo` is a full Swift Package executable that depends on the local `Petrel` library target. It demonstrates client initialization, password authentication (`loginWithPassword`), record creation with `AppBskyFeedPost`, and profile lookup with `app.bsky.actor.getProfile`.

To build and run `PostCLIDemo`:

```bash
cd Examples/PostCLIDemo
swift run PostCLIDemo
```

The interactive menu lets you:
1. Compose and submit a post to Bluesky.
2. View your profile information (display name, description, followers count, follows count, posts count).
3. Exit the application.

## Obtain an app password

Posting examples require an app-specific password rather than your primary account credentials.

To create an app password:
1. Open your account settings at <https://bsky.app/settings/app-passwords>.
2. Select **Add App Password**.
3. Enter a label (for example, `Petrel CLI Demo`).
4. Copy the generated password token (`xxxx-xxxx-xxxx-xxxx`).

App passwords can be revoked at any time from the same settings page without modifying your main account password.

### Security note

Interactive example scripts prompt for secrets securely on standard input with terminal echo disabled (`termios`). Do not pass passwords or credentials via command-line arguments, environment variables, or shell scripts where they may be exposed in process listings or shell history.

## Production authentication

These command-line demos use app password authentication (`AuthMode.legacy`). For production user-facing applications, use OAuth with DPoP (`AuthMode.publicOAuth` or `AuthMode.gateway`). See `Sources/Petrel/Petrel.docc/Authentication.md` and `GETTING_STARTED.md` for details on configuring OAuth flows.
