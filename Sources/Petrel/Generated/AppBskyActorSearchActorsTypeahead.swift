import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.actor.searchActorsTypeahead


public struct AppBskyActorSearchActorsTypeahead { 

    public static let typeIdentifier = "app.bsky.actor.searchActorsTypeahead"    
public struct Parameters: Parametrizable {
        public let term: String?
        public let q: String?
        public let limit: Int?
        
        public init(
            term: String? = nil, 
            q: String? = nil, 
            limit: Int? = nil
            ) {
            self.term = term
            self.q = q
            self.limit = limit
            
        }
    }    
    
public struct Output: ATProtocolCodable {
        
        
        public let actors: [AppBskyActorDefs.ProfileViewBasic]
        
        
        
        // Standard public initializer
        public init(
            
            actors: [AppBskyActorDefs.ProfileViewBasic]
            
            
        ) {
            
            self.actors = actors
            
            
        }
    }




}


extension ATProtoClient.App.Bsky.Actor {
    /// Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.
    public func searchActorsTypeahead(input: AppBskyActorSearchActorsTypeahead.Parameters) async throws -> (responseCode: Int, data: AppBskyActorSearchActorsTypeahead.Output?) {
        let endpoint = "app.bsky.actor.searchActorsTypeahead"
        
        
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
        let decodedData = try? decoder.decode(AppBskyActorSearchActorsTypeahead.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
