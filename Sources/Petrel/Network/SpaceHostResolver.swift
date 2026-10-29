//
//  SpaceHostResolver.swift
//  Petrel
//

import Foundation
import PetrelCrypto
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - SpaceAuthorityEndpoints

public struct SpaceAuthorityEndpoints: Sendable, Equatable {
    /// The authority account's `#atproto_pds` XRPC endpoint.
    public let spaceHost: URL
    /// October 22 credentials always identify the `#atproto` signing key.
    public let signingKeyFragment: String

    public init(spaceHost: URL, signingKeyFragment: String) {
        self.spaceHost = spaceHost
        self.signingKeyFragment = signingKeyFragment
    }
}

// MARK: - Extraction

extension SpaceAuthorityEndpoints {
    /// Dedicated legacy Space services/keys are ignored. Throws without a PDS.
    /// Filters candidates to authenticated-request-safe absolute hosts (https or loopback http).
    public static func extract(from doc: DIDDocument) throws -> SpaceAuthorityEndpoints {
        let pdsURL = doc.service.lazy
            .filter { service in
                service.id == "#atproto_pds" || service.id == doc.id + "#atproto_pds"
            }
            .compactMap { service -> URL? in
                guard let url = URL(string: service.serviceEndpoint),
                      isSecureOrLoopback(url)
                else {
                    return nil
                }
                return url
            }
            .first

        guard let hostURL = pdsURL else {
            throw SpaceHostResolutionError.missingSpaceHostEndpoint(doc.id)
        }

        return SpaceAuthorityEndpoints(
            spaceHost: hostURL,
            signingKeyFragment: "#atproto"
        )
    }

    static func isSecureOrLoopback(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "https", let host = url.host, !host.isEmpty { return true }
        if scheme == "http", let host = url.host?.lowercased() {
            return host == "127.0.0.1" || host == "localhost" || host == "::1"
        }
        return false
    }
}

// MARK: - SpaceHostResolutionError

public enum SpaceHostResolutionError: Error, LocalizedError, Equatable, Sendable {
    case invalidDID(String)
    case missingSpaceHostEndpoint(String)
    case networkError(String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidDID(did):
            return "The DID '\(did)' is not valid or supported for space host resolution."
        case let .missingSpaceHostEndpoint(did):
            return "No space host or PDS service endpoint found in DID document for '\(did)'."
        case let .networkError(message):
            return "Network error resolving space host: \(message)"
        case let .decodingError(message):
            return "Failed to decode DID document: \(message)"
        }
    }
}

// MARK: - SpaceHostResolver

