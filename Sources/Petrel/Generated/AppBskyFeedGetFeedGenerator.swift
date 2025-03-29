import Foundation

// lexicon: 1, id: app.bsky.feed.getFeedGenerator

public enum AppBskyFeedGetFeedGenerator {
    public static let typeIdentifier = "app.bsky.feed.getFeedGenerator"
    public struct Parameters: Parametrizable {
        public let feed: ATProtocolURI

        public init(
            feed: ATProtocolURI
        ) {
            self.feed = feed
        }
    }

    public struct Output: ATProtocolCodable {
        public let view: AppBskyFeedDefs.GeneratorView

        public let isOnline: Bool

        public let isValid: Bool

        // Standard public initializer
        public init(
            view: AppBskyFeedDefs.GeneratorView,

            isOnline: Bool,

            isValid: Bool

        ) {
            self.view = view

            self.isOnline = isOnline

            self.isValid = isValid
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            view = try container.decode(AppBskyFeedDefs.GeneratorView.self, forKey: .view)

            isOnline = try container.decode(Bool.self, forKey: .isOnline)

            isValid = try container.decode(Bool.self, forKey: .isValid)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(view, forKey: .view)

            try container.encode(isOnline, forKey: .isOnline)

            try container.encode(isValid, forKey: .isValid)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let viewValue = try (view as? DAGCBOREncodable)?.toCBORValue() ?? view
            map = map.adding(key: "view", value: viewValue)

            let isOnlineValue = try (isOnline as? DAGCBOREncodable)?.toCBORValue() ?? isOnline
            map = map.adding(key: "isOnline", value: isOnlineValue)

            let isValidValue = try (isValid as? DAGCBOREncodable)?.toCBORValue() ?? isValid
            map = map.adding(key: "isValid", value: isValidValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case view
            case isOnline
            case isValid
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get information about a feed generator. Implemented by AppView.
    func getFeedGenerator(input: AppBskyFeedGetFeedGenerator.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetFeedGenerator.Output?) {
        let endpoint = "app.bsky.feed.getFeedGenerator"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetFeedGenerator.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
