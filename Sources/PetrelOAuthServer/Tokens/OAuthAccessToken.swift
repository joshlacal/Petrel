import Foundation

/// How access tokens are represented.
///
/// The profile treats access tokens as opaque to clients, so the choice is
/// between the authorization server and its resource servers.
public enum OAuthAccessTokenFormat: Sendable {
    /// A random 256-bit value. Validating it requires the session store, which
    /// suits a PDS that is its own authorization server, and makes every
    /// access token individually revocable.
    case opaque
    /// A signed JWT (`typ: at+jwt`, RFC 9068) carrying `iss`, `aud`, `sub`,
    /// `client_id`, `scope`, `cnf.jkt`, `iat`, `exp` and `jti`. A resource
    /// server on another host can verify it with the authorization server's
    /// public key alone; one that shares the session store also sees
    /// revocation immediately.
    case signedJWT(OAuthSigningKey)
}

/// The claims of a signed access token.
public struct OAuthAccessTokenClaims: Codable, Sendable, Equatable {
    /// The confirmation claim binding the token to a DPoP key (RFC 9449 §6.1).
    public struct Confirmation: Codable, Sendable, Equatable {
        /// The RFC 7638 thumbprint of the DPoP public key.
        public let jkt: String

        /// Creates a confirmation claim.
        public init(jkt: String) {
            self.jkt = jkt
        }
    }

    /// The authorization server's issuer identifier.
    public let iss: String
    /// The resource server the token is for.
    public let aud: String
    /// The account DID.
    public let sub: String
    /// The client the token was issued to.
    public let clientID: String
    /// The effective grant, space-delimited.
    public let scope: String
    /// The DPoP key binding.
    public let cnf: Confirmation
    /// Issued-at, seconds since the epoch.
    public let iat: Int64
    /// Expiry, seconds since the epoch.
    public let exp: Int64
    /// A unique token identifier.
    public let jti: String

    private enum CodingKeys: String, CodingKey {
        case iss, aud, sub
        case clientID = "client_id"
        case scope, cnf, iat, exp, jti
    }

    /// Creates a claim set.
    public init(
        iss: String,
        aud: String,
        sub: String,
        clientID: String,
        scope: String,
        cnf: Confirmation,
        iat: Int64,
        exp: Int64,
        jti: String
    ) {
        self.iss = iss
        self.aud = aud
        self.sub = sub
        self.clientID = clientID
        self.scope = scope
        self.cnf = cnf
        self.iat = iat
        self.exp = exp
        self.jti = jti
    }
}

/// The JSON body of a successful token response (RFC 6749 §5.1 plus the
/// profile's mandatory `sub`).
public struct OAuthTokenResponse: Codable, Sendable, Equatable {
    /// The access token.
    public let accessToken: String
    /// Always `DPoP`.
    public let tokenType: String
    /// Seconds until the access token expires.
    public let expiresIn: Int
    /// The refresh token, when the client declared the `refresh_token` grant.
    public let refreshToken: String?
    /// The scopes of the session, exactly as the client requested them.
    public let scope: String
    /// The account DID. Clients must verify this against the identity they
    /// expected.
    public let sub: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope, sub
    }
}

enum OAuthAccessTokenType {
    static let jwtType = "at+jwt"
}
