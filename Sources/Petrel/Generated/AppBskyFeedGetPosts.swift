import Foundation

// lexicon: 1, id: app.bsky.feed.getPosts

public enum AppBskyFeedGetPosts {
    public static let typeIdentifier = "app.bsky.feed.getPosts"
    public struct Parameters: Parametrizable {
        public let uris: [ATProtocolURI]

        public init(
            uris: [ATProtocolURI]
        ) {
            self.uris = uris
        }
    }

    public struct Output: ATProtocolCodable {
        public let posts: [AppBskyFeedDefs.PostView]

        // Standard public initializer
        public init(
            posts: [AppBskyFeedDefs.PostView]

        ) {
            self.posts = posts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            posts = try container.decode([AppBskyFeedDefs.PostView].self, forKey: .posts)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(posts, forKey: .posts)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let postsValue = try posts.toCBORValue()
            map = map.adding(key: "posts", value: postsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case posts
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    // MARK: - getPosts

    /// Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed skeleton'.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getPosts(input: AppBskyFeedGetPosts.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetPosts.Output?) {
        let endpoint = "app.bsky.feed.getPosts"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedGetPosts.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
