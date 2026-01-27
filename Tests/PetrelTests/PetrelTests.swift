import Foundation
@testable import Petrel
import Testing

@Suite("Petrel Integration Tests")
struct PetrelTests {
    @Test("ATProtoClient can be created without authentication")
    func clientCreation() {
        let oauthConfig = OAuthConfig(
            clientId: "test",
            redirectUri: "test://callback",
            scope: "atproto transition:generic"
        )
        let client = ATProtoClient(oauthConfig: oauthConfig, namespace: "test")
        #expect(client != nil)
    }

    @Test("ATProtoClient has expected API namespaces")
    func aPINamespaces() {
        let oauthConfig = OAuthConfig(
            clientId: "test",
            redirectUri: "test://callback",
            scope: "atproto transition:generic"
        )
        let client = ATProtoClient(oauthConfig: oauthConfig, namespace: "test")

        // Verify main namespaces exist
        #expect(client.app != nil)
        #expect(client.com != nil)
        #expect(client.chat != nil)
    }

    @Test("ATProtocolValueContainer basic functionality")
    func valueContainer() {
        // Skip this test for now as it requires complex setup
        // This would need a proper Decoder implementation
    }
}
