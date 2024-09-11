import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.feed.getListFeed

public enum AppBskyFeedGetListFeed {
    public static let typeIdentifier = "app.bsky.feed.getListFeed"
    public struct Parameters: Parametrizable {
        public let list: ATProtocolURI
        public let limit: Int?
        public let cursor: String?

        public init(
            list: ATProtocolURI,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.list = list
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
        case unknownList = "UnknownList."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.
    func getListFeed(input: AppBskyFeedGetListFeed.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetListFeed.Output?) {
        let endpoint = "/app.bsky.feed.getListFeed"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetListFeed.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
