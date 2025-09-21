import Foundation

// lexicon: 1, id: app.bsky.feed.searchPosts

public enum AppBskyFeedSearchPosts {
    public static let typeIdentifier = "app.bsky.feed.searchPosts"
    public struct Parameters: Parametrizable {
        public let q: String
        public let sort: String?
        public let since: String?
        public let until: String?
        public let mentions: ATIdentifier?
        public let author: ATIdentifier?
        public let lang: LanguageCodeContainer?
        public let domain: String?
        public let url: URI?
        public let tag: [String]?
        public let limit: Int?
        public let cursor: String?

        public init(
            q: String,
            sort: String? = nil,
            since: String? = nil,
            until: String? = nil,
            mentions: ATIdentifier? = nil,
            author: ATIdentifier? = nil,
            lang: LanguageCodeContainer? = nil,
            domain: String? = nil,
            url: URI? = nil,
            tag: [String]? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.q = q
            self.sort = sort
            self.since = since
            self.until = until
            self.mentions = mentions
            self.author = author
            self.lang = lang
            self.domain = domain
            self.url = url
            self.tag = tag
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let hitsTotal: Int?

        public let posts: [AppBskyFeedDefs.PostView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            hitsTotal: Int? = nil,

            posts: [AppBskyFeedDefs.PostView]

        ) {
            self.cursor = cursor

            self.hitsTotal = hitsTotal

            self.posts = posts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            hitsTotal = try container.decodeIfPresent(Int.self, forKey: .hitsTotal)

            posts = try container.decode([AppBskyFeedDefs.PostView].self, forKey: .posts)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hitsTotal, forKey: .hitsTotal)

            try container.encode(posts, forKey: .posts)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            if let value = hitsTotal {
                // Encode optional property even if it's an empty array for CBOR
                let hitsTotalValue = try value.toCBORValue()
                map = map.adding(key: "hitsTotal", value: hitsTotalValue)
            }

            let postsValue = try posts.toCBORValue()
            map = map.adding(key: "posts", value: postsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case hitsTotal
            case posts
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case badQueryString = "BadQueryString."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    // MARK: - searchPosts

    /// Find posts matching search criteria, returning views of those posts. Note that this API endpoint may require authentication (eg, not public) for some service providers and implementations.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func searchPosts(input: AppBskyFeedSearchPosts.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedSearchPosts.Output?) {
        let endpoint = "app.bsky.feed.searchPosts"

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

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyFeedSearchPosts.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.feed.searchPosts: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
