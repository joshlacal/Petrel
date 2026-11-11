import Crypto
import Foundation

/// Injectable time. Every lifetime decision in the server reads the clock
/// through this protocol, so tests can advance time deterministically.
public protocol OAuthClock: Sendable {
    /// The current instant.
    func now() -> Date
}

/// The system wall clock.
public struct SystemOAuthClock: OAuthClock {
    /// Creates the system clock.
    public init() {}

    public func now() -> Date { Date() }
}

/// Derives the keyed digests under which opaque values are stored and
/// compared. A store never sees a raw code, token, `request_uri`, `jti` or
/// device identifier; it sees `HMAC-SHA256(secret, purpose || 0x00 || value)`.
struct OAuthKeyedDigest: Sendable {
    enum Purpose: String {
        case requestURI = "request-uri"
        case authorizationCode = "authorization-code"
        case accessToken = "access-token"
        case refreshToken = "refresh-token"
        case dpopProof = "dpop-jti"
        case clientAssertion = "client-assertion-jti"
        case codeChallenge = "code-challenge"
        case state
        case device
        case dpopNonce = "dpop-nonce"
        case browserFlow = "browser-flow"
    }

    private let secret: Data

    init(secret: Data) throws {
        guard secret.count >= 32 else {
            throw OAuthServerError.malformed("OAuth server secret must be at least 32 bytes")
        }
        self.secret = secret
    }

    func digest(_ value: String, purpose: Purpose) -> Data {
        digest(Data(value.utf8), purpose: purpose)
    }

    func digest(_ value: Data, purpose: Purpose) -> Data {
        var input = Data("petrel.oauth.\(purpose.rawValue)\u{0}".utf8)
        input.append(value)
        return Data(HMAC<SHA256>.authenticationCode(for: input, using: SymmetricKey(data: secret)))
    }
}
