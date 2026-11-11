import Foundation
@testable import PetrelOAuthServer
import Testing

@Suite("Clients: metadata validation and discovery")
struct OAuthClientMetadataTests {
    private static let clientID = "https://app.example.com/oauth/client-metadata.json"

    private static func document(_ overrides: [String: Any?] = [:]) throws -> Data {
        var object: [String: Any] = [
            "client_id": clientID,
            "application_type": "web",
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "redirect_uris": ["https://app.example.com/callback"],
            "scope": "atproto transition:generic",
            "dpop_bound_access_tokens": true,
            "token_endpoint_auth_method": "none",
        ]
        for (key, value) in overrides {
            if let value { object[key] = value } else { object.removeValue(forKey: key) }
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    private static func decode(_ overrides: [String: Any?] = [:], responseURL: String = clientID) throws -> OAuthClientMetadata {
        try OAuthClientMetadata.decodeValidated(document(overrides), responseURL: #require(URL(string: responseURL)))
    }

    @Test("a conformant public web client document is accepted")
    func validPublicClient() throws {
        let metadata = try Self.decode()
        #expect(metadata.applicationType == .web)
        #expect(metadata.tokenEndpointAuthMethod == .none)
        #expect(metadata.scopes == ["atproto", "transition:generic"])
        #expect(try metadata.matchesRedirectURI(#require(URL(string: "https://app.example.com/callback"))))
        #expect(try !metadata.matchesRedirectURI(#require(URL(string: "https://app.example.com/callback/"))))
        #expect(try !metadata.matchesRedirectURI(#require(URL(string: "https://app.example.com/callback?x=1"))))
        // application_type defaults to web; token_endpoint_auth_method defaults to none.
        let defaulted = try Self.decode(["application_type": nil, "token_endpoint_auth_method": nil])
        #expect(defaulted.applicationType == .web && defaulted.tokenEndpointAuthMethod == .none)
    }

    @Test("documents that break a profile rule are refused", arguments: [
        "client_id mismatch", "missing authorization_code", "missing code response type", "no redirect_uris",
        "dpop not bound", "dpop missing", "scope without atproto", "scope missing", "http redirect for web",
        "redirect with fragment", "redirect with default port", "client_uri on another host", "http logo",
        "http tos", "http policy", "public client with jwks", "public client with signing alg",
        "unknown auth method", "unknown application type", "duplicate grant types", "duplicate redirect",
        "bad scope token",
    ])
    func invalidDocuments(rule: String) throws {
        let overrides: [String: Any?] = switch rule {
        case "client_id mismatch": ["client_id": "https://other.example.com/client-metadata.json"]
        case "missing authorization_code": ["grant_types": ["refresh_token"]]
        case "missing code response type": ["response_types": ["token"]]
        case "no redirect_uris": ["redirect_uris": [String]()]
        case "dpop not bound": ["dpop_bound_access_tokens": false]
        case "dpop missing": ["dpop_bound_access_tokens": nil]
        case "scope without atproto": ["scope": "transition:generic"]
        case "scope missing": ["scope": nil]
        case "http redirect for web": ["redirect_uris": ["http://app.example.com/callback"]]
        case "redirect with fragment": ["redirect_uris": ["https://app.example.com/callback#x"]]
        case "redirect with default port": ["redirect_uris": ["https://app.example.com:443/callback"]]
        case "client_uri on another host": ["client_uri": "https://other.example.com"]
        case "http logo": ["logo_uri": "http://app.example.com/logo.png"]
        case "http tos": ["tos_uri": "http://app.example.com/tos"]
        case "http policy": ["policy_uri": "http://app.example.com/privacy"]
        case "public client with jwks": ["jwks_uri": "https://app.example.com/jwks.json"]
        case "public client with signing alg": ["token_endpoint_auth_signing_alg": "ES256"]
        case "unknown auth method": ["token_endpoint_auth_method": "client_secret_basic"]
        case "unknown application type": ["application_type": "spa"]
        case "duplicate grant types": ["grant_types": ["authorization_code", "authorization_code"]]
        case "duplicate redirect": ["redirect_uris": ["https://app.example.com/callback", "https://app.example.com/callback"]]
        default: ["scope": "atproto bad\"scope"]
        }
        #expect(throws: (any Error).self, "\(rule)") { _ = try Self.decode(overrides) }
    }

    @Test("client_id URL rules", arguments: [
        ("https://app.example.com/client-metadata.json", true),
        ("https://app.example.com/", true),
        ("http://app.example.com/client-metadata.json", false),
        ("https://app.example.com:8443/client-metadata.json", false),
        ("https://user@app.example.com/client-metadata.json", false),
        ("https://app.example.com/client-metadata.json#frag", false),
        ("ftp://app.example.com/x", false),
    ])
    func clientIDRules(clientID: String, valid: Bool) throws {
        let url = try #require(URL(string: clientID))
        if valid {
            try OAuthClientMetadata.validateStandardClientID(url)
        } else {
            #expect(throws: OAuthServerError.self) { try OAuthClientMetadata.validateStandardClientID(url) }
        }
    }

    @Test("native clients: reverse-domain custom scheme or same-host https only")
    func nativeRedirects() throws {
        func native(_ redirect: String) throws -> OAuthClientMetadata {
            try Self.decode(["application_type": "native", "redirect_uris": [redirect]])
        }
        let custom = try native("com.example.app:/callback")
        #expect(try custom.matchesRedirectURI(#require(URL(string: "com.example.app:/callback"))))
        _ = try native("https://app.example.com/callback")
        for bad in [
            "com.example.other:/callback", // not the client_id host reversed
            "com.example.app://callback", // two slashes
            "com.example.app:/", // no path
            "https://other.example.com/callback",
            "http://127.0.0.1/callback",
        ] {
            #expect(throws: (any Error).self, "\(bad)") { _ = try native(bad) }
        }
    }

    @Test("confidential clients need a supported algorithm and exactly one key source")
    func confidentialClients() throws {
        let key = try OAuthSigningKey.generate(keyID: "k1").publicJWK
        let jwks: [String: Any] = ["keys": [["kty": "EC", "crv": "P-256", "x": key.x, "y": key.y, "kid": "k1"]]]
        let base: [String: Any?] = ["token_endpoint_auth_method": "private_key_jwt", "token_endpoint_auth_signing_alg": "ES256"]
        let inline = try Self.decode(base.merging(["jwks": jwks]) { _, new in new })
        #expect(inline.jwks?.keys.first?.keyID == "k1")
        _ = try Self.decode(base.merging(["jwks_uri": "https://app.example.com/jwks.json"]) { _, new in new })
        _ = try Self.decode(base.merging(["jwks": jwks, "token_endpoint_auth_signing_alg": "ES256K"]) { _, new in new })

        #expect(throws: (any Error).self) { _ = try Self.decode(base) }
        #expect(throws: (any Error).self) {
            _ = try Self.decode(base.merging(["jwks": jwks, "jwks_uri": "https://app.example.com/jwks.json"]) { _, new in new })
        }
        #expect(throws: (any Error).self) {
            _ = try Self.decode(base.merging(["jwks": jwks, "token_endpoint_auth_signing_alg": "none"]) { _, new in new })
        }
        #expect(throws: (any Error).self) {
            _ = try Self.decode(base.merging(["jwks": jwks, "token_endpoint_auth_signing_alg": "RS256"]) { _, new in new })
        }
        #expect(throws: (any Error).self) {
            _ = try Self.decode(base.merging(["jwks_uri": "http://app.example.com/jwks.json"]) { _, new in new })
        }
    }

    @Test("loopback development clients: virtual metadata from the client_id itself")
    func loopbackClients() throws {
        let plain = try OAuthClientMetadata.loopbackDevelopmentMetadata(clientID: #require(URL(string: "http://localhost")))
        #expect(plain.applicationType == .native)
        #expect(plain.tokenEndpointAuthMethod == .none)
        #expect(plain.grantTypes == ["authorization_code", "refresh_token"])
        #expect(plain.scopes == ["atproto"])
        #expect(plain.redirectURIs.map(\.absoluteString) == ["http://127.0.0.1/", "http://[::1]/"])
        // Ports are ignored; paths are matched.
        #expect(try plain.matchesRedirectURI(#require(URL(string: "http://127.0.0.1:51234/"))))
        #expect(try plain.matchesRedirectURI(#require(URL(string: "http://[::1]:8080/"))))
        #expect(try !plain.matchesRedirectURI(#require(URL(string: "http://127.0.0.1:51234/callback"))))
        #expect(try !plain.matchesRedirectURI(#require(URL(string: "http://localhost:51234/"))))
        #expect(try !plain.matchesRedirectURI(#require(URL(string: "https://127.0.0.1/"))))

        let configured = try OAuthClientMetadata.loopbackDevelopmentMetadata(clientID: #require(URL(
            string: "http://localhost/?redirect_uri=http%3A%2F%2F127.0.0.1%2Fcb&scope=atproto%20transition%3Ageneric"
        )))
        #expect(configured.scopes == ["atproto", "transition:generic"])
        #expect(try configured.matchesRedirectURI(#require(URL(string: "http://127.0.0.1:9999/cb"))))

        for bad in [
            "http://localhost:8080", "http://127.0.0.1", "https://localhost", "http://localhost/path",
            "http://localhost?redirect_uri=https%3A%2F%2Fexample.com%2Fcb", "http://localhost?other=1",
            "http://localhost?scope=atproto&scope=atproto",
        ] {
            #expect(throws: (any Error).self, "\(bad)") {
                _ = try OAuthClientMetadata.loopbackDevelopmentMetadata(clientID: #require(URL(string: bad)))
            }
        }
    }
}

