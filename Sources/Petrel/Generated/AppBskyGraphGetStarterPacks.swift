import Foundation
internal import ZippyJSON

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
        let endpoint = "/app.bsky.graph.getStarterPacks"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetStarterPacks.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
