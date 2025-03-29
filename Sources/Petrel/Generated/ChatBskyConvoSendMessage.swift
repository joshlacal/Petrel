import Foundation



// lexicon: 1, id: chat.bsky.convo.sendMessage


public struct ChatBskyConvoSendMessage { 

    public static let typeIdentifier = "chat.bsky.convo.sendMessage"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let message: ChatBskyConvoDefs.MessageInput

            // Standard public initializer
            public init(convoId: String, message: ChatBskyConvoDefs.MessageInput) {
                self.convoId = convoId
                self.message = message
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.message = try container.decode(ChatBskyConvoDefs.MessageInput.self, forKey: .message)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(message, forKey: .message)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case message
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                
                let messageValue = try (message as? DAGCBOREncodable)?.toCBORValue() ?? message
                map = map.adding(key: "message", value: messageValue)
                
                
                
                return map
            }
        }
    public typealias Output = ChatBskyConvoDefs.MessageView
    



}

extension ATProtoClient.Chat.Bsky.Convo {
    /// 
    public func sendMessage(
        
        input: ChatBskyConvoSendMessage.Input
        
    ) async throws -> (responseCode: Int, data: ChatBskyConvoSendMessage.Output?) {
        let endpoint = "chat.bsky.convo.sendMessage"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        
        
        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers, 
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ChatBskyConvoSendMessage.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
