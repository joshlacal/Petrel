import Foundation
internal import ZippyJSON

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

        // Standard public initializer
        public init(
            cursor: String? = nil,

            actors: [AppBskyActorDefs.ProfileView]
        ) {
            self.cursor = cursor

            self.actors = actors
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    /// Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.
    func getSuggestions(input: AppBskyActorGetSuggestions.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetSuggestions.Output?) {
        let endpoint = "/app.bsky.actor.getSuggestions"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyActorGetSuggestions.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
