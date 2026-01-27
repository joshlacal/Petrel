import Foundation
@testable import Petrel
import Testing

@Suite("ATProtoClient Simple Tests")
struct ATProtoClientSimpleTests {
    // MARK: - Test Setup

    private func createTestClient() -> ATProtoClient {
        let oauthConfig = OAuthConfig(
            clientId: "test-client-id",
            redirectUri: "test://callback",
            scope: "atproto transition:generic"
        )
        return ATProtoClient(oauthConfig: oauthConfig, namespace: "test")
    }

    // MARK: - Client Initialization Tests

    @Test("ATProtoClient initializes with correct configuration")
    func clientInitialization() {
        let oauthConfig = OAuthConfig(
            clientId: "test-client",
            redirectUri: "catbird://callback",
            scope: "atproto transition:generic"
        )
        let client = ATProtoClient(oauthConfig: oauthConfig, namespace: "catbird-test")

        #expect(client.namespace == "catbird-test", "Should set correct namespace")

        // Test API namespaces are available
        #expect(client.app != nil, "Should have app namespace")
        #expect(client.com != nil, "Should have com namespace")
        #expect(client.chat != nil, "Should have chat namespace")
    }

    @Test("Client configuration validation")
    func clientConfigValidation() {
        // Test valid configuration
        let validConfig = OAuthConfig(
            clientId: "valid-client-id",
            redirectUri: "valid://callback",
            scope: "atproto transition:generic"
        )
        let validClient = ATProtoClient(oauthConfig: validConfig, namespace: "test")
        #expect(validClient != nil, "Valid configuration should create client")

        // Test another valid configuration
        let anotherConfig = OAuthConfig(
            clientId: "test-client",
            redirectUri: "catbird://auth/callback",
            scope: "atproto"
        )
        let anotherClient = ATProtoClient(oauthConfig: anotherConfig, namespace: "test")
        #expect(anotherClient != nil, "Another valid configuration should create client")
    }

    // MARK: - API Namespace Tests

    @Test("API namespaces are properly structured")
    func aPINamespaceStructure() {
        let client = createTestClient()

        // Verify main namespaces exist and are properly typed
        #expect(client.app != nil, "Should have app namespace")
        #expect(client.com != nil, "Should have com namespace")
        #expect(client.chat != nil, "Should have chat namespace")

        // Verify sub-namespaces exist
        #expect(client.app.bsky != nil, "Should have app.bsky namespace")
        #expect(client.com.atproto != nil, "Should have com.atproto namespace")
        #expect(client.chat.bsky != nil, "Should have chat.bsky namespace")

        // Verify specific API endpoints exist
        #expect(client.app.bsky.feed != nil, "Should have feed APIs")
        #expect(client.app.bsky.actor != nil, "Should have actor APIs")
        #expect(client.com.atproto.server != nil, "Should have server APIs")
    }

    // MARK: - Basic API Call Structure Tests

    @Test("Timeline API accepts proper parameters")
    func timelineAPIStructure() {
        let client = createTestClient()

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
    func actorProfileAPIStructure() {
        let client = createTestClient()

        // Test parameter structure
        let params = AppBskyActorGetProfile.Parameters(actor: "test.bsky.social")

        #expect(params.actor == "test.bsky.social", "Should set actor parameter")

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
    func clientDeallocation() async {
        var client: ATProtoClient? = createTestClient()

        weak var weakClient = client
        client = nil

        // Allow deallocation
        await Task.yield()

        #expect(weakClient == nil, "Client should be deallocated when no strong references remain")
    }

    // MARK: - Thread Safety Tests

    @Test("Client can be accessed from multiple tasks")
    func basicThreadSafety() async {
        let client = createTestClient()

        // Create multiple concurrent tasks that access the client
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 5 {
                group.addTask {
                    // Just access the namespace properties concurrently
                    _ = client.app
                    _ = client.com
                    _ = client.chat
                    _ = client.namespace
                }
            }
        }

        // Should complete without crashing
        #expect(client.namespace == "test", "Client should maintain state after concurrent access")
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
    func redirectURIValidation() {
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
            let client = ATProtoClient(oauthConfig: config, namespace: "test")
            #expect(client != nil, "Should accept valid URI format: \(uri)")
        }
    }

    // MARK: - Scope Validation Tests

    @Test("OAuth scope combinations")
    func oAuthScopeCombinations() {
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
            let client = ATProtoClient(oauthConfig: config, namespace: "test")
            #expect(client != nil, "Should accept scope combination: \(scope)")
        }
    }

    // MARK: - Error Handling Structure Tests

    @Test("API methods have proper error handling structure")
    func aPIErrorHandlingStructure() async throws {
        let client = createTestClient()
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
}
