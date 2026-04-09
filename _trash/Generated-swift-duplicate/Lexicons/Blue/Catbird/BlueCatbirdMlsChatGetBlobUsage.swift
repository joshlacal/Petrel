import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.getBlobUsage


public struct BlueCatbirdMlsChatGetBlobUsage { 

    public static let typeIdentifier = "blue.catbird.mlsChat.getBlobUsage"
    
public struct Output: ATProtocolCodable {
        
        
        public let usedBytes: Int
        
        public let quotaBytes: Int
        
        public let blobCount: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            usedBytes: Int,
            
            quotaBytes: Int,
            
            blobCount: Int
            
            
        ) {
            
            
            self.usedBytes = usedBytes
            
            self.quotaBytes = quotaBytes
            
            self.blobCount = blobCount
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.usedBytes = try container.decode(Int.self, forKey: .usedBytes)
            
            
            self.quotaBytes = try container.decode(Int.self, forKey: .quotaBytes)
            
            
            self.blobCount = try container.decode(Int.self, forKey: .blobCount)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(usedBytes, forKey: .usedBytes)
            
            
            try container.encode(quotaBytes, forKey: .quotaBytes)
            
            
            try container.encode(blobCount, forKey: .blobCount)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let usedBytesValue = try usedBytes.toCBORValue()
            map = map.adding(key: "usedBytes", value: usedBytesValue)
            
            
            
            let quotaBytesValue = try quotaBytes.toCBORValue()
            map = map.adding(key: "quotaBytes", value: quotaBytesValue)
            
            
            
            let blobCountValue = try blobCount.toCBORValue()
            map = map.adding(key: "blobCount", value: blobCountValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case usedBytes
            case quotaBytes
            case blobCount
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - getBlobUsage

    /// Get blob storage usage for the authenticated user Returns the authenticated user's current blob storage usage, quota, and blob count.
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getBlobUsage() async throws -> (responseCode: Int, data: BlueCatbirdMlsChatGetBlobUsage.Output?) {
        let endpoint = "blue.catbird.mlsChat.getBlobUsage"

        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getBlobUsage")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatGetBlobUsage.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.getBlobUsage: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

