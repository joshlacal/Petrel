import Foundation



// lexicon: 1, id: app.bsky.graph.getListBlocks


public struct AppBskyGraphGetListBlocks { 

    public static let typeIdentifier = "app.bsky.graph.getListBlocks"    
public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        
        public init(
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let lists: [AppBskyGraphDefs.ListView]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            lists: [AppBskyGraphDefs.ListView]
            
            
        ) {
            
            self.cursor = cursor
            
            self.lists = lists
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.lists = try container.decode([AppBskyGraphDefs.ListView].self, forKey: .lists)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            if let value = cursor {
                
                try container.encode(value, forKey: .cursor)
                
            }
            
            
            try container.encode(lists, forKey: .lists)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            if let value = cursor {
                
                
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
                
            }
            
            
            
            
            let listsValue = try (lists as? DAGCBOREncodable)?.toCBORValue() ?? lists
            map = map.adding(key: "lists", value: listsValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case lists
            
        }
    }




}


extension ATProtoClient.App.Bsky.Graph {
    /// Get mod lists that the requesting account (actor) is blocking. Requires auth.
    public func getListBlocks(input: AppBskyGraphGetListBlocks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetListBlocks.Output?) {
        let endpoint = "app.bsky.graph.getListBlocks"
        
        
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
        let decodedData = try? decoder.decode(AppBskyGraphGetListBlocks.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
