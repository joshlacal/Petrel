import Foundation

// lexicon: 1, id: app.bsky.unspecced.getTrendsSkeleton

public enum AppBskyUnspeccedGetTrendsSkeleton {
    public static let typeIdentifier = "app.bsky.unspecced.getTrendsSkeleton"
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
        public let trends: [AppBskyUnspeccedDefs.SkeletonTrend]

        // Standard public initializer
        public init(
            trends: [AppBskyUnspeccedDefs.SkeletonTrend]

        ) {
            self.trends = trends
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            trends = try container.decode([AppBskyUnspeccedDefs.SkeletonTrend].self, forKey: .trends)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(trends, forKey: .trends)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let trendsValue = try trends.toCBORValue()
            map = map.adding(key: "trends", value: trendsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case trends
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getTrendsSkeleton

    /// Get the skeleton of trends on the network. Intended to be called and then hydrated through app.bsky.unspecced.getTrends
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getTrendsSkeleton(input: AppBskyUnspeccedGetTrendsSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetTrendsSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.getTrendsSkeleton"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetTrendsSkeleton.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
