import Foundation



// lexicon: 1, id: app.bsky.graph.getBlocks


public struct AppBskyGraphGetBlocks { 

    public static let typeIdentifier = "app.bsky.graph.getBlocks"    
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
        
        public let blocks: [AppBskyActorDefs.ProfileView]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            blocks: [AppBskyActorDefs.ProfileView]
            
            
        ) {
            
            self.cursor = cursor
            
            self.blocks = blocks
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.blocks = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .blocks)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            if let value = cursor {
                
                try container.encode(value, forKey: .cursor)
                
            }
            
            
            try container.encode(blocks, forKey: .blocks)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            if let value = cursor {
                
                
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
                
            }
            
            
            
            
            let blocksValue = try (blocks as? DAGCBOREncodable)?.toCBORValue() ?? blocks
            map = map.adding(key: "blocks", value: blocksValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case blocks
            
        }
    }




}


extension ATProtoClient.App.Bsky.Graph {
    /// Enumerates which accounts the requesting account is currently blocking. Requires auth.
    public func getBlocks(input: AppBskyGraphGetBlocks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetBlocks.Output?) {
        let endpoint = "app.bsky.graph.getBlocks"
        
        
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
        let decodedData = try? decoder.decode(AppBskyGraphGetBlocks.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
