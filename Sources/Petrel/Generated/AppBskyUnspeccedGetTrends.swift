import Foundation

// lexicon: 1, id: app.bsky.unspecced.getTrends

public enum AppBskyUnspeccedGetTrends {
    public static let typeIdentifier = "app.bsky.unspecced.getTrends"
    public struct Parameters: Parametrizable {
        public let limit: Int?

        public init(
            limit: Int? = nil
        ) {
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let trends: [AppBskyUnspeccedDefs.TrendView]

        // Standard public initializer
        public init(
            trends: [AppBskyUnspeccedDefs.TrendView]

        ) {
            self.trends = trends
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            trends = try container.decode([AppBskyUnspeccedDefs.TrendView].self, forKey: .trends)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(trends, forKey: .trends)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let trendsValue = try (trends as? DAGCBOREncodable)?.toCBORValue() ?? trends
            map = map.adding(key: "trends", value: trendsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case trends
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// Get the current trends on the network
    func getTrends(input: AppBskyUnspeccedGetTrends.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetTrends.Output?) {
        let endpoint = "app.bsky.unspecced.getTrends"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetTrends.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
