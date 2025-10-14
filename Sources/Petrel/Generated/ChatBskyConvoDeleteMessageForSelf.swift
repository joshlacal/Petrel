import Foundation



// lexicon: 1, id: chat.bsky.convo.deleteMessageForSelf


public struct ChatBskyConvoDeleteMessageForSelf { 

    public static let typeIdentifier = "chat.bsky.convo.deleteMessageForSelf"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let messageId: String

            // Standard public initializer
            public init(convoId: String, messageId: String) {
                self.convoId = convoId
                self.messageId = messageId
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.messageId = try container.decode(String.self, forKey: .messageId)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(messageId, forKey: .messageId)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case messageId
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let messageIdValue = try messageId.toCBORValue()
                map = map.adding(key: "messageId", value: messageIdValue)
                
                

                return map
            }
        }
    public typealias Output = ChatBskyConvoDefs.DeletedMessageView
    



}

extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - deleteMessageForSelf

    /// 
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func deleteMessageForSelf(
        
        input: ChatBskyConvoDeleteMessageForSelf.Input
        
    ) async throws -> (responseCode: Int, data: ChatBskyConvoDeleteMessageForSelf.Output?) {
        let endpoint = "chat.bsky.convo.deleteMessageForSelf"
        
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
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.deleteMessageForSelf")
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
                let decodedData = try decoder.decode(ChatBskyConvoDeleteMessageForSelf.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.deleteMessageForSelf: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           
