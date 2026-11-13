#if canImport(CryptoKit)
  import CryptoKit
#else
  @preconcurrency import Crypto
#endif
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Hummingbird
import HummingbirdTesting
import Logging
import Petrel
import PetrelCABServerCore
import PetrelOAuthServer
import Testing

@testable import petrel_oauth_server_example

/// Petrel's own OAuth client (`ATProtoClient`) against Petrel's own
/// authorization server (the runnable example), over a real loopback TCP
/// connection: discovery from the PDS, PAR with the DPoP nonce exchange, the
/// Authorization Interface, the code exchange and `sub` verification, a
/// DPoP-protected resource call, refresh across a server nonce rotation, and
/// revocation at logout.
///
/// The public client uses the `http://localhost` development client ID. The
/// confidential client authenticates with `private_key_jwt` assertions minted
/// by a running `petrel-cab-server` (Petrel's `.cab` mode).
///
/// The server is plain `http` on loopback. Petrel attaches an account's
/// credentials up front only to `https` origins (`ExactAuthRequestOrigin`), so
/// each resource call here is first sent without them; the server answers 401,
/// and Petrel refreshes and replays the call with the new token, which it does
/// allow for a loopback session origin. The test asserts that sequence rather
/// than hiding it.
@Suite("Petrel's OAuth client against the example authorization server", .serialized)
struct PetrelClientAgainstExampleServerTests {
  static let did = ExampleServer.account.did
  static let scope = "atproto transition:generic"

