import Foundation

// lexicon: 1, id: app.bsky.unspecced.getTrendingTopics

public enum AppBskyUnspeccedGetTrendingTopics {
    public static let typeIdentifier = "app.bsky.unspecced.getTrendingTopics"
    public struct Parameters: Parametrizable {
        public let viewer: String?
        public let limit: Int?

        public init(
            viewer: String? = nil,
            limit: Int? = nil
        ) {
            self.viewer = viewer
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let topics: [AppBskyUnspeccedDefs.TrendingTopic]

        public let suggested: [AppBskyUnspeccedDefs.TrendingTopic]

        // Standard public initializer
        public init(
            topics: [AppBskyUnspeccedDefs.TrendingTopic],

            suggested: [AppBskyUnspeccedDefs.TrendingTopic]

        ) {
            self.topics = topics

            self.suggested = suggested
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// Get a list of trending topics
    func getTrendingTopics(input: AppBskyUnspeccedGetTrendingTopics.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetTrendingTopics.Output?) {
        let endpoint = "app.bsky.unspecced.getTrendingTopics"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetTrendingTopics.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
