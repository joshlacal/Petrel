import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.graph.getFollows

public enum AppBskyGraphGetFollows {
    public static let typeIdentifier = "app.bsky.graph.getFollows"
    public struct Parameters: Parametrizable {
        public let actor: String
        public let limit: Int?
        public let cursor: String?

        public init(
            actor: String,
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
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Enumerates accounts which a specified account (actor) follows.
    func getFollows(input: AppBskyGraphGetFollows.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetFollows.Output?) {
        let endpoint = "/app.bsky.graph.getFollows"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetFollows.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
