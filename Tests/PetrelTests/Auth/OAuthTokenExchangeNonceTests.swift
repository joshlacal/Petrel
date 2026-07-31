#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
@testable import Petrel
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Transport

/// Records the DPoP proof of every token-endpoint request so a test can tell how
/// many exchanges happened and which nonce each one carried.
private final class TokenEndpointRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var proofs: [String] = []

    func record(proof: String) {
        lock.lock()
        defer { lock.unlock() }
        proofs.append(proof)
    }

    var recordedProofs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return proofs
    }
}

/// URLProtocol serving an authorization server: both metadata documents and a token
/// endpoint scripted by the installed handler. Separate from `MockURLProtocol` so the
/// two suites can never fight over one global handler.
private final class OAuthFlowURLProtocol: URLProtocol {
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?
    private static let handlerLock = NSLock()

    static func setHandler(_ new: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?) {
        handlerLock.withLock { handler = new }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handlerLock.withLock({ Self.handler }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Fixtures

private let pdsHost = "https://pds.exchange.test"
private let authHost = "https://auth.exchange.test"
private let tokenEndpoint = "\(authHost)/oauth/token"
private let authServerHost = "auth.exchange.test"

private func jsonResponse(
    url: URL,
    status: Int,
    headers: [String: String] = [:]
) -> HTTPURLResponse {
    var allHeaders = headers
    allHeaders["Content-Type"] = "application/json"
    return HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: allHeaders
    )!
}

private let protectedResourceJSON = """
{
  "resource": "\(pdsHost)",
  "authorization_servers": ["\(authHost)"],
  "scopes_supported": ["atproto"],
  "bearer_methods_supported": ["header"],
  "resource_documentation": "\(pdsHost)/docs"
}
"""

private let authServerJSON = """
{
  "issuer": "\(authHost)",
  "scopes_supported": ["atproto"],
  "subject_types_supported": ["public"],
  "response_types_supported": ["code"],
  "response_modes_supported": ["query"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "code_challenge_methods_supported": ["S256"],
  "ui_locales_supported": ["en-US"],
  "display_values_supported": ["page"],
  "authorization_response_iss_parameter_supported": true,
  "request_object_signing_alg_values_supported": ["ES256"],
  "request_object_encryption_alg_values_supported": [],
  "request_object_encryption_enc_values_supported": [],
  "request_parameter_supported": true,
  "request_uri_parameter_supported": true,
  "require_request_uri_registration": true,
  "jwks_uri": "\(authHost)/oauth/jwks",
  "authorization_endpoint": "\(authHost)/oauth/authorize",
  "token_endpoint": "\(tokenEndpoint)",
  "token_endpoint_auth_methods_supported": ["none"],
  "token_endpoint_auth_signing_alg_values_supported": ["ES256"],
  "revocation_endpoint": "\(authHost)/oauth/revoke",
  "pushed_authorization_request_endpoint": "\(authHost)/oauth/par",
  "require_pushed_authorization_requests": true,
  "dpop_signing_alg_values_supported": ["ES256"],
  "client_id_metadata_document_supported": true
}
"""

private let tokenJSON = """
{
  "access_token": "access-token",
  "token_type": "DPoP",
  "expires_in": 3600,
  "refresh_token": "refresh-token",
  "scope": "atproto",
  "sub": "did:plc:parnoncerotation"
}
"""

private let useDPoPNonceJSON = """
{"error":"use_dpop_nonce","error_description":"Authorization server requires nonce in DPoP proof"}
"""

private func nonceInProof(_ compactJWS: String) throws -> String? {
    let parts = compactJWS.split(separator: ".")
    try #require(parts.count == 3)
    var encoded = String(parts[1])
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while encoded.count % 4 != 0 {
        encoded += "="
    }
    let data = try #require(Data(base64Encoded: encoded))
    let payload = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    return payload["nonce"] as? String
}

/// Runs `body` with an in-memory keychain and the OAuth flow transport installed.
private func withOAuthFlowTransport<T>(
    _ backend: InMemorySecureStorage,
    handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data),
    _ body: () async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        OAuthFlowURLProtocol.setHandler(handler)
        NetworkService.setNetworkTestProtocolClasses([OAuthFlowURLProtocol.self])
        defer {
            NetworkService.setNetworkTestProtocolClasses(nil)
            OAuthFlowURLProtocol.setHandler(nil)
            KeychainManager._setStorageOverride(nil)
        }
        return try await body()
    }
}

// MARK: - Tests

