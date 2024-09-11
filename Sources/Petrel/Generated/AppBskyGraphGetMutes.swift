import Foundation
internal import ZippyJSON

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
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.
    func getMutes(input: AppBskyGraphGetMutes.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetMutes.Output?) {
        let endpoint = "/app.bsky.graph.getMutes"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetMutes.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
