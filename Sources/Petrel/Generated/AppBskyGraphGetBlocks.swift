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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            blocks = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .blocks)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(blocks, forKey: .blocks)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let blocksValue = try blocks.toCBORValue()
            map = map.adding(key: "blocks", value: blocksValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case blocks
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getBlocks

    /// Enumerates which accounts the requesting account is currently blocking. Requires auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getBlocks(input: AppBskyGraphGetBlocks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetBlocks.Output?) {
        let endpoint = "app.bsky.graph.getBlocks"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyGraphGetBlocks.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
