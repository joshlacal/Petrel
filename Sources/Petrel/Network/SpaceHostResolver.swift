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

// MARK: - OwnedSessionInvalidator

/// Invalidates a session its owner created, once the owner is released.
/// URLSession keeps a strong reference to its delegate until it is
/// invalidated, so an owner that only drops its session leaks the session
/// and the delegate.
final class OwnedSessionInvalidator {
    private let session: URLSession

    init(_ session: URLSession) {
        self.session = session
    }

    deinit {
        // Lets a request still running finish; with the owner gone, no new
        // request can start on this session.
        session.finishTasksAndInvalidate()
    }
}

// MARK: - SpaceHostResolver

public actor SpaceHostResolver {
    private let didResolver: any DIDResolving
    private let urlSession: URLSession
    let sessionDelegate: HardenedURLSessionDelegate?
    /// Set only when this resolver created `urlSession`; invalidates it when
    /// the resolver is released. A caller's session stays the caller's.
    private let ownedSession: OwnedSessionInvalidator?

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
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        urlSession = session
        ownedSession = OwnedSessionInvalidator(session)
    }

    init(didResolver: any DIDResolving, urlSession: URLSession) {
        self.didResolver = didResolver
        self.urlSession = urlSession
        sessionDelegate = urlSession.delegate as? HardenedURLSessionDelegate
        ownedSession = nil
    }

    /// Resolves the space authority DID document and extracts endpoints.
    public func resolve(authorityDID: String) async throws -> SpaceAuthorityEndpoints {
        let doc = try await fetchDIDDocument(for: authorityDID)
        return try SpaceAuthorityEndpoints.extract(from: doc)
    }

    /// The DID document URL for a `did:plc` DID (in the public PLC directory) or a
    /// hostname-level `did:web` DID.
    ///
    /// `did:web` follows ``DIDWebIdentifier``: path-based DIDs and ports on hosts other than
    /// `localhost` are rejected, and `localhost` and `.test` hosts are accepted in debug builds
    /// only.
    public static func didDocumentURL(for did: String) throws -> URL {
        guard IdentityResolver.isStrictlyValidDID(did) else {
            throw SpaceHostResolutionError.invalidDID(did)
        }
        if did.starts(with: "did:plc:") {
            guard let url = URL(string: "https://plc.directory/\(did)") else {
                throw SpaceHostResolutionError.invalidDID(did)
            }
            return url
        } else if did.starts(with: "did:web:") {
            #if DEBUG
                let allowsDevelopmentHosts = true
            #else
                let allowsDevelopmentHosts = false
            #endif
            guard let web = try? DIDWebIdentifier(did, allowingDevelopmentHosts: allowsDevelopmentHosts) else {
                throw SpaceHostResolutionError.invalidDID(did)
            }
            return web.documentURL
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

        let document: DIDDocument
        do {
            document = try JSONDecoder().decode(DIDDocument.self, from: data)
        } catch {
            throw SpaceHostResolutionError.decodingError(error.localizedDescription)
        }
        // A document that names another DID says nothing about the one that was asked for.
        guard document.id == did else {
            throw SpaceHostResolutionError.decodingError("The DID document declares a different id than the requested DID")
        }
        return document
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

    /// Resolve the authority's sole `#atproto` signing verification method from the exact account DID.
    /// Supports both Multikey (`P-256` and `secp256k1`) and legacy W3C verification method encodings.
    static func authoritySigningKey(
        from document: DIDDocument,
        expectedDID: String
    ) throws -> ATProtoJWTVerificationKey {
        let candidates = document.verificationMethod.filter {
            $0.id == "#atproto" || $0.id == expectedDID + "#atproto"
        }
        guard document.id == expectedDID, candidates.count == 1,
              let method = candidates.first, method.controller == expectedDID
        else {
            throw SpaceVerificationError.missingSigningKey
        }
        // `candidates.count == 1` above makes "first valid key" and "the only key" the same
        // thing; the decoding rules are the ones every DID document shares.
        guard let plcKey = document.verificationKeys(withID: "#atproto").first else {
            throw SpaceVerificationError.missingSigningKey
        }
        return ATProtoJWTVerificationKey(plcKey)
    }
}
