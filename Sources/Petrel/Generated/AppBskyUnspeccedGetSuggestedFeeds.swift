import Foundation

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

            let feedsValue = try (feeds as? DAGCBOREncodable)?.toCBORValue() ?? feeds
            map = map.adding(key: "feeds", value: feedsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case feeds
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// Get a list of suggested feeds
    func getSuggestedFeeds(input: AppBskyUnspeccedGetSuggestedFeeds.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestedFeeds.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestedFeeds"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetSuggestedFeeds.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
