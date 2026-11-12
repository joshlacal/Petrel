import Foundation

/// A confidential client's `private_key_jwt` assertion that passed every check.
public struct OAuthValidatedClientAssertion: Sendable, Equatable {
    /// The authenticated client.
    public let clientID: String
    /// The key the assertion was signed with, as a session binding.
    public let key: OAuthClientKeyBinding
    /// The assertion's `jti`.
    public let jwtID: String
    /// The assertion's `exp`.
    public let expiresAt: Date
}

/// Verifies `private_key_jwt` client authentication (RFC 7523) against the
/// JWKS bound to the client's validated metadata.
///
/// Checks: the assertion type; that the client is confidential; that the
/// header names exactly one published key by `kid` and embeds none; the
/// signature (either `s` encoding, since third-party JOSE signers do not
/// canonicalise it); `iss` = `sub` = `client_id`; `aud` contains this server's
/// issuer; `iat` present and `exp` present, no more than `maximumLifetime`
/// apart; and that the `jti` was not used before within its validity window.
public struct OAuthClientAssertionValidator: Sendable {
    /// The only accepted `client_assertion_type`.
    public static let assertionType = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"

    private let replayStore: any OAuthReplayStore
    private let digest: OAuthKeyedDigest
    private let maximumLifetime: TimeInterval
    private let clockSkew: TimeInterval

    /// Creates a validator.
    public init(
        secret: Data,
        replayStore: any OAuthReplayStore,
        maximumLifetime: TimeInterval = 300,
        clockSkew: TimeInterval = 60
    ) throws {
        guard maximumLifetime > 0, maximumLifetime <= 600, maximumLifetime.isFinite,
              clockSkew >= 0, clockSkew <= 120, clockSkew.isFinite
        else {
            throw OAuthServerError.malformed("client assertion validation lifetime is invalid")
        }
        digest = try OAuthKeyedDigest(secret: secret)
        self.replayStore = replayStore
        self.maximumLifetime = maximumLifetime
        self.clockSkew = clockSkew
    }

    /// Validates one assertion.
    ///
    /// - Throws: ``OAuthServerError/unauthorized(_:)`` (reported as
    ///   `invalid_client`) for every authentication failure, and
    ///   ``OAuthServerError/unavailable(_:)`` when the replay store cannot
    ///   answer.
    public func validate(
        _ assertion: String,
        assertionType: String,
        client: OAuthResolvedClientMetadata,
        authorizationServerIssuer: String,
        now: Date = Date()
    ) async throws -> OAuthValidatedClientAssertion {
        guard assertionType == Self.assertionType,
              client.metadata.tokenEndpointAuthMethod == .privateKeyJWT,
              let keySet = client.keySet
        else {
            throw OAuthServerError.unauthorized("client assertion authentication is invalid")
        }
        let clientID = client.metadata.clientID.absoluteString
        let verified: OAuthVerifiedJWT
        let key: OAuthJSONWebKey
        let keyID: String
        do {
            let header = try OAuthCompactJWT.unverifiedHeader(assertion)
            guard header.jwk == nil, let named = header.keyID else {
                throw OAuthServerError.unauthorized("client assertion must identify one metadata key")
            }
            keyID = named
            key = try keySet.select(keyID: keyID)
            if let declared = client.metadata.tokenEndpointAuthSigningAlgorithm {
                guard declared == header.algorithm else {
                    throw OAuthServerError.unauthorized("client assertion algorithm is not the declared one")
                }
            }
            verified = try OAuthCompactJWT.verify(
                assertion,
                key: key,
                signatureEncoding: .joseInteroperable,
                constraints: .init(
                    expectedIssuer: clientID,
                    expectedAudience: authorizationServerIssuer,
                    now: now,
                    clockSkew: clockSkew,
                    requireIssuedAt: true,
                    requireExpiration: true,
                    maxLifetime: maximumLifetime,
                    maximumAge: maximumLifetime
                )
            )
        } catch let error as OAuthServerError {
            // The reasons are fixed strings about the client's own assertion,
            // so they are safe to report and far more useful than "invalid".
            switch error {
            case .unavailable: throw error
            case .expired: throw OAuthServerError.unauthorized("client assertion has expired")
            case let .unauthorized(reason), let .malformed(reason), let .invalidIdentifier(reason):
                throw OAuthServerError.unauthorized(reason.replacingOccurrences(of: "JWT", with: "client assertion"))
            }
        }
        guard verified.registeredClaims.subject == clientID,
              let jwtID = verified.registeredClaims.jwtID,
              !jwtID.isEmpty, jwtID.utf8.count <= 512, jwtID.utf8.allSatisfy({ $0 >= 0x20 && $0 != 0x7F }),
              let expiry = verified.registeredClaims.expiresAt
        else {
            throw OAuthServerError.unauthorized("client assertion claims are invalid")
        }
        let expiresAt = Date(timeIntervalSince1970: TimeInterval(expiry))
        let claimed: Bool
        do {
            claimed = try await replayStore.claim(
                namespace: .clientAssertion,
                digest: digest.digest("\(clientID)\u{0}\(jwtID)", purpose: .clientAssertion),
                expiresAt: expiresAt.addingTimeInterval(clockSkew),
                now: now
            )
        } catch {
            throw OAuthServerError.unavailable("client assertion replay store is unavailable")
        }
        guard claimed else {
            throw OAuthServerError.unauthorized("client assertion was replayed")
        }
        return OAuthValidatedClientAssertion(
            clientID: clientID,
            key: OAuthClientKeyBinding(
                keyID: keyID,
                algorithm: verified.header.algorithm,
                thumbprint: key.thumbprint()
            ),
            jwtID: jwtID,
            expiresAt: expiresAt
        )
    }
}
