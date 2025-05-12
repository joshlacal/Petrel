import Foundation



// lexicon: 1, id: app.bsky.graph.getSuggestedFollowsByActor


public struct AppBskyGraphGetSuggestedFollowsByActor { 

    public static let typeIdentifier = "app.bsky.graph.getSuggestedFollowsByActor"    
public struct Parameters: Parametrizable {
        public let actor: ATIdentifier
        
        public init(
            actor: ATIdentifier
            ) {
            self.actor = actor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let suggestions: [AppBskyActorDefs.ProfileView]
        
        public let isFallback: Bool?
        
        public let recId: Int?
        
        
        
        // Standard public initializer
        public init(
            
            suggestions: [AppBskyActorDefs.ProfileView],
            
            isFallback: Bool? = nil,
            
            recId: Int? = nil
            
            
        ) {
            
            self.suggestions = suggestions
            
            self.isFallback = isFallback
            
            self.recId = recId
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.suggestions = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .suggestions)
            
            
            self.isFallback = try container.decodeIfPresent(Bool.self, forKey: .isFallback)
            
            
            self.recId = try container.decodeIfPresent(Int.self, forKey: .recId)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(suggestions, forKey: .suggestions)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(isFallback, forKey: .isFallback)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(recId, forKey: .recId)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let suggestionsValue = try suggestions.toCBORValue()
            map = map.adding(key: "suggestions", value: suggestionsValue)
            
            
            
            if let value = isFallback {
                // Encode optional property even if it's an empty array for CBOR
                let isFallbackValue = try value.toCBORValue()
                map = map.adding(key: "isFallback", value: isFallbackValue)
            }
            
            
            
            if let value = recId {
                // Encode optional property even if it's an empty array for CBOR
                let recIdValue = try value.toCBORValue()
                map = map.adding(key: "recId", value: recIdValue)
            }
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case suggestions
            case isFallback
            case recId
            
        }
    }




}


extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getSuggestedFollowsByActor

    /// Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getSuggestedFollowsByActor(input: AppBskyGraphGetSuggestedFollowsByActor.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetSuggestedFollowsByActor.Output?) {
        let endpoint = "app.bsky.graph.getSuggestedFollowsByActor"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyGraphGetSuggestedFollowsByActor.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
