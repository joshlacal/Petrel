import Foundation
import PetrelCrypto

/// Server-issued DPoP nonces (RFC 9449 §8), rotating and stateless.
///
/// Time is divided into fixed intervals. The nonce for an interval is an HMAC
/// of the interval's index under the server secret, so any instance sharing
/// the secret issues and accepts the same values with no shared storage. A
/// nonce is accepted during its own interval and the one after it, and the
/// next interval's nonce is accepted early to absorb clock differences between
/// instances. With the default 60-second interval a nonce therefore lives for
/// at most three minutes, inside the profile's five-minute ceiling, and a
/// client holding the previous nonce is not forced through a retry by a
/// rotation that happened while its request was in flight.
public struct OAuthDPoPNonceService: Sendable {
    /// The longest rotation interval that keeps a nonce's total lifetime (three
    /// intervals) within the profile's five-minute maximum.
    public static let maximumRotationInterval: TimeInterval = 100

    private let digest: OAuthKeyedDigest
    private let rotationInterval: TimeInterval

    /// Creates a nonce service.
    ///
    /// - Parameters:
    ///   - secret: at least 32 bytes, shared by every instance that must accept
    ///     each other's nonces.
    ///   - rotationInterval: seconds between rotations, 1 through 100.
    public init(secret: Data, rotationInterval: TimeInterval = 60) throws {
        guard rotationInterval >= 1, rotationInterval <= Self.maximumRotationInterval, rotationInterval.isFinite else {
            throw OAuthServerError.malformed("DPoP nonce rotation interval is out of bounds")
        }
        digest = try OAuthKeyedDigest(secret: secret)
        self.rotationInterval = rotationInterval
    }

    /// The nonce to send in the `DPoP-Nonce` response header right now.
    public func current(now: Date = Date()) -> String {
        nonce(forInterval: interval(at: now))
    }

    /// True when `nonce` is the current nonce, the previous one, or the next.
    public func isValid(_ nonce: String, now: Date = Date()) -> Bool {
        let index = interval(at: now)
        var matched = false
        // Compare against all three without stopping early.
        for candidate in [index - 1, index, index + 1] {
            if ConstantTime.equal(self.nonce(forInterval: candidate), nonce) { matched = true }
        }
        return matched
    }

    private func interval(at date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 / rotationInterval).rounded(.down))
    }

    private func nonce(forInterval index: Int64) -> String {
        JWTBase64URL.encode(digest.digest(String(index), purpose: .dpopNonce))
    }
}
