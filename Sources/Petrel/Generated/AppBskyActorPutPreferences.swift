import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.actor.putPreferences


public struct AppBskyActorPutPreferences { 

    public static let typeIdentifier = "app.bsky.actor.putPreferences"        
public struct Input: ATProtocolCodable {
            public let preferences: AppBskyActorDefs.Preferences

            // Standard public initializer
            public init(preferences: AppBskyActorDefs.Preferences) {
                self.preferences = preferences
                
            }
        }



}

extension ATProtoClient.App.Bsky.Actor {
    /// Set the private preferences attached to the account.
    public func putPreferences(
        
        input: AppBskyActorPutPreferences.Input
        
    ) async throws -> Int {
        let endpoint = "app.bsky.actor.putPreferences"
        
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
                           
