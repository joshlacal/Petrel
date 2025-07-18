import Foundation

// lexicon: 1, id: app.bsky.graph.getKnownFollowers

public enum AppBskyGraphGetKnownFollowers {
    public static let typeIdentifier = "app.bsky.graph.getKnownFollowers"
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
        public let subject: AppBskyActorDefs.ProfileView

        public let cursor: String?

        public let followers: [AppBskyActorDefs.ProfileView]

        // Standard public initializer
        public init(
            subject: AppBskyActorDefs.ProfileView,

            cursor: String? = nil,

            followers: [AppBskyActorDefs.ProfileView]

        ) {
            self.subject = subject

            self.cursor = cursor

            self.followers = followers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            subject = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .subject)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            followers = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .followers)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(subject, forKey: .subject)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(followers, forKey: .followers)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let followersValue = try followers.toCBORValue()
            map = map.adding(key: "followers", value: followersValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case subject
            case cursor
            case followers
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getKnownFollowers

    /// Enumerates accounts which follow a specified account (actor) and are followed by the viewer.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getKnownFollowers(input: AppBskyGraphGetKnownFollowers.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetKnownFollowers.Output?) {
        let endpoint = "app.bsky.graph.getKnownFollowers"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetKnownFollowers.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
