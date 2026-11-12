import Foundation
@testable import PetrelOAuthServer
import PetrelCrypto
import Testing

/// A clock tests can move.
final class TestClock: OAuthClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        current = start
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}

/// A tiny account system: handle + password, optional second factor, and a
/// switch to disable an account.
final class TestAccounts: OAuthAccountAuthenticating, @unchecked Sendable {
    struct Entry {
        let account: OAuthAccount
        let password: String
        var secondFactorCode: String?
        var disabled = false
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private(set) var signInAttempts = 0

    static let alice = OAuthAccount(did: "did:plc:alicealicealicealicealice", handle: "alice.test")
    static let bob = OAuthAccount(did: "did:plc:bobbobbobbobbobbobbobbob", handle: "bob.test")

    init() {
        entries[Self.alice.did] = Entry(account: Self.alice, password: "alice-password")
        entries[Self.bob.did] = Entry(account: Self.bob, password: "bob-password")
    }

    func requireSecondFactor(_ did: String, code: String) {
        lock.lock()
        entries[did]?.secondFactorCode = code
        lock.unlock()
    }

    func disable(_ did: String) {
        lock.lock()
        entries[did]?.disabled = true
        lock.unlock()
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    func signIn(identifier: String, password: String, context _: OAuthSignInContext) async throws -> OAuthSignInResult {
        locked {
            signInAttempts += 1
            guard let entry = entries.values.first(where: {
                $0.account.handle == identifier || $0.account.did == identifier
            }), !entry.disabled, entry.password == password
            else { return .rejected }
            if entry.secondFactorCode != nil {
                return .secondFactorRequired(.init(subject: entry.account.did, prompt: "Enter your code"))
            }
            return .authenticated(entry.account)
        }
    }

    func verifySecondFactor(
        _ challenge: OAuthSecondFactorChallenge,
        code: String,
        context _: OAuthSignInContext
    ) async throws -> OAuthSignInResult {
        locked {
            guard let entry = entries[challenge.subject], entry.secondFactorCode == code else { return .rejected }
            return .authenticated(entry.account)
        }
    }

    func account(did: String) async throws -> OAuthAccount? {
        locked {
            guard let entry = entries[did], !entry.disabled else { return nil }
            return entry.account
        }
    }

    func resolveLoginHint(_ hint: String) async throws -> String? {
        locked {
            entries.values.first { $0.account.handle == hint || $0.account.did == hint }?.account.did
        }
    }
}

/// A client resolver whose table tests can change, to model a client rotating
/// or removing a key.
final class MutableClientResolver: OAuthClientResolving, @unchecked Sendable {
    private let lock = NSLock()
    private var clients: [String: OAuthResolvedClientMetadata] = [:]
    private(set) var revalidations = 0

    func register(_ client: OAuthResolvedClientMetadata) {
        lock.lock()
        clients[client.metadata.clientID.absoluteString] = client
        lock.unlock()
    }

    func resolve(clientID: URL, revalidate: Bool, now _: Date) async throws -> OAuthResolvedClientMetadata {
        if OAuthClientMetadata.isLoopbackDevelopmentClientID(clientID) {
            return try OAuthResolvedClientMetadata(
                metadata: OAuthClientMetadata.loopbackDevelopmentMetadata(clientID: clientID), keySet: nil
            )
        }
        return try lookup(clientID.absoluteString, revalidate: revalidate)
    }

    private func lookup(_ key: String, revalidate: Bool) throws -> OAuthResolvedClientMetadata {
        lock.lock()
        defer { lock.unlock() }
        if revalidate { revalidations += 1 }
        guard let client = clients[key] else {
            throw OAuthServerError.unauthorized("OAuth client is not registered")
        }
        return client
    }
}

struct TestHTTPError: Error, CustomStringConvertible {
    let description: String
}

struct ErrorPayload: Decodable {
    let error: String
    let error_description: String?
}

extension OAuthHTTPResponse {
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: body)
    }

    var oauthError: String? { (try? decode(ErrorPayload.self))?.error }
    var text: String { String(decoding: body, as: UTF8.self) }
}

func formBody(_ fields: [(String, String)]) -> Data {
    Data(fields.map { "\(OAuthForm.encodeComponent($0.0))=\(OAuthForm.encodeComponent($0.1))" }
        .joined(separator: "&").utf8)
}

struct DPoPClaims: Encodable {
    var jti: String
    var htm: String
    var htu: String
    var iat: Int64
    var nonce: String?
    var ath: String?
}

