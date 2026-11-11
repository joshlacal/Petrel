import Foundation
import PetrelCrypto

/// The two application environments the AT Protocol OAuth profile permits.
public enum OAuthClientApplicationType: String, Codable, Sendable, Equatable {
    /// A browser-based or server-side web application.
    case web
    /// An application installed on a device.
    case native
}

/// How a client authenticates at the token endpoint. The profile has exactly
/// two kinds of client, so there are exactly two methods.
public enum OAuthTokenEndpointAuthenticationMethod: String, Codable, Sendable, Equatable {
    /// A public client, which cannot keep a secret and does not authenticate.
    case none
    /// A confidential client, which signs an assertion with a key it publishes.
    case privateKeyJWT = "private_key_jwt"
}

/// A validated AT Protocol client metadata document. Constructing or decoding
/// this value applies the profile invariants; callers must additionally bind a
/// fetched document to its requested response URL with
/// `validateResponseIdentity(_:)`.
public struct OAuthClientMetadata: Codable, Sendable, Equatable {
    /// The `client_id`: the URL the document was fetched from.
    public let clientID: URL
    /// `application_type`; `web` when the document omits it.
    public let applicationType: OAuthClientApplicationType
    /// `redirect_uris`: at least one, all valid for the application type.
    public let redirectURIs: [URL]
    /// `grant_types`: always includes `authorization_code`.
    public let grantTypes: Set<String>
    /// `response_types`: always includes `code`.
    public let responseTypes: Set<String>
    /// `scope`, split into tokens: every scope the client might request.
    ///
    /// Every member is an RFC 6749 scope-token, which is ASCII, so `String`
    /// identity in this set is byte identity. Whether a requested scope is
    /// covered is decided by meaning (`OAuthScopeAdmissionPolicy`), never by
    /// looking a string up here.
    public let scopes: Set<String>
    /// `token_endpoint_auth_method`; `none` when the document omits it.
    public let tokenEndpointAuthMethod: OAuthTokenEndpointAuthenticationMethod
    /// `token_endpoint_auth_signing_alg`, for confidential clients.
    public let tokenEndpointAuthSigningAlgorithm: String?
    /// `dpop_bound_access_tokens`: always true in a valid document.
    public let dpopBoundAccessTokens: Bool
    /// `jwks`: the confidential client's keys, inline.
    public let jwks: OAuthJSONWebKeySet?
    /// `jwks_uri`: where the confidential client's keys are published.
    public let jwksURI: URL?
    /// `client_name`. Self-declared and unverified.
    public let clientName: String?
    /// `client_uri`. Self-declared; on the same host as the `client_id`.
    public let clientURI: URL?
    /// `logo_uri`. Self-declared and unverified.
    public let logoURI: URL?
    /// `tos_uri`.
    public let termsOfServiceURI: URL?
    /// `policy_uri`.
    public let policyURI: URL?

    /// True only for the specified `http://localhost` development virtual
    /// metadata document. This is never accepted from a fetched JSON body.
    public let isLoopbackDevelopmentClient: Bool

    /// Creates and validates client metadata.
    ///
    /// - Throws: ``OAuthServerError/malformed(_:)`` when any profile rule is
    ///   violated.
    public init(
        clientID: URL,
        applicationType: OAuthClientApplicationType = .web,
        redirectURIs: [URL],
        grantTypes: Set<String>,
        responseTypes: Set<String>,
        scopes: Set<String>,
        tokenEndpointAuthMethod: OAuthTokenEndpointAuthenticationMethod = .none,
        tokenEndpointAuthSigningAlgorithm: String? = nil,
        dpopBoundAccessTokens: Bool,
        jwks: OAuthJSONWebKeySet? = nil,
        jwksURI: URL? = nil,
        clientName: String? = nil,
        clientURI: URL? = nil,
        logoURI: URL? = nil,
        termsOfServiceURI: URL? = nil,
        policyURI: URL? = nil
    ) throws {
        try self.init(
            clientID: clientID,
            applicationType: applicationType,
            redirectURIs: redirectURIs,
            grantTypes: grantTypes,
            responseTypes: responseTypes,
            scopes: scopes,
            tokenEndpointAuthMethod: tokenEndpointAuthMethod,
            tokenEndpointAuthSigningAlgorithm: tokenEndpointAuthSigningAlgorithm,
            dpopBoundAccessTokens: dpopBoundAccessTokens,
            jwks: jwks,
            jwksURI: jwksURI,
            clientName: clientName,
            clientURI: clientURI,
            logoURI: logoURI,
            termsOfServiceURI: termsOfServiceURI,
            policyURI: policyURI,
            isLoopbackDevelopmentClient: false
        )
    }

