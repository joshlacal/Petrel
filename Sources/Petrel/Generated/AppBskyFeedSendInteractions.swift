import Foundation
import ZippyJSON

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
        public let data: Data

        // Standard public initializer
        public init(
            data: Data

        ) {
            self.data = data
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Send information about interactions with feed items back to the feed generator that served them.
    func sendInteractions(
        input: AppBskyFeedSendInteractions.Input

    ) async throws -> (responseCode: Int, data: AppBskyFeedSendInteractions.Output?) {
        let endpoint = "app.bsky.feed.sendInteractions"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedSendInteractions.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
