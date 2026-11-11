import Foundation

extension OAuthAuthorizationServer {
    static let requestURIPrefix = "urn:ietf:params:oauth:request_uri:"

    private struct PARSuccess: Encodable {
        let requestURI: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case requestURI = "request_uri"
            case expiresIn = "expires_in"
        }
    }

    /// `POST /oauth/par` (RFC 9126). Pushed requests are mandatory for every
    /// client; the authorization endpoint accepts nothing else.
    func handlePushedAuthorizationRequest(_ request: OAuthHTTPRequest) async -> OAuthHTTPResponse {
        let now = clock.now()
        do {
            let fields = try form(request)
            // RFC 9126 §2.1: a pushed request must not itself carry request_uri.
            guard fields["request_uri"] == nil, fields["request"] == nil else {
                throw EndpointError.invalidRequest("request_uri and request are not allowed in a pushed request")
            }
            // DPoP first: a request that is only missing the server nonce is
            // retried by the client with the same body, so it must not have
            // consumed the single-use client assertion.
            let proof = try await requireDPoP(request, path: Path.pushedAuthorizationRequest, now: now)
            let (client, clientKey) = try await authenticateClient(fields, revalidate: false, now: now)
            if let declared = fields["dpop_jkt"], declared != proof.keyThumbprint {
                throw EndpointError.invalidRequest("dpop_jkt does not match the DPoP proof key")
            }

            guard let responseType = fields["response_type"] else {
                throw EndpointError.invalidRequest("response_type is required")
            }
            guard responseType == "code" else {
                throw EndpointError(
                    status: 400, code: "unsupported_response_type",
                    description: "only the code response type is supported"
                )
            }
            var responseMode = OAuthResponseMode.query
            if let requested = fields["response_mode"] {
                guard let known = OAuthResponseMode(rawValue: requested) else {
                    throw EndpointError.invalidRequest("only the query and fragment response modes are supported")
                }
                responseMode = known
            }
            guard fields["code_challenge_method"] == "S256" else {
                throw EndpointError.invalidRequest("code_challenge_method must be S256")
            }
            guard let codeChallenge = fields["code_challenge"], OAuthPKCE.isValidS256Challenge(codeChallenge) else {
                throw EndpointError.invalidRequest("code_challenge must be a S256 challenge")
            }
            guard let state = fields["state"], !state.isEmpty, state.utf8.count <= 1024 else {
                throw EndpointError.invalidRequest("state is required")
            }
            guard let rawRedirect = fields["redirect_uri"], rawRedirect.utf8.count <= 2048,
                  let redirectURI = URL(string: rawRedirect), redirectURI.absoluteString == rawRedirect
            else {
                throw EndpointError.invalidRequest("redirect_uri is required")
            }
            guard client.metadata.matchesRedirectURI(redirectURI) else {
                throw EndpointError.invalidRequest("redirect_uri is not registered for this client")
            }
            let loginHint = fields["login_hint"]
            if let loginHint {
                guard !loginHint.isEmpty, loginHint.utf8.count <= 512,
                      loginHint.utf8.allSatisfy({ $0 > 0x20 && $0 < 0x7F })
                else {
                    throw EndpointError.invalidRequest("login_hint is not a handle or DID")
                }
            }

            guard let rawScope = fields["scope"] else {
                throw EndpointError(status: 400, code: "invalid_scope", description: "scope is required")
            }
            let requestedScopes: Set<String>
            do {
                requestedScopes = try OAuthScopeAdmissionPolicy.admit(
                    requested: OAuthScopeTokenizer.tokenize(rawScope),
                    declaredBy: client.metadata.scopes,
                    unknownScopes: configuration.unknownScopePolicy
                )
            } catch {
                throw EndpointError(status: 400, code: error.oauthErrorCode, description: error.description)
            }
            // A permission set that cannot be resolved fails the request here,
            // before the user is asked anything.
            do {
                _ = try await effectiveGrant(for: requestedScopes, stage: .pushedAuthorizationRequest)
            } catch let error as OAuthScopeResolutionError {
                throw EndpointError(status: 400, code: error.oauthErrorCode, description: error.description)
            } catch {
                throw EndpointError.unavailable
            }

            // A code_challenge may not be reused across sessions, and a state
            // value may not be live in two requests of the same client.
            let clientID = client.metadata.clientID.absoluteString
            let expiresAt = now.addingTimeInterval(configuration.requestLifetime)
            let freshChallenge: Bool
            let freshState: Bool
            do {
                freshChallenge = try await store.claim(
                    namespace: .codeChallenge,
                    digest: digest.digest(codeChallenge, purpose: .codeChallenge),
                    expiresAt: now.addingTimeInterval(configuration.codeChallengeReuseWindow),
                    now: now
                )
                freshState = try await store.claim(
                    namespace: .state,
                    digest: digest.digest("\(clientID)\u{0}\(state)", purpose: .state),
                    expiresAt: expiresAt,
                    now: now
                )
            } catch {
                throw EndpointError.unavailable
            }
            guard freshChallenge else {
                throw EndpointError.invalidRequest("code_challenge was already used")
            }
            guard freshState else {
                throw EndpointError.invalidRequest("state is already in use by another request")
            }

            let requestURI = Self.requestURIPrefix + random.opaqueValue()
            let record = OAuthPushedAuthorizationRequest(
                requestDigest: digest.digest(requestURI, purpose: .requestURI),
                binding: OAuthGrantBinding(
                    issuer: issuer,
                    clientID: clientID,
                    redirectURI: rawRedirect,
                    requestedScopes: requestedScopes,
                    dpopJKT: proof.keyThumbprint,
                    clientKey: clientKey,
                    refreshTokenAllowed: client.metadata.grantTypes.contains("refresh_token")
                ),
                state: state,
                codeChallenge: codeChallenge,
                loginHint: loginHint,
                responseMode: responseMode,
                expiresAt: expiresAt
            )
            do {
                try await store.storePushedAuthorizationRequest(record, now: now)
            } catch {
                throw EndpointError.unavailable
            }
            return json(201, PARSuccess(requestURI: requestURI, expiresIn: Int(configuration.requestLifetime)))
        } catch let error as EndpointError {
            return response(for: error)
        } catch {
            return response(for: .serverError)
        }
    }
}
