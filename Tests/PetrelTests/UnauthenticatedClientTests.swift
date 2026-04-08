import Foundation
@testable import Petrel
import Testing

@Suite("Unauthenticated ATProtoClient Tests")
struct UnauthenticatedClientTests {

    @Test("Unauthenticated client initializes with baseURL only")
    func initWithBaseURL() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
        let url = await client.baseURL
        #expect(url.absoluteString == "https://bsky.social")
    }

    @Test("Auth methods throw unauthenticatedClient error")
    func authMethodsThrow() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)

        await #expect(throws: APIError.self) {
            try await client.startOAuthFlow()
        }
        await #expect(throws: APIError.self) {
            try await client.loginWithPassword(identifier: "test", password: "test")
        }
        await #expect(throws: APIError.self) {
            try await client.logout()
        }
        await #expect(throws: APIError.self) {
            try await client.switchAuthMode(.legacy)
        }
        await #expect(throws: APIError.self) {
            try await client.getDid()
        }
        await #expect(throws: APIError.self) {
            try await client.getHandle()
        }
        await #expect(throws: APIError.self) {
            try await client.switchToAccount(did: "did:plc:test")
        }
        await #expect(throws: APIError.self) {
            try await client.removeAccount(did: "did:plc:test")
        }
    }

    @Test("hasValidSession returns false for unauthenticated client")
    func hasValidSessionFalse() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
        let valid = await client.hasValidSession()
        #expect(valid == false)
    }

    @Test("listAccounts returns empty for unauthenticated client")
    func listAccountsEmpty() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
        let accounts = await client.listAccounts()
        #expect(accounts.isEmpty)
    }

    @Test("getCurrentAccount returns nil for unauthenticated client")
    func getCurrentAccountNil() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
        let account = await client.getCurrentAccount()
        #expect(account == nil)
    }

    @Test("cancelOAuthFlow is safe on unauthenticated client")
    func cancelOAuthFlowSafe() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
        await client.cancelOAuthFlow()
        // Should not crash
    }
}
