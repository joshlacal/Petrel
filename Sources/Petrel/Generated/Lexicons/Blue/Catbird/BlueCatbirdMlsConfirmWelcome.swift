import Foundation



// lexicon: 1, id: blue.catbird.mls.confirmWelcome


public struct BlueCatbirdMlsConfirmWelcome { 

    public static let typeIdentifier = "blue.catbird.mls.confirmWelcome"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let success: Bool
            public let errorDetails: String?

            // Standard public initializer
            public init(convoId: String, success: Bool, errorDetails: String? = nil) {
                self.convoId = convoId
                self.success = success
                self.errorDetails = errorDetails
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.success = try container.decode(Bool.self, forKey: .success)
                
                
                self.errorDetails = try container.decodeIfPresent(String.self, forKey: .errorDetails)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(success, forKey: .success)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(errorDetails, forKey: .errorDetails)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case success
                case errorDetails
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let successValue = try success.toCBORValue()
                map = map.adding(key: "success", value: successValue)
                
                
                
                if let value = errorDetails {
                    // Encode optional property even if it's an empty array for CBOR
                    let errorDetailsValue = try value.toCBORValue()
                    map = map.adding(key: "errorDetails", value: errorDetailsValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let confirmed: Bool
        
        
        
        // Standard public initializer
        public init(
            
            
            confirmed: Bool
            
            
        ) {
            
            
            self.confirmed = confirmed
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.confirmed = try container.decode(Bool.self, forKey: .confirmed)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(confirmed, forKey: .confirmed)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let confirmedValue = try confirmed.toCBORValue()
            map = map.adding(key: "confirmed", value: confirmedValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case confirmed
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of the conversation"
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
    // MARK: - confirmWelcome

    /// Confirm successful or failed processing of Welcome message
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func confirmWelcome(
        
        input: BlueCatbirdMlsConfirmWelcome.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsConfirmWelcome.Output?) {
        let endpoint = "blue.catbird.mls.confirmWelcome"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.confirmWelcome")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsConfirmWelcome.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.confirmWelcome: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