/// A transport that serves canned responses and records what it was asked.
final class StubTransport: OAuthRemoteTransport, @unchecked Sendable {
    struct Canned {
        var status = 200
        var contentType: String? = "application/json"
        var body = Data()
        var redirectCount = 0
        var peer: OAuthIPAddress? = OAuthIPAddress(literal: "93.184.216.34")
    }

    private let lock = NSLock()
    private var responses: [String: Canned] = [:]
    private var requested: [String] = []

    func serve(_ url: String, _ canned: Canned) {
        lock.lock()
        responses[url] = canned
        lock.unlock()
    }

    var requests: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    func get(url: URL, approvedPeers _: Set<OAuthIPAddress>, timeout _: TimeInterval, maximumBodyBytes _: Int) async throws -> OAuthRemoteHTTPResponse {
        let canned = record(url.absoluteString)
        guard let canned else { throw OAuthServerError.unavailable("no such stub") }
        var headers: [String: [String]] = [:]
        if let contentType = canned.contentType { headers["content-type"] = [contentType] }
        return OAuthRemoteHTTPResponse(
            status: canned.status, headers: headers, body: canned.body, responseURL: url,
            redirectCount: canned.redirectCount, connectedPeerAddress: canned.peer
        )
    }

    private func record(_ url: String) -> Canned? {
        lock.lock()
        defer { lock.unlock() }
        requested.append(url)
        return responses[url]
    }
}