func makeDPoPProof(
    key: OAuthSigningKey,
    method: String,
    url: String,
    nonce: String?,
    accessToken: String? = nil,
    issuedAt: Date,
    jti: String = UUID().uuidString
) throws -> String {
    try OAuthCompactJWT.sign(
        DPoPClaims(
            jti: jti,
            htm: method,
            htu: url,
            iat: Int64(issuedAt.timeIntervalSince1970),
            nonce: nonce,
            ath: accessToken.map { OAuthPKCE.s256Challenge(for: $0) }
        ),
        with: key,
        type: "dpop+jwt",
        embedsPublicKey: true
    )
}

struct ClientAssertionClaims: Encodable {
    var iss: String
    var sub: String
    var aud: String
    var jti: String
    var iat: Int64
    var exp: Int64
}

/// A server wired to in-memory collaborators, plus helpers to drive it the
/// way a client and a browser would.
struct TestServer {
    static let issuer = "https://auth.example.test"
    static let webClientID = "https://app.example.test/client-metadata.json"
    static let webRedirect = "https://app.example.test/callback"
    static let confidentialClientID = "https://service.example.test/client-metadata.json"
    static let confidentialRedirect = "https://service.example.test/callback"
    static let loopbackClientID =
        "http://localhost?redirect_uri=http%3A%2F%2F127.0.0.1%3A8080%2Fcallback&scope=atproto%20transition%3Ageneric"
    static let loopbackRedirect = "http://127.0.0.1:8080/callback"

    let server: OAuthAuthorizationServer
    let store: InMemoryOAuthStore
    let clock: TestClock
    let accounts: TestAccounts
    let clients: MutableClientResolver
    let confidentialKey: OAuthSigningKey

