#if canImport(CryptoKit)
  import CryptoKit
#else
  @preconcurrency import Crypto
#endif
import Foundation
import Hummingbird
import PetrelCrypto
import Logging
@testable import Petrel
@testable import PetrelCABServerCore
import Testing

// MARK: - Petrel-side test doubles (this target cannot see PetrelTests')

actor IntegrationAccountManager: AccountManaging {
  private let account: Account
  init(account: Account) { self.account = account }
  func addAccount(_: Account) async throws {}
  func getAccount(did: String) async -> Account? { did == account.did ? account : nil }
  func updateAccountFromStorage(did _: String) async throws {}
  func removeAccount(did _: String) async throws {}
  func setCurrentAccount(did _: String) async throws {}
  func getCurrentAccount() async -> Account? { account }
  func listAccounts() async -> [Account] { [account] }
  func clearCurrentAccount() async {}
  func updateServiceDIDs(bskyAppViewDID _: String, bskyChatDID _: String) async throws {}
}

final class IntegrationDIDResolver: DIDResolving, @unchecked Sendable {
  func resolveHandleToDID(handle _: String) async throws -> String { "did:plc:test" }
  func resolveDIDToPDSURL(did _: String) async throws -> URL { URL(string: "https://pds.test")! }
  func resolveDIDToHandleAndPDSURL(did _: String) async throws -> (String, URL) {
    ("test.example", URL(string: "https://pds.test")!)
  }
}

// MARK: - Harness

/// Runs a fully-wired CABServer on a random loopback port for the duration
/// of `body`. Port collisions are possible but vanishingly rare; rerun on a
/// bind failure.
func withRunningServer(
  mutateConfig: @escaping @Sendable (inout ServerConfig) -> Void = { _ in },
  _ body: @Sendable (_ port: Int, _ serverKey: P256.Signing.PrivateKey) async throws -> Void
) async throws {
  let port = Int.random(in: 20000 ..< 60000)
  let serverKey = P256.Signing.PrivateKey()
  let pemBase64 = Data(serverKey.pemRepresentation.utf8).base64EncodedString()
  let json = """
    {
      "client_id": "https://cab.test/oauth-client-metadata.json",
      "public_url": "http://127.0.0.1:\(port)",
      "host": "127.0.0.1",
      "port": \(port),
      "keys": [{ "kid": "integration-key", "pem_base64": "\(pemBase64)" }],
      "active_kid": "integration-key"
    }
    """
  var config = try JSONDecoder().decode(ServerConfig.self, from: Data(json.utf8))
  mutateConfig(&config)
  try config.validate()

  let server = try CABServer(config: config)
  var logger = Logger(label: "integration")
  logger.logLevel = .error
  let app = server.buildApplication(logger: logger)

  let serverTask = Task { try await app.runService() }
  defer { serverTask.cancel() }

  // Wait for readiness by polling /health.
  let healthURL = URL(string: "http://127.0.0.1:\(port)/health")!
  var ready = false
  for _ in 0 ..< 50 {
    if let (_, response) = try? await URLSession.shared.data(from: healthURL),
       (response as? HTTPURLResponse)?.statusCode == 200
    {
      ready = true
      break
    }
    try await Task.sleep(nanoseconds: 100_000_000)
  }
  try #require(ready, "server did not become ready on port \(port)")

  try await body(port, serverKey)
}

func makeStrategy(port: Int, namespace: String) -> CABOAuthStrategy {
  CABOAuthStrategy(
    backendURL: URL(string: "http://127.0.0.1:\(port)")!,
    storage: KeychainStorage(namespace: namespace),
    accountManager: IntegrationAccountManager(
      account: Account(
        did: "did:plc:test",
        handle: "test.example",
        pdsURL: URL(string: "https://pds.test")!
      )
    ),
    networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
    oauthConfig: OAuthConfig(
      clientId: "https://cab.test/oauth-client-metadata.json",
      redirectUri: "https://client.example/callback",
      scope: "atproto"
    ),
    didResolver: IntegrationDIDResolver()
  )
}

// MARK: - Tests

