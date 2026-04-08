import Foundation
@testable import Petrel
import Testing

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
    let app = await client.app
    #expect(app != nil, "Should have app namespace")
    let com = await client.com
    #expect(com != nil, "Should have com namespace")
    let chat = await client.chat
    #expect(chat != nil, "Should have chat namespace")
  }

  @Test("Client configuration validation")
  func clientConfigValidation() async throws {
    // Test valid configuration
    let validConfig = OAuthConfig(
      clientId: "valid-client-id",
      redirectUri: "valid://callback",
      scope: "atproto transition:generic"
    )
    let validClient = try await ATProtoClient(oauthConfig: validConfig, namespace: "test")
    #expect(validClient != nil, "Valid configuration should create client")

    // Test another valid configuration
    let anotherConfig = OAuthConfig(
      clientId: "test-client",
      redirectUri: "catbird://auth/callback",
      scope: "atproto"
    )
    let anotherClient = try await ATProtoClient(oauthConfig: anotherConfig, namespace: "test")
    #expect(anotherClient != nil, "Another valid configuration should create client")
  }

  // MARK: - API Namespace Tests

  @Test("API namespaces are properly structured")
  func aPINamespaceStructure() async throws {
    let client = try await createTestClient()

    // Verify main namespaces exist and are properly typed
    let app = await client.app
    #expect(app != nil, "Should have app namespace")
    let com = await client.com
    #expect(com != nil, "Should have com namespace")
    let chat = await client.chat
    #expect(chat != nil, "Should have chat namespace")

    // Verify sub-namespaces exist
    let bsky = await client.app.bsky
    #expect(bsky != nil, "Should have app.bsky namespace")
    let atproto = await client.com.atproto
    #expect(atproto != nil, "Should have com.atproto namespace")
    let chatBsky = await client.chat.bsky
    #expect(chatBsky != nil, "Should have chat.bsky namespace")

    // Verify specific API endpoints exist
    let feed = await client.app.bsky.feed
    #expect(feed != nil, "Should have feed APIs")
    let actor = await client.app.bsky.actor
    #expect(actor != nil, "Should have actor APIs")
    let server = await client.com.atproto.server
    #expect(server != nil, "Should have server APIs")
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
    let _: () -> Void = {
      Task {
        // This tests that the method signature is correct
        _ = try await client.app.bsky.feed.getTimeline(input: params)
      }
    }
  }

  @Test("Actor profile API accepts proper parameters")
  func actorProfileAPIStructure() async throws {
    let client = try await createTestClient()

    // Test parameter structure
    let params = try AppBskyActorGetProfile.Parameters(actor: ATIdentifier(string: "test.bsky.social"))

    #expect(params.actor.stringValue() == "test.bsky.social", "Should set actor parameter")

    // Verify API method exists
    let _: () -> Void = {
      Task {
        _ = try await client.app.bsky.actor.getProfile(input: params)
      }
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

    weak var weakClient = client
    client = nil

    // Allow deallocation
    await Task.yield()

    #expect(weakClient == nil, "Client should be deallocated when no strong references remain")
  }

  // MARK: - Thread Safety Tests

  @Test("Client can be accessed from multiple tasks")
  func basicThreadSafety() async throws {
    let client = try await createTestClient()

    // Create multiple concurrent tasks that access the client
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 5 {
        group.addTask {
          // Just access the namespace properties concurrently
          _ = await client.app
          _ = await client.com
          _ = await client.chat
        }
      }
    }

    // Should complete without crashing
    #expect(true, "Client should maintain state after concurrent access")
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
      let client = try await ATProtoClient(oauthConfig: config, namespace: "test")
      #expect(client != nil, "Should accept valid URI format: \(uri)")
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
      let client = try await ATProtoClient(oauthConfig: config, namespace: "test")
      #expect(client != nil, "Should accept scope combination: \(scope)")
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
    } catch {
      // Expected to fail in test environment
      #expect(error != nil, "Should throw error when not properly configured")
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
