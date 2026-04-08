import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.getSubscriptionTicket


public struct BlueCatbirdMlsChatGetSubscriptionTicket { 

    public static let typeIdentifier = "blue.catbird.mlsChat.getSubscriptionTicket"
public struct Input: ATProtocolCodable {
        public let convoIds: [String]?

        /// Standard public initializer
        public init(convoIds: [String]? = nil) {
            self.convoIds = convoIds
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoIds = try container.decodeIfPresent([String].self, forKey: .convoIds)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(convoIds, forKey: .convoIds)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            if let value = convoIds {
                let convoIdsValue = try value.toCBORValue()
                map = map.adding(key: "convoIds", value: convoIdsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoIds
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let ticket: String
        
        public let endpoint: URI?
        
        public let expiresAt: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            ticket: String,
            
            endpoint: URI? = nil,
            
            expiresAt: ATProtocolDate
            
            
        ) {
            
            
            self.ticket = ticket
            
            self.endpoint = endpoint
            
            self.expiresAt = expiresAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.ticket = try container.decode(String.self, forKey: .ticket)
            
            
            self.endpoint = try container.decodeIfPresent(URI.self, forKey: .endpoint)
            
            
            self.expiresAt = try container.decode(ATProtocolDate.self, forKey: .expiresAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(ticket, forKey: .ticket)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(endpoint, forKey: .endpoint)
            
            
            try container.encode(expiresAt, forKey: .expiresAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let ticketValue = try ticket.toCBORValue()
            map = map.adding(key: "ticket", value: ticketValue)
            
            
            
            if let value = endpoint {
                // Encode optional property even if it's an empty array for CBOR
                let endpointValue = try value.toCBORValue()
                map = map.adding(key: "endpoint", value: endpointValue)
            }
            
            
            
            let expiresAtValue = try expiresAt.toCBORValue()
            map = map.adding(key: "expiresAt", value: expiresAtValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case ticket
            case endpoint
            case expiresAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case notMember = "NotMember.User is not a member of one or more specified conversations"
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}

extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - getSubscriptionTicket

    /// Get a short-lived ticket for WebSocket subscription authentication (same as v1, in v2 namespace) Get a short-lived ticket for WebSocket subscription authentication. Call this via PDS proxy, then connect directly to the MLS DS WebSocket endpoint with the ticket.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getSubscriptionTicket(
        
        input: BlueCatbirdMlsChatGetSubscriptionTicket.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatGetSubscriptionTicket.Output?) {
        let endpoint = "blue.catbird.mlsChat.getSubscriptionTicket"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getSubscriptionTicket")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatGetSubscriptionTicket.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.getSubscriptionTicket: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

