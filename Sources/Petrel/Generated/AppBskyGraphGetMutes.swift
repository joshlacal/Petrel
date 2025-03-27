import Foundation

// lexicon: 1, id: app.bsky.graph.getMutes

public enum AppBskyGraphGetMutes {
    public static let typeIdentifier = "app.bsky.graph.getMutes"
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

        public let mutes: [AppBskyActorDefs.ProfileView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            mutes: [AppBskyActorDefs.ProfileView]

        ) {
            self.cursor = cursor

            self.mutes = mutes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            mutes = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .mutes)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(mutes, forKey: .mutes)
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case mutes
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.
    func getMutes(input: AppBskyGraphGetMutes.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetMutes.Output?) {
        let endpoint = "app.bsky.graph.getMutes"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetMutes.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
