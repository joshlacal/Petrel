import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.graph.unmuteThread

public enum AppBskyGraphUnmuteThread {
    public static let typeIdentifier = "app.bsky.graph.unmuteThread"
    public struct Input: ATProtocolCodable {
        public let root: ATProtocolURI

        // Standard public initializer
        public init(root: ATProtocolURI) {
            self.root = root
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Unmutes the specified thread. Requires auth.
    func unmuteThread(
        input: AppBskyGraphUnmuteThread.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/app.bsky.graph.unmuteThread"

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
