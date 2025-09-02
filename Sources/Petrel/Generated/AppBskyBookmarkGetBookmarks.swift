import Foundation

// lexicon: 1, id: app.bsky.bookmark.getBookmarks

public enum AppBskyBookmarkGetBookmarks {
    public static let typeIdentifier = "app.bsky.bookmark.getBookmarks"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let bookmarks: [AppBskyBookmarkDefs.BookmarkView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            bookmarks: [AppBskyBookmarkDefs.BookmarkView]

        ) {
            self.cursor = cursor

            self.bookmarks = bookmarks
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            bookmarks = try container.decode([AppBskyBookmarkDefs.BookmarkView].self, forKey: .bookmarks)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(bookmarks, forKey: .bookmarks)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let bookmarksValue = try bookmarks.toCBORValue()
            map = map.adding(key: "bookmarks", value: bookmarksValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case bookmarks
        }
    }
}

public extension ATProtoClient.App.Bsky.Bookmark {
    // MARK: - getBookmarks

    /// Gets views of records bookmarked by the authenticated user. Requires authentication.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getBookmarks(input: AppBskyBookmarkGetBookmarks.Parameters) async throws -> (responseCode: Int, data: AppBskyBookmarkGetBookmarks.Output?) {
        let endpoint = "app.bsky.bookmark.getBookmarks"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
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
        let decodedData = try? decoder.decode(AppBskyBookmarkGetBookmarks.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
