# LoopbackOAuthSwiftUI

A SwiftUI app for macOS and iOS that signs in with Petrel's OAuth client, loads the timeline and posts.

- Development sign-in with `OAuthConfig.loopback(port: 8765)`: a `127.0.0.1:8765` listener (`LoopbackCallbackServer`) receives the redirect, so you do not need to publish client metadata.
- Production sign-in with an `https://.../oauth-client-metadata.json` client ID and SwiftUI's `webAuthenticationSession`. The app shows the metadata that `OAuthConfig.clientMetadataDocument(...)` generates.
- The session is restored across launches with `hasValidSession()` and `getActiveAccountInfo()`.
- The timeline view pages through `app.bsky.feed.getTimeline` and renders `RichText(post:)` segments. The composer shows the UTF-8 byte and 300-grapheme limits and posts with `client.bsky.post(...)`.

## Build and run

```bash
cd Examples/LoopbackOAuthSwiftUI
swift build
swift run LoopbackOAuthSwiftUI
```

To embed the UI inside an Xcode `.xcodeproj` for iOS Simulator or physical devices, import the `LoopbackOAuthFeature` library target and mount `RootContentView()` inside your app's `WindowGroup`, registering your custom URL scheme (`com.example.atmosphere`) in `Info.plist` when switching from Loopback Dev to Production Custom Scheme mode.
