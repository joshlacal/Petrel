import Foundation

// lexicon: 1, id: app.bsky.feed.getActorLikes

public enum AppBskyFeedGetActorLikes {
    public static let typeIdentifier = "app.bsky.feed.getActorLikes"
    public struct Parameters: Parametrizable {
        public let actor: ATIdentifier
        public let limit: Int?
        public let cursor: String?

        public init(
            actor: ATIdentifier,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.actor = actor
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            feed = try container.decode([AppBskyFeedDefs.FeedViewPost].self, forKey: .feed)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(feed, forKey: .feed)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let feedValue = try feed.toCBORValue()
            map = map.adding(key: "feed", value: feedValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case feed
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
    // MARK: - getActorLikes

    /// Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getActorLikes(input: AppBskyFeedGetActorLikes.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetActorLikes.Output?) {
        let endpoint = "app.bsky.feed.getActorLikes"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetActorLikes.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
