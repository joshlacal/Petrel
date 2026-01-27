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
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(list, forKey: .list)
            
            
            try container.encode(items, forKey: .items)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let listValue = try list.toCBORValue()
            map = map.adding(key: "list", value: listValue)
            
            
            
            let itemsValue = try items.toCBORValue()
            map = map.adding(key: "items", value: itemsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case cursor
            case list
            case items
        }
        
    }




}



extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getList

    /// Gets a 'view' (with additional context) of a specified list.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getList(input: AppBskyGraphGetList.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetList.Output?) {
        let endpoint = "app.bsky.graph.getList"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.graph.getList")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
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
                let decodedData = try decoder.decode(AppBskyGraphGetList.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.graph.getList: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

