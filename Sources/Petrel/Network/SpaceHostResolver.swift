//
//  SpaceHostResolver.swift
//  Petrel
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - SpaceAuthorityEndpoints

public struct SpaceAuthorityEndpoints: Sendable, Equatable {
    /// Space host XRPC endpoint (service `#atproto_space_host`, falling back
    /// to `#atproto_pds` per spec §Space authority).
    public let spaceHost: URL
    /// Verification method id used for credential signatures
    /// (`#atproto_space` falling back to `#atproto`).
    public let signingKeyFragment: String

    public init(spaceHost: URL, signingKeyFragment: String) {
        self.spaceHost = spaceHost
        self.signingKeyFragment = signingKeyFragment
    }
}

// MARK: - Extraction

extension SpaceAuthorityEndpoints {
    /// Pure extraction per spec: #atproto_space_host → #atproto_pds fallback;
    /// #atproto_space → #atproto fallback. Throws if no host at all.
    /// Filters candidates to authenticated-request-safe absolute hosts (https or loopback http).
    public static func extract(from doc: DIDDocument) throws -> SpaceAuthorityEndpoints {
        let spaceHostURL = doc.service.lazy
            .filter { service in
                service.id == "#atproto_space_host" || service.id.hasSuffix("#atproto_space_host")
            }
            .compactMap { service -> URL? in
                guard let url = URL(string: service.serviceEndpoint),
                      isSecureOrLoopback(url) else {
                    return nil
                }
                return url
            }
            .first

        let pdsURL = doc.service.lazy
            .filter { service in
                service.id == "#atproto_pds" || service.id.hasSuffix("#atproto_pds")
            }
            .compactMap { service -> URL? in
                guard let url = URL(string: service.serviceEndpoint),
                      isSecureOrLoopback(url) else {
                    return nil
                }
                return url
            }
            .first

        guard let hostURL = spaceHostURL ?? pdsURL else {
            throw SpaceHostResolutionError.missingSpaceHostEndpoint(doc.id)
        }

        let hasSpaceKey = doc.verificationMethod.contains { vm in
            vm.id == "#atproto_space" || vm.id.hasSuffix("#atproto_space")
        }

        let signingKeyFragment = hasSpaceKey ? "#atproto_space" : "#atproto"

        return SpaceAuthorityEndpoints(
            spaceHost: hostURL,
            signingKeyFragment: signingKeyFragment
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
        self.sessionDelegate = delegate
        self.urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    init(didResolver: any DIDResolving, urlSession: URLSession) {
        self.didResolver = didResolver
        self.urlSession = urlSession
        self.sessionDelegate = urlSession.delegate as? HardenedURLSessionDelegate
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
                  !authorityParts[0].contains("/") else {
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
                      let portNum = Int(portStr), (1 ... 65535).contains(portNum) else {
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
                          rawSegment.unicodeScalars.allSatisfy({ allowedPercentEncodedPathSegmentCharacters.contains($0) }) else {
                        throw SpaceHostResolutionError.invalidDID(did)
                    }
                    guard let decoded = rawSegment.removingPercentEncoding,
                          !decoded.isEmpty,
                          decoded != ".",
                          decoded != "..",
                          !decoded.contains("/"),
                          !decoded.contains("\\") else {
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

    /// Fetches and decodes the DID document using the hardened network path.
    public static func fetchDIDDocument(
        for did: String,
        urlSession: URLSession? = nil
    ) async throws -> DIDDocument {
        try await fetchDIDDocument(for: did, urlSession: urlSession, sessionDelegate: nil)
    }

    package static func fetchDIDDocument(
        for did: String,
        urlSession: URLSession? = nil,
        sessionDelegate: HardenedURLSessionDelegate? = nil
    ) async throws -> DIDDocument {
        let url = try didDocumentURL(for: did)
        guard try await NetworkService.validateURL(url) else {
            throw SpaceHostResolutionError.networkError("Security validation failed for DID document URL")
        }

        var request = URLRequest(url: url)
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
                let delegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: .default)
                let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
                (data, response) = try await NetworkService.executeDataTask(request, using: session, delegate: delegate)
            }
        } catch {
            throw SpaceHostResolutionError.networkError(error.localizedDescription)
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
