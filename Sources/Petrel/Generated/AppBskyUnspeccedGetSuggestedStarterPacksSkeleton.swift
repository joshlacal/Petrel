import Foundation

// lexicon: 1, id: app.bsky.unspecced.getSuggestedStarterPacksSkeleton

public enum AppBskyUnspeccedGetSuggestedStarterPacksSkeleton {
    public static let typeIdentifier = "app.bsky.unspecced.getSuggestedStarterPacksSkeleton"
    public struct Parameters: Parametrizable {
        public let viewer: DID?
        public let limit: Int?

        public init(
            viewer: DID? = nil,
            limit: Int? = nil
        ) {
            self.viewer = viewer
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let starterPacks: [ATProtocolURI]

        // Standard public initializer
        public init(
            starterPacks: [ATProtocolURI]

        ) {
            self.starterPacks = starterPacks
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            starterPacks = try container.decode([ATProtocolURI].self, forKey: .starterPacks)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(starterPacks, forKey: .starterPacks)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let starterPacksValue = try (starterPacks as? DAGCBOREncodable)?.toCBORValue() ?? starterPacks
            map = map.adding(key: "starterPacks", value: starterPacksValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case starterPacks
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// Get a skeleton of suggested starterpacks. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedStarterpacks
    func getSuggestedStarterPacksSkeleton(input: AppBskyUnspeccedGetSuggestedStarterPacksSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestedStarterPacksSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestedStarterPacksSkeleton"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetSuggestedStarterPacksSkeleton.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
