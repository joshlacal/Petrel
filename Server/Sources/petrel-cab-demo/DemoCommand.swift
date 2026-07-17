import ArgumentParser
import Foundation
import Hummingbird
import Logging
import Petrel

@main
struct DemoCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "petrel-cab-demo",
    abstract: "End-to-end demo: log into an ATProto account via a CAB backend",
    subcommands: [Login.self, Refresh.self],
    defaultSubcommand: Login.self
  )
}

struct Refresh: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "refresh",
    abstract: "Force a token refresh for the session stored by a previous login"
  )

  @Option(name: .long, help: "CAB backend base URL")
  var backend: String

  @Option(name: .long, help: "client_id URL (must match the backend's client_id)")
  var clientId: String

  @Option(name: .long, help: "Redirect URI used at login (config consistency only)")
  var redirectUri: String

  @Option(name: .long, help: "OAuth scope")
  var scope: String = "atproto transition:generic"

  func run() async throws {
    guard let backendURL = URL(string: backend) else {
      throw ValidationError("--backend is not a valid URL")
    }
    let client = try await ATProtoClient(
      oauthConfig: OAuthConfig(clientId: clientId, redirectUri: redirectUri, scope: scope),
      namespace: "blue.catbird.cabdemo",
      authMode: .cab(backendURL: backendURL),
      userAgent: "petrel-cab-demo/1.0"
    )
    // `attemptRecoveryFromServerFailures` silently returns (no throw) when there
    // is no current account — CABOAuthStrategy's `guard let did = targetDID else
    // { return }` — which would otherwise print a false PASS with zero backend
    // contact if `refresh` is run without a prior `login`. Require a stored
    // session up front.
    let (did, _, _) = await client.getActiveAccountInfo()
    guard did != nil else {
      print("REFRESH RESULT: FAIL — no_stored_session")
      throw ExitCode.failure
    }

    // `client.refreshToken()` short-circuits to `.stillValid` (→ `false`) whenever
    // the stored token isn't within its expiry buffer yet, so a healthy session
    // would report FAIL without ever contacting the backend. Force a real refresh
    // instead: `attemptRecoveryFromServerFailures` resets the local circuit
    // breaker and calls the strategy's `refreshTokenIfNeeded(forceRefresh: true)`,
    // which never short-circuits and never returns a silent `false` — the backend
    // either approves the exchange (no throw) or vetoes it (throws), so a thrown
    // error here is a genuine backend refusal.
    do {
      try await client.attemptRecoveryFromServerFailures()
      print("REFRESH RESULT: PASS")
    } catch {
      print("REFRESH RESULT: FAIL — \(error)")
      throw ExitCode.failure
    }
  }
}

struct Login: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "login",
    abstract: "Run the full CAB OAuth flow and verify an authenticated call + refresh"
  )

  @Option(name: .long, help: "Account handle to log in (e.g. alice.bsky.social)")
  var handle: String

  @Option(name: .long, help: "CAB backend base URL (e.g. https://xxx.trycloudflare.com)")
  var backend: String

  @Option(name: .long, help: "client_id URL (must match the backend's client_id)")
  var clientId: String

  @Option(
    name: .long,
    help: "Public https redirect URI (fronted by a tunnel that forwards to --callback-port)"
  )
  var redirectUri: String

  @Option(name: .long, help: "Local port the callback listener binds on 127.0.0.1")
  var callbackPort: Int = 8378

  @Option(name: .long, help: "OAuth scope")
  var scope: String = "atproto transition:generic"

  func run() async throws {
    guard let backendURL = URL(string: backend) else {
      throw ValidationError("--backend is not a valid URL")
    }

    let client = try await ATProtoClient(
      oauthConfig: OAuthConfig(clientId: clientId, redirectUri: redirectUri, scope: scope),
      namespace: "blue.catbird.cabdemo",
      authMode: .cab(backendURL: backendURL),
      userAgent: "petrel-cab-demo/1.0"
    )

    // 1. Start the flow (PAR with client assertion happens inside Petrel).
    let authURL = try await client.startOAuthFlow(identifier: handle)
    print("\n[1/5] Authorization URL (opening in browser):\n\(authURL.absoluteString)\n")
    #if os(macOS)
      let opener = Process()
      opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      opener.arguments = [authURL.absoluteString]
      try? opener.run()
    #endif

    // 2. Catch the redirect on a local listener (the tunnel forwards the
    //    public https redirect URI here).
    print("[2/5] Waiting for the OAuth callback on 127.0.0.1:\(callbackPort) …")
    let query = try await Self.waitForCallback(port: callbackPort)
    guard let callbackURL = URL(string: "\(redirectUri)?\(query)") else {
      throw ValidationError("could not reconstruct callback URL")
    }

    // 3. Exchange the code (fresh client assertion fetched inside Petrel).
    try await client.handleOAuthCallback(url: callbackURL)
    print("[3/5] Token exchange complete.")

    // 4. Authenticated call.
    let (code, session) = try await client.com.atproto.server.getSession()
    guard code == 200, let session else {
      print("E2E RESULT: FAIL — getSession returned \(code)")
      throw ExitCode.failure
    }
    print("[4/5] Authenticated as \(session.handle) (\(session.did))")

    // 5. Forced refresh (assertion-authenticated), then prove the new
    //    tokens work. `client.refreshToken()` would short-circuit to `.stillValid`
    //    (→ `false`) here since the token minted in step 3 is fresh — that would
    //    fail this gate on every healthy run. `attemptRecoveryFromServerFailures`
    //    forces a real `refreshTokenIfNeeded(forceRefresh: true)` network call,
    //    which never short-circuits: it either succeeds (no throw) or the backend
    //    veto surfaces as a thrown error.
    do {
      try await client.attemptRecoveryFromServerFailures()
    } catch {
      print("E2E RESULT: FAIL — forced refresh failed: \(error)")
      throw ExitCode.failure
    }
    let (codeAfter, _) = try await client.com.atproto.server.getSession()
    guard codeAfter == 200 else {
      print("E2E RESULT: FAIL — getSessionAfter=\(codeAfter)")
      throw ExitCode.failure
    }
    print("[5/5] Forced token refresh + re-verified session.")
    print("\nE2E RESULT: PASS — handle=\(session.handle) did=\(session.did)")
  }

  /// One-shot HTTP listener: serves GET /callback, returns its raw query
  /// string, then shuts down.
  static func waitForCallback(port: Int) async throws -> String {
    let (stream, continuation) = AsyncStream<String>.makeStream()
    let router = Router(context: BasicRequestContext.self)
    router.get("/callback") { request, _ -> Response in
      continuation.yield(request.uri.query ?? "")
      return Response(
        status: .ok,
        headers: [.contentType: "text/html; charset=utf-8"],
        body: .init(byteBuffer: ByteBuffer(
          string: "<html><body><h2>Login complete</h2><p>Return to the terminal.</p></body></html>"
        ))
      )
    }
    var logger = Logger(label: "cab-demo-callback")
    logger.logLevel = .error
    let app = Application(
      router: router,
      configuration: .init(address: .hostname("127.0.0.1", port: port)),
      logger: logger
    )
    let serverTask = Task { try await app.runService() }
    defer { serverTask.cancel() }

    var iterator = stream.makeAsyncIterator()
    guard let query = await iterator.next() else {
      throw ValidationError("callback listener ended without a request")
    }
    // Give the response a moment to flush before the listener dies.
    try await Task.sleep(nanoseconds: 500_000_000)
    return query
  }
}
