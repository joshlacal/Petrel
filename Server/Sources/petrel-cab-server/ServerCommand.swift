import ArgumentParser
import Logging
import PetrelCABServerCore

@main
struct ServerCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "petrel-cab-server",
    abstract: "ATProto OAuth client assertion backend",
    subcommands: [Serve.self],
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
