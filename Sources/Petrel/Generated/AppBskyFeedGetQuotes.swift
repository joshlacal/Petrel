import Foundation

// lexicon: 1, id: app.bsky.feed.getQuotes

public enum AppBskyFeedGetQuotes {
    public static let typeIdentifier = "app.bsky.feed.getQuotes"
    public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let cid: CID?
        public let limit: Int?
        public let cursor: String?

        public init(
            uri: ATProtocolURI,
            cid: CID? = nil,
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

        public let cid: CID?

        public let cursor: String?

        public let posts: [AppBskyFeedDefs.PostView]

        // Standard public initializer
        public init(
            uri: ATProtocolURI,

            cid: CID? = nil,

            cursor: String? = nil,

            posts: [AppBskyFeedDefs.PostView]

        ) {
            self.uri = uri

            self.cid = cid

            self.cursor = cursor

            self.posts = posts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            cid = try container.decodeIfPresent(CID.self, forKey: .cid)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            posts = try container.decode([AppBskyFeedDefs.PostView].self, forKey: .posts)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(uri, forKey: .uri)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cid, forKey: .cid)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(posts, forKey: .posts)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)

            if let value = cid {
                // Encode optional property even if it's an empty array for CBOR

                let cidValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cid", value: cidValue)
            }

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR

                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let postsValue = try (posts as? DAGCBOREncodable)?.toCBORValue() ?? posts
            map = map.adding(key: "posts", value: postsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
            case cursor
            case posts
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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedGetQuotes.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
