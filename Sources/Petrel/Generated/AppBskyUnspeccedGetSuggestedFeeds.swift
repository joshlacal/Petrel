import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: app.bsky.unspecced.getSuggestedFeeds

public enum AppBskyUnspeccedGetSuggestedFeeds {
    public static let typeIdentifier = "app.bsky.unspecced.getSuggestedFeeds"
    public struct Parameters: Parametrizable {
        public let limit: Int?

        public init(
            limit: Int? = nil
        ) {
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let feeds: [AppBskyFeedDefs.GeneratorView]

        // Standard public initializer
        public init(
            feeds: [AppBskyFeedDefs.GeneratorView]

        ) {
            self.feeds = feeds
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            feeds = try container.decode([AppBskyFeedDefs.GeneratorView].self, forKey: .feeds)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(feeds, forKey: .feeds)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let feedsValue = try feeds.toCBORValue()
            map = map.adding(key: "feeds", value: feedsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case feeds
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getSuggestedFeeds

    /// Get a list of suggested feeds
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getSuggestedFeeds(input: AppBskyUnspeccedGetSuggestedFeeds.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestedFeeds.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestedFeeds"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.unspecced.getSuggestedFeeds")
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
                let decodedData = try decoder.decode(AppBskyUnspeccedGetSuggestedFeeds.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getSuggestedFeeds: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
