import Foundation
@testable import Petrel
import Testing

private final class WeakReference<Value: AnyObject>: Sendable {
  // Keep weak actor storage out of the async test frame for Swift 6.0 runtimes.
  nonisolated(unsafe) weak var value: Value?

  init(_ value: Value?) {
    self.value = value
  }
}

@Suite("ATProtoClient Simple Tests")
struct ATProtoClientSimpleTests {
  // MARK: - Test Setup

  private func createTestClient() async throws -> ATProtoClient {
    let oauthConfig = OAuthConfig(
      clientId: "test-client-id",
      redirectUri: "test://callback",
      scope: "atproto transition:generic"
    )
    return try await ATProtoClient(oauthConfig: oauthConfig, namespace: "test")
  }

  // MARK: - Client Initialization Tests

  @Test("ATProtoClient initializes with correct configuration")
  func clientInitialization() async throws {
    let oauthConfig = OAuthConfig(
      clientId: "test-client",
      redirectUri: "catbird://callback",
      scope: "atproto transition:generic"
    )
    let client = try await ATProtoClient(oauthConfig: oauthConfig, namespace: "catbird-test")

    // Test API namespaces are available
    let _: ATProtoClient.App = await client.app
    let _: ATProtoClient.Com = await client.com
    let _: ATProtoClient.Chat = await client.chat
  }

  @Test("Client configuration validation")
  func clientConfigValidation() async throws {
    // Test valid configuration
    let validConfig = OAuthConfig(
      clientId: "valid-client-id",
      redirectUri: "valid://callback",
      scope: "atproto transition:generic"
    )
    _ = try await ATProtoClient(oauthConfig: validConfig, namespace: "test")

    // Test another valid configuration
    let anotherConfig = OAuthConfig(
      clientId: "test-client",
      redirectUri: "catbird://auth/callback",
      scope: "atproto"
    )
    _ = try await ATProtoClient(oauthConfig: anotherConfig, namespace: "test")
  }

  // MARK: - API Namespace Tests

  @Test("API namespaces are properly structured")
  func aPINamespaceStructure() async throws {
    let client = try await createTestClient()

    // Verify main namespaces exist and are properly typed
    let _: ATProtoClient.App = await client.app
    let _: ATProtoClient.Com = await client.com
    let _: ATProtoClient.Chat = await client.chat

    // Verify sub-namespaces exist
    let _: ATProtoClient.App.Bsky = await client.app.bsky
    let _: ATProtoClient.Com.Atproto = await client.com.atproto
    let _: ATProtoClient.Chat.Bsky = await client.chat.bsky

    // Verify specific API endpoints exist
    let _: ATProtoClient.App.Bsky.Feed = await client.app.bsky.feed
    let _: ATProtoClient.App.Bsky.Actor = await client.app.bsky.actor
    let _: ATProtoClient.Com.Atproto.Server = await client.com.atproto.server
  }

  // MARK: - Basic API Call Structure Tests

  @Test("Timeline API accepts proper parameters")
  func timelineAPIStructure() async throws {
    let client = try await createTestClient()

    // Test parameter structure
    let params = AppBskyFeedGetTimeline.Parameters(
      algorithm: "reverse-chronological",
      limit: 50,
      cursor: "test-cursor"
    )

    #expect(params.algorithm == "reverse-chronological", "Should set algorithm parameter")
    #expect(params.limit == 50, "Should set limit parameter")
    #expect(params.cursor == "test-cursor", "Should set cursor parameter")

    // Verify API method exists (won't call it, just check it compiles)
    let _: () async throws -> Void = {
      // This tests that the method signature is correct without issuing a request.
      _ = try await client.app.bsky.feed.getTimeline(input: params)
    }
  }

  @Test("Actor profile API accepts proper parameters")
  func actorProfileAPIStructure() async throws {
    let client = try await createTestClient()

    // Test parameter structure
    let params = try AppBskyActorGetProfile.Parameters(actor: ATIdentifier(string: "test.bsky.social"))

    #expect(params.actor.stringValue() == "test.bsky.social", "Should set actor parameter")

    // Verify API method exists
    let _: () async throws -> Void = {
      _ = try await client.app.bsky.actor.getProfile(input: params)
    }
  }

  // MARK: - Configuration Tests

  @Test("OAuth configuration properties are accessible")
  func oAuthConfigurationAccess() {
    let config = OAuthConfig(
      clientId: "test-client-123",
      redirectUri: "myapp://oauth/callback",
      scope: "atproto transition:generic transition:chat.bsky"
    )

    #expect(config.clientId == "test-client-123", "Should store client ID")
    #expect(config.redirectUri == "myapp://oauth/callback", "Should store redirect URI")
    #expect(config.scope.contains("atproto"), "Should include atproto scope")
    #expect(config.scope.contains("transition:chat.bsky"), "Should include chat scope")
  }

