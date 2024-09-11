import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.graph.getList

public enum AppBskyGraphGetList {
    public static let typeIdentifier = "app.bsky.graph.getList"
    public struct Parameters: Parametrizable {
        public let list: ATProtocolURI
        public let limit: Int?
        public let cursor: String?

        public init(
            list: ATProtocolURI,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.list = list
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let list: AppBskyGraphDefs.ListView

        public let items: [AppBskyGraphDefs.ListItemView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            list: AppBskyGraphDefs.ListView,

            items: [AppBskyGraphDefs.ListItemView]
        ) {
            self.cursor = cursor

            self.list = list

            self.items = items
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Gets a 'view' (with additional context) of a specified list.
    func getList(input: AppBskyGraphGetList.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetList.Output?) {
        let endpoint = "/app.bsky.graph.getList"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetList.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
