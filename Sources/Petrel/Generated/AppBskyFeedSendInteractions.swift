import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.feed.sendInteractions

public enum AppBskyFeedSendInteractions {
    public static let typeIdentifier = "app.bsky.feed.sendInteractions"
    public struct Input: ATProtocolCodable {
        public let interactions: [AppBskyFeedDefs.Interaction]

        // Standard public initializer
        public init(interactions: [AppBskyFeedDefs.Interaction]) {
            self.interactions = interactions
        }
    }

    public struct Output: ATProtocolCodable {
        // Standard public initializer
        public init() {}
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Send information about interactions with feed items back to the feed generator that served them.
    func sendInteractions(
        input: AppBskyFeedSendInteractions.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: AppBskyFeedSendInteractions.Output?) {
        let endpoint = "/app.bsky.feed.sendInteractions"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(AppBskyFeedSendInteractions.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
