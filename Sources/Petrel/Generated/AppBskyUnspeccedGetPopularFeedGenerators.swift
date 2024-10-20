import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.unspecced.getPopularFeedGenerators


public struct AppBskyUnspeccedGetPopularFeedGenerators { 

    public static let typeIdentifier = "app.bsky.unspecced.getPopularFeedGenerators"    
public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        public let query: String?
        
        public init(
            limit: Int? = nil, 
            cursor: String? = nil, 
            query: String? = nil
            ) {
            self.limit = limit
            self.cursor = cursor
            self.query = query
            
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


extension ATProtoClient.App.Bsky.Unspecced {
    /// An unspecced view of globally popular feed generators.
    public func getPopularFeedGenerators(input: AppBskyUnspeccedGetPopularFeedGenerators.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetPopularFeedGenerators.Output?) {
        let endpoint = "app.bsky.unspecced.getPopularFeedGenerators"
        
        
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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetPopularFeedGenerators.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
