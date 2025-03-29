import Foundation



// lexicon: 1, id: app.bsky.actor.getPreferences


public struct AppBskyActorGetPreferences { 

    public static let typeIdentifier = "app.bsky.actor.getPreferences"    
public struct Parameters: Parametrizable {
        
        public init(
            ) {
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let preferences: AppBskyActorDefs.Preferences
        
        
        
        // Standard public initializer
        public init(
            
            preferences: AppBskyActorDefs.Preferences
            
            
        ) {
            
            self.preferences = preferences
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.preferences = try container.decode(AppBskyActorDefs.Preferences.self, forKey: .preferences)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(preferences, forKey: .preferences)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let preferencesValue = try (preferences as? DAGCBOREncodable)?.toCBORValue() ?? preferences
            map = map.adding(key: "preferences", value: preferencesValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case preferences
            
        }
    }




}


extension ATProtoClient.App.Bsky.Actor {
    /// Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.
    public func getPreferences(input: AppBskyActorGetPreferences.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetPreferences.Output?) {
        let endpoint = "app.bsky.actor.getPreferences"
        
        
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
        let decodedData = try? decoder.decode(AppBskyActorGetPreferences.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
