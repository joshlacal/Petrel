import Foundation



// lexicon: 1, id: app.bsky.graph.getLists


public struct AppBskyGraphGetLists { 

    public static let typeIdentifier = "app.bsky.graph.getLists"    
public struct Parameters: Parametrizable {
        public let actor: String
        public let limit: Int?
        public let cursor: String?
        
        public init(
            actor: String, 
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
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case lists
            
        }
    }




}


extension ATProtoClient.App.Bsky.Graph {
    /// Enumerates the lists created by a specified account (actor).
    public func getLists(input: AppBskyGraphGetLists.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetLists.Output?) {
        let endpoint = "app.bsky.graph.getLists"
        
        
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
        let decodedData = try? decoder.decode(AppBskyGraphGetLists.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
