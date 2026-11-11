import Foundation

/// An account as the authorization interface shows it.
public struct OAuthAccount: Sendable, Equatable, Hashable, Codable {
    /// The account's DID. This is the `sub` of every token.
    public let did: String
    /// The account's handle, for display.
    public let handle: String?
    /// A display name, for display.
    public let displayName: String?

    /// Creates an account description.
    public init(did: String, handle: String? = nil, displayName: String? = nil) {
        self.did = did
        self.handle = handle
        self.displayName = displayName
    }
}

/// What the authenticator knows about a sign-in attempt, for rate limiting and
/// audit. None of it is an authorization input.
public struct OAuthSignInContext: Sendable, Equatable {
    /// The client the user is signing in to authorize.
    public let clientID: String
    /// The browser's network address, when the host supplied it.
    public let remoteAddress: String?

    /// Creates a context.
    public init(clientID: String, remoteAddress: String? = nil) {
        self.clientID = clientID
        self.remoteAddress = remoteAddress
    }
}

/// A pending second authentication step.
public struct OAuthSecondFactorChallenge: Sendable, Equatable, Codable {
    /// The DID of the account whose first factor succeeded.
    public let subject: String
    /// What to ask the user for, for example "Enter the 6-digit code from your
    /// authenticator app".
    public let prompt: String

    /// Creates a challenge.
    public init(subject: String, prompt: String) {
        self.subject = subject
        self.prompt = prompt
    }
}

/// The outcome of an authentication step.
public enum OAuthSignInResult: Sendable, Equatable {
    /// The user is authenticated as this account.
    case authenticated(OAuthAccount)
    /// The first factor was accepted and a second is required.
    case secondFactorRequired(OAuthSecondFactorChallenge)
    /// The credentials were not accepted. The interface shows one generic
    /// message, so this case deliberately carries no reason.
    case rejected
}

/// The host application's account system.
///
/// The authorization server owns the OAuth protocol and nothing about
/// accounts: how passwords are stored and checked, whether a second factor
/// exists, and what makes an account usable are all the host's. A PDS
/// implements this on its account database.
public protocol OAuthAccountAuthenticating: Sendable {
    /// Checks a handle-or-DID and password.
    ///
    /// Implementations are responsible for their own attempt limiting; the
    /// context carries the client and network address for that purpose.
    func signIn(identifier: String, password: String, context: OAuthSignInContext) async throws -> OAuthSignInResult

    /// Completes a second-factor challenge issued by ``signIn(identifier:password:context:)``.
    func verifySecondFactor(
        _ challenge: OAuthSecondFactorChallenge,
        code: String,
        context: OAuthSignInContext
    ) async throws -> OAuthSignInResult

    /// The account for a DID, or `nil` when it does not exist or may no longer
    /// be used (deleted, deactivated, taken down). Consulted before every code
    /// and every token is issued, so a disabled account stops refreshing.
    func account(did: String) async throws -> OAuthAccount?

    /// Resolves a client's `login_hint` (a handle or a DID) to an account DID
    /// on this server, or `nil` when it names no local account.
    func resolveLoginHint(_ hint: String) async throws -> String?
}

public extension OAuthAccountAuthenticating {
    /// Hosts without a second factor never issue a challenge, so completing
    /// one is always a rejection.
    func verifySecondFactor(
        _: OAuthSecondFactorChallenge,
        code _: String,
        context _: OAuthSignInContext
    ) async throws -> OAuthSignInResult {
        .rejected
    }

    /// By default a hint is honoured only when it is the DID of a local
    /// account.
    func resolveLoginHint(_ hint: String) async throws -> String? {
        guard hint.hasPrefix("did:") else { return nil }
        return try await account(did: hint)?.did
    }
}