    private init(
        clientID: URL,
        applicationType: OAuthClientApplicationType,
        redirectURIs: [URL],
        grantTypes: Set<String>,
        responseTypes: Set<String>,
        scopes: Set<String>,
        tokenEndpointAuthMethod: OAuthTokenEndpointAuthenticationMethod,
        tokenEndpointAuthSigningAlgorithm: String?,
        dpopBoundAccessTokens: Bool,
        jwks: OAuthJSONWebKeySet?,
        jwksURI: URL?,
        clientName: String?,
        clientURI: URL?,
        logoURI: URL?,
        termsOfServiceURI: URL?,
        policyURI: URL?,
        isLoopbackDevelopmentClient: Bool
    ) throws {
        self.clientID = clientID
        self.applicationType = applicationType
        self.redirectURIs = redirectURIs
        self.grantTypes = grantTypes
        self.responseTypes = responseTypes
        self.scopes = scopes
        self.tokenEndpointAuthMethod = tokenEndpointAuthMethod
        self.tokenEndpointAuthSigningAlgorithm = tokenEndpointAuthSigningAlgorithm
        self.dpopBoundAccessTokens = dpopBoundAccessTokens
        self.jwks = jwks
        self.jwksURI = jwksURI
        self.clientName = clientName
        self.clientURI = clientURI
        self.logoURI = logoURI
        self.termsOfServiceURI = termsOfServiceURI
        self.policyURI = policyURI
        self.isLoopbackDevelopmentClient = isLoopbackDevelopmentClient
        try validate()
    }

    private enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case applicationType = "application_type"
        case redirectURIs = "redirect_uris"
        case grantTypes = "grant_types"
        case responseTypes = "response_types"
        case scope
        case tokenEndpointAuthMethod = "token_endpoint_auth_method"
        case tokenEndpointAuthSigningAlgorithm = "token_endpoint_auth_signing_alg"
        case dpopBoundAccessTokens = "dpop_bound_access_tokens"
        case jwks
        case jwksURI = "jwks_uri"
        case clientName = "client_name"
        case clientURI = "client_uri"
        case logoURI = "logo_uri"
        case termsOfServiceURI = "tos_uri"
        case policyURI = "policy_uri"
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let clientID = try values.decode(URL.self, forKey: .clientID)
        let applicationType = try values.decodeIfPresent(OAuthClientApplicationType.self, forKey: .applicationType) ?? .web
        let redirectURIs = try values.decode([URL].self, forKey: .redirectURIs)
        let decodedGrantTypes = try values.decode([String].self, forKey: .grantTypes)
        let decodedResponseTypes = try values.decode([String].self, forKey: .responseTypes)
        guard decodedGrantTypes.count == Set(decodedGrantTypes).count,
              decodedResponseTypes.count == Set(decodedResponseTypes).count else {
            throw OAuthServerError.malformed("OAuth client metadata contains duplicate type declarations")
        }
        let grantTypes = Set(decodedGrantTypes)
        let responseTypes = Set(decodedResponseTypes)
        let scopes = try Self.parseScopes(values.decode(String.self, forKey: .scope))
        let method = try values.decodeIfPresent(OAuthTokenEndpointAuthenticationMethod.self, forKey: .tokenEndpointAuthMethod) ?? .none
        try self.init(
            clientID: clientID,
            applicationType: applicationType,
            redirectURIs: redirectURIs,
            grantTypes: grantTypes,
            responseTypes: responseTypes,
            scopes: scopes,
            tokenEndpointAuthMethod: method,
            tokenEndpointAuthSigningAlgorithm: try values.decodeIfPresent(String.self, forKey: .tokenEndpointAuthSigningAlgorithm),
            dpopBoundAccessTokens: try values.decode(Bool.self, forKey: .dpopBoundAccessTokens),
            jwks: try values.decodeIfPresent(OAuthJSONWebKeySet.self, forKey: .jwks),
            jwksURI: try values.decodeIfPresent(URL.self, forKey: .jwksURI),
            clientName: try values.decodeIfPresent(String.self, forKey: .clientName),
            clientURI: try values.decodeIfPresent(URL.self, forKey: .clientURI),
            logoURI: try values.decodeIfPresent(URL.self, forKey: .logoURI),
            termsOfServiceURI: try values.decodeIfPresent(URL.self, forKey: .termsOfServiceURI),
            policyURI: try values.decodeIfPresent(URL.self, forKey: .policyURI),
            isLoopbackDevelopmentClient: false
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(clientID, forKey: .clientID)
        try values.encode(applicationType, forKey: .applicationType)
        try values.encode(redirectURIs, forKey: .redirectURIs)
        try values.encode(grantTypes.sorted(), forKey: .grantTypes)
        try values.encode(responseTypes.sorted(), forKey: .responseTypes)
        try values.encode(scopes.sorted().joined(separator: " "), forKey: .scope)
        try values.encode(tokenEndpointAuthMethod, forKey: .tokenEndpointAuthMethod)
        try values.encodeIfPresent(tokenEndpointAuthSigningAlgorithm, forKey: .tokenEndpointAuthSigningAlgorithm)
        try values.encode(dpopBoundAccessTokens, forKey: .dpopBoundAccessTokens)
        try values.encodeIfPresent(jwks, forKey: .jwks)
        try values.encodeIfPresent(jwksURI, forKey: .jwksURI)
        try values.encodeIfPresent(clientName, forKey: .clientName)
        try values.encodeIfPresent(clientURI, forKey: .clientURI)
        try values.encodeIfPresent(logoURI, forKey: .logoURI)
        try values.encodeIfPresent(termsOfServiceURI, forKey: .termsOfServiceURI)
        try values.encodeIfPresent(policyURI, forKey: .policyURI)
    }

