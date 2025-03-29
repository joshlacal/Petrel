import Foundation



// lexicon: 1, id: chat.bsky.convo.acceptConvo


public struct ChatBskyConvoAcceptConvo { 

    public static let typeIdentifier = "chat.bsky.convo.acceptConvo"
public struct Input: ATProtocolCodable {
            public let convoId: String

            // Standard public initializer
            public init(convoId: String) {
                self.convoId = convoId
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let rev: String?
        
        
        
        // Standard public initializer
        public init(
            
            rev: String? = nil
            
            
        ) {
            
            self.rev = rev
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.rev = try container.decodeIfPresent(String.self, forKey: .rev)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            if let value = rev {
                
                try container.encode(value, forKey: .rev)
                
            }
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            if let value = rev {
                
                
                let revValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "rev", value: revValue)
                
            }
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case rev
            
        }
    }




}

extension ATProtoClient.Chat.Bsky.Convo {
    /// 
    public func acceptConvo(
        
        input: ChatBskyConvoAcceptConvo.Input
        
    ) async throws -> (responseCode: Int, data: ChatBskyConvoAcceptConvo.Output?) {
        let endpoint = "chat.bsky.convo.acceptConvo"
        
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
        let decodedData = try? decoder.decode(ChatBskyConvoAcceptConvo.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
