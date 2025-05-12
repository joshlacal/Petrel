import Foundation

// lexicon: 1, id: app.bsky.unspecced.getSuggestedUsersSkeleton

public enum AppBskyUnspeccedGetSuggestedUsersSkeleton {
    public static let typeIdentifier = "app.bsky.unspecced.getSuggestedUsersSkeleton"
    public struct Parameters: Parametrizable {
        public let viewer: DID?
        public let category: String?
        public let limit: Int?

        public init(
            viewer: DID? = nil,
            category: String? = nil,
            limit: Int? = nil
        ) {
            self.viewer = viewer
            self.category = category
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let dids: [DID]

        // Standard public initializer
        public init(
            dids: [DID]

        ) {
            self.dids = dids
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            dids = try container.decode([DID].self, forKey: .dids)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(dids, forKey: .dids)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let didsValue = try dids.toCBORValue()
            map = map.adding(key: "dids", value: didsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case dids
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getSuggestedUsersSkeleton

    /// Get a skeleton of suggested users. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsers
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getSuggestedUsersSkeleton(input: AppBskyUnspeccedGetSuggestedUsersSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestedUsersSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestedUsersSkeleton"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetSuggestedUsersSkeleton.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
