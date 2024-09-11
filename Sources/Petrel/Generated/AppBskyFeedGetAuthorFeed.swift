import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.feed.getAuthorFeed

public enum AppBskyFeedGetAuthorFeed {
    public static let typeIdentifier = "app.bsky.feed.getAuthorFeed"
    public struct Parameters: Parametrizable {
        public let actor: String
        public let limit: Int?
        public let cursor: String?
        public let filter: String?

        public init(
            actor: String,
            limit: Int? = nil,
            cursor: String? = nil,
            filter: String? = nil
        ) {
            self.actor = actor
            self.limit = limit
            self.cursor = cursor
            self.filter = filter
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
        case blockedActor = "BlockedActor."
        case blockedByActor = "BlockedByActor."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.
    func getAuthorFeed(input: AppBskyFeedGetAuthorFeed.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetAuthorFeed.Output?) {
        let endpoint = "/app.bsky.feed.getAuthorFeed"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetAuthorFeed.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
