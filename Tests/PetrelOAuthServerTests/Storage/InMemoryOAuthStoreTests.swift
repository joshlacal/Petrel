import Foundation
@testable import PetrelOAuthServer
import Testing

/// The transaction boundaries every store implementation has to reproduce.
@Suite("Storage: in-memory store transaction semantics")
struct InMemoryOAuthStoreTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let binding = OAuthGrantBinding(
        issuer: "https://auth.example.test", clientID: "https://app.example.test/c.json",
        redirectURI: "https://app.example.test/cb", requestedScopes: ["atproto"], dpopJKT: "jkt"
    )

    private func digest(_ text: String) -> Data { Data(text.utf8) }

    private func seedSession(_ store: any OAuthServerStore, code: String = "code", expiresAt: Date? = nil) async throws -> UUID {
        let id = UUID()
        try await store.storeAuthorizationCode(
            OAuthAuthorizationCode(
                codeDigest: digest(code), sessionID: id, subject: "did:plc:a", binding: binding,
                codeChallenge: "challenge", expiresAt: now.addingTimeInterval(60)
            ),
            session: OAuthSession(sessionID: id, subject: "did:plc:a", binding: binding, createdAt: now, expiresAt: expiresAt),
            now: now
        )
        return id
    }

    private func tokens(_ generation: Int) -> OAuthIssuedTokenDigests {
        OAuthIssuedTokenDigests(
            accessTokenDigest: digest("access-\(generation)"), accessExpiresAt: now.addingTimeInterval(900),
            refreshTokenDigest: digest("refresh-\(generation)"), refreshExpiresAt: now.addingTimeInterval(86400)
        )
    }

    @Test("a pushed request is consumed exactly once and never after it expires")
    func pushedRequests() async throws {
        let store: any OAuthServerStore = InMemoryOAuthStore()
        let request = OAuthPushedAuthorizationRequest(
            requestDigest: digest("r1"), binding: binding, state: "s", codeChallenge: "c", expiresAt: now.addingTimeInterval(300)
        )
        try await store.storePushedAuthorizationRequest(request, now: now)
        await #expect(throws: OAuthStoreError.duplicate) { try await store.storePushedAuthorizationRequest(request, now: now) }
        #expect(try await store.pushedAuthorizationRequest(requestDigest: digest("r1"), now: now) == request)
        #expect(try await store.consumePushedAuthorizationRequest(requestDigest: digest("r1"), now: now) == request)
        await #expect(throws: OAuthStoreError.notFound) {
            _ = try await store.consumePushedAuthorizationRequest(requestDigest: digest("r1"), now: now)
        }
        try await store.storePushedAuthorizationRequest(request, now: now)
        #expect(try await store.pushedAuthorizationRequest(requestDigest: digest("r1"), now: now.addingTimeInterval(301)) == nil)
        await #expect(throws: OAuthStoreError.notFound) {
            _ = try await store.consumePushedAuthorizationRequest(requestDigest: digest("r1"), now: now.addingTimeInterval(301))
        }
    }

    @Test("a failed verification does not consume the code; a second redemption revokes the session")
    func codeRedemption() async throws {
        let store: any OAuthServerStore = InMemoryOAuthStore()
        let id = try await seedSession(store)
        #expect(try await store.sessions(subject: "did:plc:a", now: now).isEmpty, "a session is not listed before it has tokens")
        struct Refused: Error {}
        await #expect(throws: Refused.self) {
            _ = try await store.redeemAuthorizationCode(
                codeDigest: digest("code"), verifying: { _ in throw Refused() }, issuing: tokens(1), now: now
            )
        }
        let session = try await store.redeemAuthorizationCode(
            codeDigest: digest("code"), verifying: { _ in }, issuing: tokens(1), now: now
        )
        #expect(session.sessionID == id)
        #expect(try await store.session(accessTokenDigest: digest("access-1"), now: now)?.sessionID == id)
        #expect(try await store.clientHoldsActiveSession(clientID: binding.clientID, now: now))

        await #expect(throws: OAuthStoreError.replayed) {
            _ = try await store.redeemAuthorizationCode(
                codeDigest: digest("code"), verifying: { _ in }, issuing: tokens(2), now: now
            )
        }
        #expect(try await store.session(accessTokenDigest: digest("access-1"), now: now) == nil)
        #expect(try await store.session(id: id, now: now)?.revokedAt == now)
        await #expect(throws: OAuthStoreError.notFound) {
            _ = try await store.redeemAuthorizationCode(
                codeDigest: digest("unknown"), verifying: { _ in }, issuing: tokens(1), now: now
            )
        }
    }

    @Test("refresh rotation is compare-and-swap; a retired token revokes the session")
    func refreshRotation() async throws {
        let store: any OAuthServerStore = InMemoryOAuthStore()
        let id = try await seedSession(store)
        _ = try await store.redeemAuthorizationCode(codeDigest: digest("code"), verifying: { _ in }, issuing: tokens(1), now: now)
        let rotated = try await store.rotateRefreshToken(
            refreshTokenDigest: digest("refresh-1"), replacement: tokens(2), grantedScopes: ["atproto", "repo:a.b.c"], now: now
        )
        #expect(rotated.binding.grantedScopes == ["atproto", "repo:a.b.c"])
        #expect(rotated.binding.requestedScopes == ["atproto"], "the requested side never changes")
        #expect(try await store.session(accessTokenDigest: digest("access-1"), now: now) == nil, "the old access token is gone")
        #expect(try await store.session(refreshTokenDigest: digest("refresh-1"), now: now)?.sessionID == id)

        await #expect(throws: OAuthStoreError.replayed) {
            _ = try await store.rotateRefreshToken(refreshTokenDigest: digest("refresh-1"), replacement: tokens(3), grantedScopes: nil, now: now)
        }
        await #expect(throws: OAuthStoreError.revoked) {
            _ = try await store.rotateRefreshToken(refreshTokenDigest: digest("refresh-2"), replacement: tokens(3), grantedScopes: nil, now: now)
        }
        await #expect(throws: OAuthStoreError.notFound) {
            _ = try await store.rotateRefreshToken(refreshTokenDigest: digest("nope"), replacement: tokens(3), grantedScopes: nil, now: now)
        }
    }

    @Test("an expired refresh token and a session past its hard end are refused")
    func expiry() async throws {
        let store: any OAuthServerStore = InMemoryOAuthStore()
        _ = try await seedSession(store, expiresAt: now.addingTimeInterval(3600))
        _ = try await store.redeemAuthorizationCode(codeDigest: digest("code"), verifying: { _ in }, issuing: tokens(1), now: now)
        await #expect(throws: OAuthStoreError.revoked) {
            _ = try await store.rotateRefreshToken(
                refreshTokenDigest: digest("refresh-1"), replacement: tokens(2), grantedScopes: nil, now: now.addingTimeInterval(3601)
            )
        }
        #expect(try await store.session(accessTokenDigest: digest("access-1"), now: now.addingTimeInterval(901)) == nil)

        let other: any OAuthServerStore = InMemoryOAuthStore()
        _ = try await seedSession(other)
        _ = try await other.redeemAuthorizationCode(codeDigest: digest("code"), verifying: { _ in }, issuing: tokens(1), now: now)
        await #expect(throws: OAuthStoreError.notFound) {
            _ = try await other.rotateRefreshToken(
                refreshTokenDigest: digest("refresh-1"), replacement: tokens(2), grantedScopes: nil, now: now.addingTimeInterval(86401)
            )
        }
        try await other.purgeExpired(now: now.addingTimeInterval(86401))
        #expect(try await other.session(refreshTokenDigest: digest("refresh-1"), now: now) == nil)
    }

    @Test("replay markers are per namespace, expire, and fail closed at capacity")
    func replayMarkers() async throws {
        let store: any OAuthServerStore = InMemoryOAuthStore(replayCapacity: 2)
        let expiry = now.addingTimeInterval(60)
        #expect(try await store.claim(namespace: .dpopProof, digest: digest("a"), expiresAt: expiry, now: now))
        #expect(try await !store.claim(namespace: .dpopProof, digest: digest("a"), expiresAt: expiry, now: now))
        #expect(try await store.claim(namespace: .clientAssertion, digest: digest("a"), expiresAt: expiry, now: now))
        #expect(try await store.claim(namespace: .dpopProof, digest: digest("b"), expiresAt: expiry, now: now))
        #expect(try await !store.claim(namespace: .dpopProof, digest: digest("c"), expiresAt: expiry, now: now), "full: fail closed")
        #expect(try await store.claim(namespace: .dpopProof, digest: digest("c"), expiresAt: expiry, now: now.addingTimeInterval(61)))
        #expect(try await store.claim(namespace: .dpopProof, digest: digest("a"), expiresAt: expiry, now: now.addingTimeInterval(61)))
    }

    @Test("device accounts are per device, newest first, and age out")
    func deviceAccounts() async throws {
        let store: any OAuthServerStore = InMemoryOAuthStore()
        let device = digest("device-1")
        try await store.rememberDeviceAccount(.init(subject: "did:plc:a", authenticatedAt: now), deviceDigest: device, now: now)
        try await store.rememberDeviceAccount(.init(subject: "did:plc:b", authenticatedAt: now.addingTimeInterval(10)), deviceDigest: device, now: now)
        #expect(try await store.deviceAccounts(deviceDigest: device, maximumAge: 3600, now: now.addingTimeInterval(20)).map(\.subject) == ["did:plc:b", "did:plc:a"])
        #expect(try await store.deviceAccounts(deviceDigest: digest("device-2"), maximumAge: 3600, now: now).isEmpty)
        #expect(try await store.deviceAccounts(deviceDigest: device, maximumAge: 3600, now: now.addingTimeInterval(3605)).map(\.subject) == ["did:plc:b"])
        try await store.forgetDeviceAccount(subject: "did:plc:b", deviceDigest: device, now: now)
        #expect(try await store.deviceAccounts(deviceDigest: device, maximumAge: 3600, now: now).map(\.subject) == ["did:plc:a"])
    }
}
