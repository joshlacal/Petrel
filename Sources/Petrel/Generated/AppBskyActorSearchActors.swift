import Foundation



// lexicon: 1, id: app.bsky.actor.searchActors


public struct AppBskyActorSearchActors { 

    public static let typeIdentifier = "app.bsky.actor.searchActors"    
public struct Parameters: Parametrizable {
        public let term: String?
        public let q: String?
        public let limit: Int?
        public let cursor: String?
        
        public init(
            term: String? = nil, 
            q: String? = nil, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.term = term
            self.q = q
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let actors: [AppBskyActorDefs.ProfileView]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            actors: [AppBskyActorDefs.ProfileView]
            
            
        ) {
            
            self.cursor = cursor
            
            self.actors = actors
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.actors = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .actors)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            if let value = cursor {
                
                try container.encode(value, forKey: .cursor)
                
            }
            
            
            try container.encode(actors, forKey: .actors)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case actors
            
        }
    }




}


extension ATProtoClient.App.Bsky.Actor {
    /// Find actors (profiles) matching search criteria. Does not require auth.
    public func searchActors(input: AppBskyActorSearchActors.Parameters) async throws -> (responseCode: Int, data: AppBskyActorSearchActors.Output?) {
        let endpoint = "app.bsky.actor.searchActors"
        
        
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
        let decodedData = try? decoder.decode(AppBskyActorSearchActors.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
