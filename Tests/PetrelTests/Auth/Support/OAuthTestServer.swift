#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

// MARK: - Backend seam

/// A server the OAuth client under test talks to, reached through
/// `OAuthTestURLProtocol` instead of the network.
///
/// This is the seam for swapping the in-memory `FakeOAuthServer` for a real
/// authorization server (for example the `PetrelOAuthServer` product) in an
/// in-process conformance test: wrap the real server in a type that answers
/// `handle(_:body:)` and pass it to `withOAuthTestNetwork`. Tests that only use
/// `OAuthTestClient` and the redirect returned by an approval step need no
/// other change.
protocol OAuthTestBackend: AnyObject, Sendable {
    /// Whether this backend serves `host`.
    func serves(host: String) -> Bool
    /// Answers one HTTP request. `body` is the fully read request body.
    func handle(_ request: URLRequest, body: Data) -> (HTTPURLResponse, Data)
}

/// Routes every request made by `NetworkService` to the backend serving its host.
final class OAuthTestURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var backends: [any OAuthTestBackend] = []

    static func install(_ newBackends: [any OAuthTestBackend]) {
        lock.withLock { backends = newBackends }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let host = request.url?.host?.lowercased() ?? ""
        let backend = Self.lock.withLock { Self.backends.first(where: { $0.serves(host: host) }) }
        guard let backend else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let (response, data) = backend.handle(request, body: request.bodyBytes ?? Data())
        // Offer redirects to the URL loading system the way a real transport
        // does, so the session's redirect policy is what decides.
        if (300 ..< 400).contains(response.statusCode),
           let location = response.value(forHTTPHeaderField: "Location"),
           let target = URL(string: location)
        {
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            // A session that refuses the redirect receives the 3xx response itself.
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Runs `body` with an in-memory keychain and `backends` standing in for the network.
@discardableResult
func withOAuthTestNetwork<T>(
    _ backends: [any OAuthTestBackend],
    storage backend: InMemorySecureStorage = InMemorySecureStorage(),
    _ body: () async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        OAuthTestURLProtocol.install(backends)
        NetworkService.setNetworkTestProtocolClasses([OAuthTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { host in
            host == "localhost" || host == "127.0.0.1" || host == "::1" ? ["127.0.0.1"] : ["93.184.216.34"]
        }
        defer {
            NetworkService.dnsResolverOverride = nil
            NetworkService.setNetworkTestProtocolClasses(nil)
            OAuthTestURLProtocol.install([])
            KeychainManager._setStorageOverride(nil)
        }
        return try await body()
    }
}

// MARK: - JOSE helpers

enum TestJOSE {
    static func base64URLDecode(_ value: String) -> Data? {
        var text = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while text.count % 4 != 0 {
            text += "="
        }
        return Data(base64Encoded: text)
    }

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func sha256Base64URL(_ text: String) -> String {
        base64URLEncode(Data(SHA256.hash(data: Data(text.utf8))))
    }

    /// RFC 7638 thumbprint of an EC P-256 JWK.
    static func thumbprint(x: String, y: String) -> String {
        sha256Base64URL("{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(x)\",\"y\":\"\(y)\"}")
    }

    /// Verifies a compact ES256 JWS against an EC P-256 public JWK.
    static func verifyES256(_ jws: String, x: String, y: String) -> Bool {
        let parts = jws.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let xBytes = base64URLDecode(x), let yBytes = base64URLDecode(y),
              let signature = base64URLDecode(parts[2]),
              let key = try? P256.Signing.PublicKey(x963Representation: Data([0x04]) + xBytes + yBytes),
              let ecdsa = try? P256.Signing.ECDSASignature(rawRepresentation: signature)
        else { return false }
        return key.isValidSignature(ecdsa, for: Data("\(parts[0]).\(parts[1])".utf8))
    }

    static func decodeObject(_ segment: String) -> [String: Any]? {
        guard let data = base64URLDecode(segment) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

/// A decoded DPoP proof (RFC 9449 §4.2), with its signature already checked.
struct DecodedDPoPProof: @unchecked Sendable {
    let header: [String: Any]
    let payload: [String: Any]
    let signatureValid: Bool
    let thumbprint: String

    var jti: String? { payload["jti"] as? String }
    var htm: String? { payload["htm"] as? String }
    var htu: String? { payload["htu"] as? String }
    var iat: Int? { payload["iat"] as? Int }
    var ath: String? { payload["ath"] as? String }
    var nonce: String? { payload["nonce"] as? String }

    init?(_ compact: String) {
        let parts = compact.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let header = TestJOSE.decodeObject(parts[0]),
              let payload = TestJOSE.decodeObject(parts[1]),
              let jwk = header["jwk"] as? [String: Any],
              let x = jwk["x"] as? String, let y = jwk["y"] as? String
        else { return nil }
        self.header = header
        self.payload = payload
        signatureValid = TestJOSE.verifyES256(compact, x: x, y: y)
        thumbprint = TestJOSE.thumbprint(x: x, y: y)
    }
}

// MARK: - Fake authorization + resource server

/// An in-memory atproto authorization server and PDS that *verifies* what the
/// client sends, so a test that passes proves the client's requests are
/// acceptable to a conforming server rather than merely well-shaped:
///
/// - DPoP proofs: ES256 signature against the embedded JWK, `typ`, `htm`,
///   `htu` (no query or fragment), `iat` freshness, `jti` replay, server nonce,
///   and `ath` on resource requests.
/// - Pushed authorization requests, PKCE (S256), `redirect_uri` and
///   `client_id` continuity, DPoP key binding of codes and tokens.
/// - Single-use refresh-token rotation with replay detection.
/// - Separate nonces for the authorization server and the resource server.
///
/// Endpoint paths deliberately avoid the `/oauth/` prefix the reference PDS
/// uses: the client must take every endpoint from server metadata.
final class FakeOAuthServer: OAuthTestBackend, @unchecked Sendable {
    enum Endpoint: String, Sendable {
        case protectedResourceMetadata, authorizationServerMetadata, par, token, revoke, resource, unknown
    }

    /// How the server authenticates clients.
    enum ClientAuthentication {
        /// Public clients only.
        case none
        /// Requires a `client_assertion` and verifies it as an ES256 JWT against
        /// these public JWKs (by `kid`), including `iss`/`sub`/`aud`/`exp` and `jti` replay.
        case jwks([[String: String]])
        /// Requires a `client_assertion` and treats it as an opaque single-use
        /// string (for assertions minted by a stubbed backend).
        case opaqueSingleUse
    }

    struct RecordedRequest: @unchecked Sendable {
        let endpoint: Endpoint
        let method: String
        let url: URL
        let headers: [String: String]
        let form: [String: String]
        let proof: DecodedDPoPProof?
        let status: Int
    }

    private struct PushedRequest {
        let parameters: [String: String]
        let jkt: String
    }

    private struct Grant {
        var sub: String
        var scope: String
        var jkt: String
        var clientID: String
        var revoked = false
    }

    private struct AuthorizationCode {
        let grantID: String
        let codeChallenge: String
        let redirectURI: String
        let clientID: String
    }

    // MARK: Configuration (set before use)

    let pdsOrigin: String
    let issuer: String
    var clientAuthentication: ClientAuthentication = .none
    var accessTokenLifetime: Int? = 3600
    var rotatesRefreshTokens = true
    /// Members merged over the generated authorization-server metadata; `NSNull` removes a member.
    var authorizationServerMetadataOverrides: [String: Any] = [:]
    /// Replaces the generated protected-resource metadata entirely when set.
    var protectedResourceMetadata: [String: Any]?
    var metadataStatus: [Endpoint: Int] = [:]
    var metadataContentType: [Endpoint: String] = [:]
    var metadataHeaders: [Endpoint: [String: String]] = [:]
    /// Rewrites a successful token response before it is sent.
    var tokenResponseTransform: (@Sendable ([String: Any], _ grantType: String) -> [String: Any])?
    /// Endpoints whose responses omit the `DPoP-Nonce` header.
    var omitsNonceOn: Set<Endpoint> = []
    /// When false, proofs without a nonce are accepted (a server that does not
    /// implement the mandatory nonce mechanism).
    var enforcesNonce = true
    /// Whether the resource server repeats `use_dpop_nonce` in the JSON body (as
    /// the reference PDS does) or signals it only through `WWW-Authenticate`
    /// (all RFC 9449 §9 requires).
    var resourceNonceErrorInBody = true
    /// Forces these endpoints to fail with the given status and OAuth error code.
    var forcedErrors: [Endpoint: (status: Int, error: String)] = [:]

    // MARK: State

    private let lock = NSLock()
    private var recorded: [RecordedRequest] = []
    private var pushed: [String: PushedRequest] = [:]
    private var codes: [String: AuthorizationCode] = [:]
    private var grants: [String: Grant] = [:]
    private var accessTokens: [String: String] = [:]
    private var refreshTokens: [String: (grantID: String, used: Bool)] = [:]
    private var seenJTIs: Set<String> = []
    private var seenAssertions: Set<String> = []
    private var counter = 0
    private var authorizationServerNonce = "as-nonce-1"
    private var resourceServerNonce = "rs-nonce-1"
    private(set) var lastAuthorizationQueryNames: [String] = []

    init(pdsOrigin: String = "https://pds.oauth.test", issuer: String = "https://auth.oauth.test") {
        self.pdsOrigin = pdsOrigin
        self.issuer = issuer
    }

    var pdsURL: URL { URL(string: pdsOrigin)! }
    var parEndpoint: String { "\(issuer)/as/par" }
    var tokenEndpoint: String { "\(issuer)/as/token" }
    var revocationEndpoint: String { "\(issuer)/as/revoke" }
    var authorizationEndpoint: String { "\(issuer)/as/authorize" }

    // MARK: Inspection

    var requests: [RecordedRequest] { lock.withLock { recorded } }

    func requests(to endpoint: Endpoint) -> [RecordedRequest] {
        requests.filter { $0.endpoint == endpoint }
    }

    var currentAuthorizationServerNonce: String { lock.withLock { authorizationServerNonce } }
    var currentResourceServerNonce: String { lock.withLock { resourceServerNonce } }

    func rotateAuthorizationServerNonce() {
        lock.withLock {
            counter += 1
            authorizationServerNonce = "as-nonce-r\(counter)"
        }
    }

    func rotateResourceServerNonce() {
        lock.withLock {
            counter += 1
            resourceServerNonce = "rs-nonce-r\(counter)"
        }
    }

    /// Makes the resource server stop accepting every access token issued so
    /// far, as if they had expired. Refresh tokens stay valid.
    func expireAccessTokens() {
        lock.withLock { accessTokens.removeAll() }
    }

    func isRevoked(sub: String) -> Bool {
        lock.withLock { grants.values.contains { $0.sub == sub && $0.revoked } }
    }

    var activeGrantCount: Int { lock.withLock { grants.values.filter { !$0.revoked }.count } }
    var revokedGrantCount: Int { lock.withLock { grants.values.filter(\.revoked).count } }

    // MARK: User approval

    /// Plays the user approving the request at the authorization interface.
    ///
    /// - Parameters:
    ///   - authorizationURL: The URL the client would open in a browser.
    ///   - did: The account the user signs in as.
    ///   - grantedScope: The scope the user grants; defaults to what was requested.
    /// - Returns: The redirect back to the client, carrying `code`, `state` and `iss`.
    func approve(_ authorizationURL: URL, as did: String, grantedScope: String? = nil) throws -> URL {
        let items = URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let requestURI = try #require(items.first(where: { $0.name == "request_uri" })?.value)
        let clientID = try #require(items.first(where: { $0.name == "client_id" })?.value)
        let redirect: String = try lock.withLock {
            lastAuthorizationQueryNames = items.map(\.name)
            // The request_uri is single-use.
            let stored = pushed.removeValue(forKey: requestURI)
            let request = try #require(stored)
            let parameters = request.parameters
            try #require(parameters["client_id"] == clientID)
            let challenge = try #require(parameters["code_challenge"])
            let redirectURI = try #require(parameters["redirect_uri"])
            let state = try #require(parameters["state"])
            counter += 1
            let grantID = "grant-\(counter)"
            grants[grantID] = Grant(
                sub: did,
                scope: grantedScope ?? parameters["scope"] ?? "",
                jkt: request.jkt,
                clientID: clientID
            )
            let code = "code-\(counter)"
            codes[code] = AuthorizationCode(
                grantID: grantID, codeChallenge: challenge, redirectURI: redirectURI, clientID: clientID
            )
            let encodedIssuer = issuer.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? issuer
            return "\(redirectURI)?code=\(code)&state=\(state)&iss=\(encodedIssuer)"
        }
        return try #require(URL(string: redirect))
    }

    // MARK: OAuthTestBackend

    func serves(host: String) -> Bool {
        host == URL(string: pdsOrigin)?.host || host == URL(string: issuer)?.host
    }

    func handle(_ request: URLRequest, body: Data) -> (HTTPURLResponse, Data) {
        let url = request.url!
        let origin = "\(url.scheme ?? "")://\(url.host ?? "")" + (url.port.map { ":\($0)" } ?? "")
        let endpoint: Endpoint
        switch (origin, url.path) {
        case (pdsOrigin, "/.well-known/oauth-protected-resource"): endpoint = .protectedResourceMetadata
        case (issuer, "/.well-known/oauth-authorization-server"): endpoint = .authorizationServerMetadata
        case (issuer, "/as/par"): endpoint = .par
        case (issuer, "/as/token"): endpoint = .token
        case (issuer, "/as/revoke"): endpoint = .revoke
        case (pdsOrigin, _) where url.path.hasPrefix("/xrpc/"): endpoint = .resource
        default: endpoint = .unknown
        }

        let form = Self.parseForm(body)
        let proof = request.value(forHTTPHeaderField: "DPoP").flatMap(DecodedDPoPProof.init)

        let (status, headers, payload): (Int, [String: String], Any) = lock.withLock {
            switch endpoint {
            case .protectedResourceMetadata, .authorizationServerMetadata:
                return metadataResponse(endpoint)
            case .par:
                return authorizationServerResponse(endpoint, request: request, form: form, proof: proof, handler: handlePAR)
            case .token:
                return authorizationServerResponse(endpoint, request: request, form: form, proof: proof, handler: handleToken)
            case .revoke:
                return authorizationServerResponse(endpoint, request: request, form: form, proof: proof, handler: handleRevoke)
            case .resource:
                return handleResource(request: request, proof: proof)
            case .unknown:
                return (404, [:], ["error": "not_found"])
            }
        }

        lock.withLock {
            recorded.append(RecordedRequest(
                endpoint: endpoint,
                method: request.httpMethod ?? "GET",
                url: url,
                headers: request.allHTTPHeaderFields ?? [:],
                form: form,
                proof: proof,
                status: status
            ))
        }

        var allHeaders = headers
        if allHeaders["Content-Type"] == nil {
            allHeaders["Content-Type"] = "application/json"
        }
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: allHeaders)!
        return (response, data)
    }

    // MARK: Metadata

    private func metadataResponse(_ endpoint: Endpoint) -> (Int, [String: String], Any) {
        var headers = metadataHeaders[endpoint] ?? [:]
        if let contentType = metadataContentType[endpoint] {
            headers["Content-Type"] = contentType
        }
        let status = metadataStatus[endpoint] ?? 200
        if endpoint == .protectedResourceMetadata {
            return (status, headers, protectedResourceMetadata ?? [
                "resource": pdsOrigin,
                "authorization_servers": [issuer],
            ])
        }
        var metadata: [String: Any] = [
            "issuer": issuer,
            "authorization_endpoint": authorizationEndpoint,
            "token_endpoint": tokenEndpoint,
            "pushed_authorization_request_endpoint": parEndpoint,
            "revocation_endpoint": revocationEndpoint,
            "response_types_supported": ["code"],
            "grant_types_supported": ["authorization_code", "refresh_token"],
            "code_challenge_methods_supported": ["S256"],
            "token_endpoint_auth_methods_supported": ["none", "private_key_jwt"],
            "token_endpoint_auth_signing_alg_values_supported": ["ES256"],
            "scopes_supported": ["atproto", "transition:generic"],
            "authorization_response_iss_parameter_supported": true,
            "require_pushed_authorization_requests": true,
            "dpop_signing_alg_values_supported": ["ES256"],
            "client_id_metadata_document_supported": true,
            "protected_resources": [pdsOrigin],
        ]
        for (key, value) in authorizationServerMetadataOverrides {
            if value is NSNull {
                metadata.removeValue(forKey: key)
            } else {
                metadata[key] = value
            }
        }
        return (status, headers, metadata)
    }

    // MARK: Authorization server endpoints

    private typealias Outcome = (status: Int, payload: [String: Any])

    private func oauthError(_ status: Int, _ error: String, _ description: String = "") -> Outcome {
        (status, ["error": error, "error_description": description])
    }

    /// Common front door of every authorization-server endpoint: DPoP proof
    /// verification, then client authentication, then the endpoint itself — the
    /// order the reference authorization server uses.
    private func authorizationServerResponse(
        _ endpoint: Endpoint,
        request: URLRequest,
        form: [String: String],
        proof: DecodedDPoPProof?,
        handler: ([String: String], DecodedDPoPProof) -> Outcome
    ) -> (Int, [String: String], Any) {
        var headers: [String: String] = [:]
        if !omitsNonceOn.contains(endpoint) {
            headers["DPoP-Nonce"] = authorizationServerNonce
        }
        guard request.httpMethod == "POST",
              request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded"
        else {
            return (400, headers, oauthError(400, "invalid_request", "form POST required").payload)
        }
        guard request.value(forHTTPHeaderField: "Authorization") == nil else {
            return (400, headers, oauthError(400, "invalid_request", "unexpected Authorization header").payload)
        }
        guard let proof else {
            return (400, headers, oauthError(400, "invalid_dpop_proof", "missing or malformed proof").payload)
        }
        if let failure = verify(proof, request: request, expectedNonce: authorizationServerNonce, accessToken: nil) {
            return (400, headers, oauthError(400, failure.error, failure.description).payload)
        }
        if let failure = authenticateClient(form) {
            return (401, headers, failure.payload)
        }
        if let forced = forcedErrors[endpoint] {
            return (forced.status, headers, oauthError(forced.status, forced.error).payload)
        }
        let outcome = handler(form, proof)
        return (outcome.status, headers, outcome.payload)
    }

    private func verify(
        _ proof: DecodedDPoPProof,
        request: URLRequest,
        expectedNonce: String,
        accessToken: String?
    ) -> (error: String, description: String)? {
        guard proof.signatureValid else { return ("invalid_dpop_proof", "bad signature") }
        guard proof.header["typ"] as? String == "dpop+jwt", proof.header["alg"] as? String == "ES256" else {
            return ("invalid_dpop_proof", "bad header")
        }
        guard proof.htm == request.httpMethod else { return ("invalid_dpop_proof", "htm mismatch") }
        var expectedHTU = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        expectedHTU.query = nil
        expectedHTU.fragment = nil
        guard proof.htu == expectedHTU.string else { return ("invalid_dpop_proof", "htu mismatch") }
        guard let iat = proof.iat, abs(Int(Date().timeIntervalSince1970) - iat) <= 60 else {
            return ("invalid_dpop_proof", "iat outside window")
        }
        guard let jti = proof.jti, !jti.isEmpty, seenJTIs.insert(jti).inserted else {
            return ("invalid_dpop_proof", "jti missing or replayed")
        }
        if let accessToken {
            guard proof.ath == TestJOSE.sha256Base64URL(accessToken) else {
                return ("invalid_dpop_proof", "ath mismatch")
            }
        } else {
            guard proof.ath == nil else { return ("invalid_dpop_proof", "unexpected ath") }
        }
        if enforcesNonce || proof.nonce != nil {
            guard proof.nonce == expectedNonce else {
                return ("use_dpop_nonce", "nonce required")
            }
        }
        return nil
    }

    private func authenticateClient(_ form: [String: String]) -> Outcome? {
        guard let clientID = form["client_id"], !clientID.isEmpty else {
            return oauthError(401, "invalid_client", "client_id required")
        }
        switch clientAuthentication {
        case .none:
            guard form["client_assertion"] == nil else {
                return oauthError(401, "invalid_client", "public client sent an assertion")
            }
            return nil
        case .opaqueSingleUse:
            guard form["client_assertion_type"] == "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
                  let assertion = form["client_assertion"], seenAssertions.insert(assertion).inserted
            else {
                return oauthError(401, "invalid_client", "assertion missing or replayed")
            }
            return nil
        case let .jwks(keys):
            guard form["client_assertion_type"] == "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
                  let assertion = form["client_assertion"]
            else {
                return oauthError(401, "invalid_client", "assertion required")
            }
            let parts = assertion.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3,
                  let header = TestJOSE.decodeObject(parts[0]),
                  let payload = TestJOSE.decodeObject(parts[1]),
                  header["alg"] as? String == "ES256",
                  let kid = header["kid"] as? String,
                  let key = keys.first(where: { $0["kid"] == kid }),
                  let x = key["x"], let y = key["y"],
                  TestJOSE.verifyES256(assertion, x: x, y: y)
            else {
                return oauthError(401, "invalid_client", "assertion signature")
            }
            let now = Int(Date().timeIntervalSince1970)
            guard payload["iss"] as? String == clientID, payload["sub"] as? String == clientID,
                  payload["aud"] as? String == issuer,
                  let exp = payload["exp"] as? Int, exp > now,
                  let iat = payload["iat"] as? Int, abs(now - iat) <= 60,
                  let jti = payload["jti"] as? String, seenAssertions.insert(jti).inserted
            else {
                return oauthError(401, "invalid_client", "assertion claims or replay")
            }
            return nil
        }
    }

    private func handlePAR(_ form: [String: String], _ proof: DecodedDPoPProof) -> Outcome {
        guard form["response_type"] == "code", form["code_challenge_method"] == "S256",
              let challenge = form["code_challenge"], !challenge.isEmpty,
              let state = form["state"], !state.isEmpty,
              let redirectURI = form["redirect_uri"], !redirectURI.isEmpty,
              let scope = form["scope"], scope.split(separator: " ").contains("atproto"),
              form["client_secret"] == nil
        else {
            return oauthError(400, "invalid_request", "bad authorization request")
        }
        counter += 1
        let requestURI = "urn:ietf:params:oauth:request_uri:req-\(counter)"
        pushed[requestURI] = PushedRequest(parameters: form, jkt: proof.thumbprint)
        return (201, ["request_uri": requestURI, "expires_in": 300])
    }

    private func handleToken(_ form: [String: String], _ proof: DecodedDPoPProof) -> Outcome {
        switch form["grant_type"] {
        case "authorization_code":
            guard let code = form["code"], let entry = codes.removeValue(forKey: code) else {
                return oauthError(400, "invalid_grant", "unknown or spent code")
            }
            guard var grant = grants[entry.grantID] else { return oauthError(400, "invalid_grant") }
            guard form["redirect_uri"] == entry.redirectURI, form["client_id"] == entry.clientID else {
                return oauthError(400, "invalid_grant", "redirect_uri or client_id mismatch")
            }
            guard let verifier = form["code_verifier"],
                  TestJOSE.sha256Base64URL(verifier) == entry.codeChallenge
            else {
                return oauthError(400, "invalid_grant", "PKCE verification failed")
            }
            guard proof.thumbprint == grant.jkt else {
                return oauthError(400, "invalid_dpop_proof", "key differs from the pushed request")
            }
            grant.jkt = proof.thumbprint
            grants[entry.grantID] = grant
            return (200, issueTokens(grantID: entry.grantID, grantType: "authorization_code"))

        case "refresh_token":
            guard let token = form["refresh_token"], let entry = refreshTokens[token] else {
                return oauthError(400, "invalid_grant", "unknown refresh token")
            }
            guard var grant = grants[entry.grantID], !grant.revoked else {
                return oauthError(400, "invalid_grant", "session revoked")
            }
            if entry.used {
                // Replay of a rotated token: the whole session is revoked.
                grant.revoked = true
                grants[entry.grantID] = grant
                return oauthError(400, "invalid_grant", "refresh token replayed")
            }
            guard proof.thumbprint == grant.jkt, form["client_id"] == grant.clientID else {
                return oauthError(400, "invalid_grant", "key or client mismatch")
            }
            if rotatesRefreshTokens {
                refreshTokens[token] = (entry.grantID, true)
            }
            return (200, issueTokens(grantID: entry.grantID, grantType: "refresh_token"))

        default:
            return oauthError(400, "unsupported_grant_type")
        }
    }

    private func issueTokens(grantID: String, grantType: String) -> [String: Any] {
        counter += 1
        let accessToken = "access-\(counter)"
        accessTokens[accessToken] = grantID
        let grant = grants[grantID]!
        var response: [String: Any] = [
            "access_token": accessToken,
            "token_type": "DPoP",
            "scope": grant.scope,
            "sub": grant.sub,
        ]
        if let accessTokenLifetime {
            response["expires_in"] = accessTokenLifetime
        }
        if rotatesRefreshTokens || grantType == "authorization_code" {
            let refreshToken = "refresh-\(counter)"
            refreshTokens[refreshToken] = (grantID, false)
            response["refresh_token"] = refreshToken
        }
        return tokenResponseTransform?(response, grantType) ?? response
    }

    private func handleRevoke(_ form: [String: String], _: DecodedDPoPProof) -> Outcome {
        guard let token = form["token"] else { return oauthError(400, "invalid_request", "token required") }
        if let grantID = refreshTokens[token]?.grantID ?? accessTokens[token] {
            grants[grantID]?.revoked = true
        }
        // RFC 7009: unknown tokens are answered 200 as well.
        return (200, [:])
    }

    // MARK: Resource server

    private func handleResource(request: URLRequest, proof: DecodedDPoPProof?) -> (Int, [String: String], Any) {
        var headers: [String: String] = [:]
        if !omitsNonceOn.contains(.resource) {
            headers["DPoP-Nonce"] = resourceServerNonce
        }
        guard let authorization = request.value(forHTTPHeaderField: "Authorization"),
              authorization.hasPrefix("DPoP "), let proof
        else {
            headers["WWW-Authenticate"] = "DPoP error=\"invalid_token\""
            return (401, headers, ["error": "AuthMissing", "message": "DPoP authorization required"])
        }
        let token = String(authorization.dropFirst("DPoP ".count))
        if let failure = verify(proof, request: request, expectedNonce: resourceServerNonce, accessToken: token) {
            // RFC 9449 §9: resource servers signal through WWW-Authenticate.
            headers["WWW-Authenticate"] = "DPoP error=\"\(failure.error)\", error_description=\"\(failure.description)\""
            let bodyError = resourceNonceErrorInBody ? failure.error : "AuthenticationRequired"
            return (401, headers, ["error": bodyError, "message": failure.description])
        }
        guard let grantID = accessTokens[token], let grant = grants[grantID], !grant.revoked,
              grant.jkt == proof.thumbprint
        else {
            headers["WWW-Authenticate"] = "DPoP error=\"invalid_token\""
            return (401, headers, ["error": "InvalidToken", "message": "token invalid, revoked or bound to another key"])
        }
        if let forced = forcedErrors[.resource] {
            return (forced.status, headers, ["error": forced.error, "message": forced.error])
        }
        return (200, headers, ["did": grant.sub, "handle": "user.test", "active": true])
    }

    // MARK: Helpers

    static func parseForm(_ body: Data) -> [String: String] {
        guard let text = String(data: body, encoding: .utf8), !text.isEmpty else { return [:] }
        var form: [String: String] = [:]
        for pair in text.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = String(parts[0]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(parts[0])
            let rawValue = parts.count > 1 ? String(parts[1]) : ""
            form[name] = rawValue.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? rawValue
        }
        return form
    }
}

// MARK: - Identity

/// A DID resolver over a fixed table, standing in for DID-document resolution.
final class OAuthTestDIDResolver: DIDResolving, @unchecked Sendable {
    private let lock = NSLock()
    private var handles: [String: String] = [:]
    private var services: [String: (handle: String, pds: URL)] = [:]

    func register(did: String, handle: String, pds: URL) {
        lock.withLock {
            handles[handle] = did
            services[did] = (handle, pds)
        }
    }

    func resolveHandleToDID(handle: String) async throws -> String {
        guard let did = lock.withLock({ handles[handle] }) else { throw NetworkError.requestFailed }
        return did
    }

    func resolveDIDToPDSURL(did: String) async throws -> URL {
        guard let entry = lock.withLock({ services[did] }) else { throw NetworkError.requestFailed }
        return entry.pds
    }

    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
        guard let entry = lock.withLock({ services[did] }) else { throw NetworkError.requestFailed }
        return (entry.handle, entry.pds)
    }
}

// MARK: - Client under test

/// One OAuth client instance wired exactly as `ATProtoClient` wires it: real
/// keychain storage (over the in-memory backend), a real `AccountManager`, a
/// real `NetworkService` with the strategy installed as its authentication provider.
struct OAuthTestClient {
    static let clientID = "https://app.oauth.test/oauth-client-metadata.json"
    static let redirectURI = "test.oauth.app:/callback"

    let strategy: any OAuthCoreBackedStrategy
    let core: OAuthCore
    let storage: KeychainStorage
    let accountManager: AccountManager
    let networkService: NetworkService
    let resolver: OAuthTestDIDResolver

    static func make(
        namespace: String,
        server: FakeOAuthServer,
        resolver: OAuthTestDIDResolver = OAuthTestDIDResolver(),
        scope: String = "atproto transition:generic",
        signer: (any OAuthClientAssertionSigner)? = nil,
        cabBackendSession: URLSession? = nil
    ) async -> OAuthTestClient {
        let storage = KeychainStorage(namespace: namespace)
        let accountManager = await AccountManager(storage: storage)
        let networkService = NetworkService(baseURL: server.pdsURL)
        let config = OAuthConfig(clientId: clientID, redirectUri: redirectURI, scope: scope)
        let strategy: any OAuthCoreBackedStrategy
        if let cabBackendSession {
            strategy = CABOAuthStrategy(
                backendURL: URL(string: "https://cab.oauth.test")!,
                storage: storage,
                accountManager: accountManager,
                networkService: networkService,
                oauthConfig: config,
                didResolver: resolver,
                urlSession: cabBackendSession
            )
        } else {
            strategy = PublicOAuthStrategy(
                storage: storage,
                accountManager: accountManager,
                networkService: networkService,
                oauthConfig: config,
                didResolver: resolver,
                clientAssertionSigner: signer
            )
        }
        await networkService.setAuthenticationProvider(strategy)
        return OAuthTestClient(
            strategy: strategy,
            core: strategy.core,
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            resolver: resolver
        )
    }

    /// Runs a complete identifier-first login for `did` and returns the signed-in DID.
    @discardableResult
    func signIn(handle: String, did: String, server: FakeOAuthServer) async throws -> String {
        resolver.register(did: did, handle: handle, pds: server.pdsURL)
        let (url, _) = try await strategy.startOAuthFlowWithState(identifier: handle)
        let redirect = try server.approve(url, as: did)
        return try await strategy.handleOAuthCallback(url: redirect).did
    }

    /// Performs an authenticated XRPC request through the real network stack.
    func getSession(query: String = "") async throws -> (Data, HTTPURLResponse) {
        let base = await networkService.baseURL
        let url = URL(string: "\(base.absoluteString)/xrpc/com.atproto.server.getSession\(query)")!
        let (data, response) = try await networkService.request(URLRequest(url: url), skipTokenRefresh: false)
        return (data, try #require(response as? HTTPURLResponse))
    }
}
