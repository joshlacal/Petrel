//
//  PublicOAuthStrategy.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/26.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The atproto OAuth client: identity-first or server-first login with pushed
/// authorization requests, PKCE (S256), per-session ES256 DPoP keys with
/// server-nonce handling, verified token responses and single-use refresh.
///
/// By default it acts as a public client (`token_endpoint_auth_method: none`),
/// the right choice for native and mobile apps. Given an
/// ``OAuthClientAssertionSigner`` it acts as a confidential client that
/// authenticates with `private_key_jwt`, for server-side Swift.
///
/// The flow itself lives in ``OAuthCore``; see `OAuthCore+Flow.swift`.
actor PublicOAuthStrategy: OAuthCoreBackedStrategy {
    let core: OAuthCore

    init(
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving,
        clientAssertionSigner: (any OAuthClientAssertionSigner)? = nil
    ) {
        core = OAuthCore(
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            oauthConfig: oauthConfig,
            didResolver: didResolver,
            clientAuthenticator: clientAssertionSigner.map {
                SignedClientAuthenticator(clientId: oauthConfig.clientId, signer: $0)
            }
        )
    }
}
