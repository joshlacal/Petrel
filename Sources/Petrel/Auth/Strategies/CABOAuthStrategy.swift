//
//  CABOAuthStrategy.swift
//  Petrel
//
//  Client Assertion Backend (CAB) OAuth strategy.
//

import Crypto
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The atproto OAuth client acting as a confidential client whose
/// `private_key_jwt` assertions are minted by a Client Assertion Backend.
///
/// The backend holds the client's signing key and issues a fresh, DPoP-bound
/// assertion for every request to the authorization server: pushed
/// authorization request, code exchange, refresh and revocation. Everything
/// else is the shared flow in ``OAuthCore``.
actor CABOAuthStrategy: OAuthCoreBackedStrategy {
    let core: OAuthCore
    let backendURL: URL

    /// Transport for backend assertion fetches — injectable for tests.
    let urlSession: URLSession

    private let authenticator: CABClientAuthenticator

    static let clientAssertionTypeJWTBearer = oauthClientAssertionTypeJWTBearer

    init(
        backendURL: URL,
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving,
        urlSession: URLSession = .shared
    ) {
        self.backendURL = backendURL
        self.urlSession = urlSession
        let authenticator = CABClientAuthenticator(backendURL: backendURL, urlSession: urlSession)
        self.authenticator = authenticator
        core = OAuthCore(
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            oauthConfig: oauthConfig,
            didResolver: didResolver,
            clientAuthenticator: authenticator
        )
    }

    /// Fetches a DPoP-bound client assertion for the given authorization
    /// server issuer, signed with either a flow's ephemeral key or the
    /// account's stored key. Retries exactly once when the backend answers
    /// 400 `use_dpop_nonce` with a `DPoP-Nonce` header.
    func fetchClientAssertion(
        aud: String,
        ephemeralKey: P256.Signing.PrivateKey? = nil,
        did: String? = nil
    ) async throws -> ClientAssertionResponse {
        let key: DPoPKeySource
        if let ephemeralKey {
            key = .flow(ephemeralKey.rawRepresentation)
        } else if let did {
            key = .account(did)
        } else {
            throw AuthError.dpopKeyError
        }
        return try await authenticator.fetchAssertion(audience: aud, key: key, core: core)
    }
}
