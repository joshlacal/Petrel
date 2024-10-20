import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.graph.muteActorList

public enum AppBskyGraphMuteActorList {
    public static let typeIdentifier = "app.bsky.graph.muteActorList"
    public struct Input: ATProtocolCodable {
        public let list: ATProtocolURI

        // Standard public initializer
        public init(list: ATProtocolURI) {
            self.list = list
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Creates a mute relationship for the specified list of accounts. Mutes are private in Bluesky. Requires auth.
    func muteActorList(
        input: AppBskyGraphMuteActorList.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.graph.muteActorList"

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
