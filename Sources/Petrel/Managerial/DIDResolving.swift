//
//  DIDResolving.swift
//  Petrel
//
//  Created by Josh LaCalamito on 10/19/24.
//

import AsyncDNSResolver
import Foundation
import os

// MARK: - DIDResolving Protocol

public protocol DIDResolving: Sendable, AnyObject {
    func resolveHandleToDID(handle: String) async throws -> String
    func resolveDIDToPDSURL(did: String) async throws -> URL
    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL)
}

// MARK: - DIDResolutionError

enum DIDResolutionError: Error {
    case invalidHandle
    case invalidDID
    case networkError(Error)
    case decodingError
    case missingPDSEndpoint
    case handleCouldNotBeResolved
}

// MARK: - DIDResolutionService

actor DIDResolutionService: DIDResolving {
    private let networkService: NetworkService
    private let cache: NSCache<NSString, CacheEntry>

    init(networkService: NetworkService) async {
        self.networkService = networkService
        cache = NSCache<NSString, CacheEntry>()
        cache.countLimit = 100 // Adjust as needed
    }

    public func resolveHandleToDID(handle: String) async throws -> String {
        // Check cache
        if let cachedDID = getCachedDID(for: handle) {
            return cachedDID
        }

        if let httpDID = try? await {
            // Put all your HTTP resolution code in a separate function
            let did = try await resolveHandleViaHTTP(handle: handle)
            cacheDID(did, for: handle)
            return did
        }() {
            return httpDID
        }

        // Try well-known second
        if let wellKnownDID = try? await resolveHandleToDIDviaWellKnown(handle: handle) {
            cacheDID(wellKnownDID, for: handle)
            return wellKnownDID
        }

        // Finally fall back to DNS
        if let dnsDID = try? await resolveHandleToDIDviaDNS(handle: handle) {
            cacheDID(dnsDID, for: handle)
            return dnsDID
        }

        // If all methods fail, throw an error
        throw DIDResolutionError.handleCouldNotBeResolved
    }

    private func resolveHandleToDIDviaWellKnown(handle: String) async throws -> String? {
        let logger = Logger(subsystem: "com.joshlacalamito.Petrel", category: "DIDResolution")

        logger.info("Starting well-known resolution for handle: \(handle)")

        // Form the URL to query
        guard let url = URL(string: "https://\(handle)/.well-known/atproto-did") else {
            logger.error("Invalid handle format cannot form URL: \(handle)")
            throw DIDResolutionError.invalidHandle
        }

        // Create URL request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await networkService.performRequest(request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.warning("Non-200 response from well-known endpoint: \(response.statusCode)")
                return nil
            }

            // Parse the plain text response
            guard
                let didString = String(data: data, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines)
            else {
                logger.error("Failed to decode response as UTF-8 text")
                throw DIDResolutionError.decodingError
            }

            // Validate the DID format
            if didString.starts(with: "did:") {
                logger.info("Successfully resolved handle via well-known endpoint: \(didString)")
                return didString
            } else {
                logger.error("Response from well-known endpoint is not a valid DID: \(didString)")
                return nil
            }
        } catch {
            logger.error("Error accessing well-known endpoint: \(error.localizedDescription)")
            return nil
        }
    }

    private func resolveHandleViaHTTP(handle: String) async throws -> String {
        let input = try ComAtprotoIdentityResolveHandle.Parameters(handle: Handle(handleString: handle))
        let endpoint = "com.atproto.identity.resolveHandle"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
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
        let decodedData = try? decoder.decode(
            ComAtprotoIdentityResolveHandle.Output.self, from: responseData
        )

        guard responseCode == 200, let did = decodedData?.did else {
            throw APIError.invalidPDSURL
        }
        cacheDID(did.didString(), for: handle)
        return did.didString()
    }

    private func resolveHandleToDIDviaDNS(handle: String) async throws -> String? {
        let logger = Logger(subsystem: "com.joshlacalamito.Petrel", category: "DIDResolution")

        logger.info("Starting DNS resolution for handle: \(handle)")

        // Create DNS resolver
        logger.debug("Initializing DNS resolver")
        let resolver = try AsyncDNSResolver()

        let domainQuery = "_atproto.\(handle)"
        logger.info("Attempting domain-level resolution with query: \(domainQuery)")

        do {
            logger.debug("Executing DNS TXT lookup for: \(domainQuery)")
            // Query for TXT records using the correct method
            let records = try await resolver.queryTXT(name: domainQuery)
            logger.info("Successfully retrieved \(records.count) TXT records for \(domainQuery)")

            // Look for a matching record
            logger.debug("Searching for 'did=' prefix in domain TXT records")
            // For user-specific records
            for (index, record) in records.enumerated() {
                logger.debug("Examining record [\(index)]: \(record.txt)")
                // Accept both formats: direct "did:..." and "did=did:..."
                if record.txt.starts(with: "did:") {
                    logger.info("Found matching user-specific DID record: \(record.txt)")
                    return record.txt
                } else if record.txt.hasPrefix("did=") {
                    let didValue = record.txt.dropFirst(4)
                    logger.info("Found matching user-specific DID record with did= prefix: \(didValue)")
                    return String(didValue)
                }
            }

            logger.warning("No matching 'did=' prefix found in domain-level TXT records")
        } catch {
            logger.error("Error looking up domain-level TXT records: \(error.localizedDescription)")
            logger.info("Falling through to user-specific record lookup")
        }

        // No valid DID found via DNS
        logger.warning("No valid DID found via DNS for handle: \(handle), will fall back to HTTP")
        return nil
    }

    public func resolveDIDToPDSURL(did: String) async throws -> URL {
        return try await resolveDIDToHandleAndPDSURL(did: did).1
    }

    public func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
        // Check cache first
        if let cachedURL = getCachedPDSURL(for: did), let cachedHandle = getCachedHandle(for: did) {
            return (cachedHandle, cachedURL)
        }

        // Determine the appropriate resolution method based on DID method
        let handle: String
        let pdsURL: URL
        if did.starts(with: "did:plc:") {
            let (resolvedHandle, resolvedPDSURL) = try await resolvePLCDID(did)
            handle = resolvedHandle
            pdsURL = resolvedPDSURL
        } else if did.starts(with: "did:web:") {
            let (resolvedHandle, resolvedPDSURL) = try await resolveWebDID(did)

            handle = resolvedHandle
            pdsURL = resolvedPDSURL
        } else {
            throw DIDResolutionError.invalidDID
        }

        // Cache the result
        cachePDSURL(pdsURL, for: did)
        cacheHandle(handle, for: did)

        return (handle, pdsURL)
    }

    private func resolvePLCDID(_ did: String) async throws -> (String, URL) {
        let endpoint = "https://plc.directory/\(did)"
        let request = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (data, response) = try await networkService.performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DIDResolutionError.networkError(
                NSError(domain: "DIDResolution", code: response.statusCode))
        }

        let decoder = JSONDecoder()
        let didDocument = try decoder.decode(DIDDocument.self, from: data)

        guard
            let pdsEndpoint = didDocument.service.first(where: { $0.type == "AtprotoPersonalDataServer" }
            )?.serviceEndpoint,
            let pdsURL = URL(string: pdsEndpoint),
            let handle = didDocument.alsoKnownAs.first.map({
                $0.replacingOccurrences(of: "at://", with: "")
            })
        else {
            throw DIDResolutionError.missingPDSEndpoint
        }

        return (handle, pdsURL)
    }

    private func resolveWebDID(_ did: String) async throws -> (String, URL) {
        let parts = did.split(separator: ":")
        guard parts.count == 3, let domain = parts.last else {
            throw DIDResolutionError.invalidDID
        }

        let endpoint = "https://\(domain)/.well-known/did.json"
        let request = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (data, response) = try await networkService.performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DIDResolutionError.networkError(
                NSError(domain: "DIDResolution", code: response.statusCode))
        }

        let decoder = JSONDecoder()
        let didDocument = try decoder.decode(DIDDocument.self, from: data)

        guard
            let pdsEndpoint = didDocument.service.first(where: { $0.type == "AtprotoPersonalDataServer" }
            )?.serviceEndpoint,
            let pdsURL = URL(string: pdsEndpoint),
            let handle = didDocument.alsoKnownAs.first.map({
                $0.replacingOccurrences(of: "at://", with: "")
            })
        else {
            throw DIDResolutionError.missingPDSEndpoint
        }

        return (handle, pdsURL)
    }

    // MARK: - Caching

    private func getCachedDID(for handle: String) -> String? {
        return (cache.object(forKey: handle as NSString) as? DIDCacheEntry)?.did
    }

    private func cacheDID(_ did: String, for handle: String) {
        cache.setObject(DIDCacheEntry(did: did), forKey: handle as NSString)
    }

    private func getCachedHandle(for handle: String) -> String? {
        return (cache.object(forKey: handle as NSString) as? DIDCacheEntry)?.did
    }

    private func cacheHandle(_ did: String, for handle: String) {
        cache.setObject(DIDCacheEntry(did: did), forKey: handle as NSString)
    }

    private func getCachedPDSURL(for did: String) -> URL? {
        return (cache.object(forKey: did as NSString) as? PDSURLCacheEntry)?.url
    }

    private func cachePDSURL(_ url: URL, for did: String) {
        cache.setObject(PDSURLCacheEntry(url: url), forKey: did as NSString)
    }
}

// Add an enum to track which methods have completed
private enum ResolutionMethod: Hashable {
    case dns
    case wellKnown
}

// MARK: - Helper Structures

private class CacheEntry {}

private class DIDCacheEntry: CacheEntry {
    let did: String
    init(did: String) { self.did = did }
}

private class HandleCacheEntry: CacheEntry {
    let handle: String
    init(handle: String) { self.handle = handle }
}

private class PDSURLCacheEntry: CacheEntry {
    let url: URL
    init(url: URL) { self.url = url }
}
