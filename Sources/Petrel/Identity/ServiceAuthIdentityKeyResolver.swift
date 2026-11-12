import Foundation
import PetrelCrypto

/// ``IdentityResolver`` as the key source for service-auth verification.
///
/// A receiving service verifies a service-auth JWT against the signing key in
/// the issuer's DID document. With this conformance an identity resolver can
/// be handed straight to `ServiceAuthVerifier`:
///
/// ```swift
/// let verifier = ServiceAuthVerifier(
///     audience: .service(did: "did:web:feed.example.com", id: "bsky_fg", acceptBareDID: true),
///     keyResolver: CachingServiceAuthKeyResolver(upstream: IdentityResolver())
/// )
/// let caller = try await verifier.verify(
///     authorizationHeader: request.headers["Authorization"],
///     method: .exactly("app.bsky.feed.getFeedSkeleton")
/// )
/// ```
///
/// The verifier asks for `forceRefresh: true` once after a signature fails,
/// which makes the resolver fetch the DID document again and so picks up a
/// key rotation. Anyone can send a token with a bad signature, so wrap the
/// resolver in `CachingServiceAuthKeyResolver` as above: it limits how often
/// a forced refresh for one issuer reaches the network.
extension IdentityResolver: ServiceAuthKeyResolver {
    /// The issuer's `#atproto` signing key, from its DID document.
    ///
    /// - Parameters:
    ///   - did: The issuer's DID, without a fragment.
    ///   - forceRefresh: Fetch the DID document even when a cached copy is fresh.
    /// - Throws: ``IdentityError``, or `CancellationError`.
    public func signingKey(for did: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        try await resolveSigningKey(for: did, forceRefresh: forceRefresh).publicKey()
    }

    /// The key the issuer's DID document publishes under `keyID`, such as
    /// `#atproto_label` for a labeler's labeling key.
    ///
    /// - Parameters:
    ///   - did: The issuer's DID, without a fragment.
    ///   - keyID: The verification method fragment, with its `#`.
    ///   - forceRefresh: Fetch the DID document even when a cached copy is fresh.
    /// - Throws: ``IdentityError``, or `CancellationError`.
    public func signingKey(for did: String, keyID: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        let document = try await resolveDIDDocument(did, forceRefresh: forceRefresh)
        return try ATProtoJWTVerificationKey(document.verificationKey(withID: keyID)).publicKey()
    }
}
