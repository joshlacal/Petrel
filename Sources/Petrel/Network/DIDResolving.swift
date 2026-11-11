//
//  DIDResolving.swift
//  Petrel
//
//  Created by Josh LaCalamito on 10/19/24.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - DIDResolving Protocol

/// The identity lookups `ATProtoClient` and its authentication strategies need.
///
/// ``IdentityResolver`` is the implementation to use, directly or as the `didResolver:` of a
/// client. Conform your own type to substitute resolution entirely.
public protocol DIDResolving: Sendable, AnyObject {
    /// Resolves a handle to the DID whose document claims the handle back.
    func resolveHandleToDID(handle: String) async throws -> String
    /// Resolves a DID to the endpoint of its `#atproto_pds` service.
    func resolveDIDToPDSURL(did: String) async throws -> URL
    /// Resolves a DID to its handle and PDS endpoint. The handle is `handle.invalid` unless it
    /// resolves back to the DID.
    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL)
}

// MARK: - DIDResolutionService

/// The resolver an `ATProtoClient` creates for itself: an ``IdentityResolver`` that first asks
/// the client's own service to resolve a handle and falls back to the handle's domain.
///
/// The handle specification lets a client rely on its PDS or AppView for the handle-to-DID
/// lookup. That one request goes through the client's `NetworkService`, to the client's own
/// service origin. Everything else, including the DID document fetch that verifies the answer,
/// uses the resolver's credential-free transport: a handle host, a `did:web` host and the PLC
/// directory never see the account's credentials or headers.
final class DIDResolutionService: DIDResolving {
    /// The resolver that does the work, for callers that need more than `DIDResolving` offers.
    let identityResolver: IdentityResolver

    /// - Parameters:
    ///   - networkService: The client's network service, used only for
    ///     `com.atproto.identity.resolveHandle` on the client's own service.
    ///   - dnsTXTLookup: Replaces the system DNS TXT lookup.
    init(
        networkService: NetworkService,
        dnsTXTLookup: (@Sendable (String) async throws -> [String])? = nil
    ) async {
        #if DEBUG
            // Local development stacks use `.test` handles and `did:web:localhost`.
            let allowsDevelopmentIdentifiers = true
        #else
            let allowsDevelopmentIdentifiers = false
        #endif
        let userAgent = await networkService.getHeader(name: "User-Agent")
        identityResolver = IdentityResolver(
            options: IdentityResolver.Options(
                handleStrategy: .custom(
                    lookup: { handle in try await Self.resolveHandleViaService(handle, networkService: networkService) },
                    fallbackToDirect: true
                ),
                allowsDevelopmentIdentifiers: allowsDevelopmentIdentifiers
            ),
            httpTransport: HardenedIdentityHTTPTransport(userAgent: userAgent),
            dnsResolver: dnsTXTLookup.map(ClosureIdentityDNSResolver.init)
        )
    }

    func resolveHandleToDID(handle: String) async throws -> String {
        try await identityResolver.resolveHandleToDID(handle: handle)
    }

    func resolveDIDToPDSURL(did: String) async throws -> URL {
        try await identityResolver.resolveDIDToPDSURL(did: did)
    }

    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
        try await identityResolver.resolveDIDToHandleAndPDSURL(did: did)
    }

    /// `com.atproto.identity.resolveHandle` on the client's service. Returns `nil` when the
    /// service answers without a DID, so the resolver falls back to the handle's own domain.
    private static func resolveHandleViaService(
        _ handle: Handle,
        networkService: NetworkService
    ) async throws -> String? {
        try Task.checkCancellation()
        let input = ComAtprotoIdentityResolveHandle.Parameters(handle: handle)
        let request = try await networkService.createURLRequest(
            endpoint: "com.atproto.identity.resolveHandle",
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: input.asQueryItems()
        )
        let (data, response) = try await networkService.performRequest(request)
        guard response.statusCode == 200,
              let output = try? JSONCoders.decode(ComAtprotoIdentityResolveHandle.Output.self, from: data)
        else {
            return nil
        }
        return output.did.didString()
    }
}
