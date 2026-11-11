//
//  IdentityError.swift
//  Petrel
//

import Foundation

/// Why a handle or DID could not be resolved.
///
/// The DID cases keep apart the three outcomes the DID specification asks implementations to
/// distinguish: invalid syntax (``invalidDIDSyntax(_:)``), an unsupported method
/// (``unsupportedDIDMethod(did:method:)``), and a supported method whose resolution failed
/// (every other DID case). Task cancellation is never wrapped: a cancelled resolution throws
/// `CancellationError`.
public enum IdentityError: Error, Sendable, Equatable {
    // MARK: DID

    /// The string is not a syntactically valid DID.
    case invalidDIDSyntax(String)
    /// The DID is well formed but its method is not `plc` or `web`.
    case unsupportedDIDMethod(did: String, method: String)
    /// The `did:web` DID has a path, which AT Protocol does not support.
    case unsupportedDIDWebPath(String)
    /// The `did:web` DID breaks an AT Protocol rule: a bad hostname, a reserved top-level
    /// domain, a port on a host other than `localhost`, or a development host outside
    /// development mode.
    case invalidDIDWeb(did: String, reason: DIDWebIdentifier.ValidationError)
    /// The directory or host answered that no such DID exists (HTTP 404).
    case didNotFound(String)
    /// The PLC directory answered that the DID was deactivated (HTTP 410).
    case didTombstoned(String)
    /// The resolved document's `id` is not the DID that was asked for.
    case documentIDMismatch(expected: String, actual: String)
    /// The response was not a usable DID document.
    case invalidDIDDocument(did: String, reason: String)
    /// The document has no valid `#atproto` signing key.
    case missingSigningKey(did: String)
    /// The document has no verification method with this fragment that decodes to a key.
    case missingVerificationMethod(did: String, id: String)
    /// The document has no service with this fragment (and type, if one was required).
    case missingService(did: String, id: String)
    /// The matching service's `serviceEndpoint` is not an `https` origin (or a loopback `http`
    /// origin) without user info, path, query or fragment.
    case invalidServiceEndpoint(did: String, id: String)

    // MARK: Handle

    /// The string is not a syntactically valid handle.
    case invalidHandleSyntax(String)
    /// The handle ends in a reserved top-level domain and must fail resolution without any
    /// network request.
    case reservedHandleTLD(String)
    /// Neither the DNS TXT record nor the HTTPS well-known endpoint names a DID.
    case handleNotFound(String)
    /// The methods disagree: several `did=` TXT records with different DIDs, or (under
    /// ``HandleConflictPolicy/reject``) a DNS result that differs from the HTTPS result.
    case handleAmbiguous(handle: String, dids: [String])
    /// The handle names a DID whose document does not claim the handle back.
    case handleNotClaimedByDID(handle: String, did: String)
    /// No DID was found and at least one lookup method failed in transit, so the handle may
    /// still exist.
    case handleLookupFailed(handle: String, reason: String)

    // MARK: Transport

    /// The host answered with a status that is neither success nor "not found".
    case unexpectedStatus(url: String, statusCode: Int)
    /// The response was larger than the configured limit.
    case responseTooLarge(url: String)
    /// The request did not finish within ``IdentityResolver/Options/timeout``.
    case timedOut(String)
    /// The URL failed the network policy: a cleartext scheme for a remote host, or a host that
    /// resolves to a private, loopback or reserved address.
    case blockedByNetworkPolicy(url: String)
    /// Any other transport failure.
    case transport(url: String, reason: String)
}

extension IdentityError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidDIDSyntax(did):
            return "'\(did)' is not a valid DID."
        case let .unsupportedDIDMethod(did, method):
            return "The DID method '\(method)' of '\(did)' is not supported; AT Protocol supports did:plc and did:web."
        case let .unsupportedDIDWebPath(did):
            return "'\(did)' is a path-based did:web, which AT Protocol does not support."
        case let .invalidDIDWeb(did, reason):
            return "'\(did)' is not an acceptable did:web (\(reason))."
        case let .didNotFound(did):
            return "No DID document exists for '\(did)'."
        case let .didTombstoned(did):
            return "'\(did)' has been deactivated in the PLC directory."
        case let .documentIDMismatch(expected, actual):
            return "The DID document for '\(expected)' declares the id '\(actual)'."
        case let .invalidDIDDocument(did, reason):
            return "The DID document for '\(did)' could not be read: \(reason)"
        case let .missingSigningKey(did):
            return "The DID document for '\(did)' has no valid #atproto signing key."
        case let .missingVerificationMethod(did, id):
            return "The DID document for '\(did)' has no valid verification method '\(id)'."
        case let .missingService(did, id):
            return "The DID document for '\(did)' has no service '\(id)'."
        case let .invalidServiceEndpoint(did, id):
            return "The service '\(id)' of '\(did)' does not have a valid endpoint URL."
        case let .invalidHandleSyntax(handle):
            return "'\(handle)' is not a valid handle."
        case let .reservedHandleTLD(handle):
            return "'\(handle)' uses a reserved top-level domain and cannot be resolved."
        case let .handleNotFound(handle):
            return "The handle '\(handle)' does not resolve to a DID."
        case let .handleAmbiguous(handle, dids):
            return "The handle '\(handle)' resolves to conflicting DIDs: \(dids.joined(separator: ", "))."
        case let .handleNotClaimedByDID(handle, did):
            return "The handle '\(handle)' points at '\(did)', whose DID document does not claim it."
        case let .handleLookupFailed(handle, reason):
            return "The handle '\(handle)' could not be looked up: \(reason)"
        case let .unexpectedStatus(url, statusCode):
            return "\(url) answered with HTTP status \(statusCode)."
        case let .responseTooLarge(url):
            return "The response from \(url) exceeded the size limit."
        case let .timedOut(what):
            return "Timed out: \(what)."
        case let .blockedByNetworkPolicy(url):
            return "\(url) was blocked by the network policy."
        case let .transport(url, reason):
            return "The request to \(url) failed: \(reason)"
        }
    }
}
