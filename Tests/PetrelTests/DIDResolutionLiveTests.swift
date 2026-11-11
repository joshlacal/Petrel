import Foundation
import Petrel
import Testing

/// Opt-in checks against the live network: the system DNS resolver, the default hardened
/// transport and the public PLC directory. Skipped unless `PETREL_LIVE_IDENTITY_TESTS=1`, so
/// the ordinary suite never depends on the network.
@Suite(
    "Identity against the live network",
    .enabled(if: ProcessInfo.processInfo.environment["PETREL_LIVE_IDENTITY_TESTS"] == "1")
)
struct DIDResolutionLiveTests {
    @Test("A handle published by DNS TXT resolves and verifies in both directions")
    func dnsHandle() async throws {
        let resolver = IdentityResolver()

        let identity = try await resolver.resolveIdentity("atproto.com")

        #expect(identity.did.didString().hasPrefix("did:plc:"))
        #expect(identity.handle.value == "atproto.com")
        #expect(identity.isHandleVerified)
        #expect(identity.pdsEndpoint != nil)
        _ = try identity.signingKey()

        let reverse = try await resolver.resolveIdentity(identity.did.didString(), forceRefresh: true)
        #expect(reverse.handle.value == "atproto.com")
    }

    @Test("A name with no _atproto record and no well-known file is reported as not found")
    func missingHandle() async throws {
        let resolver = IdentityResolver()

        let started = Date()
        await #expect(throws: IdentityError.handleNotFound("no-such-handle-for-petrel-tests.bsky.social")) {
            try await resolver.resolveHandle("no-such-handle-for-petrel-tests.bsky.social")
        }
        // A missing TXT record is a prompt negative answer, not a timeout.
        #expect(Date().timeIntervalSince(started) < 4)
    }

    @Test("A handle published over HTTPS only resolves without waiting out the DNS timeout")
    func wellKnownHandle() async throws {
        let resolver = IdentityResolver()

        let started = Date()
        let identity = try await resolver.resolveIdentity("bsky.app")

        #expect(identity.isHandleVerified)
        #expect(Date().timeIntervalSince(started) < 4)
    }

    @Test("A hostname-level did:web resolves")
    func didWeb() async throws {
        let resolver = IdentityResolver()

        let document = try await resolver.resolveDIDDocument("did:web:api.bsky.app")

        #expect(document.id == "did:web:api.bsky.app")
        #expect(try document.serviceEndpoint(.appView).host != nil)
    }
}
