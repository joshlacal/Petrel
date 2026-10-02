//
//  SpaceCredentialManager.swift
//  Petrel
//

import Crypto
import Foundation
import PetrelCrypto
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

// MARK: - SpaceHTTPSignature

/// HTTP Message Signatures (RFC 9421) binding atproto Spaces requests to a
/// credential key, replacing the earlier Spaces DPoP binding. Ordinary OAuth
/// DPoP is unrelated and unchanged.
///
/// Two forms, matching the reference `createSpaceSigHeaders`:
/// - Delegation exchange (`getSpaceCredential`): `Authorization: Bearer <token>`,
///   covering `("authorization")` with `keyid` = the credential key's P-256 `did:key`.
/// - Credential use: `Authorization: Atproto-Space <credential>` plus
///   `Atproto-Space-Audience: <DID>`, covering
///   `("authorization" "atproto-space-audience")`.
///
/// The signature base is the covered component lines followed by the
/// `"@signature-params"` line, joined by LF with no trailing LF, signed with
/// `ecdsa-p256-sha256` and carried as the 64-byte raw `r || s` value in
/// standard base64.
enum SpaceHTTPSignature {
    static let label = "atproto-space"

    /// The credential key's public half as a P-256 `did:key`.
    static func keyID(for key: P256.Signing.PrivateKey) -> String {
        P256DIDKey(publicKey: key.publicKey).value
    }

    /// The inner list (with parameters) that follows `atproto-space=` in
    /// `Signature-Input` and ends the signature base. `coversAudience == false`
    /// is the delegation-exchange form, which must name its key.
    static func signatureParams(keyID: String, coversAudience: Bool) -> String {
        coversAudience
            ? #"("authorization" "atproto-space-audience")"#
            : #"("authorization");keyid="\#(keyID)""#
    }

    static func signatureBase(
        authorization: String,
        audience: String?,
        signatureParams: String
    ) -> Data {
        var lines = [#""authorization": "# + authorization.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let audience {
            lines.append(#""atproto-space-audience": "# + audience.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        lines.append(#""@signature-params": "# + signatureParams)
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// Request headers for a space request signed by `key`. Pass `audience`
    /// when using a space credential; omit it for the delegation exchange.
    static func headers(
        key: P256.Signing.PrivateKey,
        authorization: String,
        audience: String?
    ) throws -> [String: String] {
        let params = signatureParams(keyID: keyID(for: key), coversAudience: audience != nil)
        let base = signatureBase(authorization: authorization, audience: audience, signatureParams: params)
        let signature = try P256WireSignature.sign(base, using: key)

        var headers = [
            "Authorization": authorization,
            "Signature-Input": "\(label)=\(params)",
            "Signature": "\(label)=:\(signature.base64EncodedString()):",
        ]
        if let audience {
            headers["Atproto-Space-Audience"] = audience
        }
        return headers
    }

    /// The audience DID a credential-bearing request is bound to: the repo
    /// owner's DID (`repo` query parameter) for repo operations, otherwise the
    /// space authority's bare DID. Never a hostname or service identifier.
    static func audience(for url: URL, space: SpaceRef) -> String {
        if let repo = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "repo" })?.value,
            !repo.isEmpty {
            return repo
        }
        return space.spaceDID
    }
}

// MARK: - SpaceCredentialJWT

enum SpaceCredentialJWT {
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

    /// Provider that resolves a space authority DID to its space host XRPC endpoint URL.
    ///
    /// Note: SpaceAuthorityHostProvider returns only URL (spaceHost). SpaceAuthorityEndpoints.signingKeyFragment
    /// has no consumer today; a future credential-signature verifier may want it.
    public typealias SpaceAuthorityHostProvider = @Sendable (String) async throws -> URL

    private let client: ATProtoClient
    private let authorityHostProvider: SpaceAuthorityHostProvider
    private let urlSession: URLSession
    private let delegationTokenProvider: DelegationTokenProvider

    private var cache: [SpaceRef: SpaceCredential] = [:]
    private var inFlight: [SpaceRef: Task<SpaceCredential, Error>] = [:]
    private var generations: [SpaceRef: UInt64] = [:]