    init(
        accessTokenFormat: OAuthAccessTokenFormat = .opaque,
        lexiconResolver: (any OAuthLexiconResolving)? = nil,
        webClientScopes: Set<String> = ["atproto", "transition:generic", "repo:app.bsky.feed.post?action=create"],
        webClientGrants: Set<String> = ["authorization_code", "refresh_token"],
        trustedClientIDs: Set<String> = [],
        unknownScopePolicy: OAuthUnknownScopePolicy = .reject
    ) throws {
        store = InMemoryOAuthStore()
        clock = TestClock()
        accounts = TestAccounts()
        clients = MutableClientResolver()
        confidentialKey = try OAuthSigningKey.generate(keyID: "key-1")
        try clients.register(.init(
            metadata: OAuthClientMetadata(
                clientID: #require(URL(string: Self.webClientID)),
                applicationType: .web,
                redirectURIs: [#require(URL(string: Self.webRedirect))],
                grantTypes: webClientGrants,
                responseTypes: ["code"],
                scopes: webClientScopes,
                dpopBoundAccessTokens: true,
                clientName: "Example App",
                clientURI: URL(string: "https://app.example.test"),
                logoURI: URL(string: "https://app.example.test/logo.png")
            ),
            keySet: nil
        ))
        let keySet = try OAuthJSONWebKeySet(keys: [confidentialKey.publicJWK])
        try clients.register(.init(
            metadata: OAuthClientMetadata(
                clientID: #require(URL(string: Self.confidentialClientID)),
                applicationType: .web,
                redirectURIs: [#require(URL(string: Self.confidentialRedirect))],
                grantTypes: ["authorization_code", "refresh_token"],
                responseTypes: ["code"],
                scopes: ["atproto", "transition:generic"],
                tokenEndpointAuthMethod: .privateKeyJWT,
                tokenEndpointAuthSigningAlgorithm: "ES256",
                dpopBoundAccessTokens: true,
                jwks: keySet
            ),
            keySet: keySet
        ))
        server = try OAuthAuthorizationServer(
            configuration: OAuthAuthorizationServerConfiguration(
                issuer: #require(URL(string: Self.issuer)),
                serverSecret: Data(repeating: 7, count: 32),
                accessTokenFormat: accessTokenFormat,
                unknownScopePolicy: unknownScopePolicy,
                trustedClientIDs: trustedClientIDs
            ),
            store: store,
            accounts: accounts,
            clients: clients,
            lexiconResolver: lexiconResolver,
            clock: clock
        )
    }

    func get(_ path: String, query: String? = nil, headers: [(String, String)] = []) async -> OAuthHTTPResponse {
        await server.handle(OAuthHTTPRequest(method: "GET", path: path, query: query, headers: .init(headers)))
    }

    func post(_ path: String, _ fields: [(String, String)], headers: [(String, String)] = []) async -> OAuthHTTPResponse {
        await server.handle(OAuthHTTPRequest(
            method: "POST", path: path,
            headers: .init([("Content-Type", "application/x-www-form-urlencoded")] + headers),
            body: formBody(fields)
        ))
    }
}

/// One OAuth client instance: a DPoP key, a PKCE verifier and the tokens it
/// has been given. Drives the server through `handle(_:)` exactly as a real
/// client drives it over HTTP, including the `use_dpop_nonce` retry.
final class TestClient: @unchecked Sendable {
    let harness: TestServer
    let clientID: String
    let redirectURI: String
    var dpopKey: OAuthSigningKey
    let assertionKey: OAuthSigningKey?
    var nonce: String?
    let verifier = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "") + "-._~"
    var state = UUID().uuidString

    struct PAR: Decodable {
        let request_uri: String
        let expires_in: Int
    }

    init(
        _ harness: TestServer,
        clientID: String = TestServer.webClientID,
        redirectURI: String = TestServer.webRedirect,
        assertionKey: OAuthSigningKey? = nil,
        dpopAlgorithm: OAuthJWSAlgorithm = .es256
    ) throws {
        self.harness = harness
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.assertionKey = assertionKey
        dpopKey = try OAuthSigningKey.generate(algorithm: dpopAlgorithm)
    }

    static func confidential(_ harness: TestServer) throws -> TestClient {
        try TestClient(
            harness,
            clientID: TestServer.confidentialClientID,
            redirectURI: TestServer.confidentialRedirect,
            assertionKey: harness.confidentialKey
        )
    }

    static func loopback(_ harness: TestServer) throws -> TestClient {
        try TestClient(harness, clientID: TestServer.loopbackClientID, redirectURI: TestServer.loopbackRedirect)
    }

    var challenge: String { OAuthPKCE.s256Challenge(for: verifier) }

    func assertion(
        key: OAuthSigningKey? = nil,
        audience: String = TestServer.issuer,
        jti: String = UUID().uuidString,
        lifetime: TimeInterval = 60
    ) throws -> String {
        let now = harness.clock.now()
        return try OAuthCompactJWT.sign(
            ClientAssertionClaims(
                iss: clientID, sub: clientID, aud: audience, jti: jti,
                iat: Int64(now.timeIntervalSince1970),
                exp: Int64(now.addingTimeInterval(lifetime).timeIntervalSince1970)
            ),
            with: #require(key ?? assertionKey)
        )
    }

    /// The form fields that authenticate this client.
    func clientFields() throws -> [(String, String)] {
        var fields = [("client_id", clientID)]
        if assertionKey != nil {
            fields.append(("client_assertion_type", OAuthClientAssertionValidator.assertionType))
            try fields.append(("client_assertion", assertion()))
        }
        return fields
    }

    /// Posts a form with a DPoP proof, retrying once on `use_dpop_nonce` with
    /// the same body — including the same client assertion — and only a new
    /// proof, which is what the reference client does.
    func send(_ path: String, _ fields: [(String, String)]) async throws -> OAuthHTTPResponse {
        for _ in 0 ..< 2 {
            let proof = try makeDPoPProof(
                key: dpopKey, method: "POST", url: TestServer.issuer + path,
                nonce: nonce, issuedAt: harness.clock.now()
            )
            let response = await harness.post(path, fields, headers: [("DPoP", proof)])
            if let fresh = response.headers["DPoP-Nonce"] { nonce = fresh }
            if response.oauthError == "use_dpop_nonce" { continue }
            return response
        }
        throw TestHTTPError(description: "server kept asking for a nonce")
    }

    func parFields(scope: String = "atproto transition:generic", overrides: [String: String?] = [:]) throws -> [(String, String)] {
        var fields: [(String, String)] = try clientFields() + [
            ("response_type", "code"),
            ("code_challenge", challenge),
            ("code_challenge_method", "S256"),
            ("state", state),
            ("redirect_uri", redirectURI),
            ("scope", scope),
        ]
        for (name, value) in overrides {
            fields.removeAll { $0.0 == name }
            if let value { fields.append((name, value)) }
        }
        return fields
    }

    func pushRequest(scope: String = "atproto transition:generic", overrides: [String: String?] = [:]) async throws -> String {
        let response = try await send(OAuthAuthorizationServer.Path.pushedAuthorizationRequest, parFields(scope: scope, overrides: overrides))
        guard response.status == 201 else {
            throw TestHTTPError(description: "PAR failed: \(response.status) \(response.text)")
        }
        return try response.decode(PAR.self).request_uri
    }

    func exchange(code: String, overrides: [String: String?] = [:]) async throws -> OAuthHTTPResponse {
        var fields: [(String, String)] = try clientFields() + [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("code_verifier", verifier),
            ("redirect_uri", redirectURI),
        ]
        for (name, value) in overrides {
            fields.removeAll { $0.0 == name }
            if let value { fields.append((name, value)) }
        }
        return try await send(OAuthAuthorizationServer.Path.token, fields)
    }

    func refresh(_ refreshToken: String) async throws -> OAuthHTTPResponse {
        try await send(
            OAuthAuthorizationServer.Path.token,
            clientFields() + [("grant_type", "refresh_token"), ("refresh_token", refreshToken)]
        )
    }

    /// PAR, sign-in, consent, code exchange.
    func signIn(
        as account: OAuthAccount = TestAccounts.alice,
        password: String = "alice-password",
        scope: String = "atproto transition:generic"
    ) async throws -> OAuthTokenResponse {
        let requestURI = try await pushRequest(scope: scope)
        let browser = TestBrowser(harness)
        let code = try await browser.approve(requestURI: requestURI, clientID: clientID, account: account, password: password)
        let response = try await exchange(code: code)
        guard response.status == 200 else {
            throw TestHTTPError(description: "token exchange failed: \(response.status) \(response.text)")
        }
        return try response.decode(OAuthTokenResponse.self)
    }
}

/// A browser: a cookie jar and the user's clicks.
final class TestBrowser: @unchecked Sendable {
    let harness: TestServer
    var cookies: [String: String] = [:]
    var lastPage = ""

