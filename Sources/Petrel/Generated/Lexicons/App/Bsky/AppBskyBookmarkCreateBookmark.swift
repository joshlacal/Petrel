import Foundation

// lexicon: 1, id: app.bsky.bookmark.createBookmark

public enum AppBskyBookmarkCreateBookmark {
    public static let typeIdentifier = "app.bsky.bookmark.createBookmark"
    public struct Input: ATProtocolCodable {
        public let uri: ATProtocolURI
        public let cid: CID

        /// Standard public initializer
        public init(uri: ATProtocolURI, cid: CID) {
            self.uri = uri
            self.cid = cid
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            cid = try container.decode(CID.self, forKey: .cid)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)
        }

        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)

            return map
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case unsupportedCollection = "UnsupportedCollection.The URI to be bookmarked is for an unsupported collection."
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.App.Bsky.Bookmark {
    // MARK: - createBookmark

    /// Creates a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func createBookmark(
        input: AppBskyBookmarkCreateBookmark.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.bookmark.createBookmark"

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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.bookmark.createBookmark")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        return response.statusCode
    }
}
