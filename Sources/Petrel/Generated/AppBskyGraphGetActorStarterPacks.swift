import Foundation



// lexicon: 1, id: app.bsky.graph.getActorStarterPacks


public struct AppBskyGraphGetActorStarterPacks { 

    public static let typeIdentifier = "app.bsky.graph.getActorStarterPacks"    
public struct Parameters: Parametrizable {
        public let actor: ATIdentifier
        public let limit: Int?
        public let cursor: String?
        
        public init(
            actor: ATIdentifier, 
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
        
        public let starterPacks: [AppBskyGraphDefs.StarterPackViewBasic]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            starterPacks: [AppBskyGraphDefs.StarterPackViewBasic]
            
            
        ) {
            
            self.cursor = cursor
            
            self.starterPacks = starterPacks
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.starterPacks = try container.decode([AppBskyGraphDefs.StarterPackViewBasic].self, forKey: .starterPacks)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            if let value = cursor {
                
                try container.encode(value, forKey: .cursor)
                
            }
            
            
            try container.encode(starterPacks, forKey: .starterPacks)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            if let value = cursor {
                
                
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
                
            }
            
            
            
            
            let starterPacksValue = try (starterPacks as? DAGCBOREncodable)?.toCBORValue() ?? starterPacks
            map = map.adding(key: "starterPacks", value: starterPacksValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case starterPacks
            
        }
    }




}


extension ATProtoClient.App.Bsky.Graph {
    /// Get a list of starter packs created by the actor.
    public func getActorStarterPacks(input: AppBskyGraphGetActorStarterPacks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetActorStarterPacks.Output?) {
        let endpoint = "app.bsky.graph.getActorStarterPacks"
        
        
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
        let decodedData = try? decoder.decode(AppBskyGraphGetActorStarterPacks.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
