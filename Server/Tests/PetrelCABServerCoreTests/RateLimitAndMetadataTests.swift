#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import Hummingbird
import HummingbirdTesting
@testable import PetrelCABServerCore
import Testing

@Suite("Rate limiter")
struct RateLimiterTests {
  @Test("Allows up to the per-minute budget, then refuses, then refills")
  func tokenBucket() async {
    let limiter = RateLimiter(requestsPerMinute: 3)
    let start = Date(timeIntervalSince1970: 2_000_000)
    #expect(await limiter.allow(key: "k", now: start) == true)
    #expect(await limiter.allow(key: "k", now: start) == true)
    #expect(await limiter.allow(key: "k", now: start) == true)
    #expect(await limiter.allow(key: "k", now: start) == false)
    // Independent keys have independent budgets.
    #expect(await limiter.allow(key: "other", now: start) == true)
    // One second refills 3/60 = 0.05 tokens — not enough.
    #expect(await limiter.allow(key: "k", now: start.addingTimeInterval(1)) == false)
    // Twenty-one seconds refills > 1 token.
    #expect(await limiter.allow(key: "k", now: start.addingTimeInterval(21)) == true)
  }

  @Test("Idle buckets are evicted so a caller rotating keys can't grow memory without bound")
  func staleBucketsAreEvicted() async {
    let limiter = RateLimiter(requestsPerMinute: 3)
    let start = Date(timeIntervalSince1970: 4_000_000)

    // The prune sweep is amortized to every ~100 calls, so a distinct key
    // per call up to (but under) that interval leaves every bucket in
    // place — no sweep has run yet.
    for i in 0 ..< 99 {
      #expect(await limiter.allow(key: "rotating-\(i)", now: start) == true)
    }
    #expect(await limiter.bucketCountForTesting == 99)

    // The 100th call both trips the amortization counter and lands past
    // the eviction horizon (2× the full-refill window) for every prior
    // bucket, so the sweep it triggers drops them all, keeping only the
    // bucket just touched.
    #expect(await limiter.allow(key: "sweep-trigger", now: start.addingTimeInterval(121)) == true)
    #expect(await limiter.bucketCountForTesting == 1)
  }

  @Test("Between sweeps buckets can grow past a single interval, but the next sweep reclaims them all")
  func transientGrowthIsBoundedByAmortizationInterval() async {
    let limiter = RateLimiter(requestsPerMinute: 3)
    let start = Date(timeIntervalSince1970: 4_500_000)

    // 199 distinct rotating keys at the same instant, crossing one
    // internal sweep boundary (at call 100) along the way. Since none of
    // them are actually stale yet (no time has passed), that sweep evicts
    // nothing — the dict grows past what an eager per-call prune would
    // ever allow it to reach, even for a moment.
    for i in 0 ..< 199 {
      _ = await limiter.allow(key: "rotating-\(i)", now: start)
    }
    #expect(await limiter.bucketCountForTesting == 199)

    // The 200th call both trips the next sweep and lands past the
    // eviction horizon for all of them, collapsing the dict back down to
    // just the bucket just touched: growth between sweeps was real, but
    // still bounded and eventually reclaimed, never unbounded.
    #expect(await limiter.allow(key: "sweep-trigger", now: start.addingTimeInterval(121)) == true)
    #expect(await limiter.bucketCountForTesting == 1)
  }

  @Test("Eviction never discounts a live bucket's accumulated usage")
  func evictionPreservesLiveBucketAccuracy() async {
    let limiter = RateLimiter(requestsPerMinute: 3)
    let start = Date(timeIntervalSince1970: 5_000_000)

    // Exhaust "k"'s budget, then keep it alive with unrelated traffic on
    // other keys spaced so no sweep ever finds "k" stale.
    #expect(await limiter.allow(key: "k", now: start) == true)
    #expect(await limiter.allow(key: "k", now: start) == true)
    #expect(await limiter.allow(key: "k", now: start) == true)
    #expect(await limiter.allow(key: "k", now: start) == false)

    // Ten seconds later "k" is still within its refill window and remains
    // refused — the sweep must not have reset it to a fresh, full bucket.
    #expect(await limiter.allow(key: "k", now: start.addingTimeInterval(10)) == false)
  }
}

@Suite("Rate-limited endpoint")
struct RateLimitedEndpointTests {
  @Test("Per-jkt budget exhaustion yields 429 rate_limited")
  func endpointRateLimit() async throws {
    let (config, _) = try makeTestConfig {
      $0.rateLimit = RateLimitConfig(requestsPerMinute: 2)
    }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      let deviceKey = P256.Signing.PrivateKey()
      for expected in [HTTPResponse.Status.ok, .ok, .tooManyRequests] {
        let proof = try makeDPoPProof(
          key: deviceKey, htu: "https://cab.test/oauth/client-assertion"
        )
        let response = try await client.execute(
          uri: "/oauth/client-assertion", method: .post,
          headers: [
            .contentType: "application/x-www-form-urlencoded",
            .dpop: proof,
          ],
          body: ByteBuffer(string: "aud=https://auth.example")
        )
        #expect(response.status == expected)
      }
    }
  }
}

@Suite("Client metadata endpoint")
struct ClientMetadataEndpointTests {
  @Test("Serves the configured document verbatim; absent config yields 404")
  func metadataToggle() async throws {
    let (bare, _) = try makeTestConfig()
    let bareServer = try CABServer(config: bare)
    let bareApp = Application(router: bareServer.buildRouter())
    try await bareApp.test(.router) { client in
      try await client.execute(uri: "/oauth-client-metadata.json", method: .get) { response in
        #expect(response.status == .notFound)
      }
    }

    let (config, _) = try makeTestConfig {
      $0.clientMetadata = .object([
        "client_id": .string("https://cab.test/oauth-client-metadata.json"),
        "token_endpoint_auth_method": .string("private_key_jwt"),
        "jwks_uri": .string("https://cab.test/.well-known/jwks.json"),
        "dpop_bound_access_tokens": .bool(true),
      ])
    }
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      try await client.execute(uri: "/oauth-client-metadata.json", method: .get) { response in
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "application/json")
        let parsed = try JSONSerialization.jsonObject(
          with: Data(buffer: response.body)
        ) as? [String: Any]
        #expect(parsed?["token_endpoint_auth_method"] as? String == "private_key_jwt")
        #expect(parsed?["dpop_bound_access_tokens"] as? Bool == true)
      }
    }
  }
}
