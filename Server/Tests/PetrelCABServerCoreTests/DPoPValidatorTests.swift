#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import PetrelCrypto
@testable import PetrelCABServerCore
import Testing

let testEndpoint = "https://cab.test/oauth/client-assertion"

/// Builds DPoP proofs with every field overridable, for the validation matrix.
/// `embedJWKOf` lets a test embed a DIFFERENT public key than the signer
/// (wrong-key case). `includePrivateKey` leaks `d` into the header jwk.
func makeDPoPProof(
  key: P256.Signing.PrivateKey = .init(),
  typ: String? = "dpop+jwt",
  htm: String = "POST",
  htu: String = testEndpoint,
  iat: Int = Int(Date().timeIntervalSince1970),
  jti: String = UUID().uuidString,
  nonce: String? = nil,
  includePrivateKey: Bool = false,
  embedJWKOf: P256.Signing.PrivateKey? = nil
) throws -> String {
  let jwkKey = embedJWKOf ?? key
  let dValue = includePrivateKey ? JWTBase64URL.encode(key.rawRepresentation) : nil
  let pubX963 = jwkKey.publicKey.x963Representation
  let xB64 = JWTBase64URL.encode(Data(pubX963.dropFirst().prefix(32)))
  let yB64 = JWTBase64URL.encode(Data(pubX963.suffix(32)))
  let jwk = JWK(x: xB64, y: yB64, d: dValue)

  struct Header: Encodable {
    let typ: String?
    let alg: String
    let jwk: JWK
  }
  let header = Header(typ: typ, alg: "ES256", jwk: jwk)
  struct Claims: Encodable {
    let jti: String
    let htm: String
    let htu: String
    let iat: Int
    let nonce: String?
  }
  let payload = Claims(jti: jti, htm: htm, htu: htu, iat: iat, nonce: nonce)
  let headerData = try JSONEncoder().encode(header)
  let payloadData = try JSONEncoder().encode(payload)
  let headerB64 = JWTBase64URL.encode(headerData)
  let payloadB64 = JWTBase64URL.encode(payloadData)
  let signingInput = "\(headerB64).\(payloadB64)"
  let signatureBytes = try P256WireSignature.sign(Data(signingInput.utf8), using: key)
  let sigB64 = JWTBase64URL.encode(signatureBytes)
  return "\(headerB64).\(payloadB64).\(sigB64)"
}

/// Hand-crafted `alg: none` token — build the compact serialization manually.
func makeAlgNoneProof(htu: String = testEndpoint) throws -> String {
  let jwk = JWK(publicKey: P256.Signing.PrivateKey().publicKey)
  let jwkJSON = String(data: try JSONEncoder().encode(jwk), encoding: .utf8)!
  let header = #"{"alg":"none","typ":"dpop+jwt","jwk":\#(jwkJSON)}"#
  let payload = #"{"jti":"\#(UUID().uuidString)","htm":"POST","htu":"\#(htu)","iat":\#(Int(Date().timeIntervalSince1970))}"#
  return "\(JWTBase64URL.encode(Data(header.utf8))).\(JWTBase64URL.encode(Data(payload.utf8)))."
}

@Suite("DPoP proof validation")
struct DPoPValidatorTests {
  let validator = DPoPValidator(endpointURL: testEndpoint, iatWindow: 300)

  @Test("Valid proof passes and yields the key's RFC 7638 thumbprint")
  func validProof() throws {
    let key = P256.Signing.PrivateKey()
    let proof = try makeDPoPProof(key: key, jti: "jti-1")
    let (validated, claims) = try validator.validate(proof: proof)
    #expect(validated.jti == "jti-1")
    #expect(claims.htm == "POST")
    let expectedJKT = try JWK(publicKey: key.publicKey).thumbprint()
    #expect(validated.jkt == expectedJKT)
  }

  @Test("Canonically-equivalent htu forms pass")
  func htuCanonicalization() throws {
    for htu in [
      "HTTPS://CAB.TEST/oauth/client-assertion",
      "https://cab.test:443/oauth/client-assertion",
      "https://cab.test/oauth/client-assertion?ignored=1",
      "https://cab.test/oauth/client-assertion#frag",
    ] {
      let proof = try makeDPoPProof(htu: htu)
      _ = try validator.validate(proof: proof)
    }
  }

  @Test("Rejection matrix", arguments: [
    "wrong-typ", "missing-typ", "wrong-htm", "wrong-htu", "stale-iat",
    "future-iat", "private-jwk", "wrong-key", "malformed",
  ])
  func rejections(kind: String) throws {
    let proof: String
    switch kind {
    case "wrong-typ": proof = try makeDPoPProof(typ: "jwt")
    case "missing-typ": proof = try makeDPoPProof(typ: nil)
    case "wrong-htm": proof = try makeDPoPProof(htm: "GET")
    case "wrong-htu": proof = try makeDPoPProof(htu: "https://other.example/oauth/client-assertion")
    case "stale-iat": proof = try makeDPoPProof(iat: Int(Date().timeIntervalSince1970) - 3600)
    case "future-iat": proof = try makeDPoPProof(iat: Int(Date().timeIntervalSince1970) + 3600)
    case "private-jwk": proof = try makeDPoPProof(includePrivateKey: true)
    case "wrong-key": proof = try makeDPoPProof(embedJWKOf: P256.Signing.PrivateKey())
    case "malformed": proof = "not.a.jws"
    default: fatalError("unknown kind")
    }
    #expect(throws: CABRequestError.self) {
      _ = try validator.validate(proof: proof)
    }
  }

  @Test("alg none is rejected")
  func algNoneRejected() throws {
    let proof = try makeAlgNoneProof()
    #expect(throws: CABRequestError.self) {
      _ = try validator.validate(proof: proof)
    }
  }

  @Test("Rejections carry the invalid_dpop_proof error code")
  func rejectionErrorCode() throws {
    do {
      _ = try validator.validate(proof: try makeDPoPProof(htm: "GET"))
      Issue.record("expected throw")
    } catch let error as CABRequestError {
      #expect(error.error == "invalid_dpop_proof")
      #expect(error.status == 400)
    }
  }
}
