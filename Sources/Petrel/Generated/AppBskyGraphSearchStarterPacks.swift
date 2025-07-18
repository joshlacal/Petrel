import Foundation

// lexicon: 1, id: app.bsky.graph.searchStarterPacks

public enum AppBskyGraphSearchStarterPacks {
    public static let typeIdentifier = "app.bsky.graph.searchStarterPacks"
    public struct Parameters: Parametrizable {
        public let q: String
        public let limit: Int?
        public let cursor: String?

        public init(
            q: String,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.q = q
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            starterPacks = try container.decode([AppBskyGraphDefs.StarterPackViewBasic].self, forKey: .starterPacks)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(starterPacks, forKey: .starterPacks)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let starterPacksValue = try starterPacks.toCBORValue()
            map = map.adding(key: "starterPacks", value: starterPacksValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case starterPacks
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    // MARK: - searchStarterPacks

    /// Find starter packs matching search criteria. Does not require auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func searchStarterPacks(input: AppBskyGraphSearchStarterPacks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphSearchStarterPacks.Output?) {
        let endpoint = "app.bsky.graph.searchStarterPacks"

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
        let decodedData = try? decoder.decode(AppBskyGraphSearchStarterPacks.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
