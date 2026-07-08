#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import JSONWebAlgorithms
import JSONWebKey

public struct SigningKey: Sendable {
  public let kid: String
  public let privateKey: P256.Signing.PrivateKey

  public var publicJWK: JWK {
    var jwk = privateKey.publicKey.jwkRepresentation
    jwk.keyID = kid
    return jwk
  }
}

public struct KeyStore: Sendable {
  public let keys: [SigningKey]
  public let activeKid: String

  public var activeKey: SigningKey {
    // Presence is guaranteed by init.
    keys.first { $0.kid == activeKid }!
  }

  public init(config: ServerConfig) throws {
    var loaded: [SigningKey] = []
    for keyConfig in config.keys {
      let pem: String
      if let path = keyConfig.pemPath {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
          throw ConfigError.invalidKeyMaterial(kid: keyConfig.kid)
        }
        pem = contents
      } else if let base64 = keyConfig.pemBase64 {
        guard let data = Data(base64Encoded: base64),
              let contents = String(data: data, encoding: .utf8)
        else {
          throw ConfigError.invalidKeyMaterial(kid: keyConfig.kid)
        }
        pem = contents
      } else {
        throw ConfigError.invalidKeyMaterial(kid: keyConfig.kid)
      }
      guard let privateKey = try? P256.Signing.PrivateKey(pemRepresentation: pem) else {
        throw ConfigError.invalidKeyMaterial(kid: keyConfig.kid)
      }
      loaded.append(SigningKey(kid: keyConfig.kid, privateKey: privateKey))
    }
    guard loaded.contains(where: { $0.kid == config.activeKid }) else {
      throw ConfigError.unknownActiveKid(config.activeKid)
    }
    keys = loaded
    activeKid = config.activeKid
  }

  /// RFC 7517 JWK Set of every configured public key. All keys stay
  /// published so assertions signed before a rotation keep verifying.
  public func jwksDocument() throws -> Data {
    struct JWKSet: Encodable {
      let keys: [JWK]
    }
    let publicKeys = keys.map { key -> JWK in
      var jwk = key.publicJWK
      jwk.algorithm = "ES256"
      return jwk
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(JWKSet(keys: publicKeys))
  }
}
