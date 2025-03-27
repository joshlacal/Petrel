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

        private enum CodingKeys: String, CodingKey {
            case starterPack
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Gets a view of a starter pack.
    func getStarterPack(input: AppBskyGraphGetStarterPack.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetStarterPack.Output?) {
        let endpoint = "app.bsky.graph.getStarterPack"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetStarterPack.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
