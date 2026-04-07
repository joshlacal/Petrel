import Foundation



// lexicon: 1, id: app.bsky.bookmark.deleteBookmark


public struct AppBskyBookmarkDeleteBookmark { 

    public static let typeIdentifier = "app.bsky.bookmark.deleteBookmark"
public struct Input: ATProtocolCodable {
        public let uri: ATProtocolURI

        /// Standard public initializer
        public init(uri: ATProtocolURI) {
            self.uri = uri
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(uri, forKey: .uri)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case uri
        }
    }        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unsupportedCollection = "UnsupportedCollection.The URI to be bookmarked is for an unsupported collection."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}

extension ATProtoClient.App.Bsky.Bookmark {
    // MARK: - deleteBookmark

    /// Deletes a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func deleteBookmark(
        
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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.bookmark.deleteBookmark")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           

