#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
@testable import Petrel
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Runs `body` with an injected in-memory storage backend, always restoring the
/// platform default afterwards.
private func withInMemoryStorage<T>(
    _ backend: InMemorySecureStorage,
    _ body: () async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        defer { KeychainManager._setStorageOverride(nil) }
        return try await body()
    }
}

/// Covers the invariant that every write of a DPoP nonce reaches all three stores
/// `OAuthCore.createDPoPProof` reads (in-memory JKT map, persisted JKT map,
/// persisted DID map), and that every clear empties all of them. A write landing
/// only in the DID-scoped store is shadowed by the JKT-scoped layers, which is how
/// a session ends up replaying a nonce the server already rejected.
@Suite("DPoP nonce store consistency", .serialized)
struct DPoPNonceStoreTests {
    private static let did = "did:plc:noncestore"
    private static let host = "auth.nonce.test"
    private static let endpoint = "https://auth.nonce.test/oauth/token"

    // MARK: - Fixtures

    private func makeCore(storage: KeychainStorage, did: String = did) -> OAuthCore {
        OAuthCore(
            storage: storage,
            accountManager: MockAccountManager(account: makeAccount(did: did)),
            networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/oauth-client-metadata.json",
                redirectUri: "https://client.example/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver()
        )
    }

    private func makeAccount(did: String = did) -> Account {
        Account(
            did: did,
            handle: "nonce.example",
            pdsURL: URL(string: "https://pds.test")!
        )
    }

    private func makeSession(did: String = did) -> Session {
        Session(
            accessToken: "access",
            refreshToken: "refresh",
            createdAt: Date(),
            expiresIn: 3600,
            tokenType: .dpop,
            did: did
        )
    }

    /// Installs a DPoP key for `did` and returns its JWK thumbprint — the key the
    /// JKT-scoped stores are keyed by.
    @discardableResult
    private func installDPoPKey(
        storage: KeychainStorage,
        core: OAuthCore,
        did: String = did
    ) async throws -> String {
        let key = P256.Signing.PrivateKey()
        try await storage.saveDPoPKeyRepresentation(key.x963Representation, for: did)
        let jwk = try await core.createJWK(from: key)
        return try await core.calculateJWKThumbprint(jwk: jwk)
    }

    /// The nonce a freshly minted proof actually carries — the only check that covers
    /// the whole read precedence rather than one store in isolation.
    private func nonceInProof(from core: OAuthCore, did: String = did) async throws -> String? {
        let proof = try await core.createDPoPProof(
            for: "POST",
            url: Self.endpoint,
            type: .tokenRefresh,
            did: did
        )
        let parts = proof.split(separator: ".")
        try #require(parts.count == 3)
        var encoded = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while encoded.count % 4 != 0 {
            encoded += "="
        }
        let data = try #require(Data(base64Encoded: encoded))
        let payload = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return payload["nonce"] as? String
    }

    // MARK: - Writes

    @Test("A nonce update without a JKT still reaches all three stores")
    func updateWithoutJKTWritesAllStores() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.jkt-nil-write")
            let core = makeCore(storage: storage)
            let thumbprint = try await installDPoPKey(storage: storage, core: core)

            // A stale JKT-scoped nonce of the kind login leaves behind — it shadows any
            // write that reaches the DID-scoped store alone.
            await core.updateDPoPNonceInternal(domain: Self.host, nonce: "stale", for: Self.did)

            // The token endpoint's response carries no AuthContext, so jkt is nil.
            await core.updateDPoPNonce(
                for: URL(string: Self.endpoint)!,
                from: ["DPoP-Nonce": "fresh"],
                did: Self.did,
                jkt: nil
            )

