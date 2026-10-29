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
    /// When the manager stops reusing this credential, fixed at exchange time
    /// from the credential's own lifetime (see `SpaceCredentialManager.refreshDeadline`).
    let refreshAt: Date
}

// MARK: - SpaceCredentialError

public enum SpaceCredentialError: Error, LocalizedError, Equatable, Sendable {
    case missingDelegationToken
    case spaceDeleted(host: String, message: String?)
    /// The authority refused to issue a credential. `error` is the XRPC error
    /// name, such as `UserNotAuthorized`, `AppNotAuthorized` or `NotAuthorized`
    /// (or `HTTP 403`), or `SpaceNotFound` at HTTP 400 (the reference host) or
    /// 404 (Swan): the authority does not host the space or, without a
    /// delegation token, the space is not public. None of these means the
    /// space was deleted.
    case authorizationRefused(host: String, error: String, message: String?)
    /// The authority rejected a presented token as invalid: the delegation
    /// token (`InvalidDelegationToken` and similar) or, when `error` is
    /// `InvalidClientAttestation`, the client attestation. Not an access denial.
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
        case let .spaceDeleted(host, message):
            if let message, !message.isEmpty {
                return "SpaceDeleted: \(message)"
            }
            return "SpaceDeleted: The space was deleted by authority at \(host)"
        case let .authorizationRefused(host, error, message):
            if error == "SpaceNotFound" {
                let detail = message.map { $0.isEmpty ? "" : " (\($0))" } ?? ""
                return "Space not found at \(host)\(detail). The authority does not host this space, or the space is not public and no delegation token was sent; this does not mean it was deleted."
            }
            if let message, !message.isEmpty {
                return "You no longer have access to this space (\(host) refused authorization: \(message))"
            }
            return "You no longer have access to this space (\(host) refused authorization: \(error))"
        case let .tokenRejected(host, error, _, evidence):
            let subject = error == "InvalidClientAttestation" ? "client attestation" : "delegation token"
            if let evidence, !evidence.isEmpty {
                return "\(host) rejected the \(subject) as invalid (not an access denial; membership is unaffected). \(host) reports: \(evidence)."
            }
            return "\(host) rejected the \(subject) as invalid (not an access denial; membership is unaffected)."
        case let .exchangeFailed(statusCode, message):
            return "Space credential exchange failed with status \(statusCode): \(message)"
        case let .invalidToken(reason):
            return "Invalid space credential token: \(reason)"
        case .invalidResponse:
            return "Invalid HTTP response from server"
        case .invalidKey:
            return "Failed to initialize cryptographic key"
        case let .invalidSpaceRef(ref):
            return "Invalid space reference: \(ref)"
        case let .insecureURL(url):
            return "Refusing authenticated request to insecure non-HTTPS URL: \(url)"
        }
    }
}

// MARK: - SpaceHTTPSignature

/// HTTP Message Signatures (RFC 9421) binding atproto Spaces requests to a
/// credential key, replacing the earlier Spaces DPoP binding. Ordinary OAuth
/// DPoP is unrelated and unchanged.
///
/// Credential presentation covers the exact Authorization and audience values,
/// with the mandatory October 22 label/tag. Credential exchange uses JSON only.
enum SpaceHTTPSignature {
    static let label = "atproto-space-credential"

    /// The credential key's public half as a P-256 `did:key`.
    static func keyID(for key: P256.Signing.PrivateKey) -> String {
        P256DIDKey(publicKey: key.publicKey).value
    }

    static func signatureParams() -> String {
        #"("authorization" "atproto-space-audience");tag="atproto-space-credential""#
    }

