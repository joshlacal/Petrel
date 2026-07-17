#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import JSONWebKey
import JSONWebSignature

public struct ValidatedProof: Sendable, Equatable {
  public let jkt: String
  public let jti: String
}

public struct DPoPProofClaims: Decodable, Sendable {
  public let jti: String
  public let htm: String
  public let htu: String
  public let iat: Int
  public let exp: Int?
  public let nonce: String?
}

/// Stateless DPoP proof checks (RFC 9449): structure, typ/alg pinning,
/// embedded-key signature, htm/htu, iat freshness. Stateful checks (jti
/// replay, nonce requirement, device policy) belong to the route handler.
public struct DPoPValidator: Sendable {
  public let expectedHTU: String
  public let iatWindow: TimeInterval

  public init(endpointURL: String, iatWindow: TimeInterval) {
    expectedHTU = Self.canonicalize(endpointURL)
    self.iatWindow = iatWindow
  }

  public func validate(
    proof: String, now: Date = Date()
  ) throws -> (ValidatedProof, DPoPProofClaims) {
    let jws: JWS
    do {
      jws = try JWS(jwsString: proof)
    } catch {
      throw CABRequestError.invalidDPoPProof("malformed JWS")
    }

    guard jws.protectedHeader.type == "dpop+jwt" else {
      throw CABRequestError.invalidDPoPProof("typ must be dpop+jwt")
    }
    // jose-swift's JWS.verify returns true unconditionally for alg=none —
    // the algorithm MUST be pinned before verifying.
    guard jws.protectedHeader.algorithm == .ES256 else {
      throw CABRequestError.invalidDPoPProof("alg must be ES256")
    }
    guard let jwk = jws.protectedHeader.jwk,
          jwk.keyType == .ellipticCurve,
          jwk.curve == .p256
    else {
      throw CABRequestError.invalidDPoPProof("header jwk must be an EC P-256 public key")
    }
    guard jwk.d == nil else {
      throw CABRequestError.invalidDPoPProof("header jwk must not contain private key material")
    }
    guard (try? jws.verify(key: jwk)) == true else {
      throw CABRequestError.invalidDPoPProof("signature verification failed")
    }

    let claims: DPoPProofClaims
    do {
      claims = try JSONDecoder().decode(DPoPProofClaims.self, from: jws.payload)
    } catch {
      throw CABRequestError.invalidDPoPProof("malformed claims")
    }

    guard claims.htm == "POST" else {
      throw CABRequestError.invalidDPoPProof("htm must be POST")
    }
    guard Self.canonicalize(claims.htu) == expectedHTU else {
      throw CABRequestError.invalidDPoPProof("htu does not match this endpoint")
    }
    let age = now.timeIntervalSince1970 - TimeInterval(claims.iat)
    guard abs(age) <= iatWindow else {
      throw CABRequestError.invalidDPoPProof("iat outside acceptance window")
    }
    if let exp = claims.exp, TimeInterval(exp) < now.timeIntervalSince1970 {
      throw CABRequestError.invalidDPoPProof("proof expired")
    }

    guard let jkt = try? jwk.thumbprint() else {
      throw CABRequestError.invalidDPoPProof("could not compute key thumbprint")
    }
    return (ValidatedProof(jkt: jkt, jti: claims.jti), claims)
  }

  /// RFC 9449 §4.3 htu comparison: no query/fragment, lowercase
  /// scheme/host, default ports stripped.
  static func canonicalize(_ url: String) -> String {
    guard var components = URLComponents(string: url) else { return url }
    components.query = nil
    components.fragment = nil
    components.scheme = components.scheme?.lowercased()
    components.host = components.host?.lowercased()
    if let scheme = components.scheme, let port = components.port,
       (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
    {
      components.port = nil
    }
    return components.string ?? url
  }
}
