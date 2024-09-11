import Foundation
internal import ZippyJSON

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
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Gets a view of a starter pack.
    func getStarterPack(input: AppBskyGraphGetStarterPack.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetStarterPack.Output?) {
        let endpoint = "/app.bsky.graph.getStarterPack"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyGraphGetStarterPack.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
