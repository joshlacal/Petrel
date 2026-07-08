#if canImport(CryptoKit)
  import CryptoKit
#else
  @preconcurrency import Crypto
#endif
import Foundation
import Hummingbird
import JSONWebKey
import JSONWebSignature
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
      let jws = try JWS(jwsString: response.clientAssertion)
      #expect(jws.protectedHeader.keyID == "integration-key")
      #expect(try jws.verify(key: serverKey.publicKey.jwkRepresentation))

      struct Claims: Decodable {
        struct Cnf: Decodable { let jkt: String }
        let iss: String
        let aud: String
        let cnf: Cnf
      }
      let claims = try JSONDecoder().decode(Claims.self, from: jws.payload)
      #expect(claims.iss == "https://cab.test/oauth-client-metadata.json")
      #expect(claims.aud == "https://auth.example")
      #expect(claims.cnf.jkt == (try deviceKey.publicKey.jwkRepresentation.thumbprint()))
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
    let jkt = try deviceKey.publicKey.jwkRepresentation.thumbprint()
    try await withRunningServer(mutateConfig: { $0.deniedJkts = [jkt] }) { port, _ in
      let strategy = makeStrategy(port: port, namespace: "integration.denied")
      await #expect(throws: AuthError.clientAssertionBackendError(403, "access_denied")) {
        _ = try await strategy.fetchClientAssertion(
          aud: "https://auth.example", ephemeralKey: deviceKey
        )
      }
    }
  }
}
