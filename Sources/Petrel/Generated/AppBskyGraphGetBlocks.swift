import Foundation

// lexicon: 1, id: app.bsky.graph.getBlocks

public enum AppBskyGraphGetBlocks {
    public static let typeIdentifier = "app.bsky.graph.getBlocks"
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

        public let blocks: [AppBskyActorDefs.ProfileView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            blocks: [AppBskyActorDefs.ProfileView]

        ) {
            self.cursor = cursor

            self.blocks = blocks
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Enumerates which accounts the requesting account is currently blocking. Requires auth.
    func getBlocks(input: AppBskyGraphGetBlocks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetBlocks.Output?) {
        let endpoint = "app.bsky.graph.getBlocks"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetBlocks.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
