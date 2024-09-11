import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.feed.getSuggestedFeeds

public enum AppBskyFeedGetSuggestedFeeds {
    public static let typeIdentifier = "app.bsky.feed.getSuggestedFeeds"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
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
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get a list of suggested feeds (feed generators) for the requesting account.
    func getSuggestedFeeds(input: AppBskyFeedGetSuggestedFeeds.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetSuggestedFeeds.Output?) {
        let endpoint = "/app.bsky.feed.getSuggestedFeeds"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetSuggestedFeeds.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