    /// Designated initializer taking a custom `authorityHostProvider`.
    public init(
        client: ATProtoClient,
        authorityHostProvider: @escaping SpaceAuthorityHostProvider,
        urlSession: URLSession = .shared,
        delegationTokenProvider: DelegationTokenProvider? = nil
    ) {
        self.client = client
        self.authorityHostProvider = authorityHostProvider
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

    /// Compatibility initializer delegating authority host resolution to `SpaceHostResolver`.
    public init(
        client: ATProtoClient,
        resolver: SpaceHostResolver,
        urlSession: URLSession = .shared,
        delegationTokenProvider: DelegationTokenProvider? = nil
    ) {
        self.init(
            client: client,
            authorityHostProvider: { did in
                try await resolver.resolve(authorityDID: did).spaceHost
            },
            urlSession: urlSession,
            delegationTokenProvider: delegationTokenProvider
        )
    }

    /// Cached credential for the space, exchanging a fresh one (with a fresh
    /// key) when absent or within 60s of the credential's own `exp`.
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

    /// Performs an authenticated GET with the space credential:
    /// `Authorization: Atproto-Space <credential>`, `Atproto-Space-Audience`,
    /// and an HTTP message signature over both, made with the credential key.
    ///
    /// - Parameter audience: The DID the request is addressed to. Defaults to
    ///   the URL's `repo` query parameter (repo operations) or, without one,
    ///   the space authority's DID (space-host operations).
    ///
    /// A `401 CredentialRevoked` response drops the cached credential so it is
    /// never presented again; the response is returned to the caller unchanged
    /// and nothing is retried here.
    public func get(url: URL, space: SpaceRef, audience: String? = nil) async throws -> (Data, HTTPURLResponse) {
        guard Self.isSecureOrLoopback(url) else {
            throw SpaceCredentialError.insecureURL(url.absoluteString)
        }
        let audience = audience ?? SpaceHTTPSignature.audience(for: url, space: space)
        guard DID.isValidDID(audience) else {
            throw SpaceCredentialError.invalidSpaceRef("invalid space audience DID: \(audience)")
        }

        let cred = try await credential(for: space)
        guard let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: cred.keyRawRepresentation) else {
            throw SpaceCredentialError.invalidKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let headers = try SpaceHTTPSignature.headers(
            key: privateKey,
            authorization: "Atproto-Space \(cred.token)",
            audience: audience
        )
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpaceCredentialError.invalidResponse
        }
        if httpResponse.statusCode == 401,
           ATProtoErrorParser.parseGeneric(data: data, statusCode: 401)?.error == "CredentialRevoked",
           cache[space]?.token == cred.token {
            // A revoked credential is never presented again. Any replacement
            // comes from a fresh delegation exchange, which the user's session
            // and the authority must both still authorize.
            cache.removeValue(forKey: space)
        }
        return (data, httpResponse)
    }

    // MARK: - Private Helpers

    static func isSecureOrLoopback(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "https", let host = url.host, !host.isEmpty { return true }
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

        let spaceHost = try await authorityHostProvider(authorityDID)
        let delegationToken = try await delegationTokenProvider(space)

        let ephemeralKey = P256.Signing.PrivateKey()

        let exchangeURL: URL
        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            exchangeURL = spaceHost.appending(path: "xrpc/com.atproto.space.getSpaceCredential")
        } else {
            exchangeURL = spaceHost.appendingPathComponent("xrpc/com.atproto.space.getSpaceCredential")
        }

        guard Self.isSecureOrLoopback(exchangeURL) else {
            throw SpaceCredentialError.insecureURL(exchangeURL.absoluteString)
        }

        var request = URLRequest(url: exchangeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The signature's keyid (the fresh key's did:key) becomes the issued
        // credential's cnf.kid.
        let headers = try SpaceHTTPSignature.headers(
            key: ephemeralKey,
            authorization: "Bearer \(delegationToken)",
            audience: nil
        )
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let input = ComAtprotoSpaceGetSpaceCredential.Input(space: space)
        request.httpBody = try JSONEncoder().encode(input)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpaceCredentialError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let host = spaceHost.host ?? spaceHost.absoluteString
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
                let evidence = await probeServerEvidence(spaceHost: spaceHost)
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

        let payload = try SpaceCredentialJWT.payload(ofJWT: token)
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
