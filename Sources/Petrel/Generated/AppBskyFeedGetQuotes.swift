import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.feed.getQuotes

public enum AppBskyFeedGetQuotes {
    public static let typeIdentifier = "app.bsky.feed.getQuotes"
    public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let cid: String?
        public let limit: Int?
        public let cursor: String?

        public init(
            uri: ATProtocolURI,
            cid: String? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.uri = uri
            self.cid = cid
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let uri: ATProtocolURI

        public let cid: String?

        public let cursor: String?

        public let posts: [AppBskyFeedDefs.PostView]

        // Standard public initializer
        public init(
            uri: ATProtocolURI,

            cid: String? = nil,

            cursor: String? = nil,

            posts: [AppBskyFeedDefs.PostView]

        ) {
            self.uri = uri

            self.cid = cid

            self.cursor = cursor

            self.posts = posts
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get a list of quotes for a given post.
    func getQuotes(input: AppBskyFeedGetQuotes.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetQuotes.Output?) {
        let endpoint = "app.bsky.feed.getQuotes"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetQuotes.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
