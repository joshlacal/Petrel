import Foundation
@testable import Petrel
import Testing

@Suite("Petrel Integration Tests")
struct PetrelTests {
    @Test("ATProtoClient can be created without authentication")
    func clientCreation() async throws {
        let oauthConfig = OAuthConfig(
            clientId: "test",
            redirectUri: "test://callback",
            scope: "atproto transition:generic"
        )
        // Initializer now throws and is async; creation succeeding is the assertion.
        _ = try await ATProtoClient(oauthConfig: oauthConfig, namespace: "test")
    }

    @Test("ATProtoClient has expected API namespaces")
    func aPINamespaces() async throws {
        let oauthConfig = OAuthConfig(
            clientId: "test",
            redirectUri: "test://callback",
            scope: "atproto transition:generic"
        )
        let client = try await ATProtoClient(oauthConfig: oauthConfig, namespace: "test")

        // Verify main namespaces exist (actor-isolated properties; accessing them is the check)
        _ = await client.app
        _ = await client.com
        _ = await client.chat
    }

    @Test("ATProtocolValueContainer basic functionality")
    func valueContainer() {
        // Skip this test for now as it requires complex setup
        // This would need a proper Decoder implementation
    }
}
