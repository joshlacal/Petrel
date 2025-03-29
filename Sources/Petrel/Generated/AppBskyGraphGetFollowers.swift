import Foundation



// lexicon: 1, id: app.bsky.graph.getFollowers


public struct AppBskyGraphGetFollowers { 

    public static let typeIdentifier = "app.bsky.graph.getFollowers"    
public struct Parameters: Parametrizable {
        public let actor: ATIdentifier
        public let limit: Int?
        public let cursor: String?
        
        public init(
            actor: ATIdentifier, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.actor = actor
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let subject: AppBskyActorDefs.ProfileView
        
        public let cursor: String?
        
        public let followers: [AppBskyActorDefs.ProfileView]
        
        
        
        // Standard public initializer
        public init(
            
            subject: AppBskyActorDefs.ProfileView,
            
            cursor: String? = nil,
            
            followers: [AppBskyActorDefs.ProfileView]
            
            
        ) {
            
            self.subject = subject
            
            self.cursor = cursor
            
            self.followers = followers
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.subject = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .subject)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.followers = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .followers)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(subject, forKey: .subject)
            
            
            if let value = cursor {
                
                try container.encode(value, forKey: .cursor)
                
            }
            
            
            try container.encode(followers, forKey: .followers)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let subjectValue = try (subject as? DAGCBOREncodable)?.toCBORValue() ?? subject
            map = map.adding(key: "subject", value: subjectValue)
            
            
            
            if let value = cursor {
                
                
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
                
            }
            
            
            
            
            let followersValue = try (followers as? DAGCBOREncodable)?.toCBORValue() ?? followers
            map = map.adding(key: "followers", value: followersValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case subject
            case cursor
            case followers
            
        }
    }




}


extension ATProtoClient.App.Bsky.Graph {
    /// Enumerates accounts which follow a specified account (actor).
    public func getFollowers(input: AppBskyGraphGetFollowers.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetFollowers.Output?) {
        let endpoint = "app.bsky.graph.getFollowers"
        
        
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
        let decodedData = try? decoder.decode(AppBskyGraphGetFollowers.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
