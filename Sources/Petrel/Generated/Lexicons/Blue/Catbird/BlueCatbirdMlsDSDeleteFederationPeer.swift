import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.deleteFederationPeer


public struct BlueCatbirdMlsDSDeleteFederationPeer { 

    public static let typeIdentifier = "blue.catbird.mlsDS.deleteFederationPeer"
public struct Input: ATProtocolCodable {
        public let dsDid: String

        /// Standard public initializer
        public init(dsDid: String) {
            self.dsDid = dsDid
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.dsDid = try container.decode(String.self, forKey: .dsDid)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(dsDid, forKey: .dsDid)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let dsDidValue = try dsDid.toCBORValue()
            map = map.adding(key: "dsDid", value: dsDidValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case dsDid
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let deleted: Bool
        
        public let dsDid: String
        
        
        
        // Standard public initializer
        public init(
            
            
            deleted: Bool,
            
            dsDid: String
            
            
        ) {
            
            
            self.deleted = deleted
            
            self.dsDid = dsDid
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.deleted = try container.decode(Bool.self, forKey: .deleted)
            
            
            self.dsDid = try container.decode(String.self, forKey: .dsDid)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(deleted, forKey: .deleted)
            
            
            try container.encode(dsDid, forKey: .dsDid)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let deletedValue = try deleted.toCBORValue()
            map = map.adding(key: "deleted", value: deletedValue)
            
            
            
            let dsDidValue = try dsDid.toCBORValue()
            map = map.adding(key: "dsDid", value: dsDidValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case deleted
            case dsDid
        }
        
    }




}

extension ATProtoClient.Blue.Catbird.MlsDS {
    // MARK: - deleteFederationPeer

    /// Delete a federation peer policy (admin only). Remove a federation peer policy record. Requires federation admin privileges.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func deleteFederationPeer(
        
        input: BlueCatbirdMlsDSDeleteFederationPeer.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSDeleteFederationPeer.Output?) {
        let endpoint = "blue.catbird.mlsDS.deleteFederationPeer"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.deleteFederationPeer")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSDeleteFederationPeer.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.deleteFederationPeer: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

