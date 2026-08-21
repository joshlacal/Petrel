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

    private static func isSecureOrLoopback(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "https" { return true }
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

    public init(didResolver: any DIDResolving) {
        self.didResolver = didResolver
        self.urlSession = .shared
    }

    init(didResolver: any DIDResolving, urlSession: URLSession) {
        self.didResolver = didResolver
        self.urlSession = urlSession
    }

    /// Resolves the space authority DID document and extracts endpoints.
    public func resolve(authorityDID: String) async throws -> SpaceAuthorityEndpoints {
        let doc = try await fetchDIDDocument(for: authorityDID)
        return try SpaceAuthorityEndpoints.extract(from: doc)
    }

    /// Pure helper to construct the canonical DID document URL for `did:plc:` and `did:web:` per specifications.
    public static func didDocumentURL(for did: String) throws -> URL {
        let endpoint: String
        if did.starts(with: "did:plc:") {
            endpoint = "https://plc.directory/\(did)"
        } else if did.starts(with: "did:web:") {
            let parts = did.split(separator: ":")
            guard parts.count >= 3 else {
                throw SpaceHostResolutionError.invalidDID(did)
            }
            let domain = String(parts[2])
            if parts.count == 3 {
                endpoint = "https://\(domain)/.well-known/did.json"
            } else {
                let path = parts[3...].joined(separator: "/")
                endpoint = "https://\(domain)/\(path)/did.json"
            }
        } else {
            throw SpaceHostResolutionError.invalidDID(did)
        }

        guard let url = URL(string: endpoint) else {
            throw SpaceHostResolutionError.invalidDID(did)
        }
        return url
    }

    /// Fetches and decodes the DID document using a given URLSession.
    public static func fetchDIDDocument(for did: String, urlSession: URLSession = .shared) async throws -> DIDDocument {
        let url = try didDocumentURL(for: did)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
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
        try await Self.fetchDIDDocument(for: did, urlSession: urlSession)
    }
}
