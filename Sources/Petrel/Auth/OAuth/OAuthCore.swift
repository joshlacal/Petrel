//
//  OAuthCore.swift
//  Petrel
//
//  Extracted from PublicOAuthStrategy to enable reuse by CABOAuthStrategy.
//

import Crypto
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import PetrelCrypto

/// Shared OAuth machinery (DPoP, PKCE, nonce tracking, metadata fetching,
/// refresh coordination with deduplication & circuit breaking).
///
/// Strategy actors (PublicOAuthStrategy, CABOAuthStrategy) compose an
/// instance of this actor and delegate common work to it while keeping
/// strategy-specific token exchange / refresh logic in their own actors.
actor OAuthCore {
    // MARK: - Dependencies

    let storage: KeychainStorage
    let accountManager: AccountManaging
    let networkService: NetworkService
    let oauthConfig: OAuthConfig
    let didResolver: DIDResolving
    /// How this client authenticates to the authorization server (public,
    /// in-process `private_key_jwt`, or a Client Assertion Backend).
    let clientAuthenticator: any OAuthClientAuthenticating

    // MARK: - Authorization Flow State

    /// Flow starts in progress, keyed by target and scope, so concurrent identical
    /// requests share one pushed authorization request.
    var oauthStartTasks: [String: Task<(url: URL, state: String), Error>] = [:]
    /// State tokens of flows that have been started and not yet completed or cancelled.
    var inFlightOAuthStateTokens: Set<String> = []
    /// Bumped by every cancellation so a start that was mid-flight notices it.
    var cancellationGeneration: UInt64 = 0
    /// State tokens that were cancelled or denied and must never complete.
    var deniedStateTokens: Set<String> = []
    weak var progressDelegate: AuthProgressDelegate?

    // MARK: - Shared State

    let refreshCircuitBreaker = RefreshCircuitBreaker()
    var noncesByThumbprint: [String: [String: String]] = [:]
    var usedRefreshTokens: Set<String> = []
    var activeRefreshTasks: [String: Task<TokenRefreshResult, Error>] = [:]
    /// Nonces observed during OAuth flows that have no account yet, keyed by the
    /// flow's ephemeral DPoP key thumbprint and then by host. Keying by host alone
    /// would collide whenever two logins to the same authorization server (the common
    /// case — everyone's PDS is bsky.social) overlap.
    var oauthFlowNonces: [String: [String: String]] = [:]
    var ambiguousRefreshUntil: [String: Date] = [:]

    /// When each DID's persisted JKT-scoped nonces were last merged into
    /// `noncesByThumbprint`. Bounds how often a proof re-reads the keychain.
    var lastPersistedNonceMerge: [String: Date] = [:]

    /// Cached DPoP key and precomputed proof material per DID. Swift Crypto
    /// 3.x's immutable P-256 key lacks a Linux `Sendable` annotation.
    struct DPoPMaterial: @unchecked Sendable {
        let privateKey: P256.Signing.PrivateKey
        let jwk: JWK
        let thumbprint: String
        let headerBase64: String
    }
    private var dpopMaterialCache: [String: DPoPMaterial] = [:]
    private var activeDPoPLoadTasks: [String: (generation: UInt64, task: Task<DPoPMaterial, Error>)] = [:]
    /// Token for the DPoP key mutation observer. Initialized during init and cleaned up in deinit.
    private nonisolated(unsafe) var dpopKeyObserverToken: UUID?
    /// Test-only hook invoked when entering the coalesced-waiter branch of `getOrCreateDPoPMaterial`.
    var onCoalescedDPoPWaiterAwaited: (@Sendable () -> Void)?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()



    /// Which thumbprints hold cached nonces for which DID, so one account's logout
    /// clears exactly its own entries. Thumbprints are per-DID (each account has its
    /// own DPoP key), but `noncesByThumbprint` is keyed by thumbprint alone, so
    /// without this reverse index a clear could only be all-or-nothing.
    var thumbprintsByDID: [String: Set<String>] = [:]

    /// DIDs whose JKT-scoped nonce write could not be persisted (e.g. a locked
    /// keychain). Their persisted copy is known to be older than what memory holds, so
    /// a merge may only fill gaps for them instead of letting persistence win —
    /// otherwise the next merge would reinstate a nonce the server has already
    /// rejected. Cleared as soon as a persist for that DID succeeds.
    var didsWithUnpersistedNonces: Set<String> = []

    /// How long a merge of the persisted JKT-scoped nonces is trusted before the next
    /// proof re-reads the keychain.
    ///
    /// This instance is the only writer of its own nonces, so the merge exists solely
    /// to observe writes by *another* `OAuthCore` (each strategy builds its own) or
    /// another process in the keychain access group. Missing one of those costs a
    /// single `use_dpop_nonce` 400, whose handler writes the server's fresh nonce to
    /// every store — so the staleness is self-correcting and worth trading for one
    /// keychain read per DID per interval instead of one per outbound request.
    private static let persistedNonceMergeInterval: TimeInterval = 30

    /// Sessions that were successfully refreshed server-side but could not be
    /// persisted to the keychain (e.g. device locked). Held in memory so the
    /// running process keeps working; `getSession`'s pending-key handling covers
    /// the next launch. Keyed by DID.
    var unpersistedSessions: [String: Session] = [:]

    /// Upper bound for `usedRefreshTokens`; entries only matter within a process
    /// lifetime, so the set is cleared when it grows past this.
    private static let usedRefreshTokenCap = 64

    /// Strategy-specific refresh implementation.
    /// Set by the owning strategy after init via `setPerformActualRefresh`.
    var performActualRefresh: (@Sendable (Account, Session) async throws -> TokenRefreshResult)?

    func setPerformActualRefresh(_ closure: @escaping @Sendable (Account, Session) async throws -> TokenRefreshResult) {
        performActualRefresh = closure
    }
    init(
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving,
        clientAuthenticator: (any OAuthClientAuthenticating)? = nil
    ) {
        self.storage = storage
        self.accountManager = accountManager
        self.networkService = networkService
        self.oauthConfig = oauthConfig
        self.didResolver = didResolver
        self.clientAuthenticator = clientAuthenticator ?? PublicClientAuthenticator(clientId: oauthConfig.clientId)

        // Register synchronously on init so no storage mutation event can be missed
        self.dpopKeyObserverToken = KeychainStorage.dpopKeyMutationHub.addObserver { [weak self] did in
            guard let self else { return }
            if let did {
                await self.clearDPoPKeyCache(for: did)
            } else {
                await self.clearAllDPoPKeyCaches()
            }
        }
    }

    deinit {
        if let token = dpopKeyObserverToken {
            KeychainStorage.dpopKeyMutationHub.removeObserver(token)
        }
    }



    // MARK: - PKCE Helpers

    func generateCodeVerifier() -> String {
        let data = Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) })
        return base64URLEncode(data)
    }

    func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return base64URLEncode(Data(hash))
    }

    // MARK: - Encoding Helpers

    func base64URLEncode(_ data: Data) -> String {
        JWTBase64URL.encode(data)
    }

    func encodeFormData(_ params: [String: String]) -> Data {
        // `.urlQueryAllowed` permits '&', '=', '+', and ';' — legal in a query component
        // overall, but they collide with the delimiters this encoding relies on: '&'/'='
        // join the key/value pairs below, '+' decodes as a space, and ';' is a legacy
        // pair separator. A value containing one of them literally — e.g. an atproto
        // rich-scope entry like "repo:com.example.profile?action=create&action=update" —
        // would otherwise be split into bogus extra form fields by the receiving server,
        // silently truncating the value.
        var formValueAllowed = CharacterSet.urlQueryAllowed
        formValueAllowed.remove(charactersIn: "&=+;")

        let queryItems = params.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: formValueAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: formValueAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        return queryItems.joined(separator: "&").data(using: .utf8) ?? Data()
    }

    // MARK: - URL Helpers

    func extractAuthorizationCode(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }

    func extractState(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "state" })?
            .value
    }

    func extractNonceFromHeaders(_ headers: [AnyHashable: Any]) -> String? {
        for (key, value) in headers {
            if let keyString = key as? String,
               keyString.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame
            {
                return value as? String
            }
        }
        return nil
    }

    func canonicalHTU(_ url: URL) -> String {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        comps.scheme = comps.scheme?.lowercased()
        comps.host = comps.host?.lowercased()
        if (comps.scheme == "https" && comps.port == 443) || (comps.scheme == "http" && comps.port == 80) {
            comps.port = nil
        }
        if comps.path.isEmpty { comps.path = "/" }
        comps.fragment = nil
        comps.query = nil
        return comps.string ?? url.absoluteString
    }

    func calculateATH(from token: String) -> String {
        let tokenData = Data(token.utf8)
        let hash = SHA256.hash(data: tokenData)
        return base64URLEncode(Data(hash))
    }

    // MARK: - JWK & Crypto Helpers

    func createJWK(from privateKey: P256.Signing.PrivateKey) throws -> JWK {
        let publicKey = privateKey.publicKey
        let x963 = publicKey.x963Representation
        let x = x963.dropFirst().prefix(32)
        let y = x963.suffix(32)
        return JWK(
            x: JWTBase64URL.encode(Data(x)),
            y: JWTBase64URL.encode(Data(y))
        )
    }

    func calculateJWKThumbprint(jwk: JWK) throws -> String {
        let canonicalJSON = "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(jwk.x)\",\"y\":\"\(jwk.y)\"}"
        let jsonData = Data(canonicalJSON.utf8)
        let hash = SHA256.hash(data: jsonData)
        return JWTBase64URL.encode(Data(hash))
    }

    func precomputeDPoPMaterial(for privateKey: P256.Signing.PrivateKey) throws -> DPoPMaterial {
        let jwk = try createJWK(from: privateKey)
        let thumbprint = try calculateJWKThumbprint(jwk: jwk)
        let header = DPoPHeader(jwk: jwk)
        let headerData = try encoder.encode(header)
        let headerBase64 = JWTBase64URL.encode(headerData)
        return DPoPMaterial(
            privateKey: privateKey,
            jwk: jwk,
            thumbprint: thumbprint,
            headerBase64: headerBase64
        )
    }

    /// A mutation can invalidate a load while the load itself is creating the key.
    /// Three retries cover ordinary replacement races without allowing a persistently
    /// failing store to spin forever.
    private static let maxDPoPGenerationMismatchRetries = 3

    func getOrCreateDPoPMaterial(for did: String) async throws -> DPoPMaterial {
        var generationMismatchRetries = 0
        while true {
            if let cached = dpopMaterialCache[did] {
                return cached
            }
            let currentGen = KeychainStorage.dpopKeyMutationHub.generation(for: did)
            if let entry = activeDPoPLoadTasks[did], entry.generation == currentGen {
                onCoalescedDPoPWaiterAwaited?()
                do {
                    let material = try await entry.task.value
                    if KeychainStorage.dpopKeyMutationHub.generation(for: did) == currentGen {
                        return material
                    }
                    continue
                } catch {
                    if KeychainStorage.dpopKeyMutationHub.generation(for: did) != currentGen {
                        generationMismatchRetries += 1
                        if generationMismatchRetries > Self.maxDPoPGenerationMismatchRetries {
                            throw error
                        }
                        continue
                    }
                    throw error
                }
            }

            let loadGen = currentGen
            let loadTask = Task<DPoPMaterial, Error> {
                let key = try await self.fetchOrGenerateDPoPKey(for: did)
                return try self.precomputeDPoPMaterial(for: key)
            }
            activeDPoPLoadTasks[did] = (generation: loadGen, task: loadTask)

            do {
                let material = try await loadTask.value
                if KeychainStorage.dpopKeyMutationHub.generation(for: did) == loadGen {
                    if activeDPoPLoadTasks[did]?.generation == loadGen {
                        activeDPoPLoadTasks.removeValue(forKey: did)
                    }
                    dpopMaterialCache[did] = material
                    return material
                }
                continue
            } catch {
                if activeDPoPLoadTasks[did]?.generation == loadGen {
                    activeDPoPLoadTasks.removeValue(forKey: did)
                }
                if KeychainStorage.dpopKeyMutationHub.generation(for: did) != loadGen {
                    generationMismatchRetries += 1
                    if generationMismatchRetries > Self.maxDPoPGenerationMismatchRetries {
                        throw error
                    }
                    continue
                }
                throw error
            }
        }
    }

    /// Injects a test hook invoked whenever a concurrent caller awaits an active in-flight load task.
    func setCoalescedWaiterHook(_ hook: (@Sendable () -> Void)?) {
        self.onCoalescedDPoPWaiterAwaited = hook
    }

    func clearDPoPKeyCache(for did: String) {
        dpopMaterialCache.removeValue(forKey: did)
        if let entry = activeDPoPLoadTasks.removeValue(forKey: did) {
            entry.task.cancel()
        }
    }

    func clearAllDPoPKeyCaches() {
        dpopMaterialCache.removeAll()
        for did in Array(activeDPoPLoadTasks.keys) {
            if let entry = activeDPoPLoadTasks.removeValue(forKey: did) {
                entry.task.cancel()
            }
        }
    }





    // MARK: - DPoP Proof Creation

    func createDPoPProof(
        for method: String,
        url: String,
        type: DPoPProofType,
        accessToken: String? = nil,
        did: String? = nil,
        ephemeralKeyRawRepresentation: Data? = nil,
        nonce: String? = nil,
        usesStoredNonce: Bool = true
    ) async throws -> String {
        let (proof, _) = try await createDPoPProofWithMaterial(
            for: method,
            url: url,
            type: type,
            accessToken: accessToken,
            did: did,
            ephemeralKeyRawRepresentation: ephemeralKeyRawRepresentation,
            nonce: nonce,
            usesStoredNonce: usesStoredNonce
        )
        return proof
    }

    func createDPoPProofWithMaterial(
        for method: String,
        url: String,
        type: DPoPProofType,
        accessToken: String? = nil,
        did: String? = nil,
        ephemeralKeyRawRepresentation: Data? = nil,
        nonce: String? = nil,
        usesStoredNonce: Bool = true
    ) async throws -> (proof: String, thumbprint: String) {
        var targetDID: String? = did
        if targetDID == nil {
            targetDID = await accountManager.getCurrentAccount()?.did
        }

        let privateKey: P256.Signing.PrivateKey
        let keyThumbprint: String
        let headerBase64: String

        if let keyData = ephemeralKeyRawRepresentation {
            let key = try P256.Signing.PrivateKey(rawRepresentation: keyData)
            let material = try precomputeDPoPMaterial(for: key)
            privateKey = material.privateKey
            keyThumbprint = material.thumbprint
            headerBase64 = material.headerBase64
        } else if let currentDID = targetDID {
            let material = try await getOrCreateDPoPMaterial(for: currentDID)
            privateKey = material.privateKey
            keyThumbprint = material.thumbprint
            headerBase64 = material.headerBase64
        } else {
            throw AuthError.noActiveAccount
        }

        var ath: String?
        if type == .resourceAccess, let token = accessToken {
            ath = calculateATH(from: token)
        }

        // Determine nonce to use
        let finalNonce: String?
        if let explicitNonce = nonce {
            finalNonce = explicitNonce
        } else if !usesStoredNonce {
            // The recipient is not the server the stored nonces came from (e.g. a
            // client assertion backend): a nonce is only ever sent back to its issuer.
            finalNonce = nil
        } else if did == nil && ephemeralKeyRawRepresentation != nil,
                  let urlObject = URL(string: url),
                  let domain = urlObject.host?.lowercased()
        {
            finalNonce = oauthFlowNonces[keyThumbprint]?[domain]
        } else if let targetDID = targetDID, let urlObject = URL(string: url), let domain = urlObject.host?.lowercased() {
            // Pick up nonces written by another OAuthCore or another process, letting
            // persistence win. Rate-limited: see `persistedNonceMergeInterval`.
            await mergePersistedNoncesIfStale(for: targetDID)

            // Multi-layer nonce retrieval: JKT-scoped (in-memory, now including everything
            // persisted above) first, DID-scoped persistence as the fallback.
            if let jktNonce = noncesByThumbprint[keyThumbprint]?[domain] {
                finalNonce = jktNonce
            } else if let storedNonces = try? await storage.getDPoPNonces(for: targetDID),
                      let didNonce = storedNonces[domain]
            {
                finalNonce = didNonce
            } else {
                finalNonce = nil
            }
        } else {
            finalNonce = nil
        }

        // Canonicalize HTU
        let htuValue: String
        if let urlObj = URL(string: url) {
            htuValue = canonicalHTU(urlObj)
        } else {
            htuValue = url
        }

        let payload = DPoPPayload(
            jti: "\(UUID().uuidString)-\(UInt64.random(in: 0 ... UInt64.max))",
            htm: method,
            htu: htuValue,
            iat: Int(Date().timeIntervalSince1970),
            exp: Int(Date().timeIntervalSince1970) + 120,
            ath: ath,
            nonce: finalNonce
        )

        let jwtPayloadData = try encoder.encode(payload)
        let payloadBase64 = JWTBase64URL.encode(jwtPayloadData)
        let signingInput = "\(headerBase64).\(payloadBase64)"
        let signatureBytes = try P256WireSignature.sign(Data(signingInput.utf8), using: privateKey)
        let signatureBase64 = JWTBase64URL.encode(signatureBytes)

        let proof = "\(headerBase64).\(payloadBase64).\(signatureBase64)"
        return (proof, keyThumbprint)
    }

    func getOrCreateDPoPKey(for did: String) async throws -> P256.Signing.PrivateKey {
        try await getOrCreateDPoPMaterial(for: did).privateKey
    }

    private func fetchOrGenerateDPoPKey(for did: String) async throws -> P256.Signing.PrivateKey {
        do {
            if let representation = try await storage.getDPoPKeyRepresentation(for: did) {
                return try P256.Signing.PrivateKey(x963Representation: representation)
            }
        } catch {
            throw AuthError.dpopKeyError
        }

        // Check if this is an OAuth session that requires a specific key. A failed
        // session read must not be taken for "first login": minting a fresh key would
        // permanently break the cnf/jkt binding of the tokens already issued.
        let existingSession: Session?
        do {
            existingSession = try await storage.getSession(for: did)
        } catch {
            LogManager.logError(
                "Cannot determine whether DID \(LogManager.logDID(did)) has a DPoP-bound session (\(error)); refusing to mint a new DPoP key"
            )
            throw AuthError.dpopKeyError
        }
        if let existingSession, existingSession.tokenType == .dpop {
            throw AuthError.dpopKeyError
        }

        let newKey = P256.Signing.PrivateKey()
        try await storage.saveDPoPKeyRepresentation(newKey.x963Representation, for: did)
        return newKey
    }



    /// Records `nonce` in every store `createDPoPProof` reads for `did`: the in-memory
    /// JKT map, the persisted JKT-scoped map, and the persisted DID-scoped map.
    ///
    /// Writing only the DID-scoped store is never enough — it sits last in the read
    /// precedence, so a stale JKT-scoped entry shadows it and the next `use_dpop_nonce`
    /// retry replays the value the server just rejected.
    ///
    /// `thumbprint` is the DPoP key thumbprint when the caller already knows it
    /// (e.g. from an `AuthContext`); pass `nil` to derive it from the DID's stored key.
    ///
    /// - Returns: `false` when the thumbprint could not be resolved, i.e. the
    ///   JKT-scoped layers still hold whatever stale value shadows this write —
    ///   callers about to retry a request with the fresh nonce must not bother.
    @discardableResult
    private func writeNonceToAllStores(
        domain: String,
        nonce: String,
        did: String,
        thumbprint: String?
    ) async -> Bool {
        var nonces = (try? await storage.getDPoPNonces(for: did)) ?? [:]
        nonces[domain] = nonce
        do {
            try await storage.saveDPoPNonces(nonces, for: did)
        } catch {
            LogManager.logWarning(
                "Failed to persist DID-scoped DPoP nonce for DID: \(LogManager.logDID(did)), domain: \(domain), error: \(error)",
                category: .authentication
            )
        }

        var candidateThumbprint = thumbprint
        if candidateThumbprint == nil {
            candidateThumbprint = await dpopKeyThumbprint(for: did)
        }
        guard let resolvedThumbprint = candidateThumbprint else {
            LogManager.logError(
                "Could not resolve DPoP key thumbprint for DID: \(LogManager.logDID(did)); the fresh nonce for domain \(domain) reached only the DID-scoped store and stays shadowed by the JKT-scoped stores",
                category: .authentication
            )
            return false
        }

        var memDomainMap = noncesByThumbprint[resolvedThumbprint] ?? [:]
        memDomainMap[domain] = nonce
        noncesByThumbprint[resolvedThumbprint] = memDomainMap
        thumbprintsByDID[did, default: []].insert(resolvedThumbprint)

        var jktNonces = (try? await storage.getDPoPNoncesByJKT(for: did)) ?? [:]
        var jktDomainMap = jktNonces[resolvedThumbprint] ?? [:]
        jktDomainMap[domain] = nonce
        jktNonces[resolvedThumbprint] = jktDomainMap
        do {
            try await storage.saveDPoPNoncesByJKT(jktNonces, for: did)
            didsWithUnpersistedNonces.remove(did)
        } catch {
            // The in-memory map is read first, so this process still uses the fresh
            // nonce; only the next launch falls back to the DID-scoped copy. Flagging
            // the DID stops a later merge from reinstating the older persisted value
            // over the one just written here.
            didsWithUnpersistedNonces.insert(did)
            LogManager.logWarning(
                "Failed to persist JKT-scoped DPoP nonce for DID: \(LogManager.logDID(did)), domain: \(domain), error: \(error)",
                category: .authentication
            )
        }

        return true
    }

    /// The JWK thumbprint of the DID's DPoP key, or `nil` when the key is unavailable
    /// (e.g. a locked keychain) — the nonce stores are keyed by it.
    private func dpopKeyThumbprint(for did: String) async -> String? {
        do {
            let material = try await getOrCreateDPoPMaterial(for: did)
            return material.thumbprint
        } catch {
            LogManager.logError(
                "Failed to derive DPoP key thumbprint for DID: \(LogManager.logDID(did)): \(error)",
                category: .authentication
            )
            return nil
        }
    }


    /// Applies a server-issued nonce for `domain` to all of `did`'s nonce stores.
    /// - Returns: `false` when the write could not reach the JKT-scoped stores, so a
    ///   retry would replay the stale nonce the server just rejected.
    @discardableResult
    func updateDPoPNonceInternal(domain: String, nonce: String, for did: String) async -> Bool {
        await writeNonceToAllStores(domain: domain, nonce: nonce, did: did, thumbprint: nil)
    }

    /// Merges the persisted JKT-scoped nonces for `did` into memory unless the last
    /// merge is still within `persistedNonceMergeInterval`.
    private func mergePersistedNoncesIfStale(for did: String) async {
        if let mergedAt = lastPersistedNonceMerge[did],
           Date().timeIntervalSince(mergedAt) < Self.persistedNonceMergeInterval
        {
            return
        }
        // Stamped before the read so proofs issued concurrently don't all queue their
        // own keychain round trip behind this one.
        lastPersistedNonceMerge[did] = Date()

        guard let persistedByJKT = try? await storage.getDPoPNoncesByJKT(for: did) else { return }
        // Persistence normally wins: it is how a write by another OAuthCore or another
        // process is observed. The exception is a DID whose own write never reached the
        // keychain — there the persisted copy is the older one, so memory keeps it.
        let memoryIsNewer = didsWithUnpersistedNonces.contains(did)
        for (persistedThumbprint, domainMap) in persistedByJKT {
            var merged = noncesByThumbprint[persistedThumbprint] ?? [:]
            merged.merge(domainMap) { cached, persisted in memoryIsNewer ? cached : persisted }
            noncesByThumbprint[persistedThumbprint] = merged
            thumbprintsByDID[did, default: []].insert(persistedThumbprint)
        }
    }

    /// Clears the in-memory nonce caches belonging to `did`. Persisted stores are
    /// cleared by the caller. Other accounts' cached nonces are left alone — they are
    /// keyed by their own DPoP thumbprints and remain valid.
    ///
    /// Safe to call after the DID's DPoP key has been deleted: the thumbprints come
    /// from the reverse index rather than from re-deriving the key.
    func clearNonceCache(for did: String) {
        for thumbprint in thumbprintsByDID[did] ?? [] {
            noncesByThumbprint.removeValue(forKey: thumbprint)
        }
        thumbprintsByDID.removeValue(forKey: did)
        lastPersistedNonceMerge.removeValue(forKey: did)
        didsWithUnpersistedNonces.remove(did)
        clearDPoPKeyCache(for: did)
    }


    /// Upper bound on the number of in-flight OAuth flows holding a nonce. Flows are
    /// short-lived and user-driven, so anything past this is abandoned logins whose
    /// nonces nobody will claim. Past the cap the map is dropped wholesale; a flow that
    /// was still live simply pays for one `use_dpop_nonce` challenge.
    private static let oauthFlowNonceKeyCap = 8

    /// Records a nonce observed during an OAuth flow, scoped to the flow's ephemeral
    /// DPoP key. `createDPoPProof` reads this map for ephemeral-key proofs, which have
    /// no account to scope a nonce to yet.
    func recordOAuthFlowNonce(
        _ nonce: String,
        for endpoint: String,
        ephemeralKeyRawRepresentation: Data
    ) {
        guard let key = try? P256.Signing.PrivateKey(rawRepresentation: ephemeralKeyRawRepresentation),
              let thumbprint = try? calculateJWKThumbprint(jwk: createJWK(from: key))
        else {
            LogManager.logWarning(
                "Could not derive a thumbprint for an OAuth flow key; dropping the flow nonce for \(endpoint)",
                category: .authentication
            )
            return
        }
        recordOAuthFlowNonce(nonce, for: endpoint, keyThumbprint: thumbprint)
    }

    func recordOAuthFlowNonce(_ nonce: String, for endpoint: String, keyThumbprint: String) {
        guard let domain = URL(string: endpoint)?.host?.lowercased() else { return }
        if oauthFlowNonces[keyThumbprint] == nil, oauthFlowNonces.count >= Self.oauthFlowNonceKeyCap {
            oauthFlowNonces.removeAll()
        }
        oauthFlowNonces[keyThumbprint, default: [:]][domain] = nonce
    }

    /// Moves the nonces collected during the OAuth flow into `did`'s stores, once the
    /// callback has bound the flow's ephemeral DPoP key to the account. Without this the
    /// first authenticated request re-learns each nonce through a wasted 400.
    /// Call after persisting the DPoP key for `did`.
    ///
    /// Only this flow's nonces move: they are looked up under the DID's own DPoP
    /// thumbprint, which at this point is the flow's ephemeral key, so a login running
    /// concurrently against the same authorization server keeps its own.
    func transferOAuthFlowNonces(to did: String) async {
        guard let thumbprint = await dpopKeyThumbprint(for: did),
              // Taken before the first suspension point below: the actor can accept
              // another flow's nonce while the writes are in flight.
              let pending = oauthFlowNonces.removeValue(forKey: thumbprint)
        else {
            return
        }

        for (domain, nonce) in pending {
            await writeNonceToAllStores(domain: domain, nonce: nonce, did: did, thumbprint: thumbprint)
        }
    }

    // MARK: - Server Metadata

    /// Resolves the authorization server for a PDS that came from an account's
    /// DID document: fetches and validates the PDS's protected-resource metadata,
    /// then the metadata of the single authorization server it names.
    ///
    /// Nothing is assumed on failure. A PDS whose metadata cannot be fetched or
    /// does not satisfy the atproto OAuth profile cannot be signed in to.
    func resolveAuthorizationServer(forPDS pdsURL: URL) async throws -> AuthorizationServerMetadata {
        guard let origin = OAuthOrigin.canonical(of: pdsURL) else {
            throw OAuthMetadataError.invalidOrigin(pdsURL.absoluteString)
        }
        return try await resolveAuthorizationServer(forResourceOrigin: origin)
    }

    /// Resolves the authorization server for a host the user named (server-first
    /// login). The host is tried as a PDS first; if it does not serve valid
    /// protected-resource metadata it is tried as an authorization server (an
    /// entryway) directly.
    ///
    /// Either way the returned metadata's `issuer` equals the origin it was
    /// fetched from, and the caller must still bind the eventual `sub` to that
    /// issuer through the account's own DID document.
    func resolveAuthorizationServer(forServer serverURL: URL) async throws -> AuthorizationServerMetadata {
        guard let origin = OAuthOrigin.canonical(of: serverURL) else {
            throw OAuthMetadataError.invalidOrigin(serverURL.absoluteString)
        }
        do {
            return try await resolveAuthorizationServer(forResourceOrigin: origin)
        } catch let resourceError as OAuthMetadataError {
            do {
                return try await fetchAuthorizationServerMetadata(issuer: origin)
            } catch let issuerError as OAuthMetadataError {
                // A host with no protected-resource document at all was only ever
                // a candidate authorization server, so that failure is the useful one.
                if case .unexpectedStatus(.protectedResource, 404) = resourceError {
                    throw issuerError
                }
                throw resourceError
            }
        }
    }

    private func resolveAuthorizationServer(forResourceOrigin origin: String) async throws -> AuthorizationServerMetadata {
        let resource = try await fetchProtectedResourceMetadata(origin: origin)
        let issuer = try resource.validate(forResourceAt: origin)
        let metadata = try await fetchAuthorizationServerMetadata(issuer: issuer)
        // RFC 9728 §4: an authorization server that lists its resources must list this one.
        if let protected = metadata.protectedResources, !protected.contains(origin) {
            throw OAuthMetadataError.resourceNotProtected(resource: origin, issuer: issuer)
        }
        return metadata
    }

    /// Fetches a PDS's protected-resource metadata. The document is returned
    /// undecided: call `validate(forResourceAt:)` before trusting it.
    func fetchProtectedResourceMetadata(origin: String) async throws -> ProtectedResourceMetadata {
        try await fetchMetadataDocument(ProtectedResourceMetadata.self, document: .protectedResource, origin: origin)
    }

    /// Fetches and validates an authorization server's metadata. `issuer` must be
    /// a canonical origin; the returned document's `issuer` is guaranteed equal to it.
    func fetchAuthorizationServerMetadata(issuer: String) async throws -> AuthorizationServerMetadata {
        try OAuthOrigin.requireCanonical(issuer)
        let metadata = try await fetchMetadataDocument(
            AuthorizationServerMetadata.self, document: .authorizationServer, origin: issuer
        )
        try metadata.validate(fetchedFrom: issuer, clientAuthentication: clientAuthenticator.method)
        return metadata
    }

    /// Fetches one well-known metadata document: HTTP 200 only (redirects are
    /// never followed), `application/json` only.
    private func fetchMetadataDocument<Body: Decodable>(
        _: Body.Type,
        document: OAuthMetadataError.Document,
        origin: String
    ) async throws -> Body {
        guard let url = URL(string: "\(origin)/.well-known/\(document.rawValue)") else {
            throw OAuthMetadataError.invalidOrigin(origin)
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0

        let (data, response) = try await sendWithTransportRetry(request)
        guard response.statusCode == 200 else {
            throw OAuthMetadataError.unexpectedStatus(document: document, status: response.statusCode)
        }
        let contentType = response.value(forHTTPHeaderField: "Content-Type")
        guard Self.isJSONContentType(contentType) else {
            throw OAuthMetadataError.unexpectedContentType(document: document, contentType: contentType)
        }
        do {
            return try decoder.decode(Body.self, from: data)
        } catch {
            throw OAuthMetadataError.malformedDocument(document: document)
        }
    }

    static func isJSONContentType(_ contentType: String?) -> Bool {
        guard let mediaType = contentType?.split(separator: ";").first else { return false }
        return mediaType.trimmingCharacters(in: .whitespaces).lowercased() == "application/json"
    }

    /// Sends an idempotent request, retrying transport failures (not HTTP
    /// statuses, and not policy refusals) up to three times.
    private func sendWithTransportRetry(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let maxAttempts = 3
        var attempt = 1
        while true {
            do {
                return try await sendToAuthorizationServer(request)
            } catch let error as NetworkError {
                if case .requestFailed = error, attempt < maxAttempts {
                    let delay = pow(2.0, Double(attempt - 1)) * 0.1
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }
                throw AuthError.networkError(error)
            }
        }
    }

    /// The one place OAuth protocol requests leave the process. Transport
    /// failures surface as `NetworkError`; cancellation is passed through.
    private func sendToAuthorizationServer(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await networkService.executeAuthProtocolRequest(request)
        } catch let error as NetworkError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            LogManager.logError(
                "OAuth request to \(request.url.map { LogManager.sanitizeURLForLogging($0) } ?? "unknown") failed: \(error)",
                category: .authentication
            )
            throw NetworkError.requestFailed
        }
    }

    // MARK: - Authorization Server Requests

    /// Sends a DPoP-signed form POST to an authorization-server endpoint and
    /// handles the server's nonce protocol (RFC 9449 §8).
    ///
    /// - A `DPoP-Nonce` on any response is recorded for the signing key.
    /// - A `use_dpop_nonce` challenge is answered exactly once, with a new proof
    ///   carrying the server's nonce and freshly produced client-authentication
    ///   parameters (a client assertion's `jti` is single-use).
    ///
    /// Used for every request to the authorization server — pushed authorization
    /// request, code exchange, refresh and revocation — so the nonce handling is
    /// the same on all of them.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint URL, taken from validated server metadata.
    ///   - issuer: The validated issuer, used as the client assertion audience.
    ///   - proofType: The DPoP proof type.
    ///   - key: The DPoP key that signs the request.
    ///   - initialNonce: A nonce to use on the first attempt instead of the stored one.
    ///   - timeout: Per-attempt request timeout.
    ///   - parameters: The request's own form parameters (client authentication is added here).
    /// - Returns: The body and response of the final attempt, whatever its status.
    func sendAuthorizationServerRequest(
        endpoint: String,
        issuer: String,
        proofType: DPoPProofType,
        key: DPoPKeySource,
        initialNonce: String? = nil,
        timeout: TimeInterval = 30.0,
        parameters: [String: String]
    ) async throws -> (Data, HTTPURLResponse) {
        guard OAuthOrigin.isEndpointURL(endpoint), let endpointURL = URL(string: endpoint) else {
            throw OAuthMetadataError.invalidEndpoint(field: "endpoint", value: endpoint)
        }

        var nonce = initialNonce
        var attempt = 0
        while true {
            var form = parameters
            let clientAuthentication = try await clientAuthenticator.parameters(forIssuer: issuer, key: key, core: self)
            form.merge(clientAuthentication) { _, authentication in authentication }

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.timeoutInterval = timeout
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = encodeFormData(form)

            let proof: String
            switch key {
            case let .flow(rawRepresentation):
                proof = try await createDPoPProof(
                    for: "POST", url: endpoint, type: proofType,
                    ephemeralKeyRawRepresentation: rawRepresentation, nonce: nonce
                )
            case let .account(did):
                proof = try await createDPoPProof(
                    for: "POST", url: endpoint, type: proofType, did: did, nonce: nonce
                )
            }
            request.setValue(proof, forHTTPHeaderField: "DPoP")

            let (data, response) = try await sendToAuthorizationServer(request)

            let serverNonce = response.value(forHTTPHeaderField: "DPoP-Nonce")
            if let serverNonce {
                await recordNonce(serverNonce, endpoint: endpoint, key: key)
            }

            if attempt == 0, let serverNonce, Self.isUseDPoPNonceChallenge(data: data, response: response) {
                LogManager.logInfo(
                    "Authorization server \(endpointURL.host ?? "unknown") issued a DPoP nonce challenge; retrying once",
                    category: .authentication
                )
                nonce = serverNonce
                attempt += 1
                continue
            }
            return (data, response)
        }
    }

    /// Whether `response` is an RFC 9449 `use_dpop_nonce` challenge: signalled in
    /// the JSON error body by authorization servers (§8) and in
    /// `WWW-Authenticate` by resource servers (§9).
    static func isUseDPoPNonceChallenge(data: Data, response: HTTPURLResponse) -> Bool {
        guard response.statusCode == 400 || response.statusCode == 401 else { return false }
        if let body = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
           body.error == "use_dpop_nonce"
        {
            return true
        }
        if let challenge = response.value(forHTTPHeaderField: "WWW-Authenticate"),
           challenge.lowercased().contains("error=\"use_dpop_nonce\"")
        {
            return true
        }
        return false
    }

    /// Files a server-issued nonce under the key that signed the request: the
    /// flow's ephemeral key before an account exists, the account's stores after.
    private func recordNonce(_ nonce: String, endpoint: String, key: DPoPKeySource) async {
        switch key {
        case let .flow(rawRepresentation):
            recordOAuthFlowNonce(nonce, for: endpoint, ephemeralKeyRawRepresentation: rawRepresentation)
        case let .account(did):
            guard let domain = URL(string: endpoint)?.host?.lowercased() else { return }
            await updateDPoPNonceInternal(domain: domain, nonce: nonce, for: did)
        }
    }

    /// Builds the form parameters for a pushed authorization request.
    /// `additionalParameters` override base entries on key collision.
    func buildPARParameters(
        codeChallenge: String,
        identifier: String?,
        state: String,
        scope: String? = nil,
        additionalParameters: [String: String]? = nil
    ) -> [String: String] {
        var parameters: [String: String] = [
            "client_id": oauthConfig.clientId,
            "redirect_uri": oauthConfig.redirectUri,
            "response_type": "code",
            "code_challenge_method": "S256",
            "code_challenge": codeChallenge,
            "state": state,
            "scope": scope ?? oauthConfig.scope,
        ]

        if let identifier {
            parameters["login_hint"] = identifier
        }

        if let additionalParameters {
            parameters.merge(additionalParameters) { _, new in new }
        }

        return parameters
    }

    /// Sends the pushed authorization request that starts a flow (RFC 9126).
    /// - Returns: The `request_uri` for the authorization redirect and the DPoP
    ///   nonce the server issued with it.
    func pushAuthorizationRequest(
        metadata: AuthorizationServerMetadata,
        codeChallenge: String,
        identifier: String?,
        state: String,
        scope: String,
        flowKey: Data
    ) async throws -> (requestURI: String, parNonce: String) {
        let (data, response) = try await sendAuthorizationServerRequest(
            endpoint: metadata.pushedAuthorizationRequestEndpoint,
            issuer: metadata.issuer,
            proofType: .authorization,
            key: .flow(flowKey),
            parameters: buildPARParameters(
                codeChallenge: codeChallenge, identifier: identifier, state: state, scope: scope
            )
        )

        guard (200 ... 299).contains(response.statusCode) else {
            throw parseOAuthError(from: data, statusCode: response.statusCode)
        }
        guard let parResponse = try? decoder.decode(PARResponse.self, from: data) else {
            throw AuthError.invalidResponse
        }
        let nonce = try Self.requireNonce(in: response, endpoint: "pushed authorization request")
        return (parResponse.requestURI, nonce)
    }

    /// The atproto OAuth profile makes server nonces mandatory: a response to a
    /// DPoP request that carries no `DPoP-Nonce` header must be rejected.
    static func requireNonce(in response: HTTPURLResponse, endpoint: String) throws -> String {
        guard let nonce = response.value(forHTTPHeaderField: "DPoP-Nonce"), !nonce.isEmpty else {
            LogManager.logError(
                "The \(endpoint) response carried no DPoP-Nonce header; the atproto OAuth profile requires one",
                category: .authentication
            )
            throw AuthError.invalidResponse
        }
        return nonce
    }

    func parseOAuthError(from data: Data, statusCode: Int) -> AuthError {
        if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
            let desc = errorResponse.errorDescription ?? ""
            let isNativeNone = (errorResponse.error == "invalid_client_metadata" || errorResponse.error == "invalid_client")
                && (desc.localizedCaseInsensitiveContains("none method")
                    || desc.localizedCaseInsensitiveContains("must authenticate using none")
                    || (desc.localizedCaseInsensitiveContains("native") && desc.localizedCaseInsensitiveContains("none")))
            if isNativeNone {
                return .nativeClientNoneAuthRequired(errorResponse.errorDescription)
            } else if errorResponse.error == "invalid_client_metadata" {
                return .invalidClientMetadata(errorResponse.errorDescription)
            }
            return .serverError(statusCode, "\(errorResponse.error): \(desc)")
        }
        return .authorizationFailed
    }

    /// Exchanges an authorization code for tokens (RFC 6749 §4.1.3 with PKCE and DPoP).
    func exchangeAuthorizationCode(
        _ code: String,
        codeVerifier: String,
        redirectURI: String,
        metadata: AuthorizationServerMetadata,
        flowKey: Data,
        initialNonce: String?
    ) async throws -> TokenResponse {
        let (data, response) = try await sendAuthorizationServerRequest(
            endpoint: metadata.tokenEndpoint,
            issuer: metadata.issuer,
            proofType: .tokenRequest,
            key: .flow(flowKey),
            initialNonce: initialNonce,
            parameters: [
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirectURI,
                "code_verifier": codeVerifier,
            ]
        )

        guard (200 ..< 300).contains(response.statusCode) else {
            if let errorResponse = try? decoder.decode(OAuthErrorResponse.self, from: data) {
                if errorResponse.error == "invalid_grant" {
                    throw AuthError.invalidCredentials
                }
                throw AuthError.serverError(
                    response.statusCode, "\(errorResponse.error): \(errorResponse.errorDescription ?? "")"
                )
            }
            throw AuthError.tokenRefreshFailed
        }

        do {
            _ = try Self.requireNonce(in: response, endpoint: "token")
            return try JSONCoders.decode(TokenResponse.self, from: data)
        } catch {
            LogManager.logError("Token response failed validation: \(error)", category: .authentication)
            // The server considers the session issued. Revoke whatever token can
            // still be read from the response rather than abandoning it.
            if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let token = (object["refresh_token"] as? String) ?? (object["access_token"] as? String)
            {
                await revokeToken(token, metadata: metadata, key: .flow(flowKey))
            }
            throw AuthError.invalidResponse
        }
    }

    /// Sends a refresh-token grant for `did`'s session.
    /// - Returns: The raw response; the caller verifies and persists it.
    func requestTokenRefresh(
        did: String,
        refreshToken: String,
        metadata: AuthorizationServerMetadata
    ) async throws -> (Data, HTTPURLResponse) {
        try await sendAuthorizationServerRequest(
            endpoint: metadata.tokenEndpoint,
            issuer: metadata.issuer,
            proofType: .tokenRefresh,
            key: .account(did),
            parameters: [
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
            ]
        )
    }

    /// Revokes `token` at the authorization server (RFC 7009).
    ///
    /// The request is authenticated like every other authorization-server
    /// request: DPoP proof, nonce retry, and the client's authentication
    /// parameters, so a confidential client's revocation carries its assertion.
    ///
    /// - Returns: `true` when the server confirmed the revocation with HTTP 200.
    ///   `false` when the server has no revocation endpoint, refused, or could
    ///   not be reached — the token may then still be valid server-side.
    @discardableResult
    func revokeToken(_ token: String, metadata: AuthorizationServerMetadata, key: DPoPKeySource) async -> Bool {
        guard let endpoint = metadata.revocationEndpoint else {
            LogManager.logInfo(
                "Authorization server \(metadata.issuer) has no revocation endpoint; token not revoked",
                category: .authentication
            )
            return false
        }
        do {
            let (_, response) = try await sendAuthorizationServerRequest(
                endpoint: endpoint,
                issuer: metadata.issuer,
                proofType: .tokenRequest,
                key: key,
                // Logout and account removal wait on this; an unreachable
                // server must not hold them up for long.
                timeout: 10.0,
                parameters: ["token": token]
            )
            guard response.statusCode == 200 else {
                LogManager.logError(
                    "Token revocation at \(metadata.issuer) was refused with HTTP \(response.statusCode); the token may remain valid",
                    category: .authentication
                )
                return false
            }
            return true
        } catch {
            LogManager.logError(
                "Token revocation at \(metadata.issuer) failed (\(error)); the token may remain valid",
                category: .authentication
            )
            return false
        }
    }

    // MARK: - AuthenticationProvider Methods

    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async {
        guard let domain = url.host?.lowercased() else { return }

        // Extract nonce case-insensitively
        var nonce: String?
        for (key, value) in headers {
            if key.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame {
                nonce = value
                break
            }
        }
        guard let nonce else { return }

        var targetDID = did
        if targetDID == nil {
            targetDID = await accountManager.getCurrentAccount()?.did
        }
        guard let resolvedDID = targetDID else { return }

        // `jkt` is nil for every response the network layer handles without an
        // AuthContext — notably the token endpoint, whose 200 carries the nonce the
        // *next* refresh needs. Deriving the thumbprint from the DID's key keeps that
        // nonce out of the DID-scoped store alone, where the JKT layers would shadow it.
        await writeNonceToAllStores(domain: domain, nonce: nonce, did: resolvedDID, thumbprint: jkt)
    }

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        return try await prepareAuthenticatedRequestWithContext(request).0
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        guard let account = await accountManager.getCurrentAccount(),
              let session = try? await storage.getSession(for: account.did)
        else {
            throw AuthError.noActiveAccount
        }

        var req = request
        let isTokenEndpoint = account.authorizationServerMetadata?.tokenEndpoint == request.url?.absoluteString
        let type: DPoPProofType = isTokenEndpoint ? .tokenRequest : .resourceAccess

        // Generate DPoP and obtain its thumbprint atomically from the same material
        let (proof, thumbprint) = try await createDPoPProofWithMaterial(
            for: request.httpMethod ?? "GET",
            url: request.url?.absoluteString ?? "",
            type: type,
            accessToken: isTokenEndpoint ? nil : session.accessToken,
            did: account.did
        )
        req.setValue(proof, forHTTPHeaderField: "DPoP")

        if !isTokenEndpoint {
            req.setValue("DPoP \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        return (req, AuthContext(did: account.did, jkt: thumbprint))

    }

    // MARK: - Refresh Coordination

    func tokensExist() async -> Bool {
        guard let did = await accountManager.getCurrentAccount()?.did else { return false }
        return (try? await storage.getSession(for: did)) != nil
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        try await refreshTokenIfNeeded(forceRefresh: false)
    }

    /// Refreshes the current account's tokens when they are due (or when forced).
    ///
    /// This is the refresh lock the profile calls for: refresh tokens are
    /// single-use, so at most one refresh per account is in flight and every
    /// concurrent caller awaits that one instead of presenting the same token again.
    func refreshTokenIfNeeded(forceRefresh: Bool) async throws -> TokenRefreshResult {
        while true {
            guard let account = await accountManager.getCurrentAccount(),
                  let session = await currentSession(for: account.did)
            else {
                throw AuthError.noActiveAccount
            }

            let did = account.did

            if let task = activeRefreshTasks[did] { return try await task.value }

            guard let refreshToken = session.refreshToken else {
                // A session granted without a refresh token (the client did not
                // declare the refresh_token grant) is good for as long as its
                // access token is: there is nothing to refresh it with, so it
                // must not be refused while the token still works.
                if !forceRefresh, !session.isExpired { return .stillValid }
                LogManager.logInfo(
                    "Session for DID \(LogManager.logDID(did)) has no refresh token and its access token can no longer be used; the user must sign in again",
                    category: .authentication
                )
                throw AuthError.tokenRefreshFailed
            }
            if usedRefreshTokens.contains(refreshToken) {
                // Either the server definitively rejected this token, or a refresh
                // that finished while this call was reading the session has already
                // rotated it. Only the first is a failure.
                if let latest = await currentSession(for: did)?.refreshToken, latest != refreshToken {
                    continue
                }
                throw AuthError.tokenRefreshFailed
            }

            // Circuit breaker check
            guard await refreshCircuitBreaker.canAttemptRefresh(for: did) else { throw AuthError.tokenRefreshFailed }

            // Another caller may have started a refresh during the suspensions above.
            if let task = activeRefreshTasks[did] { return try await task.value }
            if usedRefreshTokens.contains(refreshToken) { continue }

            // Check expiry
            if !forceRefresh && !session.isExpiringSoon { return .stillValid }

            // Tests may substitute the wire exchange; production always runs the real one.
            let performRefresh: @Sendable (Account, Session) async throws -> TokenRefreshResult =
                performActualRefresh ?? { [weak self] account, session in
                    guard let self else { throw AuthError.tokenRefreshFailed }
                    return try await self.performRefresh(for: account, session: session)
                }

            // Guard against concurrent reuse while the request is in flight. The token is
            // only treated as permanently consumed when the server definitively used it
            // (success, or invalid_grant); a transient failure (timeout, offline, 5xx)
            // must NOT burn it, or every later refresh fails until app restart.
            if usedRefreshTokens.count > Self.usedRefreshTokenCap {
                usedRefreshTokens.removeAll()
            }
            usedRefreshTokens.insert(refreshToken)

            let task = Task<TokenRefreshResult, Error> {
                try await performRefresh(account, session)
            }
            activeRefreshTasks[did] = task
            defer { activeRefreshTasks.removeValue(forKey: did) }

            do {
                return try await task.value
            } catch {
                if !Self.isDefinitiveRefreshRejection(error) {
                    usedRefreshTokens.remove(refreshToken)
                }
                throw error
            }
        }
    }

    /// True when the auth server definitively consumed or revoked the refresh token
    /// (it must never be retried); false for transient failures that are safe to retry.
    static func isDefinitiveRefreshRejection(_ error: Error) -> Bool {
        // `.invalidResponse` is thrown only after a 2xx refresh response failed
        // verification: the server has rotated the token, so the old one is spent.
        (error as? AuthError) == .invalidCredentials || (error as? AuthError) == .invalidResponse
    }

    /// Returns the freshest known session for `did`: an unpersisted in-memory session
    /// (from a refresh whose keychain save failed) wins over the stored one when newer.
    /// The stored read bypasses the in-memory cache so a rotation performed by another
    /// process sharing the access group (e.g. an app extension) is observed before
    /// this process attempts to rotate an already-consumed token.
    func currentSession(for did: String) async -> Session? {
        let stored = try? await storage.getSession(for: did, bypassCache: true)
        guard let unpersisted = unpersistedSessions[did] else { return stored }
        if let stored, stored.createdAt >= unpersisted.createdAt {
            unpersistedSessions.removeValue(forKey: did)
            return stored
        }
        return unpersisted
    }

    /// Persists a session obtained from a successful token refresh. At this point the
    /// server has already rotated the (single-use) refresh token, so losing `session`
    /// means losing the account: retry the atomic save, then fall back to a single-write
    /// pending key plus an in-memory copy. Persistence failure is deliberately not an
    /// error — the refresh itself succeeded.
    func persistRefreshedSession(_ session: Session, for account: Account) async {
        let did = account.did
        for attempt in 1 ... 3 {
            do {
                try await storage.saveAccountAndSession(account, session: session, for: did)
                unpersistedSessions.removeValue(forKey: did)
                return
            } catch {
                LogManager.logWarning(
                    "Refreshed-session persist attempt \(attempt)/3 failed for DID: \(LogManager.logDID(did)), error: \(error)"
                )
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 150_000_000)
                }
            }
        }

        unpersistedSessions[did] = session
        do {
            try await storage.savePendingSession(session, for: did)
            LogManager.logError(
                "Refreshed session could not be saved atomically for DID: \(LogManager.logDID(did)); wrote pending key and holding in memory"
            )
        } catch {
            LogManager.logError(
                "CRITICAL: refreshed session for DID: \(LogManager.logDID(did)) could not be persisted at all; holding in memory only. Error: \(error)"
            )
        }
    }
}

/// Minimal ES256 JWK representation for DPoP proof headers and RFC 7638 thumbprints.
struct JWK: Codable, Sendable, Equatable {
    let kty: String
    let crv: String
    let x: String
    let y: String

    init(x: String, y: String) {
        self.kty = "EC"
        self.crv = "P-256"
        self.x = x
        self.y = y
    }

    init(kty: String = "EC", crv: String = "P-256", x: String, y: String) {
        self.kty = kty
        self.crv = crv
        self.x = x
        self.y = y
    }
}

private struct DPoPHeader: Codable, Sendable {
    let typ: String
    let alg: String
    let jwk: JWK

    init(jwk: JWK) {
        self.typ = "dpop+jwt"
        self.alg = "ES256"
        self.jwk = jwk
    }
}

// MARK: - Supporting Types

private struct DPoPPayload: Encodable {
    let jti: String
    let htm: String
    let htu: String
    let iat: Int
    let exp: Int?
    let ath: String?
    let nonce: String?
}

struct PARResponse: Decodable {
    let requestURI: String
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case requestURI = "request_uri"
        case expiresIn = "expires_in"
    }
}

struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
