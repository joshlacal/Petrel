import Crypto
import Foundation
import PetrelCrypto

/// The state of one pass through the authorization interface, carried in a
/// signed, short-lived cookie so the server keeps nothing per browser tab.
public struct OAuthBrowserFlow: Sendable, Equatable, Codable {
    /// The `request_uri` being approved.
    public let requestURI: String
    /// The CSRF token every form of this flow must echo.
    public let csrfToken: String
    /// The authenticated account, once sign-in or account selection succeeded.
    public var subject: String?
    /// When the browser proved it holds ``subject``: the sign-in time, or the
    /// remembered sign-in time of a selected account. An approval is refused
    /// when the account was revoked at or after this instant.
    public var authenticatedAt: Date?
    /// A second-factor challenge in progress.
    public var pendingSecondFactor: OAuthSecondFactorChallenge?
    /// When the flow was started.
    public let issuedAt: Date
    /// When the flow stops being usable.
    public let expiresAt: Date
}

/// Signs and verifies ``OAuthBrowserFlow`` cookie values with HMAC-SHA256
/// under the server secret.
///
/// The cookie is integrity-protected, not encrypted: it holds a `request_uri`
/// (useless without the browser flow it is bound to), a CSRF token and a DID.
public struct OAuthBrowserFlowService: Sendable {
    /// The longest a flow may stay open.
    public static let maximumLifetime: TimeInterval = 15 * 60

    private struct Payload: Codable {
        let v: Int
        let flow: OAuthBrowserFlow
    }

    private let digest: OAuthKeyedDigest
    private let random: any OAuthRandomSource

    /// Creates the service.
    public init(secret: Data, random: any OAuthRandomSource = SystemOAuthRandomSource()) throws {
        digest = try OAuthKeyedDigest(secret: secret)
        self.random = random
    }

    /// Starts a flow for a `request_uri`.
    public func begin(
        requestURI: String,
        lifetime: TimeInterval = 10 * 60,
        now: Date
    ) -> OAuthBrowserFlow {
        OAuthBrowserFlow(
            requestURI: requestURI,
            csrfToken: random.opaqueValue(),
            subject: nil,
            authenticatedAt: nil,
            pendingSecondFactor: nil,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(min(max(lifetime, 1), Self.maximumLifetime))
        )
    }

    /// Encodes and signs a flow as a cookie value.
    public func seal(_ flow: OAuthBrowserFlow) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        let payload: Data
        do {
            payload = try encoder.encode(Payload(v: 1, flow: flow))
        } catch {
            throw OAuthServerError.malformed("OAuth browser flow cannot be encoded")
        }
        return "\(JWTBase64URL.encode(payload)).\(JWTBase64URL.encode(digest.digest(payload, purpose: .browserFlow)))"
    }

    /// Verifies a cookie value and returns its flow.
    ///
    /// - Throws: ``OAuthServerError/unauthorized(_:)`` for every failure, with
    ///   one message, so the caller cannot tell a forged value from an expired
    ///   one.
    public func open(_ value: String, now: Date) throws -> OAuthBrowserFlow {
        let rejected = OAuthServerError.unauthorized("OAuth browser flow rejected")
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard value.utf8.count <= 8192, parts.count == 2,
              let payload = JWTBase64URLBridge.decode(String(parts[0]), maxBytes: 4096),
              let signature = JWTBase64URLBridge.decode(String(parts[1]), maxBytes: 32),
              ConstantTime.equal(signature, digest.digest(payload, purpose: .browserFlow))
        else {
            throw rejected
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decoded = try? decoder.decode(Payload.self, from: payload), decoded.v == 1 else {
            throw rejected
        }
        let flow = decoded.flow
        guard flow.expiresAt > now,
              flow.issuedAt <= now.addingTimeInterval(60),
              flow.expiresAt.timeIntervalSince(flow.issuedAt) <= Self.maximumLifetime + 1
        else {
            throw rejected
        }
        return flow
    }
}
