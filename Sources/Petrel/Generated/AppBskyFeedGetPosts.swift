import Foundation



// lexicon: 1, id: app.bsky.feed.getPosts


public struct AppBskyFeedGetPosts { 

    public static let typeIdentifier = "app.bsky.feed.getPosts"    
public struct Parameters: Parametrizable {
        public let uris: [ATProtocolURI]
        
        public init(
            uris: [ATProtocolURI]
            ) {
            self.uris = uris
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let posts: [AppBskyFeedDefs.PostView]
        
        
        
        // Standard public initializer
        public init(
            
            posts: [AppBskyFeedDefs.PostView]
            
            
        ) {
            
            self.posts = posts
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.posts = try container.decode([AppBskyFeedDefs.PostView].self, forKey: .posts)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(posts, forKey: .posts)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case posts
            
        }
    }




}


extension ATProtoClient.App.Bsky.Feed {
    /// Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed skeleton'.
    public func getPosts(input: AppBskyFeedGetPosts.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetPosts.Output?) {
        let endpoint = "app.bsky.feed.getPosts"
        
        
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
        let decodedData = try? decoder.decode(AppBskyFeedGetPosts.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
