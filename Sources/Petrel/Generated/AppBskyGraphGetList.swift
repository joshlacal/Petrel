import Foundation



// lexicon: 1, id: app.bsky.graph.getList


public struct AppBskyGraphGetList { 

    public static let typeIdentifier = "app.bsky.graph.getList"    
public struct Parameters: Parametrizable {
        public let list: ATProtocolURI
        public let limit: Int?
        public let cursor: String?
        
        public init(
            list: ATProtocolURI, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.list = list
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let list: AppBskyGraphDefs.ListView
        
        public let items: [AppBskyGraphDefs.ListItemView]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            list: AppBskyGraphDefs.ListView,
            
            items: [AppBskyGraphDefs.ListItemView]
            
            
        ) {
            
            self.cursor = cursor
            
            self.list = list
            
            self.items = items
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.list = try container.decode(AppBskyGraphDefs.ListView.self, forKey: .list)
            
            
            self.items = try container.decode([AppBskyGraphDefs.ListItemView].self, forKey: .items)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            if let value = cursor {
                
                try container.encode(value, forKey: .cursor)
                
            }
            
            
            try container.encode(list, forKey: .list)
            
            
            try container.encode(items, forKey: .items)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case list
            case items
            
        }
    }




}


extension ATProtoClient.App.Bsky.Graph {
    /// Gets a 'view' (with additional context) of a specified list.
    public func getList(input: AppBskyGraphGetList.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetList.Output?) {
        let endpoint = "app.bsky.graph.getList"
        
        
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
        let decodedData = try? decoder.decode(AppBskyGraphGetList.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
