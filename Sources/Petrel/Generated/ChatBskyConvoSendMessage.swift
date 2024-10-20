import Foundation
import ZippyJSON


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
        
        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyConvoSendMessage.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