    /// Decodes a fetched document after rejecting duplicate JSON member names.
    /// `responseURL` must be the final response URL; redirects are not an
    /// accepted way to satisfy the `client_id` identity relation.
    public static func decodeValidated(_ data: Data, responseURL: URL) throws -> Self {
        let metadata: Self
        do {
            try StrictJSON.validate(data)
            metadata = try JSONDecoder().decode(Self.self, from: data)
        } catch let error as OAuthServerError {
            throw error
        } catch {
            throw OAuthServerError.malformed("OAuth client metadata document is invalid")
        }
        try metadata.validateResponseIdentity(responseURL)
        return metadata
    }

    /// The response URL comparison is byte-for-byte at the URL string level,
    /// not Foundation URL equivalence. This avoids normalizing away an identity
    /// difference that an HTTP client might otherwise conceal.
    public func validateResponseIdentity(_ responseURL: URL) throws {
        guard !isLoopbackDevelopmentClient,
              clientID.absoluteString == responseURL.absoluteString else {
            throw OAuthServerError.unauthorized("OAuth client metadata response URL does not match client_id")
        }
    }

    /// Checks a requested authorization redirect against the registered
    /// redirect set. The localhost virtual client has the profile's special
    /// port-insensitive loopback matching; all other registrations are exact.
    public func matchesRedirectURI(_ requested: URL) -> Bool {
        if isLoopbackDevelopmentClient {
            return redirectURIs.contains { Self.matchesLoopbackRedirect($0, requested) }
        }
        return redirectURIs.contains { $0.absoluteString == requested.absoluteString }
    }

