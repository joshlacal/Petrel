import ArgumentParser
import Foundation
import Hummingbird

@main
struct ExampleCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "petrel-oauth-server-example",
    abstract: "Runs an in-memory AT Protocol OAuth authorization server for development."
  )

  @Option(help: "The address to listen on.")
  var hostname = "127.0.0.1"

  @Option(help: "The port to listen on.")
  var port = 8787

  @Option(help: "The public origin clients use. Defaults to http://<hostname>:<port>.")
  var origin: String?

  @Option(
    name: .customLong("register-client"),
    help: """
    A client metadata JSON file (with inline jwks for a confidential client) to pre-register, \
    for clients that cannot publish their metadata at a public https URL. May be repeated. \
    When given, only registered and http://localhost development clients are accepted.
    """
  )
  var registeredClients: [String] = []

  func run() async throws {
    guard let url = URL(string: origin ?? "http://\(hostname):\(port)") else {
      throw ValidationError("origin is not a URL")
    }
    let clients = try registeredClients.map { try ExampleServer.loadClient(at: $0) }
    let example = try ExampleServer(origin: url, clients: clients)
    let app = Application(
      router: example.router(),
      configuration: .init(address: .hostname(hostname, port: port))
    )
    FileHandle.standardError.write(Data("""
    Petrel example authorization server
      issuer:   \(example.server.issuer)
      metadata: \(example.server.issuer)/.well-known/oauth-authorization-server
      account:  \(ExampleServer.account.handle ?? "") / \(ExampleServer.password)
      client:   any http://localhost development client, or a published client metadata URL

    """.utf8))
    try await app.runService()
  }
}
