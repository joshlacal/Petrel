import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.feed.getRepostedBy

public enum AppBskyFeedGetRepostedBy {
    public static let typeIdentifier = "app.bsky.feed.getRepostedBy"
    public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let cid: String?
        public let limit: Int?
        public let cursor: String?

        public init(
            uri: ATProtocolURI,
            cid: String? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.uri = uri
            self.cid = cid
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let uri: ATProtocolURI

        public let cid: String?

        public let cursor: String?

        public let repostedBy: [AppBskyActorDefs.ProfileView]

        // Standard public initializer
        public init(
            uri: ATProtocolURI,

            cid: String? = nil,

            cursor: String? = nil,

            repostedBy: [AppBskyActorDefs.ProfileView]
        ) {
            self.uri = uri

            self.cid = cid

            self.cursor = cursor

            self.repostedBy = repostedBy
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get a list of reposts for a given post.
    func getRepostedBy(input: AppBskyFeedGetRepostedBy.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetRepostedBy.Output?) {
        let endpoint = "/app.bsky.feed.getRepostedBy"

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
        let decodedData = try? decoder.decode(AppBskyFeedGetRepostedBy.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
