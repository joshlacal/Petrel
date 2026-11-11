//
//  ATProtoClient+Identity.swift
//  Petrel
//

import Foundation

public extension ATProtoClient {
    /// The ``IdentityResolver`` this client resolves handles and DIDs with.
    ///
    /// It is the resolver the client created for itself, or the one passed as `didResolver:`.
    /// `nil` when the client was given a `DIDResolving` of another type.
    nonisolated var identityResolver: IdentityResolver? {
        if let service = didResolver as? DIDResolutionService {
            return service.identityResolver
        }
        return didResolver as? IdentityResolver
    }

    /// Resolves a handle or a DID to a verified identity: the DID, its document, and the handle
    /// confirmed in both directions (or `handle.invalid`).
    ///
    /// - Parameters:
    ///   - identifier: A handle or a DID.
    ///   - forceRefresh: Ignore cached results.
    /// - Throws: ``IdentityError``; `APIError.serviceNotInitialized` when the client was given a
    ///   `DIDResolving` that is not an ``IdentityResolver``.
    func resolveIdentity(_ identifier: String, forceRefresh: Bool = false) async throws -> ResolvedIdentity {
        guard let identityResolver else {
            throw APIError.serviceNotInitialized
        }
        return try await identityResolver.resolveIdentity(identifier, forceRefresh: forceRefresh)
    }

    /// Resolves a DID to its document.
    ///
    /// - Throws: ``IdentityError``; `APIError.serviceNotInitialized` when the client was given a
    ///   `DIDResolving` that is not an ``IdentityResolver``.
    func resolveDIDDocument(_ did: String, forceRefresh: Bool = false) async throws -> DIDDocument {
        guard let identityResolver else {
            throw APIError.serviceNotInitialized
        }
        return try await identityResolver.resolveDIDDocument(did, forceRefresh: forceRefresh)
    }
}
