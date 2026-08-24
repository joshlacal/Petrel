#if canImport(CryptoKit)
  @preconcurrency import CryptoKit
#else
  @preconcurrency import Crypto
#endif
import Foundation
import PetrelCrypto

/// Signs RFC 7523 client assertion JWTs bound to a DPoP key via cnf/jkt.
public struct AssertionMinter: Sendable {
  public let clientId: String
  public let signingKey: SigningKey
  public let ttl: TimeInterval

  struct CnfClaim: Codable {
    let jkt: String
  }

  struct AssertionClaims: Codable {
    let iss: String
    let sub: String
    let aud: String
    let jti: String
    let iat: Int
    let exp: Int
    let cnf: CnfClaim
  }

  public init(clientId: String, signingKey: SigningKey, ttl: TimeInterval) {
    self.clientId = clientId
    self.signingKey = signingKey
    self.ttl = ttl
  }

  public func mint(aud: String, jkt: String, now: Date = Date()) throws -> String {
    let iat = Int(now.timeIntervalSince1970)
    let claims = AssertionClaims(
      iss: clientId,
      sub: clientId,
      aud: aud,
      jti: UUID().uuidString,
      iat: iat,
      exp: iat + Int(ttl),
      cnf: CnfClaim(jkt: jkt)
    )
    // kid is REQUIRED by @atproto/oauth-provider's client-assertion check.
    struct Header: Encodable {
      let alg: String
      let kid: String

      init(kid: String) {
        self.alg = "ES256"
        self.kid = kid
      }
    }
    let header = Header(kid: signingKey.kid)
    let headerData = try JSONEncoder().encode(header)
    let payloadData = try JSONEncoder().encode(claims)
    let headerB64 = JWTBase64URL.encode(headerData)
    let payloadB64 = JWTBase64URL.encode(payloadData)
    let signingInput = "\(headerB64).\(payloadB64)"
    let signatureBytes = try P256WireSignature.sign(Data(signingInput.utf8), using: signingKey.privateKey)
    let sigB64 = JWTBase64URL.encode(signatureBytes)
    return "\(headerB64).\(payloadB64).\(sigB64)"
}
}
