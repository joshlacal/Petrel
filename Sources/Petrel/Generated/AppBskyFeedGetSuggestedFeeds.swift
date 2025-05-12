import Foundation



// lexicon: 1, id: app.bsky.feed.getSuggestedFeeds


public struct AppBskyFeedGetSuggestedFeeds { 

    public static let typeIdentifier = "app.bsky.feed.getSuggestedFeeds"    
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
        
        public let feeds: [AppBskyFeedDefs.GeneratorView]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            feeds: [AppBskyFeedDefs.GeneratorView]
            
            
        ) {
            
            self.cursor = cursor
            
            self.feeds = feeds
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.feeds = try container.decode([AppBskyFeedDefs.GeneratorView].self, forKey: .feeds)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(feeds, forKey: .feeds)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let feedsValue = try feeds.toCBORValue()
            map = map.adding(key: "feeds", value: feedsValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case feeds
            
        }
    }




}


extension ATProtoClient.App.Bsky.Feed {
    // MARK: - getSuggestedFeeds

    /// Get a list of suggested feeds (feed generators) for the requesting account.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getSuggestedFeeds(input: AppBskyFeedGetSuggestedFeeds.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetSuggestedFeeds.Output?) {
        let endpoint = "app.bsky.feed.getSuggestedFeeds"

        
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
        let decodedData = try? decoder.decode(AppBskyFeedGetSuggestedFeeds.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
