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


extension ATProtoClient.App.Bsky.Feed {
    // MARK: - getFeedGenerators

    /// Get information about a list of feed generators.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getFeedGenerators(input: AppBskyFeedGetFeedGenerators.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetFeedGenerators.Output?) {
        let endpoint = "app.bsky.feed.getFeedGenerators"

        
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

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyFeedGetFeedGenerators.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.feed.getFeedGenerators: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