public actor SpaceHostResolver {
    private let didResolver: any DIDResolving
    private let urlSession: URLSession
    private let sessionDelegate: HardenedURLSessionDelegate?

    public init(didResolver: any DIDResolving) {
        self.didResolver = didResolver
        let config = URLSessionConfiguration.ephemeral
        #if DEBUG
            if let testClasses = NetworkService.getNetworkTestProtocolClasses() {
                config.protocolClasses = testClasses
            }
        #endif
        let delegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: .default)
        sessionDelegate = delegate
        urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    init(didResolver: any DIDResolving, urlSession: URLSession) {
        self.didResolver = didResolver
        self.urlSession = urlSession
        sessionDelegate = urlSession.delegate as? HardenedURLSessionDelegate
    }

    /// Resolves the space authority DID document and extracts endpoints.
    public func resolve(authorityDID: String) async throws -> SpaceAuthorityEndpoints {
        let doc = try await fetchDIDDocument(for: authorityDID)
        return try SpaceAuthorityEndpoints.extract(from: doc)
    }

    private static let allowedPercentEncodedPathSegmentCharacters: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.insert(charactersIn: "%")
        allowed.remove(charactersIn: "/?#")
        return allowed
    }()

    /// Pure helper to construct the canonical DID document URL for `did:plc:` and `did:web:` per specifications.
    public static func didDocumentURL(for did: String) throws -> URL {
        if did.starts(with: "did:plc:") {
            let endpoint = "https://plc.directory/\(did)"
            guard let url = URL(string: endpoint) else {
                throw SpaceHostResolutionError.invalidDID(did)
            }
            return url
        } else if did.starts(with: "did:web:") {
            let parts = did.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count >= 3, parts[0] == "did", parts[1] == "web" else {
                throw SpaceHostResolutionError.invalidDID(did)
            }

            let rawAuthority = String(parts[2])
            let authorityParts = rawAuthority.components(separatedBy: "%3A")
            guard (1 ... 2).contains(authorityParts.count),
                  !authorityParts[0].contains("%"),
                  !authorityParts[0].contains("/")
            else {
                throw SpaceHostResolutionError.invalidDID(did)
            }
            let host = authorityParts[0]
            guard !host.isEmpty else {
                throw SpaceHostResolutionError.invalidDID(did)
            }
            let port: Int?
            if authorityParts.count == 2 {
                let portStr = authorityParts[1]
                guard !portStr.isEmpty, !portStr.contains("%"), !portStr.contains("/"),
                      let portNum = Int(portStr), (1 ... 65535).contains(portNum)
                else {
                    throw SpaceHostResolutionError.invalidDID(did)
                }
                port = portNum
            } else {
                port = nil
            }

            let pathComponents = parts.dropFirst(3)
            var components = URLComponents()
            components.scheme = "https"
            components.host = host
            components.port = port

            if pathComponents.isEmpty {
                components.percentEncodedPath = "/.well-known/did.json"
            } else {
                var rawSegments: [String] = []
                for component in pathComponents {
                    let rawSegment = String(component)
                    guard !rawSegment.isEmpty,
                          rawSegment != ".",
                          rawSegment != "..",
                          !rawSegment.contains("/"),
                          rawSegment.unicodeScalars.allSatisfy({ allowedPercentEncodedPathSegmentCharacters.contains($0) })
                    else {
                        throw SpaceHostResolutionError.invalidDID(did)
                    }
                    guard let decoded = rawSegment.removingPercentEncoding,
                          !decoded.isEmpty,
                          decoded != ".",
                          decoded != "..",
                          !decoded.contains("/"),
                          !decoded.contains("\\")
                    else {
                        throw SpaceHostResolutionError.invalidDID(did)
                    }
                    rawSegments.append(rawSegment)
                }
                components.percentEncodedPath = "/" + rawSegments.joined(separator: "/") + "/did.json"
            }

            guard let url = components.url else {
                throw SpaceHostResolutionError.invalidDID(did)
            }
            return url
        } else {
            throw SpaceHostResolutionError.invalidDID(did)
        }
    }

    /// Read an account's public PDS record without trusting a DID-document URL as a network route.
    /// The pinned-address delegate rejects DNS rebinding and redirects; only signed debug fixtures
    /// can route synthetic hosts to loopback.
    public static func fetchBoundedPublicJSON(
        from url: URL,
        limits: NetworkResponseLimits,
        fixtureSession: URLSession? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard url.scheme == "https", let host = url.host,
              url.user == nil, url.password == nil, url.fragment == nil
        else {
            throw SpaceHostResolutionError.networkError("Invalid public service endpoint")
        }
        #if DEBUG && canImport(Network) && canImport(Security)
            let fixture = DebugFixtureTransport.current
            let fixtureAllowed = fixture?.permits(url) == true
        #else
            let fixtureAllowed = false
        #endif
        guard fixtureAllowed || (
            host != "localhost" && host != "127.0.0.1" && host != "::1" &&
                (url.port == nil || url.port == 443)
        ) else {
            throw SpaceHostResolutionError.networkError("Public service endpoint is not allowed")
        }
        if !fixtureAllowed {
            guard try await NetworkService.validateURL(url) else {
                throw SpaceHostResolutionError.networkError("Public service endpoint failed validation")
            }
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        let data: Data
        let response: URLResponse
        // Release and Linux builds have no fixture transport, so `fixtureAllowed` is the literal
        // `false` there and an unguarded fixture branch is dead code the warning gate rejects.
        #if DEBUG && canImport(Network) && canImport(Security)
            if fixtureAllowed, let fixtureSession {
                (data, response) = try await fixtureSession.data(for: request)
            } else {
                (data, response) = try await fetchThroughHardenedSession(request, limits: limits)
            }
        #else
            (data, response) = try await fetchThroughHardenedSession(request, limits: limits)
        #endif
        guard let http = response as? HTTPURLResponse,
              data.count <= limits.maximumDecodedBytes,
              http.url == url
        else {
            throw SpaceHostResolutionError.networkError("Invalid public service response")
        }
        return (data, http)
    }

    private static func fetchThroughHardenedSession(
        _ request: URLRequest,
        limits: NetworkResponseLimits
    ) async throws -> (Data, URLResponse) {
        try await withPerCallHardenedSession(configuration: .ephemeral, limits: limits) { session, delegate in
            try await NetworkService.executeDataTask(request, using: session, delegate: delegate)
        }
    }

    /// Runs `body` with a hardened session made for this call alone, then
    /// invalidates the session. URLSession keeps a strong reference to its
    /// delegate until it is invalidated, so a per-call session that is only
    /// dropped leaks itself and its delegate on every call.
    static func withPerCallHardenedSession<T>(
        configuration: URLSessionConfiguration,
        limits: NetworkResponseLimits,
        _ body: (URLSession, HardenedURLSessionDelegate) async throws -> T
    ) async rethrows -> T {
        let delegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: limits)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        // Lets a request that `body` left running finish; nothing else holds
        // this session, so no new request can start on it.
        defer { session.finishTasksAndInvalidate() }
        return try await body(session, delegate)
    }

    /// Fetches and decodes the DID document using the hardened network path.
    /// A tighter limit is useful for authority documents at security boundaries.
    public static func fetchDIDDocument(
        for did: String,
        urlSession: URLSession? = nil,
        limits: NetworkResponseLimits = .default
    ) async throws -> DIDDocument {
        try await fetchDIDDocument(for: did, urlSession: urlSession, sessionDelegate: nil, limits: limits)
    }

    package static func fetchDIDDocument(
        for did: String,
        urlSession: URLSession? = nil,
        sessionDelegate: HardenedURLSessionDelegate? = nil,
        limits: NetworkResponseLimits = .default
    ) async throws -> DIDDocument {
        let url = try didDocumentURL(for: did)
        #if DEBUG && canImport(Network) && canImport(Security)
            let fixtureAllowed = DebugFixtureTransport.current?.permits(url) == true
        #else
            let fixtureAllowed = false
        #endif
        if !fixtureAllowed {
            guard try await NetworkService.validateURL(url) else {
                throw SpaceHostResolutionError.networkError("Security validation failed for DID document URL")
            }
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            if let sessionDelegate {
                let session = urlSession ?? URLSession.shared
                (data, response) = try await NetworkService.executeDataTask(request, using: session, delegate: sessionDelegate)
            } else if let urlSession {
                if let delegate = urlSession.delegate as? HardenedURLSessionDelegate {
                    (data, response) = try await NetworkService.executeDataTask(request, using: urlSession, delegate: delegate)
                } else {
                    (data, response) = try await urlSession.data(for: request)
                }
            } else {
                let config = URLSessionConfiguration.ephemeral
                #if DEBUG
                    if let testClasses = NetworkService.getNetworkTestProtocolClasses() {
                        config.protocolClasses = testClasses
                    }
                #endif
                (data, response) = try await withPerCallHardenedSession(configuration: config, limits: limits) { [request] session, delegate in
                    try await NetworkService.executeDataTask(request, using: session, delegate: delegate)
                }
            }
        } catch {
            throw SpaceHostResolutionError.networkError(error.localizedDescription)
        }

        guard data.count <= limits.maximumDecodedBytes else {
            throw SpaceHostResolutionError.networkError("DID document exceeds response limit")
        }
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SpaceHostResolutionError.networkError("HTTP status \(statusCode)")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(DIDDocument.self, from: data)
        } catch {
            throw SpaceHostResolutionError.decodingError(error.localizedDescription)
        }
    }

    public func fetchDIDDocument(for did: String) async throws -> DIDDocument {
        try await Self.fetchDIDDocument(for: did, urlSession: urlSession, sessionDelegate: sessionDelegate)
    }
}

public extension SpaceHostResolver {
    /// Resolve the author's sole P-256 KEM method from the exact account DID.
    /// PLC can publish the legacy raw-point representation as well as Multikey.
    static func authorKEMKey(from document: DIDDocument, expectedDID: String) throws -> String {
        let candidates = document.verificationMethod.filter {
            $0.id == "#atproto_kem" || $0.id == expectedDID + "#atproto_kem"
        }
        guard document.id == expectedDID, candidates.count == 1,
              let method = candidates.first, method.controller == expectedDID
        else {
            throw SpaceVerificationError.missingKEMKey
        }
        switch method.type {
        case "Multikey":
            return try P256DIDKey("did:key:" + method.publicKeyMultibase).value
        case "EcdsaSecp256r1VerificationKey2019":
            let key = try PLCDIDKeyCodec.decodeLegacyMultibase(method.publicKeyMultibase, curve: .p256)
            guard case .p256 = key else { throw SpaceVerificationError.missingKEMKey }
            return key.didKey
        default:
            throw SpaceVerificationError.missingKEMKey
        }
    }
}
