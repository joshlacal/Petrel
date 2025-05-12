import Foundation

// lexicon: 1, id: app.bsky.graph.getFollows

public enum AppBskyGraphGetFollows {
    public static let typeIdentifier = "app.bsky.graph.getFollows"
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

        public let follows: [AppBskyActorDefs.ProfileView]

        // Standard public initializer
        public init(
            subject: AppBskyActorDefs.ProfileView,

            cursor: String? = nil,

            follows: [AppBskyActorDefs.ProfileView]

        ) {
            self.subject = subject

            self.cursor = cursor

            self.follows = follows
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            subject = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .subject)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            follows = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .follows)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(subject, forKey: .subject)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(follows, forKey: .follows)
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

            let followsValue = try follows.toCBORValue()
            map = map.adding(key: "follows", value: followsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case subject
            case cursor
            case follows
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getFollows

    /// Enumerates accounts which a specified account (actor) follows.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getFollows(input: AppBskyGraphGetFollows.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetFollows.Output?) {
        let endpoint = "app.bsky.graph.getFollows"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetFollows.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
