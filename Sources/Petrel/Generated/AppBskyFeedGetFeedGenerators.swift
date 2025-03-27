import Foundation



// lexicon: 1, id: app.bsky.feed.getFeedGenerators


public struct AppBskyFeedGetFeedGenerators { 

    public static let typeIdentifier = "app.bsky.feed.getFeedGenerators"    
public struct Parameters: Parametrizable {
        public let feeds: [ATProtocolURI]
        
        public init(
            feeds: [ATProtocolURI]
            ) {
            self.feeds = feeds
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let feeds: [AppBskyFeedDefs.GeneratorView]
        
        
        
        // Standard public initializer
        public init(
            
            feeds: [AppBskyFeedDefs.GeneratorView]
            
            
        ) {
            
            self.feeds = feeds
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.feeds = try container.decode([AppBskyFeedDefs.GeneratorView].self, forKey: .feeds)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(feeds, forKey: .feeds)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case feeds
            
        }
    }




}


extension ATProtoClient.App.Bsky.Feed {
    /// Get information about a list of feed generators.
    public func getFeedGenerators(input: AppBskyFeedGetFeedGenerators.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetFeedGenerators.Output?) {
        let endpoint = "app.bsky.feed.getFeedGenerators"
        
        
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
        let decodedData = try? decoder.decode(AppBskyFeedGetFeedGenerators.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
