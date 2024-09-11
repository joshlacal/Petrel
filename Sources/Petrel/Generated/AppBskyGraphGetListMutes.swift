import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.graph.getListMutes

public enum AppBskyGraphGetListMutes {
    public static let typeIdentifier = "app.bsky.graph.getListMutes"
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
    /// Enumerates mod lists that the requesting account (actor) currently has muted. Requires auth.
    func getListMutes(input: AppBskyGraphGetListMutes.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetListMutes.Output?) {
        let endpoint = "/app.bsky.graph.getListMutes"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetListMutes.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
