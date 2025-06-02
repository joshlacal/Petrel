import Foundation
@testable import Petrel
import Testing

@Suite("Petrel Integration Tests")
struct PetrelTests {
    @Test("ATProtoClient can be created without authentication")
    func clientCreation() async throws {
        let client = ATProtoClient()
        #expect(client != nil)
    }

    @Test("ATProtoClient has expected API namespaces")
    func aPINamespaces() async throws {
        let client = ATProtoClient()

        // Verify main namespaces exist
        #expect(client.app != nil)
        #expect(client.com != nil)
        #expect(client.chat != nil)
    }

    @Test("ATProtocolValueContainer basic functionality")
    func valueContainer() throws {
        let testData = ["key": "value", "number": 42] as [String: Any]
        let container = ATProtocolValueContainer(testData)

        #expect(container.storage.count == 2)
    }
}
