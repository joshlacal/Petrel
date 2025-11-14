import Foundation



// lexicon: 1, id: blue.catbird.mls.publishKeyPackage


public struct BlueCatbirdMlsPublishKeyPackage { 

    public static let typeIdentifier = "blue.catbird.mls.publishKeyPackage"
public struct Input: ATProtocolCodable {
            public let keyPackage: String
            public let idempotencyKey: String?
            public let cipherSuite: String
            public let expires: ATProtocolDate?

            // Standard public initializer
            public init(keyPackage: String, idempotencyKey: String? = nil, cipherSuite: String, expires: ATProtocolDate? = nil) {
                self.keyPackage = keyPackage
                self.idempotencyKey = idempotencyKey
                self.cipherSuite = cipherSuite
                self.expires = expires
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.keyPackage = try container.decode(String.self, forKey: .keyPackage)
                
                
                self.idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
                
                
                self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
                
                
                self.expires = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expires)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(keyPackage, forKey: .keyPackage)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
                
                
                try container.encode(cipherSuite, forKey: .cipherSuite)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(expires, forKey: .expires)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case keyPackage
                case idempotencyKey
                case cipherSuite
                case expires
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let keyPackageValue = try keyPackage.toCBORValue()
                map = map.adding(key: "keyPackage", value: keyPackageValue)
                
                
                
                if let value = idempotencyKey {
                    // Encode optional property even if it's an empty array for CBOR
                    let idempotencyKeyValue = try value.toCBORValue()
                    map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
                }
                
                
                
                let cipherSuiteValue = try cipherSuite.toCBORValue()
                map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
                
                
                
                if let value = expires {
                    // Encode optional property even if it's an empty array for CBOR
                    let expiresValue = try value.toCBORValue()
                    map = map.adding(key: "expires", value: expiresValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        // Empty output - no properties (response is {})
        
        
        // Standard public initializer
        public init(
            
        ) {
            
        }
        
        public init(from decoder: Decoder) throws {
            
            // Empty output - just validate it's an object by trying to get any container
            _ = try decoder.singleValueContainer()
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            // Empty output - encode empty object
            _ = encoder.singleValueContainer()
            
        }

        public func toCBORValue() throws -> Any {
            
            // Empty output - return empty CBOR map
            return OrderedCBORMap()
            
        }
        
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                /// Key package is malformed or invalid
                case invalidKeyPackage = "InvalidKeyPackage"
                /// Cipher suite is not supported
                case invalidCipherSuite = "InvalidCipherSuite"
                /// Expiration date is too far in the future (max 90 days)
                case expirationTooFar = "ExpirationTooFar"
                /// Maximum number of key packages per user exceeded
                case tooManyKeyPackages = "TooManyKeyPackages"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - publishKeyPackage

    /// Publish an MLS key package to enable others to add you to conversations
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func publishKeyPackage(
        
        input: BlueCatbirdMlsPublishKeyPackage.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsPublishKeyPackage.Output?) {
        let endpoint = "blue.catbird.mls.publishKeyPackage"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.publishKeyPackage")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsPublishKeyPackage.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.publishKeyPackage: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsPublishKeyPackage.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
        
    }
    
}
                           

