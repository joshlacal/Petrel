import Foundation



// lexicon: 1, id: app.bsky.unspecced.getTrendingTopics


public struct AppBskyUnspeccedGetTrendingTopics { 

    public static let typeIdentifier = "app.bsky.unspecced.getTrendingTopics"    
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
        
        
        public let topics: [AppBskyUnspeccedDefs.TrendingTopic]
        
        public let suggested: [AppBskyUnspeccedDefs.TrendingTopic]
        
        
        
        // Standard public initializer
        public init(
            
            topics: [AppBskyUnspeccedDefs.TrendingTopic],
            
            suggested: [AppBskyUnspeccedDefs.TrendingTopic]
            
            
        ) {
            
            self.topics = topics
            
            self.suggested = suggested
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.topics = try container.decode([AppBskyUnspeccedDefs.TrendingTopic].self, forKey: .topics)
            
            
            self.suggested = try container.decode([AppBskyUnspeccedDefs.TrendingTopic].self, forKey: .suggested)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(topics, forKey: .topics)
            
            
            try container.encode(suggested, forKey: .suggested)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let topicsValue = try topics.toCBORValue()
            map = map.adding(key: "topics", value: topicsValue)
            
            
            
            let suggestedValue = try suggested.toCBORValue()
            map = map.adding(key: "suggested", value: suggestedValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case topics
            case suggested
            
        }
    }




}


extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getTrendingTopics

    /// Get a list of trending topics
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getTrendingTopics(input: AppBskyUnspeccedGetTrendingTopics.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetTrendingTopics.Output?) {
        let endpoint = "app.bsky.unspecced.getTrendingTopics"

        
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
                let decodedData = try decoder.decode(AppBskyUnspeccedGetTrendingTopics.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getTrendingTopics: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
