import Foundation

// lexicon: 1, id: app.bsky.feed.getFeedGenerator

public enum AppBskyFeedGetFeedGenerator {
    public static let typeIdentifier = "app.bsky.feed.getFeedGenerator"
    public struct Parameters: Parametrizable {
        public let feed: ATProtocolURI

        public init(
            feed: ATProtocolURI
        ) {
            self.feed = feed
        }
    }

    public struct Output: ATProtocolCodable {
        public let view: AppBskyFeedDefs.GeneratorView

        public let isOnline: Bool

        public let isValid: Bool

        // Standard public initializer
        public init(
            view: AppBskyFeedDefs.GeneratorView,

            isOnline: Bool,

            isValid: Bool

        ) {
            self.view = view

            self.isOnline = isOnline

            self.isValid = isValid
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            view = try container.decode(AppBskyFeedDefs.GeneratorView.self, forKey: .view)

            isOnline = try container.decode(Bool.self, forKey: .isOnline)

            isValid = try container.decode(Bool.self, forKey: .isValid)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(view, forKey: .view)

            try container.encode(isOnline, forKey: .isOnline)

            try container.encode(isValid, forKey: .isValid)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let viewValue = try view.toCBORValue()
            map = map.adding(key: "view", value: viewValue)

            let isOnlineValue = try isOnline.toCBORValue()
            map = map.adding(key: "isOnline", value: isOnlineValue)

            let isValidValue = try isValid.toCBORValue()
            map = map.adding(key: "isValid", value: isValidValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case view
            case isOnline
            case isValid
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    // MARK: - getFeedGenerator

    /// Get information about a feed generator. Implemented by AppView.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getFeedGenerator(input: AppBskyFeedGetFeedGenerator.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetFeedGenerator.Output?) {
        let endpoint = "app.bsky.feed.getFeedGenerator"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.feed.getFeedGenerator")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyFeedGetFeedGenerator.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.feed.getFeedGenerator: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
