import Foundation
internal import ZippyJSON

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
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// An unspecced view of globally popular feed generators.
    func getPopularFeedGenerators(input: AppBskyUnspeccedGetPopularFeedGenerators.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetPopularFeedGenerators.Output?) {
        let endpoint = "/app.bsky.unspecced.getPopularFeedGenerators"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetPopularFeedGenerators.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
