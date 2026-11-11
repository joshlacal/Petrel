//
//  OAuthClientAuthentication.swift
//  Petrel
//
//  How an OAuth client identifies itself to the authorization server: as a
//  public client (`client_id` only) or as a confidential client presenting a
//  signed `private_key_jwt` client assertion, minted either in-process or by a
//  Client Assertion Backend.
//

import Crypto
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import PetrelCrypto

/// The DPoP key that signs a request to the authorization server.
enum DPoPKeySource: Sendable, Equatable {
    /// The ephemeral key of an authorization flow that has not produced an
    /// account yet (raw P-256 private key representation).
    case flow(Data)
    /// The persisted key of a signed-in account, by DID.
    case account(String)
}

/// Produces the client-authentication form parameters for one request to an
/// authorization server.
///
/// Implementations are called once per HTTP attempt, including the retry after
/// a `use_dpop_nonce` challenge, so a client assertion (whose `jti` is
/// single-use) is never sent twice.
protocol OAuthClientAuthenticating: Sendable {
    /// The token-endpoint authentication method these parameters implement.
    var method: OAuthClientAuthenticationMethod { get }

    /// - Parameters:
    ///   - issuer: The validated issuer of the authorization server being called;
    ///     the audience of any assertion.
    ///   - key: The DPoP key signing the request the parameters will accompany.
    ///   - core: The OAuth core, for implementations that need a DPoP proof of their own.
    /// - Returns: Form parameters, always including `client_id`.
    func parameters(forIssuer issuer: String, key: DPoPKeySource, core: OAuthCore) async throws -> [String: String]
}

let oauthClientAssertionTypeJWTBearer = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"

/// A public client: identified by `client_id` alone (`token_endpoint_auth_method: none`).
struct PublicClientAuthenticator: OAuthClientAuthenticating {
    let clientId: String
    let method = OAuthClientAuthenticationMethod.none

    func parameters(forIssuer _: String, key _: DPoPKeySource, core _: OAuthCore) async throws -> [String: String] {
        ["client_id": clientId]
    }
}

// MARK: - In-process confidential client

/// Signs `private_key_jwt` client assertions for a confidential OAuth client.
///
/// Implement this to keep the signing key somewhere Petrel cannot read it (a
/// KMS, an HSM, the Secure Enclave). For a key held in process memory use
/// ``OAuthClientAssertionKey``.
public protocol OAuthClientAssertionSigner: Sendable {
    /// The `kid` of the signing key. It must match a key published in the
    /// `jwks` (or `jwks_uri`) of the client metadata document.
    var keyID: String { get }

    /// Signs `signingInput` (the ASCII `header.payload` of a JWT) with ES256.
    /// - Returns: The 64-byte raw `r || s` signature.
    func signES256(_ signingInput: Data) async throws -> Data
}

/// An in-memory ES256 (P-256) client-authentication key for a confidential
/// OAuth client, with the JWK and JWKS a client metadata document must publish.
public struct OAuthClientAssertionKey: OAuthClientAssertionSigner, Hashable {
    /// The key identifier advertised in the JWKS and sent as the assertion's `kid`.
    public let keyID: String
    private let rawRepresentation: Data

    /// Wraps an existing P-256 private key.
    /// - Parameters:
    ///   - keyID: The `kid` to publish and sign with. Must not be empty.
    ///   - rawRepresentation: The 32-byte raw private scalar.
    /// - Throws: ``OAuthClientAssertionError/invalidKey`` when the bytes are not a
    ///   P-256 private key or `keyID` is empty.
    public init(keyID: String, rawRepresentation: Data) throws {
        guard !keyID.isEmpty, (try? P256.Signing.PrivateKey(rawRepresentation: rawRepresentation)) != nil else {
            throw OAuthClientAssertionError.invalidKey
        }
        self.keyID = keyID
        self.rawRepresentation = rawRepresentation
    }

