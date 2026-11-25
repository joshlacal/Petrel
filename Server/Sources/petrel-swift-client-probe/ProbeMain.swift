import ArgumentParser
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel

@main
struct ProbeCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "petrel-swift-client-probe",
    abstract: "Drives Swift Petrel ATProtoClient against a live Rust petrel-server instance."
  )

  @Option(name: .long, help: "Base URL of running petrel-rust-test-server")
  var baseUrl: String

  func run() async throws {
    guard let baseURL = URL(string: baseUrl) else {
      throw ValidationError("Invalid --base-url")
    }
    try await runPublicFlow(baseURL: baseURL)
    try await runCabFlow(baseURL: baseURL)
    print("SWIFT_PROBE_OK")
  }
}

private let aliceDID = "did:plc:alice1234567890abcdef"
private let bobDID = "did:plc:bob1234567890abcdefgh"

private func makeStorageDir() -> URL {
  let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".petrel-test-storage")
  return base.appendingPathComponent("petrel-swift-probe-\(UUID().uuidString)")
}

private func randomMasterKey() -> Data {
  Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) })
}

private func registerPublicClient(baseURL: URL, clientID: String, redirectURI: String) async throws {
  var req = URLRequest(url: baseURL.appendingPathComponent("_test/registerClient"))
  req.httpMethod = "POST"
  req.setValue("application/json", forHTTPHeaderField: "Content-Type")
  req.httpBody = try JSONSerialization.data(withJSONObject: [
    "client_id": clientID,
    "redirect_uris": [redirectURI],
    "confidential": false,
    "scope": "atproto transition:generic",
  ])
  let (_, resp) = try await performDataTask(on: .shared, request: req)
  guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
    throw ProbeError("Failed to register public client")
  }
}

private func runPublicFlow(baseURL: URL) async throws {
  let clientID = "\(baseURL.absoluteString)/public-client.json"
  let redirectURI = "http://127.0.0.1/callback"
  try await registerPublicClient(baseURL: baseURL, clientID: clientID, redirectURI: redirectURI)

  let storage = makeStorageDir()
  defer { try? FileManager.default.removeItem(at: storage) }

  let client = try await ATProtoClient(
    baseURL: baseURL,
    oauthConfig: OAuthConfig(clientId: clientID, redirectUri: redirectURI, scope: "atproto transition:generic"),
    namespace: "probe.public.\(UUID().uuidString)",
    authMode: .publicOAuth,
    didResolver: ProbeDIDResolver(pds: baseURL),
    credentialStorage: .encryptedFiles(directory: storage, masterKey: randomMasterKey())
  )

  let authURL = try await client.startOAuthFlow(identifier: "alice.example")
  let callback = try await approveConsent(
    authorizeURL: authURL,
    identifier: "alice.example",
    password: "alice-password"
  )
  try await client.handleOAuthCallback(url: callback)

  let session1 = try await client.com.atproto.server.getSession()
  guard session1.responseCode == 200, session1.data?.did.description == aliceDID else {
    throw ProbeError("Unexpected getSession response 1: \(session1.responseCode)")
  }

  let putInput = try ComAtprotoRepoPutRecord.Input(
    repo: ATIdentifier(string: aliceDID),
    collection: NSID(nsidString: "app.bsky.feed.post"),
    rkey: RecordKey(keyString: "swiftprobe1"),
    record: try ATProtocolValueContainer.decodeKnownFallback(text: "hello from swift petrel")
  )
  let putOut = try await client.com.atproto.repo.putRecord(input: putInput)
  guard putOut.responseCode == 200,
        let uri = putOut.data?.uri.uriString(),
        uri.hasPrefix("at://\(aliceDID)/")
  else {
    throw ProbeError("Unexpected putRecord response: \(putOut.responseCode)")
  }

  try await client.attemptRecoveryFromServerFailures()
  let session2 = try await client.com.atproto.server.getSession()
  guard session2.responseCode == 200, session2.data?.did.description == aliceDID else {
    throw ProbeError("Unexpected getSession after refresh: \(session2.responseCode)")
  }

  try await client.logout()
}

private func runCabFlow(baseURL: URL) async throws {
  let clientID = "\(baseURL.absoluteString)/oauth-client-metadata.json"
  let redirectURI = "\(baseURL.absoluteString)/cab-callback"

  let storage = makeStorageDir()
  defer { try? FileManager.default.removeItem(at: storage) }

  let client = try await ATProtoClient(
    baseURL: baseURL,
    oauthConfig: OAuthConfig(clientId: clientID, redirectUri: redirectURI, scope: "atproto transition:generic"),
    namespace: "probe.cab.\(UUID().uuidString)",
    authMode: .cab(backendURL: baseURL),
    didResolver: ProbeDIDResolver(pds: baseURL),
    credentialStorage: .encryptedFiles(directory: storage, masterKey: randomMasterKey())
  )

  let authURL = try await client.startOAuthFlow(identifier: "bob.example")
  let callback = try await approveConsent(
    authorizeURL: authURL,
    identifier: "bob.example",
    password: "bob-password"
  )
  try await client.handleOAuthCallback(url: callback)

  let session = try await client.com.atproto.server.getSession()
  guard session.responseCode == 200, session.data?.did.description == bobDID else {
    throw ProbeError("Unexpected CAB getSession response: \(session.responseCode)")
  }

  try await client.logout()
}