    /// Generates the exact virtual public-client metadata defined by the AT
    /// Protocol loopback development exception. It performs no HTTP request.
    public static func loopbackDevelopmentMetadata(clientID: URL) throws -> Self {
        guard isLoopbackDevelopmentClientID(clientID) else {
            throw OAuthServerError.malformed("invalid loopback development client_id")
        }
        let components = URLComponents(url: clientID, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let permitted = Set(["redirect_uri", "scope"])
        guard items.allSatisfy({ permitted.contains($0.name) }),
              items.filter({ $0.name == "scope" }).count <= 1 else {
            throw OAuthServerError.malformed("invalid loopback development client_id query")
        }
        let redirectItems = items.filter { $0.name == "redirect_uri" }
        guard redirectItems.allSatisfy({ $0.value != nil }) else {
            throw OAuthServerError.malformed("invalid loopback development redirect_uri")
        }
        let redirectValues = redirectItems.compactMap(\.value)
        let redirects: [URL]
        if redirectValues.isEmpty {
            redirects = [
                URL(string: "http://127.0.0.1/")!,
                URL(string: "http://[::1]/")!,
            ]
        } else {
            redirects = try redirectValues.map {
                guard let url = URL(string: $0), isLoopbackRedirect(url) else {
                    throw OAuthServerError.malformed("invalid loopback development redirect_uri")
                }
                return url
            }
        }
        let scope = try parseScopes(items.first(where: { $0.name == "scope" })?.value ?? "atproto")
        return try Self(
            clientID: clientID,
            applicationType: .native,
            redirectURIs: redirects,
            grantTypes: ["authorization_code", "refresh_token"],
            responseTypes: ["code"],
            scopes: scope,
            tokenEndpointAuthMethod: .none,
            tokenEndpointAuthSigningAlgorithm: nil,
            dpopBoundAccessTokens: true,
            jwks: nil,
            jwksURI: nil,
            clientName: "Development client",
            clientURI: nil,
            logoURI: nil,
            termsOfServiceURI: nil,
            policyURI: nil,
            isLoopbackDevelopmentClient: true
        )
    }

    /// True when `url` is exactly the `http://localhost` development form: no port, no path beyond `/`, no user info, no fragment.
    public static func isLoopbackDevelopmentClientID(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "http", components.host == "localhost",
              components.port == nil, components.user == nil, components.password == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            return false
        }
        return true
    }

    /// Validates the non-development `client_id` URL form before any remote
    /// fetch is attempted. Response identity still has to be validated after
    /// a successful exact-200 document fetch.
    public static func validateStandardClientID(_ url: URL) throws {
        try validateHTTPSClientID(url)
    }

    /// Checks every rule the profile puts on a client metadata document. Every
    /// construction path passes through here.
    func validate() throws {
        if isLoopbackDevelopmentClient {
            guard Self.isLoopbackDevelopmentClientID(clientID) else {
                throw OAuthServerError.malformed("invalid loopback development client_id")
            }
        } else {
            try Self.validateHTTPSClientID(clientID)
        }
        // Scopes are validated lexically here: one charset and one budget
        // shared with the wire tokenizer. Which scopes may actually be granted
        // is decided when a request asks for them.
        let declaredWireForm = scopes.sorted().joined(separator: " ")
        guard !scopes.isEmpty,
              scopes.count <= OAuthScopeBudget.rawInput.scopeCount,
              scopes.allSatisfy(ScopeToken.isScopeToken),
              scopes.allSatisfy({ $0.utf8.count <= OAuthScopeBudget.rawInput.bytesPerScope }),
              declaredWireForm.utf8.count <= OAuthScopeBudget.rawInput.bytesPerSet else {
            throw OAuthServerError.malformed("OAuth client metadata scope is not a valid scope-token list")
        }
        // By what the scope is, not by spelling.
        guard scopes.contains(where: { scope in
            if case .atproto? = try? ATProtoScope.parse(scope) { return true }
            return false
        }) else {
            throw OAuthServerError.malformed("OAuth client metadata scope must include atproto")
        }
        guard !redirectURIs.isEmpty,
              grantTypes.contains("authorization_code"),
              responseTypes.contains("code"),
              dpopBoundAccessTokens else {
            throw OAuthServerError.malformed("OAuth client metadata misses a required AT Protocol field")
        }
        guard redirectURIs.count == Set(redirectURIs.map(\.absoluteString)).count else {
            throw OAuthServerError.malformed("OAuth client metadata contains duplicate redirect URIs")
        }
        try redirectURIs.forEach { try validateRedirectURI($0) }
        guard jwks == nil || jwksURI == nil else {
            throw OAuthServerError.malformed("OAuth client metadata cannot contain both jwks and jwks_uri")
        }
        switch tokenEndpointAuthMethod {
        case .none:
            guard tokenEndpointAuthSigningAlgorithm == nil, jwks == nil, jwksURI == nil else {
                throw OAuthServerError.malformed("public OAuth clients cannot declare client authentication keys")
            }
        case .privateKeyJWT:
            guard let algorithm = tokenEndpointAuthSigningAlgorithm,
                  OAuthJWSAlgorithm(rawValue: algorithm) != nil,
                  jwks != nil || jwksURI != nil
            else {
                throw OAuthServerError.malformed(
                    "confidential OAuth clients require a supported signing algorithm and exactly one JWKS source"
                )
            }
            if let jwksURI {
                try Self.validateHTTPSURL(jwksURI, message: "jwks_uri must be an HTTPS URL")
            }
        }
        if let clientURI {
            try Self.validateHTTPSURL(clientURI, message: "client_uri must be an HTTPS URL")
            guard clientURI.host?.lowercased() == clientID.host?.lowercased() else {
                throw OAuthServerError.malformed("client_uri hostname must match client_id")
            }
        }
        for uri in [logoURI, termsOfServiceURI, policyURI].compactMap({ $0 }) {
            try Self.validateHTTPSURL(uri, message: "display metadata URI must be an HTTPS URL")
        }
    }

