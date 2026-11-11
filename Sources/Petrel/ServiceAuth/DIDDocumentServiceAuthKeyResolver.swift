import Foundation
import PetrelCrypto

/// Resolves service-auth signing keys from DID documents.
///
/// This is the piece the specification describes for a receiving service:
/// "validate the signature by checking this key against the account's DID
/// document." Give it any way of fetching a DID document and it reads the
/// requested verification method out of it:
///
/// ```swift
/// let resolver = DIDDocumentServiceAuthKeyResolver { did, forceRefresh in
///     try await directory.document(for: did, bypassCache: forceRefresh)
/// }
/// let verifier = ServiceAuthVerifier(
///     audience: .service(did: "did:web:feed.example.com", id: "bsky_fg", acceptBareDID: true),
///     keyResolver: resolver
/// )
/// ```
///
/// `Multikey` verification methods and the two legacy 2019 suites are
/// supported, on both curves. The document's `id` must be the DID that was
/// asked for, so a document source cannot answer with another identity's
/// keys.
///
/// The resolver does not cache. Wrap it in
/// `CachingServiceAuthKeyResolver` unless the document source already
/// caches and rate-limits forced refreshes.
public struct DIDDocumentServiceAuthKeyResolver: ServiceAuthKeyResolver {
    // INTEGRATION(sdk-green/identity): when the public IdentityResolver is on
    // the same branch, add a convenience that uses it as the document source:
    //
    //     public init(identityResolver: IdentityResolver) {
    //         self.init { did, forceRefresh in
    //             try await identityResolver.resolveDIDDocument(did, forceRefresh: forceRefresh)
    //         }
    //     }
    //
    // and name it in the two ServiceAuth DocC articles in place of `directory`.

    private let resolveDocument: @Sendable (_ did: String, _ forceRefresh: Bool) async throws -> DIDDocument

    /// - Parameter resolveDocument: Fetches the DID document for a DID.
    ///   When `forceRefresh` is `true` it must bypass any cache: the
    ///   verifier asks for that after a signature failed, in case the
    ///   issuer rotated its key.
    public init(
        resolveDocument: @escaping @Sendable (_ did: String, _ forceRefresh: Bool) async throws -> DIDDocument
    ) {
        self.resolveDocument = resolveDocument
    }

    /// Returns the issuer's `#atproto` signing key.
    public func signingKey(for did: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        try await signingKey(for: did, keyID: ServiceJWT.defaultKeyID, forceRefresh: forceRefresh)
    }

    /// Returns the key the issuer's DID document publishes under `keyID`.
    ///
    /// - Throws: `ServiceAuthError.keyResolutionFailed(did:keyID:reason:)`
    ///   if the document is for another DID, has no such verification
    ///   method, or the method's key cannot be read; otherwise whatever the
    ///   document source throws.
    public func signingKey(for did: String, keyID: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        let document = try await resolveDocument(did, forceRefresh)
        return try Self.signingKey(in: document, did: did, keyID: keyID)
    }

    /// Reads the key published under `keyID` out of a DID document.
    ///
    /// - Parameters:
    ///   - document: The resolved DID document.
    ///   - did: The DID the document was resolved for.
    ///   - keyID: The verification method fragment, with its `#`
    ///     (`#atproto`, `#atproto_label`).
    /// - Throws: `ServiceAuthError.keyResolutionFailed(did:keyID:reason:)`.
    public static func signingKey(
        in document: DIDDocument,
        did: String,
        keyID: String = ServiceJWT.defaultKeyID
    ) throws -> ATProtoPublicKey {
        func failure(_ reason: String) -> ServiceAuthError {
            .keyResolutionFailed(did: did, keyID: keyID, reason: reason)
        }
        guard document.id == did else {
            throw failure("DID document is for \(document.id)")
        }
        // A verification method id is either the bare fragment or the full
        // DID URL; the first match wins, as in the reference implementation.
        guard let method = document.verificationMethod.first(where: { $0.id == keyID || $0.id == did + keyID }) else {
            throw failure("DID document has no verification method \(keyID)")
        }
        do {
            return try ATProtoPublicKey(
                verificationMethodType: method.type, publicKeyMultibase: method.publicKeyMultibase
            )
        } catch {
            throw failure("verification method \(keyID) does not hold a P-256 or K-256 key (\(error))")
        }
    }
}
