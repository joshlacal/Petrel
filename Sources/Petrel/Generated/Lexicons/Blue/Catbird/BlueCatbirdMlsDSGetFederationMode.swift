import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.getFederationMode


public struct BlueCatbirdMlsDSGetFederationMode { 

    public static let typeIdentifier = "blue.catbird.mlsDS.getFederationMode"
    
public struct Output: ATProtocolCodable {
        
        
        public let effectiveMode: String
        
        public let overrideMode: String?
        
        public let envMode: String
        
        
        
        // Standard public initializer
        public init(
            
            
            effectiveMode: String,
            
            overrideMode: String? = nil,
            
            envMode: String
            
            
        ) {
            
            
            self.effectiveMode = effectiveMode
            
            self.overrideMode = overrideMode
            
            self.envMode = envMode
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.effectiveMode = try container.decode(String.self, forKey: .effectiveMode)
            
            
            self.overrideMode = try container.decodeIfPresent(String.self, forKey: .overrideMode)
            
            
            self.envMode = try container.decode(String.self, forKey: .envMode)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(effectiveMode, forKey: .effectiveMode)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(overrideMode, forKey: .overrideMode)
            
            
            try container.encode(envMode, forKey: .envMode)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let effectiveModeValue = try effectiveMode.toCBORValue()
            map = map.adding(key: "effectiveMode", value: effectiveModeValue)
            
            
            
            if let value = overrideMode {
                // Encode optional property even if it's an empty array for CBOR
                let overrideModeValue = try value.toCBORValue()
                map = map.adding(key: "overrideMode", value: overrideModeValue)
            }
            
            
            
            let envModeValue = try envMode.toCBORValue()
            map = map.adding(key: "envMode", value: envModeValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case effectiveMode
            case overrideMode
            case envMode
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.MlsDS {
    // MARK: - getFederationMode

    /// Get the current federation mode (admin only). Return the effective, override, and environment federation mode settings.
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getFederationMode() async throws -> (responseCode: Int, data: BlueCatbirdMlsDSGetFederationMode.Output?) {
        let endpoint = "blue.catbird.mlsDS.getFederationMode"

        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.getFederationMode")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSGetFederationMode.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.getFederationMode: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

