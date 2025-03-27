import Foundation

// lexicon: 1, id: app.bsky.feed.getRepostedBy

public enum AppBskyFeedGetRepostedBy {
    public static let typeIdentifier = "app.bsky.feed.getRepostedBy"
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

        public let repostedBy: [AppBskyActorDefs.ProfileView]

        // Standard public initializer
        public init(
            uri: ATProtocolURI,

            cid: String? = nil,

            cursor: String? = nil,

            repostedBy: [AppBskyActorDefs.ProfileView]

        ) {
            self.uri = uri

            self.cid = cid

            self.cursor = cursor

            self.repostedBy = repostedBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            cid = try container.decodeIfPresent(String.self, forKey: .cid)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            repostedBy = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .repostedBy)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(uri, forKey: .uri)

            if let value = cid {
                try container.encode(value, forKey: .cid)
            }

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(repostedBy, forKey: .repostedBy)
        }

        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
            case cursor
            case repostedBy
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get a list of reposts for a given post.
    func getRepostedBy(input: AppBskyFeedGetRepostedBy.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetRepostedBy.Output?) {
        let endpoint = "app.bsky.feed.getRepostedBy"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetRepostedBy.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
