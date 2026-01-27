import Foundation



// lexicon: 1, id: blue.catbird.mls.blockChatSender


public struct BlueCatbirdMlsBlockChatSender { 

    public static let typeIdentifier = "blue.catbird.mls.blockChatSender"
public struct Input: ATProtocolCodable {
            public let senderDid: String
            public let requestId: String?
            public let reason: String?

            // Standard public initializer
            public init(senderDid: String, requestId: String? = nil, reason: String? = nil) {
                self.senderDid = senderDid
                self.requestId = requestId
                self.reason = reason
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.senderDid = try container.decode(String.self, forKey: .senderDid)
                
                
                self.requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
                
                
                self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(senderDid, forKey: .senderDid)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(requestId, forKey: .requestId)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(reason, forKey: .reason)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case senderDid
                case requestId
                case reason
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let senderDidValue = try senderDid.toCBORValue()
                map = map.adding(key: "senderDid", value: senderDidValue)
                
                
                
                if let value = requestId {
                    // Encode optional property even if it's an empty array for CBOR
                    let requestIdValue = try value.toCBORValue()
                    map = map.adding(key: "requestId", value: requestIdValue)
                }
                
                
                
                if let value = reason {
                    // Encode optional property even if it's an empty array for CBOR
                    let reasonValue = try value.toCBORValue()
                    map = map.adding(key: "reason", value: reasonValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let success: Bool
        
        public let blockedCount: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            success: Bool,
            
            blockedCount: Int
            
            
        ) {
            
            
            self.success = success
            
            self.blockedCount = blockedCount
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.success = try container.decode(Bool.self, forKey: .success)
            
            
            self.blockedCount = try container.decode(Int.self, forKey: .blockedCount)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(success, forKey: .success)
            
            
            try container.encode(blockedCount, forKey: .blockedCount)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)
            
            
            
            let blockedCountValue = try blockedCount.toCBORValue()
            map = map.adding(key: "blockedCount", value: blockedCountValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case success
            case blockedCount
        }
        
    }




}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - blockChatSender

    /// Block a sender and decline all their pending requests
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func blockChatSender(
        
        input: BlueCatbirdMlsBlockChatSender.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsBlockChatSender.Output?) {
        let endpoint = "blue.catbird.mls.blockChatSender"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.blockChatSender")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsBlockChatSender.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.blockChatSender: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

