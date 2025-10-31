import Foundation



// lexicon: 1, id: blue.catbird.mls.getMessages


public struct BlueCatbirdMlsGetMessages { 

    public static let typeIdentifier = "blue.catbird.mls.getMessages"    
public struct Parameters: Parametrizable {
        public let convoId: String
        public let limit: Int?
        public let sinceMessage: String?
        
        public init(
            convoId: String, 
            limit: Int? = nil, 
            sinceMessage: String? = nil
            ) {
            self.convoId = convoId
            self.limit = limit
            self.sinceMessage = sinceMessage
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let messages: [BlueCatbirdMlsDefs.MessageView]
        
        public let cursor: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            messages: [BlueCatbirdMlsDefs.MessageView],
            
            cursor: String? = nil
            
            
        ) {
            
            
            self.messages = messages
            
            self.cursor = cursor
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.messages = try container.decode([BlueCatbirdMlsDefs.MessageView].self, forKey: .messages)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(messages, forKey: .messages)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let messagesValue = try messages.toCBORValue()
            map = map.adding(key: "messages", value: messagesValue)
            
            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case messages
            case cursor
        }
        
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of the conversation"
                case invalidCursor = "InvalidCursor.Pagination cursor is invalid"
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getMessages

    /// Retrieve messages from an MLS conversation
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getMessages(input: BlueCatbirdMlsGetMessages.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetMessages.Output?) {
        let endpoint = "blue.catbird.mls.getMessages"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getMessages")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetMessages.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getMessages: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           

