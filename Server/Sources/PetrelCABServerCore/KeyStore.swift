#if canImport(CryptoKit)
  @preconcurrency import CryptoKit
#else
  @preconcurrency import Crypto
#endif
import Foundation
import PetrelCrypto

/// Minimal ES256 JWK representation for DPoP proof headers and RFC 7638 thumbprints.
public struct JWK: Codable, Sendable, Equatable {
  public let kty: String
  public let crv: String
  public let kid: String?
  public let x: String
  public let y: String
  public let alg: String?
  public let d: String?

  public init(
    kty: String = "EC",
    crv: String = "P-256",
    kid: String? = nil,
    x: String,
    y: String,
    alg: String? = nil,
    d: String? = nil
  ) {
    self.kty = kty
    self.crv = crv
    self.kid = kid
    self.x = x
    self.y = y
    self.alg = alg
    self.d = d
  }

  public init(publicKey: P256.Signing.PublicKey, kid: String? = nil, alg: String? = nil) {
    let x963 = publicKey.x963Representation
    let x = x963.dropFirst().prefix(32)
    let y = x963.suffix(32)
    self.init(
      kty: "EC",
      crv: "P-256",
      kid: kid,
      x: JWTBase64URL.encode(Data(x)),
      y: JWTBase64URL.encode(Data(y)),
      alg: alg
    )
  }

  /// Computes the RFC 7638 SHA-256 thumbprint for this EC P-256 key.
  public func thumbprint() throws -> String {
    let canonicalJSON = "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(x)\",\"y\":\"\(y)\"}"
    let hash = SHA256.hash(data: Data(canonicalJSON.utf8))
    return JWTBase64URL.encode(Data(hash))
  }
}

public struct SigningKey: Sendable {
  public let kid: String
  public let privateKey: P256.Signing.PrivateKey

  public var publicJWK: JWK {
    JWK(publicKey: privateKey.publicKey, kid: kid)
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
      JWK(publicKey: key.privateKey.publicKey, kid: key.kid, alg: "ES256")
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(JWKSet(keys: publicKeys))
  }
}
