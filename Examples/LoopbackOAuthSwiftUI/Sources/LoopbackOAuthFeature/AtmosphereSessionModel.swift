import Foundation
import Observation
import Petrel

/// `@MainActor @Observable` session and timeline coordinator demonstrating Petrel 2.0 OAuth,
/// Keychain session persistence, paginated timeline fetching, and `RichText` post publishing.
@MainActor
@Observable
public final class AtmosphereSessionModel {
    public enum AuthConfigurationPreset: String, CaseIterable, Identifiable, Sendable {
        /// Zero-deploy localhost development (`http://localhost` client ID + `127.0.0.1:8765` redirect).
        case loopbackDev = "Loopback Dev (Zero-Deploy)"
        /// Production custom-URL-scheme OAuth (`https://.../oauth-client-metadata.json` + `ASWebAuthenticationSession`).
        case customSchemeProd = "Production Custom Scheme"

        public var id: String {
            rawValue
        }
    }

    public static let loopbackPort = 8765

    public var preset: AuthConfigurationPreset = .loopbackDev
    public var handleInput = ""
    public private(set) var isSignedIn = false
    public private(set) var activeDID: String?
    public private(set) var activeHandle: String?
    public private(set) var activePDSURL: URL?

    public private(set) var timelinePosts: [AppBskyFeedDefs.FeedViewPost] = []
    public private(set) var timelineCursor: String?

    public private(set) var isBusy = false
    public var errorMessage: String?

    private var client: ATProtoClient?

    public init() {}

    // MARK: - Client & Session Restoration

    public func bootstrapSessionIfAvailable() async {
        do {
            let activeClient = try await ensureClient()
            if await activeClient.hasValidSession() {
                await syncAccountSummary(from: activeClient)
                try await refreshTimeline()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func switchPreset(_ newPreset: AuthConfigurationPreset) async {
        guard preset != newPreset else { return }
        preset = newPreset
        client = nil
        isSignedIn = false
        activeDID = nil
        activeHandle = nil
        activePDSURL = nil
        timelinePosts = []
        timelineCursor = nil
        await bootstrapSessionIfAvailable()
    }

    // MARK: - Sign In (Loopback HTTP Server & Custom-Scheme ASWebAuthenticationSession)

    /// Starts the zero-deploy loopback OAuth flow, opens the system browser via `openBrowser`,
    /// awaits the `127.0.0.1:8765/callback` redirect, and exchanges the code with DPoP + PKCE.
    public func signInWithLoopback(openBrowser: (URL) -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let activeClient = try await ensureClient()
            let server = try LoopbackCallbackServer(port: Self.loopbackPort)

            let trimmedHandle = handleInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let authURL: URL
            if trimmedHandle.isEmpty {
                authURL = try await activeClient.startOAuthFlow(server: URL(string: "https://bsky.social")!)
            } else {
                authURL = try await activeClient.startOAuthFlow(identifier: trimmedHandle)
            }

            async let callbackURL = server.waitForCallback()
            openBrowser(authURL)
            let receivedURL = try await callbackURL

            try await activeClient.handleOAuthCallback(url: receivedURL)
            await syncAccountSummary(from: activeClient)
            try await refreshTimeline()
        } catch {
            errorMessage = describeError(error)
        }
    }

    /// Starts a custom-URL-scheme OAuth flow suitable for `WebAuthenticationSession` / `ASWebAuthenticationSession`
    /// on iOS and macOS (`com.example.atmosphere:/oauth/callback`).
    public func prepareCustomSchemeAuthorizationURL() async throws -> URL {
        let activeClient = try await ensureClient()
        let trimmedHandle = handleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHandle.isEmpty {
            return try await activeClient.startOAuthFlow(server: URL(string: "https://bsky.social")!)
        } else {
            return try await activeClient.startOAuthFlow(identifier: trimmedHandle)
        }
    }

    public func completeOAuthCallback(url: URL) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let activeClient = try await ensureClient()
            try await activeClient.handleOAuthCallback(url: url)
            await syncAccountSummary(from: activeClient)
            try await refreshTimeline()
        } catch {
            errorMessage = describeError(error)
        }
    }

    public func signOut() async {
        isBusy = true
        defer { isBusy = false }

        do {
            if let client {
                try await client.logout()
            }
        } catch {
            errorMessage = describeError(error)
        }
        isSignedIn = false
        activeDID = nil
        activeHandle = nil
        activePDSURL = nil
        timelinePosts = []
        timelineCursor = nil
    }

    // MARK: - Timeline & Posting

    public func refreshTimeline() async throws {
        let activeClient = try await ensureClient()
        let (_, output) = try await activeClient.app.bsky.feed.getTimeline(
            input: .init(limit: 25)
        )
        timelinePosts = output?.feed ?? []
        timelineCursor = output?.cursor
    }

    public func loadMoreTimeline() async {
        guard let cursor = timelineCursor, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let activeClient = try await ensureClient()
            let (_, output) = try await activeClient.app.bsky.feed.getTimeline(
                input: .init(limit: 25, cursor: cursor)
            )
            if let more = output?.feed {
                timelinePosts.append(contentsOf: more)
            }
            timelineCursor = output?.cursor
        } catch {
            errorMessage = describeError(error)
        }
    }

    /// Publishes a post using `BskyAgent.post(_:)`, which detects mentions, links, and hashtags,
    /// resolves `@handles` to DIDs, computes UTF-8 byte slices, and writes `app.bsky.feed.post`.
    public func publishPost(text: String) async throws {
        let activeClient = try await ensureClient()
        _ = try await activeClient.bsky.post(text)
        try await refreshTimeline()
    }

    /// Generates the production `oauth-client-metadata.json` document matching the custom-scheme preset.
    public func productionClientMetadataJSON() throws -> String {
        let prodConfig = Self.productionOAuthConfig()
        let metadata = try prodConfig.clientMetadataDocument(
            applicationType: .native,
            clientName: "Atmosphere SwiftUI Starter"
        )
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Helpers

    private func ensureClient() async throws -> ATProtoClient {
        if let client {
            return client
        }
        let oauthConfig: OAuthConfig
        let namespace: String
        switch preset {
        case .loopbackDev:
            oauthConfig = OAuthConfig.loopback(
                port: Self.loopbackPort,
                scope: "atproto transition:generic"
            )
            namespace = "com.example.atmosphere.loopback"
        case .customSchemeProd:
            oauthConfig = Self.productionOAuthConfig()
            namespace = "com.example.atmosphere.prod"
        }

        let created = try await ATProtoClient(
            oauthConfig: oauthConfig,
            namespace: namespace,
            authMode: .publicOAuth
        )
        client = created
        return created
    }

    private static func productionOAuthConfig() -> OAuthConfig {
        OAuthConfig(
            clientId: "https://atmosphere.example.com/oauth-client-metadata.json",
            redirectUri: "com.example.atmosphere:/oauth/callback",
            scope: "atproto transition:generic"
        )
    }

    private func syncAccountSummary(from activeClient: ATProtoClient) async {
        let info = await activeClient.getActiveAccountInfo()
        activeDID = info.did
        activeHandle = info.handle
        activePDSURL = info.pdsURL
        isSignedIn = info.did != nil
    }

    private func describeError(_ error: any Error) -> String {
        if let statusError = error as? AccountStatusError {
            let reason = statusError.status.reason?.rawValue ?? "inactive"
            return "Account is \(reason) on PDS."
        }
        if let xrpcError = error as? ATProtoXRPCError {
            return "XRPC \(xrpcError.statusCode) \(xrpcError.error): \(xrpcError.message ?? "")"
        }
        return error.localizedDescription
    }
}
