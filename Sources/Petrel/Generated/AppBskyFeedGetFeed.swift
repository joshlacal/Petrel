import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.feed.getFeed

public enum AppBskyFeedGetFeed {
    public static let typeIdentifier = "app.bsky.feed.getFeed"
    public struct Parameters: Parametrizable {
        public let feed: ATProtocolURI
        public let limit: Int?
        public let cursor: String?

        public init(
            feed: ATProtocolURI,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.feed = feed
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

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case unknownFeed = "UnknownFeed."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get a hydrated feed from an actor's selected feed generator. Implemented by App View.
    func getFeed(input: AppBskyFeedGetFeed.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetFeed.Output?) {
        let endpoint = "/app.bsky.feed.getFeed"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedGetFeed.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
