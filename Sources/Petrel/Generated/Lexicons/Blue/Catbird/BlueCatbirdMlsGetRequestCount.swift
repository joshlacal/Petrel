import Foundation



// lexicon: 1, id: blue.catbird.mls.getRequestCount


public struct BlueCatbirdMlsGetRequestCount { 

    public static let typeIdentifier = "blue.catbird.mls.getRequestCount"
    
public struct Output: ATProtocolCodable {
        
        
        public let pendingCount: Int
        
        public let lastRequestAt: ATProtocolDate?
        
        
        
        // Standard public initializer
        public init(
            
            
            pendingCount: Int,
            
            lastRequestAt: ATProtocolDate? = nil
            
            
        ) {
            
            
            self.pendingCount = pendingCount
            
            self.lastRequestAt = lastRequestAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.pendingCount = try container.decode(Int.self, forKey: .pendingCount)
            
            
            self.lastRequestAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastRequestAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(pendingCount, forKey: .pendingCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lastRequestAt, forKey: .lastRequestAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let pendingCountValue = try pendingCount.toCBORValue()
            map = map.adding(key: "pendingCount", value: pendingCountValue)
            
            
            
            if let value = lastRequestAt {
                // Encode optional property even if it's an empty array for CBOR
                let lastRequestAtValue = try value.toCBORValue()
                map = map.adding(key: "lastRequestAt", value: lastRequestAtValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case pendingCount
            case lastRequestAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unauthorized = "Unauthorized.Authentication required"
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
    // MARK: - getRequestCount

    /// Get count of pending chat requests for badge display Returns the count of pending chat requests. Lightweight endpoint for badge updates.
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getRequestCount() async throws -> (responseCode: Int, data: BlueCatbirdMlsGetRequestCount.Output?) {
        let endpoint = "blue.catbird.mls.getRequestCount"

        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getRequestCount")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetRequestCount.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getRequestCount: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

