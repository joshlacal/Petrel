import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.healthCheck


public struct BlueCatbirdMlsDSHealthCheck { 

    public static let typeIdentifier = "blue.catbird.mlsDS.healthCheck"
    
public struct Output: ATProtocolCodable {
        
        
        public let did: String
        
        public let version: String
        
        public let uptime: Int
        
        public let federationCapabilities: [String]
        
        
        
        // Standard public initializer
        public init(
            
            
            did: String,
            
            version: String,
            
            uptime: Int,
            
            federationCapabilities: [String]
            
            
        ) {
            
            
            self.did = did
            
            self.version = version
            
            self.uptime = uptime
            
            self.federationCapabilities = federationCapabilities
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.did = try container.decode(String.self, forKey: .did)
            
            
            self.version = try container.decode(String.self, forKey: .version)
            
            
            self.uptime = try container.decode(Int.self, forKey: .uptime)
            
            
            self.federationCapabilities = try container.decode([String].self, forKey: .federationCapabilities)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(version, forKey: .version)
            
            
            try container.encode(uptime, forKey: .uptime)
            
            
            try container.encode(federationCapabilities, forKey: .federationCapabilities)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            let versionValue = try version.toCBORValue()
            map = map.adding(key: "version", value: versionValue)
            
            
            
            let uptimeValue = try uptime.toCBORValue()
            map = map.adding(key: "uptime", value: uptimeValue)
            
            
            
            let federationCapabilitiesValue = try federationCapabilities.toCBORValue()
            map = map.adding(key: "federationCapabilities", value: federationCapabilitiesValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case did
            case version
            case uptime
            case federationCapabilities
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.MlsDS {
    // MARK: - healthCheck

    /// Simple health/status endpoint for DS-to-DS discovery. Return the health status and federation capabilities of this delivery service. No authentication required.
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func healthCheck() async throws -> (responseCode: Int, data: BlueCatbirdMlsDSHealthCheck.Output?) {
        let endpoint = "blue.catbird.mlsDS.healthCheck"

        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.healthCheck")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSHealthCheck.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.healthCheck: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

