import Foundation

/// Every failure `PetrelPLC` reports.
///
/// The cases separate *what the directory said* (``notFound(did:)``,
/// ``tombstoned(did:)``, ``rejected(status:message:)``,
/// ``rateLimited(retryAfterSeconds:)``) from *what Petrel concluded*
/// (``malformed(_:)`` for input that is not a well-formed operation or
/// response, ``unauthorized(_:)`` for a signature, CID or chain that does not
/// verify) and from transport trouble (``unavailable(_:)``).
public enum PetrelPLCError: Error, Sendable, Equatable, CustomStringConvertible {
    /// A DID, handle or CID is not syntactically valid.
    case invalidIdentifier(String)
    /// A value does not fit the AT Protocol profile of a PLC operation.
    case invalidProfile(String)
    /// A signature, CID, genesis hash or operation chain does not verify.
    case unauthorized(String)
    /// Not produced by `PetrelPLC`; kept for source compatibility.
    case conflict(expected: UInt64, actual: UInt64)
    /// Not produced by `PetrelPLC`; kept for source compatibility.
    case expired
    /// Input is not a well-formed operation, log or directory response, or an
    /// operation breaks a rule that applies when writing.
    case malformed(String)
    /// The directory could not be reached, answered with a server error, or
    /// sent a response larger than the configured bound.
    case unavailable(String)
    /// The directory has no operations for this DID (`404`,
    /// "DID not registered").
    case notFound(did: String)
    /// The DID exists but its current operation is a tombstone (`410`, or the
    /// reference server's `404` "DID not available").
    case tombstoned(did: String)
    /// The directory refused the request with a `4xx` status. `message` is
    /// the directory's own explanation, empty when it gave none.
    case rejected(status: Int, message: String)
    /// The directory answered `429`. `retryAfterSeconds` is its `Retry-After`
    /// header when that was a whole number of seconds.
    case rateLimited(retryAfterSeconds: Int?)
    /// The directory answered a submit with a success status, but the
    /// operation could not then be confirmed in the audit log because the
    /// confirming read failed. The operation may well be registered: do not
    /// resubmit blindly; read the audit log and look for `cid`.
    case submittedButUnconfirmed(cid: String, reason: String)

    /// A one-line description of the failure.
    public var description: String {
        switch self {
        case let .invalidIdentifier(value): "invalid identifier: \(value)"
        case let .invalidProfile(value): "invalid protocol profile: \(value)"
        case let .unauthorized(value): "unauthorized: \(value)"
        case .conflict: "repository revision conflict"
        case .expired: "credential or token expired"
        case let .malformed(value): "malformed input: \(value)"
        case let .unavailable(value): "unavailable: \(value)"
        case let .notFound(did): "DID not registered: \(did)"
        case let .tombstoned(did): "DID is tombstoned: \(did)"
        case let .rejected(status, message):
            message.isEmpty
                ? "PLC directory rejected the request (HTTP \(status))"
                : "PLC directory rejected the request (HTTP \(status)): \(message)"
        case let .rateLimited(retryAfter):
            retryAfter.map { "PLC directory rate limit reached; retry after \($0) s" }
                ?? "PLC directory rate limit reached"
        case let .submittedButUnconfirmed(cid, reason):
            "PLC directory accepted operation \(cid) but it could not be confirmed: \(reason)"
        }
    }
}

/// Short spelling of ``PetrelPLCError``.
public typealias PLCError = PetrelPLCError
