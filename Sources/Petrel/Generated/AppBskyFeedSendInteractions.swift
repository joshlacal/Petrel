import Foundation

// lexicon: 1, id: app.bsky.feed.sendInteractions

public enum AppBskyFeedSendInteractions {
    public static let typeIdentifier = "app.bsky.feed.sendInteractions"
    public struct Input: ATProtocolCodable {
        public let interactions: [AppBskyFeedDefs.Interaction]

        // Standard public initializer
        public init(interactions: [AppBskyFeedDefs.Interaction]) {
            self.interactions = interactions
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            interactions = try container.decode([AppBskyFeedDefs.Interaction].self, forKey: .interactions)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(interactions, forKey: .interactions)
        }

        private enum CodingKeys: String, CodingKey {
            case interactions
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let interactionsValue = try interactions.toCBORValue()
            map = map.adding(key: "interactions", value: interactionsValue)

            return map
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let data = try container.decode(Data.self, forKey: .data)
            self.data = data
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(data, forKey: .data)
        }

        public func toCBORValue() throws -> Any {
            return data
        }

        private enum CodingKeys: String, CodingKey {
            case data
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    // MARK: - sendInteractions

    /// Send information about interactions with feed items back to the feed generator that served them.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func sendInteractions(
        input: AppBskyFeedSendInteractions.Input

    ) async throws -> (responseCode: Int, data: AppBskyFeedSendInteractions.Output?) {
        let endpoint = "app.bsky.feed.sendInteractions"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedSendInteractions.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
