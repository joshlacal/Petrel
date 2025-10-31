import Foundation



// lexicon: 1, id: chat.bsky.convo.updateRead


public struct ChatBskyConvoUpdateRead { 

    public static let typeIdentifier = "chat.bsky.convo.updateRead"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let messageId: String?

            // Standard public initializer
            public init(convoId: String, messageId: String? = nil) {
                self.convoId = convoId
                self.messageId = messageId
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.messageId = try container.decodeIfPresent(String.self, forKey: .messageId)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(messageId, forKey: .messageId)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case messageId
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                if let value = messageId {
                    // Encode optional property even if it's an empty array for CBOR
                    let messageIdValue = try value.toCBORValue()
                    map = map.adding(key: "messageId", value: messageIdValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let convo: ChatBskyConvoDefs.ConvoView
        
        
        
        // Standard public initializer
        public init(
            
            
            convo: ChatBskyConvoDefs.ConvoView
            
            
        ) {
            
            
            self.convo = convo
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convo = try container.decode(ChatBskyConvoDefs.ConvoView.self, forKey: .convo)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convo, forKey: .convo)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoValue = try convo.toCBORValue()
            map = map.adding(key: "convo", value: convoValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convo
        }
        
    }




}

extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - updateRead

    /// 
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateRead(
        
        input: ChatBskyConvoUpdateRead.Input
        
    ) async throws -> (responseCode: Int, data: ChatBskyConvoUpdateRead.Output?) {
        let endpoint = "chat.bsky.convo.updateRead"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.updateRead")
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
                let decodedData = try decoder.decode(ChatBskyConvoUpdateRead.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.updateRead: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

