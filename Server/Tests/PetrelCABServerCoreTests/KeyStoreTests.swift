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

/// Builds a config whose single key is a freshly generated P-256 PEM.
func makeTestConfig(
  mutate: (inout ServerConfig) -> Void = { _ in }
) throws -> (ServerConfig, P256.Signing.PrivateKey) {
  let key = P256.Signing.PrivateKey()
  let pemBase64 = Data(key.pemRepresentation.utf8).base64EncodedString()
  let json = """
    {
      "client_id": "https://cab.test/oauth-client-metadata.json",
      "public_url": "https://cab.test",
      "keys": [{ "kid": "test-key-1", "pem_base64": "\(pemBase64)" }],
      "active_kid": "test-key-1"
    }
    """
  var config = try JSONDecoder().decode(ServerConfig.self, from: Data(json.utf8))
  mutate(&config)
  try config.validate()
  return (config, key)
}

@Suite("Key store")
struct KeyStoreTests {
  @Test("Loads a base64 PEM key and exposes it as the active key")
  func loadsBase64PEM() throws {
    let (config, key) = try makeTestConfig()
    let store = try KeyStore(config: config)
    #expect(store.keys.count == 1)
    #expect(store.activeKey.kid == "test-key-1")
    #expect(store.activeKey.privateKey.rawRepresentation == key.rawRepresentation)
  }

  @Test("Loads a PEM key from a file path")
  func loadsPEMFile() throws {
    let key = P256.Signing.PrivateKey()
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent("cab-key-\(UUID().uuidString).pem").path
    try key.pemRepresentation.write(toFile: path, atomically: true, encoding: .utf8)
    var (config, _) = try makeTestConfig()
    config.keys = [KeyConfig(kid: "file-key", pemPath: path)]
    config.activeKid = "file-key"
    let store = try KeyStore(config: config)
    #expect(store.activeKey.privateKey.rawRepresentation == key.rawRepresentation)
  }

  @Test("Garbage key material throws invalidKeyMaterial")
  func garbageKeyMaterial() throws {
    var (config, _) = try makeTestConfig()
    config.keys = [KeyConfig(kid: "bad", pemBase64: Data("not a pem".utf8).base64EncodedString())]
    config.activeKid = "bad"
    #expect(throws: ConfigError.invalidKeyMaterial(kid: "bad")) {
      _ = try KeyStore(config: config)
    }
  }

  @Test("JWKS document contains every public key and no private material")
  func jwksShape() throws {
    let (config, _) = try makeTestConfig()
    let store = try KeyStore(config: config)
    let document = try store.jwksDocument()
    let parsed = try #require(
      try JSONSerialization.jsonObject(with: document) as? [String: Any]
    )
    let keys = try #require(parsed["keys"] as? [[String: Any]])
    try #require(keys.count == 1)
    #expect(keys[0]["kty"] as? String == "EC")
    #expect(keys[0]["crv"] as? String == "P-256")
    #expect(keys[0]["kid"] as? String == "test-key-1")
    #expect(keys[0]["x"] is String)
    #expect(keys[0]["y"] is String)
    #expect(keys[0]["d"] == nil)
  }

  @Test("GET /.well-known/jwks.json serves the document")
  func jwksEndpoint() async throws {
    let (config, _) = try makeTestConfig()
    let server = try CABServer(config: config)
    let app = Application(router: server.buildRouter())
    try await app.test(.router) { client in
      try await client.execute(uri: "/.well-known/jwks.json", method: .get) { response in
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "application/json")
        let body = String(buffer: response.body)
        #expect(body.contains("\"keys\""))
        #expect(body.contains("test-key-1"))
        #expect(!body.contains("\"d\""))
      }
    }
  }
}
