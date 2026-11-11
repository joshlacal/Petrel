//
//  AccountStatus.swift
//  Petrel
//
//  Account hosting status ("Hosting Status" in the atproto Account
//  specification) as the session layer reports it.
//

import Foundation

/// The hosting status of an account at a service, as carried by the `active`
/// flag and `status` string of `com.atproto.server.getSession`,
/// `com.atproto.sync.getRepoStatus` and the `#account` event.
///
/// `isActive` governs behaviour: an inactive account's content must not be
/// shown or redistributed. `reason` only clarifies why. The two are separate
/// because the specification allows some reasons (`desynchronized`,
/// `throttled`) alongside `active: true`, and allows new reasons to appear at
/// any time — an unrecognised one is preserved in ``Reason/other(_:)`` rather
/// than rejected.
public struct AccountStatus: Sendable, Hashable, CustomStringConvertible {
    /// The specific state reported in the `status` string.
    public enum Reason: Sendable, Hashable {
        /// The host or a service has taken the account down. Long-term.
        case takendown
        /// The host or a service has temporarily paused the account.
        case suspended
        /// The user or host deleted the account.
        case deleted
        /// The user paused the account; also the state after migrating away.
        case deactivated
        /// The host detected a repository synchronisation problem. May be active.
        case desynchronized
        /// The host paused processing because a rate limit was exceeded. May be active.
        case throttled
        /// A status string this version of Petrel does not know.
        case other(String)

        /// Interprets a `status` string.
        public init(_ status: String) {
            switch status {
            case "takendown": self = .takendown
            case "suspended": self = .suspended
            case "deleted": self = .deleted
            case "deactivated": self = .deactivated
            case "desynchronized": self = .desynchronized
            case "throttled": self = .throttled
            default: self = .other(status)
            }
        }

        /// The wire `status` string.
        public var rawValue: String {
            switch self {
            case .takendown: "takendown"
            case .suspended: "suspended"
            case .deleted: "deleted"
            case .deactivated: "deactivated"
            case .desynchronized: "desynchronized"
            case .throttled: "throttled"
            case let .other(status): status
            }
        }
    }

    /// Whether the account is active at the service that reported the status.
    public let isActive: Bool

    /// Why the account is in this state, when the service said.
    public let reason: Reason?

    /// An active account with no qualifying status.
    public static let active = AccountStatus(isActive: true, reason: nil)

    /// Creates a status.
    public init(isActive: Bool, reason: Reason?) {
        self.isActive = isActive
        self.reason = reason
    }

    /// Interprets the `active` / `status` pair of an API response or event.
    /// - Parameters:
    ///   - active: The `active` flag. Endpoints that predate the flag omit it;
    ///     an omitted flag means active.
    ///   - status: The `status` string, if any.
    public init(active: Bool?, status: String?) {
        self.init(isActive: active ?? true, reason: status.map(Reason.init))
    }

    public var description: String {
        let state = isActive ? "active" : "inactive"
        return reason.map { "\(state) (\($0.rawValue))" } ?? state
    }
}

/// A server refused a request because of the account's hosting status — it
/// has been taken down, suspended or deactivated — rather than because of its
/// credentials. Signing in again does not help; the session is left in place
/// so the app can explain the state or let the user reactivate.
public struct AccountStatusError: Error, LocalizedError, Equatable, Sendable {
    /// The status the server reported.
    public let status: AccountStatus

    /// The server's own explanation, if it gave one.
    public let message: String?

    /// Creates an account status error.
    public init(status: AccountStatus, message: String? = nil) {
        self.status = status
        self.message = message
    }

    /// Recognises the XRPC error names servers use for status refusals.
    /// - Returns: `nil` when `name` is not an account-status error.
    public init?(xrpcErrorName name: String, message: String? = nil) {
        let reason: AccountStatus.Reason
        switch name {
        case "AccountTakedown": reason = .takendown
        case "AccountSuspended": reason = .suspended
        case "AccountDeactivated": reason = .deactivated
        case "AccountDeleted": reason = .deleted
        default: return nil
        }
        self.init(status: AccountStatus(isActive: false, reason: reason), message: message)
    }

    /// Recognises a status refusal in an XRPC error response body.
    init?(xrpcErrorBody data: Data) {
        guard let body = try? JSONDecoder().decode(XRPCErrorBody.self, from: data) else { return nil }
        self.init(xrpcErrorName: body.error, message: body.message)
    }

    public var errorDescription: String? {
        switch status.reason {
        case .takendown: "This account has been taken down."
        case .suspended: "This account has been suspended."
        case .deactivated: "This account is deactivated."
        case .deleted: "This account has been deleted."
        default: "This account is not active."
        }
    }

    public var failureReason: String? {
        message
    }
}

/// The server requires a second factor to sign in with a password: it has
/// emailed the account a confirmation code. Ask the user for it and sign in
/// again, passing it as the auth-factor token.
public struct AuthFactorTokenRequiredError: Error, LocalizedError, Equatable, Sendable {
    /// Creates the error.
    public init() {}

    public var errorDescription: String? {
        "A sign-in code was emailed to this account. Enter it to finish signing in."
    }
}

/// The `{error, message}` body of a failed XRPC request.
struct XRPCErrorBody: Decodable {
    let error: String
    let message: String?
}
