import Foundation

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
        input: AppBskyGraphUnmuteThread.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.graph.unmuteThread"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