  @Test("public client: sign in, resource calls with refresh, logout revokes")
  func publicClient() async throws {
    let redirectURI = "http://127.0.0.1:53124/callback"
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    let clientID = "http://localhost?redirect_uri="
      + (try #require("http://127.0.0.1/callback".addingPercentEncoding(withAllowedCharacters: allowed)))
      + "&scope=" + (try #require(Self.scope.addingPercentEncoding(withAllowedCharacters: allowed)))

    try await Harness.run(clients: []) { harness, http in
      let client = try await harness.makeClient(
        OAuthConfig(clientId: clientID, redirectUri: redirectURI, scope: Self.scope),
        authMode: .publicOAuth
      )
      try await Self.exercise(client: client, harness: harness, http: http, rotateNonce: true)
    }
  }

  @Test("confidential client through petrel-cab-server: sign in, resource calls with refresh, logout revokes")
  func confidentialClient() async throws {
    let clientID = "https://client.example/oauth-client-metadata.json"
    let redirectURI = "https://client.example/callback"

    // The authorization server knows the client by its metadata document,
    // whose JWKS is the public half of the key the backend signs with.
    let cabKey = P256.Signing.PrivateKey()
    let point = cabKey.publicKey.x963Representation
    func base64URL(_ bytes: Data) -> String {
      bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    let key: [String: Any] = [
      "kty": "EC", "crv": "P-256", "kid": "interop-key", "alg": "ES256", "use": "sig",
      "x": base64URL(point[1 ..< 33]), "y": base64URL(point[33 ..< 65]),
    ]
    let metadata: [String: Any] = [
      "client_id": clientID,
      "client_name": "Petrel interop confidential client",
      "application_type": "web",
      "grant_types": ["authorization_code", "refresh_token"],
      "response_types": ["code"],
      "redirect_uris": [redirectURI],
      "scope": Self.scope,
      "token_endpoint_auth_method": "private_key_jwt",
      "token_endpoint_auth_signing_alg": "ES256",
      "dpop_bound_access_tokens": true,
      "jwks": ["keys": [key]],
    ]
    let document = try OAuthClientMetadata.decodeValidated(
      JSONSerialization.data(withJSONObject: metadata), responseURL: #require(URL(string: clientID))
    )
    let registered = OAuthResolvedClientMetadata(metadata: document, keySet: document.jwks)
    let cabPEM = Data(cabKey.pemRepresentation.utf8).base64EncodedString()

    try await Harness.run(clients: [registered]) { harness, http in
      // The client assertion backend, minting assertions for this server only.
      let cabPort = Int.random(in: 20000 ..< 40000)
      let configuration = try JSONDecoder().decode(ServerConfig.self, from: Data("""
        {
          "client_id": "\(clientID)",
          "public_url": "http://127.0.0.1:\(cabPort)",
          "host": "127.0.0.1",
          "port": \(cabPort),
          "keys": [{ "kid": "interop-key", "pem_base64": "\(cabPEM)" }],
          "active_kid": "interop-key",
          "aud_allowlist": ["\(harness.origin)"]
        }
        """.utf8))
      try configuration.validate()
      var logger = Logger(label: "petrel-client-interop.cab")
      logger.logLevel = .error
      let cab = try CABServer(config: configuration).buildApplication(logger: logger)
      let cabTask = Task { try await cab.runService() }
      defer { cabTask.cancel() }
      try await waitUntilServing(#require(URL(string: "http://127.0.0.1:\(cabPort)/health")))

      let client = try await harness.makeClient(
        OAuthConfig(clientId: clientID, redirectUri: redirectURI, scope: Self.scope),
        authMode: .cab(backendURL: #require(URL(string: "http://127.0.0.1:\(cabPort)")))
      )
      try await Self.exercise(client: client, harness: harness, http: http, rotateNonce: false)
    }
  }

  // MARK: - The scenario both client shapes run

  private static func exercise(
    client: ATProtoClient,
    harness: Harness,
    http: any TestClientProtocol,
    rotateNonce: Bool
  ) async throws {
    let origin = harness.origin
    // Discovery starts from the account's PDS, which names this server.
    let authorizationURL = try await client.startOAuthFlow(identifier: did)
    #expect(authorizationURL.absoluteString.hasPrefix(origin + "/oauth/authorize?"))
    #expect(harness.log.contains("GET", "/.well-known/oauth-protected-resource", 200))
    #expect(harness.log.contains("GET", "/.well-known/oauth-authorization-server", 200))
    #expect(harness.log.contains("POST", "/oauth/par", 201))

    // The browser: authorization page, sign-in, consent.
    let callback = try await Browser(http: http, origin: origin).authorize(authorizationURL)
    try await client.handleOAuthCallback(url: callback)
    #expect(harness.log.contains("POST", "/oauth/token", 200))
    #expect(try await harness.example.server.sessions(subject: did).count == 1)

    // A DPoP-protected call. Sent first without credentials (plain http),
    // refused, then replayed after a refresh.
    let beforeCall = harness.log.entries.count
    let first = try await client.com.atproto.server.getSession()
    #expect(first.responseCode == 200)
    #expect(first.data.map { "\($0.did)" } == did)
    let call = Array(harness.log.entries[beforeCall...])
    #expect(call.map(\.summary) == [
      "GET /xrpc/com.atproto.server.getSession 401",
      "POST /oauth/token 200",
      "GET /xrpc/com.atproto.server.getSession 200",
    ], "\(call)")

    // The server's DPoP nonce rotates two 60-second intervals past the one
    // the client holds, so the client's nonce is no longer accepted. The
    // client takes the current one from the 401's DPoP-Nonce header, and the
    // refresh and the replay go through without a nonce retry. (Client DPoP
    // proofs carry the real time and expire 120 seconds after issue; client
    // assertions expire sooner, so only the public client moves the clock.)
    if rotateNonce {
      let nonce = harness.example.verifier.currentNonce()
      harness.clock.advance(125)
      #expect(harness.example.verifier.currentNonce() != nonce)
    }
    let beforeSecond = harness.log.entries.count
    #expect(try await client.com.atproto.server.getSession().responseCode == 200)
    let second = Array(harness.log.entries[beforeSecond...])
    #expect(second.map(\.summary) == call.map(\.summary), "\(second)")
    #expect(try await harness.example.server.sessions(subject: did).count == 1, "refresh rotates within one session")

    // Logout revokes the session at the authorization server.
    let beforeLogout = harness.log.entries.count
    try await client.logout()
    #expect(harness.log.entries[beforeLogout...].map(\.summary) == ["POST /oauth/revoke 200"])
    #expect(try await harness.example.server.sessions(subject: did).isEmpty, "logout revoked the session")
  }
}

// MARK: - Harness

/// The example server on a free loopback port with a movable clock and a
/// request log, and the client-side fixtures that point at it.
private struct Harness: Sendable {
  let origin: String
  let clock = OffsetClock()
  let log = RequestLog()
  let example: ExampleServer
  let storage: URL

  private init(origin: String, clients: [OAuthResolvedClientMetadata]) throws {
    self.origin = origin
    example = try ExampleServer(origin: #require(URL(string: origin)), clients: clients, clock: clock)
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".petrel-test-storage")
    storage = base.appendingPathComponent("petrel-client-interop-\(UUID().uuidString)")
  }

  /// Serves the example over TCP on a port the system picks, for the client,
  /// and runs `body` with an in-process connection to the same server for the
  /// browser. The server's origin includes the port, so the example is
  /// created once the listener is up, before any request reaches it.
  static func run(
    clients: [OAuthResolvedClientMetadata],
    _ body: @Sendable (Harness, any TestClientProtocol) async throws -> Void
  ) async throws {
    var logger = Logger(label: "petrel-client-interop")
    logger.logLevel = .error
    let late = LateResponder(context: contextType(of: ExampleServer.router))
    let (ports, listening) = AsyncStream.makeStream(of: Int.self)
    let live = Application(
      responder: late,
      configuration: .init(address: .hostname("127.0.0.1", port: 0)),
      onServerRunning: { channel in
        listening.yield(channel.localAddress?.port ?? 0)
        listening.finish()
      },
      logger: logger
    )
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { try await live.runService() }
      defer { group.cancelAll() }
      var iterator = ports.makeAsyncIterator()
      let port = try #require(await iterator.next())
      let harness = try Harness(origin: "http://127.0.0.1:\(port)", clients: clients)
      defer { try? FileManager.default.removeItem(at: harness.storage) }
      let responder = RecordingResponder(inner: harness.example.router().buildResponder(), log: harness.log)
      late.bind(responder)
      let browser = Application(responder: responder, logger: logger)
      try await browser.test(.router) { http in
        do {
          try await body(harness, http)
        } catch {
          Issue.record("requests the server answered: \(harness.log.entries)")
          throw error
        }
      }
    }
  }

  /// A client whose PDS, for the demo account, is this server.
  func makeClient(_ configuration: OAuthConfig, authMode: AuthMode) async throws -> ATProtoClient {
    var key = Data(count: 32)
    for index in key.indices {
      key[index] = UInt8.random(in: .min ... .max)
    }
    return try await ATProtoClient(
      baseURL: #require(URL(string: origin)),
      oauthConfig: configuration,
      namespace: "petrel.client-interop.\(UUID().uuidString)",
      authMode: authMode,
      didResolver: LoopbackDIDResolver(did: PetrelClientAgainstExampleServerTests.did, pds: #require(URL(string: origin))),
      credentialStorage: .encryptedFiles(directory: storage, masterKey: key)
    )
  }
}

/// The request context type of the example's router.
private func contextType<Context>(of _: (ExampleServer) -> () -> Router<Context>) -> Context.Type {
  Context.self
}

/// A responder whose target is set after the listener is up. Nothing can
/// reach it earlier: the client learns the port only afterwards.
private final class LateResponder<Context: RequestContext>: HTTPResponder, @unchecked Sendable {
  private let lock = NSLock()
  private var target: (@Sendable (Request, Context) async throws -> Response)?

  init(context _: Context.Type) {}

  func bind<Inner: HTTPResponder>(_ responder: Inner) where Inner.Context == Context {
    lock.withLock { target = { try await responder.respond(to: $0, context: $1) } }
  }

  func respond(to request: Request, context: Context) async throws -> Response {
    guard let target = lock.withLock({ target }) else { return Response(status: .serviceUnavailable) }
    return try await target(request, context)
  }
}

/// Waits until `url` answers 200, for a server started in the background. A
/// random port can collide with another process; the test then fails here.
private func waitUntilServing(_ url: URL) async throws {
  for _ in 0 ..< 100 {
    if let (_, response) = try? await URLSession.shared.data(from: url),
       (response as? HTTPURLResponse)?.statusCode == 200
    {
      return
    }
    try await Task.sleep(nanoseconds: 50_000_000)
  }
  Issue.record("nothing answered at \(url)")
  throw URLError(.cannotConnectToHost)
}

/// The server's clock: the real time plus an offset the test moves forward.
/// Client DPoP proofs carry the real time, so the offset stays inside the
/// server's proof window.
private final class OffsetClock: OAuthClock, @unchecked Sendable {
  private let lock = NSLock()
  private var offset: TimeInterval = 0

  func now() -> Date {
    Date().addingTimeInterval(lock.withLock { offset })
  }

  func advance(_ seconds: TimeInterval) {
    lock.withLock { offset += seconds }
  }
}

/// Resolves the demo account to the loopback server.
private final class LoopbackDIDResolver: DIDResolving, @unchecked Sendable {
  let did: String
  let pds: URL

  init(did: String, pds: URL) {
    self.did = did
    self.pds = pds
  }

  func resolveHandleToDID(handle: String) async throws -> String {
    guard handle == (ExampleServer.account.handle ?? "") else { throw URLError(.cannotFindHost) }
    return did
  }

  func resolveDIDToPDSURL(did: String) async throws -> URL {
    guard did == self.did else { throw URLError(.cannotFindHost) }
    return pds
  }

  func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
    guard did == self.did else { throw URLError(.cannotFindHost) }
    return (ExampleServer.account.handle ?? "", pds)
  }
}

/// Every request the server answered: method, path, status and any
/// `WWW-Authenticate` challenge.
private final class RequestLog: @unchecked Sendable {
  struct Entry: Sendable, CustomStringConvertible {
    let method: String
    let path: String
    let status: Int
    let challenge: String
    let detail: String
    var summary: String { "\(method) \(path) \(status)" }
    var description: String { "\(summary) \(challenge) \(detail)" }
  }

  private let lock = NSLock()
  private var recorded: [Entry] = []

  var entries: [Entry] { lock.withLock { recorded } }

  func append(_ entry: Entry) {
    lock.withLock { recorded.append(entry) }
  }

  func contains(_ method: String, _ path: String, _ status: Int) -> Bool {
    entries.contains { $0.method == method && $0.path == path && $0.status == status }
  }
}

private struct RecordingResponder<Inner: HTTPResponder>: HTTPResponder {
  let inner: Inner
  let log: RequestLog

  func respond(to request: Request, context: Inner.Context) async throws -> Response {
    var response = try await inner.respond(to: request, context: context)
    // Error bodies are small; keep them so a failure can say what was refused.
    var detail = ""
    if response.status.code >= 400 {
      let collector = BodyCollector()
      try await response.body.write(collector)
      let body = collector.buffer
      detail = String(buffer: body)
      response.body = ResponseBody(byteBuffer: body)
    }
    log.append(.init(
      method: request.method.rawValue,
      path: request.uri.path,
      status: response.status.code,
      challenge: response.headers[.wwwAuthenticate] ?? "",
      detail: detail
    ))
    return response
  }
}

private final class BodyCollector: ResponseBodyWriter, @unchecked Sendable {
  var buffer = ByteBuffer()
  func write(_ buffer: ByteBuffer) async throws {
    var copy = buffer
    self.buffer.writeBuffer(&copy)
  }

  func finish(_: HTTPFields?) async throws {}
}

/// The user's browser on the Authorization Interface: loads the page, signs
/// in as the demo account, approves, and returns the redirect it was sent.
private struct Browser {
  let http: any TestClientProtocol
  let origin: String

  func authorize(_ authorizationURL: URL) async throws -> URL {
    let components = try #require(URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false))
    var jar: [String: String] = [:]
    let page = try await http.execute(uri: components.path + "?" + (components.percentEncodedQuery ?? ""), method: .get)
    #expect(page.status == .ok)
    store(page, into: &jar)
    var html = String(buffer: page.body)

    func submit(_ path: String, _ fields: [(String, String)]) async throws -> TestResponse {
      var allowed = CharacterSet.alphanumerics
      allowed.insert(charactersIn: "-._~")
      let body = try ([("csrf", csrf(html))] + fields).map { name, value in
        "\(name)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
      }.joined(separator: "&")
      let response = try await http.execute(
        uri: path, method: .post,
        headers: [
          .contentType: "application/x-www-form-urlencoded",
          .cookie: jar.map { "\($0.key)=\($0.value)" }.joined(separator: "; "),
          .origin: origin,
        ],
        body: ByteBuffer(string: body)
      )
      store(response, into: &jar)
      return response
    }

    let consent = try await submit("/oauth/authorize/sign-in", [
      ("identifier", ExampleServer.account.handle ?? ""), ("password", ExampleServer.password),
    ])
    #expect(consent.status == .ok)
    html = String(buffer: consent.body)
    let approved = try await submit("/oauth/authorize/consent", [("decision", "approve")])
    #expect(approved.status == .seeOther)
    return try #require(approved.headers[.location].flatMap(URL.init(string:)))
  }

  private func store(_ response: TestResponse, into jar: inout [String: String]) {
    for field in response.headers where field.name == .setCookie {
      guard let pair = field.value.split(separator: ";").first, let separator = pair.firstIndex(of: "=") else { continue }
      let value = String(pair[pair.index(after: separator)...])
      jar[String(pair[..<separator])] = value.isEmpty ? nil : value
    }
  }

  private func csrf(_ page: String) throws -> String {
    let marker = "name=\"csrf\" value=\""
    let range = try #require(page.range(of: marker))
    return String(page[range.upperBound...].prefix { $0 != "\"" })
  }
}
