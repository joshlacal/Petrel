import Foundation



// lexicon: 1, id: blue.catbird.mls.invalidateWelcome


public struct BlueCatbirdMlsInvalidateWelcome { 

    public static let typeIdentifier = "blue.catbird.mls.invalidateWelcome"
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let reason: String

        /// Standard public initializer
        public init(convoId: String, reason: String) {
            self.convoId = convoId
            self.reason = reason
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.reason = try container.decode(String.self, forKey: .reason)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(reason, forKey: .reason)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let reasonValue = try reason.toCBORValue()
            map = map.adding(key: "reason", value: reasonValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case reason
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let invalidated: Bool
        
        public let welcomeId: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            invalidated: Bool,
            
            welcomeId: String? = nil
            
            
        ) {
            
            
            self.invalidated = invalidated
            
            self.welcomeId = welcomeId
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.invalidated = try container.decode(Bool.self, forKey: .invalidated)
            
            
            self.welcomeId = try container.decodeIfPresent(String.self, forKey: .welcomeId)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(invalidated, forKey: .invalidated)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(welcomeId, forKey: .welcomeId)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let invalidatedValue = try invalidated.toCBORValue()
            map = map.adding(key: "invalidated", value: invalidatedValue)
            
            
            
            if let value = welcomeId {
                // Encode optional property even if it's an empty array for CBOR
                let welcomeIdValue = try value.toCBORValue()
                map = map.adding(key: "welcomeId", value: welcomeIdValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case invalidated
            case welcomeId
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case notFound = "NotFound.No unconsumed Welcome found for this conversation and user"
                case unauthorized = "Unauthorized.Not the recipient of this Welcome"
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
    // MARK: - invalidateWelcome

    /// Invalidate a Welcome message that cannot be processed (e.g., NoMatchingKeyPackage). This allows the client to fall back to External Commit or request re-addition.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func invalidateWelcome(
        
        input: BlueCatbirdMlsInvalidateWelcome.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsInvalidateWelcome.Output?) {
        let endpoint = "blue.catbird.mls.invalidateWelcome"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.invalidateWelcome")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsInvalidateWelcome.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.invalidateWelcome: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

