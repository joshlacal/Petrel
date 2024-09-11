import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.graph.unmuteActorList

public enum AppBskyGraphUnmuteActorList {
    public static let typeIdentifier = "app.bsky.graph.unmuteActorList"
    public struct Input: ATProtocolCodable {
        public let list: ATProtocolURI

        // Standard public initializer
        public init(list: ATProtocolURI) {
            self.list = list
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Unmutes the specified list of accounts. Requires auth.
    func unmuteActorList(
        input: AppBskyGraphUnmuteActorList.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/app.bsky.graph.unmuteActorList"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        return responseCode
    }
}
