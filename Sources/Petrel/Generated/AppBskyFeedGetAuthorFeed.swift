import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.feed.getAuthorFeed


public struct AppBskyFeedGetAuthorFeed { 

    public static let typeIdentifier = "app.bsky.feed.getAuthorFeed"    
public struct Parameters: Parametrizable {
        public let actor: String
        public let limit: Int?
        public let cursor: String?
        public let filter: String?
        
        public init(
            actor: String, 
            limit: Int? = nil, 
            cursor: String? = nil, 
            filter: String? = nil
            ) {
            self.actor = actor
            self.limit = limit
            self.cursor = cursor
            self.filter = filter
            
        }
    }    
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let feed: [AppBskyFeedDefs.FeedViewPost]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            feed: [AppBskyFeedDefs.FeedViewPost]
            
            
        ) {
            
            self.cursor = cursor
            
            self.feed = feed
            
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case blockedActor = "BlockedActor."
                case blockedByActor = "BlockedByActor."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.App.Bsky.Feed {
    /// Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.
    public func getAuthorFeed(input: AppBskyFeedGetAuthorFeed.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetAuthorFeed.Output?) {
        let endpoint = "app.bsky.feed.getAuthorFeed"
        
        
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
        let decodedData = try? decoder.decode(AppBskyFeedGetAuthorFeed.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
