import Foundation
import JSONWebKey
import JSONWebSignature

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
    let header = DefaultJWSHeaderImpl(algorithm: .ES256, keyID: signingKey.kid)
    let payload = try JSONEncoder().encode(claims)
    return try JWS(payload: payload, protectedHeader: header, key: signingKey.privateKey)
      .compactSerialization
  }
}
