import Foundation



// lexicon: 1, id: app.bsky.graph.getLists


public struct AppBskyGraphGetLists { 

    public static let typeIdentifier = "app.bsky.graph.getLists"    
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
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(lists, forKey: .lists)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let listsValue = try lists.toCBORValue()
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
    // MARK: - getLists

    /// Enumerates the lists created by a specified account (actor).
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getLists(input: AppBskyGraphGetLists.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetLists.Output?) {
        let endpoint = "app.bsky.graph.getLists"

        
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
        let decodedData = try? decoder.decode(AppBskyGraphGetLists.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
