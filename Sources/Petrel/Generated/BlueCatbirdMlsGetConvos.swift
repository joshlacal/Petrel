import Foundation



// lexicon: 1, id: blue.catbird.mls.getConvos


public struct BlueCatbirdMlsGetConvos { 

    public static let typeIdentifier = "blue.catbird.mls.getConvos"    
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
        
        
        public let conversations: [BlueCatbirdMlsDefs.ConvoView]
        
        public let cursor: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            conversations: [BlueCatbirdMlsDefs.ConvoView],
            
            cursor: String? = nil
            
            
        ) {
            
            
            self.conversations = conversations
            
            self.cursor = cursor
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.conversations = try container.decode([BlueCatbirdMlsDefs.ConvoView].self, forKey: .conversations)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(conversations, forKey: .conversations)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let conversationsValue = try conversations.toCBORValue()
            map = map.adding(key: "conversations", value: conversationsValue)
            
            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case conversations
            case cursor
        }
        
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case invalidCursor = "InvalidCursor.The provided pagination cursor is invalid"
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getConvos

    /// Retrieve MLS conversations for the authenticated user with pagination support Query to fetch user's MLS conversations
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getConvos(input: BlueCatbirdMlsGetConvos.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetConvos.Output?) {
        let endpoint = "blue.catbird.mls.getConvos"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getConvos")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetConvos.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getConvos: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           

