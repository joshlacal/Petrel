import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import PetrelOAuthServer
import PetrelOAuthServerHummingbird
import Testing

@testable import petrel_oauth_server_example

/// Drives the runnable example server over HTTP the way an OAuth client and a
/// browser do: discovery, PAR, the Authorization Interface, the code exchange,
/// a DPoP-protected resource call, refresh and revocation.
@Suite("Example authorization server over Hummingbird")
struct ExampleServerEndToEndTests {
  static let origin = "http://127.0.0.1:8787"
  static let clientID = "http://localhost?redirect_uri=http%3A%2F%2F127.0.0.1%2Fcallback&scope=atproto%20transition%3Ageneric"
  static let redirectURI = "http://127.0.0.1:53124/callback"

  struct Metadata: Decodable {
    let issuer: String
    let pushed_authorization_request_endpoint: String
    let authorization_endpoint: String
    let token_endpoint: String
    let revocation_endpoint: String
    let require_pushed_authorization_requests: Bool
    let dpop_signing_alg_values_supported: [String]
  }

  struct ResourceMetadata: Decodable {
    let authorization_servers: [String]
  }

  struct PAR: Decodable {
    let request_uri: String
  }

  struct Tokens: Decodable {
    let access_token: String
    let refresh_token: String?
    let token_type: String
    let sub: String
    let scope: String
  }

  struct OAuthError: Decodable {
    let error: String
  }

  struct Session: Decodable {
    let did: String
    let handle: String?
    let canPost: Bool
  }

  struct ProofClaims: Encodable {
    let jti: String
    let htm: String
    let htu: String
    let iat: Int64
    let nonce: String?
    let ath: String?
  }

  /// A minimal OAuth client: one DPoP key and the latest server nonce.
  final class Client: @unchecked Sendable {
    let http: any TestClientProtocol
    let key: OAuthSigningKey
    var nonce: String?

    init(_ http: any TestClientProtocol) throws {
      self.http = http
      key = try OAuthSigningKey.generate()
    }

    func proof(_ method: String, _ url: String, accessToken: String? = nil) throws -> String {
      try OAuthCompactJWT.sign(
        ProofClaims(
          jti: UUID().uuidString, htm: method, htu: url,
          iat: Int64(Date().timeIntervalSince1970), nonce: nonce,
          ath: accessToken.map { OAuthPKCE.s256Challenge(for: $0) }
        ),
        with: key, type: "dpop+jwt", embedsPublicKey: true
      )
    }

    func path(_ url: String) -> String {
      String(url.dropFirst(ExampleServerEndToEndTests.origin.count))
    }

    static func form(_ fields: [(String, String)]) -> ByteBuffer {
      var allowed = CharacterSet.alphanumerics
      allowed.insert(charactersIn: "-._~")
      let text = fields.map { name, value in
        "\(name)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
      }.joined(separator: "&")
      return ByteBuffer(string: text)
    }

    /// POSTs a form with a DPoP proof, retrying once when the server asks for
    /// a nonce.
    func post(_ url: String, _ fields: [(String, String)]) async throws -> TestResponse {
      for _ in 0 ..< 2 {
        let response = try await http.execute(
          uri: path(url), method: .post,
          headers: [.contentType: "application/x-www-form-urlencoded", .init("DPoP")!: proof("POST", url)],
          body: Self.form(fields)
        )
        if let fresh = response.headers[.init("DPoP-Nonce")!] { nonce = fresh }
        if response.status == .badRequest,
           (try? JSONDecoder().decode(OAuthError.self, from: response.body))?.error == "use_dpop_nonce"
        {
          continue
        }
        return response
      }
      throw CancellationError()
    }

