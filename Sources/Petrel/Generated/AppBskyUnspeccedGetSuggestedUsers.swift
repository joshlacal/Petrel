import Foundation

// lexicon: 1, id: app.bsky.unspecced.getSuggestedUsers

public enum AppBskyUnspeccedGetSuggestedUsers {
    public static let typeIdentifier = "app.bsky.unspecced.getSuggestedUsers"
    public struct Parameters: Parametrizable {
        public let category: String?
        public let limit: Int?

        public init(
            category: String? = nil,
            limit: Int? = nil
        ) {
            self.category = category
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let actors: [AppBskyActorDefs.ProfileViewBasic]

        // Standard public initializer
        public init(
            actors: [AppBskyActorDefs.ProfileViewBasic]

        ) {
            self.actors = actors
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            actors = try container.decode([AppBskyActorDefs.ProfileViewBasic].self, forKey: .actors)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(actors, forKey: .actors)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let actorsValue = try (actors as? DAGCBOREncodable)?.toCBORValue() ?? actors
            map = map.adding(key: "actors", value: actorsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case actors
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// Get a list of suggested users
    func getSuggestedUsers(input: AppBskyUnspeccedGetSuggestedUsers.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestedUsers.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestedUsers"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetSuggestedUsers.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
