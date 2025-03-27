import Foundation



// lexicon: 1, id: chat.bsky.moderation.updateActorAccess


public struct ChatBskyModerationUpdateActorAccess { 

    public static let typeIdentifier = "chat.bsky.moderation.updateActorAccess"
public struct Input: ATProtocolCodable {
            public let actor: String
            public let allowAccess: Bool
            public let ref: String?

            // Standard public initializer
            public init(actor: String, allowAccess: Bool, ref: String? = nil) {
                self.actor = actor
                self.allowAccess = allowAccess
                self.ref = ref
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.actor = try container.decode(String.self, forKey: .actor)
                
                
                self.allowAccess = try container.decode(Bool.self, forKey: .allowAccess)
                
                
                self.ref = try container.decodeIfPresent(String.self, forKey: .ref)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(actor, forKey: .actor)
                
                
                try container.encode(allowAccess, forKey: .allowAccess)
                
                
                if let value = ref {
                    
                    try container.encode(value, forKey: .ref)
                    
                }
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case actor
                case allowAccess
                case ref
            }
        }



}

extension ATProtoClient.Chat.Bsky.Moderation {
    /// 
    public func updateActorAccess(
        
        input: ChatBskyModerationUpdateActorAccess.Input
        
    ) async throws -> Int {
        let endpoint = "chat.bsky.moderation.updateActorAccess"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        
        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers, 
            body: requestData,
            queryItems: nil
        )
        
        
        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
        
    }
    
}
                           
