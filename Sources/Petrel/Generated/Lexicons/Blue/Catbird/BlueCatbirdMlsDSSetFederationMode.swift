import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.setFederationMode


public struct BlueCatbirdMlsDSSetFederationMode { 

    public static let typeIdentifier = "blue.catbird.mlsDS.setFederationMode"
public struct Input: ATProtocolCodable {
        public let mode: String

        /// Standard public initializer
        public init(mode: String) {
            self.mode = mode
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.mode = try container.decode(String.self, forKey: .mode)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(mode, forKey: .mode)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let modeValue = try mode.toCBORValue()
            map = map.adding(key: "mode", value: modeValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case mode
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let updated: Bool
        
        public let effectiveMode: String
        
        public let overrideMode: String?
        
        public let envMode: String
        
        
        
        // Standard public initializer
        public init(
            
            
            updated: Bool,
            
            effectiveMode: String,
            
            overrideMode: String? = nil,
            
            envMode: String
            
            
        ) {
            
            
            self.updated = updated
            
            self.effectiveMode = effectiveMode
            
            self.overrideMode = overrideMode
            
            self.envMode = envMode
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.updated = try container.decode(Bool.self, forKey: .updated)
            
            
            self.effectiveMode = try container.decode(String.self, forKey: .effectiveMode)
            
            
            self.overrideMode = try container.decodeIfPresent(String.self, forKey: .overrideMode)
            
            
            self.envMode = try container.decode(String.self, forKey: .envMode)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(updated, forKey: .updated)
            
            
            try container.encode(effectiveMode, forKey: .effectiveMode)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(overrideMode, forKey: .overrideMode)
            
            
            try container.encode(envMode, forKey: .envMode)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let updatedValue = try updated.toCBORValue()
            map = map.adding(key: "updated", value: updatedValue)
            
            
            
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
            case updated
            case effectiveMode
            case overrideMode
            case envMode
        }
        
    }




}

extension ATProtoClient.Blue.Catbird.MlsDS {
    // MARK: - setFederationMode

    /// Set the federation mode at runtime (admin only). Set a runtime override for the federation mode. Requires federation admin privileges.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func setFederationMode(
        
        input: BlueCatbirdMlsDSSetFederationMode.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSSetFederationMode.Output?) {
        let endpoint = "blue.catbird.mlsDS.setFederationMode"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        
        let requestData: Data? = try JSONEncoder().encode(input)
        
        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.setFederationMode")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSSetFederationMode.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.setFederationMode: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

