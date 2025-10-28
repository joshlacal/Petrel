//
//  DIDResolving.swift
//  Petrel
//
//  Created by Josh LaCalamito on 10/19/24.
//

import AsyncDNSResolver
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import Logging

// MARK: - DIDResolving Protocol

public protocol DIDResolving: Sendable, AnyObject {
    func resolveHandleToDID(handle: String) async throws -> String
    func resolveDIDToPDSURL(did: String) async throws -> URL
    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL)
}

// MARK: - DIDResolutionError

enum DIDResolutionError: Error, LocalizedError {
    case invalidHandle(String)
    case invalidDID(String)
    case networkError(Error)
    case decodingError(String)
    case missingPDSEndpoint(String)
    case handleCouldNotBeResolved(String)
    case dnsResolutionFailed(String)
    case serverNotResponding(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case let .invalidHandle(handle):
            return "The handle '\(handle)' is not in a valid format."
        case let .invalidDID(did):
            return "The DID '\(did)' is not valid or supported."
        case let .networkError(error):
            return "Network error during resolution: \(error.localizedDescription)"
        case let .decodingError(context):
            return "Failed to decode server response: \(context)"
        case let .missingPDSEndpoint(did):
            return "No Personal Data Server (PDS) endpoint found for '\(did)'."
        case let .handleCouldNotBeResolved(handle):
            return "Unable to resolve the handle '\(handle)'. It may not exist or be accessible."
        case let .dnsResolutionFailed(handle):
            return "DNS resolution failed for handle '\(handle)'."
        case let .serverNotResponding(server):
            return "Server '\(server)' is not responding."
        case .cancelled:
            return "Resolution was cancelled."
        }
    }

    var failureReason: String? {
        switch self {
        case let .invalidHandle(handle):
            return "Handle '\(handle)' doesn't follow the expected format (e.g., user.bsky.social)."
        case let .handleCouldNotBeResolved(handle):
            return "Multiple resolution methods failed for '\(handle)'."
        case let .networkError(error):
            return "Network connectivity issue: \(error.localizedDescription)"
        case .serverNotResponding:
            return "The authentication server is currently unavailable."
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidHandle:
            return "Check the handle format. It should be like 'username.bsky.social'."
        case .handleCouldNotBeResolved:
            return "Verify the handle exists and try again. Check for typos."
        case .networkError, .serverNotResponding:
            return "Check your internet connection and try again."
        case .missingPDSEndpoint:
            return "This appears to be a configuration issue. Try a different handle."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
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

    func resolveHandleToDID(handle: String) async throws -> String {
        // Check for cancellation at the start
        try Task.checkCancellation()

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

        // Check for cancellation before next attempt
        try Task.checkCancellation()

        // Try well-known second
        if let wellKnownDID = try? await resolveHandleToDIDviaWellKnown(handle: handle) {
            cacheDID(wellKnownDID, for: handle)
            return wellKnownDID
        }

        // Check for cancellation before DNS fallback
        try Task.checkCancellation()

        // Finally fall back to DNS
        if let dnsDID = try? await resolveHandleToDIDviaDNS(handle: handle) {
            cacheDID(dnsDID, for: handle)
            return dnsDID
        }

        // If all methods fail, throw an error with the handle
        throw DIDResolutionError.handleCouldNotBeResolved(handle)
    }

    private func resolveHandleToDIDviaWellKnown(handle: String) async throws -> String? {
        let logger = Logger(label: "com.joshlacalamito.Petrel.DIDResolution")

        // Check for cancellation before network operation
        try Task.checkCancellation()

        logger.info("Starting well-known resolution for handle: \(handle)")

        // Form the URL to query
        guard let url = URL(string: "https://\(handle)/.well-known/atproto-did") else {
            logger.error("Invalid handle format cannot form URL: \(handle)")
            throw DIDResolutionError.invalidHandle(handle)
        }

        // Create URL request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await networkService.performRequest(request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.warning("Invalid response type from well-known endpoint")
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                logger.warning("Non-200 response from well-known endpoint: \(httpResponse.statusCode)")
                return nil
            }

            // Parse the plain text response
            guard
                let didString = String(data: data, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines)
            else {
                logger.error("Failed to decode response as UTF-8 text")
                throw DIDResolutionError.decodingError("Failed to decode well-known DID response as UTF-8")
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
        // Check for cancellation before network operation
        try Task.checkCancellation()

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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(description: "Response is not HTTPURLResponse")
        }

        let responseCode = httpResponse.statusCode

        // Content-Type validation
        guard let contentType = httpResponse.allHeaderFields["Content-Type"] as? String else {
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
        let logger = Logger(label: "com.joshlacalamito.Petrel.DIDResolution")

        // Check for cancellation before DNS operation
        try Task.checkCancellation()

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

    func resolveDIDToPDSURL(did: String) async throws -> URL {
        return try await resolveDIDToHandleAndPDSURL(did: did).1
    }

    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
        // Check for cancellation at the start
        try Task.checkCancellation()

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
            throw DIDResolutionError.invalidDID(did)
        }

        // Cache the result
        cachePDSURL(pdsURL, for: did)
        cacheHandle(handle, for: did)

        return (handle, pdsURL)
    }

    private func resolvePLCDID(_ did: String) async throws -> (String, URL) {
        // Check for cancellation before network operation
        try Task.checkCancellation()

        let endpoint = "https://plc.directory/\(did)"
        let request = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (data, response) = try await networkService.performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DIDResolutionError.networkError(
                NSError(domain: "DIDResolution", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
        }

        guard httpResponse.statusCode == 200 else {
            throw DIDResolutionError.networkError(
                NSError(domain: "DIDResolution", code: httpResponse.statusCode))
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
            throw DIDResolutionError.missingPDSEndpoint(did)
        }

        return (handle, pdsURL)
    }

    private func resolveWebDID(_ did: String) async throws -> (String, URL) {
        // Check for cancellation before network operation
        try Task.checkCancellation()

        let parts = did.split(separator: ":")
        guard parts.count == 3, let domain = parts.last else {
            throw DIDResolutionError.invalidDID(did)
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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DIDResolutionError.networkError(
                NSError(domain: "DIDResolution", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
        }

        guard httpResponse.statusCode == 200 else {
            throw DIDResolutionError.networkError(
                NSError(domain: "DIDResolution", code: httpResponse.statusCode))
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
            throw DIDResolutionError.missingPDSEndpoint(did)
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
