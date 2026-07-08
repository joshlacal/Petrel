import Foundation
@testable import PetrelCABServerCore
import Testing

@Suite("Server configuration")
struct ServerConfigTests {
  private func write(_ json: String) throws -> String {
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent("cab-config-\(UUID().uuidString).json").path
    try json.write(toFile: path, atomically: true, encoding: .utf8)
    return path
  }

  @Test("Minimal config decodes with documented defaults")
  func minimalConfig() throws {
    let path = try write(
      """
      {
        "client_id": "https://cab.example.com/oauth-client-metadata.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1"
      }
      """
    )
    let config = try ServerConfig.load(path: path, environment: [:])
    #expect(config.clientId == "https://cab.example.com/oauth-client-metadata.json")
    #expect(config.publicUrl == "https://cab.example.com")
    #expect(config.host == "127.0.0.1")
    #expect(config.port == 8080)
    #expect(config.allowedOrigins.isEmpty)
    #expect(config.requireOrigin == false)
    #expect(config.audAllowlist == nil)
    #expect(config.assertionTtlSeconds == 60)
    #expect(config.iatWindowSeconds == 300)
    #expect(config.requireNonce == false)
    #expect(config.deniedJkts.isEmpty)
    #expect(config.clientMetadata == nil)
    #expect(config.rateLimit == nil)
  }

  @Test("Environment variables override file values")
  func envOverrides() throws {
    let path = try write(
      """
      {
        "client_id": "https://file.example/meta.json",
        "public_url": "https://file.example",
        "port": 1111,
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1"
      }
      """
    )
    let config = try ServerConfig.load(
      path: path,
      environment: [
        "CAB_CLIENT_ID": "https://env.example/meta.json",
        "CAB_PUBLIC_URL": "https://env.example",
        "CAB_PORT": "2222",
        "CAB_HOST": "0.0.0.0",
        "CAB_ALLOWED_ORIGINS": "https://a.example,https://b.example",
        "CAB_REQUIRE_NONCE": "true",
        "CAB_DENIED_JKTS": "badjkt1,badjkt2",
      ]
    )
    #expect(config.clientId == "https://env.example/meta.json")
    #expect(config.publicUrl == "https://env.example")
    #expect(config.port == 2222)
    #expect(config.host == "0.0.0.0")
    #expect(config.allowedOrigins == ["https://a.example", "https://b.example"])
    #expect(config.requireNonce == true)
    #expect(config.deniedJkts == ["badjkt1", "badjkt2"])
  }

  @Test("Env-only configuration works without a file")
  func envOnly() throws {
    let config = try ServerConfig.load(
      path: nil,
      environment: [
        "CAB_CLIENT_ID": "https://env.example/meta.json",
        "CAB_PUBLIC_URL": "https://env.example",
        "CAB_KEY_PEM_BASE64": "aWdub3JlZA==",
        "CAB_KEY_KID": "envkey",
      ]
    )
    #expect(config.clientId == "https://env.example/meta.json")
    #expect(config.keys.count == 1)
    #expect(config.keys[0].kid == "envkey")
    #expect(config.activeKid == "envkey")
  }

  @Test("Validation rejects unknown active_kid")
  func unknownActiveKid() throws {
    let path = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "nope"
      }
      """
    )
    #expect(throws: ConfigError.self) {
      _ = try ServerConfig.load(path: path, environment: [:])
    }
  }

  @Test("Validation rejects non-https public_url (except loopback)")
  func rejectsPlainHTTP() throws {
    let path = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "http://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1"
      }
      """
    )
    #expect(throws: ConfigError.self) {
      _ = try ServerConfig.load(path: path, environment: [:])
    }
    // Loopback is fine for development:
    let loopbackPath = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "http://127.0.0.1:8080",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1"
      }
      """
    )
    let config = try ServerConfig.load(path: loopbackPath, environment: [:])
    #expect(config.publicUrl == "http://127.0.0.1:8080")
  }
}
