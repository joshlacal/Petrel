import Foundation

// lexicon: 1, id: app.bsky.actor.getSuggestions

public enum AppBskyActorGetSuggestions {
    public static let typeIdentifier = "app.bsky.actor.getSuggestions"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let actors: [AppBskyActorDefs.ProfileView]

        public let recId: Int?

        // Standard public initializer
        public init(
            cursor: String? = nil,

            actors: [AppBskyActorDefs.ProfileView],

            recId: Int? = nil

        ) {
            self.cursor = cursor

            self.actors = actors

            self.recId = recId
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    /// Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.
    func getSuggestions(input: AppBskyActorGetSuggestions.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetSuggestions.Output?) {
        let endpoint = "app.bsky.actor.getSuggestions"

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
        let decodedData = try? decoder.decode(AppBskyActorGetSuggestions.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