    /// GETs a protected resource with `Authorization: DPoP` and a proof that
    /// carries `ath`, retrying once for the nonce.
    func resource(_ url: String, accessToken: String) async throws -> TestResponse {
      var last: TestResponse?
      for _ in 0 ..< 2 {
        let response = try await http.execute(
          uri: path(url), method: .get,
          headers: [
            .authorization: "DPoP \(accessToken)",
            .init("DPoP")!: proof("GET", url, accessToken: accessToken),
          ]
        )
        if let fresh = response.headers[.init("DPoP-Nonce")!] { nonce = fresh }
        last = response
        if response.status == .unauthorized,
           response.headers[.wwwAuthenticate]?.contains("use_dpop_nonce") == true
        {
          continue
        }
        break
      }
      return try #require(last)
    }
  }

  private func cookies(_ response: TestResponse, into jar: inout [String: String]) {
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

  private func runFlow(_ http: any TestClientProtocol) async throws {
    let origin = Self.origin
    let decoder = JSONDecoder()

    // 1. Discovery, starting from the resource server as a client does.
    let resource = try await http.execute(uri: "/.well-known/oauth-protected-resource", method: .get)
    #expect(resource.status == .ok)
    let issuer = try #require(decoder.decode(ResourceMetadata.self, from: resource.body).authorization_servers.first)
    #expect(issuer == origin)
    let discovery = try await http.execute(uri: "/.well-known/oauth-authorization-server", method: .get)
    let metadata = try decoder.decode(Metadata.self, from: discovery.body)
    #expect(metadata.issuer == origin)
    #expect(metadata.require_pushed_authorization_requests)
    #expect(metadata.dpop_signing_alg_values_supported.contains("ES256"))

    // 2. Pushed authorization request.
    let client = try Client(http)
    let verifier = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    let state = UUID().uuidString
    let par = try await client.post(metadata.pushed_authorization_request_endpoint, [
      ("client_id", Self.clientID),
      ("response_type", "code"),
      ("code_challenge", OAuthPKCE.s256Challenge(for: verifier)),
      ("code_challenge_method", "S256"),
      ("state", state),
      ("redirect_uri", Self.redirectURI),
      ("scope", "atproto transition:generic"),
      ("login_hint", "demo.test"),
    ])
    #expect(par.status == .created, "\(String(buffer: par.body))")
    let requestURI = try decoder.decode(PAR.self, from: par.body).request_uri

    // 3. The browser: authorization page, sign-in, consent.
    var jar: [String: String] = [:]
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    let query = "client_id=\(try #require(Self.clientID.addingPercentEncoding(withAllowedCharacters: allowed)))"
      + "&request_uri=\(try #require(requestURI.addingPercentEncoding(withAllowedCharacters: allowed)))"
    let page = try await http.execute(uri: client.path(metadata.authorization_endpoint) + "?" + query, method: .get)
    #expect(page.status == .ok)
    #expect(page.headers[.init("X-Frame-Options")!] == "DENY")
    cookies(page, into: &jar)
    var html = String(buffer: page.body)
    #expect(html.contains("value=\"demo.test\""), "login_hint pre-fills the identifier")

    func submit(_ path: String, _ fields: [(String, String)]) async throws -> TestResponse {
      let response = try await http.execute(
        uri: path, method: .post,
        headers: [
          .contentType: "application/x-www-form-urlencoded",
          .cookie: jar.map { "\($0.key)=\($0.value)" }.joined(separator: "; "),
          .origin: origin,
        ],
        body: Client.form([("csrf", try csrf(html))] + fields)
      )
      cookies(response, into: &jar)
      return response
    }

    let consent = try await submit("/oauth/authorize/sign-in", [
      ("identifier", "demo.test"), ("password", ExampleServer.password),
    ])
    #expect(consent.status == .ok)
    html = String(buffer: consent.body)
    #expect(html.contains("name=\"decision\""))
    let approved = try await submit("/oauth/authorize/consent", [("decision", "approve")])
    #expect(approved.status == .seeOther)
    let location = try #require(approved.headers[.location])
    #expect(location.hasPrefix(Self.redirectURI + "?"))
    let callback = try #require(URLComponents(string: location)?.queryItems)
    func parameter(_ name: String) -> String? { callback.first { $0.name == name }?.value }
    #expect(parameter("state") == state)
    #expect(parameter("iss") == origin)
    let code = try #require(parameter("code"))

    // 4. Code exchange.
    let exchange = try await client.post(metadata.token_endpoint, [
      ("grant_type", "authorization_code"),
      ("client_id", Self.clientID),
      ("code", code),
      ("code_verifier", verifier),
      ("redirect_uri", Self.redirectURI),
    ])
    #expect(exchange.status == .ok, "\(String(buffer: exchange.body))")
    #expect(exchange.headers[.cacheControl] == "no-store")
    let tokens = try decoder.decode(Tokens.self, from: exchange.body)
    #expect(tokens.token_type == "DPoP")
    #expect(tokens.sub == ExampleServer.account.did)
    #expect(tokens.scope == "atproto transition:generic")

    // 5. A DPoP-protected resource request.
    let sessionURL = origin + "/xrpc/com.atproto.server.getSession"
    let authorized = try await client.resource(sessionURL, accessToken: tokens.access_token)
    #expect(authorized.status == .ok)
    let session = try decoder.decode(Session.self, from: authorized.body)
    #expect(session.did == ExampleServer.account.did)
    #expect(session.canPost)
    #expect(authorized.headers[.init("DPoP-Nonce")!] != nil, "successful responses carry a nonce too")

    // Without a token the resource answers with a DPoP challenge.
    let anonymous = try await http.execute(uri: "/xrpc/com.atproto.server.getSession", method: .get)
    #expect(anonymous.status == .unauthorized)
    #expect(anonymous.headers[.wwwAuthenticate]?.hasPrefix("DPoP") == true)

    // 6. Refresh rotates the tokens.
    let refreshed = try await client.post(metadata.token_endpoint, [
      ("grant_type", "refresh_token"),
      ("client_id", Self.clientID),
      ("refresh_token", try #require(tokens.refresh_token)),
    ])
    #expect(refreshed.status == .ok)
    let rotated = try decoder.decode(Tokens.self, from: refreshed.body)
    #expect(rotated.access_token != tokens.access_token)
    let stale = try await client.resource(sessionURL, accessToken: tokens.access_token)
    #expect(stale.status == .unauthorized, "the rotated-away access token no longer works")
    #expect(try await client.resource(sessionURL, accessToken: rotated.access_token).status == .ok)

    // 7. Revocation ends the session.
    let revoked = try await client.post(metadata.revocation_endpoint, [
      ("token", try #require(rotated.refresh_token)), ("client_id", Self.clientID),
    ])
    #expect(revoked.status == .ok)
    #expect(try await client.resource(sessionURL, accessToken: rotated.access_token).status == .unauthorized)
    let dead = try await client.post(metadata.token_endpoint, [
      ("grant_type", "refresh_token"),
      ("client_id", Self.clientID),
      ("refresh_token", try #require(rotated.refresh_token)),
    ])
    #expect(dead.status == .badRequest)
    #expect(try decoder.decode(OAuthError.self, from: dead.body).error == "invalid_grant")
  }

  @Test("the whole flow through the Hummingbird router")
  func routerFlow() async throws {
    let example = try ExampleServer(origin: #require(URL(string: Self.origin)))
    let app = Application(router: example.router())
    try await app.test(.router) { http in
      try await runFlow(http)
    }
  }

  @Test("the whole flow over a real loopback TCP connection")
  func liveFlow() async throws {
    let example = try ExampleServer(origin: #require(URL(string: Self.origin)))
    let app = Application(router: example.router(), configuration: .init(address: .hostname("127.0.0.1", port: 0)))
    try await app.test(.live) { http in
      try await runFlow(http)
    }
    // The connection's address reached the account authenticator.
    let address = example.accounts.lastSignInAddress
    #expect(address == "127.0.0.1" || address == "::1", "\(String(describing: address))")
  }

  @Test("X-Forwarded-For is honoured only from a trusted proxy, and only its right-most untrusted hop")
  func forwardedForPolicy() {
    let proxy = "10.0.0.2"
    let policy = OAuthClientAddressPolicy.forwardedFor(trustedProxies: [proxy, "10.0.0.3"])
    let forwarded = OAuthHTTPHeaders([("X-Forwarded-For", "6.6.6.6, 203.0.113.9"), ("X-Forwarded-For", "10.0.0.3")])
    // Through two trusted proxies: the hop before them.
    #expect(policy.clientAddress(peer: proxy, headers: forwarded) == "203.0.113.9")
    // From an untrusted peer the header is ignored.
    #expect(policy.clientAddress(peer: "198.51.100.7", headers: forwarded) == "198.51.100.7")
    // A trusted proxy that sent no header is the client.
    #expect(policy.clientAddress(peer: proxy, headers: OAuthHTTPHeaders()) == proxy)
    // The default never reads the header.
    #expect(OAuthClientAddressPolicy.connection.clientAddress(peer: proxy, headers: forwarded) == proxy)
  }

  /// Runs `Scripts/ts-client-interop/run.mjs`: the reference TypeScript client
  /// (`@atproto/oauth-client-node`) against the example, for a public and a
  /// confidential client. Needs node and an installed `node_modules`, so it
  /// runs only when `PETREL_TS_INTEROP_DIR` points at that directory.
  @Test(
    "the reference TypeScript client completes the flow against the example",
    .enabled(if: ProcessInfo.processInfo.environment["PETREL_TS_INTEROP_DIR"] != nil)
  )
  func typeScriptClientInterop() async throws {
    let environment = ProcessInfo.processInfo.environment
    let script = try #require(environment["PETREL_TS_INTEROP_DIR"]) + "/run.mjs"
    let port = Int(environment["PETREL_TS_INTEROP_PORT"] ?? "") ?? 18788
    let origin = "http://127.0.0.1:\(port)"
    let work = FileManager.default.temporaryDirectory.appendingPathComponent("petrel-ts-interop-\(UUID().uuidString)").path

    #expect(try await Self.run("node", [script, "--prepare", work]) == 0)
    let confidential = try ExampleServer.loadClient(at: work + "/client-metadata.json")
    let example = try ExampleServer(origin: #require(URL(string: origin)), clients: [confidential])
    let app = Application(
      router: example.router(),
      configuration: .init(address: .hostname("127.0.0.1", port: port))
    )
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { try await app.runService() }
      let status = try await Self.run(
        "node", [script, "--origin", origin, "--client-dir", work, "--log", work + "/transcript.log"]
      )
      #expect(status == 0, "see \(work)/transcript.log")
      group.cancelAll()
    }
  }

  private static func run(_ tool: String, _ arguments: [String]) async throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [tool] + arguments
    return try await withCheckedThrowingContinuation { continuation in
      process.terminationHandler = { finished in continuation.resume(returning: finished.terminationStatus) }
      do {
        try process.run()
      } catch {
        process.terminationHandler = nil
        continuation.resume(throwing: error)
      }
    }
  }

  @Test("a body over the adapter's limit is refused before it reaches the server")
  func oversizedBody() async throws {
    let example = try ExampleServer(origin: #require(URL(string: Self.origin)))
    let app = Application(router: example.router())
    try await app.test(.router) { http in
      let response = try await http.execute(
        uri: "/oauth/par", method: .post,
        headers: [.contentType: "application/x-www-form-urlencoded"],
        body: ByteBuffer(string: String(repeating: "a", count: 200_000))
      )
      #expect(response.status == .contentTooLarge)
    }
  }
}