    static func signatureBase(
        authorization: String,
        audience: String?,
        signatureParams: String
    ) -> Data {
        var lines = [#""authorization": "# + authorization]
        if let audience {
            lines.append(#""atproto-space-audience": "# + audience)
        }
        lines.append(#""@signature-params": "# + signatureParams)
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// Request headers for a space credential; body-based exchange is unsigned.
    static func headers(
        key: P256.Signing.PrivateKey,
        authorization: String,
        audience: String?
    ) throws -> [String: String] {
        guard let audience, DID.isValidDID(audience),
              authorization.lowercased().hasPrefix("atproto-space-credential "),
              !authorization.contains("\r"), !authorization.contains("\n")
        else {
            throw SpaceCredentialError.invalidToken("Invalid credential signature context")
        }
        let params = signatureParams()
        let base = signatureBase(authorization: authorization, audience: audience, signatureParams: params)
        let signature = try P256WireSignature.sign(base, using: key)

        var headers = [
            "Authorization": authorization,
            "Signature-Input": "\(label)=\(params)",
            "Signature": "\(label)=:\(signature.base64EncodedString()):",
        ]
        headers["Atproto-Space-Audience"] = audience
        return headers
    }

    /// The audience DID a credential-bearing request is bound to: the repo
    /// owner's DID (`repo` query parameter) for repo operations, otherwise the
    /// space authority's bare DID. Never a hostname or service identifier.
    static func audience(for url: URL, space: SpaceRef) -> String {
        if let repo = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "repo" })?.value,
            !repo.isEmpty
        {
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
    let sessionDelegate: HardenedURLSessionDelegate?
    /// Set only when this manager created `urlSession`; invalidates it when
    /// the manager is released. A caller's session stays the caller's.
    private let ownedSession: OwnedSessionInvalidator?
    private let delegationTokenProvider: DelegationTokenProvider
    public typealias AuthorKEMKeyProvider = @Sendable (_ repo: String, _ forceRefresh: Bool) async throws -> String
    public typealias ClientAttestationProvider = @Sendable (SpaceRef) async throws -> String?
    private let authorKEMKeyProvider: AuthorKEMKeyProvider
    private let clientAttestationProvider: ClientAttestationProvider?

    private var cache: [SpaceRef: SpaceCredential] = [:]
    private var inFlight: [SpaceRef: Task<SpaceCredential, Error>] = [:]
    private var generations: [SpaceRef: UInt64] = [:]

    /// Designated initializer taking a custom `authorityHostProvider`.
    public init(
        client: ATProtoClient,
        authorityHostProvider: @escaping SpaceAuthorityHostProvider,
        urlSession: URLSession? = nil,
        delegationTokenProvider: DelegationTokenProvider? = nil,
        authorKEMKeyProvider: AuthorKEMKeyProvider? = nil,
        clientAttestationProvider: ClientAttestationProvider? = nil
    ) {
        self.client = client
        self.clientAttestationProvider = clientAttestationProvider
        self.authorKEMKeyProvider = authorKEMKeyProvider ?? { repo, _ in
            let document = try await SpaceHostResolver.fetchDIDDocument(for: repo)
            return try SpaceHostResolver.authorKEMKey(from: document, expectedDID: repo)
        }
        self.authorityHostProvider = authorityHostProvider
        if let urlSession {
            self.urlSession = urlSession
            sessionDelegate = urlSession.delegate as? HardenedURLSessionDelegate
            ownedSession = nil
        } else {
            let config = URLSessionConfiguration.ephemeral
            #if DEBUG
                if let testClasses = NetworkService.getNetworkTestProtocolClasses() {
                    config.protocolClasses = testClasses
                }
            #endif
            let delegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: .default)
            sessionDelegate = delegate
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            self.urlSession = session
            ownedSession = OwnedSessionInvalidator(session)
        }
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
        urlSession: URLSession? = nil,
        delegationTokenProvider: DelegationTokenProvider? = nil,
        authorKEMKeyProvider: AuthorKEMKeyProvider? = nil,
        clientAttestationProvider: ClientAttestationProvider? = nil
    ) {
        self.init(
            client: client,
            authorityHostProvider: { did in
                try await resolver.resolve(authorityDID: did).spaceHost
            },
            urlSession: urlSession,
            delegationTokenProvider: delegationTokenProvider,
            authorKEMKeyProvider: authorKEMKeyProvider,
            clientAttestationProvider: clientAttestationProvider
        )
    }

    /// Cached credential for the space, exchanging a fresh one (with a fresh
    /// key) when absent or past its refresh deadline: the credential's own
    /// `exp` less min(60 s, half its issued lifetime).
    public func credential(for space: SpaceRef) async throws -> SpaceCredential {
        let now = Date()
        if let cached = cache[space], cached.refreshAt > now {
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

    /// The time after which a credential is no longer reused. The margin
    /// before `exp` is min(60 s, half the issued lifetime `exp - iat`), so a
    /// 60 s credential is reused for 30 s rather than never. Reuse also ends
    /// that margin before one lifetime after local receipt, so a device clock
    /// behind the issuer's cannot extend it. Without a usable `iat`, the
    /// margin is a flat 60 s.
    static func refreshDeadline(expiresAt: Date, issuedAt: TimeInterval?, receivedAt: Date) -> Date {
        let maximumMargin: TimeInterval = 60
        guard let issuedAt, issuedAt.isFinite, issuedAt < expiresAt.timeIntervalSince1970 else {
            return expiresAt.addingTimeInterval(-maximumMargin)
        }
        let lifetime = expiresAt.timeIntervalSince1970 - issuedAt
        let margin = min(maximumMargin, lifetime / 2)
        return min(expiresAt, receivedAt.addingTimeInterval(lifetime)).addingTimeInterval(-margin)
    }

    /// Drop cached credential (e.g. on SpaceDeleted).
    public func invalidate(_ space: SpaceRef) {
        cache.removeValue(forKey: space)
        generations[space, default: 0] += 1
        inFlight.removeValue(forKey: space)?.cancel()
    }

    /// Performs an authenticated GET with the space credential:
    /// `Authorization: Atproto-Space-Credential <credential>`, `Atproto-Space-Audience`,
    /// and an HTTP message signature over both, made with the credential key.
    ///
    /// - Parameters:
    ///   - url: The secure or loopback endpoint to read with the space credential.
    ///   - space: The permissioned space whose credential authorizes the request.
    ///   - audience: The DID the request is addressed to. Defaults to the URL's
    ///     `repo` query parameter (repo operations) or, without one, the space
    ///     authority's DID (space-host operations).
    ///   - maximumArchiveBytes: For `getRepo` only, the largest response to
    ///     accept, replacing the session's response limit (10 MiB by default)
    ///     for that request and bounding STAR verification. Values above
    ///     `SpaceSTAR.defaultMaximumArchiveBytes` are clamped to it. Ignored for
    ///     other methods. `nil` keeps the default limits.
    ///
    /// A `401 CredentialRevoked` response drops the cached credential so it is
    /// never presented again; the response is returned to the caller unchanged
    /// and nothing is retried here.
    public func get(
        url: URL,
        space: SpaceRef,
        audience: String? = nil,
        maximumArchiveBytes: Int? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard Self.isSecureOrLoopback(url) else {
            throw SpaceCredentialError.insecureURL(url.absoluteString)
        }
        guard try await NetworkService.validateURL(url) else {
            throw SpaceCredentialError.insecureURL(url.absoluteString)
        }
        let audience = audience ?? SpaceHTTPSignature.audience(for: url, space: space)
        guard DID.isValidDID(audience) else {
            throw SpaceCredentialError.invalidSpaceRef("invalid space audience DID: \(audience)")
        }

        let method = url.lastPathComponent.replacingOccurrences(of: "com.atproto.space.", with: "")
        let needsMAC = ["getLatestCommit", "getRepo", "listRepoOps", "getRecord"].contains(method)
        let responseLimits = Self.archiveResponseLimits(
            maximumArchiveBytes,
            method: method,
            base: sessionDelegate?.limits ?? .default
        )
        for attempt in 0 ..< 2 {
            do {
                let context: SpaceMAC.Encapsulation?
                if needsMAC {
                    let authorKey = try await authorKEMKeyProvider(audience, attempt > 0)
                    context = try SpaceMAC.encapsulate(authorKey: authorKey)
                } else { context = nil }
                return try await signedGet(url: url, space: space, audience: audience, method: method, context: context, responseLimits: responseLimits)
            } catch SpaceMAC.Failure.mismatch where attempt == 0 {
                // A rotated KEM key can produce a valid response under a different
                // secret. Refresh once, and always use another ephemeral key.
                continue
            }
        }
        throw SpaceMAC.Failure.mismatch
    }

    /// Per-request limits for a `getRepo` STAR archive of at most
    /// `maximumArchiveBytes`, clamped to `SpaceSTAR.defaultMaximumArchiveBytes`.
    /// Nil (keep the session's limits) for other methods or without a value.
    static func archiveResponseLimits(
        _ maximumArchiveBytes: Int?,
        method: String,
        base: NetworkResponseLimits
    ) -> NetworkResponseLimits? {
        guard method == "getRepo", let maximumArchiveBytes else { return nil }
        let bytes = max(0, min(maximumArchiveBytes, SpaceSTAR.defaultMaximumArchiveBytes))
        return NetworkResponseLimits(
            maximumWireBytes: bytes,
            maximumDecodedBytes: bytes,
            maximumExpansionRatio: base.maximumExpansionRatio,
            maximumDiagnosticBytes: base.maximumDiagnosticBytes
        )
    }

    private func signedGet(
        url: URL,
        space: SpaceRef,
        audience: String,
        method: String,
        context: SpaceMAC.Encapsulation?,
        responseLimits: NetworkResponseLimits?
    ) async throws -> (Data, HTTPURLResponse) {
        let cred = try await credential(for: space)
        let generation = generations[space, default: 0]
        guard let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: cred.keyRawRepresentation) else {
            throw SpaceCredentialError.invalidKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let headers = try SpaceHTTPSignature.headers(
            key: privateKey,
            authorization: "Atproto-Space-Credential \(cred.token)",
            audience: audience
        )
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        if let context {
            let type = method == "getRecord" ? "atproto-space-record" : "atproto-space-repo"
            request.setValue("type=\"\(type)\", ver=1, key_share=\"\(context.keyShare)\"", forHTTPHeaderField: "Atproto-Space-Want-Mac")
        }
        if method == "getRepo" { request.setValue("application/octet-stream", forHTTPHeaderField: "Accept") }
        let data: Data
        let response: URLResponse
        if let sessionDelegate {
            (data, response) = try await NetworkService.executeDataTask(request, using: urlSession, delegate: sessionDelegate, limits: responseLimits)
        } else if let delegate = urlSession.delegate as? HardenedURLSessionDelegate {
            (data, response) = try await NetworkService.executeDataTask(request, using: urlSession, delegate: delegate, limits: responseLimits)
        } else {
            (data, response) = try await urlSession.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpaceCredentialError.invalidResponse
        }
        if httpResponse.statusCode == 401,
           ATProtoErrorParser.parseGeneric(data: data, statusCode: 401)?.error == "CredentialRevoked",
           cache[space]?.token == cred.token
        {
            // A revoked credential is never presented again. Any replacement
            // comes from a fresh delegation exchange, which the user's session
            // and the authority must both still authorize.
            cache.removeValue(forKey: space)
        }
        try Task.checkCancellation()
        guard generations[space, default: 0] == generation else { throw CancellationError() }
        if (200 ... 299).contains(httpResponse.statusCode), let context {
            let header = httpResponse.value(forHTTPHeaderField: "Atproto-Space-Mac")
            if method == "getRepo" {
                let mac = try SpaceMACHeader.parse(header, type: "atproto-space-repo")
                _ = try SpaceSTAR.verify(
                    archive: data, space: space, repo: audience, sharedSecret: context.sharedSecret, mac: mac,
                    maximumArchiveBytes: responseLimits?.maximumDecodedBytes ?? SpaceSTAR.defaultMaximumArchiveBytes
                )
            } else {
                try SpaceResponseVerifier.verifyJSON(data, method: method, url: url, space: space, repo: audience, secret: context.sharedSecret, macHeader: header)
            }
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
        guard try await NetworkService.validateURL(exchangeURL) else {
            throw SpaceCredentialError.insecureURL(exchangeURL.absoluteString)
        }

        var request = URLRequest(url: exchangeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let input = try ComAtprotoSpaceGetSpaceCredential.Input(
            space: space,
            credentialKid: SpaceHTTPSignature.keyID(for: ephemeralKey),
            delegationToken: delegationToken,
            clientAttestation: await clientAttestationProvider?(space)
        )
        request.httpBody = try JSONEncoder().encode(input)

        let data: Data
        let response: URLResponse
        if let sessionDelegate {
            (data, response) = try await NetworkService.executeDataTask(request, using: urlSession, delegate: sessionDelegate)
        } else if let delegate = urlSession.delegate as? HardenedURLSessionDelegate {
            (data, response) = try await NetworkService.executeDataTask(request, using: urlSession, delegate: delegate)
        } else {
            (data, response) = try await urlSession.data(for: request)
        }
        let receivedAt = Date()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpaceCredentialError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let host = spaceHost.host ?? spaceHost.absoluteString
            let parsed = ATProtoErrorParser.parseGeneric(data: data, statusCode: httpResponse.statusCode)
            let errorName = parsed?.error
            let serverMessage = parsed?.message
            let rawBody = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = serverMessage ?? (rawBody.isEmpty ? "HTTP \(httpResponse.statusCode)" : rawBody)

            let isSpaceDeleted = httpResponse.statusCode == 400 && errorName == "SpaceDeleted"
            if isSpaceDeleted {
                throw SpaceCredentialError.spaceDeleted(host: host, message: serverMessage ?? (rawBody.isEmpty ? nil : rawBody))
            }

            // Not a deletion: the authority does not host the space or, without
            // a delegation token, the space is not public. The reference host
            // answers 400 and Swan answers 404; both keep the error name.
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 404, errorName == "SpaceNotFound" {
                throw SpaceCredentialError.authorizationRefused(host: host, error: "SpaceNotFound", message: serverMessage ?? (rawBody.isEmpty ? nil : rawBody))
            }

            // An invalid client attestation says nothing about the delegation
            // token, so it skips the token-failure evidence probe.
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401, errorName == "InvalidClientAttestation" {
                throw SpaceCredentialError.tokenRejected(host: host, error: "InvalidClientAttestation", message: serverMessage)
            }

            let isTokenRejected = (httpResponse.statusCode == 400 && errorName == "InvalidDelegationToken") ||
                (
                    (httpResponse.statusCode == 400 || httpResponse.statusCode == 401) &&
                        ["InvalidToken", "ExpiredToken", "invalid_token"].contains(errorName ?? "")
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

        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw SpaceCredentialError.invalidToken("Malformed JWT") }
        let syntheticHeaderJWT = "e30.\(parts[0]).x"
        let header = try SpaceCredentialJWT.payload(ofJWT: syntheticHeaderJWT)
        guard header["kid"] as? String == "#atproto" else { throw SpaceCredentialError.invalidToken("Credential kid must be #atproto") }
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

        guard expSeconds.isFinite, expSeconds > Date().timeIntervalSince1970 else {
            throw SpaceCredentialError.invalidToken("Credential has expired")
        }
        let expiresAt = Date(timeIntervalSince1970: expSeconds)
        let issuedAt: TimeInterval?
        if let num = payload["iat"] as? NSNumber {
            issuedAt = num.doubleValue
        } else if let intVal = payload["iat"] as? Int {
            issuedAt = TimeInterval(intVal)
        } else {
            issuedAt = payload["iat"] as? Double
        }
        return SpaceCredential(
            token: token,
            expiresAt: expiresAt,
            keyRawRepresentation: ephemeralKey.rawRepresentation,
            refreshAt: Self.refreshDeadline(expiresAt: expiresAt, issuedAt: issuedAt, receivedAt: receivedAt)
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
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
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
        let standardKeys: Set = [
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
                    lower.contains("impl")
                {
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
