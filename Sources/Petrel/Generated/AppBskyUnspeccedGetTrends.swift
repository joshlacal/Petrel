import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: app.bsky.unspecced.getTrends

public enum AppBskyUnspeccedGetTrends {
    public static let typeIdentifier = "app.bsky.unspecced.getTrends"
    public struct Parameters: Parametrizable {
        public let limit: Int?

        public init(
            limit: Int? = nil
        ) {
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let trends: [AppBskyUnspeccedDefs.TrendView]

        // Standard public initializer
        public init(
            trends: [AppBskyUnspeccedDefs.TrendView]

        ) {
            self.trends = trends
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            trends = try container.decode([AppBskyUnspeccedDefs.TrendView].self, forKey: .trends)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(trends, forKey: .trends)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let trendsValue = try trends.toCBORValue()
            map = map.adding(key: "trends", value: trendsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case trends
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getTrends

    /// Get the current trends on the network
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getTrends(input: AppBskyUnspeccedGetTrends.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetTrends.Output?) {
        let endpoint = "app.bsky.unspecced.getTrends"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.unspecced.getTrends")
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
                let decodedData = try decoder.decode(AppBskyUnspeccedGetTrends.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getTrends: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
