import Foundation



// lexicon: 1, id: app.bsky.notification.getPreferences


public struct AppBskyNotificationGetPreferences { 

    public static let typeIdentifier = "app.bsky.notification.getPreferences"    
public struct Parameters: Parametrizable {
        
        public init(
            ) {
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let preferences: AppBskyNotificationDefs.Preferences
        
        
        
        // Standard public initializer
        public init(
            
            
            preferences: AppBskyNotificationDefs.Preferences
            
            
        ) {
            
            
            self.preferences = preferences
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.preferences = try container.decode(AppBskyNotificationDefs.Preferences.self, forKey: .preferences)
            
            
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


extension ATProtoClient.App.Bsky.Notification {
    // MARK: - getPreferences

    /// Get notification-related preferences for an account. Requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getPreferences(input: AppBskyNotificationGetPreferences.Parameters) async throws -> (responseCode: Int, data: AppBskyNotificationGetPreferences.Output?) {
        let endpoint = "app.bsky.notification.getPreferences"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.notification.getPreferences")
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
                let decodedData = try decoder.decode(AppBskyNotificationGetPreferences.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.notification.getPreferences: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
