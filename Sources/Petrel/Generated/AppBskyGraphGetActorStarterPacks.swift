import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.graph.getActorStarterPacks

public enum AppBskyGraphGetActorStarterPacks {
    public static let typeIdentifier = "app.bsky.graph.getActorStarterPacks"
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
        public let cursor: String?

        public let starterPacks: [AppBskyGraphDefs.StarterPackViewBasic]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            starterPacks: [AppBskyGraphDefs.StarterPackViewBasic]
        ) {
            self.cursor = cursor

            self.starterPacks = starterPacks
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Get a list of starter packs created by the actor.
    func getActorStarterPacks(input: AppBskyGraphGetActorStarterPacks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetActorStarterPacks.Output?) {
        let endpoint = "/app.bsky.graph.getActorStarterPacks"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetActorStarterPacks.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
