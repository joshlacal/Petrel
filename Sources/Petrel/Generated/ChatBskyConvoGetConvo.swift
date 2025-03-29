import Foundation



// lexicon: 1, id: chat.bsky.convo.getConvo


public struct ChatBskyConvoGetConvo { 

    public static let typeIdentifier = "chat.bsky.convo.getConvo"    
public struct Parameters: Parametrizable {
        public let convoId: String
        
        public init(
            convoId: String
            ) {
            self.convoId = convoId
            
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
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let convoValue = try (convo as? DAGCBOREncodable)?.toCBORValue() ?? convo
            map = map.adding(key: "convo", value: convoValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case convo
            
        }
    }




}


extension ATProtoClient.Chat.Bsky.Convo {
    /// 
    public func getConvo(input: ChatBskyConvoGetConvo.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetConvo.Output?) {
        let endpoint = "chat.bsky.convo.getConvo"
        
        
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
        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyConvoGetConvo.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
