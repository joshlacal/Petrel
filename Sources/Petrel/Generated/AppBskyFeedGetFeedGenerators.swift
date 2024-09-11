import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.feed.getFeedGenerators

public enum AppBskyFeedGetFeedGenerators {
    public static let typeIdentifier = "app.bsky.feed.getFeedGenerators"
    public struct Parameters: Parametrizable {
        public let feeds: [ATProtocolURI]

        public init(
            feeds: [ATProtocolURI]
        ) {
            self.feeds = feeds
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
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get information about a list of feed generators.
    func getFeedGenerators(input: AppBskyFeedGetFeedGenerators.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetFeedGenerators.Output?) {
        let endpoint = "/app.bsky.feed.getFeedGenerators"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetFeedGenerators.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
