import Crypto
import Foundation
import PetrelCrypto

/// Unpadded base64url, forwarded to `PetrelCrypto` so there is one codec.
enum JWTBase64URLBridge {
    static func encode(_ data: Data) -> String { JWTBase64URL.encode(data) }

    static func decode(_ value: String, maxBytes: Int = 16384) -> Data? {
        try? JWTBase64URL.decode(value, maxBytes: maxBytes)
    }
}

/// Comparison that does not return early on the first differing byte, for
/// values an attacker can probe.
enum ConstantTime {
    static func equal(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }

    static func equal(_ lhs: String, _ rhs: String) -> Bool {
        equal(Data(lhs.utf8), Data(rhs.utf8))
    }
}

/// Injectable randomness for opaque values (codes, tokens, request URIs,
/// CSRF secrets). The default draws from the system CSPRNG; tests substitute a
/// deterministic source.
public protocol OAuthRandomSource: Sendable {
    /// Returns `count` unpredictable bytes.
    func bytes(count: Int) -> Data
}

/// The system cryptographically secure random number generator.
public struct SystemOAuthRandomSource: OAuthRandomSource {
    /// Creates the system source.
    public init() {}

    public func bytes(count: Int) -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0 ..< count).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }
}

extension OAuthRandomSource {
    /// 32 random bytes as 43 characters of base64url.
    func opaqueValue() -> String {
        JWTBase64URL.encode(bytes(count: 32))
    }
}

/// PKCE (RFC 7636) with the only transform the AT Protocol profile permits.
public enum OAuthPKCE {
    /// True when `challenge` is the S256 transform of `verifier`.
    public static func verifyS256(verifier: String, challenge: String) -> Bool {
        ConstantTime.equal(s256Challenge(for: verifier), challenge)
    }

    /// `BASE64URL(SHA256(verifier))`.
    public static func s256Challenge(for verifier: String) -> String {
        JWTBase64URL.encode(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// RFC 7636 §4.1: 43–128 characters from the unreserved set.
    public static func isValidVerifier(_ value: String) -> Bool {
        (43 ... 128).contains(value.utf8.count) && value.utf8.allSatisfy { byte in
            (0x30 ... 0x39).contains(byte) || (0x41 ... 0x5A).contains(byte) || (0x61 ... 0x7A).contains(byte)
                || byte == 0x2D || byte == 0x2E || byte == 0x5F || byte == 0x7E
        }
    }

    /// A S256 challenge is exactly 43 characters of unpadded base64url.
    public static func isValidS256Challenge(_ value: String) -> Bool {
        guard value.utf8.count == 43, let decoded = JWTBase64URLBridge.decode(value, maxBytes: 32) else {
            return false
        }
        return decoded.count == 32
    }
}
