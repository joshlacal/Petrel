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
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let topicsValue = try (topics as? DAGCBOREncodable)?.toCBORValue() ?? topics
            map = map.adding(key: "topics", value: topicsValue)
            
            
            
            
            let suggestedValue = try (suggested as? DAGCBOREncodable)?.toCBORValue() ?? suggested
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
    /// Get a list of trending topics
    public func getTrendingTopics(input: AppBskyUnspeccedGetTrendingTopics.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetTrendingTopics.Output?) {
        let endpoint = "app.bsky.unspecced.getTrendingTopics"
        
        
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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetTrendingTopics.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