  // MARK: - Memory Management Tests

  @Test("Client can be deallocated properly")
  func clientDeallocation() async throws {
    var client: ATProtoClient? = try await createTestClient()

    let weakClient = WeakReference(client)
    client = nil

    // Allow deallocation
    await Task.yield()

    #expect(weakClient.value == nil, "Client should be deallocated when no strong references remain")
  }

  // MARK: - Thread Safety Tests

  @Test("Client can be accessed from multiple tasks")
  func basicThreadSafety() async throws {
    let client = try await createTestClient()

    // Create multiple concurrent tasks that access the client
    let completedAccessCount = await withTaskGroup(of: Int.self) { group in
      for _ in 0 ..< 5 {
        group.addTask {
          // Just access the namespace properties concurrently
          _ = await client.app
          _ = await client.com
          _ = await client.chat
          return 1
        }
      }

      var completedAccessCount = 0
      for await count in group {
        completedAccessCount += count
      }
      return completedAccessCount
    }

    #expect(completedAccessCount == 5, "Every concurrent namespace access should complete")
  }

  // MARK: - Parameter Validation Tests

  @Test("API parameters handle edge cases")
  func aPIParameterEdgeCases() {
    // Test with nil optional parameters
    let emptyParams = AppBskyFeedGetTimeline.Parameters()
    #expect(emptyParams.algorithm == nil, "Optional algorithm should be nil")
    #expect(emptyParams.limit == nil, "Optional limit should be nil")
    #expect(emptyParams.cursor == nil, "Optional cursor should be nil")

    // Test with minimum values
    let minParams = AppBskyFeedGetTimeline.Parameters(limit: 1)
    #expect(minParams.limit == 1, "Should accept minimum limit")

    // Test with maximum reasonable values
    let maxParams = AppBskyFeedGetTimeline.Parameters(limit: 100)
    #expect(maxParams.limit == 100, "Should accept maximum reasonable limit")

    // Test with empty strings
    let emptyStringParams = AppBskyFeedGetTimeline.Parameters(
      algorithm: "",
      cursor: ""
    )
    #expect(emptyStringParams.algorithm == "", "Should accept empty algorithm")
    #expect(emptyStringParams.cursor == "", "Should accept empty cursor")
  }

  // MARK: - URL Validation Tests

  @Test("OAuth redirect URI validation")
  func redirectURIValidation() async throws {
    // Test various URI formats
    let uriFormats = [
      "myapp://oauth/callback",
      "https://example.com/auth/callback",
      "custom-scheme://auth",
      "app.bundle.id://oauth",
    ]

    for uri in uriFormats {
      let config = OAuthConfig(
        clientId: "test",
        redirectUri: uri,
        scope: "atproto"
      )
      _ = try await ATProtoClient(oauthConfig: config, namespace: "test")
    }
  }

  // MARK: - Scope Validation Tests

  @Test("OAuth scope combinations")
  func oAuthScopeCombinations() async throws {
    let scopeCombinations = [
      "atproto",
      "atproto transition:generic",
      "atproto transition:chat.bsky",
      "atproto transition:generic transition:chat.bsky",
    ]

    for scope in scopeCombinations {
      let config = OAuthConfig(
        clientId: "test",
        redirectUri: "test://callback",
        scope: scope
      )
      _ = try await ATProtoClient(oauthConfig: config, namespace: "test")
    }
  }

  // MARK: - Error Handling Structure Tests

  @Test("API methods have proper error handling structure")
  func aPIErrorHandlingStructure() async throws {
    let client = try await createTestClient()
    let params = AppBskyFeedGetTimeline.Parameters(limit: 20)

    // Test that API methods are marked as throws
    do {
      // This will fail in test environment, but we're testing the structure
      _ = try await client.app.bsky.feed.getTimeline(input: params)
      Issue.record("Expected timeline request to fail in the test environment")
    } catch {
      // Reaching this branch proves the generated method propagates its failure.
    }
  }

  // MARK: - Unauthenticated Client Tests

  @Test("Unauthenticated client can be created")
  func unauthenticatedClientCreation() async {
    let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
    let mode = await client.currentAuthMode
    #expect(mode == .none, "Should be in .none auth mode")
  }

  @Test("AuthMode enum has expected cases")
  func authModeEnumCases() {
    // Verify all expected cases exist
    let none: AuthMode = .none
    let legacy: AuthMode = .legacy
    let publicOAuth: AuthMode = .publicOAuth
    let gateway: AuthMode = .gateway
    let cab: AuthMode = .cab(backendURL: URL(string: "https://example.com")!)

    #expect(none == .none)
    #expect(legacy == .publicOAuth || legacy == .legacy) // just verify it compiles
    #expect(publicOAuth == .publicOAuth)
    #expect(gateway == .gateway)
    #expect(cab != .none)
  }
}
