import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.graph.getStarterPacks

public enum AppBskyGraphGetStarterPacks {
    public static let typeIdentifier = "app.bsky.graph.getStarterPacks"
    public struct Parameters: Parametrizable {
        public let uris: [ATProtocolURI]

        public init(
            uris: [ATProtocolURI]
        ) {
            self.uris = uris
        }
    }

    public struct Output: ATProtocolCodable {
        public let starterPacks: [AppBskyGraphDefs.StarterPackViewBasic]

        // Standard public initializer
        public init(
            starterPacks: [AppBskyGraphDefs.StarterPackViewBasic]

        ) {
            self.starterPacks = starterPacks
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Get views for a list of starter packs.
    func getStarterPacks(input: AppBskyGraphGetStarterPacks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetStarterPacks.Output?) {
        let endpoint = "app.bsky.graph.getStarterPacks"

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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyGraphGetStarterPacks.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
