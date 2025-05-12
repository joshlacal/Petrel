import Foundation



// lexicon: 1, id: app.bsky.unspecced.getSuggestedFeedsSkeleton


public struct AppBskyUnspeccedGetSuggestedFeedsSkeleton { 

    public static let typeIdentifier = "app.bsky.unspecced.getSuggestedFeedsSkeleton"    
public struct Parameters: Parametrizable {
        public let viewer: DID?
        public let limit: Int?
        
        public init(
            viewer: DID? = nil, 
            limit: Int? = nil
            ) {
            self.viewer = viewer
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let feeds: [ATProtocolURI]
        
        
        
        // Standard public initializer
        public init(
            
            feeds: [ATProtocolURI]
            
            
        ) {
            
            self.feeds = feeds
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.feeds = try container.decode([ATProtocolURI].self, forKey: .feeds)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(feeds, forKey: .feeds)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let feedsValue = try feeds.toCBORValue()
            map = map.adding(key: "feeds", value: feedsValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case feeds
            
        }
    }




}


extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getSuggestedFeedsSkeleton

    /// Get a skeleton of suggested feeds. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedFeeds
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getSuggestedFeedsSkeleton(input: AppBskyUnspeccedGetSuggestedFeedsSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestedFeedsSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestedFeedsSkeleton"

        
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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetSuggestedFeedsSkeleton.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
