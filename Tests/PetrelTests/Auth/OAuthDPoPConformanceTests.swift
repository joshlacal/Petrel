#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// DPoP (RFC 9449) as the atproto OAuth profile requires it: proof contents,
/// server nonces tracked per server, and a single retry on a nonce challenge
/// at every endpoint that takes a proof.
///
/// `FakeOAuthServer` verifies each proof's signature, `htm`, `htu`, `iat`,
/// `jti`, nonce and `ath`, so a 2xx in these tests means the proof was valid.
@Suite("OAuth DPoP conformance", .serialized)
struct OAuthDPoPConformanceTests {
    private static let aliceDID = "did:plc:dpopalice"

    // MARK: - Proof contents

    private func makeCore(namespace: String) async -> OAuthCore {
        let storage = KeychainStorage(namespace: namespace)
        return OAuthCore(
            storage: storage,
            accountManager: await AccountManager(storage: storage),
            networkService: NetworkService(baseURL: URL(string: "https://pds.oauth.test")!),
            oauthConfig: OAuthConfig(
                clientId: OAuthTestClient.clientID, redirectUri: OAuthTestClient.redirectURI, scope: "atproto"
            ),
            didResolver: OAuthTestDIDResolver()
        )
    }

    @Test("A proof is an ES256 dpop+jwt carrying only the public key, signed by that key")
    func proofHeaderAndSignature() async throws {
        try await withOAuthTestNetwork([]) {
            let core = await makeCore(namespace: "dpop.header")
            let key = P256.Signing.PrivateKey()
            let compact = try await core.createDPoPProof(
                for: "POST",
                url: "https://auth.oauth.test/as/token",
                type: .tokenRequest,
                ephemeralKeyRawRepresentation: key.rawRepresentation
            )
            let proof = try #require(DecodedDPoPProof(compact))
            #expect(proof.signatureValid)
            #expect(proof.header["typ"] as? String == "dpop+jwt")
            #expect(proof.header["alg"] as? String == "ES256")
            let jwk = try #require(proof.header["jwk"] as? [String: Any])
            #expect(Set(jwk.keys) == ["kty", "crv", "x", "y"]) // no private "d"
            #expect(jwk["kty"] as? String == "EC")
            #expect(jwk["crv"] as? String == "P-256")
            // The embedded key is the signing key.
            let point = key.publicKey.x963Representation
            #expect(jwk["x"] as? String == TestJOSE.base64URLEncode(Data(point.dropFirst().prefix(32))))
            #expect(jwk["y"] as? String == TestJOSE.base64URLEncode(Data(point.suffix(32))))
        }
    }

    @Test(
        "htu is the request URL without query or fragment; htm is the method",
        arguments: [
            ("GET", "https://pds.oauth.test/xrpc/app.bsky.feed.getTimeline?limit=50&cursor=abc#frag",
             "https://pds.oauth.test/xrpc/app.bsky.feed.getTimeline"),
            ("POST", "https://PDS.oauth.test:443/xrpc/com.atproto.repo.createRecord",
             "https://pds.oauth.test/xrpc/com.atproto.repo.createRecord"),
            ("GET", "https://pds.oauth.test:8443/xrpc/x.y.z?q=%23tag",
             "https://pds.oauth.test:8443/xrpc/x.y.z"),
            ("POST", "https://auth.oauth.test", "https://auth.oauth.test/"),
        ]
    )
    func htuAndHtm(method: String, url: String, expectedHTU: String) async throws {
        try await withOAuthTestNetwork([]) {
            let core = await makeCore(namespace: "dpop.htu")
            let compact = try await core.createDPoPProof(
                for: method, url: url, type: .resourceAccess, accessToken: "token",
                ephemeralKeyRawRepresentation: P256.Signing.PrivateKey().rawRepresentation
            )
            let proof = try #require(DecodedDPoPProof(compact))
            #expect(proof.htm == method)
            #expect(proof.htu == expectedHTU)
        }
    }

    @Test("iat is the current time and every proof has its own jti")
    func iatAndJTI() async throws {
        try await withOAuthTestNetwork([]) {
            let core = await makeCore(namespace: "dpop.jti")
            let key = P256.Signing.PrivateKey().rawRepresentation
            var jtis: Set<String> = []
            let before = Int(Date().timeIntervalSince1970)
            for _ in 0 ..< 200 {
                let compact = try await core.createDPoPProof(
                    for: "POST", url: "https://auth.oauth.test/as/par", type: .authorization,
                    ephemeralKeyRawRepresentation: key
                )
                let proof = try #require(DecodedDPoPProof(compact))
                let iat = try #require(proof.iat)
                #expect(iat >= before && iat <= Int(Date().timeIntervalSince1970))
                let jti = try #require(proof.jti)
                #expect(jti.count >= 16)
                jtis.insert(jti)
            }
            #expect(jtis.count == 200)
        }
    }

