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
    #expect(config.replayCapacity == 50_000)
    #expect(config.deviceCapacity == 10_000)
    #expect(config.rateLimitCapacity == 10_000)
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
        "CAB_REPLAY_CAPACITY": "12345",
        "CAB_DEVICE_CAPACITY": "6789",
        "CAB_RATE_LIMIT_CAPACITY": "4321",
      ]
    )
    #expect(config.clientId == "https://env.example/meta.json")
    #expect(config.publicUrl == "https://env.example")
    #expect(config.port == 2222)
    #expect(config.host == "0.0.0.0")
    #expect(config.allowedOrigins == ["https://a.example", "https://b.example"])
    #expect(config.requireNonce == true)
    #expect(config.deniedJkts == ["badjkt1", "badjkt2"])
    #expect(config.replayCapacity == 12345)
    #expect(config.deviceCapacity == 6789)
    #expect(config.rateLimitCapacity == 4321)
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

  @Test("CAB_KEY_PEM_BASE64 replaces file-configured keys and wins active_kid, rather than appending")
  func envKeyReplacesFileKeys() throws {
    let path = try write(
      """
      {
        "client_id": "https://file.example/meta.json",
        "public_url": "https://file.example",
        "keys": [
          { "kid": "file-key-1", "pem_path": "/nonexistent/should-never-be-read.pem" }
        ],
        "active_kid": "file-key-1"
      }
      """
    )
    let config = try ServerConfig.load(
      path: path,
      environment: [
        "CAB_KEY_PEM_BASE64": "aWdub3JlZA==",
        "CAB_KEY_KID": "env-key-1",
      ]
    )
    // The file key is gone entirely — not merely superseded by activeKid —
    // so KeyStore never attempts to read the (missing) file pem_path.
    #expect(config.keys == [KeyConfig(kid: "env-key-1", pemBase64: "aWdub3JlZA==")])
    #expect(config.activeKid == "env-key-1")
  }

  @Test("CAB_KEY_PEM_BASE64 wins active_kid even when the file sets its own active_kid")
  func envKeyWinsActiveKidOverFile() throws {
    let path = try write(
      """
      {
        "client_id": "https://file.example/meta.json",
        "public_url": "https://file.example",
        "keys": [
          { "kid": "file-key-1", "pem_base64": "aWdub3JlZA==" }
        ],
        "active_kid": "file-key-1"
      }
      """
    )
    let config = try ServerConfig.load(
      path: path,
      environment: ["CAB_KEY_PEM_BASE64": "ZW52a2V5"]
    )
    // Defaults to "cab-key-1" when CAB_KEY_KID isn't set.
    #expect(config.activeKid == "cab-key-1")
    #expect(config.keys == [KeyConfig(kid: "cab-key-1", pemBase64: "ZW52a2V5")])
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

  @Test("Validation rejects non-positive or out-of-range bounds with specific error details")
  func rejectsInvalidBounds() throws {
    // replay_capacity == 0
    let path0 = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1",
        "replay_capacity": 0
      }
      """
    )
    #expect(throws: ConfigError.invalidValue(field: "replay_capacity", value: "0")) {
      _ = try ServerConfig.load(path: path0, environment: [:])
    }

    // replay_capacity < 0
    let pathNegReplay = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1",
        "replay_capacity": -1
      }
      """
    )
    #expect(throws: ConfigError.invalidValue(field: "replay_capacity", value: "-1")) {
      _ = try ServerConfig.load(path: pathNegReplay, environment: [:])
    }

    // device_capacity == 0
    let pathDevice0 = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1",
        "device_capacity": 0
      }
      """
    )
    #expect(throws: ConfigError.invalidValue(field: "device_capacity", value: "0")) {
      _ = try ServerConfig.load(path: pathDevice0, environment: [:])
    }

    // device_capacity < 0
    let pathNegDevice = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1",
        "device_capacity": -5
      }
      """
    )
    #expect(throws: ConfigError.invalidValue(field: "device_capacity", value: "-5")) {
      _ = try ServerConfig.load(path: pathNegDevice, environment: [:])
    }

    // rate_limit_capacity == 0
    let pathRL0 = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1",
        "rate_limit_capacity": 0
      }
      """
    )
    #expect(throws: ConfigError.invalidValue(field: "rate_limit_capacity", value: "0")) {
      _ = try ServerConfig.load(path: pathRL0, environment: [:])
    }

    // rate_limit_capacity < 0
    let pathNegRL = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1",
        "rate_limit_capacity": -10
      }
      """
    )
    #expect(throws: ConfigError.invalidValue(field: "rate_limit_capacity", value: "-10")) {
      _ = try ServerConfig.load(path: pathNegRL, environment: [:])
    }

    // Port bounds: negative or > 65535 rejected, 0 accepted (ephemeral binding)
    let pathNegPort = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1",
        "port": -1
      }
      """
    )
    #expect(throws: ConfigError.invalidValue(field: "port", value: "-1")) {
      _ = try ServerConfig.load(path: pathNegPort, environment: [:])
    }

    let pathHugePort = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1",
        "port": 70000
      }
      """
    )
    #expect(throws: ConfigError.invalidValue(field: "port", value: "70000")) {
      _ = try ServerConfig.load(path: pathHugePort, environment: [:])
    }

    let pathPort0 = try write(
      """
      {
        "client_id": "https://cab.example.com/meta.json",
        "public_url": "https://cab.example.com",
        "keys": [{ "kid": "k1", "pem_base64": "aWdub3JlZA==" }],
        "active_kid": "k1",
        "port": 0
      }
      """
    )
    let configPort0 = try ServerConfig.load(path: pathPort0, environment: [:])
    #expect(configPort0.port == 0)
  }

  @Test("Unparsable capacity or port environment variables throw invalidValue")
  func unparsableEnvThrows() throws {
    let baseEnv = [
      "CAB_CLIENT_ID": "https://env.example/meta.json",
      "CAB_PUBLIC_URL": "https://env.example",
      "CAB_KEY_PEM_BASE64": "aWdub3JlZA==",
      "CAB_KEY_KID": "envkey",
    ]

    var envReplay = baseEnv
    envReplay["CAB_REPLAY_CAPACITY"] = "50_000"
    #expect(throws: ConfigError.invalidValue(field: "replay_capacity", value: "50_000")) {
      _ = try ServerConfig.load(path: nil, environment: envReplay)
    }

    var envDevice = baseEnv
    envDevice["CAB_DEVICE_CAPACITY"] = "10k"
    #expect(throws: ConfigError.invalidValue(field: "device_capacity", value: "10k")) {
      _ = try ServerConfig.load(path: nil, environment: envDevice)
    }

    var envRateLimit = baseEnv
    envRateLimit["CAB_RATE_LIMIT_CAPACITY"] = "invalid"
    #expect(throws: ConfigError.invalidValue(field: "rate_limit_capacity", value: "invalid")) {
      _ = try ServerConfig.load(path: nil, environment: envRateLimit)
    }

    var envPort = baseEnv
    envPort["CAB_PORT"] = "http"
    #expect(throws: ConfigError.invalidValue(field: "port", value: "http")) {
      _ = try ServerConfig.load(path: nil, environment: envPort)
    }
  }
}
