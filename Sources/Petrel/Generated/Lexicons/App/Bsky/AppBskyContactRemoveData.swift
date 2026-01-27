import Foundation

// lexicon: 1, id: app.bsky.contact.removeData

public enum AppBskyContactRemoveData {
    public static let typeIdentifier = "app.bsky.contact.removeData"
    public struct Input: ATProtocolCodable {
        /// Standard public initializer
        public init() {}

        public func toCBORValue() throws -> Any {
            return OrderedCBORMap()
        }
    }

    public struct Output: ATProtocolCodable {
        // Empty output - no properties (response is {})

        /// Standard public initializer
        public init(
        ) {}

        public init(from decoder: Decoder) throws {
            // Empty output - just validate it's an object by trying to get any container
            _ = try decoder.singleValueContainer()
        }

        public func encode(to encoder: Encoder) throws {
            // Empty output - encode empty object
            _ = encoder.singleValueContainer()
        }

        public func toCBORValue() throws -> Any {
            // Empty output - return empty CBOR map
            return OrderedCBORMap()
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case invalidDid = "InvalidDid."
        case internalError = "InternalError."
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.App.Bsky.Contact {
    // MARK: - removeData

    /// Removes all stored hashes used for contact matching, existing matches, and sync status. Requires authentication.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func removeData(
        input: AppBskyContactRemoveData.Input

    ) async throws -> (responseCode: Int, data: AppBskyContactRemoveData.Output?) {
        let endpoint = "app.bsky.contact.removeData"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.contact.removeData")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyContactRemoveData.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.contact.removeData: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
