import Foundation
import Hummingbird
import Logging

/// Assembles the configured server. `init` builds all stateful components;
/// `buildRouter()` wires routes; `buildApplication(logger:)` returns a
/// runnable app.
public struct CABServer: Sendable {
  public let config: ServerConfig
  public let keyStore: KeyStore

  public init(config: ServerConfig) throws {
    self.config = config
    keyStore = try KeyStore(config: config)
  }

  public func buildRouter() -> Router<BasicRequestContext> {
    let router = Router(context: BasicRequestContext.self)
    router.get("/health") { _, _ in "OK" }

    // JWKS must be precomputable — fail at startup, not per request.
    let jwksBody = (try? keyStore.jwksDocument()) ?? Data()
    router.get("/.well-known/jwks.json") { _, _ -> Response in
      Response(
        status: .ok,
        headers: [.contentType: "application/json", .cacheControl: "public, max-age=300"],
        body: .init(byteBuffer: ByteBuffer(data: jwksBody))
      )
    }
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
