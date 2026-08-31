#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import PetrelCrypto
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

      let parts = body.clientAssertion.split(separator: ".")
      #expect(parts.count == 3)
      let headerData = try JWTBase64URL.decode(String(parts[0]))
      let headerDict = try #require(try JSONSerialization.jsonObject(with: headerData) as? [String: Any])
      #expect(headerDict["alg"] as? String == "ES256")
      #expect(headerDict["kid"] as? String == "test-key-1")

      let signingInput = "\(parts[0]).\(parts[1])"
      let signatureBytes = try JWTBase64URL.decode(String(parts[2]))
      let ecdsaSig = try P256WireSignature.decodeMalleabilityTolerant(signatureBytes)
      #expect(signingKey.publicKey.isValidSignature(ecdsaSig, for: Data(signingInput.utf8)))

      let claimsData = try JWTBase64URL.decode(String(parts[1]))
      let claims = try JSONDecoder().decode(AssertionClaims.self, from: claimsData)
      #expect(claims.iss == config.clientId)
      #expect(claims.sub == config.clientId)
      #expect(claims.aud == "https://auth.example")
      #expect(claims.exp - claims.iat == 60)
      let deviceJKT = try JWK(publicKey: deviceKey.publicKey).thumbprint()
      #expect(claims.cnf.jkt == deviceJKT)
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
    let jkt = try JWK(publicKey: deviceKey.publicKey).thumbprint()
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

  @Test("Origin policy: a \"*\" entry allows any browser origin through, echoing the concrete origin")
  func originPolicyWildcard() async throws {
    let (config, _) = try makeTestConfig { $0.allowedOrigins = ["*"] }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let ok = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), origin: "https://anything.example"
      )
      #expect(ok.status == .ok)
      // The concrete request origin is echoed back — never the literal
      // "*" — since credentialed/DPoP requests require a specific value.
      #expect(
        ok.headers[HTTPField.Name("Access-Control-Allow-Origin")!] == "https://anything.example"
      )

      let otherOrigin = try await postAssertion(
        client, proof: try makeDPoPProof(htu: endpointHTU), origin: "https://another.example"
      )
      #expect(otherOrigin.status == .ok)
      #expect(
        otherOrigin.headers[HTTPField.Name("Access-Control-Allow-Origin")!]
          == "https://another.example"
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

  @Test("Zero-mutation: invalid form, disallowed aud, or oversized identifiers leave stores unchanged")
  func zeroMutationOnRejectedRequests() async throws {
    let (config, _) = try makeTestConfig {
      $0.audAllowlist = ["https://allowed.example"]
      $0.rateLimit = RateLimitConfig(requestsPerMinute: 10)
    }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let deviceKey = P256.Signing.PrivateKey()

      // Helper to assert zero state mutated across all three stores
      func assertZeroStoreMutation() async {
        #expect(await server.replayStore.seenCountForTesting == 0)
        #expect(await server.rateLimiter?.bucketCountForTesting == 0)
        let snapshot = await server.deviceStore.snapshot()
        #expect(snapshot.isEmpty)
      }

      // Case 1: Missing / empty form body (missing aud)
      let proofMissingAud = try makeDPoPProof(key: deviceKey, htu: endpointHTU, jti: "zero-mut-1")
      let resMissing = try await postAssertion(client, proof: proofMissingAud, body: "")
      #expect(resMissing.status == .badRequest)
      await assertZeroStoreMutation()

      // Case 2: Disallowed aud
      let proofDisallowedAud = try makeDPoPProof(key: deviceKey, htu: endpointHTU, jti: "zero-mut-2")
      let resDisallowed = try await postAssertion(
        client, proof: proofDisallowedAud, body: "aud=https://disallowed.example"
      )
      #expect(resDisallowed.status == .badRequest)
      await assertZeroStoreMutation()

      // Case 3: Oversized aud (> 2048 chars)
      let hugeAud = "https://allowed.example/" + String(repeating: "x", count: 2500)
      let proofHugeAud = try makeDPoPProof(key: deviceKey, htu: endpointHTU, jti: "zero-mut-3")
      let resHugeAud = try await postAssertion(
        client, proof: proofHugeAud, body: "aud=\(hugeAud)"
      )
      #expect(resHugeAud.status == .badRequest)
      await assertZeroStoreMutation()

      // Case 4: Oversized JTI (> 512 chars)
      let hugeJti = String(repeating: "j", count: 600)
      let proofHugeJti = try makeDPoPProof(key: deviceKey, htu: endpointHTU, jti: hugeJti)
      let resHugeJti = try await postAssertion(
        client, proof: proofHugeJti, body: "aud=https://allowed.example"
      )
      #expect(resHugeJti.status == .badRequest)
      await assertZeroStoreMutation()

      // Case 5: Oversized proof (> 8192 chars)
      let hugeProof = String(repeating: "p", count: 9000)
      let resHugeProof = try await postAssertion(
        client, proof: hugeProof, body: "aud=https://allowed.example"
      )
      #expect(resHugeProof.status == .badRequest)
      await assertZeroStoreMutation()
    }
  }

  @Test("Replay store saturation returns 503 temporarily_unavailable and preserves live replay records")
  func replaySaturationReturns503() async throws {
    let (config, _) = try makeTestConfig {
      $0.replayCapacity = 2
    }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let proof1 = try makeDPoPProof(htu: endpointHTU, jti: "jti-1")
      let res1 = try await postAssertion(client, proof: proof1)
      #expect(res1.status == .ok)

      let proof2 = try makeDPoPProof(htu: endpointHTU, jti: "jti-2")
      let res2 = try await postAssertion(client, proof: proof2)
      #expect(res2.status == .ok)

      // 3rd distinct jti saturates the 2-entry store
      let proof3 = try makeDPoPProof(htu: endpointHTU, jti: "jti-3")
      let res3 = try await postAssertion(client, proof: proof3)
      #expect(res3.status == .serviceUnavailable)

      // Original jti-1 must still be refused as a replay (400, not 503!)
      let resReplay = try await postAssertion(client, proof: proof1)
      #expect(resReplay.status == .badRequest)
    }
  }


  @Test("Rate-limited requests (429) do not commit state to ReplayStore")
  func rateLimitedRequestsDoNotCommitReplayState() async throws {
    let (config, _) = try makeTestConfig {
      $0.rateLimit = RateLimitConfig(requestsPerMinute: 2)
      $0.replayCapacity = 50
    }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let deviceKey = P256.Signing.PrivateKey()

      let proof1 = try makeDPoPProof(key: deviceKey, htu: endpointHTU, jti: "rate-limit-jti-1")
      let res1 = try await postAssertion(client, proof: proof1)
      #expect(res1.status == .ok)

      let proof2 = try makeDPoPProof(key: deviceKey, htu: endpointHTU, jti: "rate-limit-jti-2")
      let res2 = try await postAssertion(client, proof: proof2)
      #expect(res2.status == .ok)
      #expect(await server.replayStore.seenCountForTesting == 2)

      // 3rd request from same device exceeds the rate limit (2 req/min)
      let proof3 = try makeDPoPProof(key: deviceKey, htu: endpointHTU, jti: "rate-limit-jti-3")
      let res3 = try await postAssertion(client, proof: proof3)
      #expect(res3.status == .tooManyRequests)

      // ReplayStore must NOT have recorded jti-3 for the 429-rejected request
      #expect(await server.replayStore.seenCountForTesting == 2)
    }
  }
}
