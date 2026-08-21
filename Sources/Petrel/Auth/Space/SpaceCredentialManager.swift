//
//  SpaceCredentialManager.swift
//  Petrel
//

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - SpaceCredential

public struct SpaceCredential: Sendable, Equatable {
    public let token: String
    public let expiresAt: Date
    public let keyRawRepresentation: Data

    public init(token: String, expiresAt: Date, keyRawRepresentation: Data) {
        self.token = token
        self.expiresAt = expiresAt
        self.keyRawRepresentation = keyRawRepresentation
    }
}

// MARK: - SpaceCredentialError

public enum SpaceCredentialError: Error, LocalizedError, Equatable, Sendable {
    case missingDelegationToken
    case exchangeFailed(statusCode: Int, message: String)
    case invalidToken(String)
    case invalidResponse
    case invalidKey
    case invalidSpaceRef(String)

    public var errorDescription: String? {
        switch self {
        case .missingDelegationToken:
            return "Failed to obtain delegation token for space"
        case .exchangeFailed(let statusCode, let message):
            return "Space credential exchange failed with status \(statusCode): \(message)"
        case .invalidToken(let reason):
            return "Invalid space credential token: \(reason)"
        case .invalidResponse:
            return "Invalid HTTP response from server"
        case .invalidKey:
            return "Failed to initialize cryptographic key"
        case .invalidSpaceRef(let ref):
            return "Invalid space reference: \(ref)"
        }
    }
}

// MARK: - SpaceDPoP

enum SpaceDPoP {
    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// dpop+jwt proof signed by `key`. `accessToken` non-nil adds `ath`.
    static func proof(
        key: P256.Signing.PrivateKey,
        htm: String,
        htu: String,
        accessToken: String?,
        now: Date = .init()
    ) throws -> String {
        let x963 = key.publicKey.x963Representation
        let xData = Data(x963.dropFirst().prefix(32))
        let yData = Data(x963.suffix(32))

        let headerDict: [String: Any] = [
            "typ": "dpop+jwt",
            "alg": "ES256",
            "jwk": [
                "kty": "EC",
                "crv": "P-256",
                "x": base64URLEncode(xData),
                "y": base64URLEncode(yData),
            ] as [String: Any],
        ]

        var payloadDict: [String: Any] = [
            "jti": "\(UUID().uuidString)-\(UInt64.random(in: 0...UInt64.max))",
            "htm": htm,
            "htu": htu,
            "iat": Int(now.timeIntervalSince1970),
        ]

        if let accessToken {
            let hash = SHA256.hash(data: Data(accessToken.utf8))
            payloadDict["ath"] = base64URLEncode(Data(hash))
        }

        let headerData = try JSONSerialization.data(withJSONObject: headerDict, options: [])
        let payloadData = try JSONSerialization.data(withJSONObject: payloadDict, options: [])

        let headerB64 = base64URLEncode(headerData)
        let payloadB64 = base64URLEncode(payloadData)

        let signingInput = "\(headerB64).\(payloadB64)"
        let signature = try key.signature(for: Data(signingInput.utf8))
        let sigB64 = base64URLEncode(signature.rawRepresentation)

        return "\(signingInput).\(sigB64)"
    }

    /// Decode a JWT payload without verification (for exp extraction).
    static func payload(ofJWT jwt: String) throws -> [String: Any] {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else {
            throw SpaceCredentialError.invalidToken("Malformed JWT: expected at least 2 parts")
        }

        var s = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 {
            s += "="
        }

        guard let data = Data(base64Encoded: s) else {
            throw SpaceCredentialError.invalidToken("Invalid base64 encoding in JWT payload")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpaceCredentialError.invalidToken("JWT payload is not a valid JSON object")
        }

        return json
    }
}

// MARK: - SpaceCredentialManager

