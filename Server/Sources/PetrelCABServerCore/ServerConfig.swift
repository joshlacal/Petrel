import Foundation

public enum ConfigError: Error, Equatable, CustomStringConvertible {
  case fileNotReadable(String)
  case missingField(String)
  case unknownActiveKid(String)
  case invalidKeyMaterial(kid: String)
  case invalidURL(field: String, value: String)

  public var description: String {
    switch self {
    case let .fileNotReadable(path): "config file not readable: \(path)"
    case let .missingField(name): "missing required config field: \(name)"
    case let .unknownActiveKid(kid): "active_kid \"\(kid)\" is not in keys"
    case let .invalidKeyMaterial(kid): "key \"\(kid)\" has no loadable PEM (need pem_path or pem_base64 containing a P-256 private key)"
    case let .invalidURL(field, value): "\(field) must be an https URL (or http on 127.0.0.1/localhost for development): \(value)"
    }
  }
}

public struct KeyConfig: Codable, Sendable, Equatable {
  public var kid: String
  public var pemPath: String?
  public var pemBase64: String?

  enum CodingKeys: String, CodingKey {
    case kid
    case pemPath = "pem_path"
    case pemBase64 = "pem_base64"
  }

  public init(kid: String, pemPath: String? = nil, pemBase64: String? = nil) {
    self.kid = kid
    self.pemPath = pemPath
    self.pemBase64 = pemBase64
  }
}

public struct RateLimitConfig: Codable, Sendable, Equatable {
  public var requestsPerMinute: Int

  enum CodingKeys: String, CodingKey {
    case requestsPerMinute = "requests_per_minute"
  }

  public init(requestsPerMinute: Int = 60) {
    self.requestsPerMinute = requestsPerMinute
  }
}

public struct ServerConfig: Codable, Sendable, Equatable {
  public var clientId: String
  public var publicUrl: String
  public var host: String
  public var port: Int
  public var keys: [KeyConfig]
  public var activeKid: String
  public var allowedOrigins: [String]
  public var requireOrigin: Bool
  public var audAllowlist: [String]?
  public var assertionTtlSeconds: Int
  public var iatWindowSeconds: Int
  public var requireNonce: Bool
  public var nonceSecretBase64: String?
  public var deniedJkts: [String]
  public var clientMetadata: JSONValue?
  public var rateLimit: RateLimitConfig?

  enum CodingKeys: String, CodingKey {
    case clientId = "client_id"
    case publicUrl = "public_url"
    case host
    case port
    case keys
    case activeKid = "active_kid"
    case allowedOrigins = "allowed_origins"
    case requireOrigin = "require_origin"
    case audAllowlist = "aud_allowlist"
    case assertionTtlSeconds = "assertion_ttl_seconds"
    case iatWindowSeconds = "iat_window_seconds"
    case requireNonce = "require_nonce"
    case nonceSecretBase64 = "nonce_secret_base64"
    case deniedJkts = "denied_jkts"
    case clientMetadata = "client_metadata"
    case rateLimit = "rate_limit"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    clientId = try container.decodeIfPresent(String.self, forKey: .clientId) ?? ""
    publicUrl = try container.decodeIfPresent(String.self, forKey: .publicUrl) ?? ""
    host = try container.decodeIfPresent(String.self, forKey: .host) ?? "127.0.0.1"
    port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 8080
    keys = try container.decodeIfPresent([KeyConfig].self, forKey: .keys) ?? []
    activeKid = try container.decodeIfPresent(String.self, forKey: .activeKid) ?? ""
    allowedOrigins = try container.decodeIfPresent([String].self, forKey: .allowedOrigins) ?? []
    requireOrigin = try container.decodeIfPresent(Bool.self, forKey: .requireOrigin) ?? false
    audAllowlist = try container.decodeIfPresent([String].self, forKey: .audAllowlist)
    assertionTtlSeconds = try container.decodeIfPresent(Int.self, forKey: .assertionTtlSeconds) ?? 60
    iatWindowSeconds = try container.decodeIfPresent(Int.self, forKey: .iatWindowSeconds) ?? 300
    requireNonce = try container.decodeIfPresent(Bool.self, forKey: .requireNonce) ?? false
    nonceSecretBase64 = try container.decodeIfPresent(String.self, forKey: .nonceSecretBase64)
    deniedJkts = try container.decodeIfPresent([String].self, forKey: .deniedJkts) ?? []
    clientMetadata = try container.decodeIfPresent(JSONValue.self, forKey: .clientMetadata)
    rateLimit = try container.decodeIfPresent(RateLimitConfig.self, forKey: .rateLimit)
  }

