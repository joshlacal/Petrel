import Hummingbird
import Logging

/// Assembles the configured server. `init` builds all stateful components;
/// `buildRouter()` wires routes; `buildApplication(logger:)` returns a
/// runnable app.
public struct CABServer: Sendable {
  public let config: ServerConfig

  public init(config: ServerConfig) throws {
    self.config = config
  }

  public func buildRouter() -> Router<BasicRequestContext> {
    let router = Router(context: BasicRequestContext.self)
    router.get("/health") { _, _ in "OK" }
    return router
  }

  public func buildApplication(logger: Logger) -> some ApplicationProtocol {
    Application(
      router: buildRouter(),
      configuration: .init(
        address: .hostname(config.host, port: config.port),
        serverName: "petrel-cab-server"
      ),
      logger: logger
    )
  }
}
