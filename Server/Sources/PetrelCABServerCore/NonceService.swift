#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation

extension Data {
  public func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

/// Stateless server nonces: `<unix-ts>.<HMAC-SHA256(ts)>`. No storage —
/// any instance holding the secret can validate. With no configured secret
/// a random one is generated at startup (nonces then die with the process,
/// which is fine: clients transparently retry on the next challenge).
public struct NonceService: Sendable {
  private let secret: SymmetricKey
  private let validity: TimeInterval

  public init(secretBase64: String?, validity: TimeInterval = 300) {
    if let secretBase64, let data = Data(base64Encoded: secretBase64), !data.isEmpty {
      secret = SymmetricKey(data: data)
    } else {
      secret = SymmetricKey(size: .bits256)
    }
    self.validity = validity
  }

  public func issue(now: Date = Date()) -> String {
    let timestamp = String(Int(now.timeIntervalSince1970))
    return "\(timestamp).\(mac(timestamp))"
  }

  public func isValid(_ nonce: String, now: Date = Date()) -> Bool {
    let parts = nonce.split(separator: ".", maxSplits: 1)
    guard parts.count == 2, let timestamp = Int(parts[0]) else { return false }
    guard abs(now.timeIntervalSince1970 - TimeInterval(timestamp)) <= validity else {
      return false
    }
    guard let submittedMAC = Self.decodeBase64URL(String(parts[1])) else { return false }
    // MAC verification must be constant-time to avoid a timing oracle,
    // even though the nonce value itself isn't a secret.
    return HMAC<SHA256>.isValidAuthenticationCode(
      submittedMAC, authenticating: Data(String(parts[0]).utf8), using: secret
    )
  }

  private func mac(_ value: String) -> String {
    let digest = HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: secret)
    return Data(digest).base64URLEncodedString()
  }

  private static func decodeBase64URL(_ value: String) -> Data? {
    var base64 = value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = base64.count % 4
    if remainder > 0 {
      base64.append(String(repeating: "=", count: 4 - remainder))
    }
    return Data(base64Encoded: base64)
  }
}
