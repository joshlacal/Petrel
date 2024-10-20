import Foundation
import ZippyJSON


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
                           
