import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.graph.getListBlocks

public enum AppBskyGraphGetListBlocks {
    public static let typeIdentifier = "app.bsky.graph.getListBlocks"
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
    /// Get mod lists that the requesting account (actor) is blocking. Requires auth.
    func getListBlocks(input: AppBskyGraphGetListBlocks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetListBlocks.Output?) {
        let endpoint = "app.bsky.graph.getListBlocks"

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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyGraphGetListBlocks.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
