import Foundation



// lexicon: 1, id: blue.catbird.mls.validateWelcome


public struct BlueCatbirdMlsValidateWelcome { 

    public static let typeIdentifier = "blue.catbird.mls.validateWelcome"
public struct Input: ATProtocolCodable {
        public let welcomeMessage: Bytes

        /// Standard public initializer
        public init(welcomeMessage: Bytes) {
            self.welcomeMessage = welcomeMessage
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.welcomeMessage = try container.decode(Bytes.self, forKey: .welcomeMessage)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(welcomeMessage, forKey: .welcomeMessage)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let welcomeMessageValue = try welcomeMessage.toCBORValue()
            map = map.adding(key: "welcomeMessage", value: welcomeMessageValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case welcomeMessage
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let valid: Bool
        
        public let keyPackageHash: String
        
        public let recipientDid: DID?
        
        public let groupId: String?
        
        public let reserved: Bool?
        
        public let reservedUntil: ATProtocolDate?
        
        
        
        // Standard public initializer
        public init(
            
            
            valid: Bool,
            
            keyPackageHash: String,
            
            recipientDid: DID? = nil,
            
            groupId: String? = nil,
            
            reserved: Bool? = nil,
            
            reservedUntil: ATProtocolDate? = nil
            
            
        ) {
            
            
            self.valid = valid
            
            self.keyPackageHash = keyPackageHash
            
            self.recipientDid = recipientDid
            
            self.groupId = groupId
            
            self.reserved = reserved
            
            self.reservedUntil = reservedUntil
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.valid = try container.decode(Bool.self, forKey: .valid)
            
            
            self.keyPackageHash = try container.decode(String.self, forKey: .keyPackageHash)
            
            
            self.recipientDid = try container.decodeIfPresent(DID.self, forKey: .recipientDid)
            
            
            self.groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
            
            
            self.reserved = try container.decodeIfPresent(Bool.self, forKey: .reserved)
            
            
            self.reservedUntil = try container.decodeIfPresent(ATProtocolDate.self, forKey: .reservedUntil)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(valid, forKey: .valid)
            
            
            try container.encode(keyPackageHash, forKey: .keyPackageHash)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(recipientDid, forKey: .recipientDid)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(groupId, forKey: .groupId)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reserved, forKey: .reserved)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reservedUntil, forKey: .reservedUntil)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let validValue = try valid.toCBORValue()
            map = map.adding(key: "valid", value: validValue)
            
            
            
            let keyPackageHashValue = try keyPackageHash.toCBORValue()
            map = map.adding(key: "keyPackageHash", value: keyPackageHashValue)
            
            
            
            if let value = recipientDid {
                // Encode optional property even if it's an empty array for CBOR
                let recipientDidValue = try value.toCBORValue()
                map = map.adding(key: "recipientDid", value: recipientDidValue)
            }
            
            
            
            if let value = groupId {
                // Encode optional property even if it's an empty array for CBOR
                let groupIdValue = try value.toCBORValue()
                map = map.adding(key: "groupId", value: groupIdValue)
            }
            
            
            
            if let value = reserved {
                // Encode optional property even if it's an empty array for CBOR
                let reservedValue = try value.toCBORValue()
                map = map.adding(key: "reserved", value: reservedValue)
            }
            
            
            
            if let value = reservedUntil {
                // Encode optional property even if it's an empty array for CBOR
                let reservedUntilValue = try value.toCBORValue()
                map = map.adding(key: "reservedUntil", value: reservedUntilValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case valid
            case keyPackageHash
            case recipientDid
            case groupId
            case reserved
            case reservedUntil
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidWelcome = "InvalidWelcome.Welcome message is malformed or cannot be parsed"
                case keyPackageNotFound = "KeyPackageNotFound.Referenced key package was never uploaded by this user"
                case keyPackageAlreadyConsumed = "KeyPackageAlreadyConsumed.Referenced key package has already been used"
                case keyPackageReserved = "KeyPackageReserved.Referenced key package is reserved by another Welcome message"
                case recipientMismatch = "RecipientMismatch.Welcome message is not for the authenticated user"
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
    // MARK: - validateWelcome

    /// Validate a Welcome message before processing and reserve the referenced key package. Prevents race conditions and helps clients detect missing bundles early.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func validateWelcome(
        
        input: BlueCatbirdMlsValidateWelcome.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsValidateWelcome.Output?) {
        let endpoint = "blue.catbird.mls.validateWelcome"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.validateWelcome")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsValidateWelcome.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.validateWelcome: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

