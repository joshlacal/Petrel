import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.graph.muteThread

public enum AppBskyGraphMuteThread {
    public static let typeIdentifier = "app.bsky.graph.muteThread"
    public struct Input: ATProtocolCodable {
        public let root: ATProtocolURI

        // Standard public initializer
        public init(root: ATProtocolURI) {
            self.root = root
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Mutes a thread preventing notifications from the thread and any of its children. Mutes are private in Bluesky. Requires auth.
    func muteThread(
        input: AppBskyGraphMuteThread.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.graph.muteThread"

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
