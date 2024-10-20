import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.feed.getTimeline

public enum AppBskyFeedGetTimeline {
    public static let typeIdentifier = "app.bsky.feed.getTimeline"
    public struct Parameters: Parametrizable {
        public let algorithm: String?
        public let limit: Int?
        public let cursor: String?

        public init(
            algorithm: String? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.algorithm = algorithm
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let feed: [AppBskyFeedDefs.FeedViewPost]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            feed: [AppBskyFeedDefs.FeedViewPost]

        ) {
            self.cursor = cursor

            self.feed = feed
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.
    func getTimeline(input: AppBskyFeedGetTimeline.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetTimeline.Output?) {
        let endpoint = "app.bsky.feed.getTimeline"

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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedGetTimeline.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
