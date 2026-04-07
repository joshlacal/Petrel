import Foundation



// lexicon: 1, id: app.bsky.contact.startPhoneVerification


public struct AppBskyContactStartPhoneVerification { 

    public static let typeIdentifier = "app.bsky.contact.startPhoneVerification"
public struct Input: ATProtocolCodable {
        public let phone: String

        /// Standard public initializer
        public init(phone: String) {
            self.phone = phone
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.phone = try container.decode(String.self, forKey: .phone)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(phone, forKey: .phone)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let phoneValue = try phone.toCBORValue()
            map = map.adding(key: "phone", value: phoneValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case phone
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
                case rateLimitExceeded = "RateLimitExceeded."
                case invalidDid = "InvalidDid."
                case invalidPhone = "InvalidPhone."
                case internalError = "InternalError."
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

extension ATProtoClient.App.Bsky.Contact {
    // MARK: - startPhoneVerification

    /// Starts a phone verification flow. The phone passed will receive a code via SMS that should be passed to `app.bsky.contact.verifyPhone`. Requires authentication.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func startPhoneVerification(
        
        input: AppBskyContactStartPhoneVerification.Input
        
    ) async throws -> (responseCode: Int, data: AppBskyContactStartPhoneVerification.Output?) {
        let endpoint = "app.bsky.contact.startPhoneVerification"
        
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
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.contact.startPhoneVerification")
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
                let decodedData = try decoder.decode(AppBskyContactStartPhoneVerification.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.contact.startPhoneVerification: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