@Suite("Petrel ↔ petrel-cab-server integration", .serialized)
struct ClientServerIntegrationTests {
  @Test("Petrel fetches a verifiable assertion from the real server")
  func fetchRoundTrip() async throws {
    try await withRunningServer { port, serverKey in
      let strategy = makeStrategy(port: port, namespace: "integration.fetch")
      let deviceKey = P256.Signing.PrivateKey()

      let response = try await strategy.fetchClientAssertion(
        aud: "https://auth.example", ephemeralKey: deviceKey
      )

      #expect(response.clientId == "https://cab.test/oauth-client-metadata.json")
      let parts = response.clientAssertion.split(separator: ".")
      #expect(parts.count == 3)
      let headerData = try JWTBase64URL.decode(String(parts[0]))
      let headerDict = try #require(try JSONSerialization.jsonObject(with: headerData) as? [String: Any])
      #expect(headerDict["kid"] as? String == "integration-key")

      let signingInput = "\(parts[0]).\(parts[1])"
      let signatureBytes = try JWTBase64URL.decode(String(parts[2]))
      let ecdsaSig = try P256WireSignature.decodeMalleabilityTolerant(signatureBytes)
      #expect(serverKey.publicKey.isValidSignature(ecdsaSig, for: Data(signingInput.utf8)))

      struct Claims: Decodable {
        struct Cnf: Decodable { let jkt: String }
        let iss: String
        let aud: String
        let cnf: Cnf
      }
      let payloadData = try JWTBase64URL.decode(String(parts[1]))
      let claims = try JSONDecoder().decode(Claims.self, from: payloadData)
      #expect(claims.iss == "https://cab.test/oauth-client-metadata.json")
      #expect(claims.aud == "https://auth.example")
      let deviceJKT = try JWK(publicKey: deviceKey.publicKey).thumbprint()
      #expect(claims.cnf.jkt == deviceJKT)
  }
    }

  @Test("Nonce dance is transparent: require_nonce server, one client call")
  func nonceDance() async throws {
    try await withRunningServer(mutateConfig: { $0.requireNonce = true }) { port, _ in
      let strategy = makeStrategy(port: port, namespace: "integration.nonce")
      let response = try await strategy.fetchClientAssertion(
        aud: "https://auth.example", ephemeralKey: P256.Signing.PrivateKey()
      )
      #expect(!response.clientAssertion.isEmpty)
    }
  }

  @Test("Server device refusal surfaces as the typed Petrel error")
  func deviceRefusal() async throws {
    let deviceKey = P256.Signing.PrivateKey()
    let jkt = try JWK(publicKey: deviceKey.publicKey).thumbprint()
    try await withRunningServer(mutateConfig: { $0.deniedJkts = [jkt] }) { port, _ in
      let strategy = makeStrategy(port: port, namespace: "integration.denied")
      await #expect(throws: ClientAssertionBackendError(statusCode: 403, code: "access_denied")) {
        _ = try await strategy.fetchClientAssertion(
          aud: "https://auth.example", ephemeralKey: deviceKey
        )
      }
    }
  }

  @Test("Public cab.swan.place fetch round trip")
  func publicServerFetch() async throws {
    let strategy = CABOAuthStrategy(
      backendURL: URL(string: "https://cab.swan.place")!,
      storage: KeychainStorage(namespace: "test.public"),
      accountManager: IntegrationAccountManager(
        account: Account(
          did: "did:plc:test",
          handle: "test.example",
          pdsURL: URL(string: "https://pds.test")!
        )
      ),
      networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
      oauthConfig: OAuthConfig(
        clientId: "https://cab.swan.place/oauth-client-metadata.json",
        redirectUri: "blue.catbird.atprotodrive:/callback",
        scope: "atproto"
      ),
      didResolver: IntegrationDIDResolver()
    )
    let deviceKey = P256.Signing.PrivateKey()
    let response = try await strategy.fetchClientAssertion(
      aud: "https://swan.place", ephemeralKey: deviceKey
    )
    #expect(response.clientId == "https://cab.swan.place/oauth-client-metadata.json")
    #expect(!response.clientAssertion.isEmpty)
  }

  @Test("Live PAR against swan.place with cab.swan.place assertion")
  func swanPlacePAR() async throws {
    let client = try await ATProtoClient(
      oauthConfig: OAuthConfig(
        clientId: "https://cab.swan.place/oauth-client-metadata.json",
        redirectUri: "blue.catbird.atprotodrive:/callback",
        scope: "atproto"
      ),
      namespace: "test.swan.par",
      authMode: .cab(backendURL: URL(string: "https://cab.swan.place")!)
    )
    let authURL = try await client.startOAuthFlow(identifier: "josh.swan.place")
    print("SWAN.PLACE AUTH URL: \(authURL.absoluteString)")
    #expect(authURL.absoluteString.starts(with: "https://swan.place/oauth/authorize"))
  }

  @Test("Live PAR against bsky.social with public-client metadata")
  func bskySocialPublicOAuthPAR() async throws {
    let client = try await ATProtoClient(
      oauthConfig: OAuthConfig(
        clientId: "https://cab.swan.place/public-client-metadata.json",
        redirectUri: "blue.catbird.atprotodrive:/callback",
        scope: "atproto"
      ),
      namespace: "test.bsky.public",
      authMode: .publicOAuth
    )
    let authURL = try await client.startOAuthFlow(identifier: "jay.bsky.team")
    print("BSKY.SOCIAL PUBLIC AUTH URL: \(authURL.absoluteString)")
    #expect(authURL.absoluteString.starts(with: "https://bsky.social/oauth/authorize"))
  }
}