public actor SpaceCredentialManager {
    public typealias DelegationTokenProvider = @Sendable (SpaceRef) async throws -> String

    private let client: ATProtoClient
    private let resolver: SpaceHostResolver
    private let urlSession: URLSession
    private let delegationTokenProvider: DelegationTokenProvider

    private var cache: [SpaceRef: SpaceCredential] = [:]
    private var inFlight: [SpaceRef: Task<SpaceCredential, Error>] = [:]

    public init(
        client: ATProtoClient,
        resolver: SpaceHostResolver,
        urlSession: URLSession = .shared
    ) {
        self.client = client
        self.resolver = resolver
        self.urlSession = urlSession
        self.delegationTokenProvider = { [client] space in
            let (_, output) = try await client.com.atproto.space.getDelegationToken(
                input: .init(space: space)
            )
            guard let token = output?.token else {
                throw SpaceCredentialError.missingDelegationToken
            }
            return token
        }
    }

    /// Internal initializer with injectable delegation token provider for tests.
    init(
        client: ATProtoClient,
        resolver: SpaceHostResolver,
        urlSession: URLSession = .shared,
        delegationTokenProvider: @escaping DelegationTokenProvider
    ) {
        self.client = client
        self.resolver = resolver
        self.urlSession = urlSession
        self.delegationTokenProvider = delegationTokenProvider
    }

    /// Cached credential for the space, exchanging a fresh one when absent
    /// or within 60s of expiry.
    public func credential(for space: SpaceRef) async throws -> SpaceCredential {
        let now = Date()
        if let cached = cache[space], cached.expiresAt > now.addingTimeInterval(60) {
            return cached
        }

        if let inFlightTask = inFlight[space] {
            return try await inFlightTask.value
        }

        let task = Task { [weak self] () -> SpaceCredential in
            guard let self else {
                throw SpaceCredentialError.invalidResponse
            }
            return try await self.exchangeCredential(for: space)
        }

        inFlight[space] = task
        defer { inFlight.removeValue(forKey: space) }

        do {
            let credential = try await task.value
            cache[space] = credential
            return credential
        } catch {
            cache.removeValue(forKey: space)
            throw error
        }
    }

    /// Drop cached credential (e.g. on SpaceDeleted).
    public func invalidate(_ space: SpaceRef) {
        cache.removeValue(forKey: space)
    }

    /// Performs an authenticated GET against an arbitrary repo host:
    /// Authorization: DPoP <credential> plus a per-request DPoP proof with
    /// htm/htu/iat/jti and ath = base64url(SHA256(credential)).
    public func get(url: URL, space: SpaceRef) async throws -> (Data, HTTPURLResponse) {
        let cred = try await credential(for: space)
        guard let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: cred.keyRawRepresentation) else {
            throw SpaceCredentialError.invalidKey
        }

        let htu = canonicalHTU(url)
        let dpopProof = try SpaceDPoP.proof(
            key: privateKey,
            htm: "GET",
            htu: htu,
            accessToken: cred.token
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("DPoP \(cred.token)", forHTTPHeaderField: "Authorization")
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpaceCredentialError.invalidResponse
        }
        return (data, httpResponse)
    }

    // MARK: - Private Helpers

    private func exchangeCredential(for space: SpaceRef) async throws -> SpaceCredential {
        let authorityDID = space.spaceDID
        guard !authorityDID.isEmpty else {
            throw SpaceCredentialError.invalidSpaceRef(space.uriString())
        }

        let endpoints = try await resolver.resolve(authorityDID: authorityDID)
        let delegationToken = try await delegationTokenProvider(space)

        let ephemeralKey = P256.Signing.PrivateKey()

        let exchangeURL: URL
        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            exchangeURL = endpoints.spaceHost.appending(path: "xrpc/com.atproto.space.getSpaceCredential")
        } else {
            exchangeURL = endpoints.spaceHost.appendingPathComponent("xrpc/com.atproto.space.getSpaceCredential")
        }

        let htu = canonicalHTU(exchangeURL)
        let dpopProof = try SpaceDPoP.proof(
            key: ephemeralKey,
            htm: "POST",
            htu: htu,
            accessToken: nil
        )

        var request = URLRequest(url: exchangeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(delegationToken)", forHTTPHeaderField: "Authorization")
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")

        let input = ComAtprotoSpaceGetSpaceCredential.Input(space: space)
        request.httpBody = try JSONEncoder().encode(input)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpaceCredentialError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw SpaceCredentialError.exchangeFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let output = try JSONDecoder().decode(ComAtprotoSpaceGetSpaceCredential.Output.self, from: data)
        let token = output.credential

        let payload = try SpaceDPoP.payload(ofJWT: token)
        guard let expValue = payload["exp"] else {
            throw SpaceCredentialError.invalidToken("Missing exp claim in credential JWT")
        }

        let expSeconds: TimeInterval
        if let num = expValue as? NSNumber {
            expSeconds = num.doubleValue
        } else if let intVal = expValue as? Int {
            expSeconds = TimeInterval(intVal)
        } else if let doubleVal = expValue as? Double {
            expSeconds = doubleVal
        } else {
            throw SpaceCredentialError.invalidToken("Invalid exp claim type in credential JWT")
        }

        let expiresAt = Date(timeIntervalSince1970: expSeconds)
        return SpaceCredential(
            token: token,
            expiresAt: expiresAt,
            keyRawRepresentation: ephemeralKey.rawRepresentation
        )
    }

    private func canonicalHTU(_ url: URL) -> String {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        comps.scheme = comps.scheme?.lowercased()
        comps.host = comps.host?.lowercased()
        if (comps.scheme == "https" && comps.port == 443) || (comps.scheme == "http" && comps.port == 80) {
            comps.port = nil
        }
        if comps.path.isEmpty { comps.path = "/" }
        comps.fragment = nil
        comps.query = nil
        return comps.string ?? url.absoluteString
    }
}
