import Foundation



// lexicon: 1, id: app.bsky.feed.getActorLikes


public struct AppBskyFeedGetActorLikes { 

    public static let typeIdentifier = "app.bsky.feed.getActorLikes"    
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
        
        public let feed: [AppBskyFeedDefs.FeedViewPost]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            feed: [AppBskyFeedDefs.FeedViewPost]
            
            
        ) {
            
            self.cursor = cursor
            
            self.feed = feed
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.feed = try container.decode([AppBskyFeedDefs.FeedViewPost].self, forKey: .feed)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            if let value = cursor {
                
                try container.encode(value, forKey: .cursor)
                
            }
            
            
            try container.encode(feed, forKey: .feed)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case feed
            
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
    /// Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.
    public func getActorLikes(input: AppBskyFeedGetActorLikes.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetActorLikes.Output?) {
        let endpoint = "app.bsky.feed.getActorLikes"
        
        
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
        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedGetActorLikes.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
