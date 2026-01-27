import Foundation



// lexicon: 1, id: blue.catbird.mls.getChatRequestSettings


public struct BlueCatbirdMlsGetChatRequestSettings { 

    public static let typeIdentifier = "blue.catbird.mls.getChatRequestSettings"
    
public struct Output: ATProtocolCodable {
        
        
        public let allowFollowersBypass: Bool
        
        public let allowFollowingBypass: Bool
        
        public let autoExpireDays: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            allowFollowersBypass: Bool,
            
            allowFollowingBypass: Bool,
            
            autoExpireDays: Int
            
            
        ) {
            
            
            self.allowFollowersBypass = allowFollowersBypass
            
            self.allowFollowingBypass = allowFollowingBypass
            
            self.autoExpireDays = autoExpireDays
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.allowFollowersBypass = try container.decode(Bool.self, forKey: .allowFollowersBypass)
            
            
            self.allowFollowingBypass = try container.decode(Bool.self, forKey: .allowFollowingBypass)
            
            
            self.autoExpireDays = try container.decode(Int.self, forKey: .autoExpireDays)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(allowFollowersBypass, forKey: .allowFollowersBypass)
            
            
            try container.encode(allowFollowingBypass, forKey: .allowFollowingBypass)
            
            
            try container.encode(autoExpireDays, forKey: .autoExpireDays)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let allowFollowersBypassValue = try allowFollowersBypass.toCBORValue()
            map = map.adding(key: "allowFollowersBypass", value: allowFollowersBypassValue)
            
            
            
            let allowFollowingBypassValue = try allowFollowingBypass.toCBORValue()
            map = map.adding(key: "allowFollowingBypass", value: allowFollowingBypassValue)
            
            
            
            let autoExpireDaysValue = try autoExpireDays.toCBORValue()
            map = map.adding(key: "autoExpireDays", value: autoExpireDaysValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case allowFollowersBypass
            case allowFollowingBypass
            case autoExpireDays
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getChatRequestSettings

    /// Get user's chat request settings
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getChatRequestSettings() async throws -> (responseCode: Int, data: BlueCatbirdMlsGetChatRequestSettings.Output?) {
        let endpoint = "blue.catbird.mls.getChatRequestSettings"

        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getChatRequestSettings")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetChatRequestSettings.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getChatRequestSettings: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

