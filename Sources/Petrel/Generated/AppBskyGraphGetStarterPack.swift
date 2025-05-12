import Foundation

// lexicon: 1, id: app.bsky.graph.getStarterPack

public enum AppBskyGraphGetStarterPack {
    public static let typeIdentifier = "app.bsky.graph.getStarterPack"
    public struct Parameters: Parametrizable {
        public let starterPack: ATProtocolURI

        public init(
            starterPack: ATProtocolURI
        ) {
            self.starterPack = starterPack
        }
    }

    public struct Output: ATProtocolCodable {
        public let starterPack: AppBskyGraphDefs.StarterPackView

        // Standard public initializer
        public init(
            starterPack: AppBskyGraphDefs.StarterPackView

        ) {
            self.starterPack = starterPack
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            starterPack = try container.decode(AppBskyGraphDefs.StarterPackView.self, forKey: .starterPack)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(starterPack, forKey: .starterPack)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let starterPackValue = try starterPack.toCBORValue()
            map = map.adding(key: "starterPack", value: starterPackValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case starterPack
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getStarterPack

    /// Gets a view of a starter pack.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getStarterPack(input: AppBskyGraphGetStarterPack.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetStarterPack.Output?) {
        let endpoint = "app.bsky.graph.getStarterPack"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetStarterPack.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
