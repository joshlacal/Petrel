import Foundation
import Petrel
import PetrelCrypto
import PetrelOAuthServer
import PetrelRepo

// Steps 5 and 6 of Lexicon resolution: from the authority DID to the PDS that
// hosts its repository and the key that signs it.

// MARK: - OAuthLexiconAuthority

/// What the DID document of a Lexicon authority says: where its repository is
/// served and which key signs its commits.
///
/// Both values come from the same DID document. The signing key is never taken
/// from the PDS or from the repository it serves.
public struct OAuthLexiconAuthority: Sendable, Equatable {
    /// The `#atproto_pds` service endpoint.
    public let pdsEndpoint: URL
    /// The `#atproto` verification method.
    public let signingKey: ATProtoPublicKey

    /// Creates an authority record.
    public init(pdsEndpoint: URL, signingKey: ATProtoPublicKey) {
        self.pdsEndpoint = pdsEndpoint
        self.signingKey = signingKey
    }
}

/// Why the DID document of a Lexicon authority could not be used.
public enum OAuthLexiconAuthorityError: Error, Sendable, Equatable {
    /// The DID document could not be fetched, or the DID is of a method the
    /// resolver does not accept.
    case documentUnavailable
    /// The DID document has no PDS endpoint or no `#atproto` signing key.
    case documentIncomplete
}

/// Resolves a Lexicon authority DID to its PDS and signing key (steps 5 and 6).
public protocol OAuthLexiconAuthorityResolving: Sendable {
    /// Resolves `did`.
    ///
    /// - Throws: ``OAuthLexiconAuthorityError`` when the document cannot be
    ///   used, `CancellationError` when cancelled. Any other error is reported
    ///   by ``AuthenticatedOAuthLexiconResolver`` as
    ///   ``OAuthLexiconResolverFailure/authorityDocumentUnavailable``.
    func resolveAuthority(did: String) async throws -> OAuthLexiconAuthority
}

// MARK: - IdentityResolver-backed authorities

/// Steps 5 and 6 through Petrel's `IdentityResolver`: `did:plc` and
/// hostname-level `did:web`, the document's `id` checked against the DID, and
/// the identity layer's cache.
public struct IdentityOAuthLexiconAuthorityResolver: OAuthLexiconAuthorityResolving {
    private let identity: IdentityResolver

    /// Creates the resolver.
    ///
    /// The identity resolver's HTTP transport fetches `did:web` documents from
    /// hosts the authority chooses. Give it a transport with the same
    /// protections as the rest of the server's outbound fetches, such as
    /// ``OAuthRemoteIdentityHTTPTransport``.
    public init(identity: IdentityResolver) {
        self.identity = identity
    }

    /// Resolves `did` to its PDS endpoint and `#atproto` signing key.
    ///
    /// - Throws: ``OAuthLexiconAuthorityError`` or `CancellationError`.
    public func resolveAuthority(did: String) async throws -> OAuthLexiconAuthority {
        let document: DIDDocument
        do {
            document = try await identity.resolveDIDDocument(did)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw OAuthLexiconAuthorityError.documentUnavailable
        }
        do {
            let endpoint = try document.serviceEndpoint(.pds)
            let key = try document.atprotoSigningKey().publicKey()
            return OAuthLexiconAuthority(pdsEndpoint: endpoint, signingKey: key)
        } catch {
            throw OAuthLexiconAuthorityError.documentIncomplete
        }
    }
}

/// An `IdentityHTTPTransport` that sends DID document requests through an
/// ``OAuthRemoteDocumentFetcher``.
///
/// A `did:web` document is served from a host its owner chooses, so fetching it
/// is the same server-side request forgery risk as fetching client metadata.
/// Routing it through the fetcher applies the same policy: HTTPS, public
/// addresses only, a pinned connection (unless the policy opts out), no
/// redirects, a JSON body within the size and time limits.
///
/// The fetcher accepts only an exact `200`; any other status, and any policy
/// refusal, is thrown rather than returned as a response, so the identity
/// resolver reports it as a transport failure.
public struct OAuthRemoteIdentityHTTPTransport: IdentityHTTPTransport {
    private let fetcher: OAuthRemoteDocumentFetcher

    /// Creates the transport.
    public init(fetcher: OAuthRemoteDocumentFetcher) {
        self.fetcher = fetcher
    }

    /// Fetches `request.url` as JSON.
    ///
    /// Redirects are never followed, whatever `request.followsRedirects` says;
    /// the response size is bounded by the smaller of the request's and the
    /// fetcher policy's limits.
    public func send(_ request: IdentityHTTPRequest) async throws -> IdentityHTTPResponse {
        let body = try await fetcher.fetchJSON(from: request.url)
        guard body.count <= request.maximumResponseBytes else {
            throw IdentityError.responseTooLarge(url: request.url.absoluteString)
        }
        return IdentityHTTPResponse(statusCode: 200, body: body)
    }
}

// MARK: - Commit verification

/// Verifies a repository commit signature under a key from a DID document, on
/// either curve. Strict: high-S and non-compact signatures are refused.
struct OAuthLexiconCommitVerifier: PublicRepositoryCommitVerifier {
    let publicKey: ATProtoPublicKey

    var signingAlgorithm: PublicRepositorySigningAlgorithm {
        switch publicKey.curve {
        case .p256: return .p256
        case .k256: return .secp256k1
        }
    }

    var verificationIdentity: String { publicKey.didKey }

    func verify(signature: Data, unsignedCommitBytes: Data, did _: String) async throws {
        guard publicKey.isValidSignature(signature, for: unsignedCommitBytes, options: .strict) else {
            throw PublicRepositoryCommitError.invalidSignature
        }
    }
}
