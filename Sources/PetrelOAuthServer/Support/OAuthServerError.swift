import Foundation

/// The failure vocabulary of the authorization-server core.
///
/// Every case carries a short, stable, operator-facing reason. The reason is
/// never derived from attacker-controlled input and is not meant for the wire:
/// endpoint handlers map each case to an RFC 6749 / RFC 9449 error code and do
/// not echo the associated text to the client.
public enum OAuthServerError: Error, Sendable, Equatable, CustomStringConvertible {
    /// A DID, NSID, client identifier or URL was not well formed.
    case invalidIdentifier(String)
    /// The caller presented a credential, proof or binding that does not
    /// authorize the operation.
    case unauthorized(String)
    /// A credential, proof or request outlived its validity window.
    case expired
    /// Input could not be parsed or violated a structural limit.
    case malformed(String)
    /// A dependency (store, resolver, remote document) could not answer. The
    /// request may be retried.
    case unavailable(String)

    public var description: String {
        switch self {
        case let .invalidIdentifier(value): "invalid identifier: \(value)"
        case let .unauthorized(value): "unauthorized: \(value)"
        case .expired: "credential or token expired"
        case let .malformed(value): "malformed input: \(value)"
        case let .unavailable(value): "unavailable: \(value)"
        }
    }
}
