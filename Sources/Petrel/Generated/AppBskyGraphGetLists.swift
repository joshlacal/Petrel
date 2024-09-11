import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.graph.getLists

public enum AppBskyGraphGetLists {
    public static let typeIdentifier = "app.bsky.graph.getLists"
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

        public let lists: [AppBskyGraphDefs.ListView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            lists: [AppBskyGraphDefs.ListView]
        ) {
            self.cursor = cursor

            self.lists = lists
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Enumerates the lists created by a specified account (actor).
    func getLists(input: AppBskyGraphGetLists.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetLists.Output?) {
        let endpoint = "/app.bsky.graph.getLists"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetLists.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
