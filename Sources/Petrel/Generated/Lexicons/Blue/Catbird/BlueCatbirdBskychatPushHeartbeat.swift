import Foundation



// lexicon: 1, id: blue.catbird.bskychat.pushHeartbeat


public struct BlueCatbirdBskychatPushHeartbeat { 

    public static let typeIdentifier = "blue.catbird.bskychat.pushHeartbeat"
public struct Input: ATProtocolCodable {
        public let platform: String

        /// Standard public initializer
        public init(platform: String) {
            self.platform = platform
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.platform = try container.decode(String.self, forKey: .platform)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(platform, forKey: .platform)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let platformValue = try platform.toCBORValue()
            map = map.adding(key: "platform", value: platformValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case platform
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let leaseExpiresAt: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            leaseExpiresAt: ATProtocolDate
            
            
        ) {
            
            
            self.leaseExpiresAt = leaseExpiresAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.leaseExpiresAt = try container.decode(ATProtocolDate.self, forKey: .leaseExpiresAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(leaseExpiresAt, forKey: .leaseExpiresAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let leaseExpiresAtValue = try leaseExpiresAt.toCBORValue()
            map = map.adding(key: "leaseExpiresAt", value: leaseExpiresAtValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case leaseExpiresAt
        }
        
    }




}

extension ATProtoClient.Blue.Catbird.Bskychat {
    // MARK: - pushHeartbeat

    /// Send a heartbeat to indicate the client is actively viewing chat. Suppresses server-side polling.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func pushHeartbeat(
        
        input: BlueCatbirdBskychatPushHeartbeat.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdBskychatPushHeartbeat.Output?) {
        let endpoint = "blue.catbird.bskychat.pushHeartbeat"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.bskychat.pushHeartbeat")
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
                let decodedData = try decoder.decode(BlueCatbirdBskychatPushHeartbeat.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.bskychat.pushHeartbeat: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

