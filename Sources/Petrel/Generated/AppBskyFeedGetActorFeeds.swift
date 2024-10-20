import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.feed.getActorFeeds


public struct AppBskyFeedGetActorFeeds { 

    public static let typeIdentifier = "app.bsky.feed.getActorFeeds"    
public struct Parameters: Parametrizable {
        public let actor: String
        public let limit: Int?
        public let cursor: String?
        
        public init(
            actor: String, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.actor = actor
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
    }




}


extension ATProtoClient.App.Bsky.Feed {
    /// Get a list of feeds (feed generator records) created by the actor (in the actor's repo).
    public func getActorFeeds(input: AppBskyFeedGetActorFeeds.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetActorFeeds.Output?) {
        let endpoint = "app.bsky.feed.getActorFeeds"
        
        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
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
        
        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedGetActorFeeds.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
