import Foundation
import Hummingbird
import PetrelOAuthServer
import PetrelOAuthServerHummingbird

/// A complete, runnable AT Protocol OAuth authorization server with a stub
/// resource server, for development and interoperability testing.
///
/// Everything is in memory and nothing is secret: one demo account, loopback
/// development clients accepted, and state that disappears on exit. It shows
/// the whole integration surface a real PDS fills in: an account
/// authenticator, a store, a client resolver and a protected route.
public struct ExampleServer: Sendable {
  /// The demo account.
  public static let account = OAuthAccount(did: "did:plc:petrelexampledemoaccount", handle: "demo.test")
  /// The demo account's password.
  public static let password = "petrel-demo"

  /// The authorization server.
  public let server: OAuthAuthorizationServer
  /// The resource-server verifier sharing its stores.
  public let verifier: OAuthResourceServerVerifier
  /// The origin clients address the server by.
  public let origin: URL
  /// The account system, which remembers the address of the last sign-in.
  let accounts = DemoAccounts()

  /// Creates the example for an origin such as `http://127.0.0.1:8787`.
  ///
  /// - Parameters:
  ///   - origin: the public origin. `http` is accepted for loopback only.
  ///   - clients: additional pre-registered clients, for tests that cannot
  ///     publish a metadata document. Discoverable `https` clients and
  ///     `http://localhost` development clients work without registration.
  ///   - clock: the time source.
  public init(
    origin: URL,
    clients: [OAuthResolvedClientMetadata] = [],
    clock: any OAuthClock = SystemOAuthClock()
  ) throws {
    self.origin = origin
    let store = InMemoryOAuthStore()
    var secret = Data(count: 32)
    for index in secret.indices {
      secret[index] = UInt8.random(in: .min ... .max)
    }
    let resolver: any OAuthClientResolving = try clients.isEmpty
      ? OAuthClientMetadataLoader(
        fetcher: OAuthRemoteDocumentFetcher(
          policy: OAuthRemoteFetchPolicy(),
          transport: PinnedNIOOAuthRemoteTransport()
        ),
        cache: store
      )
      : StaticOAuthClientResolver(clients)
    server = try OAuthAuthorizationServer(
      configuration: OAuthAuthorizationServerConfiguration(
        issuer: origin,
        serverSecret: secret,
        secureCookies: origin.scheme == "https"
      ),
      store: store,
      accounts: accounts,
      clients: resolver,
      interface: OAuthDefaultInterface(serviceName: "Petrel example server"),
      clock: clock
    )
    verifier = OAuthResourceServerVerifier(authorizationServer: server)
  }

  /// Reads and validates a client metadata document from a file, for
  /// pre-registering a client whose `client_id` cannot be fetched.
  public static func loadClient(at path: String) throws -> OAuthResolvedClientMetadata {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    struct ClientID: Decodable {
      let client_id: URL
    }
    let clientID = try JSONDecoder().decode(ClientID.self, from: data).client_id
    let metadata = try OAuthClientMetadata.decodeValidated(data, responseURL: clientID)
    return OAuthResolvedClientMetadata(metadata: metadata, keySet: metadata.jwks)
  }

  /// The router: every OAuth endpoint, plus one protected XRPC method.
  public func router() -> Router<OAuthServerRequestContext> {
    let router = Router(context: OAuthServerRequestContext.self)
    OAuthServerHummingbird.addRoutes(to: router, server: server)

    router.get("/health") { _, _ in "OK" }

    // A protected resource: who am I, and may I post?
    let verifier = self.verifier
    let origin = self.origin
    router.get("/xrpc/com.atproto.server.getSession") { request, _ -> Response in
      switch await OAuthServerHummingbird.authenticate(request, verifier: verifier, publicOrigin: origin) {
      case let .failure(challenge):
        return challenge.response
      case let .success(grant):
        struct Session: Encodable {
          let did: String
          let handle: String?
          let scope: String
          let canPost: Bool
        }
        let body = Session(
          did: grant.subject,
          handle: grant.subject == Self.account.did ? Self.account.handle : nil,
          scope: grant.permissions.rawScopes.sorted().joined(separator: " "),
          canPost: grant.permissions.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var response = OAuthHTTPResponse(
          status: 200,
          headers: OAuthHTTPHeaders([
            ("Content-Type", "application/json"),
            // Every response carries a nonce, so clients always hold a current one.
            ("DPoP-Nonce", verifier.currentNonce()),
            ("Access-Control-Expose-Headers", "DPoP-Nonce, WWW-Authenticate"),
          ])
        )
        response.body = (try? encoder.encode(body)) ?? Data()
        return OAuthServerHummingbird.response(response)
      }
    }
    return router
  }
}

/// The example's account system: one account, one password. A real one limits
/// attempts per account and per `context.remoteAddress`.
final class DemoAccounts: OAuthAccountAuthenticating, @unchecked Sendable {
  private let lock = NSLock()
  private var lastAddress: String?

  /// The client address of the most recent sign-in attempt.
  var lastSignInAddress: String? {
    lock.withLock { lastAddress }
  }

  func signIn(identifier: String, password: String, context: OAuthSignInContext) async throws -> OAuthSignInResult {
    lock.withLock { lastAddress = context.remoteAddress }
    let account = ExampleServer.account
    guard identifier == account.handle || identifier == account.did, password == ExampleServer.password else {
      return .rejected
    }
    return .authenticated(account)
  }

  func account(did: String) async throws -> OAuthAccount? {
    did == ExampleServer.account.did ? ExampleServer.account : nil
  }

  func resolveLoginHint(_ hint: String) async throws -> String? {
    hint == ExampleServer.account.handle || hint == ExampleServer.account.did ? ExampleServer.account.did : nil
  }
}
