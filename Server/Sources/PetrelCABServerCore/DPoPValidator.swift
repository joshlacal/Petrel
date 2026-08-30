#if canImport(CryptoKit)
  @preconcurrency import CryptoKit
#else
  @preconcurrency import Crypto
#endif
import Foundation
import PetrelCrypto

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

struct DPoPProofHeader: Decodable, Sendable {
  let typ: String?
  let alg: String?
  let jwk: JWK?
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
    guard proof.count <= 8192 else {
      throw CABRequestError.invalidDPoPProof("proof exceeds maximum length")
    }
    let parts = proof.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else {
      throw CABRequestError.invalidDPoPProof("malformed JWS")
    }
    let headerString = String(parts[0])
    let payloadString = String(parts[1])
    let signatureString = String(parts[2])

    guard let headerData = try? JWTBase64URL.decode(headerString),
          let payloadData = try? JWTBase64URL.decode(payloadString),
          let signatureBytes = try? JWTBase64URL.decode(signatureString)
    else {
      throw CABRequestError.invalidDPoPProof("malformed JWS")
    }

    guard let header = try? JSONDecoder().decode(DPoPProofHeader.self, from: headerData) else {
      throw CABRequestError.invalidDPoPProof("malformed JWS")
    }

    guard header.typ == "dpop+jwt" else {
      throw CABRequestError.invalidDPoPProof("typ must be dpop+jwt")
    }
    guard header.alg == "ES256" else {
      throw CABRequestError.invalidDPoPProof("alg must be ES256")
    }
    guard let jwk = header.jwk,
          jwk.kty == "EC",
          jwk.crv == "P-256"
    else {
      throw CABRequestError.invalidDPoPProof("header jwk must be an EC P-256 public key")
    }
    guard jwk.d == nil else {
      throw CABRequestError.invalidDPoPProof("header jwk must not contain private key material")
    }

    guard let xData = try? JWTBase64URL.decode(jwk.x),
          let yData = try? JWTBase64URL.decode(jwk.y),
          xData.count == 32, yData.count == 32
    else {
      throw CABRequestError.invalidDPoPProof("header jwk coordinates must be 32-byte base64url")
    }
    var uncompressed = Data([0x04])
    uncompressed.append(xData)
    uncompressed.append(yData)
    guard let publicKey = try? P256.Signing.PublicKey(x963Representation: uncompressed) else {
      throw CABRequestError.invalidDPoPProof("header jwk must be an EC P-256 public key")
    }

    let signingInput = "\(headerString).\(payloadString)"
    guard let ecdsaSig = try? P256WireSignature.decodeMalleabilityTolerant(signatureBytes),
          publicKey.isValidSignature(ecdsaSig, for: Data(signingInput.utf8))
    else {
      throw CABRequestError.invalidDPoPProof("signature verification failed")
    }

    let claims: DPoPProofClaims
    do {
      claims = try JSONDecoder().decode(DPoPProofClaims.self, from: payloadData)
    } catch {
      throw CABRequestError.invalidDPoPProof("malformed claims")
    }
    guard !claims.jti.isEmpty, claims.jti.count <= 512 else {
      throw CABRequestError.invalidDPoPProof("invalid or oversized jti")
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
