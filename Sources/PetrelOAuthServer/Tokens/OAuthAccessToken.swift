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

    /// The longest access token, in bytes, that ``OAuthResourceServerVerifier``
    /// accepts and that this server issues. 8 KiB is also the usual limit on
    /// a request header line in HTTP servers and proxies.
    public static let maximumSignedTokenBytes = 8192

    /// The longest effective grant, in bytes of its space-separated `scope`
    /// claim, that a ``signedJWT(_:)`` server admits at the pushed
    /// authorization request.
    ///
    /// A signed token carries its scopes, base64url-encoded (4/3 larger), next
    /// to the other claims, header and signature. 4 KiB of scopes leaves about
    /// 1.6 KiB for the rest within ``maximumSignedTokenBytes``. A grant over
    /// this is refused with `invalid_scope` before the user is asked; a token
    /// that still comes out too long (for example from an unusually long
    /// `client_id` or DID) is refused at issue. At refresh, a re-derived
    /// grant over the budget leaves the session on the grant it already has.
    /// Opaque tokens carry no scopes and have no such limit.
    public static let signedTokenScopeBudget = 4096

    /// Whether `scopes` fit in a token of this format.
    func admits(grant scopes: Set<String>) -> Bool {
        guard case .signedJWT = self else { return true }
        // The claim joins the scopes with single spaces.
        let bytes = scopes.reduce(0) { $0 + $1.utf8.count } + max(0, scopes.count - 1)
        return bytes <= Self.signedTokenScopeBudget
    }
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