    /// Wraps a PEM-encoded (SEC1 or PKCS#8) P-256 private key.
    /// - Throws: ``OAuthClientAssertionError/invalidKey`` when the PEM is not a
    ///   P-256 private key or `keyID` is empty.
    public init(keyID: String, pemRepresentation: String) throws {
        guard let key = try? P256.Signing.PrivateKey(pemRepresentation: pemRepresentation) else {
            throw OAuthClientAssertionError.invalidKey
        }
        try self.init(keyID: keyID, rawRepresentation: key.rawRepresentation)
    }

    /// Generates a new random key.
    /// - Parameter keyID: The `kid` to publish and sign with; a random one by default.
    public static func generate(keyID: String = UUID().uuidString) throws -> OAuthClientAssertionKey {
        try OAuthClientAssertionKey(keyID: keyID, rawRepresentation: P256.Signing.PrivateKey().rawRepresentation)
    }

    /// The public key as a JWK (`kty`, `crv`, `x`, `y`, `kid`, `use`, `alg`).
    /// Contains no private material.
    public var publicJWK: [String: String] {
        // The initializers validated the bytes, so re-deriving the key cannot fail.
        guard let key = try? P256.Signing.PrivateKey(rawRepresentation: rawRepresentation) else { return [:] }
        let point = key.publicKey.x963Representation
        return [
            "kty": "EC",
            "crv": "P-256",
            "x": JWTBase64URL.encode(Data(point.dropFirst().prefix(32))),
            "y": JWTBase64URL.encode(Data(point.suffix(32))),
            "kid": keyID,
            "use": "sig",
            "alg": "ES256",
        ]
    }

    /// A JWKS document (`{"keys": [...]}`) publishing the public halves of
    /// `keys`, suitable for a client metadata `jwks` member or a `jwks_uri` endpoint.
    public static func jwksDocument(for keys: [OAuthClientAssertionKey]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: ["keys": keys.map(\.publicJWK)],
            options: [.sortedKeys]
        )
    }

    /// Signs `signingInput` with this key and returns the 64-byte raw `r || s` signature.
    public func signES256(_ signingInput: Data) async throws -> Data {
        let key = try P256.Signing.PrivateKey(rawRepresentation: rawRepresentation)
        return try P256WireSignature.sign(signingInput, using: key)
    }
}

/// Errors from confidential-client authentication.
public enum OAuthClientAssertionError: Error, LocalizedError, Equatable, Sendable {
    /// The supplied key material is not a usable P-256 private key, or its key ID is empty.
    case invalidKey
    /// The signer returned something other than a 64-byte ES256 signature.
    case invalidSignature

    /// A sentence describing what was wrong with the key or signature.
    public var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "The client authentication key is not a valid P-256 private key with a key ID."
        case .invalidSignature:
            return "The client assertion signer did not return a 64-byte ES256 signature."
        }
    }
}

/// A confidential client that signs its own assertions (RFC 7523 `private_key_jwt`).
struct SignedClientAuthenticator: OAuthClientAuthenticating {
    let clientId: String
    let signer: any OAuthClientAssertionSigner
    let method = OAuthClientAuthenticationMethod.privateKeyJWT

    /// Lifetime of one assertion. Assertions are minted per request and used once.
    static let assertionLifetime = 60

    func parameters(forIssuer issuer: String, key _: DPoPKeySource, core _: OAuthCore) async throws -> [String: String] {
        try await [
            "client_id": clientId,
            "client_assertion_type": oauthClientAssertionTypeJWTBearer,
            "client_assertion": mintAssertion(audience: issuer),
        ]
    }

