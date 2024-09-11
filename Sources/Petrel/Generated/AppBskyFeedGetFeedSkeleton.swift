import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.feed.getFeedSkeleton

public enum AppBskyFeedGetFeedSkeleton {
    public static let typeIdentifier = "app.bsky.feed.getFeedSkeleton"
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

        public let feed: [AppBskyFeedDefs.SkeletonFeedPost]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            feed: [AppBskyFeedDefs.SkeletonFeedPost]
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
    /// Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.
    func getFeedSkeleton(input: AppBskyFeedGetFeedSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetFeedSkeleton.Output?) {
        let endpoint = "/app.bsky.feed.getFeedSkeleton"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetFeedSkeleton.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
