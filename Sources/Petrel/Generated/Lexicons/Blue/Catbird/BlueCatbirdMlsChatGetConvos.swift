import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.getConvos


public struct BlueCatbirdMlsChatGetConvos { 

    public static let typeIdentifier = "blue.catbird.mlsChat.getConvos"    
public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        public let filter: String?
        public let countOnly: Bool?
        
        public init(
            limit: Int? = nil, 
            cursor: String? = nil, 
            filter: String? = nil, 
            countOnly: Bool? = nil
            ) {
            self.limit = limit
            self.cursor = cursor
            self.filter = filter
            self.countOnly = countOnly
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let conversations: [BlueCatbirdMlsChatDefs.ConvoView]
        
        public let cursor: String?
        
        public let pendingCount: Int?
        
        public let requestCount: Int?
        
        
        
        // Standard public initializer
        public init(
            
            
            conversations: [BlueCatbirdMlsChatDefs.ConvoView],
            
            cursor: String? = nil,
            
            pendingCount: Int? = nil,
            
            requestCount: Int? = nil
            
            
        ) {
            
            
            self.conversations = conversations
            
            self.cursor = cursor
            
            self.pendingCount = pendingCount
            
            self.requestCount = requestCount
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.conversations = try container.decode([BlueCatbirdMlsChatDefs.ConvoView].self, forKey: .conversations)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.pendingCount = try container.decodeIfPresent(Int.self, forKey: .pendingCount)
            
            
            self.requestCount = try container.decodeIfPresent(Int.self, forKey: .requestCount)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(conversations, forKey: .conversations)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pendingCount, forKey: .pendingCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(requestCount, forKey: .requestCount)
            
            
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
            
            
            
            if let value = pendingCount {
                // Encode optional property even if it's an empty array for CBOR
                let pendingCountValue = try value.toCBORValue()
                map = map.adding(key: "pendingCount", value: pendingCountValue)
            }
            
            
            
            if let value = requestCount {
                // Encode optional property even if it's an empty array for CBOR
                let requestCountValue = try value.toCBORValue()
                map = map.adding(key: "requestCount", value: requestCountValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case conversations
            case cursor
            case pendingCount
            case requestCount
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidCursor = "InvalidCursor.The provided pagination cursor is invalid"
                case invalidFilter = "InvalidFilter.Unknown filter value"
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}



extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - getConvos

    /// Retrieve conversations with flexible filtering (consolidates getConvos + getExpectedConversations + listChatRequests + getRequestCount) Query conversations for the authenticated user with pagination and filtering. The 'filter' parameter replaces separate endpoints for expected conversations, chat requests, and request counts.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getConvos(input: BlueCatbirdMlsChatGetConvos.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatGetConvos.Output?) {
        let endpoint = "blue.catbird.mlsChat.getConvos"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getConvos")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatGetConvos.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.getConvos: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