  /// Loads config from an optional JSON file, then applies environment
  /// overrides, then validates. Env-only operation (path == nil) is supported.
  public static func load(
    path: String?,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> ServerConfig {
    var config: ServerConfig
    if let path {
      guard let data = FileManager.default.contents(atPath: path) else {
        throw ConfigError.fileNotReadable(path)
      }
      config = try JSONDecoder().decode(ServerConfig.self, from: data)
    } else {
      config = try JSONDecoder().decode(ServerConfig.self, from: Data("{}".utf8))
    }

    if let value = environment["CAB_CLIENT_ID"] { config.clientId = value }
    if let value = environment["CAB_PUBLIC_URL"] { config.publicUrl = value }
    if let value = environment["CAB_HOST"] { config.host = value }
    if let value = environment["CAB_PORT"], let port = Int(value) { config.port = port }
    if let value = environment["CAB_ACTIVE_KID"] { config.activeKid = value }
    if let value = environment["CAB_KEY_PEM_BASE64"] {
      // The env-provided key takes precedence over any file-configured
      // keys: replace (not append), and force activeKid to match — a
      // stale file activeKid pointing at a now-absent file key would
      // otherwise abort startup (or KeyStore would keep trying the file's
      // pem_path), defeating the env override for containerized deploys.
      let kid = environment["CAB_KEY_KID"] ?? "cab-key-1"
      config.keys = [KeyConfig(kid: kid, pemBase64: value)]
      config.activeKid = kid
    }
    if let value = environment["CAB_ALLOWED_ORIGINS"] {
      config.allowedOrigins = value.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespaces)
      }
    }
    if let value = environment["CAB_REQUIRE_NONCE"] {
      config.requireNonce = value == "true" || value == "1"
    }
    if let value = environment["CAB_NONCE_SECRET_BASE64"] { config.nonceSecretBase64 = value }
    if let value = environment["CAB_DENIED_JKTS"] {
      config.deniedJkts = value.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespaces)
      }
    }

    try config.validate()
    return config
  }

  public func validate() throws {
    guard !clientId.isEmpty else { throw ConfigError.missingField("client_id") }
    guard !publicUrl.isEmpty else { throw ConfigError.missingField("public_url") }
    try Self.requireWebURL(clientId, field: "client_id")
    try Self.requireWebURL(publicUrl, field: "public_url")
    guard !keys.isEmpty else { throw ConfigError.missingField("keys") }
    guard keys.contains(where: { $0.kid == activeKid }) else {
      throw ConfigError.unknownActiveKid(activeKid)
    }
    for key in keys where key.pemPath == nil && key.pemBase64 == nil {
      throw ConfigError.invalidKeyMaterial(kid: key.kid)
    }
  }

  /// https required; plain http allowed only on loopback hosts (development).
  static func requireWebURL(_ value: String, field: String) throws {
    guard let url = URL(string: value), let scheme = url.scheme, let host = url.host else {
      throw ConfigError.invalidURL(field: field, value: value)
    }
    if scheme == "https" { return }
    if scheme == "http", host == "127.0.0.1" || host == "localhost" || host == "::1" { return }
    throw ConfigError.invalidURL(field: field, value: value)
  }
}
