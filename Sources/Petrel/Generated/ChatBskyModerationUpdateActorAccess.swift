import Foundation



// lexicon: 1, id: chat.bsky.moderation.updateActorAccess


public struct ChatBskyModerationUpdateActorAccess { 

    public static let typeIdentifier = "chat.bsky.moderation.updateActorAccess"
public struct Input: ATProtocolCodable {
            public let actor: DID
            public let allowAccess: Bool
            public let ref: String?

            // Standard public initializer
            public init(actor: DID, allowAccess: Bool, ref: String? = nil) {
                self.actor = actor
                self.allowAccess = allowAccess
                self.ref = ref
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.actor = try container.decode(DID.self, forKey: .actor)
                
                
                self.allowAccess = try container.decode(Bool.self, forKey: .allowAccess)
                
                
                self.ref = try container.decodeIfPresent(String.self, forKey: .ref)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(actor, forKey: .actor)
                
                
                try container.encode(allowAccess, forKey: .allowAccess)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(ref, forKey: .ref)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case actor
                case allowAccess
                case ref
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let actorValue = try actor.toCBORValue()
                map = map.adding(key: "actor", value: actorValue)
                
                
                
                let allowAccessValue = try allowAccess.toCBORValue()
                map = map.adding(key: "allowAccess", value: allowAccessValue)
                
                
                
                if let value = ref {
                    // Encode optional property even if it's an empty array for CBOR
                    let refValue = try value.toCBORValue()
                    map = map.adding(key: "ref", value: refValue)
                }
                
                

                return map
            }
        }



}

extension ATProtoClient.Chat.Bsky.Moderation {
    // MARK: - updateActorAccess

    /// 
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateActorAccess(
        
        input: ChatBskyModerationUpdateActorAccess.Input
        
    ) async throws -> Int {
        let endpoint = "chat.bsky.moderation.updateActorAccess"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        
        let (_, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
        
    }
    
}
                           
