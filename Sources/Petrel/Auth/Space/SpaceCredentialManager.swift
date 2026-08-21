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

public struct SpaceCredential: Sendable {
    public let token: String
    public let expiresAt: Date
    public let keyRawRepresentation: Data

    init(token: String, expiresAt: Date, keyRawRepresentation: Data) {
        self.token = token
        self.expiresAt = expiresAt
        self.keyRawRepresentation = keyRawRepresentation
    }
}

// MARK: - SpaceCredentialError

public enum SpaceCredentialError: Error, LocalizedError, Equatable, Sendable {
    case missingDelegationToken
    case spaceDeleted(host: String, message: String?)
    case authorizationRefused(host: String, error: String, message: String?)
    case tokenRejected(host: String, error: String, message: String?, evidence: String? = nil)
    case exchangeFailed(statusCode: Int, message: String)
    case invalidToken(String)
    case invalidResponse
    case invalidKey
    case invalidSpaceRef(String)
    case insecureURL(String)

    public var errorDescription: String? {
        switch self {
        case .missingDelegationToken:
            return "Failed to obtain delegation token for space"
        case .spaceDeleted(let host, let message):
            if let message, !message.isEmpty {
                return "SpaceDeleted: \(message)"
            }
            return "SpaceDeleted: The space was deleted by authority at \(host)"
        case .authorizationRefused(let host, let error, let message):
            if let message, !message.isEmpty {
                return "You no longer have access to this space (\(host) refused authorization: \(message))"
            }
            return "You no longer have access to this space (\(host) refused authorization: \(error))"
        case .tokenRejected(let host, _, _, let evidence):
            if let evidence, !evidence.isEmpty {
                return "\(host) rejected the delegation token as invalid (not an access denial; membership is unaffected). \(host) reports: \(evidence)."
            }
            return "\(host) rejected the delegation token as invalid (not an access denial; membership is unaffected)."
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
        case .insecureURL(let url):
            return "Refusing authenticated request to insecure non-HTTPS URL: \(url)"
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
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              !parts[0].isEmpty,
              !parts[1].isEmpty,
              !parts[2].isEmpty
        else {
            throw SpaceCredentialError.invalidToken("Malformed JWT: expected exactly 3 non-empty parts")
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
    private var generations: [SpaceRef: UInt64] = [:]

    public init(
        client: ATProtoClient,
        resolver: SpaceHostResolver,
        urlSession: URLSession = .shared,
        delegationTokenProvider: (@Sendable (SpaceRef) async throws -> String)? = nil
    ) {
        self.client = client
        self.resolver = resolver
        self.urlSession = urlSession
        self.delegationTokenProvider = delegationTokenProvider ?? { [client] space in
            let (_, output) = try await client.com.atproto.space.getDelegationToken(
                input: .init(space: space)
            )
            guard let token = output?.token else {
                throw SpaceCredentialError.missingDelegationToken
            }
            return token
        }
    }

    /// Cached credential for the space, exchanging a fresh one when absent
    /// or within 60s of expiry.
    public func credential(for space: SpaceRef) async throws -> SpaceCredential {
        let now = Date()
        if let cached = cache[space], cached.expiresAt > now.addingTimeInterval(60) {
            return cached
        }

        let currentGeneration = generations[space, default: 0]
        let task: Task<SpaceCredential, Error>
        if let existing = inFlight[space] {
            task = existing
        } else {
            let newTask = Task { [weak self] () -> SpaceCredential in
                guard let self else {
                    throw SpaceCredentialError.invalidResponse
                }
                let cred = try await self.exchangeCredential(for: space)
                try Task.checkCancellation()
                return cred
            }
            inFlight[space] = newTask
            task = newTask
        }

        defer {
            if inFlight[space] == task {
                inFlight.removeValue(forKey: space)
            }
        }

        do {
            let credential = try await task.value
            try Task.checkCancellation()
            guard generations[space, default: 0] == currentGeneration else {
                throw CancellationError()
            }
            cache[space] = credential
            return credential
        } catch {
            if generations[space, default: 0] == currentGeneration {
                cache.removeValue(forKey: space)
            }
            throw error
        }
    }

    /// Drop cached credential (e.g. on SpaceDeleted).
    public func invalidate(_ space: SpaceRef) {
        cache.removeValue(forKey: space)
        generations[space, default: 0] += 1
        inFlight.removeValue(forKey: space)?.cancel()
    }

    /// Performs an authenticated GET against an arbitrary repo host:
    /// Authorization: DPoP <credential> plus a per-request DPoP proof with
    /// htm/htu/iat/jti and ath = base64url(SHA256(credential)).
    public func get(url: URL, space: SpaceRef) async throws -> (Data, HTTPURLResponse) {
        guard Self.isSecureOrLoopback(url) else {
            throw SpaceCredentialError.insecureURL(url.absoluteString)
        }

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

    private static func isSecureOrLoopback(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "https" { return true }
        if scheme == "http", let host = url.host?.lowercased() {
            return host == "127.0.0.1" || host == "localhost" || host == "::1"
        }
        return false
    }

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

        guard Self.isSecureOrLoopback(exchangeURL) else {
            throw SpaceCredentialError.insecureURL(exchangeURL.absoluteString)
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
            let host = endpoints.spaceHost.host ?? endpoints.spaceHost.absoluteString
            let parsed = ATProtoErrorParser.parseGeneric(data: data, statusCode: httpResponse.statusCode)
            let errorName = parsed?.error
            let serverMessage = parsed?.message
            let rawBody = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = serverMessage ?? (rawBody.isEmpty ? "HTTP \(httpResponse.statusCode)" : rawBody)

            let isSpaceDeleted = errorName == "SpaceDeleted" ||
                rawBody.localizedCaseInsensitiveContains("SpaceDeleted")
            if isSpaceDeleted {
                throw SpaceCredentialError.spaceDeleted(host: host, message: serverMessage ?? (rawBody.isEmpty ? nil : rawBody))
            }

            let isTokenRejected = httpResponse.statusCode == 401 && (
                errorName == "InvalidDelegationToken" ||
                errorName == "InvalidToken" ||
                errorName == "ExpiredToken" ||
                errorName == "invalid_token" ||
                errorName == "InvalidClientAttestation" ||
                rawBody.localizedCaseInsensitiveContains("InvalidDelegationToken") ||
                rawBody.localizedCaseInsensitiveContains("invalid_token") ||
                rawBody.localizedCaseInsensitiveContains("InvalidToken")
            )
            if isTokenRejected {
                let evidence = await probeServerEvidence(spaceHost: endpoints.spaceHost)
                throw SpaceCredentialError.tokenRejected(
                    host: host,
                    error: errorName ?? "InvalidDelegationToken",
                    message: serverMessage,
                    evidence: evidence
                )
            }

            let isAuthRefused = httpResponse.statusCode == 403 ||
                errorName == "UserNotAuthorized" ||
                errorName == "AppNotAuthorized" ||
                errorName == "NotAuthorized" ||
                errorName == "AccessDenied" ||
                errorName == "Forbidden" ||
                errorName == "PermissionDenied" ||
                errorName == "AuthError"
            if isAuthRefused {
                throw SpaceCredentialError.authorizationRefused(host: host, error: errorName ?? "HTTP 403", message: serverMessage ?? (rawBody.isEmpty ? nil : rawBody))
            }

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

    private func probeServerEvidence(spaceHost: URL) async -> String? {
        guard Self.isSecureOrLoopback(spaceHost) else { return nil }
        let describeURL: URL
        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            describeURL = spaceHost.appending(path: "xrpc/com.atproto.server.describeServer")
        } else {
            describeURL = spaceHost.appendingPathComponent("xrpc/com.atproto.server.describeServer")
        }
        guard Self.isSecureOrLoopback(describeURL) else { return nil }

        var request = URLRequest(url: describeURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 2.0)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                group.addTask { [request, urlSession] in
                    try await urlSession.data(for: request)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    throw URLError(.timedOut)
                }
                guard let firstResult = try await group.next() else {
                    throw URLError(.cancelled)
                }
                group.cancelAll()
                return firstResult
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            return Self.extractIdentifyingEvidence(from: json)
        } catch {
            return nil
        }
    }

    private static func extractIdentifyingEvidence(from json: [String: Any]) -> String? {
        let standardKeys: Set<String> = [
            "did",
            "availableUserDomains",
            "inviteCodeRequired",
            "phoneVerificationRequired",
            "blobUploadLimit",
            "links",
            "contact",
        ]

        var citations: [String] = []
        let prioritizedKeys = [
            "swanProfile",
            "profile",
            "serverProfile",
            "version",
            "serverVersion",
            "protocolVersion",
            "implementation",
            "software",
            "build",
            "revision",
        ]

        for key in prioritizedKeys {
            if let val = json[key], !(val is NSNull) {
                let valStr = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !valStr.isEmpty {
                    citations.append("\(key)=\(valStr)")
                }
            }
        }

        if citations.isEmpty {
            let sortedKeys = json.keys.sorted()
            for key in sortedKeys {
                guard !standardKeys.contains(key) else { continue }
                let lower = key.lowercased()
                if lower.contains("profile") ||
                    lower.contains("version") ||
                    lower.contains("revision") ||
                    lower.contains("build") ||
                    lower.contains("software") ||
                    lower.contains("impl") {
                    if let val = json[key], !(val is NSNull) {
                        let valStr = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !valStr.isEmpty {
                            citations.append("\(key)=\(valStr)")
                        }
                    }
                }
            }
        }

        guard !citations.isEmpty else { return nil }
        return citations.joined(separator: ", ")
    }
}