private extension ATProtocolValueContainer {
  static func decodeKnownFallback(text: String) throws -> ATProtocolValueContainer {
    let json = #"{"$type":"app.bsky.feed.post","text":"\#(text)","createdAt":"2026-01-01T00:00:00Z"}"#
    return try JSONDecoder().decode(ATProtocolValueContainer.self, from: Data(json.utf8))
  }
}

private final class NoRedirectSessionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
  func urlSession(
    _: URLSession,
    task _: URLSessionTask,
    willPerformHTTPRedirection _: HTTPURLResponse,
    newRequest _: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

private func approveConsent(
  authorizeURL: URL,
  identifier: String,
  password: String
) async throws -> URL {
  let session = URLSession(
    configuration: .ephemeral,
    delegate: NoRedirectSessionDelegate(),
    delegateQueue: nil
  )
  defer { session.finishTasksAndInvalidate() }

  let (pageData, getResp) = try await performDataTask(on: session, request: URLRequest(url: authorizeURL))
  guard let getHTTP = getResp as? HTTPURLResponse, getHTTP.statusCode == 200 else {
    throw ProbeError("GET /oauth/authorize failed")
  }
  let html = String(decoding: pageData, as: UTF8.self)
  let flowID = extractHiddenInput(html, name: "flow_id")
  let csrfToken = extractHiddenInput(html, name: "csrf_token")
  let cookieHeader = extractCookiePair(from: getHTTP, name: "__petrel_oauth_csrf")

  guard var comps = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false) else {
    throw ProbeError("Invalid authorizeURL")
  }
  comps.query = nil
  guard let actionURL = comps.url else {
    throw ProbeError("Missing actionURL")
  }

  var postReq = URLRequest(url: actionURL)
  postReq.httpMethod = "POST"
  postReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
  if let cookieHeader {
    postReq.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
  }
  postReq.httpBody = formEncode([
    ("flow_id", flowID),
    ("csrf_token", csrfToken),
    ("identifier", identifier),
    ("password", password),
    ("decision", "approve"),
  ])

  let (_, postResp) = try await performDataTask(on: session, request: postReq)
  guard let postHTTP = postResp as? HTTPURLResponse,
        (300 ..< 400).contains(postHTTP.statusCode),
        let location = postHTTP.value(forHTTPHeaderField: "Location"),
        let callbackURL = URL(string: location)
  else {
    throw ProbeError("POST /oauth/authorize did not redirect")
  }
  return callbackURL
}

private func performDataTask(
  on session: URLSession,
  request: URLRequest
) async throws -> (Data, URLResponse) {
  try await withCheckedThrowingContinuation { continuation in
    let task = session.dataTask(with: request) { data, response, error in
      if let error {
        continuation.resume(throwing: error)
        return
      }
      guard let response else {
        continuation.resume(throwing: ProbeError("Missing URLResponse"))
        return
      }
      continuation.resume(returning: (data ?? Data(), response))
    }
    task.resume()
  }
}

private func extractHiddenInput(_ html: String, name: String) -> String {
  let marker = "name=\"\(name)\" value=\""
  guard let range = html.range(of: marker) else { return "" }
  return String(html[range.upperBound...].prefix { $0 != "\"" })
}

private func extractCookiePair(from response: HTTPURLResponse, name: String) -> String? {
  let raw = response.value(forHTTPHeaderField: "Set-Cookie") ?? ""
  for part in raw.split(separator: ";") {
    let trimmed = part.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("\(name)=") {
      return trimmed
    }
  }
  return nil
}

private func formEncode(_ pairs: [(String, String)]) -> Data {
  var allowed = CharacterSet.alphanumerics
  allowed.insert(charactersIn: "-._~")
  let joined = pairs
    .map { k, v in
      let ek = k.addingPercentEncoding(withAllowedCharacters: allowed) ?? k
      let ev = v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v
      return "\(ek)=\(ev)"
    }
    .joined(separator: "&")
  return Data(joined.utf8)
}

private final class ProbeDIDResolver: DIDResolving, @unchecked Sendable {
  let pds: URL
  init(pds: URL) { self.pds = pds }

  func resolveHandleToDID(handle: String) async throws -> String {
    switch handle {
    case "alice.example": return aliceDID
    case "bob.example": return bobDID
    default: throw ProbeError("Unknown handle \(handle)")
    }
  }

  func resolveDIDToPDSURL(did _: String) async throws -> URL {
    pds
  }

  func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
    let handle = did == bobDID ? "bob.example" : "alice.example"
    return (handle, pds)
  }
}

private struct ProbeError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}
