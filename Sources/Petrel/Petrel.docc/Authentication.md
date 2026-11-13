# Authentication

Authenticate users across any Personal Data Server using AT Protocol OAuth (PAR, PKCE, and DPoP), zero-deploy loopback OAuth, `ASWebAuthenticationSession`, or legacy app passwords.

## OAuth Authentication (Recommended)

OAuth is the standard authentication mechanism for new AT Protocol applications. Given a handle (`alice.bsky.social`) or DID (`did:plc:...`), ``ATProtoClient`` discovers the account's Authorization Server, submits a Pushed Authorization Request (`PAR`) with PKCE `S256`, and binds tokens to a per-session `ES256` DPoP key stored in secure storage.

To start from a hosting provider's PDS or entryway URL (`https://bsky.social`) instead, call `startOAuthFlow(server:scopes:)`; see <doc:OAuthClient>.



<!-- compile-example: oauth-authentication -->
```swift
import Foundation
import Petrel

func authenticateExample(callbackURL: URL) async throws {
    let oauth = OAuthConfig(
        clientId: "https://yourapp.example.com/oauth-client-metadata.json",
        redirectUri: "com.example.yourapp:/oauth/callback",
        scope: "atproto transition:generic"
    )
    let client = try await ATProtoClient(
        oauthConfig: oauth,
        namespace: "com.example.yourapp"
    )

    let authURL = try await client.startOAuthFlow(identifier: "alice.bsky.social")
    print("Open this URL: \(authURL)")

    // Present authURL via ASWebAuthenticationSession / WebAuthenticationSession,
    // receive callbackURL, and complete token exchange:
    try await client.handleOAuthCallback(url: callbackURL)
}
```

## Zero-Deploy Loopback OAuth for Local Development

During local development or prototyping, use ``OAuthConfig/loopback(port:path:scope:)`` so you can sign in immediately without deploying a public `client-metadata.json` file:

<!-- compile-example: oauth-loopback-dev -->
```swift
import Foundation
import Petrel

func createLoopbackDevelopmentClient() async throws -> ATProtoClient {
    let loopback = OAuthConfig.loopback(
        port: 8765,
        path: "/callback",
        scope: "atproto transition:generic"
    )
    return try await ATProtoClient(
        oauthConfig: loopback,
        namespace: "dev.local.petrel"
    )
}
```

## Presenting the Flow with `ASWebAuthenticationSession`

In UIKit or AppKit apps (or when you want explicit control over `prefersEphemeralWebBrowserSession`), wrap `ASWebAuthenticationSession` around `startOAuthFlow` and `handleOAuthCallback`:

<!-- compile-example: oauth-aswebauth-session -->
```swift
import AuthenticationServices
import Foundation
import Petrel

@MainActor
final class NativeOAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }

    func signIn(client: ATProtoClient, identifier: String, callbackScheme: String) async throws {
        let authURL = try await client.startOAuthFlow(identifier: identifier)
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callback: .customScheme(callbackScheme)
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: AuthError.invalidCallbackURL)
                }
            }
            session.presentationContextProvider = self
            session.start()
        }
        try await client.handleOAuthCallback(url: callbackURL)
    }
}
```

## Handling OAuth Callbacks via Scene or App Delegates

If your app opens the authorization URL in an external browser or receives universal/custom-scheme links via `onOpenURL`, forward the redirect URL to ``ATProtoClient/handleOAuthCallback(url:)``:

<!-- compile-example: oauth-callback -->
```swift
import Foundation
import Petrel

func handleOAuthCallbackExample(url: URL, client: ATProtoClient) {
    Task {
        do {
            try await client.handleOAuthCallback(url: url)
        } catch {
            print("OAuth callback failed: \(error)")
        }
    }
}
```

## Token Management & Multi-Account Storage

Petrel refreshes tokens automatically before expiry and whenever a resource server rejects an expired access token. Because AT Protocol OAuth refresh tokens are single-use, concurrent XRPC calls share a single in-flight refresh operation and serialize DPoP nonce updates per server. Tokens and DPoP keys are isolated under your `namespace` in the Apple Keychain (or Secret Service / encrypted file store on Linux), and ``ATProtoClient/logout()`` revokes the token at the Authorization Server before clearing local credentials.

## Legacy Authentication

Petrel exposes legacy password authentication through ``AuthMode/legacy`` and `loginWithPassword` for CLI scripts, headless bots, or servers that have not yet enabled OAuth. Always supply a scoped Bluesky App Password rather than a primary account password. Prefer OAuth for all interactive applications.

<!-- compile-example: oauth-legacy-password -->
```swift
import Petrel

func signInWithAppPassword(identifier: String, appPassword: String) async throws -> ATProtoClient {
    let client = try await ATProtoClient(
        oauthConfig: OAuthConfig.loopback(port: 8765),
        namespace: "com.example.cli",
        authMode: .legacy
    )
    _ = try await client.loginWithPassword(identifier: identifier, password: appPassword)
    return client
}
```

## Next Steps

- Read <doc:OAuthClient> for server-first login, granular `ATProtoScopeSet` permissions, confidential `private_key_jwt` clients, and ``AccountStatusError`` handling.
- Explore <doc:ArchitectureAndMentalModel> for a comparison of `.publicOAuth`, `.gateway(_:)`, `.cab`, and `.legacy` topologies.
