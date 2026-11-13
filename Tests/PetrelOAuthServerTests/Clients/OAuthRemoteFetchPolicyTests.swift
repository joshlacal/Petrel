import Foundation
@testable import PetrelOAuthServer
import Testing

@Suite("Clients: remote fetch policy bounds")
struct OAuthRemoteFetchPolicyTests {
    @Test("the public initializer refuses a timeout above 30 seconds")
    func publicCeiling() throws {
        #expect(throws: OAuthServerError.self) { try OAuthRemoteFetchPolicy(timeout: 31) }
        #expect(throws: OAuthServerError.self) { try OAuthRemoteFetchPolicy(timeout: 0) }
        #expect(try OAuthRemoteFetchPolicy(timeout: 30).timeout == 30)
    }

    #if DEBUG
        @Test("the debug-only stub policy lifts the ceiling for in-process exchanges")
        func stubbedCeiling() throws {
            let loopback: Set<OAuthIPAddress> = [try #require(OAuthIPAddress(literal: "127.0.0.1"))]
            let policy = try OAuthRemoteFetchPolicy.stubbed(networkAllowlist: .init(addresses: loopback), timeout: 300)
            #expect(policy.timeout == 300)
            #expect(policy.networkAllowlist == .init(addresses: loopback))
            #expect(!policy.allowLoopbackDevelopment)
            #expect(!policy.allowsUnpinnedTransport)
            #expect(throws: OAuthServerError.self) { try OAuthRemoteFetchPolicy.stubbed(timeout: .infinity) }
        }
    #endif
}
