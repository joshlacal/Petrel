import Foundation
import ZippyJSON


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
        }    
    
public struct Output: ATProtocolCodable {
        
        
        public let convo: ChatBskyConvoDefs.ConvoView
        
        
        
        // Standard public initializer
        public init(
            
            convo: ChatBskyConvoDefs.ConvoView
            
            
        ) {
            
            self.convo = convo
            
            
        }
    }




}

extension ATProtoClient.Chat.Bsky.Convo {
    /// 
    public func updateRead(
        
        input: ChatBskyConvoUpdateRead.Input
        
    ) async throws -> (responseCode: Int, data: ChatBskyConvoUpdateRead.Output?) {
        let endpoint = "chat.bsky.convo.updateRead"
        
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
        
        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyConvoUpdateRead.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