    /// Mints a client assertion: `iss` = `sub` = the client ID, `aud` = the
    /// authorization server issuer, a unique `jti`, `iat`, and a short `exp`.
    func mintAssertion(audience: String, now: Date = Date()) async throws -> String {
        let issuedAt = Int(now.timeIntervalSince1970)
        let header: [String: String] = ["alg": "ES256", "typ": "JWT", "kid": signer.keyID]
        let payload: [String: Any] = [
            "iss": clientId,
            "sub": clientId,
            "aud": audience,
            "jti": UUID().uuidString,
            "iat": issuedAt,
            "exp": issuedAt + Self.assertionLifetime,
        ]
        let headerPart = try JWTBase64URL.encode(JSONSerialization.data(withJSONObject: header, options: [.sortedKeys]))
        let payloadPart = try JWTBase64URL.encode(JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
        let signingInput = "\(headerPart).\(payloadPart)"
        let signature = try await signer.signES256(Data(signingInput.utf8))
        guard signature.count == P256WireSignature.rawByteCount else {
            throw OAuthClientAssertionError.invalidSignature
        }
        return "\(signingInput).\(JWTBase64URL.encode(signature))"
    }
}

// MARK: - Client Assertion Backend

/// The response of a Client Assertion Backend's assertion endpoint.
struct ClientAssertionResponse: Decodable {
    let clientId: String
    let clientAssertion: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case clientAssertion = "client_assertion"
    }
}

/// A confidential client whose assertions are minted by a Client Assertion
/// Backend, which holds the signing key and binds each assertion to the DPoP
/// key that requested it.
struct CABClientAuthenticator: OAuthClientAuthenticating {
    let backendURL: URL
    let urlSession: URLSession
    let method = OAuthClientAuthenticationMethod.privateKeyJWT

    func parameters(forIssuer issuer: String, key: DPoPKeySource, core: OAuthCore) async throws -> [String: String] {
        let response = try await fetchAssertion(audience: issuer, key: key, core: core)
        return [
            "client_id": response.clientId,
            "client_assertion_type": oauthClientAssertionTypeJWTBearer,
            "client_assertion": response.clientAssertion,
        ]
    }

    /// Fetches a DPoP-bound client assertion for `audience`. Retries exactly once
    /// when the backend answers 400 `use_dpop_nonce` with a `DPoP-Nonce` header.
    ///
    /// The authorization server's nonces are deliberately never sent to the
    /// backend: backend nonces come only from the backend's own challenge.
    func fetchAssertion(audience: String, key: DPoPKeySource, core: OAuthCore) async throws -> ClientAssertionResponse {
        try await fetchAssertionAttempt(audience: audience, key: key, core: core, nonce: nil, isRetry: false)
    }

    private func fetchAssertionAttempt(
        audience: String,
        key: DPoPKeySource,
        core: OAuthCore,
        nonce: String?,
        isRetry: Bool
    ) async throws -> ClientAssertionResponse {
        let assertionURL = backendURL.appendingPathComponent("oauth/client-assertion")

        let dpopProof: String
        switch key {
        case let .flow(rawRepresentation):
            dpopProof = try await core.createDPoPProof(
                for: "POST",
                url: assertionURL.absoluteString,
                type: .tokenRequest,
                ephemeralKeyRawRepresentation: rawRepresentation,
                nonce: nonce,
                usesStoredNonce: false
            )
        case let .account(did):
            dpopProof = try await core.createDPoPProof(
                for: "POST",
                url: assertionURL.absoluteString,
                type: .tokenRefresh,
                did: did,
                nonce: nonce,
                usesStoredNonce: false
            )
        }

        var request = URLRequest(url: assertionURL)
        request.httpMethod = "POST"
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = await core.encodeFormData(["aud": audience])
        request.timeoutInterval = 30.0

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if (200 ..< 300).contains(httpResponse.statusCode) {
            return try JSONCoders.decode(ClientAssertionResponse.self, from: data)
        }

        let oauthError = try? JSONCoders.decode(OAuthErrorResponse.self, from: data)
        if !isRetry,
           oauthError?.error == "use_dpop_nonce",
           let serverNonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce")
        {
            return try await fetchAssertionAttempt(
                audience: audience, key: key, core: core, nonce: serverNonce, isRetry: true
            )
        }

        throw ClientAssertionBackendError(
            statusCode: httpResponse.statusCode,
            code: oauthError?.error
        )
    }
}
