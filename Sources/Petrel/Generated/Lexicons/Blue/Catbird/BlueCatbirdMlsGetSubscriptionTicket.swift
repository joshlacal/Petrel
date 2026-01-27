import Foundation



// lexicon: 1, id: blue.catbird.mls.getSubscriptionTicket


public struct BlueCatbirdMlsGetSubscriptionTicket { 

    public static let typeIdentifier = "blue.catbird.mls.getSubscriptionTicket"
public struct Input: ATProtocolCodable {
            public let convoId: String?

            // Standard public initializer
            public init(convoId: String? = nil) {
                self.convoId = convoId
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decodeIfPresent(String.self, forKey: .convoId)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(convoId, forKey: .convoId)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                if let value = convoId {
                    // Encode optional property even if it's an empty array for CBOR
                    let convoIdValue = try value.toCBORValue()
                    map = map.adding(key: "convoId", value: convoIdValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let ticket: String
        
        public let endpoint: String
        
        public let expiresAt: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            ticket: String,
            
            endpoint: String,
            
            expiresAt: ATProtocolDate
            
            
        ) {
            
            
            self.ticket = ticket
            
            self.endpoint = endpoint
            
            self.expiresAt = expiresAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.ticket = try container.decode(String.self, forKey: .ticket)
            
            
            self.endpoint = try container.decode(String.self, forKey: .endpoint)
            
            
            self.expiresAt = try container.decode(ATProtocolDate.self, forKey: .expiresAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(ticket, forKey: .ticket)
            
            
            try container.encode(endpoint, forKey: .endpoint)
            
            
            try container.encode(expiresAt, forKey: .expiresAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let ticketValue = try ticket.toCBORValue()
            map = map.adding(key: "ticket", value: ticketValue)
            
            
            
            let endpointValue = try endpoint.toCBORValue()
            map = map.adding(key: "endpoint", value: endpointValue)
            
            
            
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
                case unauthorized = "Unauthorized.Authentication required"
                case forbidden = "Forbidden.User is not a member of the specified conversation"
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

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getSubscriptionTicket

    /// Get a short-lived signed ticket for subscribing to MLS events via WebSocket. The ticket is valid for 30 seconds and must be used to establish a WebSocket connection.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getSubscriptionTicket(
        
        input: BlueCatbirdMlsGetSubscriptionTicket.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetSubscriptionTicket.Output?) {
        let endpoint = "blue.catbird.mls.getSubscriptionTicket"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getSubscriptionTicket")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetSubscriptionTicket.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getSubscriptionTicket: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

