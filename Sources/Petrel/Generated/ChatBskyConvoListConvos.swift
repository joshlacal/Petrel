import Foundation
import ZippyJSON


// lexicon: 1, id: chat.bsky.convo.listConvos


public struct ChatBskyConvoListConvos { 

    public static let typeIdentifier = "chat.bsky.convo.listConvos"    
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
        
        
        public let cursor: String?
        
        public let convos: [ChatBskyConvoDefs.ConvoView]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            convos: [ChatBskyConvoDefs.ConvoView]
            
            
        ) {
            
            self.cursor = cursor
            
            self.convos = convos
            
            
        }
    }




}


extension ATProtoClient.Chat.Bsky.Convo {
    /// 
    public func listConvos(input: ChatBskyConvoListConvos.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoListConvos.Output?) {
        let endpoint = "chat.bsky.convo.listConvos"
        
        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
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
        let decodedData = try? decoder.decode(ChatBskyConvoListConvos.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
