#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import JSONWebKey
import JSONWebSignature
@testable import PetrelCABServerCore
import Testing

private let endpointHTU = "https://cab.test/oauth/client-assertion"

private struct AssertionClaims: Decodable {
  struct Cnf: Decodable { let jkt: String }
  let iss: String
  let sub: String
  let aud: String
  let jti: String
  let iat: Int
  let exp: Int
  let cnf: Cnf
}

private func postAssertion(
  _ client: any TestClientProtocol,
  proof: String?,
  body: String = "aud=https://auth.example",
  origin: String? = nil
) async throws -> TestResponse {
  var headers: HTTPFields = [.contentType: "application/x-www-form-urlencoded"]
  if let proof { headers[.dpop] = proof }
  if let origin { headers[HTTPField.Name("Origin")!] = origin }
  return try await client.execute(
    uri: "/oauth/client-assertion", method: .post, headers: headers,
    body: ByteBuffer(string: body)
  )
}

@Suite("Assertion endpoint")
struct AssertionEndpointTests {
  @Test("Happy path mints a verifiable, correctly-shaped assertion")
  func happyPath() async throws {
    let (config, signingKey) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let deviceKey = P256.Signing.PrivateKey()
      let proof = try makeDPoPProof(key: deviceKey, htu: endpointHTU)
      let response = try await postAssertion(client, proof: proof)
      #expect(response.status == .ok)
      #expect(response.headers[.cacheControl] == "no-store")

      struct Body: Decodable {
        let clientId: String
        let clientAssertion: String
        enum CodingKeys: String, CodingKey {
          case clientId = "client_id"
          case clientAssertion = "client_assertion"
        }
      }
      let body = try JSONDecoder().decode(Body.self, from: Data(buffer: response.body))
      #expect(body.clientId == config.clientId)

      let jws = try JWS(jwsString: body.clientAssertion)
      #expect(jws.protectedHeader.algorithm == .ES256)
      #expect(jws.protectedHeader.keyID == "test-key-1")
      #expect(try jws.verify(key: signingKey.publicKey.jwkRepresentation))

      let claims = try JSONDecoder().decode(AssertionClaims.self, from: jws.payload)
      #expect(claims.iss == config.clientId)
      #expect(claims.sub == config.clientId)
      #expect(claims.aud == "https://auth.example")
      #expect(claims.exp - claims.iat == 60)
      #expect(claims.cnf.jkt == (try deviceKey.publicKey.jwkRepresentation.thumbprint()))
      #expect(!claims.jti.isEmpty)
    }
  }

  @Test("Missing DPoP header is invalid_dpop_proof")
  func missingProof() async throws {
    let (config, _) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let response = try await postAssertion(client, proof: nil)
      #expect(response.status == .badRequest)
      #expect(String(buffer: response.body).contains("invalid_dpop_proof"))
    }
  }

  @Test("Replaying a proof (same jti) is refused")
  func replayRefused() async throws {
    let (config, _) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let proof = try makeDPoPProof(htu: endpointHTU)
      let first = try await postAssertion(client, proof: proof)
      #expect(first.status == .ok)
      let second = try await postAssertion(client, proof: proof)
      #expect(second.status == .badRequest)
      #expect(String(buffer: second.body).contains("invalid_dpop_proof"))
    }
  }

  @Test("A denied jkt gets access_denied")
  func deniedDevice() async throws {
    let deviceKey = P256.Signing.PrivateKey()
    let jkt = try deviceKey.publicKey.jwkRepresentation.thumbprint()
    let (config, _) = try makeTestConfig { $0.deniedJkts = [jkt] }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let proof = try makeDPoPProof(key: deviceKey, htu: endpointHTU)
      let response = try await postAssertion(client, proof: proof)
      #expect(response.status == .forbidden)
      #expect(String(buffer: response.body).contains("access_denied"))
    }
  }

  @Test("Missing aud is invalid_request")
  func missingAud() async throws {
    let (config, _) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let proof = try makeDPoPProof(htu: endpointHTU)
      let response = try await postAssertion(client, proof: proof, body: "")
      #expect(response.status == .badRequest)
      #expect(String(buffer: response.body).contains("invalid_request"))
    }
  }

  @Test("aud outside the allowlist is refused")
  func audAllowlist() async throws {
    let (config, _) = try makeTestConfig { $0.audAllowlist = ["https://bsky.social"] }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let refused = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), body: "aud=https://evil.example"
      )
      #expect(refused.status == .badRequest)
      let allowed = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), body: "aud=https://bsky.social"
      )
      #expect(allowed.status == .ok)
    }
  }

  @Test("require_nonce challenges then accepts the echoed nonce")
  func nonceFlow() async throws {
    let (config, _) = try makeTestConfig { $0.requireNonce = true }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let deviceKey = P256.Signing.PrivateKey()
      let challenge = try await postAssertion(
        client, proof: try makeDPoPProof(key: deviceKey, htu: endpointHTU)
      )
      #expect(challenge.status == .badRequest)
      #expect(String(buffer: challenge.body).contains("use_dpop_nonce"))
      let nonce = try #require(challenge.headers[.dpopNonce])

      let retry = try await postAssertion(
        client, proof: try makeDPoPProof(key: deviceKey, htu: endpointHTU, nonce: nonce)
      )
      #expect(retry.status == .ok)
    }
  }

  @Test("Origin policy: allowlisted origins get CORS headers, others get 403")
  func originPolicy() async throws {
    let (config, _) = try makeTestConfig { $0.allowedOrigins = ["https://app.example"] }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let ok = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), origin: "https://app.example"
      )
      #expect(ok.status == .ok)
      #expect(ok.headers[HTTPField.Name("Access-Control-Allow-Origin")!] == "https://app.example")

      let refused = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), origin: "https://evil.example"
      )
      #expect(refused.status == .forbidden)

      // Preflight
      let preflight = try await client.execute(
        uri: "/oauth/client-assertion", method: .options,
        headers: [HTTPField.Name("Origin")!: "https://app.example"]
      )
      #expect(preflight.status == .noContent)
      #expect(
        preflight.headers[HTTPField.Name("Access-Control-Allow-Headers")!]?
          .contains("DPoP") == true
      )
    }
  }

  @Test(
    "Origin policy is scoped to the assertion endpoint: health/JWKS stay open without an Origin header even under require_origin, while the assertion route stays gated"
  )
  func originPolicyScopedToAssertionEndpoint() async throws {
    let (config, _) = try makeTestConfig {
      $0.requireOrigin = true
      $0.allowedOrigins = ["https://app.example"]
    }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      // The AS fetches these server-to-server (no Origin header) to
      // validate assertions and serve metadata; load balancers probe
      // /health the same way. None of these are the assertion endpoint,
      // so require_origin must not gate them.
      try await client.execute(uri: "/health", method: .get) { response in
        #expect(response.status == .ok)
      }
      try await client.execute(uri: "/.well-known/jwks.json", method: .get) { response in
        #expect(response.status == .ok)
      }

      // The assertion endpoint itself is still gated: no Origin header
      // plus require_origin is still refused.
      let refused = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU)
      )
      #expect(refused.status == .forbidden)
    }
  }
}