struct StubResolver: OAuthHostnameResolving {
    var addresses: [String: [String]] = [:]

    func resolve(host: String) async throws -> [OAuthIPAddress] {
        (addresses[host] ?? ["93.184.216.34"]).compactMap(OAuthIPAddress.init(literal:))
    }
}

@Suite("Clients: hardened metadata fetch and caching")
struct OAuthClientMetadataLoaderTests {
    private static let clientID = "https://app.example.com/oauth/client-metadata.json"

    private func loader(
        _ transport: StubTransport,
        resolver: StubResolver = StubResolver(),
        store: InMemoryOAuthStore = InMemoryOAuthStore()
    ) throws -> OAuthClientMetadataLoader {
        try OAuthClientMetadataLoader(
            fetcher: OAuthRemoteDocumentFetcher(
                policy: OAuthRemoteFetchPolicy(requiresConnectedPeerProof: true),
                resolver: resolver,
                transport: transport
            ),
            cache: store
        )
    }

    private func document(_ extra: [String: Any] = [:]) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "client_id": Self.clientID,
            "grant_types": ["authorization_code"],
            "response_types": ["code"],
            "redirect_uris": ["https://app.example.com/callback"],
            "scope": "atproto",
            "dpop_bound_access_tokens": true,
        ].merging(extra) { _, new in new })
    }

    @Test("a 200 application/json document is fetched once, validated and then served from cache")
    func fetchAndCache() async throws {
        let transport = StubTransport()
        try transport.serve(Self.clientID, .init(body: document()))
        let loader = try loader(transport)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let url = try #require(URL(string: Self.clientID))
        let first = try await loader.resolve(clientID: url, now: now)
        #expect(first.metadata.clientID.absoluteString == Self.clientID)
        _ = try await loader.resolve(clientID: url, now: now.addingTimeInterval(200))
        #expect(transport.requests.count == 1)
        // The cache expires, and revalidation bypasses it.
        _ = try await loader.resolve(clientID: url, now: now.addingTimeInterval(301))
        #expect(transport.requests.count == 2)
        _ = try await loader.resolve(clientID: url, revalidate: true, now: now.addingTimeInterval(302))
        #expect(transport.requests.count == 3)
    }

    @Test("jwks_uri is fetched through the same hardened path")
    func jwksURI() async throws {
        let key = try OAuthSigningKey.generate(keyID: "k1").publicJWK
        let transport = StubTransport()
        try transport.serve(Self.clientID, .init(body: document([
            "token_endpoint_auth_method": "private_key_jwt",
            "token_endpoint_auth_signing_alg": "ES256",
            "jwks_uri": "https://keys.example.com/jwks.json",
        ])))
        try transport.serve("https://keys.example.com/jwks.json", .init(body: JSONSerialization.data(withJSONObject: [
            "keys": [["kty": "EC", "crv": "P-256", "x": key.x, "y": key.y, "kid": "k1"]],
        ])))
        let resolved = try await loader(transport).resolve(clientID: #require(URL(string: Self.clientID)))
        #expect(resolved.keySet?.keys.first?.thumbprint() == key.thumbprint())
        #expect(transport.requests == [Self.clientID, "https://keys.example.com/jwks.json"])
    }

    @Test("responses that are not an exact 200 JSON document are refused", arguments: [
        "201", "404", "redirect", "text/html", "no content type", "empty", "not json", "duplicate members",
        "client_id mismatch", "no peer proof", "peer not in DNS answer",
    ])
    func refusedResponses(scenario: String) async throws {
        var canned = try StubTransport.Canned(body: document())
        switch scenario {
        case "201": canned.status = 201
        case "404": canned.status = 404
        case "redirect": canned.redirectCount = 1
        case "text/html": canned.contentType = "text/html"
        case "no content type": canned.contentType = nil
        case "empty": canned.body = Data()
        case "not json": canned.body = Data("<html>".utf8)
        case "duplicate members": canned.body = Data(#"{"client_id":"a","client_id":"b"}"#.utf8)
        case "client_id mismatch": canned.body = try document(["client_id": "https://other.example.com/c.json"])
        case "no peer proof": canned.peer = nil
        default: canned.peer = OAuthIPAddress(literal: "198.51.100.7")
        }
        let transport = StubTransport()
        transport.serve(Self.clientID, canned)
        let loader = try loader(transport)
        await #expect(throws: (any Error).self, "\(scenario)") {
            _ = try await loader.resolve(clientID: #require(URL(string: Self.clientID)))
        }
    }

    @Test("hosts that resolve to non-public addresses are never contacted", arguments: [
        "127.0.0.1", "10.0.0.5", "192.168.1.10", "172.16.0.1", "169.254.169.254", "100.64.0.1", "0.0.0.0",
        "::1", "fe80::1", "fc00::1", "::ffff:10.0.0.1",
    ])
    func privateAddresses(address: String) async throws {
        let transport = StubTransport()
        try transport.serve(Self.clientID, .init(body: document()))
        let loader = try loader(transport, resolver: StubResolver(addresses: ["app.example.com": [address]]))
        await #expect(throws: OAuthServerError.self, "\(address)") {
            _ = try await loader.resolve(clientID: #require(URL(string: Self.clientID)))
        }
        #expect(transport.requests.isEmpty, "the request was sent to \(address)")
    }

    @Test("a host with one public and one private address is refused: every answer must be public")
    func mixedAnswers() async throws {
        let transport = StubTransport()
        try transport.serve(Self.clientID, .init(body: document()))
        let loader = try loader(transport, resolver: StubResolver(addresses: ["app.example.com": ["93.184.216.34", "10.0.0.1"]]))
        await #expect(throws: OAuthServerError.self) {
            _ = try await loader.resolve(clientID: #require(URL(string: Self.clientID)))
        }
        #expect(transport.requests.isEmpty)
    }

    @Test("IP-literal and non-https client_ids are refused before any lookup")
    func literalAndScheme() async throws {
        let transport = StubTransport()
        let loader = try loader(transport)
        for bad in ["https://10.0.0.1/client.json", "https://[::1]/client.json", "http://app.example.com/client.json"] {
            await #expect(throws: OAuthServerError.self, "\(bad)") {
                _ = try await loader.resolve(clientID: #require(URL(string: bad)))
            }
        }
        #expect(transport.requests.isEmpty)
    }

    @Test("loopback clients need no fetch and can be disabled")
    func loopback() async throws {
        let transport = StubTransport()
        let url = try #require(URL(string: "http://localhost"))
        let resolved = try await loader(transport).resolve(clientID: url)
        #expect(resolved.metadata.isLoopbackDevelopmentClient)
        #expect(transport.requests.isEmpty)
        let strict = try OAuthClientMetadataLoader(
            fetcher: OAuthRemoteDocumentFetcher(policy: OAuthRemoteFetchPolicy(), transport: transport),
            cache: InMemoryOAuthStore(),
            allowsLoopbackClients: false
        )
        await #expect(throws: OAuthServerError.self) { _ = try await strict.resolve(clientID: url) }
    }
}