    @Test("ath is the SHA-256 of the access token, present only on resource requests")
    func athBinding() async throws {
        try await withOAuthTestNetwork([]) {
            let core = await makeCore(namespace: "dpop.ath")
            let key = P256.Signing.PrivateKey().rawRepresentation
            let token = "opaque.access-token_123"

            let resourceProof = try #require(DecodedDPoPProof(await core.createDPoPProof(
                for: "GET", url: "https://pds.oauth.test/xrpc/a.b.c", type: .resourceAccess,
                accessToken: token, ephemeralKeyRawRepresentation: key
            )))
            // Independently computed: base64url(SHA-256(ASCII(token))).
            let expected = TestJOSE.base64URLEncode(Data(SHA256.hash(data: Data(token.utf8))))
            #expect(resourceProof.ath == expected)

            for type in [DPoPProofType.authorization, .tokenRequest, .tokenRefresh] {
                let proof = try #require(DecodedDPoPProof(await core.createDPoPProof(
                    for: "POST", url: "https://auth.oauth.test/as/token", type: type,
                    accessToken: token, ephemeralKeyRawRepresentation: key
                )))
                #expect(proof.ath == nil)
            }
        }
    }

    // MARK: - Resource requests

    @Test("A resource request carries the token, and a proof bound to it and to the URL without its query")
    func resourceRequestProof() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "dpop.resource", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)

            let (_, response) = try await client.getSession(query: "?include=email&x=%23y")
            #expect(response.statusCode == 200)

            let accepted = try #require(server.requests(to: .resource).last)
            #expect(accepted.status == 200)
            let authorization = try #require(accepted.headers["Authorization"])
            #expect(authorization.hasPrefix("DPoP "))
            let token = String(authorization.dropFirst(5))
            let proof = try #require(accepted.proof)
            #expect(proof.ath == TestJOSE.sha256Base64URL(token))
            #expect(proof.htm == "GET")
            #expect(proof.htu == "https://pds.oauth.test/xrpc/com.atproto.server.getSession")
            // The session key: the one the tokens were issued to.
            #expect(proof.thumbprint == server.requests(to: .token).last?.proof?.thumbprint)
        }
    }

    // MARK: - Nonces per server

    @Test("Authorization-server and resource-server nonces are tracked separately")
    func separateNonceCaches() async throws {
        let server = FakeOAuthServer() // entryway layout: different hosts, different nonces
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "dpop.nonce.separate", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            _ = try await client.getSession()

            let authorizationNonce = server.currentAuthorizationServerNonce
            let resourceNonce = server.currentResourceServerNonce
            #expect(authorizationNonce != resourceNonce)

            // Stored under each server's own host.
            let stored = try #require(try await client.storage.getDPoPNonces(for: Self.aliceDID))
            #expect(stored["auth.oauth.test"] == authorizationNonce)
            #expect(stored["pds.oauth.test"] == resourceNonce)

            // The resource server rotating its nonce costs one retry there…
            server.rotateResourceServerNonce()
            let resourceBefore = server.requests(to: .resource).count
            #expect(try await client.getSession().1.statusCode == 200)
            let resourceAttempts = Array(server.requests(to: .resource).dropFirst(resourceBefore))
            #expect(resourceAttempts.map(\.status) == [401, 200])
            #expect(resourceAttempts[0].proof?.nonce == resourceNonce)
            #expect(resourceAttempts[1].proof?.nonce == server.currentResourceServerNonce)

            // …and leaves the authorization server's nonce alone: the next refresh
            // is accepted on its first attempt with the authorization server's nonce.
            let tokenBefore = server.requests(to: .token).count
            _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            let refreshAttempts = Array(server.requests(to: .token).dropFirst(tokenBefore))
            #expect(refreshAttempts.map(\.status) == [200])
            #expect(refreshAttempts[0].proof?.nonce == authorizationNonce)

            // And no proof ever carried the other server's nonce.
            #expect(server.requests(to: .resource).allSatisfy { $0.proof?.nonce?.hasPrefix("as-") != true })
            #expect(server.requests(to: .token).allSatisfy { $0.proof?.nonce?.hasPrefix("rs-") != true })
        }
    }

    @Test("A PDS that is its own authorization server works even when its two roles issue different nonces")
    func singleHostWithDistinctNonces() async throws {
        let server = FakeOAuthServer(pdsOrigin: "https://solo.oauth.test", issuer: "https://solo.oauth.test")
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "dpop.nonce.solo", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            #expect(try await client.getSession().1.statusCode == 200)
            _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            #expect(try await client.getSession().1.statusCode == 200)
            #expect(server.requests(to: .token).last?.status == 200)
        }
    }

    // MARK: - Nonce retry at every endpoint

    @Test("PAR: a use_dpop_nonce challenge is answered once with the server's nonce and a new jti")
    func parNonceRetry() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "dpop.retry.par", server: server)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            _ = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")

            let attempts = server.requests(to: .par)
            #expect(attempts.map(\.status) == [400, 201])
            #expect(attempts[0].proof?.nonce == nil) // a new key has no nonce yet
            #expect(attempts[1].proof?.nonce == server.currentAuthorizationServerNonce)
            #expect(attempts[0].proof?.jti != attempts[1].proof?.jti)
            #expect(attempts[0].proof?.thumbprint == attempts[1].proof?.thumbprint)
            // The retry repeats the same authorization request.
            #expect(attempts[0].form == attempts[1].form)
        }
    }

    @Test("Token exchange: a nonce rotated since PAR is recovered from with one retry")
    func tokenExchangeNonceRetry() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "dpop.retry.token", server: server)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            let (url, _) = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            let parNonce = server.currentAuthorizationServerNonce
            let redirect = try server.approve(url, as: Self.aliceDID)

            server.rotateAuthorizationServerNonce()
            let result = try await client.strategy.handleOAuthCallback(url: redirect)
            #expect(result.did == Self.aliceDID)

            let attempts = server.requests(to: .token)
            #expect(attempts.map(\.status) == [400, 200])
            #expect(attempts[0].proof?.nonce == parNonce)
            #expect(attempts[1].proof?.nonce == server.currentAuthorizationServerNonce)
            // The rejected attempt did not spend the code: the same one succeeds.
            #expect(attempts[0].form["code"] == attempts[1].form["code"])

            // The account inherits the nonce the server accepted, not the stale one.
            let stored = try await client.storage.getDPoPNonces(for: Self.aliceDID)
            #expect(stored?["auth.oauth.test"] == server.currentAuthorizationServerNonce)
        }
    }

    @Test("Refresh: a stale nonce is recovered from with one retry, without spending the refresh token")
    func refreshNonceRetry() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "dpop.retry.refresh", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            let staleNonce = server.currentAuthorizationServerNonce
            server.rotateAuthorizationServerNonce()
            let before = server.requests(to: .token).count

            #expect(try await client.strategy.refreshTokenIfNeeded(forceRefresh: true) == .refreshedSuccessfully)

            let attempts = Array(server.requests(to: .token).dropFirst(before))
            #expect(attempts.map(\.status) == [400, 200])
            #expect(attempts[0].proof?.nonce == staleNonce)
            #expect(attempts[1].proof?.nonce == server.currentAuthorizationServerNonce)
            #expect(attempts[0].form["refresh_token"] == attempts[1].form["refresh_token"])
            #expect(server.revokedGrantCount == 0)
        }
    }

    @Test(
        "Resource requests: a nonce challenge is answered once, whether signalled in the body or only in WWW-Authenticate",
        arguments: [true, false]
    )
    func resourceNonceRetry(signalledInBody: Bool) async throws {
        let server = FakeOAuthServer()
        server.resourceNonceErrorInBody = signalledInBody
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "dpop.retry.resource.\(signalledInBody)", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)

            // First contact with the resource server: no nonce for that host yet.
            #expect(try await client.getSession().1.statusCode == 200)
            let attempts = server.requests(to: .resource)
            #expect(attempts.map(\.status) == [401, 200])
            #expect(attempts[0].proof?.nonce == nil)
            #expect(attempts[1].proof?.nonce == server.currentResourceServerNonce)
            #expect(attempts[0].proof?.jti != attempts[1].proof?.jti)
            // A nonce challenge is not an expired token: no refresh was triggered.
            #expect(server.requests(to: .token).filter { $0.form["grant_type"] == "refresh_token" }.isEmpty)

            // With the nonce learned, the next request needs no retry.
            #expect(try await client.getSession().1.statusCode == 200)
            #expect(server.requests(to: .resource).count == 3)
        }
    }

    @Test("A server that keeps demanding a new nonce is retried once, not forever")
    func nonceRetryIsBounded() async throws {
        let server = FakeOAuthServer()
        // After the proof (with the right nonce) verifies, answer use_dpop_nonce anyway.
        server.forcedErrors[.par] = (400, "use_dpop_nonce")
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "dpop.retry.bounded", server: server)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            await #expect(throws: AuthError.serverError(400, "use_dpop_nonce: ")) {
                _ = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            }
            #expect(server.requests(to: .par).count == 2)
        }
    }

    @Test("Nonces learned during a flow belong to that flow's key, not to the signed-in account")
    func flowNoncesDoNotLeakIntoCurrentAccount() async throws {
        let server = FakeOAuthServer()
        let second = FakeOAuthServer(pdsOrigin: "https://pds.second.test", issuer: "https://auth.second.test")
        try await withOAuthTestNetwork([server, second]) {
            let client = await OAuthTestClient.make(namespace: "dpop.nonce.isolation", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)

            // While Alice is signed in, start (but do not finish) a login for
            // another account at another authorization server.
            client.resolver.register(did: "did:plc:dpopbob", handle: "bob.test", pds: second.pdsURL)
            _ = try await client.strategy.startOAuthFlowWithState(identifier: "bob.test")

            let aliceNonces = try #require(try await client.storage.getDPoPNonces(for: Self.aliceDID))
            #expect(aliceNonces["auth.second.test"] == nil)
        }
    }
}
