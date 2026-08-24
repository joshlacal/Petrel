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
    internal nonisolated(unsafe) static var dnsTXTResolverOverride: (@Sendable (String) async throws -> [String])?

    static func didFromTXTRecord(_ txt: String) -> String? {
        let trimmed = txt.trimmingCharacters(in: .whitespacesAndNewlines)

        let rawDID: String
        if trimmed.hasPrefix("did=") {
            rawDID = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if trimmed.hasPrefix("did:") {
            rawDID = trimmed
        } else {
            return nil
        }

        let normalized: String
        if rawDID.hasPrefix("did:did:") {
            normalized = "did:" + rawDID.dropFirst("did:did:".count)
        } else {
            normalized = rawDID
        }

        guard normalized.count > "did:".count else {
            return nil
        }
        return normalized
    }

    init(networkService: NetworkService) async {
        self.networkService = networkService
        cache = NSCache<NSString, CacheEntry>()
        cache.countLimit = 100 // Adjust as needed
    }

    func resolveHandleToDID(handle: String) async throws -> String {
        // Check for cancellation at the start
        try Task.checkCancellation()

        guard let canonicalHandle = try? Handle(handleString: handle).value else {
            throw DIDResolutionError.invalidHandle(handle)
        }

        // Check cache
        if let cachedDID = getCachedDID(for: canonicalHandle) {
            return cachedDID
        }

        // Resolve candidate DID via HTTP resolveHandle first, then well-known, then DNS
        var candidateDID: String?
        do {
            candidateDID = try await resolveHandleViaHTTP(handle: canonicalHandle)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            do {
                candidateDID = try await resolveHandleToDIDviaWellKnown(handle: canonicalHandle)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                candidateDID = nil
            }
            if candidateDID == nil {
                do {
                    candidateDID = try await resolveHandleToDIDviaDNS(handle: canonicalHandle)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    candidateDID = nil
                }
            }
        }
        guard let did = candidateDID else {
            throw DIDResolutionError.handleCouldNotBeResolved(handle)
        }

        // Bidirectional verification:
        // Verify DID document's alsoKnownAs contains at://<canonicalHandle>
        try Task.checkCancellation()
        let didDoc: DIDDocument
        do {
            didDoc = try await fetchDIDDocument(for: did)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DIDResolutionError.handleCouldNotBeResolved(handle)
        }

        let expectedAKA = "at://\(canonicalHandle)"
        guard didDoc.alsoKnownAs.contains(where: { $0.lowercased() == expectedAKA }) else {
            throw DIDResolutionError.handleCouldNotBeResolved(handle)
        }

        cacheDID(did, for: canonicalHandle)
        return did
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
            let (data, httpResponse) = try await networkService.performRequest(request)

            guard httpResponse.statusCode == 200 else {
                logger.warning("Non-200 response from well-known endpoint: \(httpResponse.statusCode)")
                return nil
            }

            // Parse the plain text response
            guard
                let didString = String(data: data, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
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
        } catch is CancellationError {
            throw CancellationError()
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

        let (responseData, httpResponse) = try await networkService.performRequest(urlRequest)

        let responseCode = httpResponse.statusCode

        // Content-Type validation
        guard let contentType = httpResponse.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decodedData = try? JSONCoders.decode(
            ComAtprotoIdentityResolveHandle.Output.self, from: responseData
        )

        guard responseCode == 200, let did = decodedData?.did else {
            throw APIError.invalidPDSURL
        }
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
            let txtStrings: [String]
            if let override = Self.dnsTXTResolverOverride {
                txtStrings = try await override(domainQuery)
            } else {
                logger.debug("Executing DNS TXT lookup for: \(domainQuery)")
                let records = try await resolver.queryTXT(name: domainQuery)
                logger.info("Successfully retrieved \(records.count) TXT records for \(domainQuery)")
                txtStrings = records.map(\.txt)
            }

            // Look for a matching record
            logger.debug("Searching for 'did=' prefix in domain TXT records")
            // For user-specific records
            for (index, txt) in txtStrings.enumerated() {
                logger.debug("Examining record [\(index)]: \(txt)")
                if let did = Self.didFromTXTRecord(txt) {
                    logger.info("Found matching user-specific DID record: \(did)")
                    return did
                }
            }

            logger.warning("No matching 'did=' prefix found in domain-level TXT records")
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            logger.error("Error looking up domain-level TXT records: \(error.localizedDescription)")
            logger.info("Falling through to user-specific record lookup")
        }
        // No valid DID found via DNS
        logger.warning("No valid DID found via DNS for handle: \(handle), will fall back to HTTP")
        return nil
    }

    func resolveDIDToPDSURL(did: String) async throws -> URL {
        if let cachedURL = getCachedPDSURL(for: did) {
            return cachedURL
        }
        return try await resolveDIDToHandleAndPDSURL(did: did).1
    }

    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
        // Check for cancellation at the start
        try Task.checkCancellation()

        // Check cache first
        if let cachedURL = getCachedPDSURL(for: did), let cachedHandle = getCachedHandle(for: did) {
            return (cachedHandle, cachedURL)
        }

        let didDocument = try await fetchDIDDocument(for: did)
        let pdsURL = try extractPDSURL(from: didDocument, did: did)
        let candidateHandle = extractCandidateHandle(from: didDocument)

        // Cache PDS URL immediately since DID document resolution and PDS extraction succeeded
        cachePDSURL(pdsURL, for: did)

        guard let candidate = candidateHandle else {
            // No candidate handle asserted in DID document -> definitive missing handle
            cacheHandle(Handle.invalid, for: did)
            return (Handle.invalid, pdsURL)
        }

        // Bidirectional verification (DID -> handle):
        // When the candidate handle round-trips to this DID, cache handle and return.
        // When reverse resolution definitively resolves to a different DID, cache Handle.invalid.
        // When reverse resolution encounters a transient error, return Handle.invalid for this call
        // but do NOT cache it, allowing subsequent calls to retry the reverse check.
        do {
            let reverseDID = try await resolveHandleToDID(handle: candidate)
            if reverseDID == did {
                // (3) Verified success: cache handle and return
                cacheHandle(candidate, for: did)
                return (candidate, pdsURL)
            } else {
                // (2a) DEFINITIVE mismatch — reverse resolution SUCCEEDED but returned a different DID
                cacheHandle(Handle.invalid, for: did)
                return (Handle.invalid, pdsURL)
            }
        } catch is CancellationError {
            // (1) CancellationError must ALWAYS propagate (never swallowed by try?, never converted to handle.invalid)
            throw CancellationError()
        } catch {
            // (2b) TRANSIENT failure — reverse resolution errored (network, 5xx, DNS failure)
            // Return PDS URL with the handle marked unverified/invalid for THIS call
            // but DO NOT write handle.invalid into the resolver cache (cache only the DID-doc/PDS part).
            // Next call retries the reverse check.
            return (Handle.invalid, pdsURL)
        }
    }

    private func fetchDIDDocument(for did: String) async throws -> DIDDocument {
        if did.starts(with: "did:plc:") {
            return try await fetchPLCDIDDocument(did)
        } else if did.starts(with: "did:web:") {
            return try await fetchWebDIDDocument(did)
        } else {
            throw DIDResolutionError.invalidDID(did)
        }
    }

    private func fetchPLCDIDDocument(_ did: String) async throws -> DIDDocument {
        try Task.checkCancellation()

        let endpoint = "https://plc.directory/\(did)"
        let request = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (data, httpResponse) = try await networkService.performRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw DIDResolutionError.networkError(
                NSError(domain: "DIDResolution", code: httpResponse.statusCode)
            )
        }

        return try JSONCoders.decode(DIDDocument.self, from: data)
    }

    private func fetchWebDIDDocument(_ did: String) async throws -> DIDDocument {
        try Task.checkCancellation()

        let parts = did.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts[0] == "did", parts[1] == "web" else {
            throw DIDResolutionError.invalidDID(did)
        }

        let rawAuthority = String(parts[2])
        let authorityParts = rawAuthority.components(separatedBy: "%3A")
        guard (1 ... 2).contains(authorityParts.count),
              !authorityParts[0].contains("%"),
              !authorityParts[0].contains("/") else {
            throw DIDResolutionError.invalidDID(did)
        }
        let domain: String
        if authorityParts.count == 2 {
            let port = authorityParts[1]
            guard !port.isEmpty, !port.contains("%"), !port.contains("/"),
                  let portNum = UInt16(port), portNum > 0 else {
                throw DIDResolutionError.invalidDID(did)
            }
            domain = "\(authorityParts[0]):\(port)"
        } else {
            domain = authorityParts[0]
        }

        let pathComponents = parts.dropFirst(3)
        let endpoint: String
        if pathComponents.isEmpty {
            endpoint = "https://\(domain)/.well-known/did.json"
        } else {
            var decodedSegments: [String] = []
            for component in pathComponents {
                guard let decoded = String(component).removingPercentEncoding,
                      !decoded.isEmpty,
                      decoded != ".",
                      decoded != "..",
                      !decoded.contains("/") else {
                    throw DIDResolutionError.invalidDID(did)
                }
                decodedSegments.append(decoded)
            }
            let path = decodedSegments.joined(separator: "/")
            endpoint = "https://\(domain)/\(path)/did.json"
        }

        let request = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (data, httpResponse) = try await networkService.performRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw DIDResolutionError.networkError(
                NSError(domain: "DIDResolution", code: httpResponse.statusCode)
            )
        }

        return try JSONCoders.decode(DIDDocument.self, from: data)
    }

    private func extractPDSURL(from didDocument: DIDDocument, did: String) throws -> URL {
        // Swan & Upstream matchesIdentifier rule:
        // Exactly one service matching id (#atproto_pds or did#atproto_pds) AND type AtprotoPersonalDataServer
        let matches = didDocument.service.filter { service in
            (service.id == "#atproto_pds" || service.id == "\(did)#atproto_pds")
                && service.type == "AtprotoPersonalDataServer"
        }
        guard matches.count == 1,
              let service = matches.first,
              let pdsURL = URL(string: service.serviceEndpoint)
        else {
            throw DIDResolutionError.missingPDSEndpoint(did)
        }
        return pdsURL
    }

    private func extractCandidateHandle(from didDocument: DIDDocument) -> String? {
        for aka in didDocument.alsoKnownAs {
            let candidate: String
            if aka.hasPrefix("at://") {
                candidate = String(aka.dropFirst(5))
            } else {
                candidate = aka
            }
            if !candidate.isEmpty, let validHandle = try? Handle(handleString: candidate).value {
                return validHandle
            }
        }
        return nil
    }

    // MARK: - Caching

    private func getCachedDID(for handle: String) -> String? {
        return (cache.object(forKey: "did:\(handle)" as NSString) as? DIDCacheEntry)?.did
    }

    private func cacheDID(_ did: String, for handle: String) {
        cache.setObject(DIDCacheEntry(did: did), forKey: "did:\(handle)" as NSString)
    }

    private func getCachedHandle(for did: String) -> String? {
        return (cache.object(forKey: "handle:\(did)" as NSString) as? HandleCacheEntry)?.handle
    }

    private func cacheHandle(_ handle: String, for did: String) {
        cache.setObject(HandleCacheEntry(handle: handle), forKey: "handle:\(did)" as NSString)
    }

    private func getCachedPDSURL(for did: String) -> URL? {
        return (cache.object(forKey: "pds:\(did)" as NSString) as? PDSURLCacheEntry)?.url
    }

    private func cachePDSURL(_ url: URL, for did: String) {
        cache.setObject(PDSURLCacheEntry(url: url), forKey: "pds:\(did)" as NSString)
    }
}

/// Add an enum to track which methods have completed
private enum ResolutionMethod: Hashable {
    case dns
    case wellKnown
}

// MARK: - Helper Structures

private class CacheEntry {}

private class DIDCacheEntry: CacheEntry {
    let did: String
    init(did: String) {
        self.did = did
    }
}

private class HandleCacheEntry: CacheEntry {
    let handle: String
    init(handle: String) {
        self.handle = handle
    }
}

private class PDSURLCacheEntry: CacheEntry {
    let url: URL
    init(url: URL) {
        self.url = url
    }
}