/// The authorization server can rotate the DPoP nonce between the pushed
/// authorization request and the token exchange. The exchange must spend its one
/// `use_dpop_nonce` retry on the server's nonce whether or not it started out with a
/// PAR nonce — gating the retry on "no initial nonce" made a rotated PAR nonce fail
/// the login outright.
@Suite("OAuth token exchange nonce handling", .serialized)
struct OAuthTokenExchangeNonceTests {
    private func makeStrategy(namespace: String) -> PublicOAuthStrategy {
        PublicOAuthStrategy(
            storage: KeychainStorage(namespace: namespace),
            accountManager: MockAccountManager(
                account: Account(
                    did: "did:plc:parnoncerotation",
                    handle: "exchange.example",
                    pdsURL: URL(string: pdsHost)!
                )
            ),
            networkService: NetworkService(baseURL: URL(string: pdsHost)!),
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/oauth-client-metadata.json",
                redirectUri: "https://client.example/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver()
        )
    }

    /// Answers the metadata documents, then the token endpoint: `use_dpop_nonce` first,
    /// tokens second.
    private func makeHandler(
        recorder: TokenEndpointRecorder
    ) -> @Sendable (URLRequest) -> (HTTPURLResponse, Data) {
        { request in
            let url = request.url!
            switch url.path {
            case "/.well-known/oauth-protected-resource":
                return (jsonResponse(url: url, status: 200), Data(protectedResourceJSON.utf8))
            case "/.well-known/oauth-authorization-server":
                return (jsonResponse(url: url, status: 200), Data(authServerJSON.utf8))
            case "/oauth/token":
                let proof = request.value(forHTTPHeaderField: "DPoP") ?? ""
                recorder.record(proof: proof)
                if recorder.recordedProofs.count == 1 {
                    return (
                        jsonResponse(
                            url: url,
                            status: 400,
                            headers: ["DPoP-Nonce": "server-nonce"]
                        ),
                        Data(useDPoPNonceJSON.utf8)
                    )
                }
                return (jsonResponse(url: url, status: 200), Data(tokenJSON.utf8))
            default:
                return (jsonResponse(url: url, status: 404), Data("{}".utf8))
            }
        }
    }

    @Test(
        "Token exchange retries once on use_dpop_nonce, with or without a PAR nonce",
        arguments: [nil, "rotated-par-nonce"] as [String?]
    )
    func tokenExchangeRetriesWithServerNonce(initialPARNonce: String?) async throws {
        let backend = InMemorySecureStorage()
        let recorder = TokenEndpointRecorder()
        try await withOAuthFlowTransport(backend, handler: makeHandler(recorder: recorder)) {
            let namespace = "test.exchange.\(initialPARNonce ?? "no-par-nonce")"
            let strategy = makeStrategy(namespace: namespace)
            let storage = KeychainStorage(namespace: namespace)
            let stateToken = UUID().uuidString
            let ephemeralKey = P256.Signing.PrivateKey()
            try await storage.saveOAuthState(
                OAuthState(
                    stateToken: stateToken,
                    codeVerifier: "verifier",
                    createdAt: Date(),
                    initialIdentifier: "exchange.example",
                    targetPDSURL: URL(string: pdsHost)!,
                    ephemeralDPoPKey: ephemeralKey.rawRepresentation,
                    parResponseNonce: initialPARNonce,
                    bskyAppViewDID: nil,
                    bskyChatDID: nil
                )
            )

            let callbackURL = URL(
                string: "https://client.example/callback?code=auth-code&state=\(stateToken)"
            )!
            let result = try await strategy.handleOAuthCallback(url: callbackURL)

            let proofs = recorder.recordedProofs
            #expect(result.did == "did:plc:parnoncerotation")
            #expect(proofs.count == 2)
            let firstNonce = try nonceInProof(#require(proofs.first))
            let secondNonce = try nonceInProof(#require(proofs.last))
            #expect(firstNonce == initialPARNonce)
            #expect(secondNonce == "server-nonce")

            // The account inherits the nonce the server accepted, not the one it
            // rejected — otherwise the first authenticated request pays for another
            // use_dpop_nonce round trip.
            let storedNonces = try await storage.getDPoPNonces(for: result.did)
            let storedByJKT = try await storage.getDPoPNoncesByJKT(for: result.did)
            let thumbprint = try #require(storedByJKT?.keys.first)
            #expect(storedNonces?[authServerHost] == "server-nonce")
            #expect(storedByJKT?[thumbprint]?[authServerHost] == "server-nonce")
        }
    }
}