    private func validateRedirectURI(_ redirect: URL) throws {
        guard let components = URLComponents(url: redirect, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil, components.fragment == nil else {
            throw OAuthServerError.malformed("OAuth redirect URI is malformed")
        }
        if isLoopbackDevelopmentClient {
            guard Self.isLoopbackRedirect(redirect) else {
                throw OAuthServerError.malformed("loopback development redirect URI is invalid")
            }
            return
        }
        switch applicationType {
        case .web:
            guard components.scheme?.lowercased() == "https", components.host != nil,
                  components.port != 443 else {
                throw OAuthServerError.malformed("web OAuth redirect URI must be HTTPS without default port")
            }
        case .native:
            if components.scheme?.lowercased() == "https" {
                guard components.host?.lowercased() == clientID.host?.lowercased(),
                      components.port == nil else {
                    throw OAuthServerError.malformed("native HTTPS redirect URI must share client_id origin")
                }
            } else {
                guard let scheme = components.scheme?.lowercased(),
                      scheme != "http", scheme != "https",
                      components.host == nil,
                      !components.path.isEmpty, components.path != "/",
                      redirect.absoluteString.hasPrefix("\(scheme):/"),
                      !redirect.absoluteString.hasPrefix("\(scheme)://"),
                      let clientHost = clientID.host?.lowercased(),
                      scheme == clientHost.split(separator: ".").reversed().joined(separator: ".") else {
                    throw OAuthServerError.malformed("native OAuth redirect URI does not match client_id")
                }
            }
        }
    }

    private static func validateHTTPSClientID(_ url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https", components.host != nil,
              components.port == nil, components.user == nil, components.password == nil,
              components.fragment == nil else {
            throw OAuthServerError.malformed("OAuth client_id must be an HTTPS URL without an explicit port")
        }
    }

    private static func validateHTTPSURL(_ url: URL, message: String) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https", components.host != nil,
              components.user == nil, components.password == nil, components.fragment == nil else {
            throw OAuthServerError.malformed(message)
        }
    }

    /// Client metadata `scope` is validated lexically: RFC 6749 scope tokens
    /// under the raw-input budget.
    private static func parseScopes(_ raw: String) throws -> Set<String> {
        do {
            return try OAuthScopeTokenizer.tokenize(raw)
        } catch {
            throw OAuthServerError.malformed("OAuth scope declaration is invalid")
        }
    }

    private static func isLoopbackRedirect(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "http", components.user == nil, components.password == nil,
              components.fragment == nil, !components.path.isEmpty,
              ["127.0.0.1", "::1"].contains(
                  components.host?.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
              ) else {
            return false
        }
        return true
    }

    private static func matchesLoopbackRedirect(_ registered: URL, _ requested: URL) -> Bool {
        guard isLoopbackRedirect(registered), isLoopbackRedirect(requested),
              let left = URLComponents(url: registered, resolvingAgainstBaseURL: false),
              let right = URLComponents(url: requested, resolvingAgainstBaseURL: false) else {
            return false
        }
        return left.scheme == right.scheme &&
            left.host?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")) ==
                right.host?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")) &&
            left.percentEncodedPath == right.percentEncodedPath &&
            left.percentEncodedQuery == right.percentEncodedQuery
    }
}
