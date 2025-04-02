import Foundation

// lexicon: 1, id: app.bsky.unspecced.getPopularFeedGenerators

public enum AppBskyUnspeccedGetPopularFeedGenerators {
    public static let typeIdentifier = "app.bsky.unspecced.getPopularFeedGenerators"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        public let query: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil,
            query: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
            self.query = query
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let feeds: [AppBskyFeedDefs.GeneratorView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            feeds: [AppBskyFeedDefs.GeneratorView]

        ) {
            self.cursor = cursor

            self.feeds = feeds
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            feeds = try container.decode([AppBskyFeedDefs.GeneratorView].self, forKey: .feeds)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(feeds, forKey: .feeds)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR

                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let feedsValue = try (feeds as? DAGCBOREncodable)?.toCBORValue() ?? feeds
            map = map.adding(key: "feeds", value: feedsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case feeds
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// An unspecced view of globally popular feed generators.
    func getPopularFeedGenerators(input: AppBskyUnspeccedGetPopularFeedGenerators.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetPopularFeedGenerators.Output?) {
        let endpoint = "app.bsky.unspecced.getPopularFeedGenerators"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetPopularFeedGenerators.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
