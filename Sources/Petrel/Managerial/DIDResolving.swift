//
//  DIDResolving.swift
//  Petrel
//
//  Created by Josh LaCalamito on 10/19/24.
//

import Foundation

// MARK: - DIDResolving Protocol

public protocol DIDResolving: Sendable, AnyObject {
    func resolveHandleToDID(handle: String) async throws -> String
    func resolveDIDToPDSURL(did: String) async throws -> URL
}

// MARK: - DIDResolutionError

enum DIDResolutionError: Error {
    case invalidHandle
    case invalidDID
    case networkError(Error)
    case decodingError
    case missingPDSEndpoint
}

// MARK: - DIDResolutionService

actor DIDResolutionService: DIDResolving {
    private let networkManager: NetworkManaging
    private let cache: NSCache<NSString, CacheEntry>

    init(networkManager: NetworkManaging) async {
        self.networkManager = networkManager
        cache = NSCache<NSString, CacheEntry>()
        cache.countLimit = 100 // Adjust as needed
    }

    public func resolveHandleToDID(handle: String) async throws -> String {
        let input = ComAtprotoIdentityResolveHandle.Parameters(handle: try Handle(handleString: handle))
        let endpoint = "com.atproto.identity.resolveHandle"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoIdentityResolveHandle.Output.self, from: responseData)

        guard responseCode == 200, let did = decodedData?.did else {
            throw APIError.invalidPDSURL
        }
        return did.didString()
    }

    public func resolveDIDToPDSURL(did: String) async throws -> URL {
        // Check cache first
        if let cachedURL = getCachedPDSURL(for: did) {
            return cachedURL
        }

        // Determine the appropriate resolution method based on DID method
        let pdsURL: URL
        if did.starts(with: "did:plc:") {
            pdsURL = try await resolvePLCDID(did)
        } else if did.starts(with: "did:web:") {
            pdsURL = try await resolveWebDID(did)
        } else {
            throw DIDResolutionError.invalidDID
        }

        // Cache the result
        cachePDSURL(pdsURL, for: did)

        return pdsURL
    }

    private func resolvePLCDID(_ did: String) async throws -> URL {
        let endpoint = "https://plc.directory/\(did)"
        let request = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (data, response) = try await networkManager.performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DIDResolutionError.networkError(NSError(domain: "DIDResolution", code: response.statusCode))
        }

        let decoder = JSONDecoder()
        let didDocument = try decoder.decode(DIDDocument.self, from: data)

        guard let pdsEndpoint = didDocument.service.first(where: { $0.type == "AtprotoPersonalDataServer" })?.serviceEndpoint,
              let pdsURL = URL(string: pdsEndpoint)
        else {
            throw DIDResolutionError.missingPDSEndpoint
        }

        return pdsURL
    }

    private func resolveWebDID(_ did: String) async throws -> URL {
        let parts = did.split(separator: ":")
        guard parts.count == 3, let domain = parts.last else {
            throw DIDResolutionError.invalidDID
        }

        let endpoint = "https://\(domain)/.well-known/did.json"
        let request = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (data, response) = try await networkManager.performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DIDResolutionError.networkError(NSError(domain: "DIDResolution", code: response.statusCode))
        }

        let decoder = JSONDecoder()
        let didDocument = try decoder.decode(DIDDocument.self, from: data)

        guard let pdsEndpoint = didDocument.service.first(where: { $0.type == "AtprotoPersonalDataServer" })?.serviceEndpoint,
              let pdsURL = URL(string: pdsEndpoint)
        else {
            throw DIDResolutionError.missingPDSEndpoint
        }

        return pdsURL
    }

    // MARK: - Caching

    private func getCachedDID(for handle: String) -> String? {
        return (cache.object(forKey: handle as NSString) as? DIDCacheEntry)?.did
    }

    private func cacheDID(_ did: String, for handle: String) {
        cache.setObject(DIDCacheEntry(did: did), forKey: handle as NSString)
    }

    private func getCachedPDSURL(for did: String) -> URL? {
        return (cache.object(forKey: did as NSString) as? PDSURLCacheEntry)?.url
    }

    private func cachePDSURL(_ url: URL, for did: String) {
        cache.setObject(PDSURLCacheEntry(url: url), forKey: did as NSString)
    }
}

// MARK: - Helper Structures

private class CacheEntry {}

private class DIDCacheEntry: CacheEntry {
    let did: String
    init(did: String) { self.did = did }
}

private class PDSURLCacheEntry: CacheEntry {
    let url: URL
    init(url: URL) { self.url = url }
}
