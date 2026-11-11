import Foundation

/// Why a request's service authentication was refused.
///
/// Every case maps to the error name the TypeScript reference
/// implementation puts in its XRPC error body (``xrpcErrorName``), so a
/// Swift service can answer a bad token the same way the reference does:
///
/// ```swift
/// do {
///     let caller = try await verifier.verify(authorizationHeader: header, method: .exactly(nsid))
/// } catch {
///     // HTTP 401, {"error": error.xrpcErrorName, "message": error.message}
/// }
/// ```
public enum ServiceAuthError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The request has no `Authorization` header.
    case missingAuthorization
    /// The `Authorization` header is not `Bearer <token>`.
    case unsupportedAuthorizationScheme
    /// The token is not a well-formed compact JWS with the required claims.
    /// The associated value says what was wrong.
    case malformedToken(String)
    /// The header `typ` marks the token as something other than a service
    /// token: an OAuth access token (`at+jwt`), a refresh token
    /// (`refresh+jwt`) or a DPoP proof (`dpop+jwt`).
    case disallowedTokenType(String)
    /// `exp` is in the past, beyond the allowed clock skew.
    case expired
    /// `exp` is further in the future than the verifier's lifetime ceiling,
    /// or `exp - iat` exceeds it.
    case excessiveLifetime(maximum: TimeInterval)
    /// `aud` does not name this service.
    case audienceMismatch(actual: String)
    /// `lxm` is missing or is not the method being called.
    case lexiconMethodMismatch(expected: String?, actual: String?)
    /// `iss` is not a DID (optionally followed by `#fragment`).
    case invalidIssuer(String)
    /// The token names a signing key (`kid`) this service does not accept.
    case keyNotAccepted(keyID: String)
    /// The header `alg` is not `ES256` or `ES256K`.
    case unsupportedAlgorithm(String)
    /// The issuer's signing key could not be resolved.
    case keyResolutionFailed(did: String, keyID: String, reason: String)
    /// The signature does not verify against the issuer's key, even after
    /// refreshing it.
    case invalidSignature
    /// A claim the verifier is configured to require is absent.
    case missingClaim(String)
    /// The token's `jti` was already used.
    case replayed
    /// The replay store failed, so the token could not be checked for reuse.
    case replayStoreFailed(String)

    /// The XRPC error name the reference implementation uses for this
    /// failure: `BadJwt`, `BadJwtType`, `JwtExpired`, `BadJwtAudience`,
    /// `BadJwtLexiconMethod`, `BadJwtIss`, `BadJwtSignature` or `MissingJwt`.
    ///
    /// Conditions the reference does not check (lifetime ceiling, `kid`
    /// allow-list, replay, required claims) report `BadJwt`.
    public var xrpcErrorName: String {
        switch self {
        case .missingAuthorization, .unsupportedAuthorizationScheme:
            return "MissingJwt"
        case .malformedToken, .excessiveLifetime, .keyNotAccepted, .missingClaim, .replayed, .replayStoreFailed:
            return "BadJwt"
        case .disallowedTokenType:
            return "BadJwtType"
        case .expired:
            return "JwtExpired"
        case .audienceMismatch:
            return "BadJwtAudience"
        case .lexiconMethodMismatch:
            return "BadJwtLexiconMethod"
        case .invalidIssuer:
            return "BadJwtIss"
        case .unsupportedAlgorithm, .keyResolutionFailed, .invalidSignature:
            return "BadJwtSignature"
        }
    }

    /// The HTTP status to answer with. Always 401: every case is an
    /// authentication failure.
    public var httpStatus: Int { 401 }

    /// A human-readable message suitable for the XRPC error body. It never
    /// contains the token or key material.
    public var message: String {
        switch self {
        case .missingAuthorization:
            return "missing jwt"
        case .unsupportedAuthorizationScheme:
            return "authorization header is not a bearer token"
        case let .malformedToken(detail):
            return "poorly formatted jwt: \(detail)"
        case let .disallowedTokenType(type):
            return "invalid jwt type \"\(type)\""
        case .expired:
            return "jwt expired"
        case let .excessiveLifetime(maximum):
            return "jwt lifetime exceeds \(Int(maximum)) seconds"
        case .audienceMismatch:
            return "jwt audience does not match service did"
        case let .lexiconMethodMismatch(expected, actual):
            let wanted = expected.map { " must match: \($0)" } ?? ""
            return actual == nil
                ? "missing jwt lexicon method (\"lxm\").\(wanted)"
                : "bad jwt lexicon method (\"lxm\").\(wanted)"
        case .invalidIssuer:
            return "jwt iss is not a valid did"
        case let .keyNotAccepted(keyID):
            return "jwt signing key \(keyID) is not accepted by this service"
        case let .unsupportedAlgorithm(algorithm):
            return "unsupported jwt algorithm \"\(algorithm)\""
        case let .keyResolutionFailed(did, keyID, reason):
            return "could not resolve signing key \(keyID) of \(did): \(reason)"
        case .invalidSignature:
            return "jwt signature does not match jwt issuer"
        case let .missingClaim(name):
            return "jwt is missing required claim \"\(name)\""
        case .replayed:
            return "jwt was already used"
        case let .replayStoreFailed(reason):
            return "could not check jwt for reuse: \(reason)"
        }
    }

    /// ``xrpcErrorName`` and ``message``, joined.
    public var description: String { "\(xrpcErrorName): \(message)" }
}
