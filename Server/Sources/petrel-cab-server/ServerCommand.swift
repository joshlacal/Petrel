import ArgumentParser
import Logging
import PetrelCABServerCore

@main
struct ServerCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "petrel-cab-server",
    abstract: "ATProto OAuth client assertion backend",
    subcommands: [Serve.self, GenerateKey.self],
    defaultSubcommand: Serve.self
  )
}

struct Serve: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "serve",
    abstract: "Run the assertion server"
  )

  @Option(name: [.short, .long], help: "Path to a JSON config file (env vars override it)")
  var config: String?

  @Option(name: .long, help: "Log level (trace|debug|info|notice|warning|error|critical)")
  var logLevel: String = "info"

  func run() async throws {
    var logger = Logger(label: "petrel-cab-server")
    logger.logLevel = Logger.Level(rawValue: logLevel) ?? .info

    let serverConfig = try ServerConfig.load(path: config)
    let server = try CABServer(config: serverConfig)
    logger.info(
      "starting",
      metadata: [
        "client_id": .string(serverConfig.clientId),
        "public_url": .string(serverConfig.publicUrl),
        "address": .string("\(serverConfig.host):\(serverConfig.port)"),
      ]
    )
    try await server.buildApplication(logger: logger).runService()
  }
}

#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Foundation
import JSONWebAlgorithms
import JSONWebKey

struct GenerateKey: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "generate-key",
    abstract: "Generate a P-256 signing key and print its PEM + public JWK"
  )

  @Option(name: .long, help: "Key ID to embed in the JWK")
  var kid: String = "cab-key-1"

  func run() throws {
    let key = P256.Signing.PrivateKey()
    var jwk = key.publicKey.jwkRepresentation
    jwk.keyID = kid
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jwkJSON = String(data: try encoder.encode(jwk), encoding: .utf8) ?? "{}"

    print("Private key PEM (store securely — e.g. keys/\(kid).pem):\n")
    print(key.pemRepresentation)
    print("\nPublic JWK (\(kid)):\n")
    print(jwkJSON)
    print("\nBase64 PEM (for the CAB_KEY_PEM_BASE64 env var):\n")
    print(Data(key.pemRepresentation.utf8).base64EncodedString())
  }
}
