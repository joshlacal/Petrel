import Foundation

// lexicon: 1, id: app.bsky.bookmark.deleteBookmark

public enum AppBskyBookmarkDeleteBookmark {
    public static let typeIdentifier = "app.bsky.bookmark.deleteBookmark"
    public struct Input: ATProtocolCodable {
        public let uri: ATProtocolURI

        // Standard public initializer
        public init(uri: ATProtocolURI) {
            self.uri = uri
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            uri = try container.decode(ATProtocolURI.self, forKey: .uri)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(uri, forKey: .uri)
        }

        private enum CodingKeys: String, CodingKey {
            case uri
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            return map
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case unsupportedCollection = "UnsupportedCollection.The URI to be bookmarked is for an unsupported collection."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.App.Bsky.Bookmark {
    // MARK: - deleteBookmark

    /// Deletes a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func deleteBookmark(
        input: AppBskyBookmarkDeleteBookmark.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.bookmark.deleteBookmark"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode
        return responseCode
    }
}
