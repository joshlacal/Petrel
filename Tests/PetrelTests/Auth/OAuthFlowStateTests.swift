//
//  OAuthFlowStateTests.swift
//  PetrelTests
//

import CryptoKit
import Foundation
@testable import Petrel
import Testing

private final class StateTestURLProtocol: URLProtocol {
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

private let pdsHost = "https://pds.test"
private let authHost = "https://auth.flowstate.test"
private let parEndpoint = "\(authHost)/oauth/par"

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
  "token_endpoint": "\(authHost)/oauth/token",
  "token_endpoint_auth_methods_supported": ["none"],
  "token_endpoint_auth_signing_alg_values_supported": ["ES256"],
  "revocation_endpoint": "\(authHost)/oauth/revoke",
  "pushed_authorization_request_endpoint": "\(parEndpoint)",
  "require_pushed_authorization_requests": true,
  "dpop_signing_alg_values_supported": ["ES256"],
  "client_id_metadata_document_supported": true
}
"""

private let parSuccessJSON = """
{
  "request_uri": "urn:ietf:params:oauth:request_uri:state-test-req-uri",
  "expires_in": 300
}
"""

private let parNativeNoneRejectionJSON = """
{
  "error": "invalid_client_metadata",
  "error_description": "Native clients must authenticate using none method"
}
"""

private func withStateTestTransport<T>(
    _ backend: InMemorySecureStorage,
    handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data),
    _ body: () async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        StateTestURLProtocol.setHandler(handler)
        NetworkService.setNetworkTestProtocolClasses([StateTestURLProtocol.self])
        defer {
            NetworkService.setNetworkTestProtocolClasses(nil)
            StateTestURLProtocol.setHandler(nil)
            KeychainManager._setStorageOverride(nil)
        }
        return try await body()
    }
}

@Suite("OAuth Flow State and Error Tests", .serialized)
struct OAuthFlowStateTests {
    private func makeStrategy(namespace: String) -> PublicOAuthStrategy {
        PublicOAuthStrategy(
            storage: KeychainStorage(namespace: namespace),
            accountManager: MockAccountManager(
                account: Account(
                    did: "did:plc:flowstatetest",
                    handle: "flowstate.example",
                    pdsURL: URL(string: pdsHost)!
                )
            ),
            networkService: NetworkService(baseURL: URL(string: pdsHost)!),
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/oauth-client-metadata.json",
                redirectUri: "blue.catbird.atprotodrive:/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver()
        )
    }

    @Test("AuthError typed cases equality and descriptions")
    func testAuthErrorCases() {
        let err1 = AuthError.nativeClientNoneAuthRequired("Native clients must authenticate using none method")
        let err2 = AuthError.nativeClientNoneAuthRequired("Native clients must authenticate using none method")
        let err3 = AuthError.invalidClientMetadata("Other metadata error")
        let err4 = AuthError.oauthFlowStateUnavailable

        #expect(err1 == err2)
        #expect(err1 != err3)
        #expect(err1 != err4)
        #expect(err1.errorDescription?.contains("Native clients must authenticate using none method") == true)
        #expect(err4.errorDescription?.contains("routing state") == true)
    }

    @Test("Unauthenticated client startOAuthFlowWithState throws unauthenticatedClient")
    func testStartOAuthFlowWithStateUnauthenticated() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
        await #expect(throws: APIError.self) {
            try await client.startOAuthFlowWithState(identifier: "test.bsky.social")
        }
    }

    @Test("startOAuthFlowWithState persists and returns the state token for callback matching")
    func testStartOAuthFlowWithStatePersistsState() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { request in
            let url = request.url!
            switch url.path {
            case "/.well-known/oauth-protected-resource":
                return (jsonResponse(url: url, status: 200), Data(protectedResourceJSON.utf8))
            case "/.well-known/oauth-authorization-server":
                return (jsonResponse(url: url, status: 200), Data(authServerJSON.utf8))
            case "/oauth/par":
                return (jsonResponse(url: url, status: 201), Data(parSuccessJSON.utf8))
            default:
                return (jsonResponse(url: url, status: 404), Data("{}".utf8))
            }
        }

        try await withStateTestTransport(backend, handler: handler) {
            let namespace = "test.flowstate.persisted"
            let strategy = makeStrategy(namespace: namespace)
            let storage = KeychainStorage(namespace: namespace)

            let (authURL, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "flowstate.example")

            #expect(!stateToken.isEmpty)
            #expect(authURL.absoluteString.contains("request_uri="))

            // Prove state token is persisted in storage and contains target PDS URL
            let persistedState = try await storage.getOAuthState(for: stateToken)
            #expect(persistedState != nil)
            #expect(persistedState?.stateToken == stateToken)
            #expect(persistedState?.targetPDSURL == URL(string: pdsHost)!)
            #expect(persistedState?.initialIdentifier == "flowstate.example")
        }
    }

    @Test("startOAuthFlowWithState throws nativeClientNoneAuthRequired on AS none method rejection")
    func testStartOAuthFlowThrowsNativeClientNoneAuthRequired() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { request in
            let url = request.url!
            switch url.path {
            case "/.well-known/oauth-protected-resource":
                return (jsonResponse(url: url, status: 200), Data(protectedResourceJSON.utf8))
            case "/.well-known/oauth-authorization-server":
                return (jsonResponse(url: url, status: 200), Data(authServerJSON.utf8))
            case "/oauth/par":
                return (jsonResponse(url: url, status: 400), Data(parNativeNoneRejectionJSON.utf8))
            default:
                return (jsonResponse(url: url, status: 404), Data("{}".utf8))
            }
        }

        try await withStateTestTransport(backend, handler: handler) {
            let namespace = "test.flowstate.none_required"
            let strategy = makeStrategy(namespace: namespace)

            await #expect(throws: AuthError.nativeClientNoneAuthRequired("Native clients must authenticate using none method")) {
                try await strategy.startOAuthFlowWithState(identifier: "flowstate.example")
            }
        }
    }
}
