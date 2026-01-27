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

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let preferencesValue = try preferences.toCBORValue()
            map = map.adding(key: "preferences", value: preferencesValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case preferences
        }
        
    }




}



extension ATProtoClient.App.Bsky.Actor {
    // MARK: - getPreferences

    /// Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getPreferences(input: AppBskyActorGetPreferences.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetPreferences.Output?) {
        let endpoint = "app.bsky.actor.getPreferences"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.actor.getPreferences")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyActorGetPreferences.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.actor.getPreferences: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