            let didNonces = try await storage.getDPoPNonces(for: Self.did)
            let jktNonces = try await storage.getDPoPNoncesByJKT(for: Self.did)
            let cached = await core.noncesByThumbprint
            let proofNonce = try await nonceInProof(from: core)
            #expect(didNonces?[Self.host] == "fresh")
            #expect(jktNonces?[thumbprint]?[Self.host] == "fresh")
            #expect(cached[thumbprint]?[Self.host] == "fresh")
            #expect(proofNonce == "fresh")
        }
    }

    @Test("A nonce update with an explicit JKT writes that thumbprint's stores")
    func updateWithJKTWritesAllStores() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.jkt-explicit-write")
            let core = makeCore(storage: storage)
            let thumbprint = try await installDPoPKey(storage: storage, core: core)

            await core.updateDPoPNonce(
                for: URL(string: Self.endpoint)!,
                from: ["dpop-nonce": "fresh"],
                did: Self.did,
                jkt: thumbprint
            )

            let didNonces = try await storage.getDPoPNonces(for: Self.did)
            let jktNonces = try await storage.getDPoPNoncesByJKT(for: Self.did)
            let proofNonce = try await nonceInProof(from: core)
            #expect(didNonces?[Self.host] == "fresh")
            #expect(jktNonces?[thumbprint]?[Self.host] == "fresh")
            #expect(proofNonce == "fresh")
        }
    }

    @Test("A write that cannot resolve the thumbprint reports failure")
    func writeReportsFailureWhenThumbprintUnavailable() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.unreadable-key")
            let core = makeCore(storage: storage)
            // An unreadable DPoP key (locked keychain, corrupt entry) leaves the
            // JKT-scoped stores untouched, so a retry would replay the stale nonce.
            backend.plant(
                key: "dpopKey.\(Self.did)",
                namespace: "dpopkeys",
                data: Data([0x00])
            )

            let applied = await core.updateDPoPNonceInternal(
                domain: Self.host, nonce: "fresh", for: Self.did
            )

            let didNonces = try await storage.getDPoPNonces(for: Self.did)
            let jktNonces = try await storage.getDPoPNoncesByJKT(for: Self.did)
            #expect(applied == false)
            #expect(didNonces?[Self.host] == "fresh")
            #expect(jktNonces?.isEmpty != false)
        }
    }

    @Test("A merge lets a persisted nonce win over a stale in-memory one")
    func persistedNonceWinsOverStaleMemory() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.persistence-merge")
            let staleCore = makeCore(storage: storage)
            let freshCore = makeCore(storage: storage)
            let thumbprint = try await installDPoPKey(storage: storage, core: staleCore)

            await staleCore.updateDPoPNonceInternal(
                domain: Self.host, nonce: "stale", for: Self.did
            )
            let staleCache = await staleCore.noncesByThumbprint
            #expect(staleCache[thumbprint]?[Self.host] == "stale")

            // A second OAuthCore over the same storage — every strategy builds its own —
            // records a newer nonce.
            await freshCore.updateDPoPNonceInternal(
                domain: Self.host, nonce: "fresh", for: Self.did
            )

            let proofNonce = try await nonceInProof(from: staleCore)
            #expect(proofNonce == "fresh")
        }
    }

    @Test("Within the merge interval a proof reuses the nonce it already holds")
    func mergeIntervalBoundsPersistenceReads() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.merge-interval")
            let core = makeCore(storage: storage)
            let otherCore = makeCore(storage: storage)
            try await installDPoPKey(storage: storage, core: core)

            await core.updateDPoPNonceInternal(domain: Self.host, nonce: "first", for: Self.did)
            // This proof merges persistence and starts the interval.
            let firstProofNonce = try await nonceInProof(from: core)
            #expect(firstProofNonce == "first")

            await otherCore.updateDPoPNonceInternal(
                domain: Self.host, nonce: "second", for: Self.did
            )

            // The documented staleness window: within the interval this core keeps
            // signing with the nonce it already holds instead of re-reading. A server
            // that has moved on answers use_dpop_nonce, and that handler writes the
            // fresh nonce to every store — so the window is self-correcting.
            let cachedProofNonce = try await nonceInProof(from: core)
            #expect(cachedProofNonce == "first")

            // Persistence really does hold the newer value: a core that has not merged
            // yet picks it up on its first proof.
            let freshProofNonce = try await nonceInProof(from: makeCore(storage: storage))
            #expect(freshProofNonce == "second")
        }
    }

    // MARK: - Clears

    @Test("Public strategy logout clears every nonce store")
    func publicLogoutClearsNonceStores() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.public-logout")
            let strategy = PublicOAuthStrategy(
                storage: storage,
                accountManager: MockAccountManager(account: makeAccount()),
                networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
                oauthConfig: OAuthConfig(
                    clientId: "https://client.example/oauth-client-metadata.json",
                    redirectUri: "https://client.example/callback",
                    scope: "atproto"
                ),
                didResolver: MockDIDResolver()
            )
            let core = await strategy.core
            let thumbprint = try await installDPoPKey(storage: storage, core: core)
            try await storage.saveAccountAndSession(
                makeAccount(), session: makeSession(), for: Self.did
            )
            await core.updateDPoPNonceInternal(domain: Self.host, nonce: "stale", for: Self.did)

            try await strategy.logout()

            let didNonces = try await storage.getDPoPNonces(for: Self.did)
            let jktNonces = try await storage.getDPoPNoncesByJKT(for: Self.did)
            let cached = await core.noncesByThumbprint
            #expect(didNonces?.isEmpty != false)
            #expect(jktNonces?.isEmpty != false)
            #expect(cached[thumbprint] == nil)
        }
    }

    @Test("Logging one account out leaves another account's cached nonces intact")
    func logoutIsScopedToTheAccountLoggingOut() async throws {
        let backend = InMemorySecureStorage()
        let otherDID = "did:plc:noncestore-other"
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.scoped-logout")
            let strategy = PublicOAuthStrategy(
                storage: storage,
                accountManager: MockAccountManager(account: makeAccount()),
                networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
                oauthConfig: OAuthConfig(
                    clientId: "https://client.example/oauth-client-metadata.json",
                    redirectUri: "https://client.example/callback",
                    scope: "atproto"
                ),
                didResolver: MockDIDResolver()
            )
            let core = await strategy.core
            let thumbprint = try await installDPoPKey(storage: storage, core: core)
            let otherThumbprint = try await installDPoPKey(
                storage: storage, core: core, did: otherDID
            )
            try await storage.saveAccountAndSession(
                makeAccount(), session: makeSession(), for: Self.did
            )
            await core.updateDPoPNonceInternal(domain: Self.host, nonce: "stale", for: Self.did)
            await core.updateDPoPNonceInternal(domain: Self.host, nonce: "other", for: otherDID)

            try await strategy.logout()

            let cached = await core.noncesByThumbprint
            let otherPersisted = try await storage.getDPoPNoncesByJKT(for: otherDID)
            #expect(cached[thumbprint] == nil)
            #expect(cached[otherThumbprint]?[Self.host] == "other")
            #expect(otherPersisted?[otherThumbprint]?[Self.host] == "other")
        }
    }

    @Test("CAB strategy logout clears every nonce store")
    func cabLogoutClearsNonceStores() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.cab-logout")
            let strategy = CABOAuthStrategy(
                backendURL: URL(string: "https://cab.example.com")!,
                storage: storage,
                accountManager: MockAccountManager(account: makeAccount()),
                networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
                oauthConfig: OAuthConfig(
                    clientId: "https://cab.example.com/oauth-client-metadata.json",
                    redirectUri: "https://client.example/callback",
                    scope: "atproto"
                ),
                didResolver: MockDIDResolver(),
                urlSession: URLSession(configuration: .ephemeral)
            )
            let core = await strategy.core
            let thumbprint = try await installDPoPKey(storage: storage, core: core)
            try await storage.saveAccountAndSession(
                makeAccount(), session: makeSession(), for: Self.did
            )
            await core.updateDPoPNonceInternal(domain: Self.host, nonce: "stale", for: Self.did)

            try await strategy.logout()

            let didNonces = try await storage.getDPoPNonces(for: Self.did)
            let jktNonces = try await storage.getDPoPNoncesByJKT(for: Self.did)
            let cached = await core.noncesByThumbprint
            #expect(didNonces?.isEmpty != false)
            #expect(jktNonces?.isEmpty != false)
            #expect(cached[thumbprint] == nil)
        }
    }

    @Test("Removing an account clears its nonce stores")
    func removeAccountClearsNonceStores() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.remove-account")
            let core = makeCore(storage: storage)
            let thumbprint = try await installDPoPKey(storage: storage, core: core)
            try await storage.saveAccountAndSession(
                makeAccount(), session: makeSession(), for: Self.did
            )
            await core.updateDPoPNonceInternal(domain: Self.host, nonce: "stale", for: Self.did)
            let seeded = try await storage.getDPoPNoncesByJKT(for: Self.did)
            #expect(seeded?[thumbprint]?[Self.host] == "stale")

            let accountManager = await AccountManager(storage: storage)
            try await accountManager.removeAccount(did: Self.did)

            let didNonces = try await storage.getDPoPNonces(for: Self.did)
            let jktNonces = try await storage.getDPoPNoncesByJKT(for: Self.did)
            #expect(didNonces?.isEmpty != false)
            #expect(jktNonces?.isEmpty != false)
        }
    }

    // MARK: - OAuth flow nonces

    @Test("Flow nonces move to the DID's stores once login binds the key")
    func flowNoncesTransferToDIDStores() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryStorage(backend) {
            let storage = KeychainStorage(namespace: "test.nonce.flow-transfer")
            let core = makeCore(storage: storage)
            let thumbprint = try await installDPoPKey(storage: storage, core: core)

            // What `pushAuthorizationRequest` records before any DID exists.
            await core.recordOAuthFlowNonce("par-nonce", for: Self.endpoint)
            // A second login to a different authorization server, still in flight.
            await core.recordOAuthFlowNonce("other-par-nonce", for: "https://auth.other.test/par")
            let recorded = await core.oauthFlowNonces
            #expect(recorded[Self.host] == "par-nonce")

            await core.transferOAuthFlowNonces(to: Self.did, from: [Self.endpoint])

            let didNonces = try await storage.getDPoPNonces(for: Self.did)
            let jktNonces = try await storage.getDPoPNoncesByJKT(for: Self.did)
            let remainingFlowNonces = await core.oauthFlowNonces
            let proofNonce = try await nonceInProof(from: core)
            #expect(didNonces?[Self.host] == "par-nonce")
            #expect(jktNonces?[thumbprint]?[Self.host] == "par-nonce")
            #expect(remainingFlowNonces[Self.host] == nil)
            // The concurrent flow's nonce is left for the login that is still using it.
            #expect(remainingFlowNonces["auth.other.test"] == "other-par-nonce")
            #expect(proofNonce == "par-nonce")
        }
    }
}