    init(_ harness: TestServer) {
        self.harness = harness
    }

    private func absorb(_ response: OAuthHTTPResponse) {
        for header in response.headers.values(for: "Set-Cookie") {
            guard let pair = header.split(separator: ";").first, let separator = pair.firstIndex(of: "=") else { continue }
            let name = String(pair[..<separator])
            let value = String(pair[pair.index(after: separator)...])
            if value.isEmpty || header.contains("Max-Age=0") {
                cookies.removeValue(forKey: name)
            } else {
                cookies[name] = value
            }
        }
        lastPage = response.text
    }

    private var cookieHeader: [(String, String)] {
        cookies.isEmpty ? [] : [("Cookie", cookies.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; "))]
    }

    var csrf: String {
        guard let range = lastPage.range(of: "name=\"csrf\" value=\"") else { return "" }
        return String(lastPage[range.upperBound...].prefix { $0 != "\"" })
    }

    @discardableResult
    func open(requestURI: String, clientID: String) async -> OAuthHTTPResponse {
        let query = "client_id=\(OAuthForm.encodeComponent(clientID))&request_uri=\(OAuthForm.encodeComponent(requestURI))"
        let response = await harness.get(OAuthAuthorizationServer.Path.authorize, query: query, headers: cookieHeader)
        absorb(response)
        return response
    }

    @discardableResult
    func submit(_ path: String, _ fields: [(String, String)], csrf override: String? = nil, extraHeaders: [(String, String)] = []) async -> OAuthHTTPResponse {
        let response = await harness.post(
            path, [("csrf", override ?? csrf)] + fields,
            headers: cookieHeader + [("Origin", TestServer.issuer)] + extraHeaders
        )
        absorb(response)
        return response
    }

    /// The parameters of a redirect back to the client.
    static func redirectParameters(_ response: OAuthHTTPResponse) -> [String: String] {
        guard let location = response.headers["Location"], let components = URLComponents(string: location) else { return [:] }
        return Dictionary((components.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    /// Opens the request, signs in, approves, and returns the code.
    func approve(requestURI: String, clientID: String, account: OAuthAccount, password: String) async throws -> String {
        await open(requestURI: requestURI, clientID: clientID)
        await submit(OAuthAuthorizationServer.Path.signIn, [("identifier", account.handle ?? account.did), ("password", password)])
        let response = await submit(OAuthAuthorizationServer.Path.consent, [("decision", "approve")])
        guard response.status == 303, let code = Self.redirectParameters(response)["code"] else {
            throw TestHTTPError(description: "consent did not redirect with a code: \(response.status) \(response.text)")
        }
        return code
    }
}
