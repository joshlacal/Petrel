import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.actor.getProfile


public struct AppBskyActorGetProfile { 

    public static let typeIdentifier = "app.bsky.actor.getProfile"    
public struct Parameters: Parametrizable {
        public let actor: String
        
        public init(
            actor: String
            ) {
            self.actor = actor
            
        }
    }    
    public typealias Output = AppBskyActorDefs.ProfileViewDetailed
    



}


extension ATProtoClient.App.Bsky.Actor {
    /// Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
    public func getProfile(input: AppBskyActorGetProfile.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetProfile.Output?) {
        let endpoint = "app.bsky.actor.getProfile"
        
        
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
        let decodedData = try? decoder.decode(AppBskyActorGetProfile.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
